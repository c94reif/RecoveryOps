import 'package:circle_x/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile();
  Future<void> saveProfile(Profile profile);
}
