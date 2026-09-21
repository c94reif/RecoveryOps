import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/onboarding/onboarding_page.dart';

/// Shows [OnboardingPage] on a device with no UIC stored, and [child] once
/// there is one.
///
/// The shell is held back rather than layered over, so the PMCS tab does not
/// read the profile until after onboarding has written it — a gate that only
/// covered the screen would leave [InspectionViewModel.load] racing the save.
class OnboardingGate extends StatefulWidget {
  /// The real app shell, built only once a UIC exists.
  final Widget child;

  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => OnboardingGateState();
}

class OnboardingGateState extends State<OnboardingGate> {
  /// Null while the stored profile is still being read.
  bool? needsOnboarding;

  @override
  void initState() {
    super.initState();
    checkProfile();
  }

  Future<void> checkProfile() async {
    Profile? profile;
    var readFailed = false;
    try {
      profile = await getIt<ProfileRepository>().getProfile();
    } catch (e) {
      // Fail open. A storage error is not evidence the operator has no UIC,
      // and onboarding is the one screen with no way past — a save would hit
      // the same broken store and strand them on it.
      debugPrint('[IvyPulse] profile read failed, skipping onboarding: $e');
      readFailed = true;
    }
    if (!mounted) return;
    setState(() {
      needsOnboarding = !readFailed && !(profile?.isComplete ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (needsOnboarding) {
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
      true => OnboardingPage(
          onComplete: () => setState(() => needsOnboarding = false),
        ),
      false => widget.child,
    };
  }
}
