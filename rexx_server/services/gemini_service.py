import os
import json
import traceback
import google.generativeai as genai


SYSTEM_PROMPT = """너는 운동 코치다.
입력된 분석 결과를 바탕으로 아래 형식의 한국어 피드백만 생성해라.

규칙:
- 운동 초보자도 이해할 수 있게 써라
- 가장 중요한 문제 1~2개만 말해라
- 비난하지 말고 코칭 톤으로 써라
- 추상적인 말 대신 바로 실행 가능한 행동을 써라
- 마지막에 8자~16자짜리 한줄 큐를 줘라

출력 형식(JSON):
{
  "summary": "...",
  "reason": "...",
  "action": "...",
  "cue": "..."
}"""


def generate_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    detected_issues: list,
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

    issues_text = "\n".join(f"- {issue}" for issue in detected_issues) if detected_issues else "없음"

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100

기준별 점수:
{criteria_text}

감지된 이슈:
{issues_text}"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=SYSTEM_PROMPT,
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
    """API 실패 시 기본 피드백 (JSON 형식)"""
    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    if detected_issues:
        summary = f"{exercise_name} 분석 결과, {detected_issues[0]} 부분에서 개선이 필요합니다."
        action = f"{detected_issues[0]}에 집중하여 연습해 보세요."
    else:
        summary = f"{exercise_name} 전반적으로 양호한 자세입니다."
        action = "현재 자세를 유지하면서 반복 연습하세요."

    fallback = {
        "summary": summary,
        "reason": "자세 분석 점수를 기반으로 한 기본 피드백입니다.",
        "action": action,
        "cue": "자세에 집중하자",
    }
    return json.dumps(fallback, ensure_ascii=False)
