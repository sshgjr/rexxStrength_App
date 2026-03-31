import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../features/pose_evaluation/engine/layer_classifier.dart';

enum LevelSuggestion { none, upgrade, downgrade }

class LevelService {
  static const String _levelKey = 'user_level';
  static const String _scoresKey = 'recent_scores';

  /// 로컬 캐시에서 현재 등급 조회
  Future<UserLevel> getCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_levelKey);
    return value != null ? UserLevel.fromString(value) : UserLevel.beginner;
  }

  /// 로컬 캐시에 등급 저장
  Future<void> saveLocalLevel(UserLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, level.apiName);
  }

  /// 서버에 등급 변경 요청
  Future<bool> updateServerLevel(UserLevel level, String token) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/me/level'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'level': level.apiName}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await saveLocalLevel(level);
        return true;
      }
    } catch (e) {
      debugPrint('[LevelService] 등급 변경 실패: $e');
    }
    return false;
  }

  /// 최근 점수 저장 (로컬)
  Future<void> addScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = prefs.getStringList(_scoresKey) ?? [];
    scores.add(score.toString());
    // 최근 10회만 유지
    if (scores.length > 10) {
      scores.removeRange(0, scores.length - 10);
    }
    await prefs.setStringList(_scoresKey, scores);
  }

  /// 최근 점수 조회
  Future<List<int>> getRecentScores() async {
    final prefs = await SharedPreferences.getInstance();
    final scores = prefs.getStringList(_scoresKey) ?? [];
    return scores.map((s) => int.parse(s)).toList();
  }

  /// 등급 변경 제안 확인 (순수 함수)
  static LevelSuggestion checkLevelSuggestion({
    required UserLevel currentLevel,
    required List<int> recentScores,
  }) {
    // 승급 체크
    if (currentLevel != UserLevel.advanced && recentScores.length >= 3) {
      final last3 = recentScores.sublist(recentScores.length - 3);
      final threshold = currentLevel == UserLevel.beginner ? 80 : 85;
      if (last3.every((s) => s >= threshold)) {
        return LevelSuggestion.upgrade;
      }
    }

    // 하향 체크
    if (currentLevel == UserLevel.advanced && recentScores.length >= 3) {
      final last3 = recentScores.sublist(recentScores.length - 3);
      if (last3.every((s) => s < 60)) {
        return LevelSuggestion.downgrade;
      }
    } else if (currentLevel == UserLevel.intermediate && recentScores.length >= 5) {
      final last5 = recentScores.sublist(recentScores.length - 5);
      if (last5.every((s) => s < 50)) {
        return LevelSuggestion.downgrade;
      }
    }

    return LevelSuggestion.none;
  }

  /// 제안 메시지 생성
  static String suggestionMessage(LevelSuggestion suggestion, UserLevel currentLevel) {
    if (suggestion == LevelSuggestion.upgrade) {
      final nextLevel = currentLevel == UserLevel.beginner
          ? UserLevel.intermediate
          : UserLevel.advanced;
      return '최근 자세가 안정적이에요! ${nextLevel.displayName}으로 올려볼까요?';
    }

    if (suggestion == LevelSuggestion.downgrade) {
      if (currentLevel == UserLevel.advanced) {
        return '최근 자세가 평소와 다른 패턴이 보여요. 중급 모드로 전환하면 더 구체적인 피드백을 받을 수 있어요.';
      } else {
        return '더 세부적인 코칭을 받아보시겠어요? 단계를 조정하면 원인과 수정 방법까지 안내해 드려요.';
      }
    }

    return '';
  }

  /// 제안 시 변경될 등급 반환
  static UserLevel suggestedLevel(LevelSuggestion suggestion, UserLevel currentLevel) {
    if (suggestion == LevelSuggestion.upgrade) {
      return currentLevel == UserLevel.beginner
          ? UserLevel.intermediate
          : UserLevel.advanced;
    }
    if (suggestion == LevelSuggestion.downgrade) {
      return currentLevel == UserLevel.advanced
          ? UserLevel.intermediate
          : UserLevel.beginner;
    }
    return currentLevel;
  }
}
