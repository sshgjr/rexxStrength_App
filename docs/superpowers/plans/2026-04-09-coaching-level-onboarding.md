# 코칭 등급 온보딩 시스템 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 회원가입 후 신체정보·운동경력·3대 1RM을 입력받아 Strength Level 표준 + 경력 상한선으로 자동 코칭 등급(초/중/상)을 산정하고, 정보 부족 시 어떤 입력이 미흡했는지 사용자에게 안내하는 온보딩 시스템 구축.

**Architecture:** Backend는 순수 함수 `level_calculator`와 하드코딩 표준 테이블을 분리해 유닛 테스트 가능하게 하고, FastAPI 라우터에서 호출. Frontend는 5단계 PageView 온보딩 + Member 페이지 인라인 등급 설정 섹션. AI 피드백 차등 분기는 이미 `gemini_service.py`에 존재하므로 추가 작업 불필요.

**Tech Stack:** FastAPI, SQLAlchemy, Pydantic v2, pytest (백엔드) / Flutter, http, flutter_test (프론트엔드)

**참조 스펙:** `docs/superpowers/specs/2026-04-09-coaching-level-onboarding-design.md`

---

## File Structure

### Backend 신규/수정 파일
| 파일 | 책임 |
|---|---|
| `rexx_server/data/__init__.py` | 신규 패키지 마커 |
| `rexx_server/data/strength_standards.py` | 하드코딩된 성별×체중×종목 1RM 컷오프 테이블 |
| `rexx_server/services/level_calculator.py` | 순수 함수 등급 산정 + LevelCalculation/Failure dataclass |
| `rexx_server/schemas/onboarding_schemas.py` | OnboardingRequest, OnboardingResponse, MissingReason Pydantic 모델 |
| `rexx_server/routers/onboarding.py` | POST /me/onboarding, GET /me/onboarding-status |
| `rexx_server/auth.py` | User 모델에 컬럼 7개 추가 |
| `rexx_server/migrations.py` | 신규 — startup 자가 마이그레이션 함수 |
| `rexx_server/main.py` | startup hook 등록, onboarding 라우터 include, PUT /me/level 확장 |
| `rexx_server/tests/test_level_calculator.py` | level_calculator 유닛 테스트 |
| `rexx_server/tests/test_onboarding_endpoint.py` | 라우터 통합 테스트 |
| `rexx_server/tests/test_user_migration.py` | 마이그레이션 함수 테스트 |

### Frontend 신규/수정 파일
| 파일 | 책임 |
|---|---|
| `rexx_app/lib/features/onboarding/onboarding_flow.dart` | 5단계 PageView 컨테이너 + 상태 관리 |
| `rexx_app/lib/features/onboarding/models/onboarding_state.dart` | 입력 데이터 + 응답 모델 |
| `rexx_app/lib/features/onboarding/steps/welcome_step.dart` | Step 1 |
| `rexx_app/lib/features/onboarding/steps/body_info_step.dart` | Step 2 |
| `rexx_app/lib/features/onboarding/steps/experience_step.dart` | Step 3 |
| `rexx_app/lib/features/onboarding/steps/lift_input_step.dart` | Step 4 |
| `rexx_app/lib/features/onboarding/steps/result_step.dart` | Step 5-A/5-B 분기 |
| `rexx_app/lib/services/auth_service.dart` | 메서드 3개 추가 |
| `rexx_app/lib/pages/home_screen.dart` | 부팅 시 onboarding-status 체크 → 라우팅 |
| `rexx_app/lib/pages/member.dart` | 코칭 등급 설정 인라인 섹션 |
| `rexx_app/test/features/onboarding/onboarding_flow_test.dart` | 위젯 테스트 |
| `rexx_app/test/features/onboarding/result_step_test.dart` | 5-A/5-B 분기 위젯 테스트 |

---

# PHASE 1: BACKEND

## Task 1: Strength Level 표준 테이블 작성

**Files:**
- Create: `rexx_server/data/__init__.py`
- Create: `rexx_server/data/strength_standards.py`
- Test: `rexx_server/tests/test_strength_standards.py`

- [ ] **Step 1: 패키지 마커 생성**

Create `rexx_server/data/__init__.py`:
```python
```
(빈 파일)

- [ ] **Step 2: 표준 테이블 작성**

Create `rexx_server/data/strength_standards.py`:
```python
"""Strength Level 식 1RM 컷오프 표준 (하드코딩).

각 배열은 [Beginner, Novice, Intermediate, Advanced, Elite] 컷오프 (kg).
출처: strengthlevel.com 공개 표준 (2024년 기준).
업데이트 시 이 파일을 직접 수정 후 PR.
"""

# 체중(kg) → [B, N, I, A, E] 1RM 컷오프 (kg)
STANDARDS: dict[str, dict[str, dict[int, list[float]]]] = {
    "male": {
        "squat": {
            50:  [25, 50, 80, 115, 155],
            60:  [35, 65, 100, 140, 185],
            70:  [45, 80, 120, 165, 215],
            80:  [55, 95, 140, 185, 240],
            90:  [65, 105, 155, 205, 260],
            100: [70, 115, 170, 220, 280],
            110: [80, 125, 180, 235, 295],
            120: [85, 135, 190, 245, 310],
        },
        "bench": {
            50:  [20, 35, 60, 90, 125],
            60:  [30, 50, 75, 110, 145],
            70:  [40, 60, 90, 125, 165],
            80:  [45, 70, 100, 140, 180],
            90:  [55, 80, 115, 150, 195],
            100: [60, 85, 120, 160, 205],
            110: [65, 95, 130, 170, 220],
            120: [70, 100, 135, 180, 230],
        },
        "deadlift": {
            50:  [40, 65, 100, 140, 185],
            60:  [50, 80, 120, 165, 215],
            70:  [60, 95, 140, 190, 245],
            80:  [70, 110, 160, 215, 270],
            90:  [80, 125, 175, 235, 290],
            100: [90, 135, 190, 250, 310],
            110: [95, 145, 205, 265, 325],
            120: [100, 155, 215, 280, 340],
        },
    },
    "female": {
        "squat": {
            45: [15, 30, 50, 75, 105],
            55: [20, 40, 65, 95, 130],
            65: [25, 45, 75, 110, 150],
            75: [30, 55, 85, 125, 165],
            85: [35, 60, 95, 135, 180],
            95: [40, 65, 105, 145, 195],
        },
        "bench": {
            45: [10, 20, 35, 55, 80],
            55: [12, 25, 40, 65, 90],
            65: [15, 30, 50, 75, 100],
            75: [20, 35, 55, 80, 110],
            85: [22, 40, 60, 85, 115],
            95: [25, 42, 65, 90, 120],
        },
        "deadlift": {
            45: [20, 40, 65, 95, 130],
            55: [25, 50, 80, 115, 150],
            65: [35, 60, 95, 130, 170],
            75: [40, 70, 105, 145, 185],
            85: [45, 75, 115, 155, 200],
            95: [50, 85, 125, 165, 215],
        },
    },
}

LIFT_NAMES = ("squat", "bench", "deadlift")
```

- [ ] **Step 3: 표준 테이블 자가 검증 테스트 작성 (failing)**

Create `rexx_server/tests/test_strength_standards.py`:
```python
"""STANDARDS 테이블 구조 검증."""
from data.strength_standards import STANDARDS, LIFT_NAMES


def test_both_sexes_present():
    assert "male" in STANDARDS
    assert "female" in STANDARDS


def test_all_lifts_present_for_each_sex():
    for sex in ("male", "female"):
        for lift in LIFT_NAMES:
            assert lift in STANDARDS[sex], f"{sex}/{lift} 누락"


def test_each_weight_bucket_has_5_cutoffs():
    for sex in STANDARDS:
        for lift in STANDARDS[sex]:
            for weight, cutoffs in STANDARDS[sex][lift].items():
                assert len(cutoffs) == 5, f"{sex}/{lift}/{weight}kg: 컷오프 5개 필요"


def test_cutoffs_are_monotonically_increasing():
    """B < N < I < A < E 순서 검증."""
    for sex in STANDARDS:
        for lift in STANDARDS[sex]:
            for weight, cutoffs in STANDARDS[sex][lift].items():
                for i in range(len(cutoffs) - 1):
                    assert cutoffs[i] < cutoffs[i + 1], (
                        f"{sex}/{lift}/{weight}kg: {cutoffs} 단조증가 위반"
                    )
```

- [ ] **Step 4: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_strength_standards.py -v`
Expected: 4 PASSED

- [ ] **Step 5: 커밋**

```bash
git add rexx_server/data/__init__.py rexx_server/data/strength_standards.py rexx_server/tests/test_strength_standards.py
git commit -m "feat(server): Strength Level 표준 1RM 컷오프 테이블 추가"
```

---

## Task 2: level_calculator — 단일 종목 점수 산정 (TDD)

**Files:**
- Create: `rexx_server/services/level_calculator.py`
- Test: `rexx_server/tests/test_level_calculator.py`

- [ ] **Step 1: 첫 번째 failing 테스트 작성**

Create `rexx_server/tests/test_level_calculator.py`:
```python
"""level_calculator 유닛 테스트."""
from services.level_calculator import score_single_lift


