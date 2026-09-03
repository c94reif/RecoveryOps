import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/mappers/recoveryEntityMapper.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';

class LatticeEntityAdapter implements RecoveryEntityPort {
  final sdk.EntityService _entities;
  final RecoveryEntityMapper _mapper;

  LatticeEntityAdapter({
    required sdk.EntityService entities,
    RecoveryEntityMapper? mapper,
  })  : _entities = entities,
        _mapper = mapper ?? const RecoveryEntityMapper();

  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    return _upsertVerified(
      _mapper.buildEntity(
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        typeName: typeName,
        vehiclePosition: position,
      ),
    );
  }

  @override
  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {
    final entity = _mapper.buildEntity(
      entityId: entityId,
      bumperNumber: bumperNumber,
      issue: issue,
      typeName: typeName,
      vehiclePosition: vehiclePosition,
      navigatorPosition: navigatorPosition,
      routeGeometry: routeGeometry,
    );
    try {
      await _entities.upsertEntity(entity);
      return true;
    } catch (e) {
      debugPrint('[RecoveryOps] publishNavigatorEntity error: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async {
    try {
      final existing = await _entities.getEntity(entityId);
      if (existing == null) {
        debugPrint(
            '[RecoveryOps] Deletion lattice: entity $entityId not on host '
            '— treating as already deleted');
        return true;
      }
      final tombstone = existing.copyWith(
        isLive: false,
        expiryTime: DateTime.now().toUtc(),
      );
      await _entities.upsertEntity(tombstone);
      debugPrint('[RecoveryOps] Deletion lattice: marked $entityId inactive');
      return true;
    } catch (e) {
      debugPrint('[RecoveryOps] Deletion lattice error: $e');
      return false;
    }
  }

  Future<bool> _upsertVerified(sdk.Entity entity) async {
    try {
      await _entities.upsertEntity(entity);
      final persisted = await _entities.getEntity(entity.id);
      if (persisted == null) {
        debugPrint(
            '[RecoveryOps] SDK upsertEntity reported success but '
            'getEntity(${entity.id}) returned null — host did not persist');
        return false;
      }
      debugPrint('[RecoveryOps] SDK upsertEntity verified: ${entity.id}');
      return true;
    } catch (e) {
      debugPrint('[RecoveryOps] SDK upsertEntity error: $e');
      return false;
    }
  }
}
