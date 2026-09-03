import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/parsedRecoveryRequest.dart';

import 'package:recovery_ops/domain/entities/publishResult.dart';
import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/entities/recoveryRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';
import 'package:recovery_ops/domain/services/queueWorkerStrategy.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/domain/services/speechRecognitionStrategy.dart';
import 'package:recovery_ops/domain/services/transcriptParserStrategy.dart';
import 'package:recovery_ops/domain/usecases/recovery/publishRecoveryRequest.dart';
import 'package:recovery_ops/domain/usecases/reporting/submitOutgoingReport.dart';
import 'package:recovery_ops/presentation/common/widgets/customSnackBar.dart';
import 'package:recovery_ops/presentation/recovery/recoveryViewModel.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';

class FakeSpeechRecognition implements SpeechRecognitionStrategy {
  bool startCalled = false;
  bool stopCalled = false;
  void Function(String text)? capturedOnResult;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {
    startCalled = true;
    capturedOnResult = onResult;
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
  }

  void simulateResult(String text) {
    capturedOnResult?.call(text);
  }
}

class FakeTranscriptParser implements TranscriptParserStrategy {
  ParsedRecoveryRequest? nextResult;
  String? lastTranscript;

  @override
  Future<ParsedRecoveryRequest> parse(String transcript) async {
    lastTranscript = transcript;
    return nextResult ??
        ParsedRecoveryRequest(
          bumperNumber: transcript.split(' ').first,
          issue: transcript.split(' ').skip(1).join(' '),
        );
  }
}

class FakeMapService implements sdk.MapService {
  final List<String> addedMarkerLabels = [];
  final List<sdk.LatLng> flyToLocations = [];
  int markerCounter = 0;

  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label, String? color, sdk.MarkerIcon? icon, sdk.MarkerDisposition? disposition}) async {
    addedMarkerLabels.add(label ?? '');
    return 'marker-${markerCounter++}';
  }

  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {
    flyToLocations.add(location);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReportsRepository implements ReportsRepository {
  final List<RecoveryReport> stored = [];
  int insertCallCount = 0;

  @override
  Future<void> insertReport(RecoveryReport report) async {
    insertCallCount++;
    stored.add(report);
  }

  @override
  Future<List<RecoveryReport>> getAllReports() async => [];
  @override
  Future<void> markAsRead(int id) async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {}
  @override
  Future<void> clearNavigatorLocation(int id) async {}
  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {}
  @override
  Future<void> deleteReport(int id) async {}
}

class _NoopEntityPort implements RecoveryEntityPort {
  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async => true;

  @override
  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async => true;

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async => true;
}

class _NoopMeshPort implements MeshBroadcasterPort {
  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async => true;

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async => true;

  @override
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {}

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {}
}

class _NoopQueueWorker implements QueueWorkerStrategy {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> enqueue(QueuedRequest request) async {}
  @override
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  }) {}
}

class FakePublishRecoveryRequest extends PublishRecoveryRequest {
  int publishCount = 0;
  PublishResult outcome = const PublishResult(latticeOk: true, meshOk: true);

  FakePublishRecoveryRequest()
      : super(
          entityPort: _NoopEntityPort(),
          meshPort: _NoopMeshPort(),
          queueWorker: _NoopQueueWorker(),
        );

  @override
  Future<PublishResult> call({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required RecoveryType type,
    required LatLng position,
  }) async {
    publishCount++;
    return outcome;
  }
}

class FakeReportsViewModel extends ChangeNotifier implements ReportsViewModel {
  @override
  final List<RecoveryReport> reports = [];
  @override
  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeSpeechRecognition fakeSpeech;
  late FakeTranscriptParser fakeParser;
  late FakeMapService fakeMap;
  late FakeReportsRepository fakeRepo;
  late FakePublishRecoveryRequest fakePublish;
  late FakeReportsViewModel fakeReportsVm;
  late SnackBarService snackBarService;
  late RecoveryViewModel vm;

  setUp(() {
    fakeSpeech = FakeSpeechRecognition();
    fakeParser = FakeTranscriptParser();
    fakeMap = FakeMapService();
    fakeRepo = FakeReportsRepository();
    fakePublish = FakePublishRecoveryRequest();
    fakeReportsVm = FakeReportsViewModel();
    snackBarService = SnackBarService.instance;
    snackBarService.queue.clear();
    vm = RecoveryViewModel(
      fakeSpeech,
      fakeParser,
      submitOutgoingReport: SubmitOutgoingReport(fakeRepo),
      mapService: fakeMap,
      publishRecoveryRequest: fakePublish,
      reportsViewModel: fakeReportsVm,
      snackBarService: snackBarService,
    );
  });

  test('initial selectedType is towBar', () {
    expect(vm.selectedType, RecoveryType.towBar);
  });

  test('initial isListening is false', () {
    expect(vm.isListening, isFalse);
  });

