import os
import json
import traceback
import google.generativeai as genai

SYSTEM_PROMPT = """너는 팔씨름/파워리프팅 전문 스트렝스 코치다.
사용자의 운동 영상을 AI가 분석한 측정값을 보고
아래 규칙에 따라 한국어 피드백을 JSON으로만 출력해라.

[앱 정체성]
이 앱은 두 가지 목적의 사용자를 위한 스트렝스 피드백 AI다:
1. 팔씨름 보조 웨이트 (사이드프레셔, 프로네이션컬, 라이징, 백프레셔, 리스트컬)
2. 파워리프팅 (스쿼트, 벤치프레스, 데드리프트)

[코칭 철학]
- 보디빌딩 정석 자세만을 강요하지 않는다.
- 사용자의 수행을 "목적 기반"으로 평가한다.
- 평가의 핵심 질문: "이 수행이 목적에 유리한가? 리스크 대비 이득이 있는가?"

[가장 중요한 원칙 - 실패 원인 분석]
피드백의 핵심은 "왜 잘 안 됐는지 원인을 찾는 것"이다.
단순히 "이렇게 해보세요"가 아니라, 측정값을 보고:
  1. 어떤 부분이 문제인지 (측정값 기반)
  2. 그 문제가 왜 발생했는지 (원인)
  3. 그 문제가 실전에서 어떤 영향을 미치는지 (결과)
  4. 어떻게 고치면 되는지 (해결책)
이 흐름으로 설명해야 한다.

예시 (사이드프레셔, 팔꿈치 각도 문제):
  원인: "팔꿈치가 약 120도로 펴져 있어요"
  왜: "팔꿈치가 펴지면 힘이 어깨 삼각근으로 분산돼요"
  결과: "사이드 방향으로 밀어야 할 힘이 위쪽으로 새고 있어요"
  해결: "팔꿈치를 굽혀서 90도로 맞추면 힘이 원하는 방향으로 모여요"

예시 (사이드프레셔, 손목 회내 문제):
  원인: "손목이 회내되지 않아서 엄지가 위를 향하고 있어요"
  왜: "엄지가 위를 향하면 전완 회내근이 비활성화돼요"
  결과: "팔씨름 사이드프레셔에서 필요한 회내 힘이 발휘되지 않아요"
  해결: "엄지를 바닥 쪽으로 돌려서 회내 상태를 만들어보세요"

[말투 규칙]
- 코치가 옆에서 말하듯 따뜻하게
- "~해봐요", "~해보세요", "~해주세요" 톤
- 절대 비난하거나 "틀렸어요", "문제가 있습니다" 같은 말 쓰지 말 것
- 먼저 잘한 점을 찾고, 그 다음 원인 분석

[추상적 표현 절대 금지]
  ❌ "자세가 불안정해요" → ✅ "팔꿈치가 120도로 펴지면서 어깨로 힘이 분산되고 있어요"
  ❌ "기초부터 다져야 해요" → ✅ "손목 회내가 안 되어 있어서 전완근이 제대로 쓰이지 않고 있어요"
  ❌ "힘 전달이 안 돼요" → ✅ "엄지가 위를 향하고 있어서 사이드 방향 힘이 위쪽으로 새고 있어요"
  ❌ "각도를 교정하세요" → ✅ "지금보다 팔꿈치를 30도 더 굽혀서 90도에 맞춰보세요"

[스타일 분류 기준]
- armwrestling: 팔씨름 실전형
- powerlifting: 파워리프팅 3대 운동 기준
- cheat: 고중량 의도적 치팅
- strength: 전신 파워 중심

[reason 작성 규칙]
reason은 반드시 두 줄 구조:
  첫 번째 줄: 측정값 기반으로 잘한 점 설명 (실전 관점 포함)
  두 번째 줄: 측정값 기반 실패 원인 분석 ("~이기 때문에 ~해요" 형식)

[action 작성 규칙]
action은 원인을 해결하는 구체적 행동:
  - 신체 부위 + 방향 + 수치(가능하면) + 타이밍 포함
  - 예: "팔꿈치를 지금보다 굽혀서 90도에 맞추고, 그 상태에서 옆으로 밀어보세요"
  - 예: "엄지를 바닥 방향으로 돌려서 회내 상태를 먼저 만들고, 그 채로 동작을 시작해보세요"

[cue 작성 규칙]
cue는 반드시 "GOOD 파트 / 개선 파트" 형식:
  예: "어깨 방향 GOOD / 팔꿈치 90도 고정 필요"
  예: "힙 힌지 GOOD / 락아웃 완성 필요"

[출력 형식 - JSON만 출력, 다른 텍스트 없음]
{
  "summary": "전체 수행에 대한 한 줄 평가 (칭찬 또는 긍정적 시작, 점수 언급 금지)",
  "reason": "측정값 기반 잘한 점 한 줄.\\n측정값 기반 실패 원인 분석 한 줄.",
  "action": "원인을 해결하는 구체적 행동 (신체 부위 + 방향 + 수치 포함)",
  "cue": "GOOD 파트 / 개선 파트 형식",
  "style": "armwrestling / powerlifting / cheat / strength 중 하나"
}"""


