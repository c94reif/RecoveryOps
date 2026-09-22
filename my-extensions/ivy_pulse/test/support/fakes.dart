import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/services/transaction_runner.dart';

// PmcsReport comes via the reports_view_model export below.
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
// QueuedSubmission comes via the reports_view_model export below.
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/location_repo.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/domain/services/id_generator.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

/// Shared in-memory doubles. Hand-written rather than generated so the tests
/// break loudly when a domain contract changes.

class FakeTransactionRunner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() action) => action();
}

class FakeSessionsRepository implements SessionsRepository {
  @override
  Future<void> updateLocation(
      String sessionId, double latitude, double longitude) async {
    final index = sessions.indexWhere((s) =>
        s.sessionId == sessionId && s.status == SessionStatus.inProgress);
    if (index != -1) {
      sessions[index] =
          sessions[index].copyWith(latitude: latitude, longitude: longitude);
    }
  }

  final List<PmcsSession> sessions = [];
  final List<PmcsSession> updated = [];
  final List<String> deleted = [];
  int nextId = 1;

  @override
  Future<List<PmcsSession>> getOpenSessions() async =>
      sessions.where((s) => s.status == SessionStatus.inProgress).toList();

  @override
  Future<PmcsSession?> getBySessionId(String sessionId) async {
    for (final session in sessions) {
      if (session.sessionId == sessionId) return session;
    }
    return null;
  }

  @override
  Future<PmcsSession> insert(PmcsSession session) async {
    final stored = session.copyWith(id: nextId++);
    sessions.add(stored);
    return stored;
  }

  @override
  Future<void> update(PmcsSession session) async {
    updated.add(session);
    final index = sessions.indexWhere((s) => s.sessionId == session.sessionId);
    if (index != -1) {
      sessions[index] = session.copyWith(
          latitude: session.latitude ?? sessions[index].latitude,
          longitude: session.longitude ?? sessions[index].longitude);
    }
  }

  @override
  Future<void> deleteBySessionId(String sessionId) async {
    deleted.add(sessionId);
    sessions.removeWhere((s) => s.sessionId == sessionId);
  }
}

class FakeResultsRepository implements ResultsRepository {
  /// Set to simulate a read failure when a phase is opened.
  bool failReads = false;
  final Map<String, Map<String, CheckResult>> stored = {};
  final List<String> clearedSessions = [];

  String key(String sessionId, PmcsPhase phase) =>
      '$sessionId|${phase.wireName}';

  @override
  Future<Map<String, CheckResult>> getResults(
    String sessionId,
    PmcsPhase phase,
  ) async {
    if (failReads) throw StateError('database unavailable');
    return Map.of(stored[key(sessionId, phase)] ?? const {});
  }

  @override
  Future<void> upsertResult(
    String sessionId,
    PmcsPhase phase,
    CheckResult result,
  ) async {
    stored.putIfAbsent(key(sessionId, phase), () => {})[result.itemId] = result;
  }

  @override
  Future<void> deleteForSession(String sessionId) async {
    clearedSessions.add(sessionId);
    stored.removeWhere((k, _) => k.startsWith('$sessionId|'));
  }
}

class FakeFaultsRepository implements FaultsRepository {
  final Map<String, List<PmcsFault>> byPhase = {};
  final List<String> clearedSessions = [];

  @override
  Future<List<PmcsFault>> getForSession(String sessionId) async => [
        for (final entry in byPhase.entries)
          if (entry.key.startsWith('$sessionId|')) ...entry.value,
      ];

  @override
  Future<void> replacePhaseFaults(
    String sessionId,
    List<PmcsFault> faults, {
    required String phaseWireName,
  }) async {
    byPhase['$sessionId|$phaseWireName'] = List.of(faults);
  }

  @override
  Future<void> deleteForSession(String sessionId) async {
    clearedSessions.add(sessionId);
    byPhase.removeWhere((k, _) => k.startsWith('$sessionId|'));
  }
}

class FakeReportsRepository implements ReportsRepository {
  /// Set to simulate the database going away mid-submit.
  bool failInsert = false;
  final List<PmcsReport> reports = [];
  final List<int> readIds = [];
  final List<int> deletedIds = [];
  bool markedAll = false;
  int nextId = 1;

