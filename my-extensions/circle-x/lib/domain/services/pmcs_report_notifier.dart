import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/services/diagnostic_logger.dart';
import 'package:circle_x/domain/services/pmcs_notification_port.dart';

class PmcsReportNotifier {
  final ReportsRepository reportsRepository;
  final ProfileRepository profileRepository;
  final PmcsNotificationPort notifications;
  final DiagnosticLogger logger;
  final Duration requestTimeout;
  final _seen = <String>{};
  final _suppressed = <String>{};
  late Future<void> _pending;
  bool _baselineLoaded = false;
  bool _disposed = false;

  PmcsReportNotifier({
    required this.reportsRepository,
    required this.profileRepository,
    this.notifications = const SilentPmcsNotificationPort(),
    this.logger = const SilentDiagnosticLogger(),
    this.requestTimeout = const Duration(seconds: 10),
  }) {
    _pending = _seed();
  }

  Future<void> get settled => _pending;

  Future<void> _seed() async {
    try {
      final existing =
          await reportsRepository.getAllReports().timeout(requestTimeout);
      if (_disposed) return;
      final ids = existing
          .map((report) => report.entityId)
          .where((id) => id.isNotEmpty)
          .toSet();
      _seen.addAll(ids);
      _baselineLoaded = true;
      await _remember(ids);
    } catch (error) {
      logger.log('[CircleX] Notification baseline unavailable: $error');
    }
  }

  Future<void> received(Iterable<PmcsReport> records) {
    final candidates = List<PmcsReport>.of(records);
    if (_disposed || candidates.isEmpty) return Future.value();
    return _pending = _pending.then((_) async {
      for (final report in candidates) {
        if (_disposed) return;
        if (report.entityId.isEmpty || !_seen.add(report.entityId)) continue;
        await _receive(report);
      }
    });
  }

  Future<void> remember(Iterable<String> reportIds) {
    final ids = reportIds.where((id) => id.isNotEmpty).toSet();
    _suppressed.addAll(ids);
    final fresh = ids.where(_seen.add).toList();
    if (_disposed || fresh.isEmpty) return Future.value();
    return _pending = _pending.then((_) => _remember(fresh));
  }

  Future<void> _receive(PmcsReport report) async {
    try {
      if (_baselineLoaded &&
          !report.isOutgoing &&
          !report.isRead &&
          !report.isMaintainerReview) {
        final profile =
            await profileRepository.getProfile().timeout(requestTimeout);
        final unit = profile?.reportUnits
            .where((unit) => unit.normalizedUic == Uic.normalize(report.uic))
            .firstOrNull;
        final withdrawn =
            await reportsRepository.getWithdrawnIds().timeout(requestTimeout);
        if (!_disposed &&
            unit != null &&
            !_suppressed.contains(report.entityId) &&
            !withdrawn.contains(report.entityId)) {
          await notifications
              .showReport(
                reportId: report.entityId,
                title: 'New PMCS: ${report.bumperNumber}',
                body: '${unit.label} · ${report.statusLabel}',
              )
              .timeout(requestTimeout);
          return;
        }
      }
    } catch (error) {
      logger.log('[CircleX] PMCS notification failed: $error');
    }
    await _remember([report.entityId]);
  }

  Future<void> _remember(Iterable<String> ids) async {
    if (_disposed || ids.isEmpty) return;
    try {
      await notifications.rememberReports(ids).timeout(requestTimeout);
    } catch (error) {
      logger.log('[CircleX] Could not remember PMCS notification IDs: $error');
    }
  }

  void dispose() => _disposed = true;
}
