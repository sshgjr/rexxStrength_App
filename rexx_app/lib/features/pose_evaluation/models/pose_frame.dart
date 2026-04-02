/// 단일 프레임의 포즈 랜드마크 데이터
class PoseLandmark {
  final int index;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const PoseLandmark({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'x': x,
        'y': y,
        'z': z,
        'likelihood': likelihood,
      };

  factory PoseLandmark.fromJson(Map<String, dynamic> json) => PoseLandmark(
        index: json['index'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        z: (json['z'] as num).toDouble(),
        likelihood: (json['likelihood'] as num).toDouble(),
      );
}

/// 단일 프레임의 전체 랜드마크 집합
class PoseFrame {
  final int frameIndex;
  final double timestamp; // 초 단위
  final List<PoseLandmark> landmarks; // 33개 BlazePose 랜드마크

  const PoseFrame({
    required this.frameIndex,
    required this.timestamp,
    required this.landmarks,
  });

  /// 특정 인덱스의 랜드마크 반환
  PoseLandmark? getLandmark(int index) {
    try {
      return landmarks.firstWhere((l) => l.index == index);
    } catch (_) {
      return null;
    }
  }

  /// BlazePose 랜드마크 인덱스 상수
  static const int leftShoulder   = 11;
  static const int rightShoulder  = 12;
  static const int leftElbow      = 13;
  static const int rightElbow     = 14;
  static const int leftWrist      = 15;
  static const int rightWrist     = 16;
  static const int leftPinky      = 17;  // 추가: 왼쪽 새끼손가락
  static const int rightPinky     = 18;  // 추가: 오른쪽 새끼손가락
  static const int leftIndex      = 19;  // 왼쪽 검지
  static const int rightIndex     = 20;  // 오른쪽 검지
  static const int leftThumb      = 21;  // 추가: 왼쪽 엄지
  static const int rightThumb     = 22;  // 추가: 오른쪽 엄지
  static const int leftHip        = 23;
  static const int rightHip       = 24;
  static const int leftKnee       = 25;
  static const int rightKnee      = 26;
  static const int leftAnkle      = 27;
  static const int rightAnkle     = 28;
  static const int leftFootIndex  = 31;
  static const int rightFootIndex = 32;
}
