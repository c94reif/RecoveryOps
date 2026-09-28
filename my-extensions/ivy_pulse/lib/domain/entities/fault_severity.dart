enum FaultSeverity {
  redX,
  circleX,
  dash;

  String get wireName => switch (this) {
        FaultSeverity.redX => 'RED_X',
        FaultSeverity.circleX => 'CIRCLE_X',
        FaultSeverity.dash => 'DASH',
      };

  String get label => switch (this) {
        FaultSeverity.redX => 'RED X',
        FaultSeverity.circleX => 'CIRCLE X',
        FaultSeverity.dash => 'DASH',
      };

  bool get deadlinesVehicle => this == FaultSeverity.redX;

  bool get requiresCorrection => this != FaultSeverity.dash;

  int get rank => switch (this) {
        FaultSeverity.redX => 3,
        FaultSeverity.circleX => 2,
        FaultSeverity.dash => 1,
      };

  static FaultSeverity fromWireName(String value) => switch (value) {
        'RED_X' => FaultSeverity.redX,
        'CIRCLE_X' => FaultSeverity.circleX,
        'DASH' => FaultSeverity.dash,
        _ => throw ArgumentError('Unknown fault severity: $value'),
      };

  static FaultSeverity? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final severity in FaultSeverity.values) {
      if (severity.wireName == value) return severity;
    }
    return null;
  }
}
