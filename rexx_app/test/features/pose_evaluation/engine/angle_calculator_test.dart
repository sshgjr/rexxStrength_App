import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/engine/angle_calculator.dart';

PoseLandmark _lm(double x, double y, {double z = 0}) {
  return PoseLandmark(index: 0, x: x, y: y, z: z, likelihood: 1.0);
}

void main() {
  group('AngleCalculator.calculateAngle', () {
    test('직각 (90도)', () {
      // (1,0) - (0,0) - (0,1) → 90도
      final a = _lm(1, 0);
      final b = _lm(0, 0);
      final c = _lm(0, 1);
      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(90.0, 0.01));
    });

    test('일직선 (180도)', () {
      // (-1,0) - (0,0) - (1,0) → 180도
      final a = _lm(-1, 0);
      final b = _lm(0, 0);
      final c = _lm(1, 0);
      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(180.0, 0.01));
    });

    test('같은 방향 (0도)', () {
      // (1,0) - (0,0) - (2,0) → 0도
      final a = _lm(1, 0);
      final b = _lm(0, 0);
      final c = _lm(2, 0);
      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(0.0, 0.01));
    });

    test('3D 각도 계산', () {
      final a = _lm(1, 0, z: 0);
      final b = _lm(0, 0, z: 0);
      final c = _lm(0, 0, z: 1);
      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(90.0, 0.01));
    });

    test('같은 점이면 0 반환', () {
      final p = _lm(1, 1);
      final angle = AngleCalculator.calculateAngle(p, p, p);
      expect(angle, 0.0);
    });
  });

  group('AngleCalculator.symmetryScore', () {
    test('동일한 각도면 100점', () {
      expect(AngleCalculator.symmetryScore(90, 90), 100.0);
    });

    test('threshold 이내면 100점', () {
      expect(AngleCalculator.symmetryScore(90, 94), 100.0);
    });

    test('큰 차이면 0점', () {
      expect(AngleCalculator.symmetryScore(90, 115), 0.0);
    });

    test('중간 차이면 중간 점수', () {
      final score = AngleCalculator.symmetryScore(90, 100);
      expect(score, greaterThan(0));
      expect(score, lessThan(100));
    });
  });

  group('AngleCalculator.rangeScore', () {
    test('이상 범위 내면 100점', () {
      expect(AngleCalculator.rangeScore(85, idealMin: 80, idealMax: 90), 100.0);
    });

    test('범위 미만이면 감점', () {
      final score = AngleCalculator.rangeScore(70, idealMin: 80, idealMax: 90, tolerance: 20);
      expect(score, closeTo(50.0, 0.01));
    });

    test('범위 초과이면 감점', () {
      final score = AngleCalculator.rangeScore(100, idealMin: 80, idealMax: 90, tolerance: 20);
      expect(score, closeTo(50.0, 0.01));
    });

    test('tolerance 초과이면 0점', () {
      expect(AngleCalculator.rangeScore(60, idealMin: 80, idealMax: 90, tolerance: 20), 0.0);
    });
  });

  group('AngleCalculator.calculateVerticalAngle', () {
    test('수직이면 0도', () {
      final top = _lm(0, 10);
      final bottom = _lm(0, 0);
      expect(AngleCalculator.calculateVerticalAngle(top, bottom), closeTo(0.0, 0.01));
    });

    test('45도 기울기', () {
      final top = _lm(5, 5);
      final bottom = _lm(0, 0);
      expect(AngleCalculator.calculateVerticalAngle(top, bottom), closeTo(45.0, 0.01));
    });
  });

  group('AngleCalculator.positionStability', () {
    test('좌표가 고정이면 100점', () {
      final positions = [
        _lm(0.5, 0.5),
        _lm(0.5, 0.5),
        _lm(0.5, 0.5),
      ];
      expect(AngleCalculator.positionStability(positions, 0.6), 100.0);
    });

    test('좌표 이동이 크면 0점', () {
      final positions = [
        _lm(0.1, 0.1),
        _lm(0.5, 0.5),
        _lm(0.9, 0.9),
      ];
      final score = AngleCalculator.positionStability(positions, 0.6);
      expect(score, 0.0);
    });

    test('중간 이동이면 중간 점수', () {
      final positions = [
        _lm(0.5, 0.5),
        _lm(0.52, 0.51),
        _lm(0.49, 0.50),
      ];
      final score = AngleCalculator.positionStability(positions, 0.6);
      expect(score, greaterThan(0));
      expect(score, lessThan(100));
    });
  });
}
