"""level_calculator 유닛 테스트."""
from services.level_calculator import score_single_lift


def test_score_below_beginner_returns_0():
    # 70kg 남성 스쿼트 컷오프: [45, 80, 120, 165, 215]
    # 30kg 들면 Beginner(45) 미만 → 0
    assert score_single_lift("male", 70.0, "squat", 30.0) == 0


def test_score_at_beginner_returns_1():
    # 정확히 Beginner 컷오프 → 1 (B tier 진입)
    assert score_single_lift("male", 70.0, "squat", 45.0) == 1


def test_score_at_intermediate_returns_3():
    # 정확히 Intermediate 컷오프 → 3 (I tier 진입, Task 5 경계 테스트와 정합)
    assert score_single_lift("male", 70.0, "squat", 120.0) == 3


def test_score_at_elite_returns_4():
    assert score_single_lift("male", 70.0, "squat", 215.0) == 4


def test_score_above_elite_clamped_to_4():
    assert score_single_lift("male", 70.0, "squat", 300.0) == 4
