import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/mappers/navigatorPayloadCodec.dart';
import 'package:recovery_ops/data/mappers/recoveryEntityMapper.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';

class LatticeReportSource implements RemoteReportSource {
  final sdk.EntityService _entities;
  final RecoveryEntityMapper _entityMapper;
  final NavigatorPayloadCodec _navigatorCodec;

  LatticeReportSource({
    required sdk.EntityService entities,
    RecoveryEntityMapper? entityMapper,
    NavigatorPayloadCodec? navigatorCodec,
  })  : _entities = entities,
        _entityMapper = entityMapper ?? const RecoveryEntityMapper(),
        _navigatorCodec = navigatorCodec ?? NavigatorPayloadCodec();

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async {
    try {
      final entities = await _entities.getEntities();
      final reports = <RecoveryReport>[];
      for (final entity in entities) {
        if (!_entityMapper.isOwnedRecoveryEntity(entity)) continue;
        if (entity.isLive == false) continue;
        final report = _entityMapper.parseRemoteEntity(entity);
        if (report != null) reports.add(report);
      }
      return reports;
    } catch (e) {
      debugPrint('[RecoveryOps] fetchRemoteRecoveryReports error: $e');
      return const [];
    }
  }

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async {
    try {
      final entities = await _entities.getEntities();
      final ids = <String>{};
      for (final entity in entities) {
        if (!_entityMapper.isOwnedRecoveryEntity(entity)) continue;
        ids.add(entity.id);
      }
      return ids;
    } catch (e) {
      debugPrint('[RecoveryOps] fetchKnownRecoveryEntityIds error: $e');
      return const {};
    }
  }

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async {
    try {
      final entity = await _entities.getEntity(entityId);
      if (entity == null) return null;
      return _navigatorCodec.parseEntityNavigatorState(entity);
    } catch (e) {
      debugPrint('[RecoveryOps] fetchNavigatorState error for $entityId: $e');
      return null;
    }
  }

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async {
    try {
      final entity = await _entities.getEntity(entityId);
      if (entity == null) {
        debugPrint('[RecoveryOps] fetchEntityGeometry: entity $entityId not found');
        return null;
      }
      final geometry = _entityMapper.extractGeometry(entity);
      if (geometry == null) {
        debugPrint(
            '[RecoveryOps] fetchEntityGeometry: no geometry in entity, '
            'geometry arrives via mesh broadcast');
      }
      return geometry;
    } catch (e) {
      debugPrint('[RecoveryOps] fetchEntityGeometry error: $e');
      return null;
    }
  }
}
