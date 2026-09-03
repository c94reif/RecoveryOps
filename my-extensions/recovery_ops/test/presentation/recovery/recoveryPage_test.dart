import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/parsedRecoveryRequest.dart';
import 'package:recovery_ops/domain/entities/publishResult.dart';
import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/entities/recoveryRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';
import 'package:recovery_ops/domain/services/queueWorkerStrategy.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/domain/services/speechRecognitionStrategy.dart';
import 'package:recovery_ops/domain/services/transcriptParserStrategy.dart';
import 'package:recovery_ops/domain/usecases/recovery/publishRecoveryRequest.dart';
import 'package:recovery_ops/domain/usecases/reporting/submitOutgoingReport.dart';
import 'package:recovery_ops/presentation/common/widgets/customSnackBar.dart';
import 'package:recovery_ops/presentation/common/widgets/customTextField.dart';
import 'package:recovery_ops/presentation/common/widgets/customButton.dart';
import 'package:recovery_ops/presentation/recovery/recoveryViewModel.dart';
import 'package:recovery_ops/presentation/recovery/recoveryPage.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/appTheme.dart';

class FakeSpeechRecognition implements SpeechRecognitionStrategy {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {}

  @override
  Future<void> stopListening() async {}
}

class FakeTranscriptParser implements TranscriptParserStrategy {
  @override
  Future<ParsedRecoveryRequest> parse(String transcript) async {
    return ParsedRecoveryRequest(bumperNumber: '', issue: transcript);
  }
}

class FakeLocationRepository implements LocationRepository {
  @override
  Future<LatLng?> getCurrentLocation() async => const LatLng(33.0, -84.0);
}

