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
    컷오프 [B, N, I, A, E]를 비교하여 1RM이 컷오프 이상이면 1씩 가산.
    Elite 이상(>= E)은 5 → 최대 4로 clamp.
    """
    cutoffs = _get_cutoffs(sex, lift, body_weight_kg)
    score = 0
    for cutoff in cutoffs:
        if one_rm_kg >= cutoff:
            score += 1
    # score는 0~5 범위 → 0~4로 clamp (Elite 이상은 4)
    return min(score, 4)


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
