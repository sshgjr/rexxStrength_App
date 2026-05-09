import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../features/pose_evaluation/models/evaluation_result.dart';
import '../features/pose_evaluation/models/history_item.dart';

/// 피드백 요청 결과 (성공/실패 원인 구분)
class FeedbackResult {
  final String? feedback;
  final FeedbackError? error;

  FeedbackResult.success(this.feedback) : error = null;
  FeedbackResult.failure(this.error) : feedback = null;

  bool get isSuccess => feedback != null;
}

enum FeedbackError {
  /// 기기가 오프라인 상태
  offline,
  /// 로그인 토큰 없음
  noToken,
  /// 서버에 연결되었으나 API 처리 실패 (Gemini API 오류 등)
  apiError,
  /// 요청 시간 초과
  timeout,
  /// 게스트 무료 체험 횟수 소진
  guestLimitReached,
  /// 알 수 없는 오류
  unknown,
}

extension FeedbackErrorMessage on FeedbackError {
  String get message {
    switch (this) {
      case FeedbackError.offline:
        return '인터넷 연결이 되어 있지 않습니다.';
      case FeedbackError.noToken:
        return '로그인이 필요합니다. 다시 로그인해 주세요.';
      case FeedbackError.apiError:
        return '서버에서 AI 피드백을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      case FeedbackError.timeout:
        return '서버 응답 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.';
      case FeedbackError.guestLimitReached:
        return '무료 AI 코칭 체험이 끝났습니다. 회원가입하면 계속 이용할 수 있어요!';
      case FeedbackError.unknown:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }
}

/// 온라인/오프라인 피드백 서비스
class PoseFeedbackService {
  static const int _maxGuestFeedbackCount = 999; // TODO: 테스트 후 2로 복원
  static const String _guestCountKey = 'guest_feedback_count';

  /// 게스트 AI 피드백 남은 횟수 확인
  Future<bool> canUseGuestFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_guestCountKey) ?? 0;
    return count < _maxGuestFeedbackCount;
  }

  /// 게스트 사용 횟수 증가 (성공 시에만 호출)
  Future<void> _incrementGuestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_guestCountKey) ?? 0;
    await prefs.setInt(_guestCountKey, count + 1);
  }

  /// 서버에 피드백 요청 (온라인 시)
  /// 오프라인이면 FeedbackResult.failure 반환 + 대기열 저장
  Future<FeedbackResult> requestFeedback({
    required EvaluationResult result,
    required String? token,
    String userLevel = 'beginner',
  }) async {
    // 1. 토큰 확인 — 게스트 모드 처리
    final bool isGuest = token == null;
    if (isGuest) {
      final canUse = await canUseGuestFeedback();
      if (!canUse) {
        debugPrint('[PoseFeedbackService] ❌ 게스트 무료 체험 소진');
        return FeedbackResult.failure(FeedbackError.guestLimitReached);
      }
      debugPrint('[PoseFeedbackService] 🎁 게스트 무료 체험 모드');
    }

    // 2. 피드백 요청 (서버 연결 확인을 별도로 하지 않고 바로 API 호출)
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/pose/feedback'),
        headers: headers,
        body: jsonEncode(result.toJson(userLevel: userLevel)),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedback = data['feedback'] as String?;
        if (isGuest) {
          await _incrementGuestCount();
          debugPrint('[PoseFeedbackService] ✅ 게스트 AI 피드백 수신 성공 (카운트 증가)');
        } else {
          debugPrint('[PoseFeedbackService] ✅ AI 피드백 수신 성공');
        }
        return FeedbackResult.success(feedback);
      }

      // 서버 응답은 왔지만 오류 (4xx, 5xx)
      debugPrint('[PoseFeedbackService] ❌ 서버 응답 오류: ${response.statusCode} / ${response.body}');
      return FeedbackResult.failure(FeedbackError.apiError);

    } on TimeoutException {
      debugPrint('[PoseFeedbackService] ❌ 요청 시간 초과');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.timeout);
    } on SocketException catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 네트워크 연결 실패: $e');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.offline);
    } catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 알 수 없는 오류: $e');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.unknown);
    }
  }

  /// 평가 이력 조회. 실패 시 예외 throw — 호출 측에서 에러 UI 처리.
  Future<List<HistoryItem>> getHistory({required String token}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/pose/history'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw HttpException('history fetch failed: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final raw = data['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 오프라인 대기열에 결과 저장
  Future<void> _saveToQueue(EvaluationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('pose_feedback_queue') ?? [];
    queue.add(jsonEncode(result.toJson()));
    await prefs.setStringList('pose_feedback_queue', queue);
  }

  /// 재연결 시 대기열 전송
  Future<void> syncQueue({required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('pose_feedback_queue') ?? [];

    if (queue.isEmpty) return;

    final remaining = <String>[];
    for (final item in queue) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/pose/feedback'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: item,
        );

        if (response.statusCode != 200) {
          remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
        break;
      }
    }

    await prefs.setStringList('pose_feedback_queue', remaining);
  }
}
