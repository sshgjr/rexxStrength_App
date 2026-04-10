import os
import json
import traceback
import google.generativeai as genai


# ── 레벨별 시스템 프롬프트 빌더 ──────────────────────────────────────────

def _build_system_prompt(user_level: str, has_layer1: bool, exercise_type: str) -> str:

    # 레벨별 피드백 강도
    level_instructions = {
        "beginner": (
            "레이어 1 (부상 위험): 반드시 경고. 왜 위험한지 + 어떻게 고치는지 구체적으로 설명해라.\n"
            "레이어 2 (스타일 개선): 원인과 구체적인 수정 방법을 안내해라.\n"
            "추천 루틴은 반드시 포함해라."
        ),
        "intermediate": (
            "레이어 1 (부상 위험): 반드시 경고. 부상 위험을 명확히 전달해라.\n"
            "레이어 2 (스타일 개선): '~해보시는 것도 좋습니다' 식의 부드러운 참고 안내만 해라.\n"
            "추천 루틴은 포함해라."
        ),
        "advanced": (
            "레이어 1 (부상 위험): 반드시 경고. 부상 위험을 명확히 전달해라.\n"
            "레이어 2 (스타일 개선): 언급하지 마라. 이미 알고 있는 내용이므로 생략.\n"
            "추천 루틴은 심화 훈련 위주로 포함해라."
        ),
    }

    # 팔씨름 운동 여부
    is_armwrestling = exercise_type in [
        "side_pressure", "pronation_curl", "wrist_curl", "rising", "back_pressure"
    ]

    armwrestling_note = """
[팔씨름 훈련 특성 - 필수 숙지]
1. 부분 가동범위 훈련이 핵심 — 실전은 전체 범위를 쓰지 않음
2. 버티기 훈련 — 최대 수축 지점에서 3~5초 버티기 = 인대/건 강화
3. 고중량 자체가 나쁜 게 아님 — 올바른 패턴이 먼저
action에는 버티기 또는 부분반복을 반드시 포함해라.
""" if is_armwrestling else ""

    return f"""너는 팔씨름/파워리프팅 전문 스트렝스 코치다.
사용자의 운동 영상을 AI가 분석한 측정값을 보고
실전 선수를 지도하는 코치처럼 한국어 피드백을 JSON으로만 출력해라.

[앱 정체성]
1. 팔씨름 보조 웨이트 (사이드프레셔, 프로네이션컬, 라이징, 백프레셔, 리스트컬)
2. 파워리프팅 (스쿼트, 벤치프레스, 데드리프트)

[사용자 레벨: {user_level}]
{level_instructions.get(user_level, level_instructions["beginner"])}
{armwrestling_note}
[용어 규칙 - 절대 지켜야 함]
전문 해부학 용어 금지, 반드시 쉬운 표현으로:
  ❌ "회내" → ✅ "엄지를 바닥 방향으로 돌리는 동작"
  ❌ "회외" → ✅ "새끼손가락을 축으로 몸 쪽으로 돌리는 동작"
  ❌ "회내근 활성화" → ✅ "엄지를 아래로 돌리는 근육이 제대로 쓰임"
  ❌ "아이소메트릭" → ✅ "버티기"
  ❌ "네거티브" → ✅ "천천히 내리기"
  ❌ "ROM" → ✅ "가동 범위"

[핵심 원칙]
1. 수행 전체를 파악해서 피드백 — 단순 항목 나열 금지
2. "사용자님" 호칭 사용 — 친근하게
3. AI 측정값(detail)을 반드시 활용해서 구체적으로 설명
4. 점수/수치 언급 금지
5. "기초부터", "불안정해요" 같은 추상적 표현 금지
6. 레이어 1 항목이 있으면 반드시 경고 — 등급 무관

[출력 형식 - JSON만 출력]
{{
  "summary": "사용자님 호칭 포함, 가장 두드러진 장점으로 시작하는 한 줄 요약",
  "reason": "장점 — 측정값 기반 구체적 칭찬 + 실전 연결.\\n약점/위험 — 측정값 기반 원인 설명 (레이어 1이면 경고 강조)",
  "action": "해결 방안 — 신체 부위 + 방향 + 감각 포함. {'버티기/부분반복 포함' if is_armwrestling else '구체적 행동'}",
  "cue": "추천 루틴: [운동명] X회 Y세트, [운동명] X회 Y세트"
}}"""


