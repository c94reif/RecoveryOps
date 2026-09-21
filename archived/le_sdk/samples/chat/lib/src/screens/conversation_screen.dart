import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart'
    as sdk;
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../services/audio_service.dart';
import '../storage/chat_database.dart';
import '../widgets/message_bubble.dart';
import '../widgets/voice_recorder.dart';

/// Conversation screen for direct, broadcast, or group chat.
class ConversationScreen extends StatefulWidget {
  final String conversationId; // peer deviceId, 'broadcast', or groupId
  final Peer? peer; // null for broadcast or group
  final sdk.ContactGroup? group; // non-null for group conversations
  final ValueNotifier<List<sdk.ContactGroup>>? groupsNotifier;
  final String localDeviceId;
  final ChatDatabase db;
  final sdk.MessagingService contactsAccessor;
  final AudioService audio;
  final ValueNotifier<List<Peer>> peersNotifier;
  final VoidCallback onBack;

  // Group action callbacks — provided by host when group != null.
  // Using callbacks instead of a direct GroupSyncService reference keeps
  // the chat sample package free of main-app dependencies.
  final Future<void> Function(String groupId, String deviceId, String callsign)?
      onAddMember;
  final Future<void> Function(String groupId, String deviceId, String callsign)?
      onRemoveMember;
  final Future<void> Function(String groupId, String newName)? onRenameGroup;
  final Future<void> Function(String groupId)? onLeaveGroup;
  final String Function() getSelfCallsign;

