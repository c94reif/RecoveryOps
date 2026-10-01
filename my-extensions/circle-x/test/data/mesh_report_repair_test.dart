import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/usecases/reporting/sync_local_reports_to_lattice.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import '../support/report_schema.dart';

void main() {
  const codec = PmcsReportCodec();
  final review = MaintainerReview(
    sourceReportId: 'original',
    faults: const [
      FaultReview(itemId: 'engine', phase: PmcsPhase.before, verified: true)
    ],
    signature: buildSignature(),
  );
  final report = buildReport(
    signature: buildSignature(),
    faults: [buildFault(itemId: 'engine')],
    maintainerReview: review,
  );
  final corruptions = <String, void Function(Map<String, Object?>)>{
    'mismatched ID': (body) => body['entityId'] = 'different',
    'unknown vehicle': (body) => body['vehicleType'] = 'UNKNOWN',
    'unknown severity': (body) =>
        ((body['faults'] as List).single as Map)['severity'] = 'RED-X',
    'unknown phase': (body) => body['phases'] = ['UNKNOWN'],
    'invalid UIC': (body) => body['uic'] = 'BAD',
    'empty review identity': (body) => ((body['maintainerReview']
        as Map)['signature'] as Map)['identity'] = {},
    'duplicate review keys': (body) {
      final faults = (body['maintainerReview'] as Map)['faults'] as List;
      faults.add({
        ...faults.single as Map<String, Object?>,
        'verified': false,
      });
    },
  };

  for (final entry in corruptions.entries) {
    test('reconciliation repairs ${entry.key} at the existing item path',
        () async {
      final items = FakeMeshItems(validate: validateReportRecord);
      final store = MeshItemReportStoreStrategy(items: items);
      final body = codec.reportBody(report);
      entry.value(body);
      // Seed models historical corruption before the schema was tightened.
      final bad = items.seed(ReportStoreConfig.itemType, {
        'reportId': report.entityId,
        'withdrawn': false,
        'updatedAt': '2099-01-01T00:00:00Z',
        'report': body,
      });

      expect(await store.fetchRemotePmcsReports(), isEmpty);
      expect(await store.fetchKnownPmcsEntityIds(), isEmpty);
      final repair = SyncLocalReportsToLattice(store, store);
      expect(await repair.call([report]), 1);
      expect(items.created, isEmpty);
      expect(items.updated, [bad.path.id]);
      expect(codec.reportBody((await store.fetchRemotePmcsReports()).single),
          codec.reportBody(report));
      expect(await store.fetchKnownPmcsEntityIds(), {report.entityId});
      expect(await repair.call([report]), 0);
      expect(items.updated, hasLength(1));
    });
  }

  test(
      'withdrawals still prevent repair from resurrecting corrupt live records',
      () async {
    final items = FakeMeshItems(validate: validateReportRecord);
    final store = MeshItemReportStoreStrategy(items: items);
    await store.deletePmcsEntity(report.entityId);
    items.seed(ReportStoreConfig.itemType, {
      'reportId': report.entityId,
      'withdrawn': false,
      'updatedAt': '2099-01-01T00:00:00Z',
      'report': {},
    });
    expect(await store.fetchKnownPmcsEntityIds(), {report.entityId});
    expect(await SyncLocalReportsToLattice(store, store).call([report]), 0);
    expect(await store.fetchRemotePmcsReports(), isEmpty);
    expect(items.updated, isEmpty);
    expect(items.created, hasLength(1));
  });
}
