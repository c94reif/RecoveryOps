import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:circle_x/domain/services/pmcs_notification_port.dart';

/// Uses Circle X's bundled Android plugin in a rebuilt native host.
/// Web previews and other platforms have no native notification capability.
PmcsNotificationPort createPmcsNotifications() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? const AndroidPmcsNotifications()
        : const SilentPmcsNotificationPort();

class AndroidPmcsNotifications implements PmcsNotificationPort {
  static const channel = MethodChannel('circle_x/pmcs_notifications');

  const AndroidPmcsNotifications();

  Future<PmcsNotificationStatus> _status(String method,
      [Map<String, Object>? arguments]) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      return PmcsNotificationStatus(
        supported: result?['supported'] == true,
        enabled: result?['enabled'] == true,
        permissionGranted: result?['permissionGranted'] == true,
      );
    } on MissingPluginException {
      // Older native hosts can still receive and relay reports.
      return const PmcsNotificationStatus();
    }
  }

  @override
  Future<PmcsNotificationStatus> getStatus() => _status('getStatus');

  @override
  Future<PmcsNotificationStatus> setEnabled(bool enabled) =>
      _status('setEnabled', {'enabled': enabled});

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Notification support is optional; a host upgrade enables it.
    }
  }

  @override
  Future<void> openSettings() => _invoke('openSettings');

  @override
  Future<void> rememberReports(Iterable<String> reportIds) async {
    final ids = reportIds.where((id) => id.isNotEmpty).toSet().toList();
    // Keep platform messages bounded during large local-history restoration.
    for (var offset = 0; offset < ids.length; offset += 250) {
      final end = offset + 250 < ids.length ? offset + 250 : ids.length;
      await _invoke('rememberReports', {
        'reportIds': ids.sublist(offset, end),
      });
    }
  }

  @override
  Future<void> showReport({
    required String reportId,
    required String title,
    required String body,
  }) async {
    if (reportId.isEmpty) return;
    await _invoke('showReport', {
      'reportId': reportId,
      'title': title,
      'body': body,
    });
  }
}
