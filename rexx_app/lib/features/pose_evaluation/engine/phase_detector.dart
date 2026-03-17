import '../models/pose_frame.dart';
import '../models/exercise_phase.dart';
import 'angle_calculator.dart';

/// 프레임 시퀀스에서 운동 단계를 감지
class PhaseDetector {
  /// 스쿼트 단계 감지: 무릎 각도 기반
  static List<MapEntry<ExercisePhase, int>> detectSquatPhases(List<PoseFrame> frames) {
    final phases = <MapEntry<ExercisePhase, int>>[];
    final kneeAngles = <double>[];

    for (final frame in frames) {
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      final ankle = frame.getLandmark(PoseFrame.leftAnkle);

      if (hip == null || knee == null || ankle == null) {
        kneeAngles.add(180);
        continue;
      }

      kneeAngles.add(AngleCalculator.calculateAngle(hip, knee, ankle));
    }

    if (kneeAngles.isEmpty) return phases;

    // 최소 무릎 각도 인덱스 = 바텀
    double minAngle = 180;
    int bottomIndex = 0;
    for (int i = 0; i < kneeAngles.length; i++) {
      if (kneeAngles[i] < minAngle) {
        minAngle = kneeAngles[i];
        bottomIndex = i;
      }
    }

    // 바텀 전후로 단계 분류
    for (int i = 0; i < frames.length; i++) {
      ExercisePhase phase;
      if (i < bottomIndex * 0.3) {
        phase = ExercisePhase.setup;
      } else if (i < bottomIndex) {
        phase = ExercisePhase.descent;
      } else if (i == bottomIndex) {
        phase = ExercisePhase.bottom;
      } else if (i < frames.length * 0.9) {
        phase = ExercisePhase.ascent;
      } else {
        phase = ExercisePhase.lockout;
      }
      phases.add(MapEntry(phase, i));
    }

    return phases;
  }

  /// 벤치프레스 단계 감지: 팔꿈치 각도 기반
  static List<MapEntry<ExercisePhase, int>> detectBenchPressPhases(List<PoseFrame> frames) {
    final phases = <MapEntry<ExercisePhase, int>>[];
    final elbowAngles = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final elbow = frame.getLandmark(PoseFrame.leftElbow);
      final wrist = frame.getLandmark(PoseFrame.leftWrist);

      if (shoulder == null || elbow == null || wrist == null) {
        elbowAngles.add(180);
        continue;
      }

      elbowAngles.add(AngleCalculator.calculateAngle(shoulder, elbow, wrist));
    }

    if (elbowAngles.isEmpty) return phases;

    double minAngle = 180;
    int bottomIndex = 0;
    for (int i = 0; i < elbowAngles.length; i++) {
      if (elbowAngles[i] < minAngle) {
        minAngle = elbowAngles[i];
        bottomIndex = i;
      }
    }

    for (int i = 0; i < frames.length; i++) {
      ExercisePhase phase;
      if (i < bottomIndex * 0.3) {
        phase = ExercisePhase.setup;
      } else if (i < bottomIndex) {
        phase = ExercisePhase.descent;
      } else if (i == bottomIndex) {
        phase = ExercisePhase.bottom;
      } else if (i < frames.length * 0.9) {
        phase = ExercisePhase.ascent;
      } else {
        phase = ExercisePhase.lockout;
      }
      phases.add(MapEntry(phase, i));
    }

    return phases;
  }

  /// 데드리프트 단계 감지: 힙 각도 기반
  static List<MapEntry<ExercisePhase, int>> detectDeadliftPhases(List<PoseFrame> frames) {
    final phases = <MapEntry<ExercisePhase, int>>[];
    final hipAngles = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);

      if (shoulder == null || hip == null || knee == null) {
        hipAngles.add(180);
        continue;
      }

      hipAngles.add(AngleCalculator.calculateAngle(shoulder, hip, knee));
    }

    if (hipAngles.isEmpty) return phases;

    // 데드리프트는 시작이 바텀 (바닥에서 시작)
    double minAngle = 180;
    int bottomIndex = 0;
    for (int i = 0; i < hipAngles.length; i++) {
      if (hipAngles[i] < minAngle) {
        minAngle = hipAngles[i];
        bottomIndex = i;
      }
    }

    for (int i = 0; i < frames.length; i++) {
      ExercisePhase phase;
      if (i <= bottomIndex) {
        phase = ExercisePhase.setup;
      } else if (i < frames.length * 0.5) {
        phase = ExercisePhase.ascent;
      } else if (i < frames.length * 0.9) {
        phase = ExercisePhase.lockout;
      } else {
        phase = ExercisePhase.lockout;
      }
      phases.add(MapEntry(phase, i));
    }

    return phases;
  }

  /// 바텀/전환 프레임 인덱스 목록 반환 (핵심 평가 구간)
  static List<int> getKeyFrameIndices(List<MapEntry<ExercisePhase, int>> phases) {
    return phases
        .where((e) => e.key == ExercisePhase.bottom || e.key == ExercisePhase.lockout)
        .map((e) => e.value)
        .toList();
  }
}
