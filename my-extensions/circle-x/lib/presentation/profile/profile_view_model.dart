import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;
  final Future<void> Function(Profile)? onSaved;

  ProfileViewModel(this.repository, {this.onSaved});

  String savedUic = '';
  String savedUnitName = '';
  List<FollowedUnit> followedUnits = const [];
  String _draftUic = '';
  String _draftUnitName = '';
  bool _disposed = false;

  bool isLoading = true;
  bool isSaving = false;
  bool isDirty = false;
  bool hasExistingProfile = false;
  String? snackBarMessage;
  String? errorMessage;

  Future<void> loadProfile() async {
    try {
      final profile = await repository.getProfile();
      if (_disposed) return;
      if (profile != null) _restore(profile, resetDraft: true);
      errorMessage = null;
    } catch (_) {
      errorMessage = 'Could not load your unit settings. Try again.';
      snackBarMessage = errorMessage;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void checkDirty(String uic, {String? unitName}) {
    _draftUic = normalize(uic);
    _draftUnitName = (unitName ?? savedUnitName).trim();
    final dirty = _draftUic != savedUic || _draftUnitName != savedUnitName;
    if (dirty != isDirty) {
      isDirty = dirty;
      _notify();
    }
  }

  Future<bool> save(String uic, {String? unitName}) => _commit((current) {
        final value = normalize(uic);
        _requireValid(value);
        final followed = current.followedUnits;
        if (followed.any((unit) => normalize(unit.uic) == value)) {
          throw const FormatException(
              'This UIC is already followed. Remove it there before making it your default.');
        }
        return Profile(
          uic: value,
          unitName: (unitName ?? current.unitName).trim(),
          followedUnits: followed,
        );
      }, message: 'Default UIC saved', resetDraft: true);

  String? followedUnitError(String uic, {String? editingUic}) {
    final value = normalize(uic);
    final error = Uic.validate(value);
    if (error != null) return error;
    if (value == savedUic) return 'This is already your default UIC.';
    if (followedUnits.any((unit) =>
        normalize(unit.uic) == value &&
        normalize(unit.uic) != normalize(editingUic ?? ''))) {
      return 'You already follow this UIC.';
    }
    return null;
  }

  Future<bool> addFollowedUnit(String uic, {String name = ''}) =>
      _saveFollowedUnit(uic, name: name);

  Future<bool> updateFollowedUnit(String originalUic, String uic,
          {String name = ''}) =>
      _saveFollowedUnit(uic, name: name, originalUic: originalUic);

  Future<bool> _saveFollowedUnit(String uic,
          {required String name, String? originalUic}) =>
      _commit((current) {
        final value = normalize(uic);
        _requireValid(value);
        if (!current.isComplete) {
          throw const FormatException('Save a default UIC first.');
        }
        if (value == normalize(current.uic)) {
          throw const FormatException('This is already your default UIC.');
        }
        final previous = originalUic == null ? null : normalize(originalUic);
        final units = current.reportUnits
            .where((unit) => unit.uic != normalize(current.uic))
            .toList();
        if (units.any((unit) => unit.uic == value && unit.uic != previous)) {
          throw const FormatException('You already follow this UIC.');
        }
        final replacement = FollowedUnit(uic: value, name: name.trim());
        if (previous == null) {
          units.add(replacement);
        } else {
          final index = units.indexWhere((unit) => unit.uic == previous);
          if (index < 0) {
            throw const FormatException('This followed unit no longer exists.');
          }
          units[index] = replacement;
        }
        return Profile(
            uic: current.uic, unitName: current.unitName, followedUnits: units);
      },
          message:
              originalUic == null ? 'Unit followed' : 'Followed unit saved');

  Future<bool> removeFollowedUnit(String uic) => _commit((current) {
        final value = normalize(uic);
        if (value == normalize(current.uic)) {
          throw const FormatException('Change your default UIC above.');
        }
        return Profile(
          uic: current.uic,
          unitName: current.unitName,
          followedUnits: current.followedUnits
              .where((unit) => normalize(unit.uic) != value)
              .toList(),
        );
      }, message: 'Unit removed from your followed units');

  Future<bool> _commit(Profile Function(Profile) change,
      {required String message, bool resetDraft = false}) async {
    if (isSaving || _disposed) return false;
    isSaving = true;
    errorMessage = null;
    _notify();
    try {
      // Read the latest settings so changing the default never overwrites a
      // followed-unit edit saved by another view of the profile.
      final current = await repository.getProfile() ?? const Profile(uic: '');
      final next = change(current);
      await repository.saveProfile(next);
      _restore(next, resetDraft: resetDraft);
      snackBarMessage = message;
      try {
        await onSaved?.call(next);
      } catch (error) {
        debugPrint('[CircleX] Could not refresh saved unit filters: $error');
      }
      return true;
    } on FormatException catch (error) {
      errorMessage = error.message;
      snackBarMessage = errorMessage;
      return false;
    } catch (_) {
      errorMessage = 'Could not save your unit settings. Try again.';
      snackBarMessage = errorMessage;
      return false;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  void _restore(Profile profile, {required bool resetDraft}) {
    savedUic = normalize(profile.uic);
    savedUnitName = profile.unitName.trim();
    followedUnits = List.unmodifiable(
        profile.reportUnits.where((unit) => unit.uic != savedUic));
    hasExistingProfile = true;
    if (resetDraft) {
      _draftUic = savedUic;
      _draftUnitName = savedUnitName;
    }
    isDirty = _draftUic != savedUic || _draftUnitName != savedUnitName;
  }

  static void _requireValid(String value) {
    final error = Uic.validate(value);
    if (error != null) throw FormatException(error);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String normalize(String uic) => Uic.normalize(uic);
}
