import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rexx_app/features/onboarding/models/onboarding_state.dart';
import 'package:rexx_app/features/onboarding/steps/result_step.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('5-A: 자동 산정 결과는 등급 + 피드백 미리보기 표시', (tester) async {
    final result = OnboardingResult(
      level: 'intermediate',
      levelSource: 'auto',
      avgTierScore: 2.3,
      cappedByExperience: false,
      feedbackStylePreview: '중급 사용자에게는 간결한 자세 교정 위주로 피드백을 드려요.',
      missingReasons: [],
    );

    await tester.pumpWidget(wrap(ResultStep(
      result: result,
      explicitSkip: false,
      onConfirm: () {},
    )));

    expect(find.textContaining('중급'), findsWidgets);
    expect(find.text('자동 산정됨'), findsOneWidget);
    expect(find.textContaining('간결한 자세 교정'), findsOneWidget);
    expect(find.textContaining('자동 산정을 못 한 이유'), findsNothing);
  });

  testWidgets('5-B: default 결과는 missing_reasons 불릿 렌더링', (tester) async {
    final result = OnboardingResult(
      level: 'beginner',
      levelSource: 'default',
      avgTierScore: null,
      cappedByExperience: false,
      feedbackStylePreview: '초급 사용자에게는 매우 상세한 자세 교정과 친절한 설명을 드려요.',
      missingReasons: [
        MissingReasonItem(
          code: 'missing_body_weight',
          message: '체중 정보가 없어 자동 산정을 할 수 없었어요.',
        ),
        MissingReasonItem(
          code: 'no_lift_inputs',
          message: '3대 중량을 한 종목도 입력하지 않으셨어요.',
        ),
      ],
    );

    await tester.pumpWidget(wrap(ResultStep(
      result: result,
      explicitSkip: false,
      onConfirm: () {},
    )));

    expect(find.text('회원님은 일단'), findsOneWidget);
    expect(find.textContaining('초급'), findsWidgets);
    expect(find.textContaining('자동 산정을 못 한 이유'), findsOneWidget);
    expect(find.textContaining('체중 정보가 없어'), findsOneWidget);
    expect(find.textContaining('3대 중량을 한 종목도'), findsOneWidget);
    expect(find.textContaining('매우 상세한 자세 교정'), findsOneWidget);
  });

  testWidgets('5-B explicit skip: missing_reasons 대신 건너뛰기 메시지', (tester) async {
    final result = OnboardingResult(
      level: 'beginner',
      levelSource: 'default',
      avgTierScore: null,
      cappedByExperience: false,
      feedbackStylePreview: '초급 사용자에게는...',
      missingReasons: [
        MissingReasonItem(code: 'no_lift_inputs', message: '...'),
      ],
    );

    await tester.pumpWidget(wrap(ResultStep(
      result: result,
      explicitSkip: true,
      onConfirm: () {},
    )));

    expect(find.textContaining('직접 건너뛰기를 선택하셨어요'), findsOneWidget);
  });

  testWidgets('확인 버튼 탭하면 onConfirm 호출', (tester) async {
    var confirmed = false;
    final result = OnboardingResult(
      level: 'intermediate',
      levelSource: 'auto',
      avgTierScore: 2.3,
      cappedByExperience: false,
      feedbackStylePreview: '...',
      missingReasons: [],
    );

    await tester.pumpWidget(wrap(ResultStep(
      result: result,
      explicitSkip: false,
      onConfirm: () => confirmed = true,
    )));

    await tester.tap(find.text('확인'));
    expect(confirmed, isTrue);
  });
}
