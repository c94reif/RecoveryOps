/// The unit the operator is signed for, stamped onto every PMCS they submit.
///
/// Only the UIC is kept. Who walked the vehicle is not a setting a Soldier
/// types once and forgets — it is read off their CAC at the moment they close
/// the PMCS out, so the name on a 5988-E is the name of whoever actually
/// signed for it. See [CacIdentity].
class Profile {
  /// Unit Identification Code — six characters, e.g. `WJ8TAA`. What a
  /// maintainer routes a 5988-E by.
  final String uic;

  const Profile({required this.uic});

  bool get isComplete => uic.trim().isNotEmpty;
}
