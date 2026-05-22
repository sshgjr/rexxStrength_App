import json
import sys
import os

# 상위 디렉토리를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from slowapi import Limiter
from slowapi.util import get_remote_address

from database import Base, engine, get_db
from auth import get_current_user, get_optional_current_user, User
from schemas.pose_schemas import (
    PoseFeedbackRequest,
    PoseFeedbackResponse,
    PoseHistoryResponse,
    PoseHistoryItem,
)
from models.pose_models import PoseEvaluation
from services.gemini_service import generate_feedback

# 테이블 생성
Base.metadata.create_all(bind=engine)

def _guest_rate_limit_key(request: Request) -> str:
    """인증된 사용자는 rate limiting 제외, 게스트만 IP 기반 제한."""
    auth = request.headers.get("Authorization")
    if auth and auth.startswith("Bearer "):
        return "authenticated_bypass"
    return get_remote_address(request)

limiter = Limiter(key_func=_guest_rate_limit_key)
router = APIRouter(prefix="/api/pose", tags=["pose"])


@router.post("/feedback", response_model=PoseFeedbackResponse)
@limiter.limit("5/minute")
def create_feedback(
    request: Request,
    data: PoseFeedbackRequest,
    current_user: User | None = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
):
    feedback_text = generate_feedback(
        exercise_type=data.exercise_type,
        total_score=data.total_score,
        criteria_scores=[c.model_dump() for c in data.criteria_scores],
        detected_issues=data.detected_issues,
        user_level=data.user_level,
        layer1_issues=[i.model_dump() for i in data.layer1_issues],
        layer2_issues=[i.model_dump() for i in data.layer2_issues],
    )

    session_id = None

    if current_user is not None:
        evaluation = PoseEvaluation(
            user_id=current_user.id,
            exercise_type=data.exercise_type,
            total_score=data.total_score,
            criteria_scores_json=json.dumps(
                [c.model_dump() for c in data.criteria_scores], ensure_ascii=False
            ),
            detected_issues_json=json.dumps(data.detected_issues, ensure_ascii=False),
            feedback_text=feedback_text,
        )
        db.add(evaluation)
        db.commit()
        db.refresh(evaluation)
        session_id = evaluation.id

    return {
        "success": True,
        "feedback": feedback_text,
        "session_id": session_id,
    }


@router.get("/history", response_model=PoseHistoryResponse)
def get_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    evaluations = (
        db.query(PoseEvaluation)
        .filter(PoseEvaluation.user_id == current_user.id)
        .order_by(PoseEvaluation.created_at.desc())
        .limit(50)
        .all()
    )

    history = [
        PoseHistoryItem(
            id=e.id,
            exercise_type=e.exercise_type,
            total_score=e.total_score,
            feedback_text=e.feedback_text,
            created_at=e.created_at,
            criteria_scores=_safe_json_list(e.criteria_scores_json),
            detected_issues=_safe_json_list(e.detected_issues_json),
        )
        for e in evaluations
    ]

    return {"success": True, "history": history}


def _safe_json_list(raw: str | None):
    """저장된 JSON 문자열을 파싱. 비어있거나 깨졌으면 빈 리스트 반환."""
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, list) else []
    except (ValueError, TypeError):
        return []
