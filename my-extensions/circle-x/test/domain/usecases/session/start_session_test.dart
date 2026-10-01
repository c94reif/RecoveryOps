import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/usecases/session/start_session.dart';

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

  for (final value in ['', 'W12', 'W12ABCD', 'W12A!C']) {
    test('invalid UIC $value cannot create a session', () async {
      await expectLater(start(uic: value), throwsArgumentError);
      expect(sessions.sessions, isEmpty);
    });
  }

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

    await Future<void>.delayed(Duration.zero);
    final saved = await sessions.getBySessionId(session.sessionId);
    expect(saved!.latitude, 33.5);
    expect(saved.longitude, -84.5);
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
