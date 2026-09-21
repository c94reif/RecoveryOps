import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart' show ContactGroup;

import '../models/message.dart';
import '../models/peer.dart';
import '../storage/chat_database.dart';
import '../widgets/contact_tile.dart';

/// Contact list screen showing online/offline peers with last message preview.
/// Also shows past conversations with peers who are no longer discovered.
class ContactsScreen extends StatefulWidget {
  final ValueNotifier<List<Peer>> peersNotifier;
  final ChatDatabase db;
  final void Function(Peer peer) onOpenConversation;
  final VoidCallback onOpenBroadcast;
  final VoidCallback onClearAllMessages;
  final ValueNotifier<List<ContactGroup>> groupsNotifier;
  final Function(ContactGroup) onOpenGroupConversation;
  final Future<void> Function(String name, List<String> memberIds)? onCreateGroup;
  final String Function() getSelfCallsign;
  final String Function()? getSelfDeviceId;
  final VoidCallback? onClose;
  final void Function({
    required String header,
    String hint,
    String initialValue,
    required ValueChanged<String> onConfirm,
    VoidCallback? onCancel,
    bool obscureText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    TextAlign textAlign,
    double? textLetterSpacing,
    String? Function(String)? validator,
  })? onOpenFieldEditor;

  const ContactsScreen({
    super.key,
    required this.peersNotifier,
    required this.db,
    required this.onOpenConversation,
    required this.onOpenBroadcast,
    required this.onClearAllMessages,
    required this.groupsNotifier,
    required this.onOpenGroupConversation,
    this.onCreateGroup,
    this.getSelfCallsign = _defaultCallsign,
    this.getSelfDeviceId,
    this.onClose,
    this.onOpenFieldEditor,
  });

  static String _defaultCallsign() => 'You';

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
  // Cache last message + unread per conversation
  final Map<String, Message?> _lastMessages = {};
  final Map<String, int> _unreadCounts = {};
  // Peers from past conversations not currently discovered
  final Map<String, Peer> _historicPeers = {};
  int _broadcastUnread = 0;

  // Create Group dialog state — persisted across open/close cycles so the
  // field-editor overlay can be shown without losing member selections.
  Set<String> _cgSelected = {};
  String _cgName = '';
  bool _cgHasCustomName = false;

  @override
  void initState() {
    super.initState();
    _loadConversationPreviews();
    widget.peersNotifier.addListener(_onPeersChanged);
    widget.groupsNotifier.addListener(_onGroupsChanged);
  }

  @override
  void dispose() {
    widget.peersNotifier.removeListener(_onPeersChanged);
    widget.groupsNotifier.removeListener(_onGroupsChanged);
    super.dispose();
  }

  void _onPeersChanged() {
    _loadConversationPreviews();
  }

  void _onGroupsChanged() {
    _loadConversationPreviews();
  }

  Future<void> _loadConversationPreviews() async {
    final peers = widget.peersNotifier.value;

    // Load previews for discovered peers
    for (final peer in peers) {
      _lastMessages[peer.deviceId] =
          await widget.db.getLastMessage(peer.deviceId);
      _unreadCounts[peer.deviceId] =
          await widget.db.getUnreadCount(peer.deviceId);
    }

    // Load broadcast
    _lastMessages['broadcast'] = await widget.db.getLastMessage('broadcast');
    _broadcastUnread = await widget.db.getUnreadCount('broadcast');

    // Load historic peers from DB that aren't currently discovered
    final discoveredIds = peers.map((p) => p.deviceId).toSet();
    final dbPeers = await widget.db.getAllPeers();
    _historicPeers.clear();
    for (final dbPeer in dbPeers) {
      if (!discoveredIds.contains(dbPeer.deviceId)) {
        _historicPeers[dbPeer.deviceId] = dbPeer;
        _lastMessages[dbPeer.deviceId] =
            await widget.db.getLastMessage(dbPeer.deviceId);
        _unreadCounts[dbPeer.deviceId] =
            await widget.db.getUnreadCount(dbPeer.deviceId);
      }
    }

    // Also check conversation summaries for conversations with peers
    // not in any peer list (e.g. messages from peers that were never cached)
    final groupIds = widget.groupsNotifier.value.map((g) => g.id).toSet();
    final summaries = await widget.db.getConversationSummaries();
    for (final s in summaries) {
      final convId = s['conversation_id'] as String;
      if (convId == 'broadcast') continue;
      if (groupIds.contains(convId)) continue;
      // Conversations with system messages are groups (even if not in notifier yet)
      if ((s['has_system_msg'] as int? ?? 0) > 0) continue;
      if (discoveredIds.contains(convId)) continue;
      if (_historicPeers.containsKey(convId)) continue;
      // Create a synthetic peer from the conversation data
      final callsign = s['last_from'] as String? ?? convId;
      _historicPeers[convId] = Peer(
        deviceId: convId,
        callsign: callsign,
        ip: '',
        tcpPort: 0,
        firstSeen: 0,
        lastSeen: s['last_ts'] as int? ?? 0,
        isOnline: false,
      );
      _lastMessages[convId] ??= await widget.db.getLastMessage(convId);
      _unreadCounts[convId] ??= await widget.db.getUnreadCount(convId);
    }

    // Load previews for active groups
    final activeGroups = widget.groupsNotifier.value
        .where((g) => !g.localUserLeft)
        .toList();
    for (final group in activeGroups) {
      final msgs = await widget.db.getMessages(group.id, limit: 1);
      _lastMessages[group.id] = msgs.isNotEmpty ? msgs.first : null;
      _unreadCounts[group.id] =
          await widget.db.getUnreadCount(group.id);
    }

    if (mounted) setState(() {});
  }

