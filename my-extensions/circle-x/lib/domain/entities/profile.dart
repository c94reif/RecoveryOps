class Profile {
  final String uic;

  const Profile({required this.uic});

  bool get isComplete => uic.trim().isNotEmpty;
}
