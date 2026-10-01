import 'dart:async';
import 'package:circle_x/domain/services/diagnostic_logger.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/domain/repositories/location_repo.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/id_generator.dart';

class StartSession {
  final DiagnosticLogger logger;
  final SessionsRepository repository;
  final LocationRepository locationRepository;
  final Clock clock;
  final IdGenerator idGenerator;

  const StartSession({
    this.logger = const SilentDiagnosticLogger(),
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
    final error = Uic.validate(uic);
    if (error != null) throw ArgumentError(error);
    final session = PmcsSession(
      sessionId: idGenerator.newId(),
      bumperNumber: bumperNumber.trim().toUpperCase(),
      vehicleType: vehicleType,
      operator: '',
      uic: Uic.normalize(uic),
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
      logger.log('[CircleX] Location unavailable for $sessionId: $error');
    }
  }
}