  /// Optional: shown as an "X" button in the thread header that dismisses
  /// the entire chat panel (not just the thread).
  final VoidCallback? onClose;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.peer,
    this.group,
    this.groupsNotifier,
    required this.localDeviceId,
    required this.db,
    required this.contactsAccessor,
    required this.audio,
    required this.peersNotifier,
    required this.onBack,
    this.onAddMember,
    this.onRemoveMember,
    this.onRenameGroup,
    this.onLeaveGroup,
    this.getSelfCallsign = _defaultCallsign,
    this.onClose,
  });

  static String _defaultCallsign() => 'You';

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  List<Message> _messages = [];
  bool _isRecording = false;
  String? _recordingPath;
  bool _showGroupRoster = false;

  bool get _isBroadcast => widget.conversationId == 'broadcast';
  bool get _isGroup => widget.group != null;

  /// Live group object — reads from the notifier so roster changes are
  /// picked up immediately (e.g. when a member leaves while chat is open).
  sdk.ContactGroup? get _currentGroup {
    final notifier = widget.groupsNotifier;
    if (notifier == null) return widget.group;
    try {
      return notifier.value.firstWhere((g) => g.id == widget.conversationId);
    } catch (_) {
      return widget.group;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    // Listen for incoming messages via the messaging service
    widget.contactsAccessor.onMessageReceived.listen(_onIncomingMessage);
    // Listen for group roster changes
    widget.groupsNotifier?.addListener(_onGroupsChanged);
  }

  @override
  void dispose() {
    widget.groupsNotifier?.removeListener(_onGroupsChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onGroupsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.db.getMessages(widget.conversationId);
    if (mounted) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
  }

  void _markAsRead() {
    widget.db.markConversationRead(widget.conversationId);
  }

  void _onIncomingMessage(sdk.IncomingMessage incoming) async {
    // The message is written to DB by ChatPanel._processIncomingMessage
    // (which runs concurrently). Reload from DB to pick it up in the
    // correct timestamp order.
    try {
      final json = jsonDecode(incoming.payload) as Map<String, dynamic>;
      final to = json['to'] as String?;
      final String conversationId;
      if (to == 'broadcast') {
        conversationId = 'broadcast';
      } else if (to == widget.conversationId && _isGroup) {
        conversationId = to!;
      } else {
        conversationId = incoming.fromPeerId;
      }
      if (conversationId != widget.conversationId) return;

      // Small delay to let _processIncomingMessage finish the DB insert
      await Future.delayed(const Duration(milliseconds: 50));
      await _loadMessages();
      _markAsRead();
    } catch (e) {
      debugPrint('ConversationScreen: failed to handle incoming message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final msgId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final message = Message(
      id: msgId,
      conversationId: widget.conversationId,
      fromDeviceId: widget.localDeviceId,
      type: MessageType.text,
      body: text,
      timestamp: now,
      status: MessageStatus.sent,
      isRead: true,
    );

    final envelope = jsonEncode({
      'type': 'text',
      'id': msgId,
      'from': widget.localDeviceId,
      'to': widget.conversationId,
      'timestamp': now,
      'body': text,
    });

    await widget.db.insertMessage(message);
    await _loadMessages();

    final success = await _sendToTarget(envelope);
    message.status = success ? MessageStatus.sent : MessageStatus.failed;
    await widget.db.updateMessageStatus(message.id, message.status);
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording and send
      final path = await widget.audio.stopRecording();
      setState(() => _isRecording = false);
      if (path != null) await _sendVoiceNote(path);
    } else {
      // Check permission
      final hasPermission = await widget.audio.hasPermission();
      if (!hasPermission) {
        final granted = await widget.audio.requestPermission();
        if (!granted) return;
      }

      final msgId = _uuid.v4();
      _recordingPath = await widget.audio.startRecording(msgId);
      if (_recordingPath != null) {
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _sendVoiceNote(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);
    final msgId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final message = Message(
      id: msgId,
      conversationId: widget.conversationId,
      fromDeviceId: widget.localDeviceId,
      type: MessageType.voice,
      audioPath: filePath,
      timestamp: now,
      status: MessageStatus.sent,
      isRead: true,
    );

    final envelope = jsonEncode({
      'type': 'voice',
      'id': msgId,
      'from': widget.localDeviceId,
      'to': widget.conversationId,
      'timestamp': now,
      'body': base64Audio,
      'mimeType': 'audio/aac',
    });

    await widget.db.insertMessage(message);
    await _loadMessages();

    final success = await _sendToTarget(envelope);
    message.status = success ? MessageStatus.sent : MessageStatus.failed;
    await widget.db.updateMessageStatus(message.id, message.status);
    if (mounted) setState(() {});
  }

  /// Send via the centralized MessagingService.
  Future<bool> _sendToTarget(String payload) async {
    try {
      if (_isBroadcast) {
        final report = await widget.contactsAccessor.broadcast(payload);
        return report.successCount > 0 || report.results.isEmpty;
      } else if (_isGroup) {
        final report = await widget.contactsAccessor.sendToGroup(
            widget.conversationId, payload);
        return report.successCount > 0;
      } else {
        final report =
            await widget.contactsAccessor.send(widget.conversationId, payload);
        return report.successCount > 0;
      }
    } catch (e) {
      debugPrint('ConversationScreen: send failed: $e');
      return false;
    }
  }

  Future<void> _retryMessage(Message msg) async {
    if (msg.type == MessageType.text) {
      final envelope = jsonEncode({
        'type': 'text',
        'id': msg.id,
        'from': widget.localDeviceId,
        'to': widget.conversationId,
        'timestamp': msg.timestamp,
        'body': msg.body,
      });
      final success = await _sendToTarget(envelope);
      msg.status = success ? MessageStatus.sent : MessageStatus.failed;
      await widget.db.updateMessageStatus(msg.id, msg.status);
      if (mounted) setState(() {});
    }
    // Voice retry: re-read from audioPath and re-send
    if (msg.type == MessageType.voice && msg.audioPath != null) {
      final file = File(msg.audioPath!);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final envelope = jsonEncode({
        'type': 'voice',
        'id': msg.id,
        'from': widget.localDeviceId,
        'to': widget.conversationId,
        'timestamp': msg.timestamp,
        'body': base64Encode(bytes),
        'mimeType': 'audio/aac',
      });
      final success = await _sendToTarget(envelope);
      msg.status = success ? MessageStatus.sent : MessageStatus.failed;
      await widget.db.updateMessageStatus(msg.id, msg.status);
      if (mounted) setState(() {});
    }
  }

  // --- Group roster actions ---

  Future<void> _addMember() async {
    final group = _currentGroup;
    if (group == null) return;

    // Show a picker dialog with peers not already in the group
    final available = widget.peersNotifier.value
        .where((p) => !group.memberDeviceIds.contains(p.deviceId))
        .toList();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts available to add')),
      );
      return;
    }

    final colors = context.lattice.colors;
    final picked = await showDialog<Peer>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.background,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          buttonPadding: EdgeInsets.zero,
          title: Container(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              'ADD MEMBER',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          content: SizedBox(
            width: 300,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (ctx, i) {
                  final peer = available[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(peer),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.borderActive),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_add, size: 20, color: colors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                peer.callsign,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: peer.isOnline
                                    ? colors.success
                                    : colors.inactive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  style: TextButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: colors.borderActive),
                    ),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      )),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (picked == null) return;
    await widget.onAddMember?.call(group.id, picked.deviceId, picked.callsign);
    await _loadMessages();
  }

  Future<void> _renameGroup() async {
    final group = _currentGroup;
    if (group == null) return;

    final controller = TextEditingController(text: group.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.lattice.colors;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            FocusManager.instance.primaryFocus?.unfocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(ctx).pop(false);
            });
          },
          child: AlertDialog(
            backgroundColor: colors.surfaceElevated,
            title: Text(
              'Rename Group',
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                filled: true,
                fillColor: colors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.borderActive),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.borderActive),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.accent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(ctx).pop(false);
                  });
                },
                child: Text('Cancel',
                    style: TextStyle(color: colors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(ctx).pop(true);
                  });
                },
                child:
                    Text('Rename', style: TextStyle(color: colors.accent)),
              ),
            ],
          ),
        );
      },
    );
    final newName = controller.text.trim();
    controller.dispose();
    if (confirmed == true) {
      if (newName.isNotEmpty && newName != group.name) {
        await widget.onRenameGroup?.call(group.id, newName);
        await _loadMessages();
      }
    }
  }

  Future<void> _confirmRemoveMember(
      String deviceId, String callsign) async {
    final group = _currentGroup;
    if (group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.lattice.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'Remove Member',
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
          content: Text(
            'Remove $callsign from the group?',
            style: TextStyle(color: colors.textLabel, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  Text('Remove', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onRemoveMember?.call(group.id, deviceId, callsign);
      await _loadMessages();
    }
  }

  Future<void> _leaveGroup() async {
    final group = _currentGroup;
    if (group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.lattice.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'Leave Group',
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
          content: Text(
            'Leave "${group.name}"?',
            style: TextStyle(color: colors.textLabel, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Leave', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onLeaveGroup?.call(group.id);
      widget.onBack();
    }
  }

  // --- Build methods ---

  Widget _buildGroupRoster(List<Peer> peers) {
    final colors = context.lattice.colors;
    final group = _currentGroup!;

    // Resolve callsign for each member device id
    Peer? _peerForId(String deviceId) {
      try {
        return peers.firstWhere((p) => p.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        border: Border(
          bottom: BorderSide(color: colors.borderActive),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Member list
          ...group.memberDeviceIds.map((deviceId) {
            final isSelf = deviceId == widget.localDeviceId;
            final peer = isSelf ? null : _peerForId(deviceId);
            final callsign = isSelf
                ? widget.getSelfCallsign()
                : (peer?.callsign ?? deviceId);
            final isOnline = isSelf ? true : (peer?.isOnline ?? false);

            return GestureDetector(
              onLongPress: isSelf
                  ? null
                  : () => _confirmRemoveMember(deviceId, callsign),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: colors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    // Online/offline dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? colors.success : colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSelf ? '$callsign (you)' : callsign,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // Leave (self) or Remove (others)
                    if (isSelf)
                      GestureDetector(
                        onTap: _leaveGroup,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.exit_to_app,
                              size: 18, color: colors.error),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () =>
                            _confirmRemoveMember(deviceId, callsign),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.remove_circle_outline,
                              size: 18, color: colors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          // Action row: Add, Rename
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Add member
                GestureDetector(
                  onTap: _addMember,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.person_add,
                        size: 20, color: colors.accent),
                  ),
                ),
                // Rename group
                GestureDetector(
                  onTap: _renameGroup,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.edit,
                        size: 20, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;

    return ValueListenableBuilder<List<Peer>>(
      valueListenable: widget.peersNotifier,
      builder: (context, peers, _) {
        final onlinePeers = peers.where((p) => p.isOnline);

        return Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.borderActive),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onBack,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.arrow_back,
                          size: 20, color: colors.textPrimary),
                    ),
                  ),
                  // Avatar
                  _buildAvatar(),
                  const SizedBox(width: 8),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBroadcast
                              ? 'Broadcast'
                              : _isGroup
                                  ? _currentGroup!.name
                                  : (widget.peer?.callsign ?? 'Unknown'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _isGroup ? 13 : 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          _isBroadcast
                              ? '${onlinePeers.length} users online'
                              : _isGroup
                                  ? '${_currentGroup!.memberDeviceIds.length} members'
                                  : (widget.peer?.isOnline == true
                                      ? 'Online'
                                      : 'Offline'),
                          style: TextStyle(
                            fontSize: 10,
                            color: _isBroadcast
                                ? colors.textSecondary
                                : _isGroup
                                    ? colors.textSecondary
                                    : (widget.peer?.isOnline == true
                                        ? colors.success
                                        : colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit icon for groups
                  if (_isGroup)
                    GestureDetector(
                      onTap: () => setState(
                          () => _showGroupRoster = !_showGroupRoster),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.edit,
                            size: 18, color: colors.textSecondary),
                      ),
                    ),
                  if (widget.onClose != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.close,
                            size: 20, color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),

            // Group roster panel (shown when tapped)
            if (_isGroup && _showGroupRoster) _buildGroupRoster(peers),

            // Messages
            Expanded(
              child: ClipRect(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isOutgoing =
                        msg.fromDeviceId == widget.localDeviceId;

                    // System messages rendered as centred italic text
                    if (msg.type == MessageType.system) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            msg.body ?? '',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }

                    // Resolve sender callsign from peers list
                    String? senderCallsign = msg.fromCallsign;
                    if (senderCallsign == null) {
                      try {
                        senderCallsign = peers
                            .firstWhere(
                                (p) => p.deviceId == msg.fromDeviceId)
                            .callsign;
                      } catch (_) {}
                    }

                    return MessageBubble(
                      message: msg,
                      isOutgoing: isOutgoing,
                      showSenderLabel: _isBroadcast || _isGroup,
                      senderCallsign: senderCallsign,
                      onRetry: msg.status == MessageStatus.failed
                          ? () => _retryMessage(msg)
                          : null,
                      onPlayVoice: (path) => widget.audio.play(path),
                      currentlyPlayingPath: widget.audio.currentlyPlaying,
                      positionStream: widget.audio.positionStream,
                      durationStream: widget.audio.durationStream,
                    );
                  },
                ),
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.borderActive),
                ),
              ),
              child: _isRecording
                  ? VoiceRecorder(onStop: _toggleRecording)
                  : Row(
                      children: [
                        // Text input
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: _isBroadcast
                                  ? 'Broadcast message...'
                                  : 'Type a message...',
                              hintStyle: TextStyle(
                                  color: colors.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: colors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: colors.borderActive),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: colors.borderActive),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: colors.accent),
                              ),
                            ),
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Mic button (hidden for broadcast — voice notes exceed 1400-byte limit)
                        if (!_isBroadcast) ...[
                          GestureDetector(
                            onTap: _toggleRecording,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                border: Border.all(
                                    color: colors.borderActive),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.mic,
                                  size: 20, color: colors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Send button
                        GestureDetector(
                          onTap: _sendText,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.send,
                                size: 20, color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar() {
    final colors = context.lattice.colors;

    if (_isBroadcast) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.iconActive.withValues(alpha: 0.15),
          border: Border.all(color: colors.iconActive, width: 2),
        ),
        child: Center(
          child: Icon(Icons.campaign, size: 16, color: colors.iconActive),
        ),
      );
    }

    if (_isGroup) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accent.withValues(alpha: 0.15),
          border: Border.all(color: colors.accent, width: 2),
        ),
        child: Center(
          child: Icon(Icons.group, size: 16, color: colors.accent),
        ),
      );
    }

    final letter = widget.peer?.callsign.isNotEmpty == true
        ? widget.peer!.callsign[0].toUpperCase()
        : '?';
    final isOnline = widget.peer?.isOnline ?? false;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? colors.success.withValues(alpha: 0.15) : colors.surfaceElevated,
        border: Border.all(
          color: isOnline ? colors.success : colors.textMuted,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isOnline ? colors.success : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
