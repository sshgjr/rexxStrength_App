import 'package:flutter/material.dart';
import '../models/evaluation_result.dart';
import '../widgets/feedback_card.dart';
import '../widgets/signup_prompt_sheet.dart';
import '../../../pages/login_page.dart';
import '../../../services/level_service.dart';
import '../widgets/level_suggestion_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _checkLevelSuggestion();
    }
  }

  Future<void> _checkLevelSuggestion() async {
    final levelService = LevelService();
    final currentLevel = await levelService.getCurrentLevel();
    final recentScores = await levelService.getRecentScores();

    final suggestion = LevelService.checkLevelSuggestion(
      currentLevel: currentLevel,
      recentScores: recentScores,
    );

    if (suggestion == LevelSuggestion.none || !mounted) return;

    // 약간의 딜레이 후 표시 (결과 화면이 먼저 보이도록)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final accepted = await LevelSuggestionSheet.show(
      context,
      suggestion: suggestion,
      currentLevel: currentLevel,
    );

    if (accepted == true && widget.token != null) {
      final newLevel = LevelService.suggestedLevel(suggestion, currentLevel);
      await levelService.updateServerLevel(newLevel, widget.token!);
    }
  }

  /// 회원가입 유도 팝업을 표시하고 결과에 따라 처리
  Future<bool> _handleGuestExit() async {
    final result = await SignupPromptSheet.show(
      context,
      widget.result.totalScore,
    );

    if (!mounted) return false;

    if (result == true) {
      final loginResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

      if (loginResult != null && mounted) {
        Navigator.pop(context, loginResult);
      }
      return false;
    } else if (result == false) {
      return true;
    }

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
            '${widget.result.exerciseType.displayName} 코칭',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // AI 코칭 피드백 (메인 콘텐츠)
              FeedbackCard(
                feedbackText: widget.result.feedbackText,
                offlineFeedback: widget.result.offlineFeedback,
                error: widget.result.feedbackError,
                layerClassification: widget.result.layerClassification,
              ),
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