# ── 운동별 맥락 ───────────────────────────────────────────────────────────

EXERCISE_CONTEXT = {
    "pronation_curl": """
[프로네이션컬 - 팔씨름 보조]
핵심: 케이블/덤벨/원판을 잡고 컬 + 동시에 엄지를 바닥 방향으로 돌리기
실전: 팔씨름 훅 전환 — 엄지를 아래로 돌리는 근육 강화

[측정값 해석]
엄지 방향 전환 충분: 장점 칭찬 + 버티기 세트 추천
엄지 방향 전환 약함: 중량 감소 + 손목 45도 굽힌 후 엄지 방향 집중
컬 가동범위 짧음: 부분 범위 = 실전 팔씨름 패턴 — 이 구간 폭발 반복 추천
중량 과함: 패턴 먼저 익혀야 함 (중량 줄이기보다 자세 먼저)

[추천 루틴 풀]
엄지 방향 약함: 해머컬 8회 4세트, 프로네이션컬 12회 4세트
중량 과함: 프로네이션컬 15회 3세트 (경량), 손목 버티기 5초 5세트
""",
    "side_pressure": """
[사이드프레셔 - 팔씨름 보조]
핵심: 팔꿈치 80~100도 + 엄지 바닥 방향 + 수평 가압
실전: 팔씨름 사이드프레셔 — 상대를 옆으로 밀어내는 힘

[측정값 해석]
팔꿈치 펴짐(100도↑): 어깨 쪽으로 힘 분산 → 사이드 힘 손실
팔꿈치 각도 좋음: 현재 자세에서 버티기 세트 추천
엄지 방향 좋음: 3~5초 버티기 추가
엄지가 위 향함: 엄지 바닥 방향 돌린 상태에서 버티기 집중
상체 기울기 과다: 중량 감소 신호

[추천 루틴 풀]
프레임 좋음: 사이드프레셔 버티기 5초 5세트, 사이드프레셔 10회 4세트
엄지 방향 약함: 사이드프레셔 버티기 5초 5세트, 프로네이션컬 12회 4세트
""",
    "wrist_curl": """
[리스트컬 - 팔씨름 보조]
핵심: 전완 고정 + 손목 전체 범위 + 손가락 끝까지 내리기
실전: 팔씨름 손목 굴곡력 — 상대 손목을 꺾어 내리는 힘

[추천 루틴 풀]
가동범위 충분: 리스트컬 최고점 버티기 3초 5세트, 리스트컬 15회 4세트
가동범위 부족: 손가락 컬 20회 3세트, 리스트컬 12회 4세트
""",
    "squat": """
[스쿼트 - 파워리프팅]
핵심: 허벅지 평행 이하, 등 중립, 무릎 발끝 방향

[레이어 1 부상 위험 항목]
무릎 내측 붕괴: 무릎 인대 파열 위험 — 반드시 경고
등 과도 굽힘: 허리 디스크 부담 — 반드시 경고

[추천 루틴 풀]
깊이 부족: 고블릿 스쿼트 15회 3세트, 스쿼트 12회 4세트
무릎 문제: 박스 스쿼트 12회 3세트, 스쿼트 10회 4세트
""",
    "bench_press": """
[벤치프레스 - 파워리프팅]
핵심: 팔꿈치 45도, 가슴 중앙 방향, 경로 일정

[레이어 1 부상 위험 항목]
팔꿈치 과도 벌어짐(90도↑): 어깨 관절 충돌 위험 — 반드시 경고

[추천 루틴 풀]
팔꿈치 문제: 덤벨 플라이 12회 3세트, 벤치프레스 10회 4세트
경로 문제: 덤벨 프레스 12회 3세트, 벤치프레스 8회 4세트
""",
    "deadlift": """
[데드리프트 - 파워리프팅]
핵심: 등 중립, 힙 힌지 주도, 락아웃 완성

[레이어 1 부상 위험 항목]
등 말림 (척추 굴곡): 허리 부상 위험 — 반드시 경고
좌우 불균형 심함: 척추 비틀림 부하 — 반드시 경고

[추천 루틴 풀]
락아웃 문제: 루마니안 데드리프트 12회 3세트, 데드리프트 5회 5세트
등 문제: 굿모닝 12회 3세트, 루마니안 데드리프트 15회 3세트
""",
}