  @override
  Future<List<PmcsReport>> getAllReports() async => List.of(reports);

  @override
  Future<PmcsReport> insertReport(PmcsReport report) async {
    if (failInsert) throw StateError('database unavailable');
    final stored = report.copyWith(id: nextId++);
    reports.add(stored);
    return stored;
  }

  @override
  Future<void> markAsRead(int id) async => readIds.add(id);

  @override
  Future<void> markAllAsRead() async => markedAll = true;

  @override
  Future<void> deleteReport(int id) async {
    deletedIds.add(id);
    reports.removeWhere((r) => r.id == id);
  }
}

class FakeQueuedSubmissionsRepository implements QueuedSubmissionsRepository {
  final List<QueuedSubmission> submissions = [];
  final List<int> deletedIds = [];
  int nextId = 1;

  @override
  Future<List<QueuedSubmission>> getAll() async => List.of(submissions);

  @override
  Future<QueuedSubmission> insert(QueuedSubmission submission) async {
    final stored = submission.copyWith(id: nextId++);
    submissions.add(stored);
    return stored;
  }

  @override
  Future<void> deleteById(int id) async {
    deletedIds.add(id);
    submissions.removeWhere((s) => s.id == id);
  }

  @override
  Future<int> count() async => submissions.length;
}

class FakeProfileRepository implements ProfileRepository {
  Profile? profile;
  final List<Profile> saved = [];

  FakeProfileRepository([this.profile]);

  @override
  Future<Profile?> getProfile() async => profile;

  @override
  Future<void> saveProfile(Profile profile) async {
    saved.add(profile);
    this.profile = profile;
  }
}

/// Hands back whatever the test set, so the sign-off gate can be driven
/// through every outcome without a camera.
class FakeCacScanner implements CacScannerStrategy {
  bool available = true;
  CacCapture result = const CacCapture.failed(CacRejection.noCodeFound);
  Object? throwOnCapture;
  int captureCalls = 0;
  int cancelCalls = 0;

  /// Convenience for the common case: a readable card.
  void willRead(String barcode) => result = CacCapture.read(barcode);

  void willFail(CacRejection rejection) =>
      result = CacCapture.failed(rejection);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CacCapture> capture() async {
    captureCalls++;
    if (throwOnCapture != null) throw throwOnCapture!;
    return result;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}

/// A capture that never resolves until the test says so.
///
/// The one scanner shape [FakeCacScanner] cannot take: everything that guards
/// an in-flight scan — the cancel control, the generation guard, the latch
/// this whole path exists to prevent — is unreachable if `capture()` has
/// already returned by the time the test looks at it.
class HangingCacScanner implements CacScannerStrategy {
  final Completer<CacCapture> pending = Completer<CacCapture>();
  int captureCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() {
    captureCalls++;
    return pending.future;
  }

  /// Nothing is completed here on purpose. The real scanner cannot close the
  /// Android camera activity either; it abandons the scan on its own side and
  /// drops whatever lands afterwards, which is exactly the sequence the
  /// generation guard has to survive.
  @override
  Future<void> cancel() async => cancelCalls++;
}

class FakeLocationRepository implements LocationRepository {
  LatLng? location;
  int calls = 0;

  FakeLocationRepository([this.location]);

  @override
  Future<LatLng?> getCurrentLocation() async {
    calls++;
    return location;
  }
}

class FakeIdGenerator implements IdGenerator {
  final List<String> ids;
  int index = 0;

  FakeIdGenerator([this.ids = const ['id-1', 'id-2', 'id-3']]);

  @override
  String newId() => ids[index++ % ids.length];
}

/// Grades by index alone — enough to assert wiring without pulling the real
/// TM rules into a use case test.
class FakeFaultClassifier implements FaultClassifierStrategy {
  final Set<String> criticalIds;

  FakeFaultClassifier({this.criticalIds = const {}});

  @override
  FaultSeverity? classify({required String itemId, required int faultIndex}) {
    if (faultIndex == 0) return null;
    if (criticalIds.contains(itemId) && faultIndex >= 3) {
      return FaultSeverity.redX;
    }
    if (faultIndex >= 3) return FaultSeverity.circleX;
    return FaultSeverity.dash;
  }

