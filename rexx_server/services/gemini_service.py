import os
import json
import traceback
import google.generativeai as genai

SYSTEM_PROMPT = """너는 친근한 헬스 코치다.
사용자의 운동 점수 데이터를 보고 아래 규칙에 따라 한국어 피드백을 JSON으로만 출력해라.

[점수 해석 기준]
- 85점 이상: 매우 잘함. 칭찬 위주로 말하고 더 발전할 포인트 1개만 살짝 언급
- 70~84점: 잘하고 있음. 칭찬 먼저, 개선점 1개만
- 50~69점: 보통. 가장 중요한 개선점 1~2개
- 50점 미만: 기초부터 다시. 핵심 1개만 집중

[말투 규칙]
- 초보자도 바로 이해하는 쉬운 말
- 코치가 옆에서 말하듯 따뜻하게
- "~해봐요", "~해보세요", "~해주세요" 톤
- 절대 비난하거나 "문제가 있습니다" 같은 말 쓰지 말 것
- 추상적인 말(예: "집중하세요") 대신 신체 부위와 방향을 구체적으로 말할 것
  예: "손목을 끝까지 올릴 때 1초 버텨보세요"
  예: "팔꿈치를 무릎 위에 고정하고 움직여보세요"

[출력 형식 - JSON만 출력, 다른 텍스트 없음]
{
  "summary": "전체 수행에 대한 한 줄 평가 (칭찬 또는 긍정적 시작)",
  "reason": "왜 그런지 이유 설명 (구체적 신체 동작 기반)",
  "action": "지금 당장 할 수 있는 행동 1~2개 (신체 부위 + 방향 + 타이밍 포함)",
  "cue": "8자~16자 짜리 핵심 한 줄 (동작 위주)"
}"""

# 운동별 맥락 정보 — 제미나이가 운동을 이해하도록
EXERCISE_CONTEXT = {
    "wrist_curl": """
[리스트컬 운동 특성]
- 전완을 무릎이나 벤치에 고정하고 손목만 위아래로 움직이는 운동
- 이 사용자는 손가락 끝까지 내리는 핑거롤 방식으로 수행함 (Full ROM)
- 정상 가동범위: 손가락 끝까지 내렸다가(-30~-45도) 손목을 최대한 올리는 것(+60~+80도), 총 100~130도
- 전완이 고정된 상태에서 손목만 움직이는 게 핵심
- 좌우 손이 비슷한 타이밍과 각도로 움직여야 함
""",
    "squat": """
[스쿼트 운동 특성]
- 발을 어깨너비로 벌리고 무릎을 굽혔다 펴는 운동
- 정상 깊이: 허벅지가 지면과 평행(무릎 각도 90도 이하)
- 무릎이 발끝 방향으로 향해야 하고, 등은 곧게 유지
""",
    "bench_press": """
[벤치프레스 운동 특성]
- 누운 상태에서 바벨/덤벨을 가슴까지 내렸다가 올리는 운동
- 정상 바텀: 팔꿈치 각도 85~95도
- 팔꿈치는 몸통과 약 45도 각도 유지
""",
    "deadlift": """
[데드리프트 운동 특성]
- 바닥의 바벨을 엉덩이 힌지로 들어올리는 운동
- 등은 45도 이내로 유지, 무릎은 살짝만 굽힘
- 마지막에 엉덩이를 완전히 펴서 락아웃 완성
""",
}

def generate_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    detected_issues: list,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("[GeminiService] GEMINI_API_KEY 없음, 기본 피드백 반환")
        return _fallback_feedback(exercise_type, total_score, criteria_scores)

    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    # 점수 수준 레이블 — 제미나이가 어조를 판단하는 기준
    if total_score >= 85:
        score_level = "매우 잘함 (칭찬 위주로)"
    elif total_score >= 70:
        score_level = "잘하고 있음 (칭찬 먼저, 개선 1개)"
    elif total_score >= 50:
        score_level = "보통 (개선점 1~2개)"
    else:
        score_level = "기초 필요 (핵심 1개만)"

    # 기준별 점수 — 잘한 항목과 아쉬운 항목 분리해서 전달
    good_criteria = [c for c in criteria_scores if c['score'] >= 75]
    weak_criteria = [c for c in criteria_scores if c['score'] < 75]

    good_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ✅"
        for c in good_criteria
    ) or "  없음"

    weak_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ⚠️"
        for c in weak_criteria
    ) or "  없음"

    # 운동 맥락 가져오기
    context = EXERCISE_CONTEXT.get(exercise_type, "")

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100 → 수준: {score_level}
{context}
[잘한 항목]
{good_text}

[아쉬운 항목]
{weak_text}

위 데이터를 바탕으로 이 사용자에게 코치 피드백을 JSON으로 작성해줘."""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=400,
                temperature=0.4,  # 0.7 → 0.4 (일관성 향상)
            ),
        )
        response = model.generate_content(user_message)
        result_text = response.text.strip()
        json.loads(result_text)  # 유효성 검증
        return result_text

    except Exception as e:
        print(f"[GeminiService] Gemini API 호출 실패: {e}")
        traceback.print_exc()
        return _fallback_feedback(exercise_type, total_score, criteria_scores)


def _fallback_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
) -> str:
    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    # 점수 기반으로 긍정/부정 분기
    if total_score >= 75:
        summary = f"{exercise_name} 전반적으로 잘 수행했어요!"
        action = "지금 자세를 유지하면서 반복 횟수를 늘려보세요."
        cue = "이 자세 그대로 유지"
    elif total_score >= 55:
        # 가장 약한 항목 찾기
        weak = min(criteria_scores, key=lambda c: c['score']) if criteria_scores else None
        weak_name = weak['name'] if weak else "동작"
        summary = f"{exercise_name} 괜찮게 하고 있어요. {weak_name}을 조금 더 다듬어봐요."
        action = f"{weak_name} 부분에 집중해서 천천히 다시 해보세요."
        cue = f"{weak_name}에 집중"
    else:
        summary = f"{exercise_name} 기본 동작부터 천천히 연습해봐요."
        action = "가벼운 무게로 천천히 Full ROM을 먼저 익혀보세요."
        cue = "천천히 끝까지 움직여요"

    fallback = {
        "summary": summary,
        "reason": f"총점 {total_score}점 기준으로 생성된 기본 피드백이에요.",
        "action": action,
        "cue": cue,
    }
    return json.dumps(fallback, ensure_ascii=False)
