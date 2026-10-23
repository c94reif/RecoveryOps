import 'package:circle_x/domain/profile/entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile();
  Future<void> saveProfile(Profile profile);
}
