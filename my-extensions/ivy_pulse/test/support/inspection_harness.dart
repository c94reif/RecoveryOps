import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';
import 'package:ivy_pulse/domain/usecases/session/abandon_session.dart';
import 'package:ivy_pulse/domain/usecases/session/complete_phase.dart';
import 'package:ivy_pulse/domain/usecases/session/load_open_sessions.dart';
import 'package:ivy_pulse/domain/usecases/session/record_check_result.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:latlong2/latlong.dart';

import 'fakes.dart';

/// A four-check Stryker catalog, small enough that a whole phase can be walked
/// in a widget test but shaped like the real one: categories per phase, a
/// serviceable option at index 0, and conditions escalating with the index.
const brakeFluid = PmcsCheckItem(
  id: 'B-BRK-01',
  item: 'Brake Fluid',
  check: 'Reservoir between MIN and MAX',
  faults: ['Level OK', 'Low', 'Empty', 'Reservoir Cracked'],
);
const parkingBrake = PmcsCheckItem(
  id: 'B-BRK-02',
  item: 'Parking Brake',
  check: 'Engages and holds',
  faults: ['Holds Firm', 'Slips', 'Will Not Engage', 'Cable Frayed'],
);
const tirePressure = PmcsCheckItem(
  id: 'D-TIR-01',
  item: 'Tire Pressure',
  check: 'CTIS reads correct pressure',
  faults: ['All Normal', 'One Low', 'One Flat', 'CTIS Inop'],
);
const coolDown = PmcsCheckItem(
  id: 'A-CDN-01',
  item: 'Engine Cool-Down',
  check: 'Idle 3-5 min',
  faults: ['Normal Shutdown', 'Unusual Noise', 'Smoke', 'Leak Developed'],
);

const testCatalog = PmcsCatalog(
  vehicleType: VehicleType.stryker,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(name: 'BRAKES', items: [brakeFluid, parkingBrake]),
    ],
    PmcsPhase.during: [
      PmcsCategory(name: 'TIRES', items: [tirePressure]),
    ],
    PmcsPhase.after: [
      PmcsCategory(name: 'COOL-DOWN', items: [coolDown]),
    ],
  },
);

const jltvHubs = PmcsCheckItem(
  id: 'B-HUB-01',
  item: 'Wheel Hubs',
  check: 'No leaks at the hub seals',
  faults: ['Dry', 'Weeping', 'Running Wet', 'Seal Blown'],
);

const jltvTestCatalog = PmcsCatalog(
  vehicleType: VehicleType.jltv,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(name: 'RUNNING GEAR', items: [jltvHubs]),
    ],
  },
);

const testProfile = Profile(uic: 'WJ8TAA');

class FakeCatalogSource implements PmcsCatalogSource {
  final Map<VehicleType, PmcsCatalog> catalogs;

  FakeCatalogSource([Map<VehicleType, PmcsCatalog>? catalogs])
      : catalogs = catalogs ??
            const {
              VehicleType.stryker: testCatalog,
              VehicleType.jltv: jltvTestCatalog,
            };

  @override
  List<VehicleType> get supportedVehicles => [
        for (final type in VehicleType.values)
          if (catalogs.containsKey(type)) type,
      ];

  @override
  PmcsCatalog catalogFor(VehicleType vehicleType) {
    final catalog = catalogs[vehicleType];
    if (catalog == null) throw StateError('no catalog for $vehicleType');
    return catalog;
  }
}

class FakeSpeechRecognition implements SpeechRecognitionStrategy {
  bool listening = false;
  int stopCalls = 0;
  void Function(String)? pendingResult;

  @override
  bool get isListening => listening;

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {
    listening = true;
    pendingResult = onResult;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
    listening = false;
  }

  Future<void> deliver(String text) async {
    final callback = pendingResult;
    pendingResult = null;
    listening = false;
    callback?.call(text);
  }
}

/// A real [InspectionViewModel] over in-memory doubles, plus the getIt
/// registrations the four inspection pages resolve in `initState`.
///
/// Widget tests drive the flow through the view model exactly as the pages do,
/// so nothing here stubs out behaviour the operator depends on.
class InspectionHarness {
  final FakeSessionsRepository sessions = FakeSessionsRepository();
  final FakeResultsRepository results = FakeResultsRepository();
  final FakeFaultsRepository faults = FakeFaultsRepository();
  final FakeReportsRepository reports = FakeReportsRepository();
  final FakePmcsEntityPort entityPort = FakePmcsEntityPort();
  final FakeMeshBroadcaster meshPort = FakeMeshBroadcaster();
  final FakeQueueWorker queueWorker = FakeQueueWorker();
  final FakeSpeechRecognition speech = FakeSpeechRecognition();

