import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/evaluation_result.dart';
import '../models/exercise_phase.dart';

/// 사용자 등급
enum UserLevel {
  beginner,
  intermediate,
  advanced;

  String get apiName => name;

  String get displayName {
    switch (this) {
      case UserLevel.beginner:
        return '초급';
      case UserLevel.intermediate:
        return '중급';
      case UserLevel.advanced:
        return '상급';
    }
  }

  static UserLevel fromString(String value) {
    return UserLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserLevel.beginner,
    );
  }
}

/// 레이어 분류된 이슈 항목
class LayerIssue {
  final CriterionResult criterion;
  final String reason;

  const LayerIssue({required this.criterion, required this.reason});

  Map<String, dynamic> toJson() => {
        'criterion': criterion.name,
        'score': criterion.score,
        'grade': criterion.grade.name,
        'reason': reason,
      };
}

/// 레이어 분류 결과
class LayerClassification {
  final List<LayerIssue> layer1Issues;
  final List<LayerIssue> layer2Issues;

  const LayerClassification({
    required this.layer1Issues,
    required this.layer2Issues,
  });

  bool get hasLayer1 => layer1Issues.isNotEmpty;
  bool get hasLayer2Only => !hasLayer1 && layer2Issues.isNotEmpty;
  bool get hasNoIssues => layer1Issues.isEmpty && layer2Issues.isEmpty;

  /// 서버에 피드백을 요청해야 하는지 결정
  bool shouldRequestFeedback(UserLevel level) {
    if (hasNoIssues) return false;
    if (hasLayer1) return true;
    // L2만 감지된 경우
    if (level == UserLevel.advanced) return false;
    return true;
  }
}

/// 레이어 분류기 — layer_config.json 기반
class LayerClassifier {
  final Map<String, _ExerciseLayerConfig> _config;

  LayerClassifier._(this._config);

  /// JSON 에셋에서 로드
  static Future<LayerClassifier> load() async {
    final jsonStr = await rootBundle.loadString('assets/config/layer_config.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return _parseConfig(data);
  }

  /// 테스트용 — Map에서 직접 생성
  factory LayerClassifier.fromMap(Map<String, dynamic> exercises) {
    return _parseConfig({'version': 1, 'exercises': exercises});
  }

  static LayerClassifier _parseConfig(Map<String, dynamic> data) {
    final exercises = data['exercises'] as Map<String, dynamic>;
    final config = <String, _ExerciseLayerConfig>{};

    for (final entry in exercises.entries) {
      final exerciseData = entry.value as Map<String, dynamic>;
      final l1 = (exerciseData['layer1'] as List<dynamic>)
          .map((e) => _LayerEntry(
                criterion: e['criterion'] as String,
                reason: e['reason'] as String,
              ))
          .toList();
      final l2 = (exerciseData['layer2'] as List<dynamic>)
          .map((e) => _LayerEntry(
                criterion: e['criterion'] as String,
                reason: e['reason'] as String,
              ))
          .toList();
      config[entry.key] = _ExerciseLayerConfig(layer1: l1, layer2: l2);
    }

    return LayerClassifier._(config);
  }

  /// 기준 결과를 레이어별로 분류
  LayerClassification classify(List<CriterionResult> criteria, ExerciseType exerciseType) {
    final exerciseConfig = _config[exerciseType.apiName];
    final l1Issues = <LayerIssue>[];
    final l2Issues = <LayerIssue>[];

    for (final c in criteria) {
      if (c.grade == CriterionGrade.good) continue;

      final l1Entry = exerciseConfig?.layer1.where((e) => e.criterion == c.name).firstOrNull;

      if (l1Entry != null) {
        l1Issues.add(LayerIssue(criterion: c, reason: l1Entry.reason));
      } else {
        final l2Entry = exerciseConfig?.layer2.where((e) => e.criterion == c.name).firstOrNull;
        final reason = l2Entry?.reason ?? '스타일 관련 항목';
        l2Issues.add(LayerIssue(criterion: c, reason: reason));
      }
    }

    return LayerClassification(layer1Issues: l1Issues, layer2Issues: l2Issues);
  }
}

class _ExerciseLayerConfig {
  final List<_LayerEntry> layer1;
  final List<_LayerEntry> layer2;
  const _ExerciseLayerConfig({required this.layer1, required this.layer2});
}

class _LayerEntry {
  final String criterion;
  final String reason;
  const _LayerEntry({required this.criterion, required this.reason});
}
