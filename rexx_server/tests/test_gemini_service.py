import json
from unittest.mock import patch
from services.gemini_service import generate_feedback, _fallback_feedback


def test_fallback_returns_three_fields():
    """폴백 피드백이 feedback/keypoint/cause 3종 필드를 포함."""
    result = _fallback_feedback("squat", 60, ["척추 각도: 개선 필요 (30점)"])
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data
    assert "cause" in data


def test_fallback_empty_issues():
    """이슈 없을 때 폴백 피드백."""
    result = _fallback_feedback("squat", 90, [])
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data


def test_generate_feedback_with_layers():
    """레이어 정보가 포함된 호출이 에러 없이 동작 (API 키 없으면 폴백)."""
    result = generate_feedback(
        exercise_type="squat",
        total_score=60,
        criteria_scores=[{"name": "척추 각도", "score": 30, "grade": "bad"}],
        detected_issues=["척추 각도: 개선 필요"],
        user_level="beginner",
        layer1_issues=[{"criterion": "척추 각도", "score": 30, "grade": "bad", "reason": "요추 과굴곡"}],
        layer2_issues=[],
    )
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data
    assert "cause" in data
