import 'dart:convert';

import 'package:circle_x/data/dao/profile/profile_dao.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';

class ProfileRepoImpl implements ProfileRepository {
  final ProfileDao dao;

  ProfileRepoImpl(this.dao);

  @override
  Future<Profile?> getProfile() async {
    final data = await dao.getProfile();
    if (data == null) return null;
    final uic = Uic.normalize(data.uic);
    return Profile(
      uic: uic,
      unitName: data.unitName.trim(),
      followedUnits: _normalizeUnits(_decodeUnits(data.followedUnitsJson), uic),
    );
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    final uic = Uic.normalize(profile.uic);
    final followed = _normalizeUnits(profile.followedUnits, uic);
    await dao.saveProfile(
      uic: uic,
      unitName: profile.unitName.trim(),
      followedUnitsJson: jsonEncode([
        for (final unit in followed) {'uic': unit.uic, 'name': unit.name},
      ]),
    );
  }

  static List<FollowedUnit> _decodeUnits(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map && entry['uic'] is String)
            FollowedUnit(
              uic: entry['uic'] as String,
              name: entry['name'] is String ? entry['name'] as String : '',
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  static List<FollowedUnit> _normalizeUnits(
      List<FollowedUnit> units, String defaultUic) {
    final seen = <String>{defaultUic};
    return List.unmodifiable([
      for (final unit in units)
        if (unit.isValid && seen.add(unit.normalizedUic))
          FollowedUnit(uic: unit.normalizedUic, name: unit.normalizedName),
    ]);
  }
}