  test('selectType updates selectedType and notifies', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.selectType(RecoveryType.wrecker);

    expect(vm.selectedType, RecoveryType.wrecker);
    expect(notifyCount, 1);
  });

  test('validate returns false and enqueues snackbar for empty bumper', () {
    final result = vm.validate('', 'Flat tire');

    expect(result, isFalse);
    expect(snackBarService.queue.length, 1);
    expect(snackBarService.queue.first.message, 'Bumper number and issue are required');
    expect(snackBarService.queue.first.isError, isTrue);
  });

  test('validate returns false and enqueues snackbar for empty issue', () {
    final result = vm.validate('HQ-42', '');

    expect(result, isFalse);
    expect(snackBarService.queue.length, 1);
  });

  test('validate returns false for whitespace-only input', () {
    final result = vm.validate('   ', '   ');

    expect(result, isFalse);
    expect(snackBarService.queue.length, 1);
  });

  test('validate returns true for valid input', () {
    final result = vm.validate('HQ-42', 'Flat tire');

    expect(result, isTrue);
    expect(snackBarService.queue, isEmpty);
  });

  test('validate does not notify on failure', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.validate('', '');

    expect(notifyCount, 0);
  });

  test('validate does not notify on success', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.validate('HQ-42', 'Flat tire');

    expect(notifyCount, 0);
  });

  test('onSubmitSuccess resets type', () {
    vm.selectType(RecoveryType.wrecker);

    vm.onSubmitSuccess();

    expect(vm.selectedType, RecoveryType.towBar);
  });

  test('onSubmitSuccess notifies listeners', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.onSubmitSuccess();

    expect(notifyCount, 1);
  });

  test('onSubmitSuccess does not enqueue snackbar', () {
    vm.onSubmitSuccess();
    expect(snackBarService.queue, isEmpty);
  });

  group('addOutgoingReport', () {
    test('inserts report into reportsViewModel.reports', () async {
      await vm.addOutgoingReport(
        entityId: 'entity-1',
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        recoveryType: 'Wrecker',
        latitude: 33.0,
        longitude: -84.0,
      );
      expect(fakeReportsVm.reports.length, 1);
      expect(fakeReportsVm.reports.first.bumperNumber, 'HQ-42');
    });

    test('sets fromCallsign to You', () async {
      await vm.addOutgoingReport(
        entityId: '',
        bumperNumber: 'HQ-42',
        issue: 'flat',
        recoveryType: 'Wrecker',
        latitude: 0,
        longitude: 0,
      );
      expect(fakeReportsVm.reports.first.fromCallsign, 'You');
    });

    test('marks report as outgoing and read', () async {
      await vm.addOutgoingReport(
        entityId: '',
        bumperNumber: 'HQ-42',
        issue: 'flat',
        recoveryType: 'Wrecker',
        latitude: 0,
        longitude: 0,
      );
      expect(fakeReportsVm.reports.first.isOutgoing, isTrue);
      expect(fakeReportsVm.reports.first.isRead, isTrue);
    });

    test('persists to repository', () async {
      await vm.addOutgoingReport(
        entityId: '',
        bumperNumber: 'HQ-42',
        issue: 'flat',
        recoveryType: 'Wrecker',
        latitude: 0,
        longitude: 0,
      );
      expect(fakeRepo.insertCallCount, 1);
    });
  });

  group('submitRecoveryRequest', () {
    test('adds outgoing report to reportsViewModel', () async {
      await vm.submitRecoveryRequest(
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        type: RecoveryType.towBar,
        position: const LatLng(33.0, -84.0),
      );
      expect(fakeReportsVm.reports.length, 1);
      expect(fakeReportsVm.reports.first.bumperNumber, 'HQ-42');
      expect(fakeReportsVm.reports.first.recoveryType, 'Tow Bar');
      expect(fakeReportsVm.reports.first.isOutgoing, isTrue);
    });

    test('uses Wrecker label for wrecker type', () async {
      await vm.submitRecoveryRequest(
        bumperNumber: 'BR-07',
        issue: 'engine failure',
        type: RecoveryType.wrecker,
        position: const LatLng(33.0, -84.0),
      );
      expect(fakeReportsVm.reports.first.recoveryType, 'Wrecker');
    });

    test('flies to position', () async {
      await vm.submitRecoveryRequest(
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        type: RecoveryType.towBar,
        position: const LatLng(33.0, -84.0),
      );
      expect(fakeMap.flyToLocations.any((l) => l.latitude == 33.0), isTrue);
    });

    test('calls publishRecoveryRequest use case', () async {
      await vm.submitRecoveryRequest(
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        type: RecoveryType.towBar,
        position: const LatLng(33.0, -84.0),
      );
      await Future.delayed(Duration.zero);
      expect(fakePublish.publishCount, 1);
    });

    test('emits per-leg snackbars on success', () async {
      snackBarService.queue.clear();
      await vm.submitRecoveryRequest(
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        type: RecoveryType.towBar,
        position: const LatLng(33.0, -84.0),
      );
      await Future.delayed(Duration.zero);
      final messages = snackBarService.queue.map((s) => s.message).toList();
      expect(messages, contains('Lattice: passed'));
      expect(messages, contains('Mesh: passed'));
    });

    test('persists report to repository', () async {
      await vm.submitRecoveryRequest(
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        type: RecoveryType.towBar,
        position: const LatLng(33.0, -84.0),
      );
      expect(fakeRepo.insertCallCount, 1);
    });
  });

  test('parseTranscript delegates to parser strategy', () async {
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      recoveryType: RecoveryType.wrecker,
    );

    await vm.parseTranscript('anything');

    expect(fakeParser.lastTranscript, 'anything');
    expect(vm.bumperResult, 'HQ-42');
    expect(vm.issueResult, 'flat tire');
    expect(vm.selectedType, RecoveryType.wrecker);
  });

  test('parseTranscript does not change selectedType when parser returns null type', () async {
    vm.selectType(RecoveryType.wrecker);
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
    );

    await vm.parseTranscript('HQ-42 flat tire');

    expect(vm.selectedType, RecoveryType.wrecker);
    expect(vm.typeResult, isNull);
  });

  test('parseTranscript sets tow bar type', () async {
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: 'BR-07',
      issue: 'engine failure',
      recoveryType: RecoveryType.towBar,
    );

    await vm.parseTranscript('BR-07 engine failure tow bar');

    expect(vm.selectedType, RecoveryType.towBar);
  });

  test('parseTranscript notifies listeners', () async {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    await vm.parseTranscript('HQ-42 flat tire');

    expect(notifyCount, 1);
  });

  test('startListening sets isListening true and calls strategy', () async {
    await vm.startListening();

    expect(vm.isListening, isTrue);
    expect(fakeSpeech.startCalled, isTrue);
  });

  test('stopListening sets isListening false and calls strategy', () async {
    await vm.startListening();
    await vm.stopListening();

    expect(vm.isListening, isFalse);
    expect(fakeSpeech.stopCalled, isTrue);
  });

  test('speech result parses transcript via strategy', () async {
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
    );

    await vm.startListening();
    fakeSpeech.simulateResult('HQ-42 flat tire');

    await Future.delayed(Duration.zero);

    expect(vm.isListening, isFalse);
    expect(vm.bumperResult, 'HQ-42');
    expect(vm.issueResult, 'flat tire');
  });

  test('isParsing is false after speech result completes', () async {
    await vm.startListening();
    fakeSpeech.simulateResult('HQ-42 flat tire');

    await Future.delayed(Duration.zero);

    expect(vm.isParsing, isFalse);
  });

  test('initial isParsing is false', () {
    expect(vm.isParsing, isFalse);
  });

  test('toggleListening starts when not listening', () async {
    await vm.toggleListening();

    expect(vm.isListening, isTrue);
    expect(fakeSpeech.startCalled, isTrue);
  });

  test('toggleListening stops when already listening', () async {
    await vm.startListening();
    await vm.toggleListening();

    expect(vm.isListening, isFalse);
    expect(fakeSpeech.stopCalled, isTrue);
  });

  test('initial bumperResult is null', () {
    expect(vm.bumperResult, isNull);
  });

  test('initial issueResult is null', () {
    expect(vm.issueResult, isNull);
  });

  test('initial typeResult is null', () {
    expect(vm.typeResult, isNull);
  });

  test('validate with bumper empty and issue non-empty fails', () {
    expect(vm.validate('', 'some issue'), isFalse);
    expect(snackBarService.queue.length, 1);
  });

  test('validate with tab characters treats as whitespace', () {
    expect(vm.validate('\t', '\t'), isFalse);
    expect(snackBarService.queue.length, 1);
  });

  test('selectType back and forth preserves last selection', () {
    vm.selectType(RecoveryType.wrecker);
    vm.selectType(RecoveryType.towBar);
    vm.selectType(RecoveryType.wrecker);
    expect(vm.selectedType, RecoveryType.wrecker);
  });

  test('parseTranscript stores bumperResult and issueResult', () async {
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: 'ZZ-99',
      issue: 'engine overheating',
    );
    await vm.parseTranscript('ZZ-99 engine overheating');

    expect(vm.bumperResult, 'ZZ-99');
    expect(vm.issueResult, 'engine overheating');
  });

  test('parseTranscript with empty bumper from parser', () async {
    fakeParser.nextResult = const ParsedRecoveryRequest(
      bumperNumber: '',
      issue: 'flat tire',
    );
    await vm.parseTranscript('flat tire');

    expect(vm.bumperResult, '');
    expect(vm.issueResult, 'flat tire');
  });

  test('startListening notifies listeners', () async {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);
    await vm.startListening();
    expect(notifyCount, 1);
  });

  test('stopListening notifies listeners', () async {
    await vm.startListening();
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);
    await vm.stopListening();
    expect(notifyCount, 1);
  });
}
