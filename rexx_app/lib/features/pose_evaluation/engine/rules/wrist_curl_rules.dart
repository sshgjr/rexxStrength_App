import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import 'exercise_rule.dart';

/// 리스트컬 평가 규칙 (구현은 Task 4에서 완성)
class WristCurlRules implements ExerciseRule {
  @override
  String get name => '리스트컬';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [];
  }
}
