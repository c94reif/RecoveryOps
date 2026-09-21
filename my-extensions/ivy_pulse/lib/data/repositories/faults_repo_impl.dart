import 'package:drift/drift.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';

class FaultsRepoImpl implements FaultsRepository {
  final PmcsFaultsDao dao;

  FaultsRepoImpl(this.dao);

  @override
  Future<List<PmcsFault>> getForSession(String sessionId) async {
    final rows = await dao.getForSession(sessionId);
    return rows
        .map((pmcsfault) => PmcsFault(
              id: pmcsfault.id,
              sessionId: pmcsfault.sessionId,
              itemId: pmcsfault.itemId,
              phase: PmcsPhase.tryFromWireName(pmcsfault.phase) ?? PmcsPhase.before,
              category: pmcsfault.category,
              subcategory: pmcsfault.subcategory,
              description: pmcsfault.description,
              condition: pmcsfault.condition,
              severity: FaultSeverity.tryFromWireName(pmcsfault.severity) ??
                  FaultSeverity.dash,
              note: pmcsfault.note,
              recordedAt: pmcsfault.recordedAt,
            ))
        .toList();
  }

  @override
  Future<void> replacePhaseFaults(
    String sessionId,
    List<PmcsFault> faults, {
    required String phaseWireName,
  }) async {
    await dao.replacePhaseFaults(
      sessionId,
      phaseWireName,
      faults
          .map((f) => PmcsFaultsCompanion.insert(
                sessionId: sessionId,
                itemId: f.itemId,
                phase: f.phase.wireName,
                category: f.category,
                subcategory: f.subcategory,
                description: f.description,
                condition: f.condition,
                severity: f.severity.wireName,
                note: Value(f.note),
                recordedAt: f.recordedAt,
              ))
          .toList(),
    );
  }

  @override
  Future<void> deleteForSession(String sessionId) =>
      dao.deleteForSession(sessionId);
}
