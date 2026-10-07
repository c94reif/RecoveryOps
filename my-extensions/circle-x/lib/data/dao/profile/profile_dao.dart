import 'package:drift/drift.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/datasources/local/tables/profile_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Future<ProfileData?> getProfile() async {
    return (select(profiles)..limit(1)).getSingleOrNull();
  }

  Future<void> saveProfile({
    required String uic,
    String unitName = '',
    String followedUnitsJson = '[]',
  }) async {
    final existing = await getProfile();
    if (existing != null) {
      await (update(profiles)..where((table) => table.id.equals(existing.id)))
          .write(
        ProfilesCompanion(
          uic: Value(uic),
          unitName: Value(unitName),
          followedUnitsJson: Value(followedUnitsJson),
        ),
      );
    } else {
      await into(profiles).insert(ProfilesCompanion.insert(
        uic: uic,
        unitName: Value(unitName),
        followedUnitsJson: Value(followedUnitsJson),
      ));
    }
  }
}
