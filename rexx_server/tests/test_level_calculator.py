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
