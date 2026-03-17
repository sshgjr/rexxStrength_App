import '../models/pose_frame.dart';
import 'dart:math';

/// 시뮬레이터용 ML Kit 대체 스텁
/// 실제 포즈 감지 대신 샘플 데이터를 반환합니다.
class PoseDetectorStub {
  /// 프레임 경로 목록에서 mock 포즈 데이터 생성
  Future<List<PoseFrame>> detectPoses(List<String> framePaths) async {
    final poseFrames = <PoseFrame>[];
    final random = Random(42); // 일관된 결과를 위한 고정 시드

    for (int i = 0; i < framePaths.length; i++) {
      // 스쿼트 동작을 시뮬레이션하는 mock 랜드마크 (33개 BlazePose)
      final phase = (i % 20) / 20.0; // 0~1 반복 사이클
      final landmarks = _generateMockLandmarks(phase, random);

      poseFrames.add(PoseFrame(
        frameIndex: i,
        timestamp: i / 5.0, // 5 FPS
        landmarks: landmarks,
      ));
    }

    return poseFrames;
  }

  /// 스쿼트 동작을 시뮬레이션하는 33개 랜드마크 생성
  List<PoseLandmark> _generateMockLandmarks(double phase, Random random) {
    // 기본 직립 자세에서 phase에 따라 무릎/엉덩이 굽힘
    final double depth = sin(phase * pi); // 0 → 1 → 0 사이클

    return List.generate(33, (index) {
      final base = _baseLandmarkPosition(index);
      // 하체 관절에 phase 기반 변형 적용
      final adjusted = _applySquatMotion(index, base, depth);
      final noise = random.nextDouble() * 2 - 1; // -1 ~ 1 노이즈

      return PoseLandmark(
        index: index,
        x: adjusted[0] + noise,
        y: adjusted[1] + noise,
        z: adjusted[2] + noise * 0.5,
        likelihood: 0.85 + random.nextDouble() * 0.15,
      );
    });
  }

  /// BlazePose 인덱스별 기본 좌표 (직립 자세, 정규화된 좌표)
  List<double> _baseLandmarkPosition(int index) {
    const positions = <int, List<double>>{
      0: [0, 0, 0],           // 코
      11: [-80, 200, 0],      // 왼쪽 어깨
      12: [80, 200, 0],       // 오른쪽 어깨
      13: [-120, 350, 0],     // 왼쪽 팔꿈치
      14: [120, 350, 0],      // 오른쪽 팔꿈치
      15: [-130, 500, 0],     // 왼쪽 손목
      16: [130, 500, 0],      // 오른쪽 손목
      23: [-60, 500, 0],      // 왼쪽 엉덩이
      24: [60, 500, 0],       // 오른쪽 엉덩이
      25: [-60, 700, 0],      // 왼쪽 무릎
      26: [60, 700, 0],       // 오른쪽 무릎
      27: [-60, 900, 0],      // 왼쪽 발목
      28: [60, 900, 0],       // 오른쪽 발목
      31: [-60, 930, 30],     // 왼쪽 발
      32: [60, 930, 30],      // 오른쪽 발
    };
    return positions[index] ?? [0, index * 30.0, 0];
  }

  /// 스쿼트 동작에 따른 하체 관절 위치 변형
  List<double> _applySquatMotion(int index, List<double> base, double depth) {
    final x = base[0];
    final y = base[1];
    final z = base[2];

    switch (index) {
      // 엉덩이: 아래로 + 뒤로
      case 23:
      case 24:
        return [x, y + depth * 100, z - depth * 80];
      // 무릎: 앞으로
      case 25:
      case 26:
        return [x, y + depth * 50, z + depth * 60];
      // 발목: 고정
      case 27:
      case 28:
      case 31:
      case 32:
        return base;
      default:
        // 상체는 약간 아래로
        return [x, y + depth * 30, z];
    }
  }

  void close() {}
}
