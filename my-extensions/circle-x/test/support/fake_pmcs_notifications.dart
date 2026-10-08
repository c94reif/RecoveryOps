import 'dart:async';

import 'package:circle_x/domain/services/pmcs_notification_port.dart';

typedef PostedPmcsAlert = ({String reportId, String title, String body});

class FakePmcsNotifications extends SilentPmcsNotificationPort {
  final remembered = <String>{};
  final attempts = <String>[];
  final posted = <PostedPmcsAlert>[];
  final rememberedBatches = <List<String>>[];
  bool enabled = true;
  bool failShow = false;
  bool failRemember = false;
  Completer<void>? showGate;
  Completer<void>? rememberGate;

  @override
  Future<void> rememberReports(Iterable<String> reportIds) async {
    final ids = reportIds.toList();
    rememberedBatches.add(ids);
    await rememberGate?.future;
    if (failRemember) throw StateError('device storage unavailable');
    remembered.addAll(ids);
  }

  @override
  Future<void> showReport({
    required String reportId,
    required String title,
    required String body,
  }) async {
    attempts.add(reportId);
    await showGate?.future;
    if (failShow) throw StateError('device notifications unavailable');
    if (remembered.add(reportId) && enabled) {
      posted.add((reportId: reportId, title: title, body: body));
    }
  }
}
