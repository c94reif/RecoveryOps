import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/navigation/sync_navigator_states.dart';

class FakeRemoteReportSource implements RemoteReportSource {
  Map<String, NavigatorUpdate?> statesByEntityId = {};
  Map<String, Exception> errorsByEntityId = {};
  int fetchCallCount = 0;
  final List<String> fetchedEntityIds = [];

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async {
    fetchCallCount++;
    fetchedEntityIds.add(entityId);
    final err = errorsByEntityId[entityId];
    if (err != null) throw err;
    return statesByEntityId[entityId];
  }

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async => null;

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async => const [];

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async => const {};
}

RecoveryReport makeReport({
  int? id,
  String? entityId,
  bool isOutgoing = false,
}) {
  return RecoveryReport(
    id: id,
    entityId: entityId,
    fromCallsign: 'Alpha',
    bumperNumber: 'HQ-42',
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 4, 14, 12),
    isOutgoing: isOutgoing,
  );
}

void main() {
  late FakeRemoteReportSource source;
  late SyncNavigatorStates usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    usecase = SyncNavigatorStates(source);
  });

  test('returns empty list when there are no outgoing reports', () async {
    final result = await usecase([
      makeReport(id: 1, entityId: 'entity-1', isOutgoing: false),
    ]);
    expect(result, isEmpty);
    expect(source.fetchCallCount, 0);
  });

  test('skips reports with null or empty entityId', () async {
    final result = await usecase([
      makeReport(id: 1, isOutgoing: true),
      makeReport(id: 2, entityId: '', isOutgoing: true),
    ]);
    expect(result, isEmpty);
    expect(source.fetchCallCount, 0);
  });

  test('fetches navigator state for each outgoing report', () async {
    source.statesByEntityId = {
      'entity-1': const NavigatorUpdate(
        entityId: 'entity-1',
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      ),
      'entity-2': const NavigatorUpdate(
        entityId: 'entity-2',
        navigatorLatitude: 35.0,
        navigatorLongitude: -86.0,
      ),
    };

    final result = await usecase([
      makeReport(id: 1, entityId: 'entity-1', isOutgoing: true),
      makeReport(id: 2, entityId: 'entity-2', isOutgoing: true),
    ]);

    expect(result.length, 2);
    expect(source.fetchCallCount, 2);
    expect(source.fetchedEntityIds, containsAll(['entity-1', 'entity-2']));
  });

  test('excludes reports with no navigator data from results', () async {
    source.statesByEntityId = {
      'entity-1': const NavigatorUpdate(
        entityId: 'entity-1',
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      ),
      'entity-2': null,
    };

    final result = await usecase([
      makeReport(id: 1, entityId: 'entity-1', isOutgoing: true),
      makeReport(id: 2, entityId: 'entity-2', isOutgoing: true),
    ]);

    expect(result.length, 1);
    expect(result.first.entityId, 'entity-1');
  });

  test('continues when one fetch throws', () async {
    source.statesByEntityId = {
      'entity-2': const NavigatorUpdate(
        entityId: 'entity-2',
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      ),
    };
    source.errorsByEntityId = {'entity-1': Exception('network error')};

    final result = await usecase([
      makeReport(id: 1, entityId: 'entity-1', isOutgoing: true),
      makeReport(id: 2, entityId: 'entity-2', isOutgoing: true),
    ]);

    expect(result.length, 1);
    expect(result.first.entityId, 'entity-2');
  });

  test('only processes outgoing reports, ignores incoming', () async {
    source.statesByEntityId = {
      'entity-out': const NavigatorUpdate(
        entityId: 'entity-out',
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      ),
      'entity-in': const NavigatorUpdate(
        entityId: 'entity-in',
        navigatorLatitude: 35.0,
        navigatorLongitude: -86.0,
      ),
    };

    final result = await usecase([
      makeReport(id: 1, entityId: 'entity-out', isOutgoing: true),
      makeReport(id: 2, entityId: 'entity-in', isOutgoing: false),
    ]);

    expect(result.length, 1);
    expect(result.first.entityId, 'entity-out');
    expect(source.fetchedEntityIds, ['entity-out']);
  });

  test('returns empty when no reports provided', () async {
    final result = await usecase(const []);
    expect(result, isEmpty);
    expect(source.fetchCallCount, 0);
  });
}
