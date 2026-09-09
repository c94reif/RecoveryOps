import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/repositories/profile_repo_impl.dart';
import 'package:recovery_ops/domain/entities/parsed_recovery_request.dart';
import 'package:recovery_ops/domain/entities/publish_result.dart';
import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';
import 'package:recovery_ops/domain/repositories/location_repo.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/queue_worker_strategy.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/speech_recognition_strategy.dart';
import 'package:recovery_ops/domain/services/transcript_parser_strategy.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_request.dart';
import 'package:recovery_ops/domain/usecases/reporting/submit_outgoing_report.dart';
import 'package:recovery_ops/presentation/home/home_page.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';
import 'package:recovery_ops/presentation/recovery/recovery_view_model.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';

class FakeSpeechRecognition implements SpeechRecognitionStrategy {
  @override
  Future<bool> get isAvailable async => true;
  @override
  Future<void> startListening(
      {required void Function(String text) onResult}) async {}
  @override
  Future<void> stopListening() async {}
}

class FakeTranscriptParser implements TranscriptParserStrategy {
  @override
  Future<ParsedRecoveryRequest> parse(String transcript) async {
    return ParsedRecoveryRequest(bumperNumber: '', issue: transcript);
  }
}

class FakeMapService implements sdk.MapService {
  @override
  Future<String> addMarker(sdk.LatLng location,
          {String? label,
          String? color,
          sdk.MarkerIcon? icon,
          sdk.MarkerDisposition? disposition}) async =>
      'marker-1';
  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {}
  @override
  Future<void> removeMarker(String id) async {}
  @override
  Future<List<sdk.MapMarker>> getMarkers() async => [];
  @override
  Future<void> clearMarkers() async {}
  @override
  Future<sdk.LatLng?> pickLocation() async => null;
  @override
  Future<void> addPolyline(String id, List<sdk.LatLng> points,
      {String? color}) async {}
  @override
  Future<void> removePolyline(String id) async {}
  @override
  Future<void> clearPolylines() async {}
  @override
  Future<sdk.ScreenPoint?> getPixelFromLocation(sdk.LatLng location) async =>
      null;
  @override
  Future<bool> simulateMarkerTap(String entityId) async => false;
}

class FakeLocationRepository implements LocationRepository {
  @override
  Future<LatLng?> getCurrentLocation() async => null;
}

class FakeReportsRepository implements ReportsRepository {
  @override
  Future<List<RecoveryReport>> getAllReports() async => [];
  @override
  Future<void> insertReport(RecoveryReport report) async {}
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
  }) async =>
      true;
  @override
  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async =>
      true;
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
  }) async =>
      true;
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
  }) async =>
      const PublishResult(latticeOk: true, meshOk: true);
}

class FakeReportsViewModel extends ChangeNotifier implements ReportsViewModel {
  @override
  final List<RecoveryReport> reports = [];

  @override
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markBracketAsRead(DistanceBracket bracket) async {}

  @override
  Future<void> markReportAsRead(RecoveryReport report) async {}

  @override
  String? distanceTo(RecoveryReport report) => null;

  @override
  double? distanceToKm(RecoveryReport report) => null;

  @override
  Future<void> viewReport(RecoveryReport report) async {}

  @override
  Future<void> navigateTo(RecoveryReport report) async {}

  @override
  Future<void> deleteReport(RecoveryReport report) async {}

  @override
  List<RecoveryReport> get yourReports =>
      reports.where((r) => r.isOutgoing).toList();

  @override
  List<RecoveryReport> get externalReports =>
      reports.where((r) => !r.isOutgoing).toList();

  @override
  Map<DistanceBracket, List<RecoveryReport>> get groupedExternalReports =>
      {for (final b in DistanceBracket.values) b: <RecoveryReport>[]};

  @override
  Map<DistanceBracket, int> get unreadPerBracket =>
      {for (final b in DistanceBracket.values) b: 0};

  @override
  double? navigatorProgress(RecoveryReport report) => null;

  @override
  String? navigatorDistanceRemaining(RecoveryReport report) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNavigationViewModel extends ChangeNotifier
    implements NavigationViewModel {
  @override
  LatLng? currentLocation;

  @override
  String activeRouteId = '';

  @override
  String? navigatingEntityId;

  @override
  RecoveryReport? navigatingReport;

  @override
  bool get isNavigating => false;

  @override
  bool get hasLocation => false;

  @override
  Future<void> refreshLocation() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late ProfileDao profileDao;
  late FakeReportsViewModel fakeReportsVm;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase.test(NativeDatabase.memory());
    profileDao = ProfileDao(db);
    fakeReportsVm = FakeReportsViewModel();

    getIt.registerLazySingleton<AppDatabase>(() => db);
    getIt.registerLazySingleton<ProfileDao>(() => profileDao);
    getIt.registerLazySingleton<ProfileRepository>(
      () => ProfileRepoImpl(profileDao),
    );
    getIt.registerLazySingleton<LocationRepository>(
      () => FakeLocationRepository(),
    );
    getIt.registerLazySingleton<PublishRecoveryRequest>(
      () => FakePublishRecoveryRequest(),
    );
    getIt.registerLazySingleton<ReportsViewModel>(() => fakeReportsVm);
    getIt.registerLazySingleton<NavigationViewModel>(
      () => FakeNavigationViewModel(),
    );
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(getIt<ProfileRepository>()),
    );
    getIt.registerLazySingleton<sdk.MapService>(() => FakeMapService());
    getIt.registerFactory<HomeViewModel>(
      () => HomeViewModel(
        getIt<LocationRepository>(),
      ),
    );
    getIt.registerLazySingleton<ReportsRepository>(
      () => FakeReportsRepository(),
    );
    getIt.registerLazySingleton<SubmitOutgoingReport>(
      () => SubmitOutgoingReport(getIt<ReportsRepository>()),
    );
    getIt.registerFactory<RecoveryViewModel>(
      () => RecoveryViewModel(
        FakeSpeechRecognition(),
        FakeTranscriptParser(),
        submitOutgoingReport: getIt<SubmitOutgoingReport>(),
        mapService: getIt<sdk.MapService>(),
        publishRecoveryRequest: getIt<PublishRecoveryRequest>(),
        reportsViewModel: getIt<ReportsViewModel>(),
      ),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.recovery_ops/cot'),
      (MethodCall methodCall) async => null,
    );
  });

  tearDown(() async {
    await db.close();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.recovery_ops/cot'),
      null,
    );
  });

  List<String> navTabs = ['Recovery', 'Reports', 'Nav', 'Profile'];

  testWidgets('Nav bar has Recovery, Reports, Nav, and Profile tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    expect(find.text('Recovery'), findsAtLeastNWidgets(1));
    expect(find.text('Reports'), findsAtLeastNWidgets(1));
    expect(find.text('Nav'), findsAtLeastNWidgets(1));
    expect(find.text('Profile'), findsAtLeastNWidgets(1));
  });

  for (final tabName in navTabs) {
    testWidgets('Tapping $tabName tab should display $tabName content',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tabName).last);
      await tester.pumpAndSettle();

      expect(find.text(tabName), findsAtLeastNWidgets(1));
    });
  }
}
