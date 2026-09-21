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

    // The UIC is the only thing routing a 5988-E back to the right motor pool,
    // so an empty one is refused rather than quietly stored.
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

  /// A UIC is six upper-case characters on every form it appears on, so it is
  /// stored that way no matter how it was typed.
  static String normalize(String uic) => uic.trim().toUpperCase();
}
