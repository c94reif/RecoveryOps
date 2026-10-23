import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/dao/reports/pmcs_reports_dao.dart';
import 'package:circle_x/data/dao/sessions/sessions_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_entity_mapper.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/repositories/reports_repo_impl.dart';
import 'package:circle_x/data/repositories/sessions_repo_impl.dart';
import 'package:circle_x/data/services/shared/drift_transaction_runner.dart';
import 'package:circle_x/data/services/delivery/lattice_pmcs_adapter.dart';
import 'package:circle_x/data/services/delivery/mesh_item_report_store_strategy.dart';
import 'package:circle_x/data/services/delivery/sdk_mesh_broadcaster.dart';
import 'package:circle_x/domain/vehicle/entities/mileage_reading.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/delivery/usecases/publish_pmcs_report.dart';
import 'package:circle_x/domain/reporting/usecases/build_session_report.dart';
import 'package:circle_x/domain/reporting/usecases/submit_session.dart';
import 'package:latlong2/latlong.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import '../support/report_schema.dart';
import 'lattice_pmcs_adapter_test.dart' show FakeEntityService;
import 'sdk_mesh_broadcaster_test.dart' show FakeMessagingService;

void main() {
  const codec = PmcsReportCodec();
  final clock = FixedClock(DateTime.utc(2026, 10, 6));
  final reading = MileageReading(value: 12345.6, unit: MileageUnit.kilometers);

  test('draft updates and submitted reports retain confirmed mileage in SQLite',
      () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);
    final sessions = SessionsRepoImpl(SessionsDao(db));
    final reports = ReportsRepoImpl(PmcsReportsDao(db));
    final draft = await sessions.insert(buildSession());
    expect(draft.mileage, isNull);
    await sessions.update(draft.copyWith(mileage: reading));
    final restored = (await sessions.getBySessionId(draft.sessionId))!;
    expect(restored.mileage!.toMap(), reading.toMap());

    final submit = SubmitSession(
      sessionsRepository: sessions,
      faultsRepository: FakeFaultsRepository(),
      reportsRepository: reports,
      buildSessionReport: BuildSessionReport(clock),
      clock: clock,
      transactionRunner: DriftTransactionRunner(db),
    );
    final sent = await submit(restored.copyWith(signature: buildSignature()));
    expect(sent.mileage!.toMap(), reading.toMap());
    expect((await reports.getAllReports()).single.mileage!.toMap(),
        reading.toMap());
    expect((await sessions.getBySessionId(draft.sessionId))!.mileage!.toMap(),
        reading.toMap());
    expect(sent.copyWith(isRead: false).mileage!.toMap(), reading.toMap());
  });

  test('schema-validated remote store writes and reads mileage for both units',
      () async {
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    for (final unit in MileageUnit.values) {
      final mileage = MileageReading(value: 98765.4, unit: unit);
      final report = buildReport(entityId: unit.symbol, mileage: mileage);
      expect(await store.publishPmcsReport(report), isTrue);
      expect((items.created.last['report'] as Map)['mileage'], mileage.toMap());
    }
    final received = await store.fetchRemotePmcsReports();
    expect(received.map((report) => report.mileage!.display),
        unorderedEquals(['98765.4 mi', '98765.4 km']));
  });

  test('actual transport adapters send mileage and preserve it on reception',
      () async {
    final entities = FakeEntityService();
    final radio = FakeMessagingService();
    final publisher = PublishPmcsReport(
        entityPort: LatticePmcsAdapter(entities: entities),
        meshPort: SdkMeshBroadcaster(messaging: radio),
        queueWorker: FakeQueueWorker(),
        codec: codec,
        clock: clock);
    addTearDown(publisher.delivery.dispose);
    final report = buildReport(mileage: reading);
    expect((await publisher(report)).allSucceeded, isTrue);
    expect(jsonDecode(radio.broadcasts.single)['mileage'], reading.toMap());
    expect(jsonDecode(entities.upserted.single.description!)['mileage'],
        reading.toMap());
    expect(
        codec
            .decodeReport(radio.broadcasts.single, fromCallsign: 'peer')!
            .mileage!
            .toMap(),
        reading.toMap());
    expect(
        const PmcsEntityMapper()
            .parseRemoteEntity(entities.upserted.single)!
            .mileage!
            .toMap(),
        reading.toMap());
  });

  test('both offline queues preserve mileage through transport retries',
      () async {
    final queue = FakeQueueWorker();
    final publisher = PublishPmcsReport(
        entityPort: FakePmcsEntityPort()..publishSucceeds = false,
        meshPort: FakeMeshBroadcaster()..broadcastSucceeds = false,
        queueWorker: queue,
        codec: codec,
        clock: clock);
    addTearDown(publisher.delivery.dispose);
    expect((await publisher(buildReport(mileage: reading))).allFailed, isTrue);
    expect(queue.enqueued.map((entry) => entry.transport).toSet(),
        {TransportKind.lattice, TransportKind.mesh});

    final entities = FakeEntityService();
    final radio = FakeMessagingService();
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    for (final entry in queue.enqueued) {
      expect(jsonDecode(entry.payload)['mileage'], reading.toMap());
      if (entry.transport == TransportKind.lattice) {
        expect(
            await LatticePmcsAdapter(entities: entities).publishEncodedReport(
                entityId: entry.entityId,
                payload: entry.payload,
                position: LatLng(entry.latitude, entry.longitude)),
            isTrue);
        expect(
            await store.publishEncodedReport(
                entityId: entry.entityId,
                payload: entry.payload,
                position: LatLng(entry.latitude, entry.longitude)),
            isTrue);
      } else {
        expect(
            await SdkMeshBroadcaster(messaging: radio)
                .broadcastEncodedReport(entry.payload),
            isTrue);
      }
    }
    expect(jsonDecode(entities.upserted.single.description!)['mileage'],
        reading.toMap());
    expect(jsonDecode(radio.broadcasts.single)['mileage'], reading.toMap());
    expect((await store.fetchRemotePmcsReports()).single.mileage!.toMap(),
        reading.toMap());
  });

  test('old reports without mileage still validate and decode', () {
    final body = codec.reportBody(buildReport());
    expect(body.containsKey('mileage'), isFalse);
    validateReportRecord({
      'reportId': 'session-1',
      'withdrawn': false,
      'updatedAt': '2026-10-06T00:00:00Z',
      'report': body,
    });
    expect(codec.reportFromBody(body, fromCallsign: 'old')!.mileage, isNull);
  });

  for (final invalid in <Object>[
    {'value': -1, 'unit': 'mi'},
    {'value': 10000000, 'unit': 'mi'},
    {'value': '12345', 'unit': 'mi'},
    {'value': 12345, 'unit': 'hours'},
    {'value': 12345},
    '12345',
  ]) {
    test('schema and decoder reject malformed mileage $invalid', () {
      final body = codec.reportBody(buildReport())..['mileage'] = invalid;
      expect(
          () => validateReportRecord({
                'reportId': 'session-1',
                'withdrawn': false,
                'updatedAt': '2026-10-06T00:00:00Z',
                'report': body,
              }),
          throwsFormatException);
      expect(codec.reportFromBody(body, fromCallsign: 'peer'), isNull);
    });
  }
}
