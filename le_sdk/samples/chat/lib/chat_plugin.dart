import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'src/models/message.dart';
import 'src/models/peer.dart' as local;
import 'src/screens/contacts_screen.dart';
import 'src/screens/conversation_screen.dart';
import 'src/services/audio_service.dart';
import 'src/storage/chat_database.dart';

/// Peer-to-peer LAN chat plugin.
class ChatPlugin extends LatticeEdgeExtension {
  late final Future<_InitResult> _initFuture;

  @override
  String get id => 'chat';

  @override
  String get name => 'Chat';

  @override
  String get description => 'Peer-to-peer LAN chat with text and voice notes';

  @override
  IconData get icon => Icons.chat;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  void onInitialize() {
    _initFuture = _initAsync();
  }

  Future<_InitResult> _initAsync() async {
    final db = ChatDatabase();
    await db.database; // Ensure DB is created

    // Load or generate device ID
    var deviceId = await db.getConfig('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await db.setConfig('device_id', deviceId);
    }

    final audio = AudioService();

    return _InitResult(
      db: db,
      deviceId: deviceId,
      audio: audio,
    );
  }

  @override
  Widget build(ExtensionContext context) =>
      _ChatApp(initFuture: _initFuture, extensionContext: context);

  @override
  void dispose() {
    _initFuture.then((result) {
      result.audio.dispose();
      result.db.close();
    }).catchError((e) {
      debugPrint('ChatPlugin: dispose failed: $e');
    });
  }
}

class _InitResult {
  final ChatDatabase db;
  final String deviceId;
  final AudioService audio;

  _InitResult({
    required this.db,
    required this.deviceId,
    required this.audio,
  });
}

// --- Navigation ---

enum _Screen { contacts, conversation }

class _ChatApp extends StatefulWidget {
  final Future<_InitResult> initFuture;
  final ExtensionContext extensionContext;

  const _ChatApp({required this.initFuture, required this.extensionContext});

