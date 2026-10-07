import 'package:circle_x/domain/entities/followed_unit.dart';
import 'package:circle_x/domain/entities/uic.dart';

export 'package:circle_x/domain/entities/followed_unit.dart';

class Profile {
  final String uic;
  final String unitName;
  final List<FollowedUnit> followedUnits;

  const Profile({
    required this.uic,
    this.unitName = '',
    this.followedUnits = const [],
  });

  bool get isComplete => Uic.isValid(uic);

  /// The submission default comes first; followed units only affect local views.
  List<FollowedUnit> get reportUnits {
    final seen = <String>{};
    final units = <FollowedUnit>[];
    for (final unit in [
      FollowedUnit(uic: uic, name: unitName),
      ...followedUnits
    ]) {
      if (!unit.isValid || !seen.add(unit.normalizedUic)) continue;
      units.add(
          FollowedUnit(uic: unit.normalizedUic, name: unit.normalizedName));
    }
    return List.unmodifiable(units);
  }
}
