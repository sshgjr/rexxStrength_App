import 'package:flutter/material.dart';

/// 비로그인 사용자에게 회원가입을 유도하는 BottomSheet 위젯.
/// 점수에 따라 다른 메시지를 표시하고, "나중에" 클릭 시 2차 확인을 보여준다.
class SignupPromptSheet extends StatefulWidget {
  final int totalScore;

  const SignupPromptSheet({super.key, required this.totalScore});

  /// BottomSheet를 표시하고, 사용자의 선택을 반환한다.
  /// - true: 회원가입 선택
  /// - false: 나가기 선택
  /// - null: 시트가 닫힘 (외부 탭 등)
  static Future<bool?> show(BuildContext context, int totalScore) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SignupPromptSheet(totalScore: totalScore),
    );
  }

  @override
  State<SignupPromptSheet> createState() => _SignupPromptSheetState();
}

class _SignupPromptSheetState extends State<SignupPromptSheet> {
  static const Color bg = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  bool _showConfirmation = false;

  _PromptContent get _content {
    if (widget.totalScore >= 70) {
      return _PromptContent(
        icon: Icons.emoji_events,
        iconColor: const Color(0xFFFFD700),
        header: '축하합니다! 상위 랭커의 자질이 보여요',
        subMessage: '회원가입하고 랭킹에 이름을 올리세요',
        illustration: _buildRankingPreview(),
      );
    } else if (widget.totalScore >= 50) {
      return _PromptContent(
        icon: Icons.trending_up,
        iconColor: primary,
        header: '좋은 시작이에요!',
        subMessage: '첫 기록을 저장하고 성장을 추적하세요',
        illustration: _buildGrowthGraph(),
      );
    } else {
      return _PromptContent(
        icon: Icons.local_fire_department,
        iconColor: const Color(0xFFF97316),
        header: '모든 챔피언은 여기서 시작했어요',
        subMessage: 'AI 코치가 함께할게요. 시작해볼까요?',
        illustration: _buildEncouragement(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: _showConfirmation ? _buildConfirmation() : _buildMainPrompt(),
    );
  }

  Widget _buildMainPrompt() {
    final content = _content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),

        // 아이콘
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: content.iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(content.icon, color: content.iconColor, size: 32),
        ),
        const SizedBox(height: 20),

        // 헤더
        Text(
          content.header,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textMain,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // 서브 메시지
        Text(
          content.subMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: textSub, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),

        // 시각 요소
        content.illustration,
        const SizedBox(height: 28),

        // 메인 CTA 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '회원가입하고 기록 저장하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 나중에 버튼
        TextButton(
          onPressed: () {
            setState(() => _showConfirmation = true);
          },
          child: const Text(
            '나중에',
            style: TextStyle(color: textSub, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),

        // 경고 아이콘
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.history,
            color: Color(0xFFF59E0B),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          '이 기록은 저장되지 않아요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        const Text(
          '다음에 또 처음부터 시작해야 해요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSub, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),

        // 역시 가입할게요 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '역시 가입할게요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 그래도 나가기 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: textSub,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '그래도 나가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  /// 70+ 점수: 흐릿한 랭킹 보드 미리보기
  Widget _buildRankingPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Text(
            '실시간 랭킹',
            style: TextStyle(
              color: textSub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // 흐릿한 랭킹 항목들
          for (int i = 0; i < 3; i++) ...[
            Opacity(
              opacity: 0.4 - (i * 0.1),
              child: Container(
                height: 36,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFFFFD700).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? const Color(0xFFFFD700) : textSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: textSub, size: 14),
              const SizedBox(width: 4),
              Text(
                '회원가입 후 확인 가능',
                style: TextStyle(
                  color: textSub.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 50-69 점수: 성장 그래프 일러스트
  Widget _buildGrowthGraph() {
    return Container(
      width: double.infinity,
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildGraphBar('오늘', widget.totalScore / 100, primary),
          _buildGraphBar('2주 후', (widget.totalScore + 15) / 100, primary.withValues(alpha: 0.6)),
          _buildGraphBar('1개월', (widget.totalScore + 25) / 100, primary.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildGraphBar(String label, double ratio, Color color) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 50 * clampedRatio,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: textSub, fontSize: 11),
        ),
      ],
    );
  }

  /// 0-49 점수: 격려 메시지
  Widget _buildEncouragement() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.1),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.sports_gymnastics,
            size: 28,
            color: Color(0xFFF97316),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI 코치의 맞춤 피드백으로\n더 빠르게 성장할 수 있어요',
              style: TextStyle(
                color: textMain,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptContent {
  final IconData icon;
  final Color iconColor;
  final String header;
  final String subMessage;
  final Widget illustration;

  const _PromptContent({
    required this.icon,
    required this.iconColor,
    required this.header,
    required this.subMessage,
    required this.illustration,
  });
}
