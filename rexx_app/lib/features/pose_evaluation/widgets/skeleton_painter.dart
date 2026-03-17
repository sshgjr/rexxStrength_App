import 'package:flutter/material.dart';
import '../models/pose_frame.dart';

/// 프레임 이미지 위에 BlazePose 랜드마크 + 뼈대선을 오버레이하는 CustomPainter
class SkeletonPainter extends CustomPainter {
  final PoseFrame? poseFrame;
  final Size imageSize;
  final bool showLabels;
  final bool showBones;
  final bool showPartNames;

  SkeletonPainter({
    required this.poseFrame,
    required this.imageSize,
    this.showLabels = false,
    this.showBones = true,
    this.showPartNames = false,
  });

  // 부위별 뼈대선 연결 맵
  static const _faceBones = [
    [0, 1], [1, 2], [2, 3], [3, 7],
    [0, 4], [4, 5], [5, 6], [6, 8],
  ];
  static const _shoulderBones = [[11, 12]];
  static const _torsoBones = [[11, 23], [12, 24], [23, 24]];
  static const _leftArmBones = [[11, 13], [13, 15], [15, 17], [15, 19], [17, 19]];
  static const _rightArmBones = [[12, 14], [14, 16], [16, 18], [16, 20], [18, 20]];
  static const _leftLegBones = [[23, 25], [25, 27], [27, 29], [27, 31], [29, 31]];
  static const _rightLegBones = [[24, 26], [26, 28], [28, 30], [28, 32], [30, 32]];

  // 부위별 라벨 그룹: (이름, 소속 랜드마크 인덱스, 색상)
  static const _partGroups = [
    ('얼굴', [0, 1, 2, 3, 4, 5, 6, 7, 8]),
    ('어깨', [11, 12]),
    ('몸통', [11, 12, 23, 24]),
    ('왼팔', [11, 13, 15, 17, 19]),
    ('오른팔', [12, 14, 16, 18, 20]),
    ('왼다리', [23, 25, 27, 29, 31]),
    ('오른다리', [24, 26, 28, 30, 32]),
  ];

  // 부위별 색상
  static const _faceColor = Color(0xFFB0BEC5);   // 회색
  static const _shoulderColor = Color(0xFF42A5F5); // 파랑
  static const _torsoColor = Color(0xFF42A5F5);    // 파랑
  static const _leftArmColor = Color(0xFFFF9800);  // 주황
  static const _rightArmColor = Color(0xFFAB47BC); // 보라
  static const _leftLegColor = Color(0xFF26C6DA);  // 시안
  static const _rightLegColor = Color(0xFFEC407A); // 핑크

  @override
  void paint(Canvas canvas, Size size) {
    if (poseFrame == null) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    if (showBones) {
      _drawBoneGroup(canvas, scaleX, scaleY, _faceBones, _faceColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _shoulderBones, _shoulderColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _torsoBones, _torsoColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _leftArmBones, _leftArmColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _rightArmBones, _rightArmColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _leftLegBones, _leftLegColor);
      _drawBoneGroup(canvas, scaleX, scaleY, _rightLegBones, _rightLegColor);
    }

    // 랜드마크 점 그리기
    for (final lm in poseFrame!.landmarks) {
      final x = lm.x * scaleX;
      final y = lm.y * scaleY;
      final color = _confidenceColor(lm.likelihood);

      canvas.drawCircle(
        Offset(x, y),
        4.0,
        Paint()..color = color,
      );

      // 랜드마크 인덱스 라벨
      if (showLabels) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${lm.index}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x + 5, y - 5));
      }
    }

    // 부위 이름 라벨 (중앙값 랜드마크 위치에 표시)
    if (showPartNames) {
      _drawPartNames(canvas, scaleX, scaleY);
    }
  }

  void _drawPartNames(Canvas canvas, double scaleX, double scaleY) {
    final bgPaint = Paint()..color = const Color(0xAA000000);

    for (final (name, indices) in _partGroups) {
      // 감지된 랜드마크만 필터링
      final detected = <PoseLandmark>[];
      for (final idx in indices) {
        final lm = poseFrame!.getLandmark(idx);
        if (lm != null) detected.add(lm);
      }
      if (detected.isEmpty) continue;

      // 인덱스 기준 정렬 후 중앙값 랜드마크 선택
      detected.sort((a, b) => a.index.compareTo(b.index));
      final median = detected[detected.length ~/ 2];
      final x = median.x * scaleX;
      final y = median.y * scaleY;

      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 반투명 배경 + 텍스트
      const pad = 3.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - tp.width / 2 - pad,
          y - tp.height - 8,
          tp.width + pad * 2,
          tp.height + pad * 2,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, bgPaint);
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height - 8 + pad));
    }
  }

  void _drawBoneGroup(
    Canvas canvas,
    double scaleX,
    double scaleY,
    List<List<int>> bones,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final bone in bones) {
      final from = poseFrame!.getLandmark(bone[0]);
      final to = poseFrame!.getLandmark(bone[1]);
      if (from == null || to == null) continue;

      canvas.drawLine(
        Offset(from.x * scaleX, from.y * scaleY),
        Offset(to.x * scaleX, to.y * scaleY),
        paint,
      );
    }
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.7) return const Color(0xFF66BB6A); // 초록
    if (confidence >= 0.4) return const Color(0xFFFFEE58); // 노랑
    return const Color(0xFFEF5350); // 빨강
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.poseFrame != poseFrame ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showBones != showBones ||
        oldDelegate.showPartNames != showPartNames;
  }
}
