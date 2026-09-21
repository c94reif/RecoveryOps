import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// A received UDP datagram.
class UdpDatagram {
  final String sourceAddress;
  final int sourcePort;
  final Uint8List bytes;
  final DateTime receivedAt;

  const UdpDatagram({
    required this.sourceAddress,
    required this.sourcePort,
    required this.bytes,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'sourceAddress': sourceAddress,
        'sourcePort': sourcePort,
        'bytes': base64Encode(bytes),
        'receivedAt': receivedAt.millisecondsSinceEpoch,
      };

  factory UdpDatagram.fromJson(Map<String, dynamic> j) => UdpDatagram(
        sourceAddress: j['sourceAddress'] as String,
        sourcePort: j['sourcePort'] as int,
        bytes: base64Decode(j['bytes'] as String),
        receivedAt: DateTime.fromMillisecondsSinceEpoch(j['receivedAt'] as int),
      );
}

/// Result of a send operation.
class SendResult {
  final bool success;
  final String? error;
  const SendResult({required this.success, this.error});

  Map<String, dynamic> toJson() => {'success': success, 'error': error};
  factory SendResult.fromJson(Map<String, dynamic> j) =>
      SendResult(success: j['success'] as bool, error: j['error'] as String?);
}

/// A live UDP subscription owning one bound host socket.
abstract class UdpSubscription {
  /// Incoming datagrams. Broadcast — multiple listeners share one socket.
  /// Does NOT honor pause() backpressure.
  Stream<UdpDatagram> get datagrams;

  /// Send raw bytes from this subscription's bound socket.
  Future<SendResult> send(Uint8List bytes, {String? destinationIp, int? port});

  /// Leave the group, close the socket, release the multicast lock. Idempotent.
  Future<void> close();
}

/// Raw UDP socket access for extensions, brokered by the native host.
abstract class NetworkService {
  /// Join [group] on [port]. Completes when bound+joined; rejects on bind failure.
  Future<UdpSubscription> subscribeMulticast(String group, int port);

  /// Bind 0.0.0.0:[port] for unicast receive. Rejects on bind failure.
  Future<UdpSubscription> subscribeUnicast(int port);

  /// Fire-and-forget multicast send (ephemeral source socket).
  Future<SendResult> sendMulticast(String group, int port, Uint8List bytes);

  /// Fire-and-forget unicast send (ephemeral source socket).
  Future<SendResult> sendUnicast(
      String destinationIp, int port, Uint8List bytes);
}
