import 'exercise_phase.dart';

/// 분류 신뢰도 수준
enum ClassificationConfidence { high, moderate, ambiguous, failed }

/// 운동 자동 분류 결과 모델
class ClassificationResult {
  final Map<ExerciseType, double> probabilities;

  ClassificationResult({required this.probabilities});

  /// 확률 내림차순 정렬된 운동 타입 리스트
  List<ExerciseType> get sortedTypes {
    final entries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// 최고 확률 운동
  ExerciseType get bestMatch => sortedTypes.first;

  /// 두 번째 확률 운동
  ExerciseType? get secondMatch =>
      sortedTypes.length > 1 ? sortedTypes[1] : null;

  double get _bestProb => probabilities[bestMatch]!;
  double get _secondProb =>
      secondMatch != null ? probabilities[secondMatch]! : 0.0;

  /// confidence 판정 (스펙 1.3 기준)
  ClassificationConfidence get confidence {
    if (_bestProb >= 0.60) return ClassificationConfidence.high;
    if (_bestProb >= 0.40) {
      if (_bestProb - _secondProb >= 0.10) {
        return ClassificationConfidence.moderate;
      }
      return ClassificationConfidence.ambiguous;
    }
    return ClassificationConfidence.failed;
  }
}
