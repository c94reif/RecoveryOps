import 'package:drift/drift.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/datasources/local/tables/profileTable.dart';

part 'profileDao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Future<ProfileData?> getProfile() async {
    return (select(profiles)..limit(1)).getSingleOrNull();
  }

  Future<void> saveProfile({
    required String name,
    required String callSign,
    required String unit,
  }) async {
    final existing = await getProfile();
    if (existing != null) {
      await (update(profiles)..where((t) => t.id.equals(existing.id))).write(
        ProfilesCompanion(
          name: Value(name),
          callSign: Value(callSign),
          unit: Value(unit),
        ),
      );
    } else {
      await into(profiles).insert(
        ProfilesCompanion.insert(
          name: name,
          callSign: callSign,
          unit: unit,
        ),
      );
    }
  }
}
