import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class LiftInputStep extends StatelessWidget {
  final OnboardingInput input;
  final bool submitting;
  final VoidCallback onComplete;
  const LiftInputStep({
    super.key,
    required this.input,
    required this.submitting,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
