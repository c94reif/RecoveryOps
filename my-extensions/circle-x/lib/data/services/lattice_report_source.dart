import 'package:flutter/foundation.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/mappers/pmcs_entity_mapper.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/remote_report_source.dart';

class LatticeReportSource implements RemoteReportSource {
  final sdk.EntityService _entities;
  final PmcsEntityMapper _entityMapper;

  LatticeReportSource({
    required sdk.EntityService entities,
    PmcsEntityMapper? entityMapper,
  })  : _entities = entities,
        _entityMapper = entityMapper ?? const PmcsEntityMapper();

  @override
  Future<List<PmcsReport>> fetchRemotePmcsReports() async {
    try {
      final entities = await _entities.getEntities();
      final reports = <PmcsReport>[];
      for (final entity in entities) {
        if (!_entityMapper.isOwnedPmcsEntity(entity)) continue;
        if (entity.isLive == false) continue;
        final report = _entityMapper.parseRemoteEntity(entity);
        if (report != null) reports.add(report);
      }
      return reports;
    } catch (error) {
      debugPrint('[CircleX] fetchRemotePmcsReports error: $error');
      rethrow;
    }
  }

  @override
  Future<Set<String>> fetchKnownPmcsEntityIds() async {
    try {
      final entities = await _entities.getEntities();
      final ids = <String>{};
      for (final entity in entities) {
        if (!_entityMapper.isOwnedPmcsEntity(entity)) continue;
        ids.add(entity.id);
      }
      return ids;
    } catch (error) {
      debugPrint('[CircleX] fetchKnownPmcsEntityIds error: $error');
      rethrow;
    }
  }

  @override
  Future<Set<String>> fetchWithdrawnPmcsEntityIds() async => {
        for (final entity in await _entities.getEntities())
          if (_entityMapper.isOwnedPmcsEntity(entity) && entity.isLive == false)
            entity.id,
      };
}
