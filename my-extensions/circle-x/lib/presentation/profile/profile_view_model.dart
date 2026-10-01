import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';

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

    final error = Uic.validate(value);
    if (error != null) {
      snackBarMessage = error;
      notifyListeners();
      return;
    }

    await repository.saveProfile(Profile(uic: value));

    savedUic = value;
    isDirty = false;
    hasExistingProfile = true;
    snackBarMessage = 'Default UIC saved';
    notifyListeners();
  }

  static String normalize(String uic) => Uic.normalize(uic);
}
