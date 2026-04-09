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
