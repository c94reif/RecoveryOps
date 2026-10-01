part of 'reports_view_model.dart';

/// Shared state and dependencies for report workflows on a single notifier.
abstract class _ReportsState extends ChangeNotifier {
  ReportsRepository get repository;
  ParseIncomingReport get parseIncomingReport;
  ParseIncomingDeletion get parseIncomingDeletion;
  SyncRemoteReports get syncRemoteReports;
  SyncLocalReportsToLattice get syncLocalReportsToLattice;
  ShowReportOnMap get showReportOnMap;
  PublishPmcsDeletion get publishPmcsDeletion;
  QueueWorkerStrategy get queueWorker;
  ProfileRepository get profileRepository;
  QueuedSubmissionsRepository get queuedRepository;
  UserNotificationSink get snackBarService;

  StreamSubscription<IncomingReportMessage>? messageSubscription;
  Timer? remoteSyncTimer;
  StreamSubscription<void>? deliverySubscription;
  Future<void>? syncInFlight;
  Future<void>? queueRefreshInFlight;
  bool queueRefreshAgain = false;
  bool disposed = false;
  List<PmcsReport>? cachedYours, cachedExternal, cachedUnit, cachedOther;
  final vehicleGroups = Expando<Map<ReportVehicleKey, List<PmcsReport>>>();

  final List<PmcsReport> reports = [];
  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  final ValueNotifier<PmcsReport?> reportToOpen = ValueNotifier(null);

  final ValueNotifier<int> queuedCount = ValueNotifier(0);

  String? activeMarkerId;

  String myUic = '';

  final List<QueuedSubmission> queued = [];

  void invalidateReportViews();
  void updateUnread();
  Future<void> refreshQueued();
  Future<void> refreshQueuedCount();
}
