import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

/// Step 5. level_source가 'auto'이면 5-A, 'default'이면 5-B 표시.
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

  bool get _isDefault => result.levelSource == 'default';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            _isDefault ? '회원님은 일단' : '회원님의 코칭 등급은',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result.levelIcon,
                size: 36,
                color: result.levelIconColor,
              ),
              const SizedBox(width: 10),
              Text(
                '${result.levelKorean}${_isDefault ? '으로' : ''}',
                style: const TextStyle(
                  color: Color(0xFFE9F5EF),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_isDefault) ...[
            const SizedBox(height: 8),
            const Text('시작할게요',
                style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 16)),
          ],
          const SizedBox(height: 12),
          Text(
            _isDefault ? '' : '자동 산정됨',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
          ),
          const SizedBox(height: 32),
          if (_isDefault) _buildMissingReasons(),
          const SizedBox(height: 24),
          _buildFeedbackPreview(),
          const SizedBox(height: 24),
          _buildSettingsHint(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMissingReasons() {
    final children = <Widget>[];
    children.add(const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        '자동 산정을 못 한 이유:',
        style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
      ),
    ));

    if (explicitSkip) {
      children.add(_bullet('직접 건너뛰기를 선택하셨어요.'));
    } else {
      for (final reason in result.missingReasons) {
        children.add(_bullet(reason.message));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Color(0xFF16A34A))),
            Expanded(
              child: Text(text, style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 13, height: 1.5)),
            ),
          ],
        ),
      );

  Widget _buildFeedbackPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              result.feedbackStylePreview,
              style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHint() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '언제든지 설정에서 변경할 수 있어요',
          style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
        ),
      ],
    );
  }
}