# ── 운동별 맥락 + 측정값 해석 가이드 ────────────────────────────────────

EXERCISE_CONTEXT = {
    "side_pressure": """
[사이드프레셔 운동 특성 - 팔씨름 보조]
- 팔꿈치를 약 80~100도로 굽힌 상태에서 손목을 회내(엄지 아래)하며 수평 가압
- 어깨 외전 75~95도: 팔이 수평에 가까울수록 힘 전달 효율 높음
- 핵심: 손목 회내 (엄지가 아래를 향해야 전완 회내근 활성화)

[측정값별 실패 원인 분석 가이드]
팔꿈치 각도:
  - 100~120도 → 원인: 팔꿈치가 펴지면 삼각근으로 힘이 분산됨 → "팔꿈치를 굽혀 90도에 맞춰보세요"
  - 120도 이상 → 원인: 팔꿈치가 많이 펴져서 어깨 관절 부담 + 힘 방향 손실 → "팔꿈치를 많이 굽혀보세요"
  - 60도 이하 → 원인: 너무 굽혀지면 전완 회내 가동범위가 줄어듦 → "팔꿈치를 살짝 펴서 90도로 맞춰보세요"

어깨 외전:
  - 60도 이하 → 원인: 팔이 몸에 붙으면 수평 가압 방향이 안 나옴 → "팔꿈치를 옆으로 더 벌려보세요"
  - 110도 이상 → 원인: 팔이 너무 위로 올라가면 어깨 충돌 위험 → "팔꿈치를 어깨 높이로 낮춰보세요"

손목 회내:
  - 회내 부족 → 원인: 전완 회내근이 비활성화되어 사이드 힘 발휘 불가 → "엄지를 바닥 쪽으로 돌려보세요"
  - 회외 상태 → 원인: 힘이 위쪽으로 새서 사이드프레셔 방향으로 전달 안 됨 → "엄지를 완전히 아래로 돌려보세요"

상체 기울기:
  - 20도 이상 → 원인: 중량을 버티지 못해 몸이 기울어짐 → "코어에 힘을 주거나 무게를 줄여보세요"
""",
    "wrist_curl": """
[리스트컬 운동 특성 - 팔씨름 보조]
- 전완을 무릎이나 벤치에 고정하고 손목만 위아래로 움직이는 운동
- 핑거롤 방식: 손가락 끝까지 내렸다가 손목을 최대한 올리는 Full ROM
- 팔씨름 관점: 팔이 일부 움직여도 중량 컨트롤 안정적이면 의도된 치팅으로 인정

[측정값별 실패 원인 분석 가이드]
손목 ROM 부족 → 원인: 가동범위가 짧으면 전완근 자극이 줄어듦 → "손가락 끝까지 펴서 내려보세요"
팔꿈치 불안정 → 원인: 팔꿈치가 들리면 전완 대신 상완이 동원됨 → "팔꿈치를 무릎에 꽉 눌러보세요"
""",
    "squat": """
[스쿼트 운동 특성 - 파워리프팅]
- 파워리프팅 기준: 허벅지 평행(무릎 90도 이하), 등 중립 유지

[측정값별 실패 원인 분석 가이드]
깊이 부족 → 원인: 허벅지가 평행 이하로 내려가지 않으면 하체 근육 활성화 부족
무릎 방향 → 원인: 무릎이 안쪽으로 모이면 무릎 관절 측면 부담 증가
상체 기울기 과다 → 원인: 상체가 앞으로 쏠리면 등 부담 + 힘 전달 손실
""",
    "bench_press": """
[벤치프레스 운동 특성 - 파워리프팅]
- 팔꿈치 85~95도, 몸통과 45도 각도 유지

[측정값별 실패 원인 분석 가이드]
팔꿈치 벌어짐 → 원인: 어깨 관절에 부담 집중 + 가슴 대신 어깨가 동원됨
경로 불일정 → 원인: 바벨 경로가 바뀌면 힘 전달 효율 저하
""",
    "deadlift": """
[데드리프트 운동 특성 - 파워리프팅]
- 등 45도 이내, 마지막 락아웃 필수

[측정값별 실패 원인 분석 가이드]
락아웃 미완성 → 원인: 엉덩이가 완전히 펴지지 않으면 최대 중량 발휘 불가
좌우 불균형 → 원인: 한쪽이 먼저 펴지면 척추 비틀림 부하 발생
등 과도 기울기 → 원인: 등이 너무 수평이면 허리 부담 집중
""",
}


