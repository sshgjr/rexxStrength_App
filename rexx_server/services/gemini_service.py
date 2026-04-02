import os
import json
import traceback
import google.generativeai as genai

SYSTEM_PROMPT = """너는 팔씨름/파워리프팅 전문 스트렝스 코치다.
사용자의 운동 점수 데이터와 AI가 분석한 구체적인 측정값을 보고
아래 규칙에 따라 한국어 피드백을 JSON으로만 출력해라.

[앱 정체성]
이 앱은 두 가지 목적의 사용자를 위한 스트렝스 피드백 AI다:
1. 팔씨름 보조 웨이트 (사이드프레셔, 프로네이션컬, 라이징, 백프레셔, 리스트컬)
2. 파워리프팅 (스쿼트, 벤치프레스, 데드리프트)

[코칭 철학]
- 보디빌딩 정석 자세만을 강요하지 않는다.
- 사용자의 수행을 "목적 기반"으로 평가한다.
- 평가의 핵심 질문: "이 수행이 목적에 유리한가? 리스크 대비 이득이 있는가?"
- 팔씨름 운동은 실전 팔씨름 동작 패턴과 힘 전달 효율을 기준으로 평가한다.

[평가 기준]
1. 수행 안정성 (중량 컨트롤 여부)
2. 자극 전달 (목표 근육 사용 여부)
3. 보상 움직임 (치팅 여부 및 의도성)
4. 리스크 대비 리워드

[판단 규칙]
- 완벽한 고립이 아니어도 실전 스포츠에 도움이 된다면 긍정 평가
- 팔씨름 운동: 의도된 치팅(고중량 컨트롤)은 긍정 평가 가능
- 단, 다음은 감점:
    → 통제 불가능한 반동
    → 부상 위험이 높은 꺾임
    → 중량을 버티지 못하는 경우

[점수 해석 기준]
- 85점 이상: 매우 잘함. 칭찬 위주로, 발전 포인트 1개만
- 70~84점: 잘하고 있음. 칭찬 먼저, 개선점 1개만
- 50~69점: 보통. 가장 중요한 개선점 1~2개
- 50점 미만: 기초 필요. 핵심 1개만 집중

[말투 규칙]
- 코치가 옆에서 말하듯 따뜻하게
- "~해봐요", "~해보세요", "~해주세요" 톤
- 절대 비난하거나 "문제가 있습니다" 같은 말 쓰지 말 것
- 무조건 교정부터 하지 않는다. 먼저 "잘한 점"을 찾는다.

[추상적 표현 절대 금지 - 핵심]
아래처럼 반드시 구체적으로 말해야 한다:
  ❌ "자세가 불안정해요"
  ✅ "팔꿈치가 몸통에서 멀어지면서 어깨 부담이 커지고 있어요"

  ❌ "힘 전달이 안 돼요"
  ✅ "손목이 회내되지 않아서 사이드 방향으로 힘이 분산되고 있어요"

  ❌ "기초부터 다져야 해요"
  ✅ "팔꿈치가 몸에서 떨어져 있어서 힘이 어깨 쪽으로 새고 있어요"

  ❌ "손목 근력이 부족해요"
  ✅ "손목 회내 각도가 부족해서 엄지가 위를 향하고 있어요 — 엄지를 아래로 돌려보세요"

[AI 측정값 활용 규칙 - 핵심]
- 입력 데이터의 "측정값" 정보를 반드시 피드백에 활용해라
- 측정값이 있으면 반드시 그 수치 기반으로 설명해라
  예: "팔꿈치 각도가 약 120도로 측정돼서 조금 펴진 상태예요"
  예: "손목이 회외 상태로 측정됐어요 — 엄지를 아래로 돌려보세요"
  예: "어깨가 수평보다 아래로 내려가 있어요 — 팔꿈치를 어깨 높이로 올려보세요"

[스타일 분류 기준]
- armwrestling: 팔씨름 실전형
- powerlifting: 파워리프팅 3대 운동 기준
- cheat: 고중량 의도적 치팅
- strength: 전신 파워 중심

[reason 작성 규칙 - 핵심]
reason은 반드시 두 줄 구조:
  첫 번째 줄: 잘한 점 (측정값 기반, 실전 관점 포함)
  두 번째 줄: 구체적 원인 (측정값 기반, "~때문에 ~해요" 형식)

좋은 예시 (사이드프레셔):
  "어깨 외전 각도가 수평에 가까워서 팔씨름 사이드 힘 전달 방향과 잘 맞아요.
  손목 회내가 부족해서 엄지가 위를 향하고 있어요 — 힘이 원하는 방향 대신 위쪽으로 빠지고 있어요."

좋은 예시 (리스트컬):
  "중량을 끝까지 버티는 컨트롤 능력이 좋아서 실전 팔씨름에 유리해요.
  팔꿈치가 무릎에서 살짝 들리면서 전완 대신 상완으로 힘이 새고 있어요."

[cue 작성 규칙]
cue는 반드시 "GOOD 파트 / 개선 파트" 형식:
  예: "어깨 방향 GOOD / 손목 회내 강화 필요"
  예: "중량 전달 GOOD / 락아웃 좌우 밸런스 개선 필요"

[출력 형식 - JSON만 출력, 다른 텍스트 없음]
{
  "summary": "전체 수행에 대한 한 줄 평가 (칭찬 또는 긍정적 시작)",
  "reason": "측정값 기반 잘한 점 한 줄.\\n측정값 기반 구체적 원인 한 줄.",
  "action": "신체 부위 + 방향 + 타이밍이 포함된 구체적 행동 1~2개",
  "cue": "GOOD 파트 / 개선 파트 형식",
  "style": "armwrestling / powerlifting / cheat / strength 중 하나"
}"""


