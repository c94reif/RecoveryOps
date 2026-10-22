import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/circle_x_extension.dart';
import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/report_store_strategy.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import 'support/fake_mesh_items.dart';
import 'support/fakes.dart';

class BackgroundMessaging extends sdk.StubMessagingService {
  final messages = StreamController<sdk.IncomingMessage>.broadcast();
  final peers = StreamController<List<sdk.Peer>>.broadcast();

  @override
  Stream<sdk.IncomingMessage> get onMessageReceived => messages.stream;

  @override
  Stream<List<sdk.Peer>> get onPeersChanged => peers.stream;

  void receive(String reportId) {
    messages.add(sdk.IncomingMessage(
      id: 'message-$reportId',
      fromPeerId: 'peer-bravo',
      fromCallsign: 'BRAVO',
      payload: const PmcsReportCodec().encodeReport(
          buildReport(entityId: reportId, signature: buildSignature())),
      receivedAt: DateTime.utc(2026, 10, 6),
    ));
  }

  Future<void> dispose() async {
    await messages.close();
    await peers.close();
  }
}

class BackgroundContext extends sdk.StubExtensionContext {
  @override
  final BackgroundMessaging messaging;

  BackgroundContext(this.messaging);
}

class StallingMeshItems extends FakeMeshItems {
  Completer<void>? stall;

  @override
  Future<List<sdk.MeshItem>> listItems(sdk.MeshDataTypePath type,
      {Map<String, Object?>? filter}) async {
    await stall?.future;
    return super.listItems(type, filter: filter);
  }
}

class CountingBackgroundWorker extends FakeQueueWorker {
  int starts = 0;
  int stops = 0;
  int retries = 0;

  @override
  Future<void> retryNow() async => retries++;

  @override
  Future<void> start() async {
    starts++;
    await super.start();
  }

  @override
  Future<void> stop() async {
    stops++;
    await super.stop();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late BackgroundMessaging messaging;
  late BackgroundContext context;
  late CountingBackgroundWorker worker;
  late StallingMeshItems items;
  late CircleXExtension extension;
  bool disposed = false;

  Future<void> until(Future<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Background delivery did not reach the expected state');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> stored(String reportId) =>
      until(() async => (await getIt<ReportsRepository>().getAllReports())
          .any((report) => report.entityId == reportId));

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    if (!getIt.isRegistered<ReportsViewModel>()) return;
    final viewModel = getIt<ReportsViewModel>();
    await viewModel.syncInFlight;
    await viewModel.queueRefreshInFlight;
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> initialize() async {
    extension.onInitializeWithContext(context);
    await getIt<ReportsViewModel>().loadFromDb();
    await settle();
  }

  void addRemote(String reportId) {
    items.seed(ReportStoreConfig.itemType, {
      'reportId': reportId,
      'withdrawn': false,
      'updatedAt': '2026-10-06T12:00:00.000Z',
      'report': const PmcsReportCodec().reportBody(
          buildReport(entityId: reportId, signature: buildSignature())),
    });
  }

  setUp(() async {
    await getIt.reset();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    database = AppDatabase.test(NativeDatabase.memory());
    messaging = BackgroundMessaging();
    context = BackgroundContext(messaging);
    worker = CountingBackgroundWorker();
    items = StallingMeshItems();
    extension = CircleXExtension();
    disposed = false;
    getIt.registerSingleton<AppDatabase>(database);
    getIt.registerSingleton<QueueWorkerStrategy>(worker);
    getIt.registerSingleton<ReportStoreStrategy>(
        MeshItemReportStoreStrategy(items: items));
    getIt.skipDoubleRegistration = true;
  });

  tearDown(() async {
    await settle();
    if (!disposed) extension.dispose();
    await Future<void>.delayed(Duration.zero);
    await messaging.dispose();
    await getIt.reset();
    getIt.skipDoubleRegistration = false;
    await database.close();
    context.close();
  });

  test('host initialization starts delivery and receives peers before UI build',
      () async {
    await initialize();

    expect(worker.starts, 1);
    expect(worker.retries, 1);
    expect(messaging.messages.hasListener, isTrue);
    messaging.receive('before-panel-build');
    await stored('before-panel-build');

    final received = (await getIt<ReportsRepository>().getAllReports()).single;
    expect(received.fromCallsign, 'BRAVO');
    expect(received.isOutgoing, isFalse);
  });

  test('repeated host initialization retains one running dependency graph',
      () async {
    await initialize();
    final original = getIt<ReportsViewModel>();

    extension.onInitializeWithContext(context);
    await settle();

    expect(getIt<ReportsViewModel>(), same(original));
    expect(worker.starts, 1);
    expect(worker.stops, 0);
  });

  test('deactivating the panel and pausing the app keep peer reception active',
      () async {
    await initialize();
    extension.onDeactivate();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    messaging.receive('while-backgrounded');
    await stored('while-backgrounded');

    expect(worker.stops, 0);
    expect(getIt<ReportsViewModel>().disposed, isFalse);
  });

  test('activation and app resume reconcile remote records immediately',
      () async {
    await initialize();
    extension.onDeactivate();
    addRemote('on-activation');

    extension.onActivate();
    await stored('on-activation');
    await settle();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addRemote('on-resume');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await stored('on-resume');

    expect(worker.starts, greaterThanOrEqualTo(3));
    expect(worker.retries, greaterThanOrEqualTo(3));
    expect(worker.stops, 0);
  });

  test('a peer coming online retries queued delivery without reopening UI',
      () async {
    await initialize();
    extension.onDeactivate();
    final retries = worker.retries;
    addRemote('peer-reconnected');

    messaging.peers.add([
      sdk.Peer(
        deviceId: 'peer-bravo',
        callsign: 'BRAVO',
        ip: '192.0.2.10',
        isOnline: true,
        lastSeen: DateTime.utc(2026, 10, 6),
      ),
    ]);
    await stored('peer-reconnected');

    expect(worker.retries, greaterThan(retries));
    expect(worker.stops, 0);
  });

  test('a peer coming online retries the queue while a report sync is stalled',
      () async {
    await initialize();
    final stall = items.stall = Completer<void>();
    addTearDown(() {
      if (!stall.isCompleted) stall.complete();
    });
    extension.onActivate();
    await Future<void>.delayed(Duration.zero);
    final retries = worker.retries;

    messaging.peers.add([
      sdk.Peer(
        deviceId: 'peer-bravo',
        callsign: 'BRAVO',
        ip: '192.0.2.10',
        isOnline: true,
        lastSeen: DateTime.utc(2026, 10, 6),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(worker.retries, greaterThan(retries));
  });

  test('teardown stops delivery and removes message and lifecycle listeners',
      () async {
    await initialize();
    final viewModel = getIt<ReportsViewModel>();
    extension.dispose();
    extension.dispose();
    disposed = true;
    await Future<void>.delayed(Duration.zero);

    expect(worker.stops, 1);
    expect(viewModel.disposed, isTrue);
    expect(messaging.messages.hasListener, isFalse);
    expect(messaging.peers.hasListener, isFalse);

    final starts = worker.starts;
    messaging.receive('after-teardown');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(worker.starts, starts);
    expect(await getIt<ReportsRepository>().getAllReports(), isEmpty);
  });
}
