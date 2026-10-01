enum PmcsPhase {
  before,
  during,
  after;

  String get wireName => switch (this) {
        PmcsPhase.before => 'BEFORE',
        PmcsPhase.during => 'DURING',
        PmcsPhase.after => 'AFTER',
      };

  String get label => switch (this) {
        PmcsPhase.before => 'Before Operations',
        PmcsPhase.during => 'During Operations',
        PmcsPhase.after => 'After Operations',
      };

  String get shortLabel => switch (this) {
        PmcsPhase.before => 'BEFORE',
        PmcsPhase.during => 'DURING',
        PmcsPhase.after => 'AFTER',
      };

  static PmcsPhase fromWireName(String value) => switch (value) {
        'BEFORE' => PmcsPhase.before,
        'DURING' => PmcsPhase.during,
        'AFTER' => PmcsPhase.after,
        _ => throw ArgumentError('Unknown PMCS phase: $value'),
      };

  static PmcsPhase? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final phase in PmcsPhase.values) {
      if (phase.wireName == value) return phase;
    }
    return null;
  }
}