  @override
  State<_ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<_ChatApp> {
  _InitResult? _init;
  String? _initError;
  _Screen _screen = _Screen.contacts;
  String? _conversationId;
  local.Peer? _conversationPeer;
  ContactGroup? _conversationGroup;
  StreamSubscription<List<Peer>>? _peersSub;

  final GlobalKey<ContactsScreenState> _contactsKey = GlobalKey();

  // Local peer list converted from SDK peers
  final ValueNotifier<List<local.Peer>> _peersNotifier = ValueNotifier([]);
  // Group list from SDK
  final ValueNotifier<List<ContactGroup>> _groupsNotifier =
      ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    widget.initFuture.then((result) {
      if (!mounted) return;
      setState(() {
        _init = result;
      });
      // Listen for incoming messages via the centralized contacts system
      widget.extensionContext.messaging.onMessageReceived.listen(_handleIncomingMessage);
      // Listen for peer changes from the host
      _peersSub =
          widget.extensionContext.messaging.onPeersChanged.listen((sdkPeers) {
        _peersNotifier.value = sdkPeers.map(_sdkPeerToLocal).toList();
      });
      // Load initial peers
      widget.extensionContext.messaging.getPeers().then((sdkPeers) {
        _peersNotifier.value = sdkPeers.map(_sdkPeerToLocal).toList();
      });
      // Load initial groups
      widget.extensionContext.messaging.getGroups().then((groups) {
        _groupsNotifier.value = groups;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
    });
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _peersNotifier.dispose();
    _groupsNotifier.dispose();
    super.dispose();
  }

  /// Convert SDK Peer to local Peer model.
  static local.Peer _sdkPeerToLocal(Peer sdkPeer) {
    return local.Peer(
      deviceId: sdkPeer.deviceId,
      callsign: sdkPeer.callsign,
      ip: sdkPeer.ip,
      tcpPort: 0, // Not used — sending goes through MessagingService
      firstSeen: sdkPeer.lastSeen.millisecondsSinceEpoch,
      lastSeen: sdkPeer.lastSeen.millisecondsSinceEpoch,
      isOnline: sdkPeer.isOnline,
    );
  }

  Future<void> _handleIncomingMessage(IncomingMessage incoming) async {
    final init = _init;
    if (init == null) return;

    try {
      final json =
          jsonDecode(incoming.payload) as Map<String, dynamic>;

      final msgType = (json['type'] as String?) == 'voice'
          ? MessageType.voice
          : MessageType.text;

      final to = json['to'] as String?;
      final String conversationId;
      if (to == 'broadcast') {
        conversationId = 'broadcast';
      } else if (to != null &&
          _groupsNotifier.value.any((g) => g.id == to)) {
        conversationId = to;
      } else if (to != null) {
        // Group may have been created after init — re-query
        final groups = await widget.extensionContext.messaging.getGroups();
        _groupsNotifier.value = groups;
        if (groups.any((g) => g.id == to)) {
          conversationId = to;
        } else {
          conversationId = incoming.fromPeerId;
        }
      } else {
        conversationId = incoming.fromPeerId;
      }

      final msg = Message(
        id: json['id'] as String? ?? incoming.id,
        conversationId: conversationId,
        fromDeviceId: incoming.fromPeerId,
        type: msgType,
        body: msgType == MessageType.voice ? null : json['body'] as String?,
        timestamp:
            json['timestamp'] as int? ?? incoming.receivedAt.millisecondsSinceEpoch,
        status: MessageStatus.sent,
        isRead: false,
        fromCallsign: incoming.fromCallsign,
      );

      // Handle voice note: decode and save file
      if (msgType == MessageType.voice && json['body'] != null) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/voice_${msg.id}.aac';
        final bytes = base64Decode(json['body'] as String);
        await File(filePath).writeAsBytes(bytes);
        msg.audioPath = filePath;
      }

      // Save message
      await init.db.insertMessage(msg);

      // Refresh contacts preview
      _contactsKey.currentState?.refresh();
    } catch (e) {
      debugPrint('ChatPlugin: failed to handle incoming message: $e');
    }
  }

  void _openConversation(local.Peer peer) {
    setState(() {
      _screen = _Screen.conversation;
      _conversationId = peer.deviceId;
      _conversationPeer = peer;
    });
  }

  void _openGroupConversation(ContactGroup group) {
    setState(() {
      _screen = _Screen.conversation;
      _conversationId = group.id;
      _conversationPeer = null;
      _conversationGroup = group;
    });
  }

  void _openBroadcast() {
    setState(() {
      _screen = _Screen.conversation;
      _conversationId = 'broadcast';
      _conversationPeer = null;
    });
  }

  void _backToContacts() {
    _contactsKey.currentState?.refresh();
    setState(() {
      _screen = _Screen.contacts;
      _conversationId = null;
      _conversationPeer = null;
      _conversationGroup = null;
    });
  }

  void _clearAllMessages() {
    final init = _init;
    if (init == null) return;
    init.db.deleteAllMessages();
    _contactsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;

    // Error state
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to initialize chat:\n$_initError',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.error),
          ),
        ),
      );
    }

    // Loading state
    if (_init == null) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.accent,
          strokeWidth: 2,
        ),
      );
    }

    final init = _init!;

    switch (_screen) {
      case _Screen.contacts:
        return ContactsScreen(
          key: _contactsKey,
          peersNotifier: _peersNotifier,
          db: init.db,
          onOpenConversation: _openConversation,
          onOpenBroadcast: _openBroadcast,
          onClearAllMessages: _clearAllMessages,
          groupsNotifier: _groupsNotifier,
          onOpenGroupConversation: _openGroupConversation,
        );

      case _Screen.conversation:
        return ConversationScreen(
          conversationId: _conversationId!,
          peer: _conversationPeer,
          group: _conversationGroup,
          localDeviceId: init.deviceId,
          db: init.db,
          contactsAccessor: widget.extensionContext.messaging,
          audio: init.audio,
          peersNotifier: _peersNotifier,
          onBack: _backToContacts,
        );
    }
  }
}