  @override
  bool isCriticalSystem(String itemId) => criticalIds.contains(itemId);
}

class FakePmcsEntityPort implements PmcsEntityPort {
  bool publishSucceeds = true;
  Completer<bool>? publishGate;
  bool deleteSucceeds = true;
  final List<PmcsReport> published = [];
  final List<String> publishedPayloads = [];
  final List<String> deletedIds = [];

  @override
  Future<bool> publishPmcsReport(PmcsReport report) async {
    published.add(report);
    if (publishGate != null) return publishGate!.future;
    return publishSucceeds;
  }

  @override
  Future<bool> publishEncodedReport({
    required String entityId,
    required String payload,
    required LatLng position,
  }) async {
    publishedPayloads.add(payload);
    return publishSucceeds;
  }

  @override
  Future<bool> deletePmcsEntity(String entityId) async {
    deletedIds.add(entityId);
    return deleteSucceeds;
  }
}

class FakeMeshBroadcaster implements MeshBroadcasterPort {
  bool broadcastSucceeds = true;
  bool deleteSucceeds = true;
  final List<PmcsReport> broadcast = [];
  final List<String> broadcastPayloads = [];
  final List<String> deletedIds = [];

  @override
  Future<bool> broadcastPmcsReport(PmcsReport report) async {
    broadcast.add(report);
    return broadcastSucceeds;
  }

  @override
  Future<bool> broadcastEncodedReport(String payload) async {
    broadcastPayloads.add(payload);
    return broadcastSucceeds;
  }

  @override
  Future<bool> broadcastPmcsDeletion(String entityId) async {
    deletedIds.add(entityId);
    return deleteSucceeds;
  }
}

class FakeQueueWorker implements QueueWorkerStrategy {
  final List<QueuedSubmission> enqueued = [];
  final List<(TransportKind, bool)> outcomes = [];
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> enqueue(QueuedSubmission submission) async {
    enqueued.add(submission);
  }

  @override
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  }) {
    outcomes.add((transport, success));
  }

  @override
  Future<int> pendingCount() async => enqueued.length;
}

class FakeRemoteReportSource implements RemoteReportSource {
  List<PmcsReport> remote = [];
  Set<String> knownIds = {};
  Object? throwOnFetch;

  @override
  Future<List<PmcsReport>> fetchRemotePmcsReports() async {
    if (throwOnFetch != null) throw throwOnFetch!;
    return remote;
  }

  @override
  Future<Set<String>> fetchKnownPmcsEntityIds() async {
    if (throwOnFetch != null) throw throwOnFetch!;
    return knownIds;
  }
}

/// Encodes to a recognisable sentinel so tests can assert on payloads without
/// depending on the real JSON codec.
class FakeReportCodec implements ReportCodec {
  final List<PmcsReport> encoded = [];
  PmcsReport? decodeResult;
  String? decodeDeletionResult;

  @override
  String encodeReport(PmcsReport report) {
    encoded.add(report);
    return 'encoded:${report.entityId}';
  }

  @override
  PmcsReport? decodeReport(String payload, {required String fromCallsign}) =>
      decodeResult;

  @override
  String encodeDeletion(String entityId) => 'deleted:$entityId';

  @override
  String? decodeDeletion(String payload) => decodeDeletionResult;
}

// ── Builders ──────────────────────────────────────────────────────────────

PmcsSession buildSession({
  int? id,
  String sessionId = 'session-1',
  String bumperNumber = 'A-11',
  VehicleType vehicleType = VehicleType.stryker,
  String operator = '',
  String uic = 'WJ8TAA',
  List<PmcsPhase> completedPhases = const [],
  SessionStatus status = SessionStatus.inProgress,
  PmcsSignature? signature,
  double? latitude = 33.0,
  double? longitude = -84.0,
}) {
  return PmcsSession(
    id: id,
    sessionId: sessionId,
    bumperNumber: bumperNumber,
    vehicleType: vehicleType,
    operator: operator,
    uic: uic,
    startedAt: DateTime.utc(2026, 3, 24, 6),
    completedPhases: completedPhases,
    status: status,
    signature: signature,
    latitude: latitude,
    longitude: longitude,
  );
}

