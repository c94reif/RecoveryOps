import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/repositories/profile_repo_impl.dart';
import 'package:recovery_ops/domain/entities/profile.dart';

void main() {
  late AppDatabase db;
  late ProfileDao dao;
  late ProfileRepoImpl repo;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    dao = ProfileDao(db);
    repo = ProfileRepoImpl(dao);
  });

  tearDown(() async {
    await db.close();
  });

  test('getProfile returns null when database is empty', () async {
    final profile = await repo.getProfile();
    expect(profile, isNull);
  });

  test('saveProfile then getProfile returns saved data', () async {
    await repo.saveProfile(
        const Profile(name: 'John', callSign: 'Ghost', unit: 'Alpha'));

    final profile = await repo.getProfile();
    expect(profile, isNotNull);
    expect(profile!.name, 'John');
    expect(profile.callSign, 'Ghost');
    expect(profile.unit, 'Alpha');
  });

  test('saveProfile updates existing profile', () async {
    await repo.saveProfile(
        const Profile(name: 'John', callSign: 'Ghost', unit: 'Alpha'));
    await repo.saveProfile(
        const Profile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo'));

    final profile = await repo.getProfile();
    expect(profile!.name, 'Jane');
    expect(profile.callSign, 'Wraith');
    expect(profile.unit, 'Bravo');
  });

  test('returned Profile is a domain entity not a database row', () async {
    await repo.saveProfile(
        const Profile(name: 'John', callSign: 'Ghost', unit: 'Alpha'));

    final profile = await repo.getProfile();
    expect(profile, isA<Profile>());
  });

  test('maps all fields correctly from DAO to entity', () async {
    await dao.saveProfile(name: 'Direct', callSign: 'DaoCall', unit: 'DaoUnit');

    final profile = await repo.getProfile();
    expect(profile!.name, 'Direct');
    expect(profile.callSign, 'DaoCall');
    expect(profile.unit, 'DaoUnit');
  });
}
