"""온보딩 라우터.

POST /me/onboarding — 입력 받아 자동 등급 산정 후 저장
GET  /me/onboarding-status — 온보딩 필요 여부 조회
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth import User, get_current_user
from database import get_db
from schemas.onboarding_schemas import (
    OnboardingRequest,
    OnboardingResponse,
    OnboardingStatusResponse,
    MissingReason,
)
from services.level_calculator import (
    calculate,
    LevelCalculation,
    LevelCalculationFailure,
)


router = APIRouter()


_FEEDBACK_PREVIEWS = {
    "beginner": "초급 사용자에게는 매우 상세한 자세 교정과 친절한 설명을 드려요.",
    "intermediate": "중급 사용자에게는 간결한 자세 교정 위주로 피드백을 드려요.",
    "advanced": "상급 사용자에게는 핵심 포인트와 미세 조정만 드려요.",
}

_MISSING_MESSAGES = {
    "missing_body_weight": (
        "체중 정보가 없어 자동 산정을 할 수 없었어요. "
        "회원 페이지에서 체중을 입력하시면 정확한 등급을 받아보실 수 있어요."
    ),
    "no_lift_inputs": (
        "3대 중량(스쿼트·벤치·데드리프트)을 한 종목도 입력하지 않으셔서 "
        "자동 산정을 할 수 없었어요. 한 종목이라도 입력하시면 등급이 결정돼요."
    ),
    "internal_error": (
        "산정 중 일시적인 문제가 발생했어요. 설정에서 다시 시도해보세요."
    ),
}


def _to_missing_reasons(codes: list[str]) -> list[MissingReason]:
    return [
        MissingReason(code=c, message=_MISSING_MESSAGES[c])
        for c in codes
        if c in _MISSING_MESSAGES
    ]


@router.post("/me/onboarding", response_model=OnboardingResponse)
def submit_onboarding(
    data: OnboardingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # 1. 입력 필드를 User에 저장
    current_user.sex = data.sex
    current_user.birth_year = data.birth_year
    current_user.training_experience = data.training_experience
    current_user.squat_1rm = data.squat_1rm
    current_user.bench_1rm = data.bench_1rm
    current_user.deadlift_1rm = data.deadlift_1rm

    # 2. 등급 산정 (체중은 기존 User.weight 사용)
    result = calculate(
        sex=data.sex,
        body_weight_kg=current_user.weight,
        squat_1rm=data.squat_1rm,
        bench_1rm=data.bench_1rm,
        deadlift_1rm=data.deadlift_1rm,
        training_experience=data.training_experience,
    )

    if isinstance(result, LevelCalculation):
        current_user.level = result.level
        current_user.level_source = "auto"
        db.commit()
        db.refresh(current_user)
        return OnboardingResponse(
            level=result.level,
            level_source="auto",
            avg_tier_score=result.avg_tier_score,
            capped_by_experience=result.capped_by_experience,
            per_lift=result.per_lift,
            feedback_style_preview=_FEEDBACK_PREVIEWS[result.level],
            changeable_in_settings=True,
            missing_reasons=[],
        )

    # 3. 산정 실패 → default 처리
    current_user.level = "beginner"
    current_user.level_source = "default"
    db.commit()
    db.refresh(current_user)
    return OnboardingResponse(
        level="beginner",
        level_source="default",
        avg_tier_score=None,
        capped_by_experience=False,
        per_lift={},
        feedback_style_preview=_FEEDBACK_PREVIEWS["beginner"],
        changeable_in_settings=True,
        missing_reasons=_to_missing_reasons(result.missing_reasons),
    )


@router.get("/me/onboarding-status", response_model=OnboardingStatusResponse)
def get_onboarding_status(current_user: User = Depends(get_current_user)):
    return OnboardingStatusResponse(
        needs_onboarding=current_user.level_source is None,
    )