PmcsFault buildFault({
  String sessionId = 'session-1',
  String itemId = 'B-ENG-01',
  PmcsPhase phase = PmcsPhase.before,
  String category = 'ENGINE COMPARTMENT',
  String subcategory = 'Engine Oil Level',
  String condition = 'Low-Add Oil',
  FaultSeverity severity = FaultSeverity.circleX,
  String? note,
}) {
  return PmcsFault(
    sessionId: sessionId,
    itemId: itemId,
    phase: phase,
    category: category,
    subcategory: subcategory,
    description: 'Check dipstick for level between ADD and FULL',
    condition: condition,
    severity: severity,
    note: note,
    recordedAt: DateTime.utc(2026, 3, 24, 7),
  );
}

PmcsReport buildReport({
  int? id,
  String entityId = 'session-1',
  String fromCallsign = 'You',
  String bumperNumber = 'A-11',
  VehicleType vehicleType = VehicleType.stryker,
  String operator = 'SGT SMITH',
  String uic = 'WJ8TAA',
  List<PmcsFault> faults = const [],
  PmcsSignature? signature,
  bool isOutgoing = true,
  bool isRead = true,
  DateTime? timestamp,
}) {
  return PmcsReport(
    id: id,
    entityId: entityId,
    fromCallsign: fromCallsign,
    bumperNumber: bumperNumber,
    vehicleType: vehicleType,
    operator: operator,
    uic: uic,
    phases: const [PmcsPhase.before],
    faults: faults,
    signature: signature,
    latitude: 33.0,
    longitude: -84.0,
    timestamp: timestamp ?? DateTime.utc(2026, 3, 24, 8),
    isOutgoing: isOutgoing,
    isRead: isRead,
  );
}

QueuedSubmission buildQueuedSubmission({
  int? id,
  String entityId = 'session-1',
  String bumperNumber = 'A-11',
  String vehicleType = 'Stryker',
  int redXCount = 0,
  int faultCount = 0,
  double latitude = 33.0,
  double longitude = -84.0,
  String payload = 'encoded:session-1',
  TransportKind transport = TransportKind.lattice,
  DateTime? createdAt,
}) {
  return QueuedSubmission(
    id: id,
    entityId: entityId,
    bumperNumber: bumperNumber,
    vehicleType: vehicleType,
    redXCount: redXCount,
    faultCount: faultCount,
    latitude: latitude,
    longitude: longitude,
    payload: payload,
    transport: transport,
    createdAt: createdAt ?? DateTime.utc(2026, 3, 24, 8),
  );
}

// ── View model doubles ────────────────────────────────────────────────────
// Shared by the shell and the reports screen: both mount [ReportsPage], and
// the real view model opens a mesh subscription and a periodic timer that a
// widget test would flag as still pending.

/// Stands in for [ReportsViewModel] in widget tests. Grouping is the real
/// triage rule rather than a canned map, so a page test still fails if a RED X
/// report stops landing under NOT MISSION CAPABLE.
class FakeReportsViewModel extends ChangeNotifier implements ReportsViewModel {
  @override
  final ValueNotifier<PmcsReport?> reportToOpen = ValueNotifier(null);

  @override
  final List<PmcsReport> reports = [];

  @override
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  @override
  final ValueNotifier<int> queuedCount = ValueNotifier(0);

  final List<PmcsReport> markedRead = [];
  final List<PmcsReport> deleted = [];
  final List<PmcsReport> viewed = [];
  int syncCalls = 0;

  @override
  List<PmcsReport> get yourReports =>
      reports.where((r) => r.isOutgoing).toList();

  @override
  List<PmcsReport> get externalReports =>
      reports.where((r) => !r.isOutgoing).toList();

  @override
  String bucketFor(PmcsReport report) {
    final tally = report.tally;
    if (tally.redX > 0) return ReportsViewModel.bucketNotMissionCapable;
    if (tally.circleX > 0) return ReportsViewModel.bucketLimited;
    return ReportsViewModel.bucketMissionCapable;
  }

  @override
  String myUic = '';

  @override
  final List<QueuedSubmission> queued = [];

  @override
  bool isSameUnit(PmcsReport report) =>
      myUic.isEmpty || report.uic.trim().toUpperCase() == myUic;

