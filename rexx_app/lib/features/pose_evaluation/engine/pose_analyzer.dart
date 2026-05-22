import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../models/exercise_phase.dart';
import '../models/evaluation_result.dart';
import '../models/debug_analysis_data.dart';
import 'rules/exercise_rule.dart';
import 'rules/squat_rules.dart';
import 'rules/bench_press_rules.dart';
import 'rules/deadlift_rules.dart';
import 'rules/wrist_curl_rules.dart';
import 'pose_detector_interface.dart';
import 'pose_detector_mlkit.dart';
import 'pose_detector_stub.dart';
import 'classifier/exercise_classifier.dart';
import '../models/classification_result.dart';
import 'layer_classifier.dart';

const bool isSimulatorMode =
    bool.fromEnvironment('SIMULATOR_MODE', defaultValue: false);

class PoseAnalyzer {
  final PoseDetectorInterface _detector;

  PoseAnalyzer()
      : _detector =
            isSimulatorMode ? PoseDetectorStub() : MLKitPoseDetector();

  Future<EvaluationResult> analyze({
    required String videoPath,
    ExerciseType? exerciseType,
    LayerClassifier? layerClassifier,
    Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
    void Function(ExerciseType)? onAutoClassified,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final frames = await _extractFrames(videoPath);
    onProgress?.call(0.3);

    final poseFrames = await _detector.detectPoses(frames);
    onProgress?.call(0.7);

    final ExerciseType resolvedType;
    if (exerciseType != null) {
      resolvedType = exerciseType;
    } else {
      final classifier = ExerciseClassifier();
      final classification = classifier.classify(poseFrames);

      if (classification.confidence == ClassificationConfidence.high) {
        resolvedType = classification.bestMatch;
      } else if (classification.confidence == ClassificationConfidence.moderate) {
        resolvedType = classification.bestMatch;
        onAutoClassified?.call(resolvedType);
      } else if (onClassificationNeeded != null) {
        resolvedType = await onClassificationNeeded(classification);
      } else {
        resolvedType = classification.bestMatch;
      }
    }

    final rule = _getRule(resolvedType);
    final criteria = rule.evaluate(poseFrames);

    LayerClassification? layerClassification;
    if (layerClassifier != null) {
      layerClassification = layerClassifier.classify(criteria, resolvedType);
    }

    double totalScore = 0;
    for (final c in criteria) {
      totalScore += c.score * c.weight;
    }

    final issues = criteria
        .where((c) => c.grade != CriterionGrade.good)
        .map((c) =>
            '${c.description}: ${c.grade.displayName} (${c.score.round()}점)')
        .toList();

    onProgress?.call(1.0);
    await _cleanup(frames);

    return EvaluationResult(
      exerciseType: resolvedType,
      totalScore: totalScore.round(),
      criteria: criteria,
      detectedIssues: issues,
      evaluatedAt: DateTime.now(),
      layerClassification: layerClassification,
    );
  }

  Future<DebugAnalysisData> analyzeWithDebug({
    required String videoPath,
    ExerciseType? exerciseType,
    LayerClassifier? layerClassifier,
    Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
    void Function(ExerciseType)? onAutoClassified,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final frames = await _extractFrames(videoPath);
    onProgress?.call(0.3);

    final poseFrames = await _detector.detectPoses(frames);
    onProgress?.call(0.7);

    final ExerciseType resolvedType;
    if (exerciseType != null) {
      resolvedType = exerciseType;
    } else {
      final classifier = ExerciseClassifier();
      final classification = classifier.classify(poseFrames);

      if (classification.confidence == ClassificationConfidence.high) {
        resolvedType = classification.bestMatch;
      } else if (classification.confidence == ClassificationConfidence.moderate) {
        resolvedType = classification.bestMatch;
        onAutoClassified?.call(resolvedType);
      } else if (onClassificationNeeded != null) {
        resolvedType = await onClassificationNeeded(classification);
      } else {
        resolvedType = classification.bestMatch;
      }
    }

    final rule = _getRule(resolvedType);
    final criteria = rule.evaluate(poseFrames);

    LayerClassification? layerClassification;
    if (layerClassifier != null) {
      layerClassification = layerClassifier.classify(criteria, resolvedType);
    }

    double totalScore = 0;
    for (final c in criteria) {
      totalScore += c.score * c.weight;
    }

    final issues = criteria
        .where((c) => c.grade != CriterionGrade.good)
        .map((c) =>
            '${c.description}: ${c.grade.displayName} (${c.score.round()}점)')
        .toList();

    onProgress?.call(1.0);

    final result = EvaluationResult(
      exerciseType: resolvedType,
      totalScore: totalScore.round(),
      criteria: criteria,
      detectedIssues: issues,
      evaluatedAt: DateTime.now(),
      layerClassification: layerClassification,
    );

    return DebugAnalysisData(
      framePaths: frames,
      poseFrames: poseFrames,
      result: result,
    );
  }

  Future<List<String>> _extractFrames(String videoPath) async {
    final tempDir = Directory.systemTemp.createTempSync('rexx_frames_');

    final controller = VideoPlayerController.file(File(videoPath));
    await controller.initialize();
    final durationMs = controller.value.duration.inMilliseconds;
    await controller.dispose();

    if (durationMs <= 0) {
      throw Exception('프레임 추출 실패: 영상 길이를 알 수 없습니다');
    }

    const intervalMs = 200;
    final framePaths = <String>[];

    for (int ms = 0; ms < durationMs; ms += intervalMs) {
      final outputPath =
          '${tempDir.path}/frame_${ms.toString().padLeft(8, '0')}.jpg';
      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outputPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
        timeMs: ms,
      );

      if (path != null) {
        framePaths.add(path);
      }
    }

    if (framePaths.isEmpty) {
      throw Exception('프레임 추출 실패: 추출된 프레임이 없습니다');
    }

    return framePaths;
  }

  ExerciseRule _getRule(ExerciseType type) {
    switch (type) {
      case ExerciseType.squat:
        return SquatRules();
      case ExerciseType.benchPress:
        return BenchPressRules();
      case ExerciseType.deadlift:
        return DeadliftRules();
      case ExerciseType.wristCurl:
        return WristCurlRules();
      case ExerciseType.sidePressure:
        return SquatRules(); // 임시 - sidePressure Rules 완성 후 교체
      case ExerciseType.pronationCurl:
        return WristCurlRules(); // 임시 - pronationCurl Rules 완성 후 교체
    }
  }

  Future<void> _cleanup(List<String> framePaths) async {
    if (framePaths.isEmpty) return;
    try {
      final dir = File(framePaths.first).parent;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  void dispose() {
    _detector.close();
  }
}
