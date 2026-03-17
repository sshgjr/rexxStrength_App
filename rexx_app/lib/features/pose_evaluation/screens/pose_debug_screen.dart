import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/debug_analysis_data.dart';
import '../models/pose_frame.dart';
import '../widgets/skeleton_painter.dart';

/// 포즈 랜드마크 디버그 오버레이 뷰어
class PoseDebugScreen extends StatefulWidget {
  final DebugAnalysisData debugData;

  const PoseDebugScreen({super.key, required this.debugData});

  @override
  State<PoseDebugScreen> createState() => _PoseDebugScreenState();
}

class _PoseDebugScreenState extends State<PoseDebugScreen> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  int _currentFrame = 0;
  bool _showLabels = false;
  bool _showBones = true;
  bool _showPartNames = false;
  bool _isPlaying = false;
  Timer? _playTimer;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _cleanupFrames();
    super.dispose();
  }

  Future<void> _cleanupFrames() async {
    final paths = widget.debugData.framePaths;
    if (paths.isEmpty) return;
    try {
      final dir = File(paths.first).parent;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _loadImageSize() async {
    if (widget.debugData.framePaths.isEmpty) return;
    final file = File(widget.debugData.framePaths.first);
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }
  }

  PoseFrame? _getPoseForFrame(int frameIndex) {
    try {
      return widget.debugData.poseFrames
          .firstWhere((p) => p.frameIndex == frameIndex);
    } catch (_) {
      return null;
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _playTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_currentFrame < widget.debugData.framePaths.length - 1) {
          setState(() => _currentFrame++);
        } else {
          _togglePlay();
        }
      });
    } else {
      _playTimer?.cancel();
      _playTimer = null;
    }
  }

  double _averageConfidence(PoseFrame? frame) {
    if (frame == null || frame.landmarks.isEmpty) return 0.0;
    final sum = frame.landmarks.fold<double>(
      0.0,
      (acc, lm) => acc + lm.likelihood,
    );
    return sum / frame.landmarks.length;
  }

  @override
  Widget build(BuildContext context) {
    final frameCount = widget.debugData.framePaths.length;
    final currentPose = _getPoseForFrame(_currentFrame);
    final confidence = _averageConfidence(currentPose);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textMain,
        title: const Text(
          '포즈 디버그 뷰어',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showLabels = !_showLabels),
            icon: Icon(
              Icons.label,
              color: _showLabels ? primary : textSub,
            ),
            tooltip: '라벨 토글',
          ),
          IconButton(
            onPressed: () => setState(() => _showPartNames = !_showPartNames),
            icon: Icon(
              Icons.text_fields,
              color: _showPartNames ? primary : textSub,
            ),
            tooltip: '부위명 토글',
          ),
          IconButton(
            onPressed: () => setState(() => _showBones = !_showBones),
            icon: Icon(
              Icons.account_tree,
              color: _showBones ? primary : textSub,
            ),
            tooltip: '뼈대선 토글',
          ),
        ],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 프레임 이미지 + 스켈레톤 오버레이
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: card,
                  child: _buildFrameView(currentPose),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 정보 바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '프레임 ${_currentFrame + 1} / $frameCount',
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(_currentFrame / 5.0).toStringAsFixed(1)}초',
                    style: const TextStyle(color: textSub, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentPose != null
                              ? (confidence >= 0.7
                                  ? const Color(0xFF66BB6A)
                                  : confidence >= 0.4
                                      ? const Color(0xFFFFEE58)
                                      : const Color(0xFFEF5350))
                              : const Color(0xFFEF5350),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentPose != null
                            ? '신뢰도 ${(confidence * 100).round()}%'
                            : '포즈 미감지',
                        style: const TextStyle(color: textSub, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 슬라이더
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: primary,
                overlayColor: primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _currentFrame.toDouble(),
                min: 0,
                max: (frameCount - 1).toDouble().clamp(0, double.infinity),
                onChanged: (v) {
                  setState(() => _currentFrame = v.round());
                },
              ),
            ),

            // 재생/일시정지 버튼
            IconButton(
              onPressed: frameCount > 1 ? _togglePlay : null,
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameView(PoseFrame? currentPose) {
    if (widget.debugData.framePaths.isEmpty) {
      return const Center(
        child: Text(
          '프레임이 없습니다',
          style: TextStyle(color: textSub),
        ),
      );
    }

    final imageFile = File(widget.debugData.framePaths[_currentFrame]);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // 프레임 이미지
            Image.file(
              imageFile,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text(
                  '이미지 로드 실패',
                  style: TextStyle(color: textSub),
                ),
              ),
            ),

            // 스켈레톤 오버레이
            if (currentPose != null && _imageSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: SkeletonPainter(
                    poseFrame: currentPose,
                    imageSize: _imageSize!,
                    showLabels: _showLabels,
                    showBones: _showBones,
                    showPartNames: _showPartNames,
                  ),
                ),
              ),

            // 포즈 미감지 표시
            if (currentPose == null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '포즈 미감지',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
