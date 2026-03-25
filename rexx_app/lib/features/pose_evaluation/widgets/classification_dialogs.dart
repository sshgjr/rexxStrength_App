import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise_phase.dart';
import '../models/classification_result.dart';

const Color _bg = Color(0xFF0B0F0C);
const Color _card = Color(0xFF0F1612);
const Color _primary = Color(0xFF16A34A);
const Color _textMain = Color(0xFFE9F5EF);
const Color _textSub = Color(0xFFA7B9B0);

/// ambiguous 분류 시 상위 2개 운동 선택 다이얼로그
Future<ExerciseType?> showAmbiguousDialog(
  BuildContext context,
  ClassificationResult result,
) {
  final top2 = result.sortedTypes.take(2).toList();

  return showDialog<ExerciseType>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '운동 종류를 확인해 주세요',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '두 운동이 비슷하게 감지되었습니다.\n어떤 운동인지 선택해 주세요.',
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          for (final type in top2) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  type.displayName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (type != top2.last) const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
}

/// 분류 실패 플로우 다이얼로그
Future<ExerciseType?> showClassificationFailedDialog(
  BuildContext context,
  ClassificationResult result,
) async {
  final isSupportedExercise = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '운동을 판별하지 못했어요',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '분석 가능한 운동 영상이 맞나요?',
            style: TextStyle(color: _textMain, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '현재 지원: 스쿼트 · 벤치프레스 · 데드리프트',
              style: TextStyle(color: _textSub, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('아니오', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('예'),
        ),
      ],
    ),
  );

  if (!context.mounted) return null;

  if (isSupportedExercise == true) {
    return showDialog<ExerciseType>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          '운동을 선택해 주세요',
          style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in result.sortedTypes) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, type),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    type.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (type != result.sortedTypes.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  } else {
    await _showUnsupportedExerciseFeedback(context);
    return null;
  }
}

Future<void> _showUnsupportedExerciseFeedback(BuildContext context) async {
  final submitted = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _FeedbackInputDialog(),
  );

  if (submitted != null && submitted.isNotEmpty) {
    await _saveFeedback(submitted);
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '소중한 의견 감사합니다!',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '더 다양한 운동을 지원할 수 있도록\n참고하겠습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: const Text('메인으로 돌아가기', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('다른 영상 분석하기'),
        ),
      ],
    ),
  );
}

Future<void> _saveFeedback(String exerciseName) async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'unsupported_exercise_requests';
  final existing = prefs.getString(key);
  final list = existing != null ? jsonDecode(existing) as List : [];
  list.add({
    'exercise': exerciseName,
    'timestamp': DateTime.now().toIso8601String(),
  });
  await prefs.setString(key, jsonEncode(list));
}

/// 운동 이름 입력 다이얼로그 — TextEditingController를 StatefulWidget 에서 관리
class _FeedbackInputDialog extends StatefulWidget {
  const _FeedbackInputDialog();

  @override
  State<_FeedbackInputDialog> createState() => _FeedbackInputDialogState();
}

class _FeedbackInputDialogState extends State<_FeedbackInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '어떤 운동인가요?',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '운동 종류를 입력해 주시면\n추후 기능 추가에 참고하겠습니다.',
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: _textMain),
            decoration: InputDecoration(
              hintText: '예: 오버헤드프레스',
              hintStyle: const TextStyle(color: _textSub),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('건너뛰기', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('제출'),
        ),
      ],
    );
  }
}
