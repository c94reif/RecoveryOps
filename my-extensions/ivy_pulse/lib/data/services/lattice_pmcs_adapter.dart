import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/data/mappers/pmcs_entity_mapper.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';

class LatticePmcsAdapter implements PmcsEntityPort {
  final sdk.EntityService _entities;
  final PmcsEntityMapper _mapper;

  LatticePmcsAdapter({
    required sdk.EntityService entities,
    PmcsEntityMapper? mapper,
  })  : _entities = entities,
        _mapper = mapper ?? const PmcsEntityMapper();

  @override
  Future<bool> publishPmcsReport(PmcsReport report) async {
    return _upsertVerified(_mapper.buildEntity(report));
  }

  @override
  Future<bool> publishEncodedReport({
    required String entityId,
    required String payload,
    required LatLng position,
  }) async {
    return _upsertVerified(
      _mapper.buildEntityFromPayload(
        entityId: entityId,
        payload: payload,
        position: position,
      ),
    );
  }

  @override
  Future<bool> deletePmcsEntity(String entityId) async {
    try {
      final existing = await _entities.getEntity(entityId);
      if (existing == null) {
        debugPrint('[IvyPulse] Deletion lattice: entity $entityId not on host '
            '— treating as already deleted');
        return true;
      }
      final tombstone = existing.copyWith(
        isLive: false,
        expiryTime: DateTime.now().toUtc(),
      );
      await _entities.upsertEntity(tombstone);

      // Verified for the same reason a publish is: the host can accept an
      // upsert and drop it. Telling an operator a deadlined vehicle was
      // withdrawn while it is still on everyone else's COP is worse than
      // telling them the withdrawal failed.
      final persisted = await _entities.getEntity(entityId);
      if (persisted != null && persisted.isLive == true) {
        debugPrint('[IvyPulse] Deletion lattice: $entityId still live after '
            'tombstone — host did not persist');
        return false;
      }
      debugPrint('[IvyPulse] Deletion lattice: marked $entityId inactive');
      return true;
    } catch (e) {
      debugPrint('[IvyPulse] Deletion lattice error: $e');
      return false;
    }
  }

  /// The host reports success on an upsert it then silently drops, so a
  /// submission is only trusted once it reads back — otherwise the operator
  /// is told the vehicle is on the COP when nobody can see it.
  Future<bool> _upsertVerified(sdk.Entity entity) async {
    try {
      await _entities.upsertEntity(entity);
      final persisted = await _entities.getEntity(entity.id);
      if (persisted == null) {
        debugPrint('[IvyPulse] SDK upsertEntity reported success but '
            'getEntity(${entity.id}) returned null — host did not persist');
        return false;
      }
      debugPrint('[IvyPulse] SDK upsertEntity verified: ${entity.id}');
      return true;
    } catch (e) {
      debugPrint('[IvyPulse] SDK upsertEntity error: $e');
      return false;
    }
  }
}
