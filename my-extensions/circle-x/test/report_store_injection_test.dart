import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/services/entity_report_store_strategy.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/remote_report_source.dart';
import 'package:circle_x/domain/services/report_store_backend.dart';
import 'package:circle_x/domain/services/report_store_strategy.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final backend in [null, ReportStoreBackend.entities]) {
    test(
        'read/write dependency graph selects ${backend?.name ?? 'default mesh items'}',
        () async {
      await getIt.reset();
      final db = AppDatabase.test(NativeDatabase.memory());
      final context = sdk.StubExtensionContext();
      getIt.registerSingleton<AppDatabase>(db);
      getIt.skipDoubleRegistration = true;
      configureDependencies(context, reportStoreBackend: backend);
      getIt.skipDoubleRegistration = false;
      final viewModel = getIt<ReportsViewModel>();
      addTearDown(() async {
        viewModel.dispose();
        await getIt<QueueWorkerStrategy>().stop();
        await getIt.reset();
        getIt.skipDoubleRegistration = false;
        await db.close();
        context.close();
      });
      await viewModel.loadFromDb();
      await viewModel.syncRemoteLatticeReports();
      final store = getIt<ReportStoreStrategy>();
      expect(
          store,
          backend == null
              ? isA<MeshItemReportStoreStrategy>()
              : isA<EntityReportStoreStrategy>());
      expect(getIt<PmcsEntityPort>(), same(store));
      expect(getIt<RemoteReportSource>(), same(store));
    });
  }
}