class FakeMapService implements sdk.MapService {
  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label, String? color, sdk.MarkerIcon? icon, sdk.MarkerDisposition? disposition}) async => 'marker-1';
  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReportsRepository implements ReportsRepository {
  @override
  Future<void> insertReport(RecoveryReport report) async {}
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
  }) async => const PublishResult(latticeOk: true, meshOk: true);
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
  late FakeReportsViewModel fakeReportsVm;
  late FakeReportsRepository fakeRepo;
  late SnackBarService snackBarService;

  setUp(() async {
    await getIt.reset();
    fakeReportsVm = FakeReportsViewModel();
    fakeRepo = FakeReportsRepository();
    snackBarService = SnackBarService.instance;
    snackBarService.queue.clear();

    getIt.registerLazySingleton<ReportsViewModel>(() => fakeReportsVm);
    getIt.registerLazySingleton<LocationRepository>(
      () => FakeLocationRepository(),
    );
    getIt.registerLazySingleton<sdk.MapService>(() => FakeMapService());
    getIt.registerLazySingleton<PublishRecoveryRequest>(
      () => FakePublishRecoveryRequest(),
    );
    getIt.registerLazySingleton<SubmitOutgoingReport>(
      () => SubmitOutgoingReport(fakeRepo),
    );
    getIt.registerFactory<RecoveryViewModel>(
      () => RecoveryViewModel(
        FakeSpeechRecognition(),
        FakeTranscriptParser(),
        submitOutgoingReport: getIt<SubmitOutgoingReport>(),
        mapService: getIt<sdk.MapService>(),
        publishRecoveryRequest: getIt<PublishRecoveryRequest>(),
        reportsViewModel: getIt<ReportsViewModel>(),
        snackBarService: snackBarService,
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    snackBarService.queue.clear();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: CustomSnackBar(
        child: const Scaffold(
          body: RecoveryPage(),
        ),
      ),
    );
  }

  testWidgets('RecoveryPage renders all fields and submit button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.widgetWithText(CustomTextField, 'Bumper Number'), findsOneWidget);
    expect(find.widgetWithText(CustomTextField, 'Issue'), findsOneWidget);
    expect(find.text('Recovery Type'), findsOneWidget);
    expect(find.text('Tow Bar'), findsOneWidget);
    expect(find.text('Wrecker'), findsOneWidget);
    expect(find.widgetWithText(CustomButton, 'Submit Recovery Request'), findsOneWidget);
  });

  testWidgets('Icons are displayed in text fields', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);
  });

  testWidgets('Shows validation snackbar when both fields are empty', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pump();

    expect(find.text('Bumper number and issue are required'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Shows validation snackbar when bumper number is empty', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Issue'), 'Flat tire');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pump();

    expect(find.text('Bumper number and issue are required'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Shows validation snackbar when issue is empty', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Bumper Number'), 'HQ-42');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pump();

    expect(find.text('Bumper number and issue are required'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Submitting calls recoveryViewModel.submitRecoveryRequest with default Tow Bar', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Bumper Number'), 'HQ-42');
    await tester.enterText(find.widgetWithText(CustomTextField, 'Issue'), 'Flat tire');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(fakeReportsVm.reports.length, 1);
    expect(fakeReportsVm.reports.first.bumperNumber, 'HQ-42');
    expect(fakeReportsVm.reports.first.recoveryType, 'Tow Bar');
  });

  testWidgets('Submitting with Wrecker type passes correct payload', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Bumper Number'), 'BR-07');
    await tester.enterText(find.widgetWithText(CustomTextField, 'Issue'), 'Engine failure');
    await tester.pump();

    await tester.tap(find.text('Wrecker'));
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(fakeReportsVm.reports.length, 1);
    expect(fakeReportsVm.reports.first.recoveryType, 'Wrecker');
  });

  testWidgets('Fields clear after successful submit', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Bumper Number'), 'HQ-42');
    await tester.enterText(find.widgetWithText(CustomTextField, 'Issue'), 'Flat tire');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final bumperField = tester.widget<CustomTextField>(
      find.widgetWithText(CustomTextField, 'Bumper Number'),
    );
    final issueField = tester.widget<CustomTextField>(
      find.widgetWithText(CustomTextField, 'Issue'),
    );
    expect(bumperField.controller.text, isEmpty);
    expect(issueField.controller.text, isEmpty);
  });

  testWidgets('Whitespace-only input is treated as empty', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.widgetWithText(CustomTextField, 'Bumper Number'), '   ');
    await tester.enterText(find.widgetWithText(CustomTextField, 'Issue'), '   ');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Submit Recovery Request'));
    await tester.pump();

    expect(find.text('Bumper number and issue are required'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Mic buttons are rendered in each text field', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byIcon(Icons.mic_none), findsNWidgets(2));
  });

  testWidgets('Idle mic buttons are green outlined with no background', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    final iconButtons = tester
        .widgetList<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.mic_none),
            matching: find.byType(IconButton),
          ),
        )
        .toList();
    expect(iconButtons, hasLength(2));

    for (final btn in iconButtons) {
      final iconWidget = btn.icon as Icon;
      expect(iconWidget.icon, Icons.mic_none);
      expect(iconWidget.color, masterChiefGreen);

      final bg = btn.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(bg, Colors.transparent);
    }

    expect(find.byTooltip('Tap to record'), findsNWidgets(2));
    expect(find.byTooltip('Recording — tap to stop'), findsNothing);
  });

  testWidgets('Tapping mic switches it to red filled with red glow and updated tooltip',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    final bumperMic = find
        .ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(IconButton),
        )
        .first;
    await tester.tap(bumperMic);
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);

    final activeBtn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.mic),
        matching: find.byType(IconButton),
      ),
    );
    final activeIcon = activeBtn.icon as Icon;
    expect(activeIcon.color, const Color(0xFFE53935));

    final activeBg = activeBtn.style!.backgroundColor!.resolve(<WidgetState>{});
    expect(activeBg, const Color(0xFFE53935).withAlpha(38));

    expect(activeBtn.style!.shape!.resolve(<WidgetState>{}), isA<CircleBorder>());

    expect(find.byTooltip('Recording — tap to stop'), findsOneWidget);
    expect(find.byTooltip('Tap to record'), findsOneWidget);
  });

  testWidgets('Tapping the active mic again returns it to idle green', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    final initialMic = find
        .ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(IconButton),
        )
        .first;
    await tester.tap(initialMic);
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.tap(find.ancestor(
      of: find.byIcon(Icons.mic),
      matching: find.byType(IconButton),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNWidgets(2));
    expect(find.byTooltip('Recording — tap to stop'), findsNothing);
    expect(find.byTooltip('Tap to record'), findsNWidgets(2));
  });

  testWidgets('Only the tapped field shows the recording state', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    final firstMic = find
        .ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(IconButton),
        )
        .first;
    await tester.tap(firstMic);
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);

    final idleBtn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.mic_none),
        matching: find.byType(IconButton),
      ),
    );
    final idleIcon = idleBtn.icon as Icon;
    expect(idleIcon.color, masterChiefGreen);
    final idleBg = idleBtn.style!.backgroundColor!.resolve(<WidgetState>{});
    expect(idleBg, Colors.transparent);
  });

  testWidgets('Spinner is not shown initially', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
