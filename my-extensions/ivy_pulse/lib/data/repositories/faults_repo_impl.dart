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
        .map((faultRow) => PmcsFault(
              id: faultRow.id,
              sessionId: faultRow.sessionId,
              itemId: faultRow.itemId,
              phase:
                  PmcsPhase.tryFromWireName(faultRow.phase) ?? PmcsPhase.before,
              category: faultRow.category,
              subcategory: faultRow.subcategory,
              description: faultRow.description,
              condition: faultRow.condition,
              severity: FaultSeverity.tryFromWireName(faultRow.severity) ??
                  FaultSeverity.dash,
              note: faultRow.note,
              recordedAt: faultRow.recordedAt,
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
          .map((fault) => PmcsFaultsCompanion.insert(
                sessionId: sessionId,
                itemId: fault.itemId,
                phase: fault.phase.wireName,
                category: fault.category,
                subcategory: fault.subcategory,
                description: fault.description,
                condition: fault.condition,
                severity: fault.severity.wireName,
                note: Value(fault.note),
                recordedAt: fault.recordedAt,
              ))
          .toList(),
    );
  }

  @override
  Future<void> deleteForSession(String sessionId) =>
      dao.deleteForSession(sessionId);
}
