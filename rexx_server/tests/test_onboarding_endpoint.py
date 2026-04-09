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
