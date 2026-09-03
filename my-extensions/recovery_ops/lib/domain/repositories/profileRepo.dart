import 'package:recovery_ops/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile();
  Future<void> saveProfile(Profile profile);
}
