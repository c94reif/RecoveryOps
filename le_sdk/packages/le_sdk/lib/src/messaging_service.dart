import 'dart:async';

/// Represents a peer device on the network.
class Peer {
  final String deviceId;
  final String callsign;
  final String ip;
  final bool isOnline;
  final DateTime lastSeen;

  const Peer({
    required this.deviceId,
    required this.callsign,
    required this.ip,
    required this.isOnline,
    required this.lastSeen,
  });

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
        deviceId: json['deviceId'] as String,
        callsign: json['callsign'] as String,
        ip: json['ip'] as String,
        isOnline: json['isOnline'] as bool,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'callsign': callsign,
        'ip': ip,
        'isOnline': isOnline,
        'lastSeen': lastSeen.toIso8601String(),
      };
}

/// A named group of contacts.
class ContactGroup {
  final String id;
  final String name;
  final List<String> memberDeviceIds;
  final String creatorDeviceId;
  final bool localUserLeft;

  const ContactGroup({
    required this.id,
    required this.name,
    required this.memberDeviceIds,
    this.creatorDeviceId = '',
    this.localUserLeft = false,
  });

  factory ContactGroup.fromJson(Map<String, dynamic> json) => ContactGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        memberDeviceIds:
            (json['memberDeviceIds'] as List<dynamic>).cast<String>(),
        creatorDeviceId: json['creatorDeviceId'] as String? ?? '',
        localUserLeft: json['localUserLeft'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberDeviceIds': memberDeviceIds,
        'creatorDeviceId': creatorDeviceId,
        'localUserLeft': localUserLeft,
      };
}

/// An incoming message from another peer.
class IncomingMessage {
  final String id;
  final String fromPeerId;
  final String fromCallsign;
  final String payload;
  final DateTime receivedAt;

  const IncomingMessage({
    required this.id,
    required this.fromPeerId,
    required this.fromCallsign,
    required this.payload,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromPeerId': fromPeerId,
        'fromCallsign': fromCallsign,
        'payload': payload,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
      };

  factory IncomingMessage.fromJson(Map<String, dynamic> json) =>
      IncomingMessage(
        id: json['id'] as String,
        fromPeerId: json['fromPeerId'] as String,
        fromCallsign: json['fromCallsign'] as String,
        payload: json['payload'] as String,
        receivedAt:
            DateTime.fromMillisecondsSinceEpoch(json['receivedAt'] as int),
      );
}

/// The result of delivering a message to a single peer.
class DeliveryResult {
  final String peerId;
  final bool success;
  final String? error;

  const DeliveryResult({
    required this.peerId,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'success': success,
        'error': error,
      };

  factory DeliveryResult.fromJson(Map<String, dynamic> json) => DeliveryResult(
        peerId: json['peerId'] as String,
        success: json['success'] as bool,
        error: json['error'] as String?,
      );
}

/// Aggregated delivery report for a multi-recipient send.
class DeliveryReport {
  final List<DeliveryResult> results;

  const DeliveryReport({required this.results});

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
}

/// Access to contacts, messaging, and peer discovery.
abstract class MessagingService {
  /// Get a list of all known peers on the network.
  Future<List<Peer>> getPeers();

  /// Stream that fires whenever the peer list changes.
  Stream<List<Peer>> get onPeersChanged;

  /// Prompt the user to pick one or more recipients.
  /// Returns null if the user cancels.
  Future<List<Peer>?> pickRecipients();

  /// Send a message payload to a single peer.
  Future<DeliveryReport> send(String peerId, String payload);

  /// Send a message payload to multiple peers.
  Future<DeliveryReport> sendToMultiple(
      List<String> peerIds, String payload);

  /// Send a message payload to all members of a group.
  Future<DeliveryReport> sendToGroup(String groupId, String payload);

  /// Broadcast a message payload to all known peers.
  Future<DeliveryReport> broadcast(String payload);

  /// Stream of incoming data messages from other peers.
  Stream<IncomingMessage> get onMessageReceived;

  /// Get the count of unread messages.
  Future<int> getUnreadCount();

  /// Mark a specific message as read.
  Future<void> markAsRead(String messageId);

  /// Mark all messages as read.
  Future<void> markAllAsRead();

  /// Get all contact groups.
  Future<List<ContactGroup>> getGroups();
}
