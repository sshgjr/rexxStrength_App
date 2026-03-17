import 'package:flutter/material.dart';
import '../../../services/pose_feedback_service.dart';

/// LLM 피드백 카드 위젯
class FeedbackCard extends StatelessWidget {
  final String? feedbackText;
  final String offlineFeedback;
  final FeedbackError? error;

  const FeedbackCard({
    super.key,
    this.feedbackText,
    required this.offlineFeedback,
    this.error,
  });

  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  @override
  Widget build(BuildContext context) {
    final displayText = feedbackText ?? offlineFeedback;
    final isOnline = feedbackText != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.smart_toy : Icons.info_outline,
                color: isOnline ? primary : textSub,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'AI 코칭 피드백' : '기본 피드백',
                style: TextStyle(
                  color: isOnline ? primary : textSub,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayText,
            style: const TextStyle(
              color: textMain,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          if (!isOnline) ...[
            const SizedBox(height: 12),
            _buildErrorHint(),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorHint() {
    final errorInfo = _getErrorInfo();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: errorInfo.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(errorInfo.icon, color: errorInfo.iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorInfo.message,
              style: TextStyle(
                color: errorInfo.iconColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ErrorInfo _getErrorInfo() {
    switch (error) {
      case FeedbackError.offline:
        return _ErrorInfo(
          icon: Icons.wifi_off,
          iconColor: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          message: '네트워크에 연결되면 AI 코칭 피드백을 받을 수 있습니다.',
        );
      case FeedbackError.noToken:
        return _ErrorInfo(
          icon: Icons.lock_outline,
          iconColor: const Color(0xFF60A5FA),
          bgColor: const Color(0xFF60A5FA).withValues(alpha: 0.1),
          message: '로그인 후 AI 코칭 피드백을 이용할 수 있습니다.',
        );
      case FeedbackError.apiError:
        return _ErrorInfo(
          icon: Icons.cloud_off,
          iconColor: const Color(0xFFEF4444),
          bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
          message: 'AI 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        );
      case FeedbackError.timeout:
        return _ErrorInfo(
          icon: Icons.timer_off,
          iconColor: const Color(0xFFF97316),
          bgColor: const Color(0xFFF97316).withValues(alpha: 0.1),
          message: '서버 응답이 지연되고 있습니다. 네트워크 상태를 확인해 주세요.',
        );
      case FeedbackError.guestLimitReached:
        return _ErrorInfo(
          icon: Icons.card_giftcard,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          message: '무료 AI 코칭 체험이 끝났어요. 회원가입하면 무제한으로 이용할 수 있습니다!',
        );
      case FeedbackError.unknown:
      case null:
        return _ErrorInfo(
          icon: Icons.info_outline,
          iconColor: textSub,
          bgColor: Colors.white.withValues(alpha: 0.05),
          message: '인터넷 연결 시 AI 피드백을 받을 수 있습니다.',
        );
    }
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String message;

  const _ErrorInfo({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.message,
  });
}
