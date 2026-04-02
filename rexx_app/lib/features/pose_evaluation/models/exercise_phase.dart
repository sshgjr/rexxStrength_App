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
  deadlift,
  wristCurl,
  sidePressure;

  String get displayName {
    switch (this) {
      case ExerciseType.squat:
        return '스쿼트';
      case ExerciseType.benchPress:
        return '벤치프레스';
      case ExerciseType.deadlift:
        return '데드리프트';
      case ExerciseType.wristCurl:
        return '리스트컬';
      case ExerciseType.sidePressure:
        return '사이드프레셔';
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
      case ExerciseType.wristCurl:
        return 'wrist_curl';
      case ExerciseType.sidePressure:
        return 'side_pressure';
    }
  }

  /// 팔씨름 보조 운동 여부
  bool get isArmWrestlingExercise {
    switch (this) {
      case ExerciseType.sidePressure:
      case ExerciseType.wristCurl:
        return true;
      default:
        return false;
    }
  }

  /// 파워리프팅 운동 여부
  bool get isPowerlifting {
    switch (this) {
      case ExerciseType.squat:
      case ExerciseType.benchPress:
      case ExerciseType.deadlift:
        return true;
      default:
        return false;
    }
  }
}
