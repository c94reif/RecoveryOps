import 'package:circle_x/data/mappers/pmcs_storage_codec.dart';

import 'package:flutter/foundation.dart';
import 'package:circle_x/data/dao/sessions/sessions_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';

class SessionsRepoImpl implements SessionsRepository {
  final SessionsDao dao;

  SessionsRepoImpl(this.dao);

  @override
  Future<List<PmcsSession>> getOpenSessions() async {
    final rows = await dao.getOpenSessions();
    final sessions = rows.map(toEntity).whereType<PmcsSession>().toList();
    if (sessions.length != rows.length) {
      debugPrint('[CircleX] getOpenSessions: skipped '
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
      completedPhases: PmcsStorageCodec.encodePhases(session.completedPhases),
      status: session.status.wireName,
      signatureJson: PmcsStorageCodec.encodeSignature(session.signature),
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
      completedPhases: PmcsStorageCodec.encodePhases(session.completedPhases),
      status: session.status.wireName,
      signatureJson: PmcsStorageCodec.encodeSignature(session.signature),
      latitude: session.latitude,
      longitude: session.longitude,
    );
  }

  @override
  Future<void> updateLocation(
          String sessionId, double latitude, double longitude) =>
      dao.updateLocation(sessionId, latitude, longitude);

  @override
  Future<void> deleteBySessionId(String sessionId) =>
      dao.deleteBySessionId(sessionId);

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
      completedPhases: PmcsStorageCodec.decodePhases(row.completedPhases),
      status: tryStatus(row.status) ?? SessionStatus.inProgress,
      signature: PmcsStorageCodec.decodeSignature(row.signatureJson),
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
}