def test_score_below_beginner_returns_0():
    # 70kg 남성 스쿼트 컷오프: [45, 80, 120, 165, 215]
    # 30kg 들면 Beginner(45) 미만 → 0
    assert score_single_lift("male", 70.0, "squat", 30.0) == 0


def test_score_at_beginner_returns_1():
    # 정확히 Beginner 컷오프 → 1 (B 이상이지만 N 미만)
    assert score_single_lift("male", 70.0, "squat", 45.0) == 1


def test_score_at_intermediate_returns_2():
    assert score_single_lift("male", 70.0, "squat", 120.0) == 2


def test_score_at_elite_returns_4():
    assert score_single_lift("male", 70.0, "squat", 215.0) == 4


def test_score_above_elite_clamped_to_4():
    assert score_single_lift("male", 70.0, "squat", 300.0) == 4
```

- [ ] **Step 2: 테스트 실행 (failing 확인)**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: ImportError ("score_single_lift" not found)

- [ ] **Step 3: 최소 구현 작성**

Create `rexx_server/services/level_calculator.py`:
```python
"""Strength Level 표준 기반 코칭 등급 자동 산정.

순수 함수로 구성하여 유닛 테스트가 가능하도록 함.
호출자(라우터)는 입력 검증 후 calculate()를 호출.
"""
from dataclasses import dataclass, field
from typing import Literal, Union

from data.strength_standards import STANDARDS, LIFT_NAMES


def _get_cutoffs(sex: str, lift: str, body_weight_kg: float) -> list[float]:
    """체중 구간 사이는 선형 보간, 양 끝은 clamp."""
    table = STANDARDS[sex][lift]
    weights = sorted(table.keys())

    if body_weight_kg <= weights[0]:
        return list(table[weights[0]])
    if body_weight_kg >= weights[-1]:
        return list(table[weights[-1]])

    # 선형 보간
    for i in range(len(weights) - 1):
        w_low, w_high = weights[i], weights[i + 1]
        if w_low <= body_weight_kg <= w_high:
            ratio = (body_weight_kg - w_low) / (w_high - w_low)
            low_cutoffs = table[w_low]
            high_cutoffs = table[w_high]
            return [
                low_cutoffs[j] + ratio * (high_cutoffs[j] - low_cutoffs[j])
                for j in range(5)
            ]
    return list(table[weights[-1]])  # fallback


def score_single_lift(
    sex: str,
    body_weight_kg: float,
    lift: str,
    one_rm_kg: float,
) -> int:
    """단일 종목 1RM을 0~4 단계 점수로 변환.

    0 = Beginner 미만, 1 = B, 2 = N, 3 = I, 4 = A 이상.
    실제로는 컷오프 [B, N, I, A, E]를 비교하여
    1RM이 i번째 컷오프 이상이면 점수 = i+1로 가산 (최대 5).
    하지만 0~4 범위로 매핑하기 위해 컷오프 미만은 0,
    이후 단계마다 1씩 증가시킴.
    """
    cutoffs = _get_cutoffs(sex, lift, body_weight_kg)
    score = 0
    for cutoff in cutoffs:
        if one_rm_kg >= cutoff:
            score += 1
    # score는 0~5 범위 → 0~4로 clamp (Elite 이상은 4)
    return min(score, 4)
```

- [ ] **Step 4: 테스트 실행 (passing 확인)**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: 5 PASSED

- [ ] **Step 5: 커밋**

```bash
git add rexx_server/services/level_calculator.py rexx_server/tests/test_level_calculator.py
git commit -m "feat(server): score_single_lift 함수 추가 (TDD)"
```

---

## Task 3: level_calculator — 여성 표준 + 보간 + clamp 검증

**Files:**
- Test: `rexx_server/tests/test_level_calculator.py` (확장)

- [ ] **Step 1: 추가 테스트 작성**

Append to `rexx_server/tests/test_level_calculator.py`:
```python
def test_female_standard_used_when_sex_female():
    # 여성 65kg 스쿼트: [25, 45, 75, 110, 150]
    assert score_single_lift("female", 65.0, "squat", 75.0) == 3


def test_weight_interpolation_between_buckets():
    # 75kg 남성 (70kg과 80kg 사이) 스쿼트
    # 70kg: [45, 80, 120, 165, 215], 80kg: [55, 95, 140, 185, 240]
    # 75kg 보간: B=50, N=87.5, I=130, A=175, E=227.5
    # 130kg 들면 정확히 Intermediate 컷오프 → 3
    assert score_single_lift("male", 75.0, "squat", 130.0) == 3


def test_weight_below_min_clamps_to_smallest_bucket():
    # 30kg (50kg 미만) → 50kg 표준 사용
    assert score_single_lift("male", 30.0, "squat", 25.0) == 1


def test_weight_above_max_clamps_to_largest_bucket():
    # 200kg (120kg 초과) → 120kg 표준 사용
    # 120kg 남성 스쿼트 Beginner=85
    assert score_single_lift("male", 200.0, "squat", 85.0) == 1
```

- [ ] **Step 2: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: 9 PASSED (기존 5 + 신규 4)

- [ ] **Step 3: 커밋**

```bash
git add rexx_server/tests/test_level_calculator.py
git commit -m "test(server): score_single_lift 보간/clamp/여성 케이스 검증"
```

---

## Task 4: level_calculator — calculate() 종합 함수 (TDD)

**Files:**
- Modify: `rexx_server/services/level_calculator.py`
- Test: `rexx_server/tests/test_level_calculator.py` (확장)

- [ ] **Step 1: failing 테스트 작성**

Append to `rexx_server/tests/test_level_calculator.py`:
```python
from services.level_calculator import (
    calculate,
    LevelCalculation,
    LevelCalculationFailure,
)


def test_calculate_intermediate_user():
    """70kg 남성 / 스쿼트 120 (I), 벤치 90 (I), 데드 140 (I) → 평균 ≈ 3 → 중급."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,
        bench_1rm=90.0,
        deadlift_1rm=140.0,
        training_experience="2_5y",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "intermediate"
    assert result.capped_by_experience is False
    assert result.per_lift == {"squat": 3, "bench": 3, "deadlift": 3}


def test_calculate_advanced_user():
    """avg ≥ 3.5 → 상급."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=215.0,  # E = 4
        bench_1rm=165.0,  # E = 4
        deadlift_1rm=245.0,  # E = 4
        training_experience="5y_plus",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "advanced"


def test_calculate_beginner_user():
    """avg < 2.0 → 초급."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=50.0,  # B (1)
        bench_1rm=45.0,  # B (1)
        deadlift_1rm=70.0,  # B (1)
        training_experience="6m_2y",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "beginner"


def test_partial_input_only_squat():
    """스쿼트만 입력 → 그 한 종목 평균으로 산정."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    assert isinstance(result, LevelCalculation)
    assert result.per_lift == {"squat": 3}


def test_no_lifts_returns_failure():
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=None,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    assert isinstance(result, LevelCalculationFailure)
    assert "no_lift_inputs" in result.missing_reasons


