import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/exercise_phase.dart';
import '../models/classification_result.dart';
import '../engine/pose_analyzer.dart';
import '../widgets/classification_dialogs.dart';
import '../../../services/pose_feedback_service.dart';
import 'pose_result_screen.dart';
import 'pose_debug_screen.dart';

class VideoUploadScreen extends StatefulWidget {
  final ExerciseType? exerciseType;  // null이면 자동 분류
  final String? token;

  const VideoUploadScreen({
    super.key,
    this.exerciseType,
    this.token,
  });

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  String? _videoPath;
  VideoPlayerController? _videoController;
  bool _isAnalyzing = false;
  double _progress = 0.0;
  String _statusText = '';
  bool _debugMode = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    setState(() {
      _videoPath = video.path;
    });

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(video.path));
    await _videoController!.initialize();
    setState(() {});
  }

  Future<void> _startAnalysis() async {
    if (_videoPath == null) return;

    setState(() {
      _isAnalyzing = true;
      _progress = 0.0;
      _statusText = '프레임 추출 중...';
    });

    try {
      final analyzer = PoseAnalyzer();

      void onProgress(double progress) {
        setState(() {
          _progress = progress;
          if (progress < 0.3) {
            _statusText = '프레임 추출 중...';
          } else if (progress < 0.7) {
            _statusText = '포즈 감지 중...';
          } else {
            _statusText = '점수 계산 중...';
          }
        });
      }

      // 분류 필요 시 사용자에게 다이얼로그 표시하는 콜백
      Future<ExerciseType> onClassificationNeeded(ClassificationResult classification) async {
        ExerciseType? selected;

        if (classification.confidence == ClassificationConfidence.ambiguous) {
          selected = await showAmbiguousDialog(context, classification);
        } else {
          // failed
          selected = await showClassificationFailedDialog(context, classification);
        }

        if (selected == null) {
          throw _ClassificationCancelledException();
        }
        return selected;
      }

      // moderate 자동 확정 시 토스트 표시
      void onAutoClassified(ExerciseType type) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${type.displayName}(으)로 분석합니다'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // 디버그 모드: 프레임을 보존하고 디버그 화면으로 이동
      if (_debugMode) {
        final debugData = await analyzer.analyzeWithDebug(
          videoPath: _videoPath!,
          exerciseType: widget.exerciseType,
          onClassificationNeeded: widget.exerciseType == null ? onClassificationNeeded : null,
          onAutoClassified: widget.exerciseType == null ? onAutoClassified : null,
          onProgress: onProgress,
        );
        analyzer.dispose();

        if (!mounted) return;

        // 디버그 화면 표시 (push로 열어 닫으면 돌아옴)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseDebugScreen(debugData: debugData),
          ),
        );

        if (!mounted) return;

        // 디버그 화면 닫은 후 결과 화면으로 이동
        final result = debugData.result;
        setState(() {
          _statusText = '피드백 생성 중...';
        });

        final feedbackService = PoseFeedbackService();
        final feedbackResult = await feedbackService.requestFeedback(
          result: result,
          token: widget.token,
        );

        final finalResult = feedbackResult.isSuccess
            ? result.copyWith(feedbackText: feedbackResult.feedback)
            : result.copyWith(feedbackError: feedbackResult.error);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PoseResultScreen(
              result: finalResult,
              token: widget.token,
            ),
          ),
        );
        return;
      }

      final result = await analyzer.analyze(
        videoPath: _videoPath!,
        exerciseType: widget.exerciseType,
        onClassificationNeeded: widget.exerciseType == null ? onClassificationNeeded : null,
        onAutoClassified: widget.exerciseType == null ? onAutoClassified : null,
        onProgress: onProgress,
      );

      analyzer.dispose();

      // LLM 피드백 요청
      setState(() {
        _statusText = '피드백 생성 중...';
      });

      final feedbackService = PoseFeedbackService();
      final feedbackResult = await feedbackService.requestFeedback(
        result: result,
        token: widget.token,
      );

      final finalResult = feedbackResult.isSuccess
          ? result.copyWith(feedbackText: feedbackResult.feedback)
          : result.copyWith(feedbackError: feedbackResult.error);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PoseResultScreen(
            result: finalResult,
            token: widget.token,
          ),
        ),
      );
    } on _ClassificationCancelledException {
      setState(() {
        _isAnalyzing = false;
        _statusText = '';
      });
      return; // 네비게이션은 다이얼로그에서 이미 처리됨
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = '';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textMain,
        title: GestureDetector(
          onLongPress: () {
                  setState(() => _debugMode = !_debugMode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _debugMode ? '디버그 모드 활성화' : '디버그 모드 비활성화',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.exerciseType != null
                    ? '${widget.exerciseType!.displayName} 영상 업로드'
                    : '영상 분석',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_debugMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEBUG',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
              onPressed: () {
                setState(() => _debugMode = !_debugMode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _debugMode ? '디버그 모드 활성화' : '디버그 모드 비활성화',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: Icon(
                _debugMode ? Icons.bug_report : Icons.bug_report_outlined,
                color: _debugMode ? const Color(0xFFEF5350) : textSub,
              ),
              tooltip: '디버그 모드',
            ),
        ],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _isAnalyzing
                  ? _buildAnalyzingView()
                  : _videoPath == null
                      ? _buildUploadPrompt()
                      : _buildVideoPreview(),
            ),
            const SizedBox(height: 20),
            if (!_isAnalyzing) _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withOpacity(0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '영상을 선택하세요',
              style: TextStyle(
                color: textMain,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '갤러리에서 운동 영상을 선택해주세요.\n측면에서 촬영된 영상이 가장 정확합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSub,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Container(
                    color: card,
                    child: const Center(
                      child: CircularProgressIndicator(color: primary),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
                setState(() {});
              },
              icon: Icon(
                _videoController?.value.isPlaying == true
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: primary,
                size: 48,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyzingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _statusText,
            style: const TextStyle(
              color: textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '잠시만 기다려주세요...',
            style: TextStyle(color: textSub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        if (_videoPath == null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text(
                '갤러리에서 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '분석 시작',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _pickVideo,
              style: OutlinedButton.styleFrom(
                foregroundColor: textSub,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '다른 영상 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClassificationCancelledException implements Exception {}
