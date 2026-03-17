/// 운동 단계 enum
enum ExercisePhase {
  setup,    // 준비 자세
  descent,  // 하강 (이센트릭)
  bottom,   // 최저점 (전환)
  ascent,   // 상승 (컨센트릭)
  lockout,  // 완전 신전 (락아웃)
}

/// 운동 종류
enum ExerciseType {
  squat,
  benchPress,
  deadlift;

  String get displayName {
    switch (this) {
      case ExerciseType.squat:
        return '스쿼트';
      case ExerciseType.benchPress:
        return '벤치프레스';
      case ExerciseType.deadlift:
        return '데드리프트';
    }
  }

  String get apiName {
    switch (this) {
      case ExerciseType.squat:
        return 'squat';
      case ExerciseType.benchPress:
        return 'bench_press';
      case ExerciseType.deadlift:
        return 'deadlift';
    }
  }
}