def test_no_body_weight_returns_failure():
    result = calculate(
        sex="male",
        body_weight_kg=None,
        squat_1rm=120.0,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    assert isinstance(result, LevelCalculationFailure)
    assert "missing_body_weight" in result.missing_reasons


def test_no_weight_and_no_lifts_returns_both_reasons():
    result = calculate(
        sex="male",
        body_weight_kg=None,
        squat_1rm=None,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    assert isinstance(result, LevelCalculationFailure)
    assert "missing_body_weight" in result.missing_reasons
    assert "no_lift_inputs" in result.missing_reasons


def test_sex_none_uses_male_standard():
    """성별 미입력 시 male 표준 fallback."""
    result_none = calculate(
        sex=None,
        body_weight_kg=70.0,
        squat_1rm=120.0,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    result_male = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,
        bench_1rm=None,
        deadlift_1rm=None,
        training_experience=None,
    )
    assert isinstance(result_none, LevelCalculation)
    assert isinstance(result_male, LevelCalculation)
    assert result_none.per_lift == result_male.per_lift
```

- [ ] **Step 2: 테스트 실행 (failing 확인)**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: 8 NEW tests FAIL (calculate not defined)

- [ ] **Step 3: calculate() 구현**

Append to `rexx_server/services/level_calculator.py`:
```python
@dataclass
class LevelCalculation:
    level: Literal["beginner", "intermediate", "advanced"]
    avg_tier_score: float
    capped_by_experience: bool
    per_lift: dict[str, int]


@dataclass
class LevelCalculationFailure:
    missing_reasons: list[str] = field(default_factory=list)


_EXPERIENCE_CAPS = {
    "lt_6m": "beginner",
    "6m_2y": "intermediate",
    "2_5y": None,
    "5y_plus": None,
}

_LEVEL_ORDER = ["beginner", "intermediate", "advanced"]


def _avg_to_level(avg: float) -> str:
    if avg < 2.0:
        return "beginner"
    if avg < 3.5:
        return "intermediate"
    return "advanced"


def _apply_experience_cap(level: str, experience: str | None) -> tuple[str, bool]:
    if experience is None:
        return level, False
    cap = _EXPERIENCE_CAPS.get(experience)
    if cap is None:
        return level, False
    if _LEVEL_ORDER.index(level) > _LEVEL_ORDER.index(cap):
        return cap, True
    return level, False


def calculate(
    sex: str | None,
    body_weight_kg: float | None,
    squat_1rm: float | None,
    bench_1rm: float | None,
    deadlift_1rm: float | None,
    training_experience: str | None,
) -> Union[LevelCalculation, LevelCalculationFailure]:
    """등급 산정 진입점.

    입력이 부족하면 LevelCalculationFailure를 반환하여
    호출자가 default beginner로 처리하도록 함.
    """
    reasons: list[str] = []

    lifts = {
        "squat": squat_1rm,
        "bench": bench_1rm,
        "deadlift": deadlift_1rm,
    }
    provided = {k: v for k, v in lifts.items() if v is not None and v > 0}

    if not provided:
        reasons.append("no_lift_inputs")
    if body_weight_kg is None or body_weight_kg <= 0:
        reasons.append("missing_body_weight")

    if reasons:
        return LevelCalculationFailure(missing_reasons=reasons)

    effective_sex = sex if sex in ("male", "female") else "male"

    try:
        per_lift = {
            lift: score_single_lift(effective_sex, body_weight_kg, lift, one_rm)
            for lift, one_rm in provided.items()
        }
    except Exception:
        return LevelCalculationFailure(missing_reasons=["internal_error"])

    avg = sum(per_lift.values()) / len(per_lift)
    raw_level = _avg_to_level(avg)
    final_level, capped = _apply_experience_cap(raw_level, training_experience)

    return LevelCalculation(
        level=final_level,
        avg_tier_score=round(avg, 2),
        capped_by_experience=capped,
        per_lift=per_lift,
    )
```

- [ ] **Step 4: 테스트 실행 (passing 확인)**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: 17 PASSED (기존 9 + 신규 8)

- [ ] **Step 5: 커밋**

```bash
git add rexx_server/services/level_calculator.py rexx_server/tests/test_level_calculator.py
git commit -m "feat(server): calculate() 종합 등급 산정 함수 + 실패 케이스 (TDD)"
```

---

## Task 5: level_calculator — 경력 상한선 + 컷오프 경계 테스트

**Files:**
- Test: `rexx_server/tests/test_level_calculator.py` (확장)

- [ ] **Step 1: 경력 상한선 테스트 작성**

Append to `rexx_server/tests/test_level_calculator.py`:
```python
def test_experience_cap_lt_6m_forces_beginner():
    """경력 6개월 미만이면 1RM이 높아도 초급으로 강제."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=215.0,
        bench_1rm=165.0,
        deadlift_1rm=245.0,
        training_experience="lt_6m",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "beginner"
    assert result.capped_by_experience is True


def test_experience_cap_6m_2y_forces_intermediate():
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=215.0,
        bench_1rm=165.0,
        deadlift_1rm=245.0,
        training_experience="6m_2y",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "intermediate"
    assert result.capped_by_experience is True


def test_experience_5y_plus_no_cap():
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,
        bench_1rm=90.0,
        deadlift_1rm=140.0,
        training_experience="5y_plus",
    )
    assert isinstance(result, LevelCalculation)
    assert result.capped_by_experience is False


def test_experience_cap_does_not_upgrade():
    """경력 5y_plus라도 1RM이 낮으면 초급은 초급."""
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=50.0,
        bench_1rm=45.0,
        deadlift_1rm=70.0,
        training_experience="5y_plus",
    )
    assert isinstance(result, LevelCalculation)
    assert result.level == "beginner"
    assert result.capped_by_experience is False


def test_cutoff_boundary_just_below_intermediate():
    """avg=1.99 → 초급."""
    # 70kg 남성 스쿼트 Beginner(45)~Novice(80) 사이의 적당한 값으로 점수 1
    # 세 종목 모두 점수 1+1+? = 평균 < 2 만들기
    # 점수 1, 2, 2 → avg = 1.67 → 초급
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=50.0,   # B(45) ≤ 50 < N(80) → 1
        bench_1rm=60.0,   # B(40) ≤ 60 < N(60)? 60=N → 2
        deadlift_1rm=95.0,  # B(60) ≤ 95 < N(95)? 95=N → 2
        training_experience=None,
    )
    assert isinstance(result, LevelCalculation)
    avg = result.avg_tier_score
    assert avg < 2.0
    assert result.level == "beginner"


def test_cutoff_boundary_just_below_advanced():
    """avg < 3.5 → 중급."""
    # 점수 3, 3, 3 → avg = 3.0 → 중급
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,  # I(120) → 3
        bench_1rm=90.0,   # I(90) → 3
        deadlift_1rm=140.0,  # I(140) → 3
        training_experience=None,
    )
    assert isinstance(result, LevelCalculation)
    assert result.avg_tier_score < 3.5
    assert result.level == "intermediate"


def test_cutoff_boundary_at_advanced():
    """avg ≥ 3.5 → 상급."""
    # 점수 3, 4, 4 → avg = 3.67 → 상급
    result = calculate(
        sex="male",
        body_weight_kg=70.0,
        squat_1rm=120.0,     # I(120) → 3
        bench_1rm=125.0,     # A(125) → 4
        deadlift_1rm=190.0,  # A(190) → 4
        training_experience=None,
    )
    assert isinstance(result, LevelCalculation)
    assert result.avg_tier_score >= 3.5
    assert result.level == "advanced"
```

- [ ] **Step 2: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_level_calculator.py -v`
Expected: 24 PASSED (기존 17 + 신규 7)

- [ ] **Step 3: 커밋**

```bash
git add rexx_server/tests/test_level_calculator.py
git commit -m "test(server): 경력 상한선 + 컷오프 경계값 검증"
```

---

## Task 6: User 모델에 컬럼 추가 + 마이그레이션

**Files:**
- Modify: `rexx_server/auth.py:29-40`
- Create: `rexx_server/migrations.py`
- Test: `rexx_server/tests/test_user_migration.py`

- [ ] **Step 1: User 모델 수정**

Edit `rexx_server/auth.py:29-40` — `class User(Base):` 블록을 다음으로 교체:
```python
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    height = Column(Float, nullable=True)
    weight = Column(Float, nullable=True)
    is_body_public = Column(Boolean, default=False, nullable=False)
    interests = Column(Text, nullable=True)  # JSON array string
    level = Column(String(20), nullable=False, server_default="beginner")  # beginner, intermediate, advanced
    # === 코칭 등급 온보딩 (2026-04-09 추가) ===
    sex = Column(String(10), nullable=True)  # "male" | "female" | None
    birth_year = Column(Integer, nullable=True)
    training_experience = Column(String(20), nullable=True)  # lt_6m | 6m_2y | 2_5y | 5y_plus
    squat_1rm = Column(Float, nullable=True)
    bench_1rm = Column(Float, nullable=True)
    deadlift_1rm = Column(Float, nullable=True)
    level_source = Column(String(20), nullable=True)  # auto | manual | default | None(미온보딩)
```

- [ ] **Step 2: 마이그레이션 함수 작성**

Create `rexx_server/migrations.py`:
```python
"""Startup 자가 마이그레이션.

신규 컬럼을 ALTER TABLE로 추가. PostgreSQL은 IF NOT EXISTS 사용,
SQLite는 try/except로 중복 추가 시도를 무시.
컬럼이 모두 nullable이라 롤백 불필요.
"""
from sqlalchemy.engine import Engine

# (컬럼명, 타입) — auth.py의 User 모델과 동기화 필요
ONBOARDING_COLUMNS: list[tuple[str, str]] = [
    ("sex", "VARCHAR(10)"),
    ("birth_year", "INTEGER"),
    ("training_experience", "VARCHAR(20)"),
    ("squat_1rm", "FLOAT"),
    ("bench_1rm", "FLOAT"),
    ("deadlift_1rm", "FLOAT"),
    ("level_source", "VARCHAR(20)"),
]


def ensure_onboarding_columns(engine: Engine) -> None:
    """users 테이블에 온보딩용 컬럼 7개를 멱등하게 추가."""
    dialect = engine.dialect.name
    for name, type_ in ONBOARDING_COLUMNS:
        try:
            with engine.begin() as conn:
                if dialect == "postgresql":
                    sql = f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {name} {type_}"
                else:
                    sql = f"ALTER TABLE users ADD COLUMN {name} {type_}"
                conn.exec_driver_sql(sql)
                print(f"[migration] users.{name} 컬럼 추가됨")
        except Exception as e:
            # 이미 존재하는 컬럼이면 무시 (SQLite duplicate column 등)
            msg = str(e).lower()
            if "duplicate" in msg or "already exists" in msg:
                continue
            print(f"[migration] users.{name} 추가 스킵: {e}")
```

- [ ] **Step 3: 마이그레이션 함수 테스트 작성**

Create `rexx_server/tests/test_user_migration.py`:
```python
"""ensure_onboarding_columns 동작 검증."""
from sqlalchemy import create_engine, inspect
from sqlalchemy.pool import StaticPool

from database import Base
from migrations import ensure_onboarding_columns, ONBOARDING_COLUMNS
# auth import는 User 모델을 등록하기 위해 필요
import auth  # noqa: F401


def _make_engine():
    return create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )


def test_columns_added_to_fresh_table():
    engine = _make_engine()
    Base.metadata.create_all(bind=engine)
    ensure_onboarding_columns(engine)

    inspector = inspect(engine)
    cols = {c["name"] for c in inspector.get_columns("users")}
    for name, _ in ONBOARDING_COLUMNS:
        assert name in cols, f"users.{name} 추가 실패"


def test_running_twice_is_idempotent():
    engine = _make_engine()
    Base.metadata.create_all(bind=engine)
    ensure_onboarding_columns(engine)
    # 두 번째 호출이 예외를 발생시키지 않아야 함
    ensure_onboarding_columns(engine)

    inspector = inspect(engine)
    cols = {c["name"] for c in inspector.get_columns("users")}
    for name, _ in ONBOARDING_COLUMNS:
        assert name in cols
```

- [ ] **Step 4: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_user_migration.py -v`
Expected: 2 PASSED

> 참고: `Base.metadata.create_all`은 이미 새 컬럼을 포함한 테이블을 만들기 때문에 `ensure_onboarding_columns`는 사실상 no-op이 되지만, 두 번 호출이 멱등하다는 사실을 검증하는 것이 핵심.

- [ ] **Step 5: 기존 테스트가 깨지지 않는지 확인**

Run: `cd rexx_server && python -m pytest tests/ -v`
Expected: 모든 기존 테스트 + 신규 테스트 PASS

- [ ] **Step 6: 커밋**

```bash
git add rexx_server/auth.py rexx_server/migrations.py rexx_server/tests/test_user_migration.py
git commit -m "feat(server): User에 온보딩 컬럼 7개 + 자가 마이그레이션 추가"
```

---

## Task 7: main.py에 startup hook 등록

**Files:**
- Modify: `rexx_server/main.py`

- [ ] **Step 1: startup 이벤트 핸들러 등록 위치 확인**

Run: `cd rexx_server && grep -n "startup\|on_event\|app = FastAPI" main.py`
Expected: `app = FastAPI(...)` 정의 라인 확인

- [ ] **Step 2: import 추가**

Edit `rexx_server/main.py` 상단 import 영역에 추가:
```python
from migrations import ensure_onboarding_columns
from database import engine
```
(이미 `database`에서 다른 항목을 import 중이라면 같은 라인에 추가)

- [ ] **Step 3: startup 이벤트 추가**

Edit `rexx_server/main.py` — `app = FastAPI(...)` 정의 직후 다음을 추가:
```python
@app.on_event("startup")
def _run_migrations():
    """앱 부팅 시 누락된 컬럼을 자동으로 추가."""
    try:
        ensure_onboarding_columns(engine)
    except Exception as e:
        # 마이그레이션 실패해도 부팅은 계속 (기존 컬럼만으로도 동작)
        print(f"[startup] 마이그레이션 중 오류 (무시): {e}")
```

- [ ] **Step 4: 부팅 검증**

Run: `cd rexx_server && python -c "from main import app; print('OK')"`
Expected: `OK` 출력 (import 에러 없음)

- [ ] **Step 5: 전체 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/ -v`
Expected: 모든 테스트 PASS

- [ ] **Step 6: 커밋**

```bash
git add rexx_server/main.py
git commit -m "feat(server): startup 시 온보딩 컬럼 자가 마이그레이션 호출"
```

---

## Task 8: Onboarding Pydantic 스키마

**Files:**
- Create: `rexx_server/schemas/onboarding_schemas.py`

- [ ] **Step 1: 스키마 파일 작성**

Create `rexx_server/schemas/onboarding_schemas.py`:
```python
"""온보딩 요청/응답 Pydantic 모델."""
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


SexLiteral = Literal["male", "female"]
ExperienceLiteral = Literal["lt_6m", "6m_2y", "2_5y", "5y_plus"]
LevelLiteral = Literal["beginner", "intermediate", "advanced"]
LevelSourceLiteral = Literal["auto", "manual", "default"]
MissingReasonCode = Literal[
    "missing_body_weight",
    "no_lift_inputs",
    "internal_error",
]


class OnboardingRequest(BaseModel):
    sex: Optional[SexLiteral] = None
    birth_year: Optional[int] = Field(default=None, ge=1900, le=2100)
    training_experience: Optional[ExperienceLiteral] = None
    squat_1rm: Optional[float] = Field(default=None, gt=0, le=600)
    bench_1rm: Optional[float] = Field(default=None, gt=0, le=400)
    deadlift_1rm: Optional[float] = Field(default=None, gt=0, le=600)

    @field_validator("birth_year")
    @classmethod
    def _check_year(cls, v: Optional[int]) -> Optional[int]:
        if v is None:
            return v
        from datetime import datetime
        current_year = datetime.now().year
        if v > current_year:
            raise ValueError("출생연도는 미래일 수 없습니다.")
        return v


class MissingReason(BaseModel):
    code: MissingReasonCode
    message: str


class OnboardingResponse(BaseModel):
    level: LevelLiteral
    level_source: LevelSourceLiteral
    avg_tier_score: Optional[float] = None
    capped_by_experience: bool = False
    per_lift: dict[str, int] = Field(default_factory=dict)
    feedback_style_preview: str
    changeable_in_settings: bool = True
    missing_reasons: list[MissingReason] = Field(default_factory=list)


class OnboardingStatusResponse(BaseModel):
    needs_onboarding: bool
```

- [ ] **Step 2: import 검증**

Run: `cd rexx_server && python -c "from schemas.onboarding_schemas import OnboardingRequest, OnboardingResponse; print('OK')"`
Expected: `OK`

- [ ] **Step 3: 커밋**

```bash
git add rexx_server/schemas/onboarding_schemas.py
git commit -m "feat(server): 온보딩 Pydantic 스키마 추가"
```

---

## Task 9: Onboarding 라우터 (TDD — 산정 성공 케이스)

**Files:**
- Create: `rexx_server/routers/onboarding.py`
- Create: `rexx_server/tests/test_onboarding_endpoint.py`
- Modify: `rexx_server/main.py` (라우터 include)

- [ ] **Step 1: 메시지 매핑 함수 + 피드백 미리보기 헬퍼**

Add to `rexx_server/routers/onboarding.py`:
```python
"""온보딩 라우터.

POST /me/onboarding — 입력 받아 자동 등급 산정 후 저장
GET  /me/onboarding-status — 온보딩 필요 여부 조회
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth import User, get_current_user
from database import get_db
from schemas.onboarding_schemas import (
    OnboardingRequest,
    OnboardingResponse,
    OnboardingStatusResponse,
    MissingReason,
)
from services.level_calculator import (
    calculate,
    LevelCalculation,
    LevelCalculationFailure,
)


router = APIRouter()


_FEEDBACK_PREVIEWS = {
    "beginner": "초급 사용자에게는 매우 상세한 자세 교정과 친절한 설명을 드려요.",
    "intermediate": "중급 사용자에게는 간결한 자세 교정 위주로 피드백을 드려요.",
    "advanced": "상급 사용자에게는 핵심 포인트와 미세 조정만 드려요.",
}

_MISSING_MESSAGES = {
    "missing_body_weight": (
        "체중 정보가 없어 자동 산정을 할 수 없었어요. "
        "회원 페이지에서 체중을 입력하시면 정확한 등급을 받아보실 수 있어요."
    ),
    "no_lift_inputs": (
        "3대 중량(스쿼트·벤치·데드리프트)을 한 종목도 입력하지 않으셔서 "
        "자동 산정을 할 수 없었어요. 한 종목이라도 입력하시면 등급이 결정돼요."
    ),
    "internal_error": (
        "산정 중 일시적인 문제가 발생했어요. 설정에서 다시 시도해보세요."
    ),
}


def _to_missing_reasons(codes: list[str]) -> list[MissingReason]:
    return [
        MissingReason(code=c, message=_MISSING_MESSAGES[c])
        for c in codes
        if c in _MISSING_MESSAGES
    ]


@router.post("/me/onboarding", response_model=OnboardingResponse)
def submit_onboarding(
    data: OnboardingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # 1. 입력 필드를 User에 저장
    current_user.sex = data.sex
    current_user.birth_year = data.birth_year
    current_user.training_experience = data.training_experience
    current_user.squat_1rm = data.squat_1rm
    current_user.bench_1rm = data.bench_1rm
    current_user.deadlift_1rm = data.deadlift_1rm

    # 2. 등급 산정 (체중은 기존 User.weight 사용)
    result = calculate(
        sex=data.sex,
        body_weight_kg=current_user.weight,
        squat_1rm=data.squat_1rm,
        bench_1rm=data.bench_1rm,
        deadlift_1rm=data.deadlift_1rm,
        training_experience=data.training_experience,
    )

    if isinstance(result, LevelCalculation):
        current_user.level = result.level
        current_user.level_source = "auto"
        db.commit()
        db.refresh(current_user)
        return OnboardingResponse(
            level=result.level,
            level_source="auto",
            avg_tier_score=result.avg_tier_score,
            capped_by_experience=result.capped_by_experience,
            per_lift=result.per_lift,
            feedback_style_preview=_FEEDBACK_PREVIEWS[result.level],
            changeable_in_settings=True,
            missing_reasons=[],
        )

    # 3. 산정 실패 → default 처리
    current_user.level = "beginner"
    current_user.level_source = "default"
    db.commit()
    db.refresh(current_user)
    return OnboardingResponse(
        level="beginner",
        level_source="default",
        avg_tier_score=None,
        capped_by_experience=False,
        per_lift={},
        feedback_style_preview=_FEEDBACK_PREVIEWS["beginner"],
        changeable_in_settings=True,
        missing_reasons=_to_missing_reasons(result.missing_reasons),
    )


@router.get("/me/onboarding-status", response_model=OnboardingStatusResponse)
def get_onboarding_status(current_user: User = Depends(get_current_user)):
    return OnboardingStatusResponse(
        needs_onboarding=current_user.level_source is None,
    )
```

- [ ] **Step 2: 라우터 main.py에 등록**

Edit `rexx_server/main.py` — `from routers.pose_feedback import router as pose_router, limiter` 라인 근처에 추가:
```python
from routers.onboarding import router as onboarding_router
app.include_router(onboarding_router)
```

- [ ] **Step 3: 통합 테스트 작성 — 자동 산정 성공**

Create `rexx_server/tests/test_onboarding_endpoint.py`:
```python
"""온보딩 엔드포인트 통합 테스트."""


def _register_with_weight(client, weight: float | None = 70.0) -> dict:
    body = {
        "username": "테스트유저",
        "email": "onboard@example.com",
        "password": "password123",
    }
    if weight is not None:
        body["weight"] = weight
    res = client.post("/register", json=body)
    return res.json()


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_onboarding_full_input_returns_auto_level(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])

    res = client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "birth_year": 1995,
        "training_experience": "2_5y",
        "squat_1rm": 120.0,
        "bench_1rm": 90.0,
        "deadlift_1rm": 140.0,
    })

    assert res.status_code == 200
    body = res.json()
    assert body["level"] == "intermediate"
    assert body["level_source"] == "auto"
    assert body["avg_tier_score"] is not None
    assert body["per_lift"] == {"squat": 3, "bench": 3, "deadlift": 3}
    assert body["missing_reasons"] == []
    assert body["changeable_in_settings"] is True
    assert "중급" in body["feedback_style_preview"]


