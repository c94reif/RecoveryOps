enum MessageType { text, voice, system }

enum MessageStatus { sent, failed }

/// A chat message (text or voice note).
class Message {
  final String id;
  final String conversationId;
  final String fromDeviceId;
  final MessageType type;
  final String? body;
  String? audioPath;
  final int timestamp;
  MessageStatus status;
  bool isRead;

  /// Callsign of sender — persisted in messages table for offline access.
  String? fromCallsign;

  Message({
    required this.id,
    required this.conversationId,
    required this.fromDeviceId,
    required this.type,
    this.body,
    this.audioPath,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isRead = false,
    this.fromCallsign,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'from_device_id': fromDeviceId,
        'from_callsign': fromCallsign,
        'type': type.name,
        'body': body,
        'audio_path': audioPath,
        'timestamp': timestamp,
        'status': status.name,
        'is_read': isRead ? 1 : 0,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        fromDeviceId: map['from_device_id'] as String,
        type: MessageType.values.byName(map['type'] as String),
        body: map['body'] as String?,
        audioPath: map['audio_path'] as String?,
        timestamp: map['timestamp'] as int,
        status: MessageStatus.values.byName(map['status'] as String),
        isRead: (map['is_read'] as int) == 1,
        fromCallsign: map['from_callsign'] as String?,
      );
}
