import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/location_repo.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
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

import '../support/cac_fixtures.dart';
import '../support/fakes.dart';

/// Fails every call, to prove a thrown repository never latches the UI.
class ThrowingSessionsRepository extends FakeSessionsRepository {
  @override
  Future<PmcsSession> insert(PmcsSession session) async {
    throw StateError('database unavailable');
  }

  @override
  Future<List<PmcsSession>> getOpenSessions() async {
    throw StateError('database unavailable');
  }
}

/// Throws the way the host location bridge can when it is not just slow.
class ThrowingLocationRepository implements LocationRepository {
  @override
  Future<LatLng?> getCurrentLocation() async {
    throw StateError('location bridge failed');
  }
}

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

class FakeCatalogSource implements PmcsCatalogSource {
  final Map<VehicleType, PmcsCatalog> catalogs;

  FakeCatalogSource([Map<VehicleType, PmcsCatalog>? catalogs])
      : catalogs = catalogs ?? const {VehicleType.stryker: testCatalog};

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

void main() {
  late FakeSessionsRepository sessions;
  late FakeResultsRepository resultsRepo;
  late FakeFaultsRepository faultsRepo;
  late FakeReportsRepository reportsRepo;
  late FakeProfileRepository profileRepo;
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late FakeQueueWorker queueWorker;
  late FakeSpeechRecognition speech;
  late FakeCacScanner cacScanner;
  late InspectionViewModel viewModel;

  final clock = FixedClock(DateTime.utc(2026, 3, 24, 7));

  setUp(() {
    SnackBarService.instance.queue.clear();

    sessions = FakeSessionsRepository();
    resultsRepo = FakeResultsRepository();
    faultsRepo = FakeFaultsRepository();
    reportsRepo = FakeReportsRepository();
    profileRepo = FakeProfileRepository(const Profile(uic: 'WJ8TAA'));
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    queueWorker = FakeQueueWorker();
    speech = FakeSpeechRecognition();
    cacScanner = FakeCacScanner();

    viewModel = InspectionViewModel(
      catalogSource: FakeCatalogSource(),
      startSession: StartSession(
        repository: sessions,
        locationRepository: FakeLocationRepository(const LatLng(33, -84)),
        clock: clock,
        idGenerator: FakeIdGenerator(['session-1']),
      ),
      loadOpenSessions: LoadOpenSessions(sessions),
      recordCheckResult: RecordCheckResult(
        repository: resultsRepo,
        classifier: FakeFaultClassifier(criticalIds: const {'B-BRK-01'}),
        clock: clock,
      ),
      completePhase: CompletePhase(
        sessionsRepository: sessions,
        faultsRepository: faultsRepo,
      ),
      abandonSession: AbandonSession(
        sessionsRepository: sessions,
        resultsRepository: resultsRepo,
        faultsRepository: faultsRepo,
      ),
      submitSession: SubmitSession(
        sessionsRepository: sessions,
        faultsRepository: faultsRepo,
        reportsRepository: reportsRepo,
        buildSessionReport: BuildSessionReport(clock),
        clock: clock,
      ),
      publishPmcsReport: PublishPmcsReport(
        entityPort: entityPort,
        meshPort: meshPort,
        queueWorker: queueWorker,
        codec: FakeReportCodec(),
        clock: clock,
      ),
      resultsRepository: resultsRepo,
      faultsRepository: faultsRepo,
      speechStrategy: speech,
      verifyOperatorIdentity: VerifyOperatorIdentity(
        scanner: cacScanner,
        parseBarcode: ParseCacBarcode(clock),
      ),
      cacScanner: cacScanner,
      profileRepository: profileRepo,
    );
  });

  Future<void> begin() async {
    await viewModel.load();
    await viewModel.beginSession(
      bumperNumber: 'A-11',
      uic: 'WJ8TAA',
    );
  }

  group('walking a known vehicle again', () {
    test('a vehicle handed over from a report is queued for the setup fields',
        () async {
      await viewModel.load();

      final accepted = viewModel.prefillVehicle(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: VehicleType.jltv,
      );

      expect(accepted, isTrue);
      expect(viewModel.selectedVehicle, VehicleType.jltv);
      expect(viewModel.pendingPrefill?.bumperNumber, 'B-22');
      expect(viewModel.pendingPrefill?.uic, 'WAB4C0');
    });

    test('the hand-over is consumed once, so an edit is not overwritten',
        () async {
      await viewModel.load();
      viewModel.prefillVehicle(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: VehicleType.stryker,
      );

      expect(viewModel.takePrefill()?.bumperNumber, 'B-22');
      expect(viewModel.takePrefill(), isNull);
      expect(viewModel.pendingPrefill, isNull);
    });

    test('is refused while another walk-around is open', () async {
      await viewModel.load();
      await viewModel.beginSession(bumperNumber: 'A-11', uic: 'WJ8TAA');
      expect(viewModel.stage, isNot(InspectionStage.setup));

      final accepted = viewModel.prefillVehicle(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: VehicleType.jltv,
      );

      expect(accepted, isFalse);
      expect(viewModel.pendingPrefill, isNull);
      // The open session's vehicle is left exactly as it was.
      expect(viewModel.session?.bumperNumber, 'A-11');
    });
  });

  group('setup', () {
    test('opens on the first supported platform', () {
      expect(viewModel.stage, InspectionStage.setup);
      expect(viewModel.selectedVehicle, VehicleType.stryker);
    });

    test('load pulls the profile and any open sessions', () async {
      await sessions.insert(buildSession(sessionId: 'open-1'));

      await viewModel.load();

      expect(viewModel.profile?.uic, 'WJ8TAA');
      expect(viewModel.openSessions, hasLength(1));
      expect(viewModel.isBusy, isFalse);
    });

    test('an empty bumper number is refused with a reason', () async {
      await viewModel.load();

      final started = await viewModel.beginSession(
        bumperNumber: '  ',
        uic: 'WJ8TAA',
      );

      expect(started, isFalse);
      expect(viewModel.stage, InspectionStage.setup);
      expect(SnackBarService.instance.queue, isNotEmpty);
    });

    test('an empty UIC is refused', () async {
      await viewModel.load();

      expect(
        await viewModel.beginSession(bumperNumber: 'A-11', uic: ''),
        isFalse,
      );
    });

    test('beginning a session carries the UIC and names nobody yet', () async {
      await begin();

      expect(viewModel.stage, InspectionStage.phaseSelect);
      expect(viewModel.session?.uic, 'WJ8TAA');
      // The CAC scanned at sign-off is what names the operator.
      expect(viewModel.session?.operator, '');
      expect(viewModel.catalog?.vehicleType, VehicleType.stryker);
    });

    test('selecting a platform is remembered', () async {
      viewModel.selectVehicle(VehicleType.stryker);

      expect(viewModel.selectedVehicle, VehicleType.stryker);
    });
  });

  group('resume', () {
    test('a resumed session reloads its faults and lands on phase select',
        () async {
      final open = await sessions.insert(
        buildSession(completedPhases: const [PmcsPhase.before]),
      );
      await faultsRepo.replacePhaseFaults(
        'session-1',
        [buildFault(severity: FaultSeverity.redX)],
        phaseWireName: PmcsPhase.before.wireName,
      );

      await viewModel.resumeSession(open);

      expect(viewModel.stage, InspectionStage.phaseSelect);
      expect(viewModel.sessionFaults, hasLength(1));
      expect(viewModel.sessionTally.isDeadlined, isTrue);
    });

    test('a session for a platform this build lacks is refused, not opened',
        () async {
      final open = buildSession(vehicleType: VehicleType.jltv);

      await viewModel.resumeSession(open);

      expect(viewModel.stage, InspectionStage.setup);
      expect(viewModel.session, isNull);
      expect(SnackBarService.instance.queue.last.isError, isTrue);
    });
  });

  group('answering checks', () {
    test('opening a phase loads the checks and targets the first one',
        () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);

      expect(viewModel.stage, InspectionStage.inspecting);
      expect(viewModel.totalCount, 2);
      expect(viewModel.answeredCount, 0);
      expect(viewModel.consumePendingScroll(), 'B-BRK-01');
    });

    test('answering advances the target to the next unanswered check',
        () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      viewModel.consumePendingScroll();

      await viewModel.answer(brakeFluid, 0);

      expect(viewModel.answeredCount, 1);
      expect(viewModel.consumePendingScroll(), 'B-BRK-02');
    });

