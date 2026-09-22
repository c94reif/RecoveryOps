import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/location_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/id_generator.dart';

/// Opens a new PMCS for a vehicle and persists it immediately, so the run
/// survives the app being killed before the first check is answered.
///
/// No operator is stamped here. A walk-around can be started by one Soldier
/// and closed out by another, and the name that matters is the one on the CAC
/// scanned at submit — so the session carries nobody until then.
class StartSession {
  final SessionsRepository repository;
  final LocationRepository locationRepository;
  final Clock clock;
  final IdGenerator idGenerator;

  const StartSession({
    required this.repository,
    required this.locationRepository,
    required this.clock,
    required this.idGenerator,
  });

  Future<PmcsSession> call({
    required String bumperNumber,
    required VehicleType vehicleType,
    required String uic,
  }) async {
    final session = PmcsSession(
      sessionId: idGenerator.newId(),
      bumperNumber: bumperNumber.trim().toUpperCase(),
      vehicleType: vehicleType,
      operator: '',
      uic: uic.trim().toUpperCase(),
      startedAt: clock.nowUtc(),
    );

    final stored = await repository.insert(session);
    unawaited(captureLocation(stored.sessionId));
    return stored;
  }

  Future<void> captureLocation(String sessionId) async {
    try {
      final position = await locationRepository.getCurrentLocation();
      if (position == null) return;
      await repository.updateLocation(
          sessionId, position.latitude, position.longitude);
    } catch (error) {
      debugPrint('[IvyPulse] Location unavailable for $sessionId: $error');
    }
  }
}
