def test_default_level_is_beginner(client, registered_user):
    """신규 사용자의 기본 등급은 beginner."""
    token = registered_user["token"]
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.json()["user"]["level"] == "beginner"


def test_update_level(client, registered_user):
    """등급 변경 API 정상 동작."""
    token = registered_user["token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.put("/me/level", json={"level": "intermediate"}, headers=headers)
    assert res.status_code == 200
    assert res.json()["level"] == "intermediate"

    # 변경 확인
    me = client.get("/me", headers=headers)
    assert me.json()["user"]["level"] == "intermediate"


def test_update_level_invalid(client, registered_user):
    """잘못된 등급값은 422 반환."""
    token = registered_user["token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.put("/me/level", json={"level": "grandmaster"}, headers=headers)
    assert res.status_code == 422


def test_update_level_requires_auth(client):
    """비인증 요청은 401 반환."""
    res = client.put("/me/level", json={"level": "intermediate"})
    assert res.status_code == 401
