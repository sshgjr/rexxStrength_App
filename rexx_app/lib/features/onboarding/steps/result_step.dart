import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ResultStep extends StatelessWidget {
  final OnboardingResult result;
  final bool explicitSkip;
  final VoidCallback onConfirm;
  const ResultStep({
    super.key,
    required this.result,
    required this.explicitSkip,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
