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
- 85점 이상: 매우 잘함. 칭찬 위주로, 발전 포인트 1개만 살짝 언급
- 70~84점: 잘하고 있음. 칭찬 먼저, 개선점 1개만
- 50~69점: 보통. 가장 중요한 개선점 1~2개
- 50점 미만: 기초 필요. 핵심 1개만 집중

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

[reason 작성 규칙 - 핵심]
reason은 반드시 두 줄 구조로 작성한다:
  첫 번째 줄: 잘한 점 (실전/스포츠 관점에서 유리한 이유 포함)
  두 번째 줄: 리스크 또는 개선 포인트 (부드럽게, 실전에서 어떤 약점이 되는지 설명)
예시:
  "고중량 컨트롤 능력이 좋아서 실전 팔씨름에 유리해요.\n다만 팔꿈치가 약간 풀리면서 힘 전달이 분산될 수 있어요."

[cue 작성 규칙 - 핵심]
cue는 반드시 "GOOD 파트 / 개선 파트" 형식으로 작성한다.
예시:
  "고중량 유지력 GOOD / 끝지점 잠그는 힘 강화 필요"
  "중량 전달 GOOD / 락아웃 좌우 밸런스 개선 필요"
  "밀기 파워 GOOD / 팔꿈치 각도 교정 필요"

