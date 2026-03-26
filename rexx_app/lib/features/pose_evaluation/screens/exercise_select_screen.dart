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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운동 영상을 분석해보세요',
              style: TextStyle(
                color: textMain,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI가 운동 종류를 자동으로 판별하고 자세를 분석합니다.',
              style: TextStyle(color: textSub, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // 자동 분석 버튼
            _buildAutoAnalyzeButton(context),
            const SizedBox(height: 32),
            // 구분선 + 안내 문구
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '또는',
                    style: TextStyle(color: textSub, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '더 빠른 분석을 원하시면 직접 선택하세요',
                style: TextStyle(color: textSub, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            // 기존 3개 운동 카드
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.squat,
              icon: Icons.fitness_center,
              description: '하체 근력의 기본, 올바른 깊이와 자세를 확인하세요.',
            ),
            const SizedBox(height: 12),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.benchPress,
              icon: Icons.airline_seat_flat,
              description: '상체 푸시의 핵심, 팔꿈치 각도와 바 경로를 분석합니다.',
            ),
            const SizedBox(height: 12),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.deadlift,
              icon: Icons.height,
              description: '후면 사슬 강화, 힙 힌지와 등 각도를 평가합니다.',
            ),
            const SizedBox(height: 12),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.wristCurl,
              icon: Icons.front_hand,
              description: '전완 강화, 손목 가동범위와 팔꿈치 고정을 분석합니다.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoAnalyzeButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoUploadScreen(token: token),
            // exerciseType 생략 → null → 자동 분류
          ),
        );
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            SizedBox(height: 12),
            Text(
              '영상으로 자동 분석',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '영상을 업로드하면 운동 종류를 자동으로 판별합니다',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
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
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exerciseType.displayName,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: textSub,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textSub, size: 22),
          ],
        ),
      ),
    );
  }
}
