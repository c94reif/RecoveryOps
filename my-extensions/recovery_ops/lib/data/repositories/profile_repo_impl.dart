import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/domain/entities/profile.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';

class ProfileRepoImpl implements ProfileRepository {
  final ProfileDao dao;

  ProfileRepoImpl(this.dao);

  @override
  Future<Profile?> getProfile() async {
    final data = await dao.getProfile();
    if (data == null) return null;
    return Profile(
      name: data.name,
      callSign: data.callSign,
      unit: data.unit,
    );
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await dao.saveProfile(
      name: profile.name,
      callSign: profile.callSign,
      unit: profile.unit,
    );
  }
}
