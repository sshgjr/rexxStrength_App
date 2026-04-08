import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexx_app/services/level_service.dart';
import 'package:rexx_app/features/pose_evaluation/engine/layer_classifier.dart';

void main() {
  group('LevelService', () {
    late LevelService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LevelService();
    });

    test('기본 등급은 beginner', () async {
      final level = await service.getCurrentLevel();
      expect(level, UserLevel.beginner);
    });

    test('등급 로컬 캐시 저장/조회', () async {
      await service.saveLocalLevel(UserLevel.intermediate);
      final level = await service.getCurrentLevel();
      expect(level, UserLevel.intermediate);
    });

    group('등급 제안 로직', () {
      test('초급→중급: 평균 80점 이상 3회 연속', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [82, 85, 80],
        );
        expect(suggestion, LevelSuggestion.upgrade);
      });

      test('중급→상급: 평균 85점 이상 3회 연속', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [88, 90, 86],
        );
        expect(suggestion, LevelSuggestion.upgrade);
      });

      test('상급→중급: 평균 60점 미만 3회 연속 (엄격)', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.advanced,
          recentScores: [55, 50, 58],
        );
        expect(suggestion, LevelSuggestion.downgrade);
      });

      test('중급→초급: 평균 50점 미만 5회 연속 (보수적)', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [45, 48, 42, 49, 40],
        );
        expect(suggestion, LevelSuggestion.downgrade);
      });

      test('중급→초급: 4회만이면 제안 안 함', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [45, 48, 42, 49],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('상급자는 이미 최고 등급이므로 승급 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.advanced,
          recentScores: [95, 98, 92],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('초급자는 이미 최저 등급이므로 하향 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [30, 25, 20, 15, 10],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('점수 부족하면 제안 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [90, 95],
        );
        expect(suggestion, LevelSuggestion.none);
      });
    });

    group('제안 메시지', () {
      test('승급 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.upgrade,
          UserLevel.beginner,
        );
        expect(msg, contains('중급'));
      });

      test('상급→중급 하향 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.downgrade,
          UserLevel.advanced,
        );
        expect(msg, contains('평소와 다른 패턴'));
      });

      test('중급→초급 하향 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.downgrade,
          UserLevel.intermediate,
        );
        expect(msg, contains('세부적인 코칭'));
      });
    });
  });
}