  @override
  List<PmcsReport> get unitReports =>
      externalReports.where(isSameUnit).toList();

  @override
  List<PmcsReport> get otherUnitReports =>
      externalReports.where((r) => !isSameUnit(r)).toList();

  @override
  Map<ReportVehicleKey, List<PmcsReport>> groupByVehicle(
      List<PmcsReport> source) {
    final groups = <ReportVehicleKey, List<PmcsReport>>{};
    for (final report in source) {
      groups.putIfAbsent((
        bumperNumber: report.bumperNumber.trim().toUpperCase(),
        uic: report.uic.trim().toUpperCase(),
      ), () => []).add(report);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final bumperOrder = a.bumperNumber.compareTo(b.bumperNumber);
        return bumperOrder != 0 ? bumperOrder : a.uic.compareTo(b.uic);
      });
    return {for (final key in keys) key: groups[key]!};
  }

  @override
  Map<String, List<QueuedSubmission>> get queuedByBumperNumber {
    final groups = <String, List<QueuedSubmission>>{};
    for (final submission in queued) {
      groups
          .putIfAbsent(submission.bumperNumber.trim().toUpperCase(), () => [])
          .add(submission);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final keys = groups.keys.toList()
      ..sort((a, b) =>
          groups[b]!.first.createdAt.compareTo(groups[a]!.first.createdAt));
    return {for (final key in keys) key: groups[key]!};
  }

  @override
  Map<String, List<PmcsReport>> get groupedByStatus {
    final result = {
      for (final bucket in ReportsViewModel.statusBuckets)
        bucket: <PmcsReport>[],
    };
    for (final report in externalReports) {
      result[bucketFor(report)]!.add(report);
    }
    return result;
  }

  @override
  Future<void> addOutgoing(PmcsReport stored) async {
    reports.removeWhere((r) => r.entityId == stored.entityId);
    reports.insert(0, stored);
    notifyListeners();
  }

  @override
  Future<void> markReportAsRead(PmcsReport report) async {
    markedRead.add(report);
    final index = reports.indexOf(report);
    if (index < 0 || report.isRead) return;
    reports[index] = report.copyWith(isRead: true);
    unreadCount.value = reports.where((r) => !r.isOutgoing && !r.isRead).length;
    notifyListeners();
  }

  @override
  Future<void> markAllAsRead() async {
    markedRead.addAll(reports);
  }

  @override
  Future<void> deleteReport(PmcsReport report) async {
    deleted.add(report);
    reports.remove(report);
    notifyListeners();
  }

  @override
  Future<void> viewReport(PmcsReport report) async {
    viewed.add(report);
  }

  @override
  Future<void> syncRemoteLatticeReports() async {
    syncCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Soldier as the parser would hand one back, for tests that need an
/// identity without going through a barcode.
CacIdentity buildIdentity({
  String edipi = '1087987498',
  String firstName = 'JOHN',
  String lastName = 'SMITH',
  String middleInitial = 'A',
  String rank = 'SGT',
  String branchCode = 'A',
  String categoryCode = 'A',
  DateTime? cardExpiresOn,
  String cardInstance = 'K',
  DateTime? verifiedAt,
}) {
  return CacIdentity(
    edipi: edipi,
    firstName: firstName,
    lastName: lastName,
    middleInitial: middleInitial,
    rank: rank,
    branchCode: branchCode,
    categoryCode: categoryCode,
    cardExpiresOn: cardExpiresOn ?? DateTime.utc(2028, 6, 30),
    cardInstance: cardInstance,
    verifiedAt: verifiedAt ?? DateTime.utc(2026, 3, 24, 9),
  );
}

PmcsSignature buildSignature({CacIdentity? identity, DateTime? signedAt}) {
  return PmcsSignature.verified(
    identity: identity ?? buildIdentity(),
    signedAt: signedAt ?? DateTime.utc(2026, 3, 24, 9),
  );
}

PmcsSignature buildUnverifiedSignature({
  CacRejection blockedBy = CacRejection.noCamera,
  DateTime? signedAt,
}) {
  return PmcsSignature.unverified(
    blockedBy: blockedBy,
    signedAt: signedAt ?? DateTime.utc(2026, 3, 24, 9),
  );
}
