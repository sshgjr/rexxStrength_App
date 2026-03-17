import 'dart:math';
import 'package:flutter/material.dart';

/// 원형 점수 게이지 위젯 (0-100)
class ScoreGauge extends StatelessWidget {
  final int score;

  const ScoreGauge({super.key, required this.score});

  Color get _scoreColor {
    if (score >= 70) return const Color(0xFF16A34A); // 초록
    if (score >= 50) return const Color(0xFFF59E0B); // 노랑
    return const Color(0xFFEF4444); // 빨강
  }

  String get _gradeText {
    if (score >= 85) return '훌륭해요!';
    if (score >= 70) return '좋아요!';
    if (score >= 50) return '보통이에요';
    return '개선이 필요해요';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(
            painter: _GaugePainter(
              score: score,
              color: _scoreColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      color: _scoreColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    '/ 100',
                    style: TextStyle(
                      color: Color(0xFFA7B9B0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _gradeText,
          style: TextStyle(
            color: _scoreColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 배경 원
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      bgPaint,
    );

    // 점수 아크
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
