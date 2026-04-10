"""Startup 자가 마이그레이션.

신규 컬럼을 ALTER TABLE로 추가. PostgreSQL은 IF NOT EXISTS 사용,
SQLite는 try/except로 중복 추가 시도를 무시.
컬럼이 모두 nullable이라 롤백 불필요.
"""
from sqlalchemy.engine import Engine

# (컬럼명, 타입) — auth.py의 User 모델과 동기화 필요
ONBOARDING_COLUMNS: list[tuple[str, str]] = [
    ("sex", "VARCHAR(10)"),
    ("birth_year", "INTEGER"),
    ("training_experience", "VARCHAR(20)"),
    ("squat_1rm", "FLOAT"),
    ("bench_1rm", "FLOAT"),
    ("deadlift_1rm", "FLOAT"),
    ("level_source", "VARCHAR(20)"),
]


def ensure_onboarding_columns(engine: Engine) -> None:
    """users 테이블에 온보딩용 컬럼 7개를 멱등하게 추가."""
    dialect = engine.dialect.name
    for name, type_ in ONBOARDING_COLUMNS:
        try:
            with engine.begin() as conn:
                if dialect == "postgresql":
                    sql = f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {name} {type_}"
                else:
                    sql = f"ALTER TABLE users ADD COLUMN {name} {type_}"
                conn.exec_driver_sql(sql)
                print(f"[migration] users.{name} 컬럼 추가됨")
        except Exception as e:
            # 이미 존재하는 컬럼이면 무시 (SQLite duplicate column 등)
            msg = str(e).lower()
            if "duplicate" in msg or "already exists" in msg:
                continue
            print(f"[migration] users.{name} 추가 스킵: {e}")