def test_onboarding_unauthenticated_returns_401(client):
    res = client.post("/me/onboarding", json={})
    assert res.status_code == 401


def test_onboarding_idempotent(client):
    """같은 사용자가 두 번 호출해도 마지막 값 반영."""
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])

    client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "squat_1rm": 50.0,
        "bench_1rm": 45.0,
        "deadlift_1rm": 70.0,
    })
    res2 = client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "squat_1rm": 215.0,
        "bench_1rm": 165.0,
        "deadlift_1rm": 245.0,
        "training_experience": "5y_plus",
    })

    assert res2.status_code == 200
    assert res2.json()["level"] == "advanced"
```

- [ ] **Step 4: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_onboarding_endpoint.py -v`
Expected: 3 PASSED

- [ ] **Step 5: 커밋**

```bash
git add rexx_server/routers/onboarding.py rexx_server/tests/test_onboarding_endpoint.py rexx_server/main.py
git commit -m "feat(server): POST /me/onboarding 자동 등급 산정 라우터 (TDD)"
```

---

## Task 10: Onboarding 라우터 — 실패/검증 케이스 테스트

**Files:**
- Modify: `rexx_server/tests/test_onboarding_endpoint.py`

- [ ] **Step 1: 실패 케이스 테스트 추가**

Append to `rexx_server/tests/test_onboarding_endpoint.py`:
```python
def test_all_null_returns_default_with_two_reasons(client):
    """체중도 1RM도 없으면 두 사유 모두 반환."""
    user_data = client.post("/register", json={
        "username": "테스트",
        "email": "noweight@example.com",
        "password": "password123",
    }).json()
    headers = _auth_header(user_data["token"])

    res = client.post("/me/onboarding", headers=headers, json={})

    assert res.status_code == 200
    body = res.json()
    assert body["level"] == "beginner"
    assert body["level_source"] == "default"
    codes = {r["code"] for r in body["missing_reasons"]}
    assert codes == {"missing_body_weight", "no_lift_inputs"}


def test_missing_weight_only(client):
    user_data = client.post("/register", json={
        "username": "테스트",
        "email": "noweight2@example.com",
        "password": "password123",
    }).json()
    headers = _auth_header(user_data["token"])

    res = client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "squat_1rm": 100.0,
    })

    body = res.json()
    assert body["level_source"] == "default"
    codes = [r["code"] for r in body["missing_reasons"]]
    assert codes == ["missing_body_weight"]


def test_no_lifts_only(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])

    res = client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "training_experience": "2_5y",
    })

    body = res.json()
    assert body["level_source"] == "default"
    codes = [r["code"] for r in body["missing_reasons"]]
    assert codes == ["no_lift_inputs"]


def test_negative_1rm_returns_400(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])

    res = client.post("/me/onboarding", headers=headers, json={
        "squat_1rm": -50.0,
    })
    assert res.status_code == 422  # Pydantic validation error


def test_future_birth_year_returns_422(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])

    res = client.post("/me/onboarding", headers=headers, json={
        "birth_year": 2999,
    })
    assert res.status_code == 422


def test_onboarding_status_new_user(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])
    res = client.get("/me/onboarding-status", headers=headers)
    assert res.status_code == 200
    assert res.json()["needs_onboarding"] is True


def test_onboarding_status_after_completion(client):
    user = _register_with_weight(client, weight=70.0)
    headers = _auth_header(user["token"])
    client.post("/me/onboarding", headers=headers, json={
        "sex": "male",
        "squat_1rm": 100.0,
    })
    res = client.get("/me/onboarding-status", headers=headers)
    assert res.json()["needs_onboarding"] is False
```

