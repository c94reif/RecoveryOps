import 'package:circle_x/domain/entities/uic.dart';

class Profile {
  final String uic;

  const Profile({required this.uic});

  bool get isComplete => Uic.isValid(uic);
}
