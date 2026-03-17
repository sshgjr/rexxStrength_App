import 'dart:math';
import '../models/pose_frame.dart';

/// 3D 관절 각도 계산 유틸리티
class AngleCalculator {
  /// 세 점(a, b, c)으로 이루어진 각도 계산 (b가 꼭짓점)
  /// 벡터 BA와 BC의 내적을 이용한 각도 계산
  /// 반환값: 각도 (degrees, 0-180)
  static double calculateAngle(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    // 벡터 BA
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final baZ = a.z - b.z;

    // 벡터 BC
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;
    final bcZ = c.z - b.z;

    // 내적
    final dotProduct = baX * bcX + baY * bcY + baZ * bcZ;

    // 벡터 크기
    final magnitudeBA = sqrt(baX * baX + baY * baY + baZ * baZ);
    final magnitudeBC = sqrt(bcX * bcX + bcY * bcY + bcZ * bcZ);

    if (magnitudeBA == 0 || magnitudeBC == 0) return 0;

    // cos(theta) = dot(BA, BC) / (|BA| * |BC|)
    final cosAngle = (dotProduct / (magnitudeBA * magnitudeBC)).clamp(-1.0, 1.0);
    final angleRadians = acos(cosAngle);

    return angleRadians * 180 / pi;
  }

  /// 수직선(y축) 대비 두 점의 각도 계산
  /// 반환값: 각도 (degrees, 0-180)
  static double calculateVerticalAngle(PoseLandmark top, PoseLandmark bottom) {
    final dx = top.x - bottom.x;
    final dy = top.y - bottom.y;

    // atan2로 수직선 대비 각도 계산
    final angleRadians = atan2(dx.abs(), dy.abs());
    return angleRadians * 180 / pi;
  }

  /// 두 점 사이의 X 좌표 차이 (정렬 확인용)
  static double xDifference(PoseLandmark a, PoseLandmark b) {
    return (a.x - b.x).abs();
  }

  /// 두 점 사이의 Y 좌표 차이 (높이 차이 확인용)
  static double yDifference(PoseLandmark a, PoseLandmark b) {
    return (a.y - b.y).abs();
  }

  /// 좌우 대칭 점수 계산
  /// 두 각도의 차이를 기반으로 0-100 점수 반환
  /// threshold: 이 각도 차이 이내면 만점
  static double symmetryScore(double leftAngle, double rightAngle, {double threshold = 5.0}) {
    final diff = (leftAngle - rightAngle).abs();
    if (diff <= threshold) {
      return 100.0;
    }
    // threshold 초과 시 선형 감점, 최대 20도 차이에서 0점
    final maxDiff = 20.0;
    final score = 100.0 * (1 - (diff - threshold) / (maxDiff - threshold));
    return score.clamp(0.0, 100.0);
  }

  /// 범위 기반 점수 계산
  /// value가 idealMin~idealMax 범위에 있으면 100점
  /// 범위를 벗어나면 선형 감점
  static double rangeScore(
    double value, {
    required double idealMin,
    required double idealMax,
    double tolerance = 20.0,
  }) {
    if (value >= idealMin && value <= idealMax) {
      return 100.0;
    }

    double deviation;
    if (value < idealMin) {
      deviation = idealMin - value;
    } else {
      deviation = value - idealMax;
    }

    final score = 100.0 * (1 - deviation / tolerance);
    return score.clamp(0.0, 100.0);
  }
}
