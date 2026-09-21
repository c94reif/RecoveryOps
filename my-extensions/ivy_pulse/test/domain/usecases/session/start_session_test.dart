import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeSessionsRepository sessions;
  late FakeLocationRepository location;
  late StartSession usecase;

  setUp(() {
    sessions = FakeSessionsRepository();
    location = FakeLocationRepository(const LatLng(33.5, -84.5));
    usecase = StartSession(
      repository: sessions,
      locationRepository: location,
      clock: FixedClock(DateTime.utc(2026, 3, 24, 6)),
      idGenerator: FakeIdGenerator(['session-abc']),
    );
  });

  Future<PmcsSession> start({
    String bumperNumber = 'a-11',
    VehicleType vehicleType = VehicleType.jltv,
    String uic = 'WJ8TAA',
  }) {
    return usecase(
      bumperNumber: bumperNumber,
      vehicleType: vehicleType,
      uic: uic,
    );
  }

  test('persists the session immediately so nothing is lost', () async {
    await start();

    expect(sessions.sessions, hasLength(1));
  });

  test('returns the session with its assigned row id', () async {
    final session = await start();

    expect(session.id, isNotNull);
    expect(session.sessionId, 'session-abc');
  });

  test('normalises the bumper number to upper case', () async {
    final session = await start(bumperNumber: '  a-11 ');

    expect(session.bumperNumber, 'A-11');
  });

  test('trims and upper-cases the UIC', () async {
    final session = await start(uic: '  wj8taa  ');

    expect(session.uic, 'WJ8TAA');
  });

  test('starts with nobody signed to it — the CAC scan at submit names them',
      () async {
    final session = await start();

    expect(session.operator, '');
  });

  test('stamps the start time from the clock', () async {
    final session = await start();

    expect(session.startedAt, DateTime.utc(2026, 3, 24, 6));
  });

  test('captures the vehicle position for the map', () async {
    final session = await start();

    expect(session.latitude, 33.5);
    expect(session.longitude, -84.5);
  });

  test('starts even when the location bridge returns nothing', () async {
    location.location = null;

    final session = await start();

    expect(session.latitude, isNull);
    expect(session.longitude, isNull);
    expect(sessions.sessions, hasLength(1));
  });

  test('opens in progress with no phases done', () async {
    final session = await start();

    expect(session.status, SessionStatus.inProgress);
    expect(session.completedPhases, isEmpty);
  });

  test('keeps the chosen platform', () async {
    final session = await start(vehicleType: VehicleType.jltv);

    expect(session.vehicleType, VehicleType.jltv);
  });
}
