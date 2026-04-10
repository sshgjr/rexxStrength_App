"""level_calculator 유닛 테스트."""
from services.level_calculator import score_single_lift
from services.level_calculator import (
    calculate,
    LevelCalculation,
    LevelCalculationFailure,
)


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
    """avg=1.67 → 초급."""
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
