import 'package:flutter/foundation.dart';
import 'package:recovery_ops/domain/entities/profile.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileViewModel(this.repository);

  String savedName = '';
  String savedCallSign = '';
  String savedUnit = '';

  bool isLoading = true;
  bool isDirty = false;
  bool hasExistingProfile = false;
  String? snackBarMessage;

  Future<void> loadProfile() async {
    final profile = await repository.getProfile();
    if (profile != null) {
      savedName = profile.name;
      savedCallSign = profile.callSign;
      savedUnit = profile.unit;
      hasExistingProfile = true;
    }
    isLoading = false;
    isDirty = false;
    notifyListeners();
  }

  void checkDirty(String name, String callSign, String unit) {
    final dirty =
        name != savedName || callSign != savedCallSign || unit != savedUnit;
    if (dirty != isDirty) {
      isDirty = dirty;
      notifyListeners();
    }
  }

  Future<void> save(String name, String callSign, String unit) async {
    if (name.isEmpty || unit.isEmpty) {
      snackBarMessage = 'All fields are required';
      notifyListeners();
      return;
    }

    await repository.saveProfile(Profile(
      name: name,
      callSign: callSign,
      unit: unit,
    ));

    savedName = name;
    savedCallSign = callSign;
    savedUnit = unit;
    isDirty = false;
    hasExistingProfile = true;
    snackBarMessage = 'Profile Saved!';
    notifyListeners();
  }
}
