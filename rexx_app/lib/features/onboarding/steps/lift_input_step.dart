import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class LiftInputStep extends StatefulWidget {
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
  State<LiftInputStep> createState() => _LiftInputStepState();
}

class _LiftInputStepState extends State<LiftInputStep> {
  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _deadCtrl = TextEditingController();

  @override
  void dispose() {
    _squatCtrl.dispose();
    _benchCtrl.dispose();
    _deadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text('3대 중량',
                style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('현재 기준 1RM(1회 최대 중량)을 입력해주세요. 모르면 체크박스를 누르세요.',
                style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
            const SizedBox(height: 24),
            _LiftField(
              label: '스쿼트',
              controller: _squatCtrl,
              unknown: widget.input.squatUnknown,
              onValueChanged: (v) => widget.input.squat1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.squatUnknown = v),
            ),
            const SizedBox(height: 16),
            _LiftField(
              label: '벤치프레스',
              controller: _benchCtrl,
              unknown: widget.input.benchUnknown,
              onValueChanged: (v) => widget.input.bench1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.benchUnknown = v),
            ),
            const SizedBox(height: 16),
            _LiftField(
              label: '데드리프트',
              controller: _deadCtrl,
              unknown: widget.input.deadliftUnknown,
              onValueChanged: (v) => widget.input.deadlift1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.deadliftUnknown = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.submitting ? null : widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: widget.submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('완료', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LiftField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool unknown;
  final ValueChanged<double?> onValueChanged;
  final ValueChanged<bool> onUnknownChanged;

  const _LiftField({
    required this.label,
    required this.controller,
    required this.unknown,
    required this.onValueChanged,
    required this.onUnknownChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !unknown,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Color(0xFFE9F5EF)),
                decoration: InputDecoration(
                  hintText: 'kg',
                  hintStyle: const TextStyle(color: Color(0xFF4A5651)),
                  filled: true,
                  fillColor: unknown ? const Color(0xFF1A1F1C) : const Color(0xFF0F1612),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => onValueChanged(double.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Checkbox(
                  value: unknown,
                  onChanged: (v) => onUnknownChanged(v ?? false),
                  activeColor: const Color(0xFF16A34A),
                ),
                const Text('모름', style: TextStyle(color: Color(0xFFA7B9B0))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
