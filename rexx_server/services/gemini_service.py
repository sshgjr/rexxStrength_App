import os
import json
import traceback
import google.generativeai as genai


def _build_system_prompt(user_level: str, has_layer1: bool) -> str:
    level_instructions = {
        "beginner": "레이어 2 항목: 원인과 구체적인 수정 방법을 안내해라.",
        "intermediate": "레이어 2 항목: '~해보시는 것도 좋습니다' 식의 부드러운 참고 안내만 해라.",
        "advanced": "레이어 2 항목: 언급하지 마라.",
    }

    return f"""너는 운동 코치다.
입력된 분석 결과를 바탕으로 아래 규칙에 따라 한국어 피드백을 생성해라.

규칙:
- 레이어 1 항목(부상 위험): 등급 무관, 반드시 경고. 부상 위험을 명확히 전달
- {level_instructions.get(user_level, level_instructions["beginner"])}
- 운동 초보자도 이해할 수 있게 써라
- 가장 중요한 문제 1~2개만 말해라
- 비난하지 말고 코칭 톤으로 써라
- 추상적인 말 대신 바로 실행 가능한 행동을 써라

출력 형식(JSON):
{{
  "feedback": "상세 설명 (2~3문장)",
  "keypoint": "핵심 한 문장 (8~16자)",
  "cause": "자세 문제 원인 분석 (1~2문장)"
}}"""


def generate_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    detected_issues: list,
    user_level: str = "beginner",
    layer1_issues: list | None = None,
    layer2_issues: list | None = None,
) -> str:
    """Gemini 2.5 Flash Lite를 사용하여 운동 자세 피드백 생성"""

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("[GeminiService] GEMINI_API_KEY가 설정되지 않음, 기본 피드백 반환")
        return _fallback_feedback(exercise_type, total_score, detected_issues)

    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    criteria_text = "\n".join(
        f"- {c['name']}: {c['score']:.0f}점 ({c['grade']})"
        for c in criteria_scores
    )

    # 레이어별 이슈 텍스트 구성
    l1_text = "없음"
    l2_text = "없음"
    has_layer1 = False

    if layer1_issues:
        has_layer1 = True
        l1_text = "\n".join(
            f"- {i['criterion']}: {i['score']:.0f}점 ({i['grade']}) — {i['reason']}"
            for i in layer1_issues
        )

    if layer2_issues:
        l2_text = "\n".join(
            f"- {i['criterion']}: {i['score']:.0f}점 ({i['grade']}) — {i['reason']}"
            for i in layer2_issues
        )

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100
사용자 등급: {user_level}

기준별 점수:
{criteria_text}

[레이어 1 — 부상 위험 항목]
{l1_text}

[레이어 2 — 스타일 허용 항목]
{l2_text}"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=_build_system_prompt(user_level, has_layer1),
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=400,
                temperature=0.7,
            ),
        )

        response = model.generate_content(user_message)
        result_text = response.text.strip()

        # JSON 유효성 검증
        json.loads(result_text)
        return result_text

    except Exception as e:
        print(f"[GeminiService] Gemini API 호출 실패: {e}")
        traceback.print_exc()
        return _fallback_feedback(exercise_type, total_score, detected_issues)


def _fallback_feedback(exercise_type: str, total_score: int, detected_issues: list) -> str:
    """API 실패 시 기본 피드백 (3종 JSON 형식)"""
    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    if detected_issues:
        feedback = f"{exercise_name} 분석 결과, {detected_issues[0]} 부분에서 개선이 필요합니다."
        keypoint = "자세 교정이 필요해요"
        cause = f"{detected_issues[0]}에서 문제가 감지되었습니다."
    else:
        feedback = f"{exercise_name} 전반적으로 양호한 자세입니다."
        keypoint = "좋은 자세입니다"
        cause = "특별한 문제가 감지되지 않았습니다."

    fallback = {
        "feedback": feedback,
        "keypoint": keypoint,
        "cause": cause,
    }
    return json.dumps(fallback, ensure_ascii=False)
