/// Identity and timing constants shared across layers.
class AppConstants {
  const AppConstants._();

  /// Extension id, also the Lattice provenance integration name — entities we
  /// publish are recognised as ours by this.
  static const String extensionId = 'ivy_pulse';
  static const String extensionName = 'Ivy Pulse';
  static const String extensionDescription =
      'Guided PMCS for tactical vehicles';

  /// Provenance data type stamped on every entity we publish.
  static const String entityDataType = 'PMCS_REPORT';

  /// Mesh payload discriminators.
  static const String meshReportType = 'ivy_pulse.report';
  static const String meshDeletionType = 'ivy_pulse.deletion';

  /// How long a published PMCS entity stays live on the map before expiring.
  /// One dispatch day — a PMCS older than that is not current.
  static const Duration entityTtl = Duration(days: 1);

  /// The host's location bridge can hang; never make an operator wait longer
  /// than this to start a walk-around.
  static const Duration locationTimeout = Duration(seconds: 5);

  /// Background pull of other crews' reports from Lattice.
  static const Duration remoteSyncInterval = Duration(minutes: 5);

  /// Retry cadence for a transport the queue believes is down.
  static const Duration transportProbeInterval = Duration(seconds: 45);

  /// How long to wait on a camera that has been handed the whole screen.
  ///
  /// The camera is a separate Android activity, so it can crash, be killed
  /// for memory, or sit behind a permission dialog the operator dismisses —
  /// none of which fire an event back into the WebView. A capture left
  /// pending latches the submit button off for the rest of the session, which
  /// is how a walked PMCS becomes one that can never be sent. Long enough
  /// that a Soldier in gloves lining a card up is never cut off mid-shot.
  static const Duration cacCaptureTimeout = Duration(seconds: 120);
}
