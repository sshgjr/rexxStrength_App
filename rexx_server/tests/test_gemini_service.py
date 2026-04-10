import json
from unittest.mock import patch
from services.gemini_service import generate_feedback, _fallback_feedback

# 새 응답 구조: summary, reason, action, cue (4섹션)
_NEW_KEYS = {"summary", "reason", "action", "cue"}


def test_fallback_returns_four_sections():
    """폴백 피드백이 summary/reason/action/cue 4섹션을 포함."""
    result = _fallback_feedback(
        "squat", 60,
        [{"name": "척추 각도", "score": 30, "grade": "bad", "detail": "요추 과굴곡"}],
    )
    data = json.loads(result)
    assert _NEW_KEYS <= set(data.keys()), f"누락된 키: {_NEW_KEYS - set(data.keys())}"


def test_fallback_empty_criteria():
    """criteria 빈 리스트일 때도 4섹션 반환."""
    result = _fallback_feedback("squat", 90, [])
    data = json.loads(result)
    assert _NEW_KEYS <= set(data.keys())


def test_generate_feedback_with_layers():
    """레이어 정보가 포함된 호출이 에러 없이 동작 (API 키 없으면 폴백)."""
    result = generate_feedback(
        exercise_type="squat",
        total_score=60,
        criteria_scores=[{"name": "척추 각도", "score": 30, "grade": "bad", "detail": "요추 과굴곡"}],
        detected_issues=["척추 각도: 개선 필요"],
        user_level="beginner",
        layer1_issues=[{"criterion": "척추 각도", "score": 30, "grade": "bad", "reason": "요추 과굴곡"}],
        layer2_issues=[],
    )
    data = json.loads(result)
    assert _NEW_KEYS <= set(data.keys())
