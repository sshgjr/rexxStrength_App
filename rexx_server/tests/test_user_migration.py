"""ensure_onboarding_columns 동작 검증."""
from sqlalchemy import create_engine, inspect
from sqlalchemy.pool import StaticPool

from database import Base
from migrations import ensure_onboarding_columns, ONBOARDING_COLUMNS
# auth import는 User 모델을 등록하기 위해 필요
import auth  # noqa: F401


def _make_engine():
    return create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )


def test_columns_added_to_fresh_table():
    engine = _make_engine()
    Base.metadata.create_all(bind=engine)
    ensure_onboarding_columns(engine)

    inspector = inspect(engine)
    cols = {c["name"] for c in inspector.get_columns("users")}
    for name, _ in ONBOARDING_COLUMNS:
        assert name in cols, f"users.{name} 추가 실패"


def test_running_twice_is_idempotent():
    engine = _make_engine()
    Base.metadata.create_all(bind=engine)
    ensure_onboarding_columns(engine)
    # 두 번째 호출이 예외를 발생시키지 않아야 함
    ensure_onboarding_columns(engine)

    inspector = inspect(engine)
    cols = {c["name"] for c in inspector.get_columns("users")}
    for name, _ in ONBOARDING_COLUMNS:
        assert name in cols
