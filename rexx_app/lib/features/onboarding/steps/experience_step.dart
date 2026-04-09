import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ExperienceStep extends StatefulWidget {
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
  State<ExperienceStep> createState() => _ExperienceStepState();
}

class _ExperienceStepState extends State<ExperienceStep> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('운동 경력',
              style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('웨이트 트레이닝을 얼마나 해오셨나요?',
              style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 24),
          for (final exp in OnboardingExperience.values)
            _ExperienceTile(
              experience: exp,
              selected: widget.input.experience == exp,
              onTap: () => setState(() => widget.input.experience = exp),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('건너뛰기', style: TextStyle(color: Color(0xFFA7B9B0))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExperienceTile extends StatelessWidget {
  final OnboardingExperience experience;
  final bool selected;
  final VoidCallback onTap;
  const _ExperienceTile({
    required this.experience,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFF0F1612),
            border: Border.all(
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF1F2925),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? Colors.white : const Color(0xFFA7B9B0),
              ),
              const SizedBox(width: 12),
              Text(
                experience.label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFE9F5EF),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
