import 'dart:async';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';

enum DeliveryStatus { sending, sent, queued, failed, discarded }

typedef DeliveryKey = ({String entityId, TransportKind transport});

/// Shared by fresh submissions, repair sync and both queue implementations.
/// A concurrent request for the same report/transport joins its existing send.
class DeliveryCoordinator {
  final _changes = StreamController<void>.broadcast(sync: true);
  final _states = <DeliveryKey, DeliveryStatus>{};
  final _active = <DeliveryKey, Future<bool>>{};
  final _attemptVersions = <DeliveryKey, int>{};
  int revision = 0;

  Stream<void> get changes => _changes.stream;
  DeliveryStatus? status(String entityId, TransportKind transport) =>
      _states[(entityId: entityId, transport: transport)];

  bool busyOrAttemptedSince(
      String entityId, TransportKind transport, int since) {
    final key = (entityId: entityId, transport: transport);
    return _active.containsKey(key) || (_attemptVersions[key] ?? -1) > since;
  }

  void update(String entityId, TransportKind transport, DeliveryStatus status) {
    final key = (entityId: entityId, transport: transport);
    _states[key] = status;
    revision++;
    _attemptVersions[key] = revision;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Also emitted after a durable queue insert/delete, so the queue badge and
  /// list refresh even when delivery itself completed a moment earlier.
  void queueChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<bool> send(
      String entityId, TransportKind transport, Future<bool> Function() action,
      {bool queuedOnFailure = false}) {
    final key = (entityId: entityId, transport: transport);
    final existing = _active[key];
    if (existing != null) return existing;
    final completion = Completer<bool>();
    _active[key] = completion.future;
    update(entityId, transport, DeliveryStatus.sending);
    unawaited(() async {
      try {
        final success = await action();
        update(
            entityId,
            transport,
            success
                ? DeliveryStatus.sent
                : queuedOnFailure
                    ? DeliveryStatus.queued
                    : DeliveryStatus.failed);
        completion.complete(success);
      } catch (error, stack) {
        update(entityId, transport, DeliveryStatus.failed);
        completion.completeError(error, stack);
      } finally {
        _active.remove(key);
      }
    }());
    return completion.future;
  }

  Future<void> dispose() => _changes.close();
}
