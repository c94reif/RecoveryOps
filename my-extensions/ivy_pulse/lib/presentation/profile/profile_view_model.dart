import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileViewModel(this.repository);

  String savedUic = '';

  bool isLoading = true;
  bool isDirty = false;
  bool hasExistingProfile = false;
  String? snackBarMessage;

  Future<void> loadProfile() async {
    final profile = await repository.getProfile();
    if (profile != null) {
      savedUic = profile.uic;
      hasExistingProfile = true;
    }
    isLoading = false;
    isDirty = false;
    notifyListeners();
  }

  void checkDirty(String uic) {
    final dirty = normalize(uic) != savedUic;
    if (dirty != isDirty) {
      isDirty = dirty;
      notifyListeners();
    }
  }

  Future<void> save(String uic) async {
    final value = normalize(uic);

    if (value.isEmpty) {
      snackBarMessage = 'UIC is required';
      notifyListeners();
      return;
    }

    await repository.saveProfile(Profile(uic: value));

    savedUic = value;
    isDirty = false;
    hasExistingProfile = true;
    snackBarMessage = 'Profile Saved!';
    notifyListeners();
  }

  static String normalize(String uic) => uic.trim().toUpperCase();
}