- [ ] **Step 2: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_onboarding_endpoint.py -v`
Expected: 10 PASSED (기존 3 + 신규 7)

- [ ] **Step 3: 커밋**

```bash
git add rexx_server/tests/test_onboarding_endpoint.py
git commit -m "test(server): 온보딩 실패/검증 케이스 통합 테스트"
```

---

## Task 11: PUT /me/level에 level_source="manual" 갱신 추가

**Files:**
- Modify: `rexx_server/main.py:193-202`

- [ ] **Step 1: 기존 코드 확인**

Run: `cd rexx_server && grep -n -A 10 "def update_level" main.py`
Expected: 라인 193 근처 함수 본문 표시

- [ ] **Step 2: 함수 수정**

Edit `rexx_server/main.py` — `update_level` 함수 본문을 다음으로 교체:
```python
@app.put("/me/level")
def update_level(
    data: UpdateLevelRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.level = data.level.value
    current_user.level_source = "manual"
    db.commit()
    db.refresh(current_user)
    return {"success": True, "level": current_user.level, "level_source": current_user.level_source}
```

- [ ] **Step 3: 기존 등급 변경 테스트가 있는지 확인**

Run: `cd rexx_server && grep -rn "me/level" tests/`
Expected: `test_user_level.py`에 관련 테스트 있음

- [ ] **Step 4: 새 검증 테스트 추가**

Append to `rexx_server/tests/test_user_level.py`:
```python
def test_put_level_sets_source_manual(client):
    user = client.post("/register", json={
        "username": "수동변경",
        "email": "manual@example.com",
        "password": "password123",
    }).json()
    headers = {"Authorization": f"Bearer {user['token']}"}

    res = client.put("/me/level", headers=headers, json={"level": "advanced"})
    assert res.status_code == 200
    body = res.json()
    assert body["level"] == "advanced"
    assert body["level_source"] == "manual"
```

- [ ] **Step 5: 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/test_user_level.py -v`
Expected: 모두 PASSED (기존 + 신규)

- [ ] **Step 6: 전체 백엔드 테스트 실행**

Run: `cd rexx_server && python -m pytest tests/ -v`
Expected: ALL PASSED

- [ ] **Step 7: 커밋**

```bash
git add rexx_server/main.py rexx_server/tests/test_user_level.py
git commit -m "feat(server): PUT /me/level 호출 시 level_source=manual 자동 갱신"
```

---

# PHASE 2: FRONTEND

## Task 12: AuthService에 온보딩 메서드 3개 추가

**Files:**
- Modify: `rexx_app/lib/services/auth_service.dart`

- [ ] **Step 1: 메서드 추가**

Edit `rexx_app/lib/services/auth_service.dart` — `_extractErrorDetail` 메서드 직전(클래스 닫기 전)에 추가:
```dart
  /// 온보딩 필요 여부 조회.
  Future<bool> getOnboardingStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/me/onboarding-status"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body["needs_onboarding"] == true;
      }
      // 실패 시 조용히 false (다음 부팅에 재시도)
      return false;
    } catch (e) {
      debugPrint('[AuthService] onboarding-status 조회 실패: $e');
      return false;
    }
  }

  /// 온보딩 데이터 제출 + 자동 등급 산정 결과 반환.
  Future<Map<String, dynamic>> submitOnboarding({
    required String token,
    String? sex,
    int? birthYear,
    String? trainingExperience,
    double? squat1rm,
    double? bench1rm,
    double? deadlift1rm,
  }) async {
    final body = <String, dynamic>{};
    if (sex != null) body["sex"] = sex;
    if (birthYear != null) body["birth_year"] = birthYear;
    if (trainingExperience != null) body["training_experience"] = trainingExperience;
    if (squat1rm != null) body["squat_1rm"] = squat1rm;
    if (bench1rm != null) body["bench_1rm"] = bench1rm;
    if (deadlift1rm != null) body["deadlift_1rm"] = deadlift1rm;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/me/onboarding"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_extractErrorDetail(response.body, '온보딩 저장 실패'));
    } on SocketException {
      throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
    }
  }

  /// 등급 수동 변경.
  Future<Map<String, dynamic>> updateLevel({
    required String token,
    required String level,
  }) async {
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/me/level"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"level": level}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_extractErrorDetail(response.body, '등급 변경 실패'));
    } on SocketException {
      throw Exception("서버에 연결할 수 없습니다.");
    }
  }
```

- [ ] **Step 2: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/services/auth_service.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add rexx_app/lib/services/auth_service.dart
git commit -m "feat(app): AuthService에 온보딩 관련 메서드 3개 추가"
```

---

## Task 13: Onboarding 상태 모델 + Flow 컨테이너 스캐폴드

**Files:**
- Create: `rexx_app/lib/features/onboarding/models/onboarding_state.dart`
- Create: `rexx_app/lib/features/onboarding/onboarding_flow.dart`

- [ ] **Step 1: 상태 모델 작성**

Create `rexx_app/lib/features/onboarding/models/onboarding_state.dart`:
```dart
/// 온보딩 입력 상태 + 응답 모델.

enum OnboardingExperience {
  lt6m('lt_6m', '6개월 이하'),
  m6to2y('6m_2y', '6개월 ~ 2년'),
  y2to5('2_5y', '2년 ~ 5년'),
  y5plus('5y_plus', '5년 이상');

  final String code;
  final String label;
  const OnboardingExperience(this.code, this.label);
}

enum OnboardingSex {
  male('male', '남성'),
  female('female', '여성');

  final String code;
  final String label;
  const OnboardingSex(this.code, this.label);
}

class OnboardingInput {
  OnboardingSex? sex;
  int? birthYear;
  OnboardingExperience? experience;
  double? squat1rm;
  double? bench1rm;
  double? deadlift1rm;
  bool squatUnknown = false;
  bool benchUnknown = false;
  bool deadliftUnknown = false;
}

class MissingReasonItem {
  final String code;
  final String message;
  MissingReasonItem({required this.code, required this.message});

  factory MissingReasonItem.fromJson(Map<String, dynamic> json) =>
      MissingReasonItem(
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

class OnboardingResult {
  final String level; // beginner | intermediate | advanced
  final String levelSource; // auto | manual | default
  final double? avgTierScore;
  final bool cappedByExperience;
  final String feedbackStylePreview;
  final List<MissingReasonItem> missingReasons;

  OnboardingResult({
    required this.level,
    required this.levelSource,
    required this.avgTierScore,
    required this.cappedByExperience,
    required this.feedbackStylePreview,
    required this.missingReasons,
  });

  factory OnboardingResult.fromJson(Map<String, dynamic> json) {
    return OnboardingResult(
      level: json['level'] as String,
      levelSource: json['level_source'] as String,
      avgTierScore: (json['avg_tier_score'] as num?)?.toDouble(),
      cappedByExperience: json['capped_by_experience'] as bool? ?? false,
      feedbackStylePreview: json['feedback_style_preview'] as String,
      missingReasons: ((json['missing_reasons'] as List?) ?? [])
          .map((e) => MissingReasonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get levelKorean => switch (level) {
        'beginner' => '초급',
        'intermediate' => '중급',
        'advanced' => '상급',
        _ => level,
      };

  String get levelEmoji => switch (level) {
        'beginner' => '🥉',
        'intermediate' => '🥈',
        'advanced' => '🥇',
        _ => '',
      };
}
```

- [ ] **Step 2: Flow 컨테이너 스캐폴드 작성**

Create `rexx_app/lib/features/onboarding/onboarding_flow.dart`:
```dart
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'models/onboarding_state.dart';
import 'steps/welcome_step.dart';
import 'steps/body_info_step.dart';
import 'steps/experience_step.dart';
import 'steps/lift_input_step.dart';
import 'steps/result_step.dart';

/// 5단계 온보딩 PageView.
/// Welcome → Body → Experience → Lifts → Result
class OnboardingFlow extends StatefulWidget {
  final String token;
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.token,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _input = OnboardingInput();
  bool _explicitSkip = false;
  OnboardingResult? _result;
  bool _submitting = false;

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit({required bool explicitSkip}) async {
    setState(() {
      _submitting = true;
      _explicitSkip = explicitSkip;
    });
    try {
      final json = await AuthService().submitOnboarding(
        token: widget.token,
        sex: _input.sex?.code,
        birthYear: _input.birthYear,
        trainingExperience: _input.experience?.code,
        squat1rm: _input.squatUnknown ? null : _input.squat1rm,
        bench1rm: _input.benchUnknown ? null : _input.bench1rm,
        deadlift1rm: _input.deadliftUnknown ? null : _input.deadlift1rm,
      );
      setState(() {
        _result = OnboardingResult.fromJson(json);
        _submitting = false;
      });
      _goToPage(4);
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('지금은 저장할 수 없어요. 나중에 설정에서 입력할 수 있어요. ($e)')),
        );
        widget.onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0C),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            WelcomeStep(
              onStart: () => _goToPage(1),
              onSkip: () => _submit(explicitSkip: true),
            ),
            BodyInfoStep(
              input: _input,
              onNext: () => _goToPage(2),
              onSkip: () => _goToPage(2),
            ),
            ExperienceStep(
              input: _input,
              onNext: () => _goToPage(3),
              onSkip: () => _goToPage(3),
            ),
            LiftInputStep(
              input: _input,
              submitting: _submitting,
              onComplete: () => _submit(explicitSkip: false),
            ),
            if (_result != null)
              ResultStep(
                result: _result!,
                explicitSkip: _explicitSkip,
                onConfirm: widget.onComplete,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 빈 step 파일들 placeholder 생성** (다음 task에서 채울 예정)

Create `rexx_app/lib/features/onboarding/steps/welcome_step.dart`:
```dart
import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;
  const WelcomeStep({super.key, required this.onStart, required this.onSkip});

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Create `rexx_app/lib/features/onboarding/steps/body_info_step.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class BodyInfoStep extends StatelessWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const BodyInfoStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Create `rexx_app/lib/features/onboarding/steps/experience_step.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ExperienceStep extends StatelessWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const ExperienceStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Create `rexx_app/lib/features/onboarding/steps/lift_input_step.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class LiftInputStep extends StatelessWidget {
  final OnboardingInput input;
  final bool submitting;
  final VoidCallback onComplete;
  const LiftInputStep({
    super.key,
    required this.input,
    required this.submitting,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Create `rexx_app/lib/features/onboarding/steps/result_step.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ResultStep extends StatelessWidget {
  final OnboardingResult result;
  final bool explicitSkip;
  final VoidCallback onConfirm;
  const ResultStep({
    super.key,
    required this.result,
    required this.explicitSkip,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

- [ ] **Step 4: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/features/onboarding/`
Expected: No issues found (placeholder들이라 경고 없음)

- [ ] **Step 5: 커밋**

```bash
git add rexx_app/lib/features/onboarding/
git commit -m "feat(app): 온보딩 모델 + Flow 컨테이너 + step placeholder"
```

---

## Task 14: Step 1 (Welcome) + Step 2 (Body Info) 구현

**Files:**
- Modify: `rexx_app/lib/features/onboarding/steps/welcome_step.dart`
- Modify: `rexx_app/lib/features/onboarding/steps/body_info_step.dart`

- [ ] **Step 1: WelcomeStep 작성**

Replace `rexx_app/lib/features/onboarding/steps/welcome_step.dart` with:
```dart
import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;
  const WelcomeStep({super.key, required this.onStart, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          const Text(
            '더 정확한 코칭을 위해\n몇 가지만 알려주세요',
            style: TextStyle(
              color: Color(0xFFE9F5EF),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _bullet('약 30초 소요'),
          _bullet('언제든 설정에서 변경 가능'),
          _bullet('모두 선택 입력'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('시작하기', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: const Text(
                '나중에 (초급자로 설정)',
                style: TextStyle(color: Color(0xFFA7B9B0)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Text('• ', style: TextStyle(color: Color(0xFF16A34A), fontSize: 18)),
            Text(text, style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 15)),
          ],
        ),
      );
}
```

- [ ] **Step 2: BodyInfoStep 작성**

Replace `rexx_app/lib/features/onboarding/steps/body_info_step.dart` with:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class BodyInfoStep extends StatefulWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const BodyInfoStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<BodyInfoStep> createState() => _BodyInfoStepState();
}

class _BodyInfoStepState extends State<BodyInfoStep> {
  final _yearCtrl = TextEditingController();

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('신체 정보',
              style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('성별', style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 8),
          _SexRadio(
            value: widget.input.sex,
            onChanged: (v) => setState(() => widget.input.sex = v),
          ),
          const SizedBox(height: 24),
          const Text('출생연도 (선택)', style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFFE9F5EF)),
            decoration: const InputDecoration(
              hintText: '예: 1995',
              hintStyle: TextStyle(color: Color(0xFF4A5651)),
              filled: true,
              fillColor: Color(0xFF0F1612),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              widget.input.birthYear = int.tryParse(v);
            },
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('건너뛰기', style: TextStyle(color: Color(0xFFA7B9B0))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SexRadio extends StatelessWidget {
  final OnboardingSex? value;
  final ValueChanged<OnboardingSex?> onChanged;
  const _SexRadio({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final option in [...OnboardingSex.values, null])
          ChoiceChip(
            label: Text(option?.label ?? '선택안함'),
            selected: value == option,
            onSelected: (_) => onChanged(option),
            selectedColor: const Color(0xFF16A34A),
            backgroundColor: const Color(0xFF0F1612),
            labelStyle: TextStyle(
              color: value == option ? Colors.white : const Color(0xFFA7B9B0),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/features/onboarding/steps/welcome_step.dart lib/features/onboarding/steps/body_info_step.dart`
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/onboarding/steps/welcome_step.dart rexx_app/lib/features/onboarding/steps/body_info_step.dart
git commit -m "feat(app): 온보딩 Step 1 (Welcome) + Step 2 (Body Info) 구현"
```

---

## Task 15: Step 3 (Experience) + Step 4 (Lift Input) 구현

**Files:**
- Modify: `rexx_app/lib/features/onboarding/steps/experience_step.dart`
- Modify: `rexx_app/lib/features/onboarding/steps/lift_input_step.dart`

- [ ] **Step 1: ExperienceStep 작성**

Replace `rexx_app/lib/features/onboarding/steps/experience_step.dart` with:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class ExperienceStep extends StatefulWidget {
  final OnboardingInput input;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const ExperienceStep({
    super.key,
    required this.input,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<ExperienceStep> createState() => _ExperienceStepState();
}

class _ExperienceStepState extends State<ExperienceStep> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('운동 경력',
              style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('웨이트 트레이닝을 얼마나 해오셨나요?',
              style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
          const SizedBox(height: 24),
          for (final exp in OnboardingExperience.values)
            _ExperienceTile(
              experience: exp,
              selected: widget.input.experience == exp,
              onTap: () => setState(() => widget.input.experience = exp),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('건너뛰기', style: TextStyle(color: Color(0xFFA7B9B0))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExperienceTile extends StatelessWidget {
  final OnboardingExperience experience;
  final bool selected;
  final VoidCallback onTap;
  const _ExperienceTile({
    required this.experience,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFF0F1612),
            border: Border.all(
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF1F2925),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? Colors.white : const Color(0xFFA7B9B0),
              ),
              const SizedBox(width: 12),
              Text(
                experience.label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFE9F5EF),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: LiftInputStep 작성**

Replace `rexx_app/lib/features/onboarding/steps/lift_input_step.dart` with:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class LiftInputStep extends StatefulWidget {
  final OnboardingInput input;
  final bool submitting;
  final VoidCallback onComplete;
  const LiftInputStep({
    super.key,
    required this.input,
    required this.submitting,
    required this.onComplete,
  });

  @override
  State<LiftInputStep> createState() => _LiftInputStepState();
}

class _LiftInputStepState extends State<LiftInputStep> {
  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _deadCtrl = TextEditingController();

  @override
  void dispose() {
    _squatCtrl.dispose();
    _benchCtrl.dispose();
    _deadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text('3대 중량',
                style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('현재 기준 1RM(1회 최대 중량)을 입력해주세요. 모르면 체크박스를 누르세요.',
                style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
            const SizedBox(height: 24),
            _LiftField(
              label: '스쿼트',
              controller: _squatCtrl,
              unknown: widget.input.squatUnknown,
              onValueChanged: (v) => widget.input.squat1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.squatUnknown = v),
            ),
            const SizedBox(height: 16),
            _LiftField(
              label: '벤치프레스',
              controller: _benchCtrl,
              unknown: widget.input.benchUnknown,
              onValueChanged: (v) => widget.input.bench1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.benchUnknown = v),
            ),
            const SizedBox(height: 16),
            _LiftField(
              label: '데드리프트',
              controller: _deadCtrl,
              unknown: widget.input.deadliftUnknown,
              onValueChanged: (v) => widget.input.deadlift1rm = v,
              onUnknownChanged: (v) => setState(() => widget.input.deadliftUnknown = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.submitting ? null : widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: widget.submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('완료', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LiftField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool unknown;
  final ValueChanged<double?> onValueChanged;
  final ValueChanged<bool> onUnknownChanged;

  const _LiftField({
    required this.label,
    required this.controller,
    required this.unknown,
    required this.onValueChanged,
    required this.onUnknownChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 14)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !unknown,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Color(0xFFE9F5EF)),
                decoration: InputDecoration(
                  hintText: 'kg',
                  hintStyle: const TextStyle(color: Color(0xFF4A5651)),
                  filled: true,
                  fillColor: unknown ? const Color(0xFF1A1F1C) : const Color(0xFF0F1612),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => onValueChanged(double.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Checkbox(
                  value: unknown,
                  onChanged: (v) => onUnknownChanged(v ?? false),
                  activeColor: const Color(0xFF16A34A),
                ),
                const Text('모름', style: TextStyle(color: Color(0xFFA7B9B0))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/features/onboarding/steps/experience_step.dart lib/features/onboarding/steps/lift_input_step.dart`
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/onboarding/steps/experience_step.dart rexx_app/lib/features/onboarding/steps/lift_input_step.dart
git commit -m "feat(app): 온보딩 Step 3 (Experience) + Step 4 (Lift Input) 구현"
```

---

## Task 16: Step 5 결과 화면 (5-A 자동 산정 / 5-B default fallback)

**Files:**
- Modify: `rexx_app/lib/features/onboarding/steps/result_step.dart`

- [ ] **Step 1: ResultStep 작성**

Replace `rexx_app/lib/features/onboarding/steps/result_step.dart` with:
```dart
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

/// Step 5. level_source가 'auto'이면 5-A, 'default'이면 5-B 표시.
class ResultStep extends StatelessWidget {
  final OnboardingResult result;
  final bool explicitSkip;
  final VoidCallback onConfirm;

  const ResultStep({
    super.key,
    required this.result,
    required this.explicitSkip,
    required this.onConfirm,
  });

  bool get _isDefault => result.levelSource == 'default';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            _isDefault ? '회원님은 일단' : '회원님의 코칭 등급은',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            '${result.levelEmoji} ${result.levelKorean}${_isDefault ? '으로' : ''}',
            style: const TextStyle(
              color: Color(0xFFE9F5EF),
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isDefault) ...[
            const SizedBox(height: 8),
            const Text('시작할게요',
                style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 16)),
          ],
          const SizedBox(height: 12),
          Text(
            _isDefault ? '' : '자동 산정됨',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
          ),
          const SizedBox(height: 32),
          if (_isDefault) _buildMissingReasons(),
          const SizedBox(height: 24),
          _buildFeedbackPreview(),
          const SizedBox(height: 24),
          _buildSettingsHint(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMissingReasons() {
    final children = <Widget>[];
    children.add(const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'ℹ️ 자동 산정을 못 한 이유:',
        style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
      ),
    ));

    if (explicitSkip) {
      children.add(_bullet('직접 건너뛰기를 선택하셨어요.'));
    } else {
      for (final reason in result.missingReasons) {
        children.add(_bullet(reason.message));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Color(0xFF16A34A))),
            Expanded(
              child: Text(text, style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 13, height: 1.5)),
            ),
          ],
        ),
      );

  Widget _buildFeedbackPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝 ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              result.feedbackStylePreview,
              style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('⚙️ ', style: TextStyle(fontSize: 14)),
        Text(
          '언제든지 설정에서 변경할 수 있어요',
          style: TextStyle(color: Color(0xFFA7B9B0), fontSize: 13),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/features/onboarding/`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add rexx_app/lib/features/onboarding/steps/result_step.dart
git commit -m "feat(app): 온보딩 Step 5 결과 화면 (5-A 자동 / 5-B default 분기)"
```

---

## Task 17: ResultStep 위젯 테스트 (5-A / 5-B 분기 검증)

**Files:**
- Create: `rexx_app/test/features/onboarding/result_step_test.dart`

- [ ] **Step 1: 테스트 작성**

Create `rexx_app/test/features/onboarding/result_step_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rexx_app/features/onboarding/models/onboarding_state.dart';
import 'package:rexx_app/features/onboarding/steps/result_step.dart';

void main() {
  Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('5-A: 자동 산정 결과는 등급 + 피드백 미리보기 표시', (tester) async {
    final result = OnboardingResult(
      level: 'intermediate',
      levelSource: 'auto',
      avgTierScore: 2.3,
      cappedByExperience: false,
      feedbackStylePreview: '중급 사용자에게는 간결한 자세 교정 위주로 피드백을 드려요.',
      missingReasons: [],
    );

    await tester.pumpWidget(_wrap(ResultStep(
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

    await tester.pumpWidget(_wrap(ResultStep(
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

    await tester.pumpWidget(_wrap(ResultStep(
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

    await tester.pumpWidget(_wrap(ResultStep(
      result: result,
      explicitSkip: false,
      onConfirm: () => confirmed = true,
    )));

    await tester.tap(find.text('확인'));
    expect(confirmed, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행**

Run: `cd rexx_app && flutter test test/features/onboarding/result_step_test.dart`
Expected: 4 tests PASSED

- [ ] **Step 3: 커밋**

```bash
git add rexx_app/test/features/onboarding/result_step_test.dart
git commit -m "test(app): ResultStep 5-A/5-B 분기 위젯 테스트"
```

---

## Task 18: HomeScreen 부팅 시 onboarding 라우팅

**Files:**
- Modify: `rexx_app/lib/pages/home_screen.dart`

- [ ] **Step 1: 기존 home_screen.dart 구조 파악**

Run: `cd rexx_app && head -80 lib/pages/home_screen.dart`
Expected: build() / 인증 토큰 처리 위치 확인

- [ ] **Step 2: 토큰이 있는 경우 부팅 시 onboarding-status 호출 추가**

Edit `rexx_app/lib/pages/home_screen.dart` — `_HomeScreenState` (또는 동등 클래스)의 `initState` 메서드에 다음 로직 추가:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartOnboarding());
}

Future<void> _maybeStartOnboarding() async {
  // SharedPreferences 등에서 토큰 가져오기 (기존 패턴 따라)
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (token == null || !mounted) return;

  final needs = await AuthService().getOnboardingStatus(token);
  if (!needs || !mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OnboardingFlow(
      token: token,
      onComplete: () => Navigator.of(context).pop(),
    ),
  ));
}
```

> 참고: `home_screen.dart`의 기존 토큰 조회 패턴을 그대로 따르고, `import 'package:shared_preferences/shared_preferences.dart';` 및 `import '../features/onboarding/onboarding_flow.dart';`, `import '../services/auth_service.dart';`를 상단에 추가.

- [ ] **Step 3: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/pages/home_screen.dart`
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/pages/home_screen.dart
git commit -m "feat(app): 홈 화면 부팅 시 온보딩 필요 여부 체크 + 라우팅"
```

---

## Task 19: Member 페이지 인라인 등급 설정 섹션

**Files:**
- Modify: `rexx_app/lib/pages/member.dart`

- [ ] **Step 1: 기존 member.dart 구조 파악**

Run: `cd rexx_app && head -60 lib/pages/member.dart`
Expected: 회원 페이지 빌드 메서드 확인

- [ ] **Step 2: 등급 설정 섹션 위젯 추가**

Edit `rexx_app/lib/pages/member.dart` — 회원 페이지 build()의 적절한 위치에 다음 위젯 호출 삽입 (기존 섹션들 사이):
```dart
LevelSettingsSection(
  currentLevel: _user?['level'] ?? 'beginner',
  currentLevelSource: _user?['level_source'] ?? 'default',
  token: _token ?? '',
  onLevelChanged: (newLevel) {
    setState(() {
      _user!['level'] = newLevel;
      _user!['level_source'] = 'manual';
    });
  },
  onReonboard: () {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingFlow(
        token: _token ?? '',
        onComplete: () {
          Navigator.of(context).pop();
          _refreshUser();  // 기존 사용자 정보 갱신 메서드
        },
      ),
    ));
  },
),
```

- [ ] **Step 3: LevelSettingsSection 위젯 정의**

Edit `rexx_app/lib/pages/member.dart` — 파일 하단에 다음 위젯 클래스 추가:
```dart
class LevelSettingsSection extends StatefulWidget {
  final String currentLevel;
  final String currentLevelSource;
  final String token;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onReonboard;

  const LevelSettingsSection({
    super.key,
    required this.currentLevel,
    required this.currentLevelSource,
    required this.token,
    required this.onLevelChanged,
    required this.onReonboard,
  });

  @override
  State<LevelSettingsSection> createState() => _LevelSettingsSectionState();
}

class _LevelSettingsSectionState extends State<LevelSettingsSection> {
  late String _selected = widget.currentLevel;
  bool _saving = false;

  static const _options = [
    ('beginner', '초급', '매우 상세한 피드백'),
    ('intermediate', '중급', '간결한 자세 교정'),
    ('advanced', '상급', '핵심 위주, 미세 조정만'),
  ];

  static const _sourceLabel = {
    'auto': '자동 산정',
    'manual': '직접 설정',
    'default': '기본값',
  };

  String _emoji(String level) => switch (level) {
        'beginner' => '🥉',
        'intermediate' => '🥈',
        'advanced' => '🥇',
        _ => '',
      };

  Future<void> _changeLevel(String newLevel) async {
    if (newLevel == _selected || _saving) return;
    final previous = _selected;
    setState(() {
      _selected = newLevel;
      _saving = true;
    });
    try {
      await AuthService().updateLevel(token: widget.token, level: newLevel);
      widget.onLevelChanged(newLevel);
    } catch (e) {
      setState(() => _selected = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등급 변경 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('코칭 등급',
                  style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '${_emoji(_selected)} ${_options.firstWhere((o) => o.$1 == _selected).$2}',
                style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '현재: ${_sourceLabel[widget.currentLevelSource] ?? widget.currentLevelSource}',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 12),
          ),
          const Divider(color: Color(0xFF1F2925), height: 24),
          for (final opt in _options)
            RadioListTile<String>(
              value: opt.$1,
              groupValue: _selected,
              onChanged: _saving ? null : (v) { if (v != null) _changeLevel(v); },
              title: Text('${opt.$2} — ${opt.$3}',
                  style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 14)),
              activeColor: const Color(0xFF16A34A),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onReonboard,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF16A34A)),
            ),
            child: const Text('신체정보·1RM 다시 입력하기 →',
                style: TextStyle(color: Color(0xFF16A34A))),
          ),
        ],
      ),
    );
  }
}
```

상단에 import 추가:
```dart
import '../services/auth_service.dart';
import '../features/onboarding/onboarding_flow.dart';
```

- [ ] **Step 4: 컴파일 검증**

Run: `cd rexx_app && flutter analyze lib/pages/member.dart`
Expected: No issues found

- [ ] **Step 5: 커밋**

```bash
git add rexx_app/lib/pages/member.dart
git commit -m "feat(app): Member 페이지에 코칭 등급 설정 인라인 섹션 추가"
```

---

## Task 20: 전체 통합 검증 + 정리

**Files:** (없음 — 검증만)

- [ ] **Step 1: 백엔드 전체 테스트**

Run: `cd rexx_server && python -m pytest tests/ -v`
Expected: ALL PASSED (level_calculator 24 + onboarding_endpoint 10 + user_migration 2 + 기존 테스트)

- [ ] **Step 2: Flutter 정적 분석**

Run: `cd rexx_app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Flutter 테스트 실행**

Run: `cd rexx_app && flutter test`
Expected: ALL PASSED (result_step_test 4 + 기존 테스트)

- [ ] **Step 4: 백엔드 부팅 smoke test**

Run: `cd rexx_server && python -c "from main import app; print(len(app.routes), 'routes')"`
Expected: 라우트 개수 출력 (이전 대비 +2 = onboarding 라우터)

- [ ] **Step 5: 라우트 등록 확인**

Run: `cd rexx_server && python -c "from main import app; print([r.path for r in app.routes if 'onboarding' in r.path])"`
Expected: `['/me/onboarding', '/me/onboarding-status']`

- [ ] **Step 6: 최종 커밋 (필요시) + 작업 완료**

작업 중 누락된 변경이 있다면:
```bash
git status
git add ...
git commit -m "chore: 온보딩 시스템 통합 검증 후 보정"
```

없으면 다음으로 넘어감.

---

## 검증 체크리스트 (최종)

- [ ] 백엔드 테스트 36개+ ALL PASS
- [ ] Flutter analyze 0 issues
- [ ] Flutter test ALL PASS
- [ ] `/me/onboarding`, `/me/onboarding-status` 라우트 등록 확인
- [ ] User 모델에 컬럼 7개 추가됨 (sex, birth_year, training_experience, squat_1rm, bench_1rm, deadlift_1rm, level_source)
- [ ] 자가 마이그레이션이 startup hook에서 호출됨
- [ ] PUT /me/level 호출 시 level_source="manual" 자동 설정
- [ ] 회원가입 → 로그인 → 자동으로 온보딩 화면 진입 가능 (수동 스모크 테스트)
- [ ] 온보딩 스킵 → default fallback + 사유 메시지 표시
- [ ] 자동 산정 성공 → 5-A 화면 + 등급 표시
- [ ] Member 페이지에서 등급 라디오 변경 가능
- [ ] "신체정보·1RM 다시 입력하기" 버튼이 온보딩 재실행
