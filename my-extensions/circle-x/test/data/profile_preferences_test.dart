import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/dao/profile/profile_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/repositories/profile_repo_impl.dart';
import 'package:circle_x/domain/profile/entities/profile.dart';

void main() {
  group('local report units', () {
    test('default UIC remains complete without any new preferences', () {
      const profile = Profile(uic: 'WJ8TAA');
      expect(profile.isComplete, isTrue);
      expect(profile.unitName, isEmpty);
      expect(profile.followedUnits, isEmpty);
      expect(profile.reportUnits.single.label, 'WJ8TAA');
    });

    test('default is first and normalized followed units are valid and unique',
        () {
      const profile =
          Profile(uic: ' wj8taa ', unitName: ' Home unit ', followedUnits: [
        FollowedUnit(uic: 'WJ8TAA', name: 'Duplicate default'),
        FollowedUnit(uic: ' wab4c0 ', name: ' Attached unit '),
        FollowedUnit(uic: 'WAB4C0', name: 'Duplicate followed'),
        FollowedUnit(uic: 'bad'),
        FollowedUnit(uic: 'A-1234'),
        FollowedUnit(uic: ' wcccc1 '),
      ]);
      expect(profile.reportUnits.map((unit) => unit.uic),
          ['WJ8TAA', 'WAB4C0', 'WCCCC1']);
      expect(profile.reportUnits.map((unit) => unit.label),
          ['Home unit (WJ8TAA)', 'Attached unit (WAB4C0)', 'WCCCC1']);
      expect(() => profile.reportUnits.add(const FollowedUnit(uic: 'WDDDD1')),
          throwsUnsupportedError);
    });

    test('invalid default is excluded without hiding valid followed units', () {
      const profile =
          Profile(uic: '', followedUnits: [FollowedUnit(uic: 'wab4c0')]);
      expect(profile.isComplete, isFalse);
      expect(profile.reportUnits.single.uic, 'WAB4C0');
    });
  });

  group('local preference persistence', () {
    late Directory directory;
    late File file;
    late AppDatabase database;
    late ProfileDao dao;
    late ProfileRepoImpl repository;

    void connect() {
      database = AppDatabase.test(NativeDatabase(file));
      dao = ProfileDao(database);
      repository = ProfileRepoImpl(dao);
    }

    setUp(() {
      directory = Directory.systemTemp.createTempSync('circle-x-profile-units');
      file = File('${directory.path}/profile.sqlite');
      connect();
    });
    tearDown(() async {
      await database.close();
      directory.deleteSync(recursive: true);
    });

    test(
        'named units survive a database restart without changing the default UIC',
        () async {
      await repository.saveProfile(const Profile(
        uic: ' wj8taa ',
        unitName: ' Home unit ',
        followedUnits: [
          FollowedUnit(uic: ' wab4c0 ', name: ' Attached unit '),
          FollowedUnit(uic: 'WCCCC1'),
        ],
      ));
      await database.close();
      connect();
      final restored = (await repository.getProfile())!;
      expect(restored.uic, 'WJ8TAA');
      expect(restored.unitName, 'Home unit');
      expect(
          restored.followedUnits.map((unit) => unit.uic), ['WAB4C0', 'WCCCC1']);
      expect(restored.followedUnits.map((unit) => unit.name),
          ['Attached unit', '']);
      expect(restored.reportUnits.map((unit) => unit.label),
          ['Home unit (WJ8TAA)', 'Attached unit (WAB4C0)', 'WCCCC1']);
    });

    test('saving normalizes and deduplicates preferences into one profile row',
        () async {
      await repository.saveProfile(const Profile(uic: 'WJ8TAA'));
      final firstId = (await dao.getProfile())!.id;
      await repository.saveProfile(const Profile(uic: 'WJ8TAA', followedUnits: [
        FollowedUnit(uic: 'wj8taa', name: 'Default duplicate'),
        FollowedUnit(uic: ' wab4c0 ', name: ' First name '),
        FollowedUnit(uic: 'WAB4C0', name: 'Second name'),
        FollowedUnit(uic: 'bad'),
      ]));
      final rows = await database.select(database.profiles).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(jsonDecode(rows.single.followedUnitsJson), [
        {'uic': 'WAB4C0', 'name': 'First name'}
      ]);
    });

    test('spacing aliases persist once while different UIC characters remain',
        () async {
      await repository.saveProfile(const Profile(
        uic: ' wj 8\ttaa ',
        followedUnits: [
          FollowedUnit(uic: 'W J8TAA', name: 'Default duplicate'),
          FollowedUnit(uic: ' wa\u00a0b4 c0 ', name: 'Attached'),
          FollowedUnit(uic: 'WAB4C0', name: 'Spacing duplicate'),
          FollowedUnit(uic: 'wab4co', name: 'Different letters'),
          FollowedUnit(uic: '00 ab12', name: 'Leading zeros'),
        ],
      ));

      final stored = (await dao.getProfile())!;
      expect(stored.uic, 'WJ8TAA');
      expect(jsonDecode(stored.followedUnitsJson), [
        {'uic': 'WAB4C0', 'name': 'Attached'},
        {'uic': 'WAB4CO', 'name': 'Different letters'},
        {'uic': '00AB12', 'name': 'Leading zeros'},
      ]);
      final restored = (await repository.getProfile())!;
      expect(restored.reportUnits.map((unit) => unit.uic),
          ['WJ8TAA', 'WAB4C0', 'WAB4CO', '00AB12']);
    });

    test('malformed stored lists never erase the existing default UIC',
        () async {
      for (final encoded in ['not JSON', '{}', 'null', '42']) {
        await dao.saveProfile(
            uic: ' wj8taa ', unitName: ' Home ', followedUnitsJson: encoded);
        final profile = (await repository.getProfile())!;
        expect(profile.uic, 'WJ8TAA');
        expect(profile.unitName, 'Home');
        expect(profile.followedUnits, isEmpty);
        expect(profile.isComplete, isTrue);
      }
    });

    test('decoding retains valid entries around invalid and duplicate entries',
        () async {
      await dao.saveProfile(
          uic: 'WJ8TAA',
          followedUnitsJson: jsonEncode([
            null,
            'bad',
            7,
            {'name': 'No UIC'},
            {'uic': 123456},
            {'uic': 'ABC!12'},
            {'uic': 'wj8 taa', 'name': 'Default duplicate'},
            {'uic': ' wa\tb4c0 ', 'name': ' Attached '},
            {'uic': 'WAB4C0', 'name': 'Duplicate'},
            {'uic': 'wcccc1', 'name': 7},
          ]));
      final profile = (await repository.getProfile())!;
      expect(
          profile.followedUnits.map((unit) => unit.uic), ['WAB4C0', 'WCCCC1']);
      expect(profile.followedUnits.map((unit) => unit.name), ['Attached', '']);
      expect(() => profile.followedUnits.add(const FollowedUnit(uic: 'WDDDD1')),
          throwsUnsupportedError);
    });

    test('removing all followed units persists an empty list', () async {
      await repository.saveProfile(const Profile(
          uic: 'WJ8TAA',
          unitName: 'Home',
          followedUnits: [FollowedUnit(uic: 'WAB4C0', name: 'Attached')]));
      await repository
          .saveProfile(const Profile(uic: 'WJ8TAA', unitName: 'Home'));
      final profile = (await repository.getProfile())!;
      expect(profile.unitName, 'Home');
      expect(profile.followedUnits, isEmpty);
      expect((await dao.getProfile())!.followedUnitsJson, '[]');
    });
  });
}
