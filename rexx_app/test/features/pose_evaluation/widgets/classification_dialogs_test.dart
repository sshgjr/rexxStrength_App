import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/widgets/classification_dialogs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('showAmbiguousDialog', () {
    testWidgets('상위 2개 운동 버튼이 표시된다', (tester) async {
      ExerciseType? selected;
      final result = ClassificationResult(probabilities: {
        ExerciseType.squat: 0.45,
        ExerciseType.deadlift: 0.40,
        ExerciseType.benchPress: 0.15,
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showAmbiguousDialog(context, result);
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 제목
      expect(find.text('운동 종류를 확인해 주세요'), findsOneWidget);
      // 상위 2개 운동 표시
      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('데드리프트'), findsOneWidget);

      // 첫 번째 선택
      await tester.tap(find.text('스쿼트'));
      await tester.pumpAndSettle();
      expect(selected, ExerciseType.squat);
    });
  });

  group('showClassificationFailedDialog', () {
    testWidgets('"예" 선택 시 3개 운동이 확률순으로 표시된다', (tester) async {
      ExerciseType? selected;
      final result = ClassificationResult(probabilities: {
        ExerciseType.deadlift: 0.35,
        ExerciseType.squat: 0.33,
        ExerciseType.benchPress: 0.32,
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showClassificationFailedDialog(context, result);
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 지원 운동 목록 표시
      expect(find.textContaining('스쿼트'), findsOneWidget);
      // "예" 버튼
      await tester.tap(find.text('예'));
      await tester.pumpAndSettle();

      // 3개 운동 확률순 선택지
      expect(find.text('데드리프트'), findsOneWidget);
      await tester.tap(find.text('데드리프트'));
      await tester.pumpAndSettle();
      expect(selected, ExerciseType.deadlift);
    });

    testWidgets('"아니오" 선택 시 텍스트 입력 + 감사 메시지 표시', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              await showClassificationFailedDialog(
                context,
                ClassificationResult(probabilities: {
                  ExerciseType.squat: 0.35,
                  ExerciseType.benchPress: 0.33,
                  ExerciseType.deadlift: 0.32,
                }),
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('아니오'));
      await tester.pumpAndSettle();

      // 텍스트 입력 필드
      expect(find.byType(TextField), findsOneWidget);

      // 입력 후 제출
      await tester.enterText(find.byType(TextField), '오버헤드프레스');
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();

      // 감사 메시지
      expect(find.textContaining('감사합니다'), findsOneWidget);
    });
  });
}
