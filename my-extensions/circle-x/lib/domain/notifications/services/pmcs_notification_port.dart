class PmcsNotificationStatus {
  final bool supported;
  final bool enabled;
  final bool permissionGranted;

  const PmcsNotificationStatus({
    this.supported = false,
    this.enabled = false,
    this.permissionGranted = false,
  });
}

abstract interface class PmcsNotificationPort {
  Future<PmcsNotificationStatus> getStatus();

  Future<PmcsNotificationStatus> setEnabled(bool enabled);

  Future<void> openSettings();

  Future<void> rememberReports(Iterable<String> reportIds);

  Future<void> showReport({
    required String reportId,
    required String title,
    required String body,
  });
}

class SilentPmcsNotificationPort implements PmcsNotificationPort {
  const SilentPmcsNotificationPort();

  @override
  Future<PmcsNotificationStatus> getStatus() async =>
      const PmcsNotificationStatus();

  @override
  Future<PmcsNotificationStatus> setEnabled(bool enabled) => getStatus();

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> rememberReports(Iterable<String> reportIds) async {}

  @override
  Future<void> showReport({
    required String reportId,
    required String title,
    required String body,
  }) async {}
}
