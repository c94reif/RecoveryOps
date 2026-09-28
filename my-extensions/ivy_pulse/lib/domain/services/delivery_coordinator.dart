import 'dart:async';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';

enum DeliveryStatus { sending, sent, queued, failed, discarded }

typedef DeliveryKey = ({
  String entityId,
  TransportKind transport,
  bool withdrawal
});

class DeliveryCoordinator {
  final ReportsRepository? reportsRepository;
  final _withdrawn = <String>{};

  DeliveryCoordinator({this.reportsRepository});

  void suppressReport(String entityId) => _withdrawn.add(entityId);

  Future<bool> isWithdrawn(String entityId) async {
    final persisted =
        await reportsRepository?.getWithdrawnIds() ?? const <String>{};
    return _withdrawn.contains(entityId) || persisted.contains(entityId);
  }

  final _changes = StreamController<void>.broadcast(sync: true);
  final _states = <DeliveryKey, DeliveryStatus>{};
  final _active = <DeliveryKey, Future<bool>>{};
  final _attemptVersions = <DeliveryKey, int>{};
  int revision = 0;

  Stream<void> get changes => _changes.stream;
  DeliveryStatus? status(String entityId, TransportKind transport,
          {bool withdrawal = false}) =>
      _states[(
        entityId: entityId,
        transport: transport,
        withdrawal: withdrawal
      )];

  bool busyOrAttemptedSince(
      String entityId, TransportKind transport, int since) {
    final key = (entityId: entityId, transport: transport, withdrawal: false);
    return _active.containsKey(key) || (_attemptVersions[key] ?? -1) > since;
  }

  void update(String entityId, TransportKind transport, DeliveryStatus status,
      {bool withdrawal = false}) {
    final key =
        (entityId: entityId, transport: transport, withdrawal: withdrawal);
    _states[key] = status;
    revision++;
    _attemptVersions[key] = revision;
    if (!_changes.isClosed) _changes.add(null);
  }

  void queueChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<bool> send(
      String entityId, TransportKind transport, Future<bool> Function() action,
      {bool queuedOnFailure = false, bool withdrawal = false}) {
    final key =
        (entityId: entityId, transport: transport, withdrawal: withdrawal);
    final existing = _active[key];
    if (existing != null) return existing;
    final completion = Completer<bool>();
    _active[key] = completion.future;
    update(entityId, transport, DeliveryStatus.sending, withdrawal: withdrawal);
    unawaited(() async {
      try {
        if (withdrawal) {
          suppressReport(entityId);
          await reportsRepository?.withdrawReport(entityId);
          final publishing = _active[(
            entityId: entityId,
            transport: transport,
            withdrawal: false
          )];
          if (publishing != null) {
            try {
              await publishing;
            } catch (_) {}
          }
        } else if (await isWithdrawn(entityId)) {
          update(entityId, transport, DeliveryStatus.discarded);
          completion.complete(true);
          return;
        }
        final success = await action();
        update(
            entityId,
            transport,
            success
                ? DeliveryStatus.sent
                : queuedOnFailure
                    ? DeliveryStatus.queued
                    : DeliveryStatus.failed,
            withdrawal: withdrawal);
        completion.complete(success);
      } catch (error, stack) {
        update(entityId, transport,
            queuedOnFailure ? DeliveryStatus.queued : DeliveryStatus.failed,
            withdrawal: withdrawal);
        completion.completeError(error, stack);
      } finally {
        _active.remove(key);
      }
    }());
    return completion.future;
  }

  Future<void> dispose() => _changes.close();
}