    test('answering the last check targets nothing further', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 0);
      await viewModel.answer(parkingBrake, 0);

      expect(viewModel.consumePendingScroll(), isNull);
      expect(viewModel.isPhaseComplete, isTrue);
    });

    test('an answered check collapses, and can be reopened', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 0);

      expect(viewModel.collapsedItemIds, contains('B-BRK-01'));

      viewModel.expandItem('B-BRK-01');
      expect(viewModel.collapsedItemIds, isNot(contains('B-BRK-01')));

      viewModel.collapseItem('B-BRK-01');
      expect(viewModel.collapsedItemIds, contains('B-BRK-01'));
    });

    test('every answer is written through immediately', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 2);

      final stored =
          await resultsRepo.getResults('session-1', PmcsPhase.before);
      expect(stored['B-BRK-01']?.faultLabel, 'Empty');
    });

    test('a critical check at the worst tier grades RED X', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 3);

      expect(viewModel.phaseTally.redX, 1);
      expect(viewModel.phaseTally.isDeadlined, isTrue);
    });

    test('a serviceable answer contributes no severity', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 0);

      expect(viewModel.phaseTally.isEmpty, isTrue);
    });

    test('re-answering replaces rather than stacks', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 3);
      await viewModel.answer(brakeFluid, 0);

      expect(viewModel.answeredCount, 1);
      expect(viewModel.phaseTally.isEmpty, isTrue);
    });

    test('reopening a phase folds away what was already answered', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 1);
      viewModel.backToPhases();

      await viewModel.openPhase(PmcsPhase.before);

      expect(viewModel.answeredCount, 1);
      expect(viewModel.collapsedItemIds, {'B-BRK-01'});
      expect(viewModel.consumePendingScroll(), 'B-BRK-02');
    });

    test('answering with no session open is a no-op, not a crash', () async {
      await viewModel.answer(brakeFluid, 1);

      expect(viewModel.results, isEmpty);
    });
  });

  group('dictated notes', () {
    test('a dictated note is attached to the existing answer', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 2);

      await viewModel.toggleNoteDictation(brakeFluid);
      expect(viewModel.isListening, isTrue);
      expect(viewModel.listeningItemId, 'B-BRK-01');

      await speech.deliver('reservoir bone dry');

      expect(viewModel.isListening, isFalse);
      expect(viewModel.results['B-BRK-01']?.note, 'reservoir bone dry');
    });

    test('the note survives to the stored result', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 2);
      await viewModel.toggleNoteDictation(brakeFluid);
      await speech.deliver('reservoir bone dry');

      final stored =
          await resultsRepo.getResults('session-1', PmcsPhase.before);
      expect(stored['B-BRK-01']?.note, 'reservoir bone dry');
    });

    test('calling the component serviceable retires its note', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 2);
      await viewModel.toggleNoteDictation(brakeFluid);
      await speech.deliver('reservoir bone dry');

      await viewModel.answer(brakeFluid, 0);

      expect(viewModel.results['B-BRK-01']?.note, isNull);
    });

    test('tapping the mic again stops listening', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 1);

      await viewModel.toggleNoteDictation(brakeFluid);
      await viewModel.toggleNoteDictation(brakeFluid);

      expect(viewModel.isListening, isFalse);
      expect(speech.stopCalls, 1);
    });

    test('an empty transcript leaves the answer alone', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 1);
      await viewModel.toggleNoteDictation(brakeFluid);
      await speech.deliver('   ');

      expect(viewModel.results['B-BRK-01']?.note, isNull);
    });
  });

  group('completing phases', () {
    test('completing a phase stores its faults and returns to phase select',
        () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 3);
      await viewModel.answer(parkingBrake, 0);

      await viewModel.completeActivePhase();

      expect(viewModel.stage, InspectionStage.phaseSelect);
      expect(viewModel.session!.isPhaseComplete(PmcsPhase.before), isTrue);
      expect(viewModel.sessionFaults, hasLength(1));
      expect(viewModel.sessionTally.redX, 1);
    });

    test('the working answers are cleared once the phase is closed', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 0);
      await viewModel.answer(parkingBrake, 0);
      await viewModel.completeActivePhase();

      expect(viewModel.results, isEmpty);
      expect(viewModel.activePhase, isNull);
    });

    test('closing the last phase goes straight to the summary', () async {
      await begin();
      for (final phase in PmcsPhase.values) {
        await viewModel.openPhase(phase);
        for (final item in viewModel.phaseItems) {
          await viewModel.answer(item, 0);
        }
        await viewModel.completeActivePhase();
      }

      expect(viewModel.stage, InspectionStage.summary);
      expect(viewModel.session!.allPhasesComplete, isTrue);
    });

    test('faults accumulate across phases', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 3);
      await viewModel.answer(parkingBrake, 0);
      await viewModel.completeActivePhase();

      await viewModel.openPhase(PmcsPhase.during);
      await viewModel.answer(tirePressure, 1);
      await viewModel.completeActivePhase();

      expect(viewModel.sessionFaults, hasLength(2));
      expect(viewModel.sessionTally.redX, 1);
      expect(viewModel.sessionTally.dash, 1);
    });

    test('backToPhases drops the working answers without closing the phase',
        () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 1);

      viewModel.backToPhases();

      expect(viewModel.stage, InspectionStage.phaseSelect);
      expect(viewModel.session!.isPhaseComplete(PmcsPhase.before), isFalse);
    });
  });

  group('submitting', () {
    Future<void> completeEverything() async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 3);
      await viewModel.answer(parkingBrake, 0);
      await viewModel.completeActivePhase();
      await viewModel.openPhase(PmcsPhase.during);
      await viewModel.answer(tirePressure, 0);
      await viewModel.completeActivePhase();
      await viewModel.openPhase(PmcsPhase.after);
      await viewModel.answer(coolDown, 0);
      await viewModel.completeActivePhase();
    }

    /// Walks the PMCS out and signs it with a readable CAC, which is the only
    /// state an ordinary submit is reachable from.
    Future<void> completeAndSign() async {
      await completeEverything();
      cacScanner.willRead(cacBarcode());
      await viewModel.scanCac();
    }

    test('the report is stored before anything goes on the wire', () async {
      await completeAndSign();

      await viewModel.submit();

      expect(reportsRepo.reports, hasLength(1));
      expect(reportsRepo.reports.single.isDeadlined, isTrue);
    });

    test('the operator is shown a receipt without waiting on the net',
        () async {
      await completeAndSign();

      await viewModel.submit();

      expect(viewModel.stage, InspectionStage.submitted);
      expect(viewModel.session, isNull);
      expect(viewModel.isBusy, isFalse);
    });

    test('both transports are attempted', () async {
      await completeAndSign();
      await viewModel.submit();
      await Future<void>.delayed(Duration.zero);

      expect(entityPort.published, hasLength(1));
      expect(meshPort.broadcast, hasLength(1));
    });

    test('a downed transport queues instead of blocking the operator',
        () async {
      entityPort.publishSucceeds = false;
      await completeAndSign();

      await viewModel.submit();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.stage, InspectionStage.submitted);
      expect(queueWorker.enqueued, hasLength(1));
    });

    test('the submitted session no longer shows as open', () async {
      await completeAndSign();

      await viewModel.submit();

      expect(viewModel.openSessions, isEmpty);
    });

    test('submitting with no session is a no-op', () async {
      await viewModel.submit();

      expect(reportsRepo.reports, isEmpty);
    });

    test('an unscanned PMCS cannot be submitted', () async {
      await completeEverything();

      await viewModel.submit();

      expect(reportsRepo.reports, isEmpty);
      expect(viewModel.stage, InspectionStage.summary);
      expect(SnackBarService.instance.queue.last.isError, isTrue);
    });

    test('the scanned Soldier is stamped on the report and the session',
        () async {
      await completeAndSign();

      await viewModel.submit();

      final report = reportsRepo.reports.single;
      expect(report.isSignatureVerified, isTrue);
      expect(report.signature!.identity!.edipi, '1087987498');
      expect(report.operator, 'SGT SMITH, JOHN A');
      // Each closed phase updates the session too, so the signed one is last.
      expect(sessions.updated.last.signature!.isVerified, isTrue);
    });

    test('a refused scan blocks the ordinary submit but offers the override',
        () async {
      await completeEverything();
      cacScanner.willFail(CacRejection.noCamera);
      await viewModel.scanCac();

      expect(viewModel.isSignedOff, isFalse);
      expect(viewModel.canSubmitUnverified, isTrue);

      await viewModel.submit();
      expect(reportsRepo.reports, isEmpty);
    });

    test('the override sends the PMCS marked unverified, with its reason',
        () async {
      await completeEverything();
      cacScanner.willFail(CacRejection.noCamera);
      await viewModel.scanCac();

      await viewModel.submitUnverified();

      final report = reportsRepo.reports.single;
      expect(report.isSignatureVerified, isFalse);
      expect(report.signature!.blockedBy, CacRejection.noCamera);
      expect(report.operator, 'UNVERIFIED');
      expect(viewModel.stage, InspectionStage.submitted);
    });

    test('the override is not reachable before a scan has been tried',
        () async {
      await completeEverything();

      expect(viewModel.canSubmitUnverified, isFalse);
      await viewModel.submitUnverified();

      expect(reportsRepo.reports, isEmpty);
    });

    test(
        'the typed fallback sends the PMCS unverified, with the name, the '
        'DoD ID and the reason the scan failed', () async {
      await completeEverything();
      cacScanner.willFail(CacRejection.codeUnreadable);
      await viewModel.scanCac();

      await viewModel.submitAttested(
        lastName: 'smith',
        firstName: 'john',
        edipi: '1087 987 498',
      );

      final report = reportsRepo.reports.single;
      expect(report.isSignatureVerified, isFalse);
      expect(report.operator, 'SMITH, JOHN');
      expect(report.signature!.method, 'typed');
      expect(report.signature!.dodId, '1087987498');
      expect(report.signature!.blockedBy, CacRejection.codeUnreadable);
      expect(viewModel.stage, InspectionStage.submitted);
    });

    test(
        'a typed entry that cannot be a Soldier is refused and nothing is '
        'stored', () async {
      await completeEverything();
      cacScanner.willFail(CacRejection.codeUnreadable);
      await viewModel.scanCac();

      await viewModel.submitAttested(
        lastName: 'SMITH',
        firstName: 'JOHN',
        edipi: '12345',
      );

      expect(reportsRepo.reports, isEmpty);
      expect(viewModel.canSubmitUnverified, isTrue);
    });

    test('the typed fallback is not reachable before a scan has been tried',
        () async {
      await completeEverything();

      await viewModel.submitAttested(
        lastName: 'SMITH',
        firstName: 'JOHN',
        edipi: '1087987498',
      );

      expect(reportsRepo.reports, isEmpty);
    });

    test('an expired CAC is refused rather than accepted', () async {
      await completeEverything();
      cacScanner.willRead(cacBarcode(expires: 'BBQH'));

      await viewModel.scanCac();

      expect(viewModel.isSignedOff, isFalse);
      expect(viewModel.lastScan!.rejection, CacRejection.expired);
    });

    test('a thrown scanner leaves the operator every way out they had',
        () async {
      await completeEverything();
      cacScanner.throwOnCapture = StateError('camera exploded');

      await viewModel.scanCac();

      expect(viewModel.isScanning, isFalse);
      expect(viewModel.isBusy, isFalse);
      expect(viewModel.canSubmitUnverified, isTrue);
    });

    test('a rescan replaces the previous result', () async {
      await completeEverything();
      cacScanner.willFail(CacRejection.noCodeFound);
      await viewModel.scanCac();
      expect(viewModel.isSignedOff, isFalse);

      cacScanner.willRead(cacBarcode());
      await viewModel.scanCac();

      expect(viewModel.isSignedOff, isTrue);
      expect(cacScanner.captureCalls, 2);
    });

    test('backing out to the phases drops the signature', () async {
      await completeAndSign();
      expect(viewModel.isSignedOff, isTrue);

      viewModel.backToPhases();

      // A signature is for the PMCS in front of the operator at the moment
      // they signed — it must not carry over a trip back through the checks.
      expect(viewModel.lastScan, isNull);
      expect(viewModel.isSignedOff, isFalse);
    });
  });

  group('discarding', () {
    test('a discarded session and its work are gone', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 1);

      await viewModel.discardSession();

      expect(viewModel.stage, InspectionStage.setup);
      expect(viewModel.session, isNull);
      expect(sessions.sessions, isEmpty);
      expect(viewModel.openSessions, isEmpty);
    });
  });

  group('failures never latch the UI', () {
    // Regression: isBusy was cleared only on the success path, so a throwing
    // repository left BEGIN PMCS and SUBMIT PMCS permanently disabled with no
    // message — unrecoverable without restarting the extension.

    InspectionViewModel buildWith({
      FakeSessionsRepository? sessionsRepository,
      LocationRepository? locationRepository,
    }) {
      final repo = sessionsRepository ?? sessions;
      return InspectionViewModel(
        catalogSource: FakeCatalogSource(),
        startSession: StartSession(
          repository: repo,
          locationRepository: locationRepository ??
              FakeLocationRepository(const LatLng(33, -84)),
          clock: clock,
          idGenerator: FakeIdGenerator(['session-1']),
        ),
        loadOpenSessions: LoadOpenSessions(repo),
        recordCheckResult: RecordCheckResult(
          repository: resultsRepo,
          classifier: FakeFaultClassifier(),
          clock: clock,
        ),
        completePhase: CompletePhase(
          sessionsRepository: repo,
          faultsRepository: faultsRepo,
        ),
        abandonSession: AbandonSession(
          sessionsRepository: repo,
          resultsRepository: resultsRepo,
          faultsRepository: faultsRepo,
        ),
        submitSession: SubmitSession(
          sessionsRepository: repo,
          faultsRepository: faultsRepo,
          reportsRepository: reportsRepo,
          buildSessionReport: BuildSessionReport(clock),
          clock: clock,
        ),
        publishPmcsReport: PublishPmcsReport(
          entityPort: entityPort,
          meshPort: meshPort,
          queueWorker: queueWorker,
          codec: FakeReportCodec(),
          clock: clock,
        ),
        resultsRepository: resultsRepo,
        faultsRepository: faultsRepo,
        speechStrategy: speech,
        verifyOperatorIdentity: VerifyOperatorIdentity(
          scanner: cacScanner,
          parseBarcode: ParseCacBarcode(clock),
        ),
        cacScanner: cacScanner,
        profileRepository: profileRepo,
      );
    }

    test('a failed start reports false and leaves the operator able to retry',
        () async {
      final vm = buildWith(sessionsRepository: ThrowingSessionsRepository());

      final started = await vm.beginSession(
        bumperNumber: 'A-11',
        uic: 'WJ8TAA',
      );

      expect(started, isFalse);
      expect(vm.isBusy, isFalse);
      expect(vm.stage, InspectionStage.setup);
      expect(SnackBarService.instance.queue.last.isError, isTrue);
    });

    test('a throwing location bridge does not lock the start button', () async {
      final vm = buildWith(locationRepository: ThrowingLocationRepository());

      await vm.beginSession(bumperNumber: 'A-11', uic: 'WJ8TAA');

      expect(vm.isBusy, isFalse);
    });

    test('a failed submit leaves the PMCS submittable', () async {
      await begin();
      await viewModel.openPhase(PmcsPhase.before);
      await viewModel.answer(brakeFluid, 0);
      await viewModel.answer(parkingBrake, 0);
      await viewModel.completeActivePhase();

      reportsRepo.failInsert = true;
      await viewModel.submit();

      expect(viewModel.isBusy, isFalse);
      expect(viewModel.session, isNotNull);
      expect(SnackBarService.instance.queue.last.isError, isTrue);
    });

    test('a failed phase open returns to phase select unlatched', () async {
      await begin();
      resultsRepo.failReads = true;

      await viewModel.openPhase(PmcsPhase.before);

      expect(viewModel.isBusy, isFalse);
      expect(viewModel.stage, InspectionStage.phaseSelect);
    });
  });
}
