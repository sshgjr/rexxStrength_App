import 'package:flutter/material.dart';

class _ExerciseOption {
  final String id;
  final String label;
  final IconData icon;
  final String reaction;

  const _ExerciseOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.reaction,
  });
}

const List<_ExerciseOption> _exerciseOptions = [
  _ExerciseOption(
    id: 'powerlifting',
    label: '3대 운동',
    icon: Icons.fitness_center,
    reaction: '오, 3대 운동을 좋아하시는군요! 스쿼트·벤치·데드리프트 자세 분석으로 함께 성장해봐요!',
  ),
  _ExerciseOption(
    id: 'bodyweight',
    label: '맨몸 운동',
    icon: Icons.accessibility_new,
    reaction: '어디서든 할 수 있는 맨몸 운동! 기본기가 탄탄하시겠네요!',
  ),
  _ExerciseOption(
    id: 'cardio',
    label: '유산소',
    icon: Icons.directions_run,
    reaction: '꾸준한 유산소 운동, 체력의 기본이죠! 응원합니다!',
  ),
  _ExerciseOption(
    id: 'yoga',
    label: '요가/필라테스',
    icon: Icons.self_improvement,
    reaction: '유연성과 코어를 동시에! 자세에 대한 감각이 남다르시겠네요!',
  ),
  _ExerciseOption(
    id: 'martial_arts',
    label: '격투기',
    icon: Icons.sports_mma,
    reaction: '격투기 좋아하시는군요! 강인한 정신력이 느껴집니다!',
  ),
  _ExerciseOption(
    id: 'swimming',
    label: '수영',
    icon: Icons.pool,
    reaction: '전신 운동의 왕, 수영! 균형 잡힌 체력을 가지고 계시겠네요!',
  ),
];

class Step3Interests extends StatefulWidget {
  final List<String> initialInterests;
  final bool loading;
  final void Function(List<String> interests) onSubmit;

  const Step3Interests({
    super.key,
    required this.initialInterests,
    required this.loading,
    required this.onSubmit,
  });

  @override
  State<Step3Interests> createState() => _Step3InterestsState();
}

class _Step3InterestsState extends State<Step3Interests> {
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  late List<String> _selected;
  String? _lastSelectedId;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialInterests);
    if (_selected.isNotEmpty) {
      _lastSelectedId = _selected.last;
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_lastSelectedId == id) {
          _lastSelectedId = _selected.isNotEmpty ? _selected.last : null;
        }
      } else {
        _selected.add(id);
        _lastSelectedId = id;
      }
    });
  }

  String? get _reactionText {
    if (_selected.isEmpty) return null;
    final lastOption = _exerciseOptions.firstWhere(
      (o) => o.id == _lastSelectedId,
      orElse: () => _exerciseOptions.first,
    );

    if (_selected.length == 1) {
      return lastOption.reaction;
    } else {
      return '${_selected.length}개나 선택하셨네요! ${lastOption.reaction}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            '관심 운동',
            style: TextStyle(
              color: textMain,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '관심 있는 운동을 모두 선택해주세요!',
            style: TextStyle(color: textSub, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // 운동 그리드
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _exerciseOptions.map((option) {
              final isSelected = _selected.contains(option.id);
              return _buildExerciseCircle(option, isSelected);
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 리액션 버블
          if (_reactionText != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _reactionText!,
                        style: const TextStyle(
                          color: textMain,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),

          // CTA 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected.isNotEmpty && !widget.loading
                  ? () => widget.onSubmit(List.from(_selected))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.celebration,
                          size: 18,
                          color: _selected.isNotEmpty
                              ? Colors.white
                              : textSub.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '시작하기!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _selected.isNotEmpty
                                ? Colors.white
                                : textSub.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExerciseCircle(_ExerciseOption option, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggle(option.id),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? primary.withValues(alpha: 0.2)
                    : primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: isSelected ? primary : primary.withValues(alpha: 0.15),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  option.icon,
                  size: 32,
                  color: isSelected ? primary : primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? textMain : textSub,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
