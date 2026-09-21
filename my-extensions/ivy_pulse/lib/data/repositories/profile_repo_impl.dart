import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';

class ProfileRepoImpl implements ProfileRepository {
  final ProfileDao dao;

  ProfileRepoImpl(this.dao);

  @override
  Future<Profile?> getProfile() async {
    final data = await dao.getProfile();
    if (data == null) return null;
    return Profile(uic: data.uic);
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await dao.saveProfile(uic: profile.uic);
  }
}
