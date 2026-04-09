// 온보딩 입력 상태 + 응답 모델.

enum OnboardingExperience {
  lt6m('lt_6m', '6개월 이하'),
  m6to2y('6m_2y', '6개월 ~ 2년'),
  y2to5('2_5y', '2년 ~ 5년'),
  y5plus('5y_plus', '5년 이상');

  final String code;
  final String label;
  const OnboardingExperience(this.code, this.label);
}

enum OnboardingSex {
  male('male', '남성'),
  female('female', '여성');

  final String code;
  final String label;
  const OnboardingSex(this.code, this.label);
}

class OnboardingInput {
  OnboardingSex? sex;
  int? birthYear;
  OnboardingExperience? experience;
  double? squat1rm;
  double? bench1rm;
  double? deadlift1rm;
  bool squatUnknown = false;
  bool benchUnknown = false;
  bool deadliftUnknown = false;
}

class MissingReasonItem {
  final String code;
  final String message;
  MissingReasonItem({required this.code, required this.message});

  factory MissingReasonItem.fromJson(Map<String, dynamic> json) =>
      MissingReasonItem(
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

class OnboardingResult {
  final String level; // beginner | intermediate | advanced
  final String levelSource; // auto | manual | default
  final double? avgTierScore;
  final bool cappedByExperience;
  final String feedbackStylePreview;
  final List<MissingReasonItem> missingReasons;

  OnboardingResult({
    required this.level,
    required this.levelSource,
    required this.avgTierScore,
    required this.cappedByExperience,
    required this.feedbackStylePreview,
    required this.missingReasons,
  });

  factory OnboardingResult.fromJson(Map<String, dynamic> json) {
    return OnboardingResult(
      level: json['level'] as String,
      levelSource: json['level_source'] as String,
      avgTierScore: (json['avg_tier_score'] as num?)?.toDouble(),
      cappedByExperience: json['capped_by_experience'] as bool? ?? false,
      feedbackStylePreview: json['feedback_style_preview'] as String,
      missingReasons: ((json['missing_reasons'] as List?) ?? [])
          .map((e) => MissingReasonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get levelKorean => switch (level) {
        'beginner' => '초급',
        'intermediate' => '중급',
        'advanced' => '상급',
        _ => level,
      };

  String get levelEmoji => switch (level) {
        'beginner' => '🥉',
        'intermediate' => '🥈',
        'advanced' => '🥇',
        _ => '',
      };
}
