import os
import json
import traceback
import google.generativeai as genai

SYSTEM_PROMPT = """너는 팔씨름/파워리프팅 전문 스트렝스 코치다.
사용자의 운동 영상을 AI가 분석한 측정값을 보고
실전 선수를 지도하는 코치처럼 한국어 피드백을 JSON으로만 출력해라.

[앱 정체성]
1. 팔씨름 보조 웨이트 (사이드프레셔, 프로네이션컬, 라이징, 백프레셔, 리스트컬)
2. 파워리프팅 (스쿼트, 벤치프레스, 데드리프트)

[코칭 스타일 - 가장 중요]
아래 예시처럼 실전 선수를 지도하는 느낌으로 써라:

좋은 예시 (사이드프레셔):
  summary: "어깨-팔꿈치-손으로 이어지는 프레임을 단단하게 유지하고 있어요. 몇 가지 디테일만 다듬으면 훨씬 강력한 힘이 나올 거예요."
  reason: "팔 힘만 쓰는 게 아니라 체중을 실어 누르는 감각이 좋아요. 실전에서 아주 강력한 압박이 될 수 있어요.\n다만 손목이 회내되지 않아서 엄지가 위를 향하고 있어요. 이 상태에서는 전완 회내근이 비활성화되어 사이드 방향으로 힘이 제대로 전달되지 않아요."
  action: "엄지를 바닥 방향으로 완전히 돌려서 회내 상태를 먼저 만들고, 그 상태에서 팔꿈치를 옆구리에 바짝 붙이며 밀어보세요. 팔꿈치와 몸이 하나의 덩어리가 되는 느낌으로요."
  cue: "프레임 고정 GOOD / 손목 회내 + 팔꿈치 몸통 밀착 필요"

좋은 예시 (프로네이션컬):
  summary: "컬 궤적이 안정적이고 중량 컨트롤도 좋아요. 회내 전환 타이밍만 잡으면 팔씨름 훅 기술에서 훨씬 강한 힘이 나올 거예요."
  reason: "손목이 일정한 호를 그리며 올라오는 컬 궤적이 좋아요. 중량을 끝까지 버티는 능력이 실전 팔씨름 훅 상황에서 유리해요.\n다만 동작 중 엄지가 위를 향한 채로 컬이 끝나고 있어요. 이 상태에서는 전완 회내근이 활성화되지 않아서 팔씨름 훅/탑롤 전환에 필요한 회내 힘이 발휘되지 않아요."
  action: "컬을 시작하는 순간부터 엄지를 아래로 돌리기 시작해서, 손목이 가장 높이 올라왔을 때 엄지가 완전히 바닥을 향하도록 해보세요. 회내가 컬과 동시에 일어나는 게 핵심이에요."
  cue: "컬 궤적 GOOD / 회내 전환 타이밍 강화 필요"

나쁜 예시 (절대 이렇게 쓰지 말 것):
  summary: "동작을 위한 준비 자세를 점검해 볼까요?" ← 너무 형식적
  reason: "측정값이 없어 정확한 실패 원인 분석이 어렵습니다." ← 측정값 없어도 있는 데이터로 분석
  reason: "상체 기울기 측정 필요 / 손목 회내 집중 필요" ← cue를 reason에 쓰는 것 금지

[핵심 원칙]
1. 수행 전체를 파악해서 피드백 → 단순 항목 나열 금지
2. 잘한 점을 실전 관점으로 구체적으로 칭찬
3. 개선점은 "왜 문제인지 → 실전에서 어떤 영향 → 어떻게 고치나" 흐름으로
4. 점수/수치 언급 금지
5. "자세가 불안정해요", "기초부터" 같은 추상적 표현 금지
6. 측정값이 없는 항목도 있는 데이터 기반으로 최선의 분석 제공

[팔씨름 운동 실전 연결 필수]
팔씨름 운동 피드백에는 반드시 실전 연결을 포함해라:
  사이드프레셔: "실전에서 상대를 옆으로 밀어내는 압박력과 직결돼요"
  프로네이션컬: "실전 팔씨름 훅/탑롤 전환 시 필요한 회내 힘과 직결돼요"
  리스트컬: "실전에서 상대 손목을 꺾어 내리는 굴곡력으로 이어져요"

[reason 작성 규칙]
두 줄 구조:
  첫째 줄: 잘한 점을 실전 관점으로 구체적으로 (측정값 기반)
  둘째 줄: 개선 원인 분석 — "~이기 때문에 ~해요" (측정값 기반, 실전 영향 포함)

[action 작성 규칙]
원인을 해결하는 구체적 행동:
  - 신체 부위 + 방향 + 감각적 표현 포함
  - 프로네이션컬 예시: "컬을 시작하는 순간부터 엄지를 아래로 돌리기 시작해서, 최고점에서 엄지가 완전히 바닥을 향하도록 해보세요"

[cue 작성 규칙]
"GOOD 파트 / 개선 파트" 형식:
  예: "컬 궤적 GOOD / 회내 전환 타이밍 강화 필요"
  예: "중량 컨트롤 GOOD / 엄지 회내 완성 필요"

[출력 형식 - JSON만 출력]
{
  "summary": "전체 수행을 한 줄로 — 잘한 점 언급 후 발전 가능성 제시 (점수 언급 금지)",
  "reason": "잘한 점을 실전 관점으로 구체적으로.\\n개선 원인 — 왜 문제인지 + 실전 영향.",
  "action": "원인 해결 행동 — 신체 부위 + 방향 + 감각적 표현 포함",
  "cue": "GOOD 파트 / 개선 파트",
  "style": "armwrestling / powerlifting / cheat / strength 중 하나"
}"""