  /// `B-BRK-01` is the one critical item, so its worst condition grades RED X
  /// while every other item's tops out at CIRCLE X.
  final FakeFaultClassifier classifier =
      FakeFaultClassifier(criticalIds: const {'B-BRK-01'});

  final FakeProfileRepository profiles;
  final FakeCatalogSource catalogSource;
  late final InspectionViewModel viewModel;

  /// The scanner the view model was actually wired to — [cacScanner] unless a
  /// test supplied its own.
  final CacScannerStrategy scanner;

  /// The in-memory scanner most tests drive outcomes through. A test that
  /// injected its own holds that object already and has no use for this.
  FakeCacScanner get cacScanner => scanner as FakeCacScanner;

  /// [scanner] replaces [cacScanner] in the wiring, for the one thing the
  /// fake cannot do: hand back a capture that never completes. The cancel
  /// path and the generation guard both only mean anything while a scan is
  /// still in flight, so without this they are untestable.
  InspectionHarness({
    Profile? profile = testProfile,
    Map<VehicleType, PmcsCatalog>? catalogs,
    CacScannerStrategy? scanner,
  })  : profiles = FakeProfileRepository(profile),
        catalogSource = FakeCatalogSource(catalogs),
        scanner = scanner ?? FakeCacScanner() {
    final fixedClock = FixedClock(DateTime.utc(2026, 3, 24, 7));

    viewModel = InspectionViewModel(
      catalogSource: catalogSource,
      startSession: StartSession(
        repository: sessions,
        locationRepository: FakeLocationRepository(const LatLng(33, -84)),
        clock: fixedClock,
        idGenerator: FakeIdGenerator(const ['session-1']),
      ),
      loadOpenSessions: LoadOpenSessions(sessions),
      recordCheckResult: RecordCheckResult(
        repository: results,
        classifier: classifier,
        clock: fixedClock,
      ),
      completePhase: CompletePhase(
        sessionsRepository: sessions,
        faultsRepository: faults,
      ),
      abandonSession: AbandonSession(
        sessionsRepository: sessions,
        resultsRepository: results,
        faultsRepository: faults,
      ),
      submitSession: SubmitSession(
        sessionsRepository: sessions,
        faultsRepository: faults,
        reportsRepository: reports,
        buildSessionReport: BuildSessionReport(fixedClock),
        clock: fixedClock,
      ),
      publishPmcsReport: PublishPmcsReport(
        entityPort: entityPort,
        meshPort: meshPort,
        queueWorker: queueWorker,
        codec: FakeReportCodec(),
        clock: fixedClock,
      ),
      resultsRepository: results,
      faultsRepository: faults,
      speechStrategy: speech,
      verifyOperatorIdentity: VerifyOperatorIdentity(
        scanner: this.scanner,
        parseBarcode: ParseCacBarcode(fixedClock),
      ),
      cacScanner: this.scanner,
      profileRepository: profiles,
    );
  }

  /// Registers everything the inspection pages pull out of getIt.
  void register() {
    getIt.registerLazySingleton<InspectionViewModel>(() => viewModel);
    getIt.registerLazySingleton<FaultClassifierStrategy>(() => classifier);
  }

  /// Profile + open sessions, the same call `InspectionFlowPage` makes.
  Future<void> load() => viewModel.load();

  /// Loads, then starts a walk-around on the default Stryker catalog.
  Future<void> begin({
    String bumperNumber = 'A-11',
    String uic = 'WJ8TAA',
  }) async {
    await load();
    await viewModel.beginSession(bumperNumber: bumperNumber, uic: uic);
  }

  /// Starts a walk-around and opens [phase] for inspection.
  Future<void> beginPhase(PmcsPhase phase) async {
    await begin();
    await viewModel.openPhase(phase);
  }

  /// Walks every phase to the end and lands on the summary, which is where
  /// the sign-off gate lives. Answers index 0 — serviceable — throughout, so
  /// the PMCS is clean unless a test says otherwise.
  Future<void> walkToSummary() async {
    await begin();
    for (final phase in PmcsPhase.values) {
      await viewModel.openPhase(phase);
      for (final item in viewModel.phaseItems) {
        await viewModel.answer(item, 0);
      }
      await viewModel.completeActivePhase();
    }
  }
}

/// Clears the singleton snack bar queue so a message enqueued by one test
/// cannot surface in the next one.
void clearSnackBars() => SnackBarService.instance.queue.clear();