# ── 운동별 맥락 + 측정값 해석 가이드 ────────────────────────────────────

EXERCISE_CONTEXT = {
    "side_pressure": """
[사이드프레셔 운동 특성 - 팔씨름 보조]
- 팔꿈치를 약 80~100도로 굽힌 상태에서 손목을 회내(엄지 아래)하며 수평 가압
- 어깨 외전 75~95도: 팔이 수평에 가까울수록 힘 전달 효율 높음
- 핵심: 손목 회내 (엄지가 아래를 향해야 팔씨름 사이드프레셔 패턴과 일치)

[측정값 → 피드백 변환 가이드]
팔꿈치 각도:
  - 80~100도: "팔꿈치 각도가 딱 좋아요"
  - 100~120도: "팔꿈치가 약간 펴져 있어요 — 팔꿈치를 몸에 좀 더 가깝게 당겨보세요"
  - 120도 이상: "팔꿈치가 많이 펴져 있어서 어깨 쪽으로 힘이 분산되고 있어요"
  - 60도 이하: "팔꿈치가 너무 굽혀져 있어요 — 살짝 펴서 90도를 만들어보세요"

어깨 외전:
  - 75~95도: "팔 방향이 수평으로 잘 잡혀 있어요"
  - 60도 이하: "팔이 몸에 너무 붙어 있어요 — 팔꿈치를 옆으로 더 벌려보세요"
  - 110도 이상: "팔이 너무 위로 올라가 있어요 — 팔꿈치를 어깨 높이로 낮춰보세요"

손목 회내:
  - 충분: "엄지가 아래를 잘 향하고 있어요 — 팔씨름 힘 전달 패턴과 일치해요"
  - 부족: "손목이 아직 안쪽으로 덜 돌아가 있어요 — 엄지를 바닥 쪽으로 돌려보세요"
  - 회외: "손목이 바깥으로 돌아가 있어서 힘이 위쪽으로 빠지고 있어요"

상체 기울기:
  - 10도 이하: "상체가 안정적으로 서 있어요"
  - 10~20도: "몸이 약간 기울어지고 있어요 — 허리에 힘을 주고 세워보세요"
  - 20도 이상: "상체가 많이 기울어지고 있어요 — 중량을 줄이거나 코어에 힘을 주세요"
""",
    "wrist_curl": """
[리스트컬 운동 특성 - 팔씨름 보조]
- 전완을 무릎이나 벤치에 고정하고 손목만 위아래로 움직이는 운동
- 핑거롤 방식: 손가락 끝까지 내렸다가 손목을 최대한 올리는 Full ROM
- 팔씨름 관점: 팔이 일부 움직여도 중량 컨트롤 안정적이면 긍정 평가
""",
    "squat": """
[스쿼트 운동 특성 - 파워리프팅]
- 파워리프팅 기준: 허벅지 평행(무릎 90도 이하), 등 중립 유지
""",
    "bench_press": """
[벤치프레스 운동 특성 - 파워리프팅]
- 팔꿈치 85~95도, 몸통과 45도 각도 유지
""",
    "deadlift": """
[데드리프트 운동 특성 - 파워리프팅]
- 등 45도 이내, 마지막 락아웃 필수
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
        score_level = "매우 잘함 (칭찬 위주로)"
    elif total_score >= 70:
        score_level = "잘하고 있음 (칭찬 먼저, 개선 1개)"
    elif total_score >= 50:
        score_level = "보통 (개선점 1~2개)"
    else:
        score_level = "기초 필요 (핵심 1개만)"

    good_criteria = [c for c in criteria_scores if c['score'] >= 75]
    weak_criteria = [c for c in criteria_scores if c['score'] < 75]

    # ── 핵심: detail 필드 포함해서 전달 ──────────────────────────────────
    # detail에는 side_pressure_rules.dart에서 계산한 구체적 측정값이 담겨 있음
    # 예: "팔꿈치 각도 117.3도 — 너무 펴져 있음, 어깨 부담 증가"
    # 예: "손목 회외 상태 — 회내 자세로 교정 필요"
    good_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ✅  측정값: {c.get('detail', '')}"
        for c in good_criteria
    ) or "  없음"

    weak_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ⚠️  측정값: {c.get('detail', '')}"
        for c in weak_criteria
    ) or "  없음"

    context = EXERCISE_CONTEXT.get(exercise_type, "")

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100 → 수준: {score_level}
{context}
[AI 측정 결과 - 잘한 항목]
{good_text}

[AI 측정 결과 - 개선 필요 항목]
{weak_text}

위 AI 측정값을 반드시 활용해서 코치 피드백을 JSON으로 작성해줘.

필수 출력 규칙:
1. reason 첫 줄: 잘한 항목의 측정값을 언급하며 구체적으로 칭찬
2. reason 둘째 줄: 개선 항목의 측정값 기반으로 "~때문에 ~해요" 형식으로 원인 설명
   예: "팔꿈치가 약 117도로 펴져 있어서 어깨 쪽으로 힘이 분산되고 있어요"
   예: "손목이 회외 상태라서 힘이 사이드 방향이 아닌 위쪽으로 빠지고 있어요"
3. action: 측정값 기반 구체적 행동 제시
   예: "팔꿈치를 지금보다 굽혀서 90도에 맞춰보세요"
4. cue: "GOOD 파트 / 개선 파트" 형식
5. "기초부터", "자세가 불안정해요" 같은 추상적 표현 절대 사용 금지"""

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
    weak = min(criteria_scores, key=lambda c: c['score']) if criteria_scores else None
    weak_detail = weak.get('detail', '') if weak else ''
    strong = max(criteria_scores, key=lambda c: c['score']) if criteria_scores else None
    strong_detail = strong.get('detail', '') if strong else ''

    fallback_map = {
        "side_pressure": {
            "high": {
                "summary": f"{exercise_name} 손목 회내와 어깨 방향이 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '어깨 외전 각도가 수평에 가까워서 팔씨름 힘 전달 방향과 잘 맞아요.'}\n{weak_detail or '팔꿈치가 몸통에서 살짝 멀어지면서 어깨 쪽으로 힘이 분산되고 있어요.'}",
                "action": "팔꿈치를 옆구리에 붙인다는 느낌으로 고정하고, 엄지가 아래를 향하도록 손목을 회내한 채 밀어보세요.",
                "cue": "어깨 방향 GOOD / 팔꿈치 몸통 고정 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 팔 방향은 맞게 잡고 있어요!",
                "reason": f"{strong_detail or '어깨 외전 방향은 수평 가압에 적합하게 잡혀 있어요.'}\n{weak_detail or '손목 회내가 부족해서 힘이 사이드 방향이 아닌 위쪽으로 빠지고 있어요.'}",
                "action": "덤벨을 잡기 전에 먼저 엄지손가락을 바닥 방향으로 돌리고, 그 상태를 유지하면서 천천히 밀어보세요.",
                "cue": "어깨 방향 GOOD / 손목 회내 강화 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 방향을 잡아가고 있어요!",
                "reason": f"사이드프레셔는 팔꿈치 90도 + 손목 회내가 핵심이에요.\n{weak_detail or '팔꿈치가 펴지거나 손목이 회내되지 않으면 힘이 원하는 방향으로 전달되지 않아요.'}",
                "action": "가벼운 무게로 팔꿈치를 90도로 굽히고, 엄지를 아래로 돌린 상태에서 옆으로 미는 연습을 먼저 해보세요.",
                "cue": "동작 방향 GOOD / 팔꿈치 90도 + 손목 회내 확립 필요",
                "style": "armwrestling",
            },
        },
        "wrist_curl": {
            "high": {
                "summary": f"{exercise_name} 중량 컨트롤이 안정적으로 잘 이루어지고 있어요!",
                "reason": f"{strong_detail or '고중량을 끝까지 버티는 컨트롤 능력이 좋아서 실전 팔씨름에 유리해요.'}\n{weak_detail or '팔꿈치가 무릎에서 살짝 들리면서 전완 대신 상완으로 힘이 새고 있어요.'}",
                "action": "손목을 최대로 꺾어 올릴 때 1초 버텨주세요. 팔꿈치는 무릎 위에 꽉 눌러 고정해보세요.",
                "cue": "고중량 유지력 GOOD / 팔꿈치 고정 강화 필요",
                "style": "armwrestling",
            },
            "mid": {
                "summary": f"{exercise_name} 꾸준한 리듬으로 잘 하고 있어요!",
                "reason": f"{strong_detail or '핑거롤 방식으로 손가락 끝까지 힘을 전달하려는 시도가 좋아요.'}\n{weak_detail or '손목 가동범위가 아직 짧아서 전완근 자극이 줄어들고 있어요.'}",
                "action": "손가락을 끝까지 펴서 바를 손끝으로 받치는 느낌으로 내리고, 손목을 끝까지 꺾어 올려보세요.",
                "cue": "전완 자극 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"손목 가동범위를 늘리면 전완 자극이 훨씬 강해져요.\n{weak_detail or '현재 손목 움직임이 짧아서 목표 근육에 자극이 충분히 전달되지 않고 있어요.'}",
                "action": "가벼운 무게로 손가락 끝까지 내렸다가 손목을 끝까지 올리는 Full ROM을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / Full ROM 확보 필요",
                "style": "armwrestling",
            },
        },
        "squat": {
            "high": {
                "summary": f"{exercise_name} 힙 힌지 동작이 안정적이에요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 중량 효율이 높아요.'}\n{weak_detail or '무릎이 발끝보다 앞으로 나가면 무릎 관절 부담이 증가해요.'}",
                "action": "내려갈 때 발뒤꿈치에 체중을 실으면서 엉덩이를 더 깊게 앉아보세요.",
                "cue": "힙 힌지 GOOD / 무릎 방향 유지 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 기본 자세가 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '하체 힘이 잘 전달되고 있어요.'}\n{weak_detail or '깊이를 조금 더 늘리면 근육 자극이 훨씬 강해져요.'}",
                "action": "발뒤꿈치에 체중을 실으면서 허벅지가 지면과 평행이 될 때까지 내려가보세요.",
                "cue": "기본 자세 GOOD / 스쿼트 깊이 개선 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"등 각도와 무릎 방향을 먼저 잡는 게 핵심이에요.\n{weak_detail or '무릎이 안쪽으로 모이면 관절 부담이 커져요.'}",
                "action": "맨몸으로 천천히 내려가면서 무릎이 발끝 방향을 향하는지 먼저 확인해보세요.",
                "cue": "동작 시작 GOOD / 무릎 방향 확립 필요",
                "style": "powerlifting",
            },
        },
        "bench_press": {
            "high": {
                "summary": f"{exercise_name} 락아웃 힘 전달이 좋아요!",
                "reason": f"{strong_detail or '푸시 파워와 상체 밀기 능력이 안정적이에요.'}\n{weak_detail or '팔꿈치가 벌어지면 어깨 부담이 커지고 힘이 분산돼요.'}",
                "action": "바벨을 내릴 때 팔꿈치를 몸통에서 약 45도 유지하면서 'ㄴ'자 모양을 만들어보세요.",
                "cue": "밀기 파워 GOOD / 팔꿈치 각도 교정 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 전반적으로 잘 하고 있어요!",
                "reason": f"{strong_detail or '가슴 근육에 자극이 잘 가고 있어요.'}\n{weak_detail or '팔꿈치 경로가 일정하지 않아 어깨에 부담이 생길 수 있어요.'}",
                "action": "올릴 때 가슴 중앙을 향해 밀어 올린다고 생각해보세요.",
                "cue": "가슴 자극 GOOD / 팔꿈치 경로 안정화 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가고 있어요!",
                "reason": f"팔꿈치 각도와 바벨 경로를 먼저 익히는 게 중요해요.\n{weak_detail or '팔꿈치가 너무 벌어지면 어깨 관절에 부담이 집중돼요.'}",
                "action": "가벼운 무게로 팔꿈치를 45도로 유지하면서 천천히 내렸다가 올려보세요.",
                "cue": "동작 시작 GOOD / 팔꿈치 각도 확립 필요",
                "style": "powerlifting",
            },
        },
        "deadlift": {
            "high": {
                "summary": f"{exercise_name} 자세 정말 잘 잡고 계세요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 중량 효율이 높아요.'}\n{weak_detail or '락아웃에서 좌우 힘 차이가 생기면 실전에서 버티기 약점이 돼요.'}",
                "action": "바벨을 끝까지 올릴 때 양쪽 엉덩이를 똑같이 앞으로 밀어내며 척추를 곧게 펴보세요.",
                "cue": "중량 전달 GOOD / 락아웃 좌우 밸런스 개선 필요",
                "style": "powerlifting",
            },
            "mid": {
                "summary": f"{exercise_name} 힙 힌지 동작이 잘 나오고 있어요!",
                "reason": f"{strong_detail or '등 각도를 안정적으로 유지하는 게 인상적이에요.'}\n{weak_detail or '마지막 락아웃 동작이 완성되지 않아 힘 전달이 줄어들고 있어요.'}",
                "action": "바벨을 올릴 때 엉덩이로 벽을 민다고 생각하면 척추가 자연스럽게 펴져요.",
                "cue": "힙 힌지 GOOD / 락아웃 완성도 개선 필요",
                "style": "powerlifting",
            },
            "low": {
                "summary": f"{exercise_name} 동작을 익혀가는 중이에요!",
                "reason": f"등 중립 자세를 먼저 익히는 게 핵심이에요.\n{weak_detail or '등이 말리는 구간이 있으면 허리 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 등을 곧게 편 상태에서 엉덩이만 뒤로 빼는 연습을 먼저 해보세요.",
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