# ── 운동별 맥락 ───────────────────────────────────────────────────────────

EXERCISE_CONTEXT = {
    "side_pressure": """
[사이드프레셔 - 팔씨름 보조]
핵심 동작: 팔꿈치 80~100도 + 손목 회내(엄지 아래) + 수평 가압
실전 연결: 팔씨름 사이드프레셔 기술 — 상대를 옆으로 밀어내는 힘

[측정값별 원인 분석]
팔꿈치 펴짐(100도↑): 삼각근으로 힘이 분산 → 사이드 방향 힘 손실
팔꿈치 너무 굽힘(60도↓): 전완 회내 가동범위 감소
어깨 너무 낮음(60도↓): 수평 가압 방향이 안 나옴 → 힘이 아래로 빠짐
어깨 너무 높음(110도↑): 어깨 충돌 위험
손목 회내 부족: 전완 회내근 비활성화 → 사이드 힘 발휘 불가
손목 회외: 힘이 위쪽으로 새서 사이드 방향 전달 안 됨
상체 기울기 과다(20도↑): 체중을 버티지 못하는 신호 → 코어 또는 무게 조절 필요

[잘된 항목 칭찬 포인트]
어깨 외전 적절: "어깨-팔꿈치-손으로 이어지는 프레임이 좋아요"
팔꿈치 각도 적절: "팔꿈치 각도가 딱 맞아서 힘 전달 효율이 높아요"
손목 회내 충분: "엄지가 아래를 향하고 있어서 팔씨름 회내 힘이 잘 나오고 있어요"
상체 안정: "체중을 실어 누르는 감각이 좋아요 — 실전에서 강한 압박이 나와요"
""",

    "pronation_curl": """
[프로네이션컬 - 팔씨름 보조]
핵심 동작: 케이블/덤벨/원판을 잡고 컬 동작 + 동시에 손목 회내(회외→회내 전환)
실전 연결: 팔씨름 훅/탑롤 전환 시 필요한 전완 회내근 강화
촬영 각도: 측면 기준

[평가 철학]
- 팔꿈치를 몸에 붙여 고립하는 운동이 아님
- 손으로 중량을 뽑는 궤적(컬 호)과 동시에 일어나는 회내가 핵심
- 엄지에 하중을 걸면서 회내가 진행되는지가 가장 중요

[측정값별 원인 분석]
손목 회내 변화량 부족: 컬 동작 중 엄지가 위→아래로 전환이 안 됨
  → 전완 회내근이 동원되지 않아 훅 전환 힘이 약해짐
  → 해결: "컬 시작 순간부터 엄지를 돌리기 시작해서 최고점에서 완전 회내"
중량 컨트롤 불안정: 손목 궤적이 흔들림 → 과중량 신호
  → 회내 동작을 제대로 수행할 여유가 없음
  → 해결: "중량을 줄이고 회내 패턴을 먼저 익혀보세요"
컬 궤적 짧음: 손목 Y 이동 범위가 작음 → Full ROM 미달
  → 전완 굴곡근 전체가 동원 안 됨
  → 해결: "손목을 더 높이 끌어올려 Full ROM으로"
손목 불안정 (꺾임): 회내 시 손목이 뒤로 꺾임
  → 엄지에 하중이 제대로 안 걸리고 손목 부상 위험
  → 해결: "손목을 중립으로 세우고 엄지 방향으로 힘을 실어보세요"

[잘된 항목 칭찬 포인트]
회내 변화량 충분: "컬 동작 중 엄지가 완전히 아래로 돌아가고 있어요 — 팔씨름 훅 전환 패턴과 일치해요"
중량 컨트롤 안정: "손목 궤적이 일정해서 고중량도 안정적으로 다루고 있어요"
컬 궤적 완성: "손목을 끝까지 끌어올리는 Full ROM이 전완 전체를 자극하고 있어요"
손목 안정성: "손목이 중립을 유지해서 엄지에 하중이 안정적으로 걸리고 있어요"
""",

    "wrist_curl": """
[리스트컬 - 팔씨름 보조]
핵심 동작: 전완 고정 + 손목 Full ROM + 핑거롤
실전 연결: 팔씨름 손목 굴곡력 — 상대 손목을 꺾어 내리는 힘

[측정값별 원인 분석]
손목 ROM 부족: 전완 굴곡근 전체가 동원 안 됨 → 자극 감소
팔꿈치 불안정: 상완이 개입되어 전완 고립 훼손
좌우 비대칭: 약한 쪽이 실전에서 먼저 무너질 수 있음

[잘된 항목 칭찬 포인트]
안정적 컨트롤: "고중량을 끝까지 버티는 컨트롤이 실전에서 유리해요"
Full ROM: "손가락 끝까지 내리는 핑거롤 방식이 전완 자극을 극대화해요"
""",

    "squat": """
[스쿼트 - 파워리프팅]
핵심: 허벅지 평행 이하, 등 중립, 무릎 발끝 방향

[측정값별 원인 분석]
깊이 부족: 하체 근육 최대 동원 불가 → 최대 중량 발휘 한계
무릎 내측 붕괴: 무릎 인대 부담 집중
상체 과도 기울기: 등 부담 + 힘 전달 손실
힙 힌지 부족: 무릎 주도로 하중이 쏠림
""",

    "bench_press": """
[벤치프레스 - 파워리프팅]
핵심: 팔꿈치 85~95도, 몸통 45도 각도, 경로 일정

[측정값별 원인 분석]
팔꿈치 과도 벌어짐: 어깨 관절 부담 + 가슴 근육 동원 감소
경로 불일정: 힘 전달 효율 저하, 어깨 부상 위험
""",

    "deadlift": """
[데드리프트 - 파워리프팅]
핵심: 등 45도 이내, 힙 힌지 주도, 락아웃 완성

[측정값별 원인 분석]
락아웃 미완성: 엉덩이 신전근 최대 수축 불가 → 힘 손실
좌우 불균형: 척추 비틀림 부하 발생 → 부상 위험
등 과도 기울기: 허리 집중 부하
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

    if total_score >= 85:
        tone = "전반적으로 매우 잘 하고 있음. 칭찬 위주로, 디테일 1개만 언급."
    elif total_score >= 70:
        tone = "잘 하고 있음. 잘한 점 충분히 칭찬 후 가장 중요한 개선 원인 1개 분석."
    elif total_score >= 50:
        tone = "기본은 있음. 잘한 점 찾아 칭찬 후 핵심 실패 원인 1~2개 분석."
    else:
        tone = "많이 개선 필요. 그래도 잘한 점 1개 찾아 칭찬 후 가장 중요한 실패 원인 집중 분석."

    good_criteria = [c for c in criteria_scores if c['score'] >= 75]
    weak_criteria = sorted(
        [c for c in criteria_scores if c['score'] < 75],
        key=lambda c: c['score']
    )

    good_text = "\n".join(
        f"  ✅ {c['name']}: {c.get('detail', '')}"
        for c in good_criteria
    ) or "  없음"

    weak_text = "\n".join(
        f"  ⚠️ {c['name']}: {c.get('detail', '')}"
        for c in weak_criteria
    ) or "  없음"

    context = EXERCISE_CONTEXT.get(exercise_type, "")

    user_message = f"""운동: {exercise_name}
코칭 어조: {tone}
{context}
[잘 된 항목 — AI 측정값]
{good_text}

[개선 필요 항목 — AI 측정값 (낮은 순)]
{weak_text}

위 측정값을 보고 실전 코치처럼 피드백을 JSON으로 작성해줘.

작성 가이드:
- summary: 수행 전체를 한 줄로 파악해서 — 잘한 점 + 발전 가능성 (점수 언급 금지)
- reason 첫 줄: 잘된 항목 중 가장 인상적인 것을 실전 관점으로 구체적으로 칭찬
- reason 둘째 줄: 가장 점수 낮은 항목의 측정값 기반으로 "왜 문제인지 → 실전에서 어떤 영향" 분석
- action: 원인을 해결하는 감각적이고 구체적인 행동 (신체 부위 + 방향 + 실전 느낌 포함)
- 점수/수치 언급 금지
- 추상적 표현 금지 ("기초부터", "불안정해요" 등)
- 팔씨름 운동이면 반드시 실전 연결 포함"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=500,
                temperature=0.4,
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

    sorted_criteria = sorted(criteria_scores, key=lambda c: c['score']) if criteria_scores else []
    weak = sorted_criteria[0] if sorted_criteria else None
    strong = sorted_criteria[-1] if sorted_criteria else None
    weak_detail = weak.get('detail', '') if weak else ''
    strong_detail = strong.get('detail', '') if strong else ''

    fallback_map = {
        "side_pressure": {
            "high": {
                "summary": f"{exercise_name} 프레임을 단단하게 유지하면서 체중까지 실어 누르는 감각이 좋아요. 몇 가지 디테일만 다듬으면 훨씬 강한 힘이 나올 거예요.",
                "reason": f"{strong_detail or '어깨-팔꿈치-손으로 이어지는 프레임이 안정적이에요. 실전에서 강한 사이드 압박이 나올 수 있어요.'}\n{weak_detail or '팔꿈치가 몸통에서 살짝 멀어지면서 삼각근으로 힘이 분산되고 있어요. 고중량에서 팔꿈치가 먼저 열릴 수 있어요.'}",
                "action": "팔꿈치를 옆구리에 바짝 붙인다는 느낌으로 당기고, 팔꿈치와 몸이 하나의 덩어리가 되어 회전하는 느낌으로 밀어보세요.",
                "cue": "프레임 고정 GOOD / 팔꿈치 몸통 밀착 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 팔 방향과 체중 전달은 잘 잡혀 있어요. 손목 회내를 더 강하게 가져가면 실전 힘이 크게 올라갈 거예요.",
                "reason": f"{strong_detail or '어깨 외전 방향이 수평 가압에 적합하게 잡혀 있어요.'}\n{weak_detail or '손목 회내가 부족해서 전완 회내근이 제대로 활성화되지 않고 있어요. 이 상태에서는 사이드 방향 힘이 위쪽으로 새고 있어요.'}",
                "action": "엄지를 바닥 방향으로 완전히 돌려서 회내 상태를 먼저 만들고, 그 상태에서 팔꿈치를 약 90도로 유지하며 옆으로 밀어보세요.",
                "cue": "체중 전달 GOOD / 손목 회내 강화 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 방향 감각을 잡아가고 있어요. 팔꿈치 각도와 손목 회내를 잡으면 힘이 완전히 달라질 거예요.",
                "reason": f"사이드프레셔는 팔꿈치 90도 + 손목 회내가 핵심이에요.\n{weak_detail or '팔꿈치가 펴지거나 손목이 회내되지 않으면 힘이 어깨와 위쪽으로 분산되어 실전에서 상대를 제대로 밀어낼 수 없어요.'}",
                "action": "가벼운 무게로 팔꿈치를 90도로 굽히고, 엄지를 완전히 아래로 돌린 회내 상태에서 옆으로 미는 패턴을 먼저 익혀보세요.",
                "cue": "동작 방향 GOOD / 팔꿈치 90도 + 손목 회내 확립 필요",
                "style": "armwrestling",
            },
        },

        "pronation_curl": {
            "high": {
                "summary": f"{exercise_name} 컬 궤적이 안정적이고 회내 전환도 잘 이루어지고 있어요. 실전 팔씨름 훅 기술에 바로 연결될 수 있는 수행이에요.",
                "reason": f"{strong_detail or '컬 동작 중 엄지가 완전히 아래로 돌아가면서 전완 회내근이 잘 활성화되고 있어요. 팔씨름 훅 전환 패턴과 일치해요.'}\n{weak_detail or '중량이 올라갈수록 회내 완성 타이밍이 조금 늦어지고 있어요. 최고점에서 엄지가 완전히 아래를 향하도록 조금 더 신경 써보세요.'}",
                "action": "지금보다 컬 시작 타이밍을 조금 더 앞당겨서 최고점에서 엄지가 완전히 바닥을 향하도록 해보세요. 회내가 먼저, 컬이 따라오는 느낌으로요.",
                "cue": "회내 전환 GOOD / 최고점 회내 완성 강화 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 컬 궤적은 안정적으로 나오고 있어요. 회내 전환 타이밍을 잡으면 팔씨름 훅 힘이 크게 올라갈 거예요.",
                "reason": f"{strong_detail or '손목이 일정한 호를 그리며 올라오는 컬 궤적이 안정적이에요. 중량 컨트롤 능력이 좋아요.'}\n{weak_detail or '컬 동작 중 엄지가 위를 향한 채로 끝나고 있어요. 전완 회내근이 활성화되지 않아서 팔씨름 훅 전환에 필요한 회내 힘이 발휘되지 않고 있어요.'}",
                "action": "컬을 시작하는 순간부터 엄지를 아래로 돌리기 시작해서, 손목이 가장 높이 올라왔을 때 엄지가 완전히 바닥을 향하도록 해보세요. 회내가 컬과 동시에 일어나는 게 핵심이에요.",
                "cue": "컬 궤적 GOOD / 회내 전환 타이밍 강화 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 컬 동작의 방향을 잡아가고 있어요. 회내 패턴을 익히면 팔씨름 실전 훅 힘이 완전히 달라질 거예요.",
                "reason": f"프로네이션컬은 컬 + 동시 회내가 핵심이에요.\n{weak_detail or '지금은 컬만 하고 회내가 일어나지 않고 있어요. 이 상태에서는 전완 회내근을 훈련하지 못하고, 팔씨름 훅 전환에 필요한 힘이 키워지지 않아요.'}",
                "action": "먼저 가벼운 무게로 컬 없이 손목 회내만 연습해보세요 — 엄지를 위에서 아래로 돌리는 동작이에요. 이 감각이 잡히면 컬과 동시에 시도해보세요.",
                "cue": "컬 방향 GOOD / 컬 + 회내 동시 수행 확립 필요",
                "style": "armwrestling",
            },
        },

        "wrist_curl": {
            "high": {
                "summary": f"{exercise_name} 고중량을 안정적으로 컨트롤하는 능력이 인상적이에요. 실전 팔씨름 손목 굴곡력으로 이어질 거예요.",
                "reason": f"{strong_detail or '고중량을 끝까지 버티는 컨트롤 능력이 실전에서 상대 손목을 꺾어 내리는 힘으로 직결돼요.'}\n{weak_detail or '팔꿈치가 무릎에서 살짝 들리면서 전완 대신 상완이 개입되고 있어요. 전완 고립이 줄어들면 실전 손목 굴곡력이 약해져요.'}",
                "action": "손목을 최대로 꺾어 올린 상태에서 1초 버텨보세요. 이때 팔꿈치를 무릎에 꽉 눌러서 상완이 개입되지 않도록 고정해보세요.",
                "cue": "고중량 컨트롤 GOOD / 팔꿈치 고정 강화 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 핑거롤 방식으로 꾸준하게 수행하고 있어요. 가동범위를 조금 더 늘리면 전완 자극이 크게 올라갈 거예요.",
                "reason": f"{strong_detail or '핑거롤 방식으로 손가락 끝까지 힘을 전달하려는 시도가 좋아요.'}\n{weak_detail or '손목 가동범위가 짧아서 전완 굴곡근의 수축 범위가 줄어들고 있어요. 실전에서 상대 손목을 끝까지 꺾어 내리는 힘이 부족해질 수 있어요.'}",
                "action": "손가락을 끝까지 펴서 바를 손끝으로 받치는 느낌으로 내리고, 손목을 끝까지 꺾어 올려보세요.",
                "cue": "핑거롤 방향 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 전완 훈련의 기본 방향을 잡아가고 있어요. 가동범위를 늘리면 효과가 완전히 달라질 거예요.",
                "reason": f"손목 가동범위가 전완 굴곡력의 핵심이에요.\n{weak_detail or '지금은 손목 움직임이 짧아서 전완 굴곡근이 일부만 동원되고 있어요. 실전에서 상대 손목을 끝까지 꺾어 내리는 힘이 부족해질 수 있어요.'}",
                "action": "가벼운 무게로 손가락을 끝까지 펴서 내렸다가, 손목을 최대한 꺾어 올리는 Full ROM을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
        },

        "squat": {
            "high": {
                "summary": f"{exercise_name} 힙 힌지 패턴이 안정적이에요. 락아웃까지 일관성 있게 유지하면 더 무거운 중량도 안전하게 다룰 수 있어요.",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '무릎이 발끝보다 앞으로 나가면 무릎 관절 전면에 부담이 집중돼요. 중량이 올라갈수록 이 부분이 먼저 한계가 와요.'}",
                "action": "내려갈 때 발뒤꿈치에 체중을 실으면서 엉덩이를 뒤로 빼는 느낌으로 앉아보세요.",
                "cue": "힙 힌지 GOOD / 무릎 방향 유지 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 기본 패턴이 잡혀 있어요. 깊이를 조금 더 확보하면 하체 근육을 완전히 동원할 수 있어요.",
                "reason": f"{strong_detail or '하체 힘이 안정적으로 전달되고 있어요.'}\n{weak_detail or '깊이가 부족해서 하체 근육이 최대로 동원되지 않고 있어요. 허벅지 평행 이하로 내려가야 최대 중량 발휘가 가능해요.'}",
                "action": "발뒤꿈치에 체중을 실으면서 허벅지가 지면과 평행이 될 때까지 내려가보세요.",
                "cue": "기본 패턴 GOOD / 스쿼트 깊이 확보 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작 방향을 잡아가고 있어요. 등 중립과 무릎 방향을 먼저 잡으면 안전하게 중량을 올릴 수 있어요.",
                "reason": f"등 중립과 무릎 방향이 스쿼트의 안전한 기반이에요.\n{weak_detail or '무릎이 안쪽으로 모이면 무릎 내측 인대에 부담이 집중되어 부상 위험이 높아져요.'}",
                "action": "맨몸으로 천천히 내려가면서 무릎이 발끝 방향을 향하는지 먼저 확인해보세요.",
                "cue": "동작 시작 GOOD / 무릎 방향 + 등 중립 확립 필요",
                "style": "powerlifting",
            },
        },

        "bench_press": {
            "high": {
                "summary": f"{exercise_name} 밀기 파워와 락아웃이 좋아요. 팔꿈치 각도만 잡으면 어깨 부담 없이 더 무거운 중량을 다룰 수 있어요.",
                "reason": f"{strong_detail or '락아웃까지 힘이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치가 벌어지면 어깨 관절에 부담이 집중되고 가슴 근육 동원이 줄어들어요. 고중량에서 어깨 부상으로 이어질 수 있어요.'}",
                "action": "바벨을 내릴 때 팔꿈치를 몸통에서 약 45도 유지하면서 'ㄴ'자 모양으로 내려보세요.",
                "cue": "밀기 파워 GOOD / 팔꿈치 각도 유지 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 가슴 근육 자극 방향은 잘 잡혀 있어요. 팔꿈치 경로를 일정하게 유지하면 힘 전달이 크게 좋아질 거예요.",
                "reason": f"{strong_detail or '가슴 근육에 자극이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치 경로가 일정하지 않아서 힘 전달 효율이 떨어지고 있어요. 어깨에 불필요한 부하가 생길 수 있어요.'}",
                "action": "올릴 때 가슴 중앙을 향해 밀어 올린다고 생각하면 경로가 자연스럽게 잡혀요.",
                "cue": "가슴 자극 GOOD / 팔꿈치 경로 안정화 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 기본 방향을 잡아가고 있어요. 팔꿈치 각도를 먼저 잡으면 안전하게 중량을 올릴 수 있어요.",
                "reason": f"팔꿈치 각도 45도가 벤치프레스의 안전한 기반이에요.\n{weak_detail or '팔꿈치가 너무 벌어지면 어깨 관절 부담이 집중되어 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 팔꿈치를 45도로 유지하면서 천천히 내렸다가 올려보세요.",
                "cue": "동작 시작 GOOD / 팔꿈치 각도 확립 필요",
                "style": "powerlifting",
            },
        },

        "deadlift": {
            "high": {
                "summary": f"{exercise_name} 힙 힌지 패턴과 힘 전달이 좋아요. 락아웃 마무리를 완성하면 최대 중량이 더 올라갈 거예요.",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '락아웃에서 좌우 힘 차이가 생기면 척추에 비틀림 부하가 발생해요. 고중량에서 허리 부상 위험이 있어요.'}",
                "action": "바벨을 끝까지 올릴 때 양쪽 엉덩이를 똑같이 앞으로 밀어내며 척추를 곧게 펴보세요.",
                "cue": "힙 힌지 GOOD / 락아웃 좌우 밸런스 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 힙 힌지 패턴이 나오고 있어요. 락아웃 마무리를 완성하면 엉덩이 신전력을 최대로 쓸 수 있어요.",
                "reason": f"{strong_detail or '등 각도를 안정적으로 유지하고 있어요.'}\n{weak_detail or '락아웃이 완성되지 않으면 엉덩이 신전근이 최대 수축되지 않아요. 이 상태에서는 최대 중량 발휘에 한계가 생겨요.'}",
                "action": "바벨을 올릴 때 엉덩이로 앞에 있는 벽을 민다고 생각하면 자연스럽게 락아웃이 완성돼요.",
                "cue": "힙 힌지 GOOD / 락아웃 완성 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작 방향을 잡아가고 있어요. 등 중립을 먼저 잡으면 안전하게 중량을 올릴 수 있어요.",
                "reason": f"등 중립이 데드리프트의 가장 중요한 안전 기반이에요.\n{weak_detail or '등이 말리면 척추 후방 인대에 부담이 집중되어 허리 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 등을 곧게 편 상태에서 엉덩이만 뒤로 빼는 힙 힌지 패턴을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / 등 중립 확립 필요",
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
        "summary": f"{exercise_name} 수행하셨어요. 측정값을 바탕으로 개선하면 훨씬 강해질 거예요.",
        "reason": f"{strong_detail or '동작 방향은 잡혀 있어요.'}\n{weak_detail or '핵심 자세를 다듬으면 힘 전달이 훨씬 좋아질 거예요.'}",
        "action": "가벼운 무게로 핵심 자세를 먼저 익혀보세요.",
        "cue": "동작 방향 GOOD / 세부 자세 다듬기 필요",
        "style": "armwrestling",
    })

    return json.dumps(fb, ensure_ascii=False)
