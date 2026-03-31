import '../../../services/pose_feedback_service.dart';
import 'exercise_phase.dart';
import '../engine/layer_classifier.dart';

/// 개별 평가 기준의 결과
class CriterionResult {
  final String name;
  final String description;
  final double score;       // 0-100
  final double weight;      // 가중치
  final CriterionGrade grade;

  const CriterionResult({
    required this.name,
    required this.description,
    required this.score,
    required this.weight,
    required this.grade,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'score': score,
        'weight': weight,
        'grade': grade.name,
      };
}

/// 평가 등급
enum CriterionGrade {
  good,    // 85-100
  warning, // 50-84
  bad;     // 0-49

  static CriterionGrade fromScore(double score) {
    if (score >= 85) return CriterionGrade.good;
    if (score >= 50) return CriterionGrade.warning;
    return CriterionGrade.bad;
  }

  String get displayName {
    switch (this) {
      case CriterionGrade.good:
        return '좋음';
      case CriterionGrade.warning:
        return '주의';
      case CriterionGrade.bad:
        return '개선 필요';
    }
  }
}

/// 전체 평가 결과
class EvaluationResult {
  final ExerciseType exerciseType;
  final int totalScore;     // 0-100 가중 평균
  final List<CriterionResult> criteria;
  final List<String> detectedIssues;
  final DateTime evaluatedAt;
  final String? feedbackText; // LLM 피드백 (온라인 시)
  final FeedbackError? feedbackError; // 피드백 실패 원인
  final LayerClassification? layerClassification; // 2-레이어 분류 결과

  const EvaluationResult({
    required this.exerciseType,
    required this.totalScore,
    required this.criteria,
    required this.detectedIssues,
    required this.evaluatedAt,
    this.feedbackText,
    this.feedbackError,
    this.layerClassification,
  });

  EvaluationResult copyWith({
    String? feedbackText,
    FeedbackError? feedbackError,
    LayerClassification? layerClassification,
  }) {
    return EvaluationResult(
      exerciseType: exerciseType,
      totalScore: totalScore,
      criteria: criteria,
      detectedIssues: detectedIssues,
      evaluatedAt: evaluatedAt,
      feedbackText: feedbackText ?? this.feedbackText,
      feedbackError: feedbackError ?? this.feedbackError,
      layerClassification: layerClassification ?? this.layerClassification,
    );
  }

  /// 가장 점수가 낮은 기준 반환
  CriterionResult get worstCriterion {
    return criteria.reduce((a, b) => a.score < b.score ? a : b);
  }

  /// 오프라인 fallback 텍스트 생성
  String get offlineFeedback {
    final worst = worstCriterion;
    return '총점 $totalScore점입니다. ${worst.description}에서 개선이 필요합니다. '
        '인터넷 연결 시 더 자세한 피드백을 받을 수 있습니다.';
  }

  Map<String, dynamic> toJson() => {
        'exercise_type': exerciseType.apiName,
        'total_score': totalScore,
        'criteria_scores': criteria.map((c) => c.toJson()).toList(),
        'detected_issues': detectedIssues,
      };
}