  /// Refresh previews externally (called after returning from conversation).
  void refresh() => _loadConversationPreviews();

  String _formatTime(int timestampMs) {
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _messagePreview(Message? msg) {
    if (msg == null) return '';
    if (msg.type == MessageType.voice) return 'Voice note';
    return msg.body ?? '';
  }

  Future<bool> _confirmDelete(BuildContext context, Peer peer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = ctx.lattice.colors;
        return AlertDialog(
          backgroundColor: dialogColors.surfaceElevated,
          title: Text(
            'Clear Conversation',
            style: TextStyle(color: dialogColors.textPrimary, fontSize: 16),
          ),
          content: Text(
            'Clear all messages with ${peer.callsign}?',
            style: TextStyle(color: dialogColors.textLabel, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: dialogColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Clear',
                  style: TextStyle(color: dialogColors.error)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.db.deleteConversation(peer.deviceId);
      _lastMessages.remove(peer.deviceId);
      _unreadCounts.remove(peer.deviceId);
      _historicPeers.remove(peer.deviceId);
      if (mounted) setState(() {});
    }
    return false;
  }

  /// Sort peers: those with unread messages first, then by last message time.
  void _sortPeers(List<Peer> peers) {
    peers.sort((a, b) {
      final aUnread = _unreadCounts[a.deviceId] ?? 0;
      final bUnread = _unreadCounts[b.deviceId] ?? 0;
      // Unread first
      if (aUnread > 0 && bUnread == 0) return -1;
      if (aUnread == 0 && bUnread > 0) return 1;
      // Then by most recent message
      final aTime = _lastMessages[a.deviceId]?.timestamp ?? 0;
      final bTime = _lastMessages[b.deviceId]?.timestamp ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  Future<void> _showCreateGroupDialog(LatticeColorScheme colors,
      {bool fresh = true}) async {
    final selfDeviceId = widget.getSelfDeviceId?.call();
    final peers = selfDeviceId != null
        ? widget.peersNotifier.value
            .where((p) => p.deviceId != selfDeviceId)
            .toList()
        : widget.peersNotifier.value;

    // Reset state when opening fresh (not returning from field editor).
    if (fresh) {
      _cgSelected = {};
      _cgName = '';
      _cgHasCustomName = false;
    }

    final nameController = TextEditingController(text: _cgName);
    final nameFocus = FocusNode();

    String autoName() {
      final names = [widget.getSelfCallsign()];
      for (final peer in peers) {
        if (_cgSelected.contains(peer.deviceId)) names.add(peer.callsign);
      }
      return names.join(', ');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            nameFocus.removeListener(() {});
            nameFocus.addListener(() => setDialogState(() {}));
            final isNameFocused = nameFocus.hasFocus;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                FocusManager.instance.primaryFocus?.unfocus();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(dialogContext).pop(false);
                });
              },
              child: AlertDialog(
              backgroundColor: colors.background,
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 24),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Text(
                  'CREATE GROUP',
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            focusNode: nameFocus,
                            readOnly: widget.onOpenFieldEditor != null,
                            autofocus: false,
                            onTap: widget.onOpenFieldEditor != null
                                ? () {
                                    // Save current state before closing dialog.
                                    _cgSelected = Set.of(_cgSelected);
                                    _cgHasCustomName = _cgHasCustomName;
                                    final currentName = nameController.text;
                                    // Close dialog so field editor is visible.
                                    Navigator.of(dialogContext).pop(null);
                                    widget.onOpenFieldEditor!.call(
                                      header: 'Group Name',
                                      hint: 'Enter group name',
                                      initialValue: currentName,
                                      onConfirm: (value) {
                                        _cgName = value;
                                        _cgHasCustomName = true;
                                        _showCreateGroupDialog(colors,
                                            fresh: false);
                                      },
                                      onCancel: () {
                                        // Re-open dialog with unchanged name.
                                        _showCreateGroupDialog(colors,
                                            fresh: false);
                                      },
                                    );
                                  }
                                : null,
                            onChanged: (val) {
                              // If user clears the field, revert to auto-naming
                              if (val.isEmpty) {
                                _cgHasCustomName = false;
                                if (_cgSelected.isNotEmpty) {
                                  nameController.text = autoName();
                                  nameController.selection =
                                      TextSelection.collapsed(
                                          offset: nameController.text.length);
                                }
                              } else {
                                _cgHasCustomName = true;
                              }
                              _cgName = nameController.text;
                              setDialogState(() {});
                            },
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => nameFocus.unfocus(),
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Group name',
                              hintStyle: TextStyle(
                                  color: colors.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: colors.surface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
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
                                borderSide: BorderSide(color: colors.iconActive),
                              ),
                            ),
                          ),
                        ),
                        if (isNameFocused) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: TextButton(
                              onPressed: () => nameFocus.unfocus(),
                              style: TextButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.iconActive,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(color: colors.borderActive),
                                ),
                              ),
                              child: Text('Done',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.iconActive,
                                  )),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text(
                        'SELECT MEMBERS',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: peers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No peers discovered yet.\nMake sure devices are on the same network.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: peers.length,
                              itemBuilder: (ctx, i) {
                                final peer = peers[i];
                                final isSelected =
                                    _cgSelected.contains(peer.deviceId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          _cgSelected.remove(peer.deviceId);
                                        } else {
                                          _cgSelected.add(peer.deviceId);
                                        }
                                        if (!_cgHasCustomName) {
                                          nameController.text = _cgSelected.isEmpty
                                              ? ''
                                              : autoName();
                                          _cgName = nameController.text;
                                        }
                                      });
                                    },
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.iconActive
                                                  .withValues(alpha: 0.5)
                                              : colors.borderActive,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_box
                                                : Icons
                                                    .check_box_outline_blank,
                                            size: 20,
                                            color: isSelected
                                                ? colors.iconActive
                                                : colors.textMuted,
                                          ),
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
                  ],
                ),
                ),
              ),
              actions: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: _cgSelected.isNotEmpty &&
                              nameController.text.trim().isNotEmpty
                          ? () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Navigator.of(dialogContext).pop(true);
                              });
                            }
                          : null,
                      style: TextButton.styleFrom(
                        backgroundColor: _cgSelected.isNotEmpty &&
                                nameController.text.trim().isNotEmpty
                            ? colors.accent
                            : colors.accent.withValues(alpha: 0.3),
                        foregroundColor: colors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text('Create',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onAccent,
                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.of(dialogContext).pop(false);
                        });
                      },
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
            ),
            );
          },
        );
      },
    );

    final name = nameController.text.trim();
    nameController.dispose();
    nameFocus.dispose();
    if (result == true && name.isNotEmpty && _cgSelected.isNotEmpty) {
      await widget.onCreateGroup?.call(name, _cgSelected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Peer>>(
      valueListenable: widget.peersNotifier,
      builder: (context, peers, _) {
        final colors = context.lattice.colors;
        final online = peers.where((p) => p.isOnline).toList();
        _sortPeers(online);

        // Offline = discovered-but-offline + historic peers from DB
        final offlineDiscovered = peers.where((p) => !p.isOnline).toList();
        final historicList = _historicPeers.values
            .where((p) => _lastMessages[p.deviceId] != null)
            .toList();
        final offline = [...offlineDiscovered, ...historicList];
        _sortPeers(offline);

        final hasAnyContent = online.isNotEmpty ||
            offline.isNotEmpty;

        return Column(
          children: [
            // Header
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(
                  bottom: BorderSide(color: colors.border),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Local Chat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onCreateGroup != null)
                    MouseRegion(
                      cursor: peers.isNotEmpty
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: peers.isNotEmpty
                            ? () => _showCreateGroupDialog(colors)
                            : null,
                        child: Opacity(
                          opacity: peers.isNotEmpty ? 1.0 : 0.4,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: Icon(Icons.group_add,
                                  size: 20, color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClearAllMessages,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: Icon(Icons.delete_outline,
                              size: 20, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: Icon(Icons.close,
                              size: 20, color: colors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ClipRect(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // Broadcast conversation (always shown at top)
                    _broadcastTile(),

                    // Group conversations
                    _buildGroupsSection(),

                    // Online section
                    if (online.isNotEmpty) ...[
                      _sectionLabel('ONLINE', online.length,
                          color: colors.success),
                      for (final peer in online)
                        _dismissibleTile(
                          peer: peer,
                          lastMessageTime:
                              _lastMessages[peer.deviceId] != null
                                  ? _formatTime(
                                      _lastMessages[peer.deviceId]!.timestamp)
                                  : null,
                        ),
                    ],

                    // Offline section
                    if (offline.isNotEmpty) ...[
                      _sectionLabel('OFFLINE', offline.length,
                          color: colors.inactive),
                      for (final peer in offline)
                        _dismissibleTile(
                          peer: peer,
                          lastMessageTime:
                              _lastMessages[peer.deviceId] != null
                                  ? _formatTime(
                                      _lastMessages[peer.deviceId]!.timestamp)
                                  : null,
                        ),
                    ],

                    // Empty state
                    if (!hasAnyContent)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Searching for nearby users...\nMake sure you are on the same network.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),

                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _broadcastTile() {
    final colors = context.lattice.colors;
    final lastMsg = _lastMessages['broadcast'];
    final hasUnread = _broadcastUnread > 0;
    return GestureDetector(
      onTap: widget.onOpenBroadcast,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasUnread ? colors.accent.withValues(alpha: 0.05) : null,
          border: Border(
            bottom: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
                border: Border.all(
                  color: colors.iconActive,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(Icons.campaign, size: 16,
                    color: colors.iconActive),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Broadcast',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (lastMsg != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _messagePreview(lastMsg),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (lastMsg != null)
                  Text(
                    _formatTime(lastMsg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textMuted,
                    ),
                  ),
                if (_broadcastUnread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(
                        minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _broadcastUnread > 99
                            ? '99+'
                            : '$_broadcastUnread',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsSection() {
    return ValueListenableBuilder<List<ContactGroup>>(
      valueListenable: widget.groupsNotifier,
      builder: (context, groups, _) {
        final colors = context.lattice.colors;
        final activeGroups =
            groups.where((g) => !g.localUserLeft).toList();
        if (activeGroups.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('GROUPS', activeGroups.length,
                color: colors.accent),
            for (final group in activeGroups)
              _groupTile(group),
          ],
        );
      },
    );
  }

  Widget _groupTile(ContactGroup group) {
    final colors = context.lattice.colors;
    final lastMsg = _lastMessages[group.id];
    final unread = _unreadCounts[group.id] ?? 0;
    final hasUnread = unread > 0;

    // Subtitle: last message body or member count
    final subtitle = lastMsg != null
        ? _messagePreview(lastMsg)
        : '${group.memberDeviceIds.length} members';

    return GestureDetector(
      onTap: () => widget.onOpenGroupConversation(group),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasUnread ? colors.accent.withValues(alpha: 0.05) : null,
          border: Border(
            bottom: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
                border: Border.all(
                  color: colors.iconActive,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(Icons.group, size: 16, color: colors.iconActive),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (lastMsg != null)
                  Text(
                    _formatTime(lastMsg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textMuted,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(
                        minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dismissibleTile({
    required Peer peer,
    required String? lastMessageTime,
  }) {
    final colors = context.lattice.colors;
    final hasUnread = (_unreadCounts[peer.deviceId] ?? 0) > 0;
    return Dismissible(
      key: ValueKey(peer.deviceId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, peer),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.error,
        child: const Icon(Icons.delete, color: Colors.white, size: 20),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: hasUnread ? colors.accent.withValues(alpha: 0.05) : null,
        ),
        child: ContactTile(
          peer: peer,
          lastMessagePreview:
              _messagePreview(_lastMessages[peer.deviceId]),
          lastMessageTime: lastMessageTime,
          unreadCount: _unreadCounts[peer.deviceId] ?? 0,
          onTap: () => widget.onOpenConversation(peer),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, int count, {required Color color}) {
    final colors = context.lattice.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$text  $count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textLabel,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
