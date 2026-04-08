from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class CriterionScore(BaseModel):
    name: str
    description: str
    score: float
    weight: float
    grade: str


class LayerIssue(BaseModel):
    criterion: str
    score: float
    grade: str
    reason: str


class PoseFeedbackRequest(BaseModel):
    exercise_type: str
    total_score: int
    criteria_scores: List[CriterionScore]
    detected_issues: List[str]
    # 신규 필드 (하위 호환: 기본값 제공)
    user_level: str = "beginner"
    layer1_issues: List[LayerIssue] = []
    layer2_issues: List[LayerIssue] = []


class PoseFeedbackResponse(BaseModel):
    success: bool
    feedback: str
    session_id: Optional[int] = None


class PoseHistoryItem(BaseModel):
    id: int
    exercise_type: str
    total_score: int
    feedback_text: Optional[str]
    created_at: datetime


class PoseHistoryResponse(BaseModel):
    success: bool
    history: List[PoseHistoryItem]
