import 'package:circle_x/domain/entities/uic.dart';

class FollowedUnit {
  final String uic;
  final String name;

  const FollowedUnit({required this.uic, this.name = ''});

  String get normalizedUic => Uic.normalize(uic);
  String get normalizedName => name.trim();
  bool get isValid => Uic.isValid(uic);
  String get label => normalizedName.isEmpty
      ? normalizedUic
      : '$normalizedName ($normalizedUic)';
}
