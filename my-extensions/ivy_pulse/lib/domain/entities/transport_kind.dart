/// The two independent legs a submission travels on. Either can be down
/// without the other, so each is queued and drained separately.
enum TransportKind {
  lattice,
  mesh;

  String get wireName => switch (this) {
        TransportKind.lattice => 'lattice',
        TransportKind.mesh => 'mesh',
      };

  String get displayName => switch (this) {
        TransportKind.lattice => 'Lattice',
        TransportKind.mesh => 'Mesh',
      };

  static TransportKind fromWireName(String value) => switch (value) {
        'lattice' => TransportKind.lattice,
        'mesh' => TransportKind.mesh,
        _ => throw ArgumentError('Unknown transport: $value'),
      };

  static TransportKind? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final transport in TransportKind.values) {
      if (transport.wireName == value) return transport;
    }
    return null;
  }
}
