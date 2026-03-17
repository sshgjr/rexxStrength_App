import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/evaluation_result.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';

void main() {
  group('CriterionGrade.fromScore', () {
    test('85 이상이면 good', () {
      expect(CriterionGrade.fromScore(85), CriterionGrade.good);
      expect(CriterionGrade.fromScore(100), CriterionGrade.good);
    });

    test('50~84면 warning', () {
      expect(CriterionGrade.fromScore(50), CriterionGrade.warning);
      expect(CriterionGrade.fromScore(84), CriterionGrade.warning);
    });

    test('50 미만이면 bad', () {
      expect(CriterionGrade.fromScore(0), CriterionGrade.bad);
      expect(CriterionGrade.fromScore(49), CriterionGrade.bad);
    });
  });

  group('CriterionGrade.displayName', () {
    test('한국어 표시 이름', () {
      expect(CriterionGrade.good.displayName, '좋음');
      expect(CriterionGrade.warning.displayName, '주의');
      expect(CriterionGrade.bad.displayName, '개선 필요');
    });
  });

  group('EvaluationResult', () {
    final criteria = [
      const CriterionResult(
        name: '무릎 각도',
        description: '무릎 각도 (바텀)',
        score: 90,
        weight: 0.3,
        grade: CriterionGrade.good,
      ),
      const CriterionResult(
        name: '힙 힌지',
        description: '힙 힌지 각도',
        score: 40,
        weight: 0.2,
        grade: CriterionGrade.bad,
      ),
      const CriterionResult(
        name: '척추 각도',
        description: '척추 각도',
        score: 70,
        weight: 0.15,
        grade: CriterionGrade.warning,
      ),
    ];

    final result = EvaluationResult(
      exerciseType: ExerciseType.squat,
      totalScore: 72,
      criteria: criteria,
      detectedIssues: ['힙 힌지 각도: 개선 필요'],
      evaluatedAt: DateTime(2026, 3, 14),
    );

    test('worstCriterion은 가장 낮은 점수 반환', () {
      expect(result.worstCriterion.name, '힙 힌지');
      expect(result.worstCriterion.score, 40);
    });

    test('offlineFeedback 텍스트 생성', () {
      expect(result.offlineFeedback, contains('72'));
      expect(result.offlineFeedback, contains('힙 힌지'));
    });

    test('toJson 변환', () {
      final json = result.toJson();
      expect(json['exercise_type'], 'squat');
      expect(json['total_score'], 72);
      expect(json['criteria_scores'], hasLength(3));
      expect(json['detected_issues'], hasLength(1));
    });

    test('copyWith 피드백 추가', () {
      final updated = result.copyWith(feedbackText: 'AI 피드백');
      expect(updated.feedbackText, 'AI 피드백');
      expect(updated.totalScore, result.totalScore);
    });
  });

  group('ExerciseType', () {
    test('displayName 한국어', () {
      expect(ExerciseType.squat.displayName, '스쿼트');
      expect(ExerciseType.benchPress.displayName, '벤치프레스');
      expect(ExerciseType.deadlift.displayName, '데드리프트');
    });

    test('apiName 영어', () {
      expect(ExerciseType.squat.apiName, 'squat');
      expect(ExerciseType.benchPress.apiName, 'bench_press');
      expect(ExerciseType.deadlift.apiName, 'deadlift');
    });
  });
}
