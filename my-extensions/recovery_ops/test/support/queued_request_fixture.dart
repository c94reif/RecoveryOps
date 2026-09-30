import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';

QueuedRequest queuedRequest({
  int? id,
  String entityId = 'recovery-1',
  TransportKind transport = TransportKind.lattice,
  DateTime? createdAt,
}) =>
    QueuedRequest(
      id: id,
      entityId: entityId,
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      recoveryType: 'Wrecker',
      latitude: 33.25,
      longitude: -84.5,
      transport: transport,
      createdAt: createdAt ?? DateTime.utc(2026, 4, 10, 9),
    );
