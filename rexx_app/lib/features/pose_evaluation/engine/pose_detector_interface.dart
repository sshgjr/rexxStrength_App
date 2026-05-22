import '../models/pose_frame.dart';

/// 프레임 시퀀스에서 포즈 랜드마크를 추출하는 디텍터 추상화.
/// 실기기에서는 ML Kit 구현(MLKitPoseDetector), 시뮬레이터에서는 Stub 구현을 주입.
abstract class PoseDetectorInterface {
  /// 프레임 경로 목록을 받아 포즈 프레임 리스트를 반환.
  Future<List<PoseFrame>> detectPoses(List<String> framePaths);

  /// 자원 해제.
  void close();
}