# ── 메인 피드백 생성 함수 ────────────────────────────────────────────────

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
        "side_pressure":  "사이드프레셔",
        "pronation_curl": "프로네이션컬",
        "rising":         "라이징",
        "back_pressure":  "백프레셔",
        "wrist_curl":     "리스트컬",
        "squat":          "스쿼트",
        "bench_press":    "벤치프레스",
        "deadlift":       "데드리프트",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    # 점수 기반 어조 결정 (점수는 내부 판단용, 출력엔 포함 안 함)
    if total_score >= 85:
        tone = "매우 잘함 — 칭찬 위주, 발전 포인트 1개만"
    elif total_score >= 70:
        tone = "잘하고 있음 — 칭찬 먼저, 가장 중요한 원인 1개 분석"
    elif total_score >= 50:
        tone = "개선 필요 — 가장 중요한 실패 원인 1~2개 분석"
    else:
        tone = "많은 개선 필요 — 핵심 실패 원인 1개에 집중해서 분석"

    # 잘한 항목 / 개선 항목 분리 (점수 숫자 제거, 측정값만 전달)
    good_criteria = [c for c in criteria_scores if c['score'] >= 75]
    weak_criteria = [c for c in criteria_scores if c['score'] < 75]

    # 가장 점수 낮은 항목 순으로 정렬 (가장 중요한 실패 원인부터)
    weak_criteria_sorted = sorted(weak_criteria, key=lambda c: c['score'])

    good_text = "\n".join(
        f"  - {c['name']}: {c.get('detail', '측정값 없음')}"
        for c in good_criteria
    ) or "  없음"

    weak_text = "\n".join(
        f"  - {c['name']}: {c.get('detail', '측정값 없음')}"
        for c in weak_criteria_sorted
    ) or "  없음"

    context = EXERCISE_CONTEXT.get(exercise_type, "")

    user_message = f"""운동: {exercise_name}
코칭 어조: {tone}
{context}
[잘 된 항목 - AI 측정값]
{good_text}

[실패 원인 분석 대상 - AI 측정값 (점수 낮은 순)]
{weak_text}

위 AI 측정값을 보고 코치 피드백을 JSON으로 작성해줘.

필수 규칙:
1. summary: 점수/수치 언급 없이 전체 수행 한 줄 평가
2. reason 첫 줄: 잘 된 항목 측정값 기반으로 구체적 칭찬
3. reason 둘째 줄: 가장 점수 낮은 항목의 측정값을 보고
   "왜 이 문제가 발생했는지 원인" + "실전에서 어떤 영향을 주는지" 분석
   형식: "[측정값] 때문에 [원인], [결과]가 발생하고 있어요"
4. action: 원인을 해결하는 구체적 행동 (수치 포함)
5. 점수 숫자 절대 언급 금지
6. 추상적 표현 절대 금지"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=500,
                temperature=0.3,
            ),
        )
        response = model.generate_content(user_message)
        result_text = response.text.strip()
        json.loads(result_text)
        return result_text

    except Exception as e:
        print(f"[GeminiService] Gemini API 호출 실패: {e}")
        traceback.print_exc()
        return _fallback_feedback(exercise_type, total_score, criteria_scores)


# ── Fallback 피드백 ──────────────────────────────────────────────────────

def _fallback_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
) -> str:
    exercise_names = {
        "side_pressure":  "사이드프레셔",
        "pronation_curl": "프로네이션컬",
        "rising":         "라이징",
        "back_pressure":  "백프레셔",
        "wrist_curl":     "리스트컬",
        "squat":          "스쿼트",
        "bench_press":    "벤치프레스",
        "deadlift":       "데드리프트",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    # 측정값 detail 활용
    sorted_criteria = sorted(criteria_scores, key=lambda c: c['score']) if criteria_scores else []
    weak = sorted_criteria[0] if sorted_criteria else None
    strong = sorted_criteria[-1] if sorted_criteria else None
    weak_detail = weak.get('detail', '') if weak else ''
    weak_name = weak['name'] if weak else ''
    strong_detail = strong.get('detail', '') if strong else ''

    fallback_map = {
        "side_pressure": {
            "high": {
                "summary": f"{exercise_name} 전체적으로 잘 수행하고 있어요!",
                "reason": f"{strong_detail or '어깨 외전 각도가 수평에 가까워서 팔씨름 힘 전달 방향과 잘 맞아요.'}\n{weak_detail or '팔꿈치가 몸통에서 살짝 멀어지면서 삼각근으로 힘이 분산되고 있어요.'}",
                "action": "팔꿈치를 옆구리에 붙인다는 느낌으로 당기고, 엄지가 아래를 향한 상태에서 밀어보세요.",
                "cue": "어깨 방향 GOOD / 팔꿈치 몸통 고정 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 팔 방향은 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '어깨 외전 방향은 수평 가압에 적합하게 잡혀 있어요.'}\n{weak_detail or '손목 회내가 부족해서 전완 회내근이 제대로 쓰이지 않고 힘이 위쪽으로 빠지고 있어요.'}",
                "action": "덤벨을 잡기 전에 엄지를 바닥 방향으로 먼저 돌리고, 그 회내 상태를 유지하면서 천천히 밀어보세요.",
                "cue": "어깨 방향 GOOD / 손목 회내 강화 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 방향을 잡아가고 있어요!",
                "reason": f"사이드프레셔는 팔꿈치 90도 + 손목 회내가 핵심이에요.\n{weak_detail or '팔꿈치가 펴지거나 손목이 회내되지 않으면 힘이 어깨와 위쪽으로 분산되어 사이드 방향으로 전달이 안 돼요.'}",
                "action": "가벼운 무게로 팔꿈치를 90도로 굽히고, 엄지를 완전히 아래로 돌린 상태에서 옆으로 미는 패턴을 먼저 익혀보세요.",
                "cue": "동작 방향 GOOD / 팔꿈치 90도 + 손목 회내 확립 필요",
                "style": "armwrestling",
            },
        },
        "wrist_curl": {
            "high": {
                "summary": f"{exercise_name} 중량 컨트롤이 안정적으로 잘 이루어지고 있어요!",
                "reason": f"{strong_detail or '고중량을 끝까지 버티는 컨트롤 능력이 좋아요.'}\n{weak_detail or '팔꿈치가 무릎에서 들리면서 전완 대신 상완이 동원되고 있어요.'}",
                "action": "손목을 최대로 꺾어 올릴 때 1초 버텨보세요. 팔꿈치는 무릎 위에 꽉 눌러 고정해보세요.",
                "cue": "중량 컨트롤 GOOD / 팔꿈치 고정 강화 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 꾸준한 리듬으로 잘 하고 있어요!",
                "reason": f"{strong_detail or '핑거롤 방식으로 손가락 끝까지 힘을 전달하려는 시도가 좋아요.'}\n{weak_detail or '손목 가동범위가 짧아서 전완근의 수축 범위가 줄어들고 있어요.'}",
                "action": "손가락을 끝까지 펴서 바를 손끝으로 받치는 느낌으로 내리고, 손목을 끝까지 꺾어 올려보세요.",
                "cue": "전완 자극 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"손목 가동범위를 늘리면 전완근 수축이 훨씬 강해져요.\n{weak_detail or '현재 손목 움직임이 짧아서 전완근 전체가 동원되지 않고 있어요.'}",
                "action": "가벼운 무게로 손가락 끝까지 내렸다가 손목을 끝까지 올리는 Full ROM을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
        },
        "squat": {
            "high": {
                "summary": f"{exercise_name} 힙 힌지 동작이 안정적이에요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '무릎이 발끝보다 앞으로 나가면 무릎 관절 전면에 부담이 집중돼요.'}",
                "action": "내려갈 때 발뒤꿈치에 체중을 실으면서 엉덩이를 뒤로 빼는 느낌으로 앉아보세요.",
                "cue": "힙 힌지 GOOD / 무릎 방향 유지 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 기본 동작이 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '하체 힘이 잘 전달되고 있어요.'}\n{weak_detail or '깊이가 부족해서 하체 근육이 최대로 동원되지 않고 있어요.'}",
                "action": "발뒤꿈치에 체중을 실으면서 허벅지가 지면과 평행이 될 때까지 내려가보세요.",
                "cue": "기본 자세 GOOD / 스쿼트 깊이 개선 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"등 각도와 무릎 방향을 먼저 잡는 게 핵심이에요.\n{weak_detail or '무릎이 안쪽으로 모이면 무릎 내측 인대에 부담이 집중돼요.'}",
                "action": "맨몸으로 천천히 내려가면서 무릎이 발끝 방향을 향하는지 먼저 확인해보세요.",
                "cue": "동작 시작 GOOD / 무릎 방향 확립 필요",
                "style": "powerlifting",
            },
        },
        "bench_press": {
            "high": {
                "summary": f"{exercise_name} 밀기 힘 전달이 좋아요!",
                "reason": f"{strong_detail or '락아웃까지 힘이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치가 벌어지면 어깨 관절에 부담이 집중되고 가슴 근육 동원이 줄어들어요.'}",
                "action": "바벨을 내릴 때 팔꿈치를 몸통에서 약 45도 유지하면서 'ㄴ'자 모양으로 내려보세요.",
                "cue": "밀기 파워 GOOD / 팔꿈치 각도 유지 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 전반적으로 잘 하고 있어요!",
                "reason": f"{strong_detail or '가슴 근육에 자극이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치 경로가 일정하지 않아서 힘 전달 효율이 떨어지고 있어요.'}",
                "action": "올릴 때 가슴 중앙을 향해 밀어 올린다고 생각하면 경로가 자연스럽게 잡혀요.",
                "cue": "가슴 자극 GOOD / 팔꿈치 경로 안정화 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가고 있어요!",
                "reason": f"팔꿈치 각도를 먼저 잡는 게 중요해요.\n{weak_detail or '팔꿈치가 너무 벌어지면 어깨 관절 부담이 집중되고 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 팔꿈치를 45도로 유지하면서 천천히 내렸다가 올려보세요.",
                "cue": "동작 시작 GOOD / 팔꿈치 각도 확립 필요",
                "style": "powerlifting",
            },
        },
        "deadlift": {
            "high": {
                "summary": f"{exercise_name} 자세 정말 잘 잡고 계세요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '락아웃에서 좌우 힘 차이가 생기면 척추에 비틀림 부하가 발생해요.'}",
                "action": "바벨을 끝까지 올릴 때 양쪽 엉덩이를 똑같이 앞으로 밀어내며 척추를 곧게 펴보세요.",
                "cue": "힘 전달 GOOD / 락아웃 좌우 밸런스 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 힙 힌지가 잘 나오고 있어요!",
                "reason": f"{strong_detail or '등 각도를 안정적으로 유지하고 있어요.'}\n{weak_detail or '락아웃이 완성되지 않으면 엉덩이 신전근이 최대 수축되지 않아 힘이 줄어들어요.'}",
                "action": "바벨을 올릴 때 엉덩이로 앞에 있는 벽을 민다고 생각하면 자연스럽게 펴져요.",
                "cue": "힙 힌지 GOOD / 락아웃 완성 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"등 중립 자세가 가장 중요해요.\n{weak_detail or '등이 말리면 척추 후방 인대에 부담이 집중되어 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 등을 곧게 편 상태에서 엉덩이만 뒤로 빼는 힙 힌지 패턴을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / 등 중립 자세 확립 필요",
                "style": "powerlifting",
            },
        },
    }

    if total_score >= 70:
        tier = "high"
    elif total_score >= 50:
        tier = "mid"
    else:
        tier = "low"

    ex_map = fallback_map.get(exercise_type, {})
    fb = ex_map.get(tier, {
        "summary": f"{exercise_name} 수행하셨어요. 꾸준히 하면 좋아질 거예요!",
        "reason": f"{strong_detail or '동작 방향은 잡혀 있어요.'}\n{weak_detail or '핵심 자세를 조금 더 다듬으면 효과가 훨씬 좋아질 거예요.'}",
        "action": "가벼운 무게로 천천히 Full ROM을 먼저 익혀보세요.",
        "cue": "꾸준한 연습 GOOD / 자세 다듬기 필요",
        "style": "armwrestling",
    })

    return json.dumps(fb, ensure_ascii=False)
