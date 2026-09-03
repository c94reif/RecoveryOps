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
}
