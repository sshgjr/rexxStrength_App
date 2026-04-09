import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ExperienceStep extends StatelessWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const ExperienceStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
