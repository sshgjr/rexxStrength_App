import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class BodyInfoStep extends StatefulWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const BodyInfoStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<BodyInfoStep> createState() => _BodyInfoStepState();
}

class _BodyInfoStepState extends State<BodyInfoStep> {
  final _yearCtrl = TextEditingController();

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('신체 정보',
              style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('성별', style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 8),
          _SexRadio(
            value: widget.input.sex,
            onChanged: (v) => setState(() => widget.input.sex = v),
          ),
          const SizedBox(height: 24),
          const Text('출생연도 (선택)', style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFFE9F5EF)),
            decoration: const InputDecoration(
              hintText: '예: 1995',
              hintStyle: TextStyle(color: Color(0xFF4A5651)),
              filled: true,
              fillColor: Color(0xFF0F1612),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              widget.input.birthYear = int.tryParse(v);
            },
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

class _SexRadio extends StatelessWidget {
  final OnboardingSex? value;
  final ValueChanged<OnboardingSex?> onChanged;
  const _SexRadio({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final option in [...OnboardingSex.values, null])
          ChoiceChip(
            label: Text(option?.label ?? '선택안함'),
            selected: value == option,
            onSelected: (_) => onChanged(option),
            selectedColor: const Color(0xFF16A34A),
            backgroundColor: const Color(0xFF0F1612),
            labelStyle: TextStyle(
              color: value == option ? Colors.white : const Color(0xFFA7B9B0),
            ),
          ),
      ],
    );
  }
}
