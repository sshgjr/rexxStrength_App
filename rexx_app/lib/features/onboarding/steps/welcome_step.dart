import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;
  const WelcomeStep({super.key, required this.onStart, required this.onSkip});

  @override
  Widget build(BuildContext context) => const Placeholder();
}
