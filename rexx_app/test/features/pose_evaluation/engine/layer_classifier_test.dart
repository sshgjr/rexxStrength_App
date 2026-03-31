import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/engine/layer_classifier.dart';
import 'package:rexx_app/features/pose_evaluation/models/evaluation_result.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';

void main() {
  late LayerClassifier classifier;

  setUp(() {
    classifier = LayerClassifier.fromMap({
      'squat': {
        'layer1': [
          {'criterion': '척추 각도', 'reason': '요추 과굴곡 → 허리 부상 위험'},
          {'criterion': '무릎-발끝 정렬', 'reason': '무릎 cave-in → ACL 부상 위험'},
        ],
        'layer2': [
          {'criterion': '무릎 각도', 'reason': '스쿼트 깊이는 스타일 차이'},
          {'criterion': '힙 힌지', 'reason': '하이바/로우바 스타일'},
          {'criterion': '좌우 대칭', 'reason': '경미한 비대칭은 자연스러운 개인차'},
        ],
      },
    });
  });

  group('LayerClassifier.classify', () {
    test('Bad 등급 L1 기준은 layer1Issues에 분류', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 90, weight: 0.30, grade: CriterionGrade.good),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer1Issues.length, 1);
      expect(result.layer1Issues.first.criterion.name, '척추 각도');
      expect(result.layer2Issues, isEmpty);
    });

    test('Warning 등급 L2 기준은 layer2Issues에 분류', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 90, weight: 0.15, grade: CriterionGrade.good),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 60, weight: 0.30, grade: CriterionGrade.warning),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer1Issues, isEmpty);
      expect(result.layer2Issues.length, 1);
      expect(result.layer2Issues.first.criterion.name, '무릎 각도');
    });

    test('Good 등급 기준은 이슈로 분류되지 않음', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 90, weight: 0.15, grade: CriterionGrade.good),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 95, weight: 0.30, grade: CriterionGrade.good),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.hasNoIssues, isTrue);
    });

    test('설정에 없는 기준은 L2로 기본 분류', () {
      final criteria = [
        const CriterionResult(name: '알 수 없는 기준', description: '알 수 없음', score: 40, weight: 0.10, grade: CriterionGrade.bad),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer2Issues.length, 1);
      expect(result.layer1Issues, isEmpty);
    });

    test('hasLayer1, hasLayer2Only 플래그 정확성', () {
      final l1Only = classifier.classify([
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad),
      ], ExerciseType.squat);
      expect(l1Only.hasLayer1, isTrue);
      expect(l1Only.hasLayer2Only, isFalse);

      final l2Only = classifier.classify([
        const CriterionResult(name: '힙 힌지', description: '힙 힌지 각도', score: 60, weight: 0.20, grade: CriterionGrade.warning),
      ], ExerciseType.squat);
      expect(l2Only.hasLayer1, isFalse);
      expect(l2Only.hasLayer2Only, isTrue);
    });
  });

  group('FeedbackDecision', () {
    test('L1 감지 시 등급 무관 출력', () {
      final classification = LayerClassification(
        layer1Issues: [LayerIssue(criterion: const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad), reason: '부상 위험')],
        layer2Issues: [],
      );

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isTrue);
    });

    test('L2만 감지 시 상급자는 피드백 스킵', () {
      final classification = LayerClassification(
        layer1Issues: [],
        layer2Issues: [LayerIssue(criterion: const CriterionResult(name: '힙 힌지', description: '힙 힌지 각도', score: 60, weight: 0.20, grade: CriterionGrade.warning), reason: '스타일')],
      );

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isFalse);
    });

    test('이슈 없으면 모든 등급 피드백 스킵', () {
      final classification = LayerClassification(layer1Issues: [], layer2Issues: []);

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isFalse);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isFalse);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isFalse);
    });
  });
}
