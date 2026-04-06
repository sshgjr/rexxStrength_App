import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/exercise_phase.dart';
import '../engine/pose_analyzer.dart';
import '../../../services/pose_feedback_service.dart';
import 'pose_result_screen.dart';
import 'pose_debug_screen.dart';

class VideoUploadScreen extends StatefulWidget {
  final ExerciseType? exerciseType;
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
  ExerciseType? _selectedExerciseType;

  // ── 운동 카테고리별 아이콘 자동 결정 ──────────────────────────────────
  // ExerciseType에 isArmWrestlingExercise / isPowerlifting getter가 있으므로
  // 새 운동 추가 시 해당 getter만 설정하면 자동으로 아이콘이 적용됨
  IconData _iconForExercise(ExerciseType type) {
    if (type.isArmWrestlingExercise) {
      return Icons.front_hand; // 팔씨름 보조 운동 — 손 아이콘
    } else if (type.isPowerlifting) {
      return Icons.fitness_center; // 파워리프팅 3대 운동 — 바벨 아이콘
    }
    return Icons.sports; // 기타
  }

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
      _selectedExerciseType = null;
    });

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(video.path));
    await _videoController!.initialize();
    setState(() {});

    if (mounted) {
      _showExercisePickerBottomSheet();
    }
  }

  void _showExercisePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1612),
      isScrollControlled: true, // 콘텐츠 높이에 맞게 조절
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView( // 스크롤 가능하게
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 드래그 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      '운동 종류를 선택하세요',
                      style: TextStyle(
                        color: Color(0xFFE9F5EF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── 파워리프팅 섹션 ──────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '파워리프팅',
                      style: TextStyle(
                        color: Color(0xFFA7B9B0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...ExerciseType.values
                      .where((t) => t.isPowerlifting)
                      .map((type) => _buildExerciseTile(type)),

                  // ── 팔씨름 보조 섹션 ─────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '팔씨름 보조 웨이트',
                      style: TextStyle(
                        color: Color(0xFFA7B9B0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...ExerciseType.values
                      .where((t) => t.isArmWrestlingExercise)
                      .map((type) => _buildExerciseTile(type)),

                  // ── 기타 운동 (어느 카테고리도 아닌 경우) ───────────
                  if (ExerciseType.values.any(
                      (t) => !t.isPowerlifting && !t.isArmWrestlingExercise)) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '기타',
                        style: TextStyle(
                          color: Color(0xFFA7B9B0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...ExerciseType.values
                        .where((t) => !t.isPowerlifting && !t.isArmWrestlingExercise)
                        .map((type) => _buildExerciseTile(type)),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    ).then((selected) {
      if (selected != null && selected is ExerciseType) {
        setState(() {
          _selectedExerciseType = selected;
        });
      }
    });
  }

  // ── 운동 항목 타일 ────────────────────────────────────────────────────
  Widget _buildExerciseTile(ExerciseType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForExercise(type),
            color: primary,
            size: 22,
          ),
        ),
        title: Text(
          type.displayName,
          style: const TextStyle(
            color: Color(0xFFE9F5EF),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.white.withValues(alpha: 0.05),
        onTap: () {
          Navigator.pop(context, type);
        },
      ),
    );
  }

  Future<void> _startAnalysis() async {
    if (_videoPath == null) return;

    final exerciseType = widget.exerciseType ?? _selectedExerciseType;
    if (exerciseType == null) {
      _showExercisePickerBottomSheet();
      return;
    }

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

      if (_debugMode) {
        final debugData = await analyzer.analyzeWithDebug(
          videoPath: _videoPath!,
          exerciseType: exerciseType,
          onProgress: onProgress,
        );
        analyzer.dispose();

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseDebugScreen(debugData: debugData),
          ),
        );

        if (!mounted) return;

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
        exerciseType: exerciseType,
        onProgress: onProgress,
      );

      analyzer.dispose();

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
      return;
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
                (widget.exerciseType ?? _selectedExerciseType) != null
                    ? '${(widget.exerciseType ?? _selectedExerciseType)!.displayName} 영상 분석'
                    : '영상 분석',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_debugMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              style: TextStyle(color: textSub, fontSize: 14, height: 1.5),
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
          if (_selectedExerciseType != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _showExercisePickerBottomSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconForExercise(_selectedExerciseType!),
                          color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedExerciseType!.displayName,
                        style: const TextStyle(
                          color: textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '변경',
                        style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_videoPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _showExercisePickerBottomSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, color: textSub, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '운동 종류를 선택하세요',
                        style: TextStyle(
                          color: textSub,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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
