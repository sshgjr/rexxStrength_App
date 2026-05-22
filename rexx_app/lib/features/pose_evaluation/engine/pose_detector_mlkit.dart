import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import '../models/pose_frame.dart';
import 'pose_detector_interface.dart';

/// ML Kit 기반 실제 포즈 디텍터. 실기기에서만 사용.
/// 시뮬레이터 빌드 시에는 인스턴스화되지 않으므로 Podfile 빌드 단계에서
/// ML Kit 의존성이 제거되어도 안전하다.
class MLKitPoseDetector implements PoseDetectorInterface {
  final mlkit.PoseDetector _detector;

  MLKitPoseDetector()
      : _detector = mlkit.PoseDetector(
          options: mlkit.PoseDetectorOptions(
            mode: mlkit.PoseDetectionMode.single,
            model: mlkit.PoseDetectionModel.accurate,
          ),
        );

  @override
  Future<List<PoseFrame>> detectPoses(List<String> framePaths) async {
    final poseFrames = <PoseFrame>[];

    for (int i = 0; i < framePaths.length; i++) {
      final inputImage = mlkit.InputImage.fromFilePath(framePaths[i]);
      final poses = await _detector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final landmarks = pose.landmarks.entries.map<PoseLandmark>((entry) {
          final lm = entry.value;
          return PoseLandmark(
            index: entry.key.index,
            x: lm.x,
            y: lm.y,
            z: lm.z,
            likelihood: lm.likelihood,
          );
        }).toList();

        poseFrames.add(PoseFrame(
          frameIndex: i,
          timestamp: i / 5.0,
          landmarks: landmarks,
        ));
      }
    }

    return poseFrames;
  }

  @override
  void close() {
    _detector.close();
  }
}
