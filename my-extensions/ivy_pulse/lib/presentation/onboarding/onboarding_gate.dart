import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/onboarding/onboarding_page.dart';

class OnboardingGate extends StatefulWidget {
  final Widget child;

  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => OnboardingGateState();
}

class OnboardingGateState extends State<OnboardingGate> {
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
    } catch (error) {
      debugPrint('[IvyPulse] profile read failed, skipping onboarding: $error');
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
