import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/models/evaluation_result.dart';
import 'package:rexx_app/features/pose_evaluation/engine/rules/wrist_curl_rules.dart';

PoseLandmark _lm(int index, double x, double y, {double z = 0, double likelihood = 0.9}) {
  return PoseLandmark(index: index, x: x, y: y, z: z, likelihood: likelihood);
}

List<PoseFrame> _goodWristCurlFrames() {
  final frames = <PoseFrame>[];
  final wristAngles = [170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0];

  final elbowX = 0.5;
  final elbowY = 0.4;
  final wristX = 0.5;
  final wristY = 0.55;
  final baseAngle = atan2(wristY - elbowY, wristX - elbowX);

  for (int i = 0; i < wristAngles.length; i++) {
    final targetRad = wristAngles[i] * pi / 180;
    final indexAngle = baseAngle + (pi - targetRad);
    final radius = 0.1;
    final indexX = wristX + radius * cos(indexAngle);
    final indexY = wristY + radius * sin(indexAngle);

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.5, 0.25),
        _lm(PoseFrame.rightShoulder, 0.5, 0.25, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, elbowX, elbowY),
        _lm(PoseFrame.rightElbow, elbowX, elbowY, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, wristY),
        _lm(PoseFrame.rightWrist, wristX, wristY, likelihood: 0.5),
        _lm(PoseFrame.leftIndex, indexX, indexY),
        _lm(PoseFrame.rightIndex, indexX, indexY, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, 0.6),
        _lm(PoseFrame.rightHip, 0.5, 0.6, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.9),
        _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

void main() {
  group('WristCurlRules', () {
    late WristCurlRules rules;

    setUp(() {
      rules = WristCurlRules();
    });

    test('name은 리스트컬이다', () {
      expect(rules.name, '리스트컬');
    });

    test('evaluate는 5개 기준을 반환한다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      expect(results.length, 5);
    });

    test('가중치 합은 1.0이다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      final weightSum = results.fold(0.0, (sum, c) => sum + c.weight);
      expect(weightSum, closeTo(1.0, 0.01));
    });

    test('좋은 자세면 총점이 50 이상이다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      final totalScore = results.fold(0.0, (sum, c) => sum + c.score * c.weight);
      expect(totalScore, greaterThan(50));
    });

    test('likelihood 낮은 프레임은 무시된다', () {
      final frames = _goodWristCurlFrames().map((f) {
        final landmarks = f.landmarks.map((lm) {
          if (lm.index == PoseFrame.leftIndex || lm.index == PoseFrame.rightIndex) {
            return PoseLandmark(index: lm.index, x: lm.x, y: lm.y, z: lm.z, likelihood: 0.1);
          }
          return lm;
        }).toList();
        return PoseFrame(frameIndex: f.frameIndex, timestamp: f.timestamp, landmarks: landmarks);
      }).toList();

      final results = rules.evaluate(frames);
      expect(results.length, 5);
    });
  });
}
