import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';

void main() {
  group('ClassificationResult', () {
    test('sortedTypes는 확률 내림차순으로 정렬된다', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.2,
          ExerciseType.benchPress: 0.5,
          ExerciseType.deadlift: 0.3,
        },
      );
      expect(result.sortedTypes, [
        ExerciseType.benchPress,
        ExerciseType.deadlift,
        ExerciseType.squat,
      ]);
    });

    test('bestProb >= 0.60이면 high confidence', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.70,
          ExerciseType.benchPress: 0.20,
          ExerciseType.deadlift: 0.10,
        },
      );
      expect(result.confidence, ClassificationConfidence.high);
      expect(result.bestMatch, ExerciseType.squat);
    });

    test('0.40~0.60이고 차이 >= 0.10이면 moderate', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.50,
          ExerciseType.benchPress: 0.30,
          ExerciseType.deadlift: 0.20,
        },
      );
      expect(result.confidence, ClassificationConfidence.moderate);
    });

    test('0.40~0.60이고 차이 < 0.10이면 ambiguous', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.45,
          ExerciseType.benchPress: 0.40,
          ExerciseType.deadlift: 0.15,
        },
      );
      expect(result.confidence, ClassificationConfidence.ambiguous);
      expect(result.secondMatch, ExerciseType.benchPress);
    });

    test('bestProb < 0.40이면 failed', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.35,
          ExerciseType.benchPress: 0.33,
          ExerciseType.deadlift: 0.32,
        },
      );
      expect(result.confidence, ClassificationConfidence.failed);
    });
  });
}
