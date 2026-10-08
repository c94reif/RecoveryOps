/// Notification preferences and Android permission state on this phone.
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

/// Silent device notifications, independent of report transport and host toasts.
abstract interface class PmcsNotificationPort {
  Future<PmcsNotificationStatus> getStatus();

  /// Only an explicit user action may call this to request OS permission.
  Future<PmcsNotificationStatus> setEnabled(bool enabled);

  Future<void> openSettings();

  /// Seed already observed report IDs without posting a notification.
  Future<void> rememberReports(Iterable<String> reportIds);

  /// Observe [reportId] once, posting silently if enabled and permitted.
  /// Observations persist even while notifications are disabled or denied.
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
