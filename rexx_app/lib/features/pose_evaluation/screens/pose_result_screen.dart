import 'package:flutter/material.dart';
import '../models/evaluation_result.dart';
import '../widgets/score_gauge.dart';
import '../widgets/criterion_breakdown.dart';
import '../widgets/feedback_card.dart';
import '../widgets/signup_prompt_sheet.dart';
import '../../../pages/login_page.dart';

class PoseResultScreen extends StatefulWidget {
  final EvaluationResult result;
  final String? token;

  const PoseResultScreen({
    super.key,
    required this.result,
    this.token,
  });

  @override
  State<PoseResultScreen> createState() => _PoseResultScreenState();
}

class _PoseResultScreenState extends State<PoseResultScreen> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color textMain = Color(0xFFE9F5EF);
  bool get _isGuest => widget.token == null;

  /// 회원가입 유도 팝업을 표시하고 결과에 따라 처리
  Future<bool> _handleGuestExit() async {
    final result = await SignupPromptSheet.show(
      context,
      widget.result.totalScore,
    );

    if (!mounted) return false;

    if (result == true) {
      // 회원가입 선택 → LoginPage로 이동
      final loginResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

      if (loginResult != null && mounted) {
        // 가입/로그인 성공 → 로그인 정보와 함께 홈으로 돌아가기
        // pop으로 ExerciseSelectScreen에 결과 전달 → HomeScreen까지 전파
        Navigator.pop(context, loginResult);
      }
      return false; // 이미 네비게이션 처리됨
    } else if (result == false) {
      // "그래도 나가기" 선택
      return true;
    }

    // null (시트 닫힘) — 아무 것도 안 함
    return false;
  }

  void _onHomePressed() async {
    if (_isGuest) {
      final shouldExit = await _handleGuestExit();
      if (shouldExit && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isGuest,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleGuestExit();
        if (shouldExit && mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: textMain,
          title: Text(
            '${widget.result.exerciseType.displayName} 평가 결과',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 원형 점수 게이지
              ScoreGauge(score: widget.result.totalScore),
              const SizedBox(height: 30),

              // LLM 피드백 카드
              FeedbackCard(
                feedbackText: widget.result.feedbackText,
                offlineFeedback: widget.result.offlineFeedback,
                error: widget.result.feedbackError,
              ),
              const SizedBox(height: 24),

              // 기준별 상세 점수
              CriterionBreakdown(criteria: widget.result.criteria),
              const SizedBox(height: 30),

              // 홈으로 돌아가기
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onHomePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
