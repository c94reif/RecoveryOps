part of 'inspection_view_model.dart';

/// State shared by the inspection workflows, with dependencies supplied by
/// [InspectionViewModel]. Cross-workflow operations are declared here so each
/// mixin depends on this contract rather than on another mixin's order.
abstract class _InspectionState extends ChangeNotifier {
  PmcsCatalogSource get catalogSource;
  StartSession get startSession;
  LoadOpenSessions get loadOpenSessions;
  RecordCheckResult get recordCheckResult;
  CompletePhase get completePhase;
  AbandonSession get abandonSession;
  SubmitSession get submitSession;
  PublishPmcsReport get publishPmcsReport;
  ResultsRepository get resultsRepository;
  FaultsRepository get faultsRepository;
  CacScannerStrategy get cacScanner;
  ProfileRepository get profileRepository;
  ReportsRepository get reportsRepository;
  Clock get clock;
  FaultSuggestionController get suggestions;
  void Function(PmcsReport report)? get onReportSubmitted;
  UserNotificationSink get snackBarService;

  InspectionStage stage = InspectionStage.setup;
  PmcsSession? session;
  PmcsCatalog? catalog;
  VehicleType selectedVehicle = VehicleType.stryker;
  PhaseWorkspace? workspace;
  bool reviewingSummaryFault = false;
  PmcsReport? submittedReport;
  PublishResult? submissionDelivery;
  bool submissionDeliveryFailed = false;
  Profile? profile;
  List<PmcsFault> sessionFaults = [];
  List<PmcsSession> openSessions = [];
  final Map<PmcsPhase, int> phaseAnswerCounts = {};
  String? pendingScrollItemId;
  bool isBusy = false;
  late final FaultDictationController dictation;
  late final CacScanController identityScan;

  bool cacScannerAvailable = true;

  PmcsHistory? history;
  bool historyUnavailable = false;

  Future<void> loadHistory();
  Future<void> resetToSetup();
}