[출력 형식 - JSON만 출력, 다른 텍스트 없음]
{
  "summary": "전체 수행에 대한 한 줄 평가 (칭찬 또는 긍정적 시작)",
  "reason": "잘한 점 먼저 한 줄.\\n다음 줄에 리스크 또는 개선 포인트 한 줄.",
  "action": "지금 당장 할 수 있는 행동 1~2개 (신체 부위 + 방향 + 타이밍 포함)",
  "cue": "GOOD 파트 / 개선 파트 형식의 핵심 한 줄",
  "style": "strict / cheat / strength / armwrestling 중 이 수행에 가장 가까운 스타일"
}"""

# 운동별 맥락 정보
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
- reason 잘한 점 예시: "고중량 컨트롤 능력 좋음 → 실전 팔씨름에 유리"
- reason 리스크 예시: "팔꿈치 약간 풀리면서 힘 전달 손실 발생 가능"
""",
    "squat": """
[스쿼트 운동 특성]
- 발을 어깨너비로 벌리고 무릎을 굽혔다 펴는 운동
- 정상 깊이: 허벅지가 지면과 평행(무릎 각도 90도 이하)
- 무릎이 발끝 방향으로 향해야 하고, 등은 곧게 유지
- reason 잘한 점 예시: "힙 힌지 타이밍과 하체 연결이 안정적"
- reason 리스크 예시: "무릎이 발끝보다 앞으로 나가면 무릎 관절 부담 증가"
""",
    "bench_press": """
[벤치프레스 운동 특성]
- 누운 상태에서 바벨/덤벨을 가슴까지 내렸다가 올리는 운동
- 정상 바텀: 팔꿈치 각도 85~95도
- 팔꿈치는 몸통과 약 45도 각도 유지
- reason 잘한 점 예시: "푸시 파워와 락아웃 힘 전달이 좋음"
- reason 리스크 예시: "팔꿈치 벌어짐 → 어깨 부담 + 힘 분산으로 실전 약점 될 수 있음"
""",
    "deadlift": """
[데드리프트 운동 특성]
- 바닥의 바벨을 엉덩이 힌지로 들어올리는 운동
- 등은 45도 이내로 유지, 무릎은 살짝만 굽힘
- 마지막에 엉덩이를 완전히 펴서 락아웃 완성
- reason 잘한 점 예시: "하체-등 연결 타이밍 좋음 → 중량 효율 좋음"
- reason 리스크 예시: "락아웃에서 좌우 힘 차이 → 실전에서 버티기 약점 될 수 있음"
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

    good_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ✅"
        for c in good_criteria
    ) or "  없음"

    weak_text = "\n".join(
        f"  - {c['name']}: {c['score']:.0f}점 ⚠️"
        for c in weak_criteria
    ) or "  없음"

    context = EXERCISE_CONTEXT.get(exercise_type, "")

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100 → 수준: {score_level}
{context}
[잘한 항목]
{good_text}

[아쉬운 항목]
{weak_text}

위 데이터를 바탕으로 이 사용자에게 코치 피드백을 JSON으로 작성해줘.

중요한 출력 규칙:
1. reason은 두 줄 구조: 첫 줄은 잘한 점(실전/스포츠 관점 포함), 둘째 줄은 리스크/개선 포인트
2. cue는 반드시 "GOOD 파트 / 개선 파트" 형식으로 작성
   예: "고중량 유지력 GOOD / 끝지점 잠그는 힘 강화 필요"
3. 잘한 점을 먼저 언급하고, 교정이 필요한 경우 실전 관점에서 어떤 약점이 되는지 부드럽게 제안"""

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

    # 운동별 / 점수 구간별 fallback (GOOD / 개선 형식 반영)
    fallback_map = {
        "wrist_curl": {
            "high": {
                "summary": f"{exercise_name} 중량 컨트롤이 안정적으로 잘 이루어지고 있어요.",
                "reason": "고중량 컨트롤 능력이 좋아서 실전 팔씨름에 유리해요.\n다만 팔꿈치가 약간 풀리면서 힘 전달이 분산될 수 있어요.",
                "action": "손목을 최대로 꺾어 올릴 때 1초 버텨주세요. 팔꿈치는 무릎 위에 꽉 고정해보세요.",
                "cue": "고중량 유지력 GOOD / 끝지점 잠그는 힘 강화 필요",
                "style": "cheat",
            },
            "mid": {
                "summary": f"{exercise_name} 꾸준한 리듬으로 동작을 이어가려는 일관성이 돋보여요.",
                "reason": "핑거롤 방식으로 손가락 끝까지 힘을 전달하려는 시도가 인상 깊어요.\n손목을 최대로 꺾어 올리는 구간에서 팔꿈치 고정을 더 신경 써주세요.",
                "action": "손목을 끝까지 내렸다가 올릴 때, 팔꿈치가 살짝 들리지 않도록 무릎이나 벤치에 더 꽉 고정해보세요.",
                "cue": "전완 자극 GOOD / 팔꿈치 고정 강화 필요",
                "style": "strict",
            },
            "low": {
                "summary": f"{exercise_name} 기본 동작부터 천천히 연습해봐요.",
                "reason": "가동범위를 늘리면 전완 자극이 훨씬 강해져요.\n지금은 손목 움직임이 짧아서 효과가 줄어들고 있어요.",
                "action": "가벼운 무게로 손가락 끝까지 내렸다가 끝까지 올리는 Full ROM을 먼저 익혀보세요.",
                "cue": "동작 시작 GOOD / Full ROM 확보 필요",
                "style": "strict",
            },
        },
        "squat": {
            "high": {
                "summary": f"{exercise_name} 힙 힌지 동작이 정말 자연스럽고 좋아요!",
                "reason": "엉덩이를 뒤로 빼는 힙 힌지 타이밍과 하체 연결이 안정적이에요.\n무릎이 발끝보다 앞으로 나가지 않도록 조금만 더 신경 써주세요.",
                "action": "무릎을 살짝 더 굽히면서 엉덩이를 더 깊게 앉는 느낌으로 내려가 보세요. 허리가 굽지 않도록 복부에 힘을 주세요.",
                "cue": "힙 힌지 GOOD / 무릎 방향 유지 필요",
                "style": "strength",
            },
            "mid": {
                "summary": f"{exercise_name} 기본 자세가 잘 잡혀 있어요!",
                "reason": "하체 힘이 잘 전달되고 있어요.\n깊이를 조금 더 늘리면 근육 자극이 훨씬 강해질 거예요.",
                "action": "발뒤꿈치에 체중을 실으면서 허벅지가 지면과 평행이 될 때까지 천천히 내려가 보세요.",
                "cue": "기본 자세 GOOD / 스쿼트 깊이 개선 필요",
                "style": "strict",
            },
            "low": {
                "summary": f"{exercise_name} 기본 동작부터 천천히 연습해봐요.",
                "reason": "지금 자세를 잡는 것 자체가 이미 훈련이에요.\n등 각도와 무릎 방향을 먼저 잡는 게 핵심이에요.",
                "action": "가벼운 무게나 맨몸으로 천천히 내려가면서 무릎이 발끝 방향을 향하는지 확인해보세요.",
                "cue": "동작 시작 GOOD / 자세 기초 확립 필요",
                "style": "strict",
            },
        },
        "bench_press": {
            "high": {
                "summary": f"{exercise_name} 락아웃 힘 전달이 정말 좋아요!",
                "reason": "푸시 파워와 상체 밀기 능력이 좋아요.\n팔꿈치가 벌어지면 어깨 부담이 커지고 힘이 분산될 수 있어요.",
                "action": "바벨을 내릴 때 팔꿈치를 몸통에서 약 45도 유지하면서, 마치 'ㄴ'자 모양을 만든다는 느낌으로 내려보세요.",
                "cue": "밀기 파워 GOOD / 팔꿈치 각도 교정 필요",
                "style": "strength",
            },
            "mid": {
                "summary": f"{exercise_name} 전반적으로 괜찮게 하고 있어요!",
                "reason": "가슴 근육에 자극이 잘 가고 있어요.\n팔꿈치 경로를 일정하게 유지하면 어깨 부담을 더 줄일 수 있어요.",
                "action": "올릴 때는 가슴 중앙을 향해 밀어 올린다고 생각하면 경로가 자연스럽게 잡혀요.",
                "cue": "가슴 자극 GOOD / 팔꿈치 경로 안정화 필요",
                "style": "strict",
            },
            "low": {
                "summary": f"{exercise_name} 기본 동작부터 천천히 연습해봐요.",
                "reason": "가벼운 무게로 자세를 먼저 잡는 게 중요해요.\n팔꿈치 각도와 바벨 경로를 익히는 게 핵심이에요.",
                "action": "가벼운 무게로 팔꿈치를 45도로 유지하면서 천천히 내렸다가 올려보세요.",
                "cue": "동작 시작 GOOD / 팔꿈치 각도 확립 필요",
                "style": "strict",
            },
        },
        "deadlift": {
            "high": {
                "summary": f"{exercise_name} 자세 정말 잘 잡아주고 계시네요!",
                "reason": "하체-등 연결 타이밍이 좋고 중량 효율이 높아요.\n락아웃에서 좌우 힘 차이가 생기면 실전에서 버티기 약점이 될 수 있어요.",
                "action": "바벨을 끝까지 들어 올릴 때, 양쪽 엉덩이를 똑같이 앞으로 밀어내며 척추를 곧게 펴는 느낌으로 마무리해보세요.",
                "cue": "중량 전달 GOOD / 락아웃 좌우 밸런스 개선 필요",
                "style": "strength",
            },
            "mid": {
                "summary": f"{exercise_name} 엉덩이 힌지 동작이 잘 나오고 있어요!",
                "reason": "등 각도를 안정적으로 유지하는 게 인상적이에요.\n마지막 락아웃 동작을 더 완성하면 힘 전달이 훨씬 좋아져요.",
                "action": "바벨을 들어 올릴 때 엉덩이로 벽을 민다고 생각하면 척추가 자연스럽게 펴져요.",
                "cue": "힙 힌지 GOOD / 락아웃 완성도 개선 필요",
                "style": "strength",
            },
            "low": {
                "summary": f"{exercise_name} 기본 동작부터 천천히 연습해봐요.",
                "reason": "등 중립 자세를 먼저 익히는 게 핵심이에요.\n지금은 등이 말리는 구간이 있어서 부상 위험이 있어요.",
                "action": "가벼운 무게로 등을 곧게 편 상태에서 엉덩이만 뒤로 빼는 연습을 먼저 해보세요.",
                "cue": "동작 시작 GOOD / 등 중립 자세 확립 필요",
                "style": "strict",
            },
        },
    }

    # 점수 구간 결정
    if total_score >= 70:
        tier = "high"
    elif total_score >= 50:
        tier = "mid"
    else:
        tier = "low"

    ex_map = fallback_map.get(exercise_type, {})
    fb = ex_map.get(tier, {
        "summary": f"{exercise_name} 수행하셨어요. 꾸준히 하면 좋아질 거예요!",
        "reason": f"총점 {total_score}점 기준으로 생성된 기본 피드백이에요.\n지속적인 연습으로 더 나아질 수 있어요.",
        "action": "가벼운 무게로 천천히 Full ROM을 먼저 익혀보세요.",
        "cue": "꾸준한 연습 GOOD / 자세 다듬기 필요",
        "style": "strict",
    })

    return json.dumps(fb, ensure_ascii=False)
