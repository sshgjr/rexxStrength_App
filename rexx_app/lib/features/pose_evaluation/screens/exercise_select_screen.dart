import 'package:flutter/material.dart';
import '../models/exercise_phase.dart';
import 'video_upload_screen.dart';

class ExerciseSelectScreen extends StatelessWidget {
  final String? token;

  const ExerciseSelectScreen({super.key, this.token});

  static const Color bg = Color(0xFF0B0F0C);
  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textMain,
        title: const Text(
          '자세 평가',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운동을 선택하세요',
              style: TextStyle(
                color: textMain,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '영상을 업로드하면 AI가 자세를 분석해드립니다.',
              style: TextStyle(color: textSub, fontSize: 14),
            ),
            const SizedBox(height: 30),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.squat,
              icon: Icons.fitness_center,
              description: '하체 근력의 기본, 올바른 깊이와 자세를 확인하세요.',
            ),
            const SizedBox(height: 16),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.benchPress,
              icon: Icons.airline_seat_flat,
              description: '상체 푸시의 핵심, 팔꿈치 각도와 바 경로를 분석합니다.',
            ),
            const SizedBox(height: 16),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.deadlift,
              icon: Icons.height,
              description: '후면 사슬 강화, 힙 힌지와 등 각도를 평가합니다.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context, {
    required ExerciseType exerciseType,
    required IconData icon,
    required String description,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoUploadScreen(
              exerciseType: exerciseType,
              token: token,
            ),
          ),
        );
        // 로그인 결과가 전달되면 홈 화면으로 전파
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exerciseType.displayName,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: textSub,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textSub, size: 24),
          ],
        ),
      ),
    );
  }
}
