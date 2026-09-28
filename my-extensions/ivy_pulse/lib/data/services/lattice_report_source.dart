import 'package:flutter/foundation.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/data/mappers/pmcs_entity_mapper.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

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
      debugPrint('[IvyPulse] fetchRemotePmcsReports error: $error');
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
      debugPrint('[IvyPulse] fetchKnownPmcsEntityIds error: $error');
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