# ── 메인 피드백 생성 함수 ────────────────────────────────────────────────

def generate_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    detected_issues: list,
    user_level: str = "beginner",
    layer1_issues: list | None = None,
    layer2_issues: list | None = None,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("[GeminiService] GEMINI_API_KEY 없음, 기본 피드백 반환")
        return _fallback_feedback(exercise_type, total_score, criteria_scores, user_level)

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

    # 레벨별 어조
    tone_map = {
        "beginner": "초보자 — 칭찬 먼저, 핵심 문제 1~2개, 추천 루틴 필수.",
        "intermediate": "중급자 — 잘한 점 칭찬 후 핵심 개선점 + 추천 루틴.",
        "advanced": "상급자 — 간결하게. 잘한 점 + 레이어1 경고 + 심화 훈련 루틴.",
    }
    tone = tone_map.get(user_level, tone_map["beginner"])

    # 잘된 항목 / 약한 항목 분리 (detail 전체 전달)
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

    # 레이어 1 (부상 위험)
    has_layer1 = bool(layer1_issues)
    l1_text = "없음"
    if layer1_issues:
        l1_text = "\n".join(
            f"  🚨 {i['criterion']}: {i.get('score', '')}점 — {i['reason']}"
            for i in layer1_issues
        )

    # 레이어 2 (스타일 개선)
    l2_text = "없음"
    if layer2_issues:
        l2_text = "\n".join(
            f"  💡 {i['criterion']}: {i.get('score', '')}점 — {i['reason']}"
            for i in layer2_issues
        )

    context = EXERCISE_CONTEXT.get(exercise_type, "")

    is_armwrestling = exercise_type in [
        "side_pressure", "pronation_curl", "wrist_curl", "rising", "back_pressure"
    ]

    user_message = f"""운동: {exercise_name}
사용자 레벨: {user_level} | 코칭 어조: {tone}
{context}
[AI 측정값 - 잘된 항목 (장점 근거)]
{good_text}

[AI 측정값 - 개선 필요 항목 (약점 근거, 낮은 순)]
{weak_text}

[레이어 1 — 부상 위험 항목 (반드시 경고)]
{l1_text}

[레이어 2 — 스타일 개선 항목]
{l2_text}

위 AI 측정값을 반드시 활용해서 4섹션 피드백을 JSON으로 작성해줘.

필수 작성 규칙:
1. summary: "사용자님" 호칭, 가장 두드러진 장점으로 시작
2. reason 첫 줄: 잘된 항목 측정값 기반으로 구체적 칭찬 + 실전 연결
3. reason 둘째 줄: {"🚨 레이어 1 항목이 있으면 부상 위험 먼저 경고 후 " if has_layer1 else ""}가장 약한 항목 측정값 기반으로 원인 설명
4. action: {"버티기/부분반복 포함 + " if is_armwrestling else ""}신체 부위 + 방향 + 감각 포함
5. cue: "추천 루틴: [운동명] X회 Y세트, [운동명] X회 Y세트" 형식으로 2~3가지
6. 전문 용어 절대 금지 (회내/회외/아이소메트릭 등)
7. 점수 언급 금지
8. "기초부터", "불안정해요" 등 추상적 표현 금지"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=_build_system_prompt(user_level, has_layer1, exercise_type),
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=600,
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
        return _fallback_feedback(exercise_type, total_score, criteria_scores, user_level)


# ── Fallback 피드백 ──────────────────────────────────────────────────────

def _fallback_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    user_level: str = "beginner",
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
    # detail의 첫 번째 파이프 구분 앞 부분만 추출
    weak_detail = weak.get('detail', '').split('|')[0].strip() if weak else ''
    strong_detail = strong.get('detail', '').split('|')[0].strip() if strong else ''

    fallback_map = {
        "pronation_curl": {
            "high": {
                "summary": "사용자님의 컬 동작과 손목 컨트롤이 상당히 좋은 편이에요!",
                "reason": f"{strong_detail or '손목이 일정한 호를 그리며 올라오는 컬 궤적이 안정적이에요. 실전 팔씨름 훅 상황에서 유리해요.'}\n{weak_detail or '엄지를 바닥 방향으로 돌리는 타이밍이 조금 늦어요. 최고점에서 엄지가 완전히 바닥을 향하도록 신경 써보세요.'}",
                "action": "엄지가 완전히 바닥을 향한 지점에서 3초 버텨보세요. 그리고 엄지가 옆을 향하는 중간 지점에서 깔짝깔짝 빠르게 10회 반복하는 세트를 추가해보세요.",
                "cue": "추천 루틴: 해머컬 8회 4세트, 프로네이션컬 최고점 버티기 5초 5세트",
            },
            "mid": {
                "summary": "사용자님의 손목 굽힘 능력은 좋은 편이에요! 엄지 방향 전환만 잡으면 훨씬 강해질 거예요.",
                "reason": f"{strong_detail or '손목이 일정한 호를 그리며 올라오는 컬 궤적이 안정적이에요.'}\n{weak_detail or '컬 동작 중 엄지를 바닥 방향으로 돌리는 힘이 약해서 팔씨름 훅 전환에 필요한 힘이 발휘되지 않고 있어요.'}",
                "action": "현재 중량보다 낮춰서 진행하고, 손목을 45도 정도 안쪽으로 굽힌 후 엄지가 몸통을 바라보게 위치시키세요. 거기서 컬을 올리면서 엄지가 완전히 바닥을 향하도록 돌리는 것에 집중해보세요. 엄지가 바닥을 향한 지점에서 3초 버텨보세요!",
                "cue": "추천 루틴: 해머컬 8회 4세트, 프로네이션컬 12회 4세트",
            },
            "low": {
                "summary": "사용자님의 컬 방향은 잡혀 있어요! 엄지를 바닥으로 돌리는 패턴을 익히면 완전히 달라질 거예요.",
                "reason": f"이 운동의 핵심은 컬을 올리면서 동시에 엄지를 바닥 방향으로 돌리는 거예요.\n{weak_detail or '지금은 컬만 하고 엄지 방향 전환이 일어나지 않고 있어요. 팔씨름 훅 전환 힘이 키워지지 않아요.'}",
                "action": "먼저 가벼운 무게로 손목을 45도 안쪽으로 굽히고 엄지가 몸통을 바라보게 위치시키세요. 거기서 엄지를 완전히 바닥을 향해 돌리는 동작을 연습하세요. 그 지점에서 3초 버티기가 핵심이에요!",
                "cue": "추천 루틴: 프로네이션컬 15회 3세트 (경량), 손목 버티기 5초 5세트",
            },
        },
        "side_pressure": {
            "high": {
                "summary": "사용자님의 프레임과 체중 전달이 정말 인상적이에요!",
                "reason": f"{strong_detail or '어깨-팔꿈치-손으로 이어지는 프레임이 단단해요. 실전에서 강한 사이드 압박이 나올 수 있어요.'}\n{weak_detail or '팔꿈치가 몸통에서 살짝 멀어지면서 어깨 쪽으로 힘이 분산되고 있어요.'}",
                "action": "최대 가압 자세에서 3~5초 버텨보세요. 실전에서 상대가 밀어올 때 버티는 힘이 이렇게 길러져요.",
                "cue": "추천 루틴: 사이드프레셔 버티기 5초 5세트, 사이드프레셔 10회 4세트",
            },
            "mid": {
                "summary": "사용자님의 팔 방향과 체중 전달은 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '어깨 방향이 수평 가압에 적합하게 잡혀 있어요.'}\n{weak_detail or '엄지가 아직 위를 향하고 있어요. 엄지를 아래로 돌리는 근육이 쓰이지 않아 옆으로 미는 힘이 위쪽으로 새고 있어요.'}",
                "action": "엄지를 완전히 바닥 방향으로 돌린 상태에서 그 자세를 3초 버텨보세요. 이 버티는 힘이 사이드 방향 힘의 핵심이에요.",
                "cue": "추천 루틴: 사이드프레셔 버티기 5초 5세트, 프로네이션컬 12회 4세트",
            },
            "low": {
                "summary": "사용자님, 방향 감각을 잡아가고 있어요! 핵심 자세를 익히면 훨씬 강해질 거예요.",
                "reason": f"이 운동의 핵심은 팔꿈치 90도 + 엄지를 바닥 방향으로 돌린 상태에서 옆으로 미는 거예요.\n{weak_detail or '팔꿈치가 펴지거나 엄지가 위를 향하면 힘이 어깨와 위쪽으로 분산돼요.'}",
                "action": "팔꿈치를 90도로 굽히고 엄지를 완전히 바닥 방향으로 돌린 상태에서 그 자세를 3초 버텨보세요.",
                "cue": "추천 루틴: 자세 버티기 5초 5세트, 사이드프레셔 10회 3세트",
            },
        },
        "wrist_curl": {
            "high": {
                "summary": "사용자님의 고중량 컨트롤이 정말 인상적이에요!",
                "reason": f"{strong_detail or '고중량을 끝까지 버티는 컨트롤이 실전에서 상대 손목을 꺾어 내리는 힘으로 직결돼요.'}\n{weak_detail or '팔꿈치가 무릎에서 살짝 들리면서 위팔이 개입되고 있어요.'}",
                "action": "손목을 최대로 꺾어 올린 상태에서 1초 잠그고, 천천히 3초에 걸쳐 내려오세요. 팔꿈치는 무릎에 꽉 눌러 고정하세요.",
                "cue": "추천 루틴: 리스트컬 최고점 버티기 3초 5세트, 리스트컬 15회 4세트",
            },
            "mid": {
                "summary": "사용자님, 꾸준히 잘 수행하고 있어요!",
                "reason": f"{strong_detail or '손가락 끝까지 힘을 전달하려는 시도가 좋아요.'}\n{weak_detail or '손목 가동 범위가 짧아서 전완 근육이 일부만 동원되고 있어요.'}",
                "action": "손가락을 끝까지 펴서 바를 손끝으로 받치는 느낌으로 내리고, 손목을 끝까지 꺾어 올리세요. 최고점에서 1초 잠그기를 추가해보세요.",
                "cue": "추천 루틴: 손가락 컬 20회 3세트, 리스트컬 12회 4세트",
            },
            "low": {
                "summary": "사용자님, 전완 훈련의 방향을 잡아가고 있어요!",
                "reason": f"손목 전체 범위와 최고점 버티기가 전완 굴곡력의 핵심이에요.\n{weak_detail or '지금은 손목 움직임이 짧아서 전완 근육이 일부만 동원되고 있어요.'}",
                "action": "가벼운 무게로 손가락 끝까지 내렸다가 손목을 끝까지 꺾어 올리고, 그 최고점에서 3초 버텨보세요.",
                "cue": "추천 루틴: 리스트컬 15회 3세트 (경량), 손목 버티기 5초 5세트",
            },
        },
        "squat": {
            "high": {
                "summary": "사용자님의 힙 힌지 패턴이 정말 안정적이에요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '무릎이 발끝보다 앞으로 나가면 무릎 관절 전면에 부담이 집중돼요.'}",
                "action": "내려갈 때 발뒤꿈치에 체중을 실으면서 엉덩이를 뒤로 빼는 느낌으로 앉아보세요.",
                "cue": "추천 루틴: 고블릿 스쿼트 15회 3세트, 스쿼트 8회 4세트",
            },
            "mid": {
                "summary": "사용자님의 기본 패턴이 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '하체 힘이 안정적으로 전달되고 있어요.'}\n{weak_detail or '깊이가 부족해서 하체 근육이 최대로 동원되지 않고 있어요.'}",
                "action": "발뒤꿈치에 체중을 실으면서 허벅지가 지면과 평행이 될 때까지 내려가보세요.",
                "cue": "추천 루틴: 박스 스쿼트 12회 3세트, 스쿼트 10회 4세트",
            },
            "low": {
                "summary": "사용자님, 동작 방향을 잡아가고 있어요!",
                "reason": f"등 중립과 무릎 방향이 스쿼트의 안전한 기반이에요.\n{weak_detail or '무릎이 안쪽으로 모이면 무릎 내측 인대에 부담이 집중돼요.'}",
                "action": "맨몸으로 천천히 내려가면서 무릎이 발끝 방향을 향하는지 먼저 확인해보세요.",
                "cue": "추천 루틴: 맨몸 스쿼트 20회 3세트, 고블릿 스쿼트 15회 3세트",
            },
        },
        "bench_press": {
            "high": {
                "summary": "사용자님의 밀기 파워와 락아웃이 정말 좋아요!",
                "reason": f"{strong_detail or '락아웃까지 힘이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치가 벌어지면 어깨 관절에 부담이 집중되고 가슴 근육 동원이 줄어들어요.'}",
                "action": "바벨을 내릴 때 팔꿈치를 몸통에서 약 45도 유지하면서 'ㄴ'자 모양으로 내려보세요.",
                "cue": "추천 루틴: 덤벨 플라이 12회 3세트, 벤치프레스 8회 4세트",
            },
            "mid": {
                "summary": "사용자님의 가슴 자극 방향은 잘 잡혀 있어요!",
                "reason": f"{strong_detail or '가슴 근육에 자극이 잘 전달되고 있어요.'}\n{weak_detail or '팔꿈치 경로가 일정하지 않아서 힘 전달 효율이 떨어지고 있어요.'}",
                "action": "올릴 때 가슴 중앙을 향해 밀어 올린다고 생각하면 경로가 자연스럽게 잡혀요.",
                "cue": "추천 루틴: 덤벨 프레스 12회 3세트, 벤치프레스 10회 4세트",
            },
            "low": {
                "summary": "사용자님, 기본 방향을 잡아가고 있어요!",
                "reason": f"팔꿈치 각도 45도가 벤치프레스의 안전한 기반이에요.\n{weak_detail or '팔꿈치가 너무 벌어지면 어깨 관절 부담이 집중되어 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 팔꿈치를 45도로 유지하면서 천천히 내렸다가 올려보세요.",
                "cue": "추천 루틴: 덤벨 프레스 15회 3세트, 푸시업 20회 3세트",
            },
        },
        "deadlift": {
            "high": {
                "summary": "사용자님의 힙 힌지 패턴과 힘 전달이 정말 좋아요!",
                "reason": f"{strong_detail or '하체-등 연결 타이밍이 좋고 힘 전달 효율이 높아요.'}\n{weak_detail or '락아웃에서 좌우 힘 차이가 생기면 척추에 비틀림 부하가 발생해요.'}",
                "action": "바벨을 끝까지 올릴 때 양쪽 엉덩이를 똑같이 앞으로 밀어내며 척추를 곧게 펴보세요.",
                "cue": "추천 루틴: 루마니안 데드리프트 12회 3세트, 데드리프트 5회 5세트",
            },
            "mid": {
                "summary": "사용자님의 힙 힌지 패턴이 잘 나오고 있어요!",
                "reason": f"{strong_detail or '등 각도를 안정적으로 유지하고 있어요.'}\n{weak_detail or '락아웃이 완성되지 않으면 엉덩이 근육이 최대로 수축되지 않아요.'}",
                "action": "바벨을 올릴 때 엉덩이로 앞에 있는 벽을 민다고 생각하면 자연스럽게 완성돼요.",
                "cue": "추천 루틴: 굿모닝 12회 3세트, 데드리프트 6회 4세트",
            },
            "low": {
                "summary": "사용자님, 동작 방향을 잡아가고 있어요!",
                "reason": f"등 중립이 데드리프트의 가장 중요한 안전 기반이에요.\n{weak_detail or '등이 말리면 척추 후방 인대에 부담이 집중되어 허리 부상 위험이 높아져요.'}",
                "action": "가벼운 무게로 등을 곧게 편 상태에서 엉덩이만 뒤로 빼는 힙 힌지 패턴을 먼저 익혀보세요.",
                "cue": "추천 루틴: 루마니안 데드리프트 15회 3세트, 힙 쓰러스트 15회 3세트",
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
        "summary": f"사용자님의 {exercise_name} 수행을 분석했어요. 꾸준히 하면 훨씬 강해질 거예요!",
        "reason": f"{strong_detail or '동작 방향은 잡혀 있어요.'}\n{weak_detail or '핵심 자세를 다듬으면 힘 전달이 훨씬 좋아질 거예요.'}",
        "action": "가벼운 무게로 최대 수축 지점에서 3초 버티는 연습부터 시작해보세요.",
        "cue": f"추천 루틴: {exercise_name} 12회 4세트, 버티기 5초 5세트",
    })

    return json.dumps(fb, ensure_ascii=False)
