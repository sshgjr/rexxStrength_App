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
