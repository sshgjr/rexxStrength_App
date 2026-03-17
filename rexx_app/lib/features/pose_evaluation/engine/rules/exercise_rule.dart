import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';

/// 운동별 평가 규칙 추상 인터페이스
abstract class ExerciseRule {
  /// 규칙 이름
  String get name;

  /// 프레임 시퀀스를 평가하여 기준별 결과 반환
  List<CriterionResult> evaluate(List<PoseFrame> frames);
}
