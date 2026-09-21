/// DA Form 5988-E fault status symbols, ordered most to least severe.
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

  /// A RED X grounds the vehicle — it is Not Mission Capable until cleared by
  /// maintenance. CIRCLE X restricts operation to mission-essential use under
  /// commander approval; DASH is a minor deficiency that may be deferred.
  bool get deadlinesVehicle => this == FaultSeverity.redX;

  /// Whether the fault has to be corrected before the vehicle is released.
  bool get requiresCorrection => this != FaultSeverity.dash;

  /// Higher rank == more severe. Used to sort and to pick a session's worst.
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
