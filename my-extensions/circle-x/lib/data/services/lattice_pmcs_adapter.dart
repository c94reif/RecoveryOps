import 'package:flutter/foundation.dart';
import 'package:circle_x/core/constants/app_constants.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/mappers/pmcs_entity_mapper.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';

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
        debugPrint('[CircleX] Deletion lattice: entity $entityId not on host '
            '— treating as already deleted');
        return true;
      }
      final tombstone = existing.copyWith(
        isLive: false,
        expiryTime: DateTime.now().toUtc().add(AppConstants.entityTtl),
      );
      await _entities.upsertEntity(tombstone);

      final persisted = await _entities.getEntity(entityId);
      if (persisted != null && persisted.isLive != false) {
        debugPrint('[CircleX] Deletion lattice: $entityId still live after '
            'tombstone — host did not persist');
        return false;
      }
      debugPrint('[CircleX] Deletion lattice: marked $entityId inactive');
      return true;
    } catch (error) {
      debugPrint('[CircleX] Deletion lattice error: $error');
      return false;
    }
  }

  Future<bool> _upsertVerified(sdk.Entity entity) async {
    try {
      await _entities.upsertEntity(entity);
      final persisted = await _entities.getEntity(entity.id);
      if (persisted == null ||
          persisted.id != entity.id ||
          persisted.description != entity.description ||
          persisted.isLive == false ||
          !_mapper.isOwnedPmcsEntity(persisted)) {
        debugPrint('[CircleX] SDK upsertEntity reported success but '
            'getEntity(${entity.id}) did not return the published report');
        return false;
      }
      debugPrint('[CircleX] SDK upsertEntity verified: ${entity.id}');
      return true;
    } catch (error) {
      debugPrint('[CircleX] SDK upsertEntity error: $error');
      return false;
    }
  }
}
