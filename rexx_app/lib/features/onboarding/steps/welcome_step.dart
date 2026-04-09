import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;
  const WelcomeStep({super.key, required this.onStart, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          const Text(
            '더 정확한 코칭을 위해\n몇 가지만 알려주세요',
            style: TextStyle(
              color: Color(0xFFE9F5EF),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _bullet('약 30초 소요'),
          _bullet('언제든 설정에서 변경 가능'),
          _bullet('모두 선택 입력'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('시작하기', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: const Text(
                '나중에 (초급자로 설정)',
                style: TextStyle(color: Color(0xFFA7B9B0)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Text('• ', style: TextStyle(color: Color(0xFF16A34A), fontSize: 18)),
            Text(text, style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 15)),
          ],
        ),
      );
}
