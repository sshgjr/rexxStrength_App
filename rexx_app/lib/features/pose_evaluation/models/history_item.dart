import 'evaluation_result.dart';
import 'exercise_phase.dart';

/// 서버에서 내려온 평가 이력 1건
class HistoryItem {
  final int id;
  final ExerciseType exerciseType;
  final int totalScore;
  final String? feedbackText;
  final List<CriterionResult> criteria;
  final List<String> detectedIssues;
  final DateTime createdAt;

  const HistoryItem({
    required this.id,
    required this.exerciseType,
    required this.totalScore,
    required this.feedbackText,
    required this.criteria,
    required this.detectedIssues,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria_scores'];
    final criteria = rawCriteria is List
        ? rawCriteria
            .whereType<Map>()
            .map((c) => _criterionFromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <CriterionResult>[];

    final rawIssues = json['detected_issues'];
    final issues = rawIssues is List
        ? rawIssues.map((e) => e.toString()).toList()
        : <String>[];

    return HistoryItem(
      id: (json['id'] as num).toInt(),
      exerciseType: _exerciseTypeFromApi(json['exercise_type'] as String? ?? ''),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      feedbackText: json['feedback_text'] as String?,
      criteria: criteria,
      detectedIssues: issues,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  /// 상세 화면에서 재사용할 EvaluationResult로 변환
  EvaluationResult toEvaluationResult() {
    return EvaluationResult(
      exerciseType: exerciseType,
      totalScore: totalScore,
      criteria: criteria,
      detectedIssues: detectedIssues,
      evaluatedAt: createdAt,
      feedbackText: feedbackText,
    );
  }
}

CriterionResult _criterionFromJson(Map<String, dynamic> json) {
  final score = (json['score'] as num?)?.toDouble() ?? 0;
  final gradeRaw = json['grade'] as String?;
  return CriterionResult(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    score: score,
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    grade: _gradeFromString(gradeRaw) ?? CriterionGrade.fromScore(score),
  );
}

CriterionGrade? _gradeFromString(String? raw) {
  if (raw == null) return null;
  for (final g in CriterionGrade.values) {
    if (g.name == raw) return g;
  }
  return null;
}

ExerciseType _exerciseTypeFromApi(String apiName) {
  for (final t in ExerciseType.values) {
    if (t.apiName == apiName) return t;
  }
  return ExerciseType.squat;
}
