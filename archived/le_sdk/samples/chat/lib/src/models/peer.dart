/// A discovered peer on the local network.
class Peer {
  final String deviceId;
  String callsign;
  String ip;
  int tcpPort;
  final int firstSeen;
  int lastSeen;
  bool isOnline;

  Peer({
    required this.deviceId,
    required this.callsign,
    required this.ip,
    required this.tcpPort,
    required this.firstSeen,
    required this.lastSeen,
    this.isOnline = true,
  });

  Map<String, dynamic> toMap() => {
        'device_id': deviceId,
        'callsign': callsign,
        'ip': ip,
        'tcp_port': tcpPort,
        'first_seen': firstSeen,
        'last_seen': lastSeen,
        'is_online': isOnline ? 1 : 0,
      };

  factory Peer.fromMap(Map<String, dynamic> map) => Peer(
        deviceId: map['device_id'] as String,
        callsign: map['callsign'] as String,
        ip: map['ip'] as String,
        tcpPort: map['tcp_port'] as int,
        firstSeen: map['first_seen'] as int,
        lastSeen: map['last_seen'] as int,
        isOnline: (map['is_online'] as int) == 1,
      );
}
