import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';

void main() {
  group('PoseLandmark', () {
    test('toJson / fromJson 왕복 변환', () {
      const lm = PoseLandmark(index: 11, x: 0.5, y: 0.6, z: 0.1, likelihood: 0.99);
      final json = lm.toJson();
      final restored = PoseLandmark.fromJson(json);

      expect(restored.index, 11);
      expect(restored.x, 0.5);
      expect(restored.y, 0.6);
      expect(restored.z, 0.1);
      expect(restored.likelihood, 0.99);
    });
  });

  group('PoseFrame', () {
    final landmarks = [
      const PoseLandmark(index: 11, x: 0.3, y: 0.4, z: 0.0, likelihood: 0.95),
      const PoseLandmark(index: 23, x: 0.3, y: 0.6, z: 0.0, likelihood: 0.90),
      const PoseLandmark(index: 25, x: 0.3, y: 0.8, z: 0.0, likelihood: 0.88),
    ];

    final frame = PoseFrame(frameIndex: 0, timestamp: 0.0, landmarks: landmarks);

    test('getLandmark 존재하는 인덱스', () {
      final lm = frame.getLandmark(PoseFrame.leftShoulder);
      expect(lm, isNotNull);
      expect(lm!.index, 11);
    });

    test('getLandmark 존재하지 않는 인덱스', () {
      final lm = frame.getLandmark(PoseFrame.rightShoulder);
      expect(lm, isNull);
    });

    test('랜드마크 상수 값 확인', () {
      expect(PoseFrame.leftShoulder, 11);
      expect(PoseFrame.rightShoulder, 12);
      expect(PoseFrame.leftHip, 23);
      expect(PoseFrame.leftKnee, 25);
      expect(PoseFrame.leftAnkle, 27);
    });

    test('검지 랜드마크 상수 값', () {
      expect(PoseFrame.leftIndex, 19);
      expect(PoseFrame.rightIndex, 20);
    });
  });
}
