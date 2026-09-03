import 'package:flutter/foundation.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';

class SyncNavigatorStates {
  final RemoteReportSource source;

  SyncNavigatorStates(this.source);

  Future<List<NavigatorUpdate>> call(List<RecoveryReport> reports) async {
    final outgoing = reports.where((r) =>
        r.isOutgoing && r.entityId != null && r.entityId!.isNotEmpty);
    if (outgoing.isEmpty) return const [];

    final updates = <NavigatorUpdate>[];
    for (final report in outgoing) {
      try {
        final state = await source.fetchNavigatorState(report.entityId!);
        if (state == null) continue;
        updates.add(state);
      } catch (e) {
        debugPrint(
            '[RecoveryOps] SyncNavigatorStates error for ${report.entityId}: $e');
      }
    }
    return updates;
  }
}
