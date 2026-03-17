import 'pose_frame.dart';
import 'evaluation_result.dart';

/// 디버그 분석용 데이터 — 프레임 이미지 경로를 보존하여 시각화에 사용
class DebugAnalysisData {
  final List<String> framePaths;
  final List<PoseFrame> poseFrames;
  final EvaluationResult result;

  const DebugAnalysisData({
    required this.framePaths,
    required this.poseFrames,
    required this.result,
  });
}
