"""온보딩 요청/응답 Pydantic 모델."""
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


SexLiteral = Literal["male", "female"]
ExperienceLiteral = Literal["lt_6m", "6m_2y", "2_5y", "5y_plus"]
LevelLiteral = Literal["beginner", "intermediate", "advanced"]
LevelSourceLiteral = Literal["auto", "manual", "default"]
MissingReasonCode = Literal[
    "missing_body_weight",
    "no_lift_inputs",
    "internal_error",
]


class OnboardingRequest(BaseModel):
    sex: Optional[SexLiteral] = None
    birth_year: Optional[int] = Field(default=None, ge=1900, le=2100)
    training_experience: Optional[ExperienceLiteral] = None
    squat_1rm: Optional[float] = Field(default=None, gt=0, le=600)
    bench_1rm: Optional[float] = Field(default=None, gt=0, le=400)
    deadlift_1rm: Optional[float] = Field(default=None, gt=0, le=600)

    @field_validator("birth_year")
    @classmethod
    def _check_year(cls, v: Optional[int]) -> Optional[int]:
        if v is None:
            return v
        from datetime import datetime
        current_year = datetime.now().year
        if v > current_year:
            raise ValueError("출생연도는 미래일 수 없습니다.")
        return v


class MissingReason(BaseModel):
    code: MissingReasonCode
    message: str


class OnboardingResponse(BaseModel):
    level: LevelLiteral
    level_source: LevelSourceLiteral
    avg_tier_score: Optional[float] = None
    capped_by_experience: bool = False
    per_lift: dict[str, int] = Field(default_factory=dict)
    feedback_style_preview: str
    changeable_in_settings: bool = True
    missing_reasons: list[MissingReason] = Field(default_factory=list)


class OnboardingStatusResponse(BaseModel):
    needs_onboarding: bool
