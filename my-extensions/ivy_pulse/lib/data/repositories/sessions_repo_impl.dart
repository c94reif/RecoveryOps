import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';

class SessionsRepoImpl implements SessionsRepository {
  final SessionsDao dao;

  SessionsRepoImpl(this.dao);

  @override
  Future<List<PmcsSession>> getOpenSessions() async {
    final rows = await dao.getOpenSessions();
    final sessions = rows.map(toEntity).whereType<PmcsSession>().toList();
    if (sessions.length != rows.length) {
      debugPrint('[IvyPulse] getOpenSessions: skipped '
          '${rows.length - sessions.length} row(s) for an unknown platform');
    }
    return sessions;
  }

  @override
  Future<PmcsSession?> getBySessionId(String sessionId) async {
    final row = await dao.getBySessionId(sessionId);
    if (row == null) return null;
    return toEntity(row);
  }

  @override
  Future<PmcsSession> insert(PmcsSession session) async {
    final id = await dao.insertSession(
      sessionId: session.sessionId,
      bumperNumber: session.bumperNumber,
      vehicleType: session.vehicleType.wireName,
      operator: session.operator,
      uic: session.uic,
      startedAt: session.startedAt,
      submittedAt: session.submittedAt,
      completedPhases: encodePhases(session.completedPhases),
      status: session.status.wireName,
      signatureJson: encodeSignature(session.signature),
      latitude: session.latitude,
      longitude: session.longitude,
    );
    return session.copyWith(id: id);
  }

  @override
  Future<void> update(PmcsSession session) async {
    await dao.updateSession(
      sessionId: session.sessionId,
      bumperNumber: session.bumperNumber,
      vehicleType: session.vehicleType.wireName,
      operator: session.operator,
      uic: session.uic,
      submittedAt: session.submittedAt,
      completedPhases: encodePhases(session.completedPhases),
      status: session.status.wireName,
      signatureJson: encodeSignature(session.signature),
      latitude: session.latitude,
      longitude: session.longitude,
    );
  }

  @override
  Future<void> deleteBySessionId(String sessionId) =>
      dao.deleteBySessionId(sessionId);

  /// Null when the row names a platform this build has no catalog for.
  ///
  /// The row is left on disk rather than deleted — a later build that carries
  /// the platform can still resume it — but it is not offered now, because a
  /// PMCS with no checklist behind it is not walkable. Decoding is tolerant
  /// throughout for the same reason: a row written by a newer build must not
  /// throw and take the operator's whole resume list with it.
  static PmcsSession? toEntity(PmcsSessionData row) {
    final vehicleType = VehicleType.tryFromWireName(row.vehicleType);
    if (vehicleType == null) return null;

    return PmcsSession(
      id: row.id,
      sessionId: row.sessionId,
      bumperNumber: row.bumperNumber,
      vehicleType: vehicleType,
      operator: row.operator,
      uic: row.uic,
      startedAt: row.startedAt,
      submittedAt: row.submittedAt,
      completedPhases: decodePhases(row.completedPhases),
      // An unreadable status reads as still in progress: showing a Soldier a
      // PMCS they may have already sent beats hiding one they have not.
      status: tryStatus(row.status) ?? SessionStatus.inProgress,
      signature: decodeSignature(row.signatureJson),
      latitude: row.latitude,
      longitude: row.longitude,
    );
  }

  static SessionStatus? tryStatus(String value) {
    for (final status in SessionStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  static String encodePhases(List<PmcsPhase> phases) =>
      phases.map((p) => p.wireName).join(',');

  static String? encodeSignature(PmcsSignature? signature) =>
      signature == null ? null : jsonEncode(signature.toMap());

  /// A garbled signature blob reads as no signature, which reads as
  /// unverified — never as a scan that happened.
  static PmcsSignature? decodeSignature(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return PmcsSignature.fromMap(jsonDecode(json) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  /// Unknown wire names are dropped rather than thrown on — a row written by a
  /// newer build must not lock the operator out of resuming their PMCS.
  static List<PmcsPhase> decodePhases(String value) {
    if (value.isEmpty) return const [];
    return value
        .split(',')
        .map(PmcsPhase.tryFromWireName)
        .whereType<PmcsPhase>()
        .toList();
  }
}
