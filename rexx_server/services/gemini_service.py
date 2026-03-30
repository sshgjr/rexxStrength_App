import os
import json
import traceback
import google.generativeai as genai

SYSTEM_PROMPT = """너는 팔씨름/스트렝스 스포츠 전문 코치다.
사용자의 운동 점수 데이터를 보고 아래 규칙에 따라 한국어 피드백을 JSON으로만 출력해라.

[코칭 철학]
- 이 시스템은 보디빌딩 정석 자세만을 강요하지 않는다.
- 사용자의 수행을 "목적 기반"으로 평가한다.
- 특히 팔씨름, 스트렝스 향상 관점에서 유효한 수행은 인정한다.
- 평가의 핵심 질문: "이 수행이 목적에 유리한가? 리스크 대비 이득이 있는가?"

[평가 기준]
1. 수행 안정성 (중량 컨트롤 여부)
2. 자극 전달 (목표 근육 사용 여부)
3. 보상 움직임 (치팅 여부 및 의도성)
4. 리스크 대비 리워드

[판단 규칙]
- 팔이 일부 움직이더라도:
    → 더 높은 중량을 안정적으로 컨트롤하고 있다면
    → "의도된 치팅"으로 긍정 평가 가능
- 완벽한 고립이 아니어도:
    → 실제 스포츠(팔씨름)에 도움이 된다면 긍정 평가
- 단, 다음은 감점:
    → 통제 불가능한 반동
    → 부상 위험이 높은 꺾임
    → 중량을 버티지 못하는 경우

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
- 무조건 교정부터 하지 않는다. 먼저 "잘한 점"을 찾는다. 그 다음 "리스크 or 개선 포인트"를 제시한다
- 추상적인 말(예: "집중하세요") 대신 신체 부위와 방향을 구체적으로 말할 것
  예: "손목을 끝까지 올릴 때 1초 버텨보세요"
  예: "팔꿈치를 무릎 위에 고정하고 움직여보세요"

[스타일 분류 기준]
- strict: 보디빌딩 스타일 — 완벽한 고립, 정석 자세 우선
- cheat: 고중량 트레이닝 — 반동/치팅을 의도적으로 사용, 중량 컨트롤이 핵심
- strength: 파워 중심 — 전신 연동, 힘 전달 효율 우선
- armwrestling: 실전형 — 팔씨름 동작 패턴에 유리한 각도/근육 사용 우선

[출력 형식 - JSON만 출력, 다른 텍스트 없음]
{
  "summary": "전체 수행에 대한 한 줄 평가 (칭찬 또는 긍정적 시작)",
  "reason": "왜 그런지 이유 설명 (구체적 신체 동작 기반, 잘한 점 먼저)",
  "action": "지금 당장 할 수 있는 행동 1~2개 (신체 부위 + 방향 + 타이밍 포함)",
  "cue": "8자~16자 짜리 핵심 한 줄 (동작 위주)",
  "style": "strict / cheat / strength / armwrestling 중 이 수행에 가장 가까운 스타일"
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
- 팔씨름 관점: 손목 굴곡 강화가 목적이므로 팔이 일부 움직이더라도
  중량을 안정적으로 컨트롤하고 있다면 의도된 치팅으로 긍정 평가 가능
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

위 데이터를 바탕으로 이 사용자에게 코치 피드백을 JSON으로 작성해줘.
반드시 잘한 점을 먼저 언급하고, 교정이 필요한 경우에도 리스크 관점에서 부드럽게 제안해줘."""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=400,
                temperature=0.4,
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

    if total_score >= 75:
        summary = f"{exercise_name} 전반적으로 잘 수행했어요!"
        action = "지금 자세를 유지하면서 반복 횟수를 늘려보세요."
        cue = "이 자세 그대로 유지"
        style = "strict"
    elif total_score >= 55:
        weak = min(criteria_scores, key=lambda c: c['score']) if criteria_scores else None
        weak_name = weak['name'] if weak else "동작"
        summary = f"{exercise_name} 중량 컨트롤은 안정적으로 이루어지고 있어요."
        action = f"{weak_name} 부분에서 손목만으로 버티는 구간을 조금 더 늘려보세요."
        cue = f"손목으로 버텨라"
        style = "cheat"
    else:
        summary = f"{exercise_name} 기본 동작부터 천천히 연습해봐요."
        action = "가벼운 무게로 천천히 Full ROM을 먼저 익혀보세요."
        cue = "천천히 끝까지 움직여요"
        style = "strict"

    fallback = {
        "summary": summary,
        "reason": f"총점 {total_score}점 기준으로 생성된 기본 피드백이에요.",
        "action": action,
        "cue": cue,
        "style": style,
    }
    return json.dumps(fallback, ensure_ascii=False)
