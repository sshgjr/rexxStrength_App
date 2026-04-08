# 2-레이어 피드백 시스템 설계

> 날짜: 2026-03-31
> 상태: 승인됨

## 개요

운동 자세 평가 결과를 **부상 위험(레이어 1)**과 **스타일 허용(레이어 2)**으로 분류하고, 사용자 등급(초급/중급/상급)에 따라 피드백 출력을 차등 제어하는 시스템.

### 핵심 원칙

- 레이어 1(부상 위험): 등급 무관 항상 경고
- 레이어 2(스타일 허용): 초급=교정 안내, 중급=참고 안내, 상급=출력 안 함
- 상급자 + 레이어 2만 감지 → 피드백 없음 (잘 하고 있다는 신호)
- 이슈 없음 → 피드백 없음

---

## 1. 레이어 설정 파일

### 위치

`rexx_app/assets/config/layer_config.json`

### 구조

```json
{
  "version": 1,
  "exercises": {
    "squat": {
      "layer1": [
        { "criterion": "척추 각도", "reason": "요추 과굴곡 → 허리 부상 위험" },
        { "criterion": "무릎-발끝 정렬", "reason": "무릎 cave-in → ACL 부상 위험" }
      ],
      "layer2": [
        { "criterion": "무릎 각도", "reason": "스쿼트 깊이는 스타일 차이" },
        { "criterion": "힙 힌지", "reason": "하이바/로우바 스타일" },
        { "criterion": "좌우 대칭", "reason": "경미한 비대칭은 자연스러운 개인차" }
      ]
    },
    "deadlift": {
      "layer1": [
        { "criterion": "등 각도", "reason": "요추 과굴곡(둥근 등) → 디스크 부상 위험" },
        { "criterion": "좌우 대칭", "reason": "고중량 비대칭 → 척추 측방 부하 부상" }
      ],
      "layer2": [
        { "criterion": "힙 힌지 패턴", "reason": "컨벤셔널/스모 등 스타일 차이" },
        { "criterion": "락아웃", "reason": "락아웃 정도는 경기/훈련 목적에 따라 다름" },
        { "criterion": "무릎 각도", "reason": "시작 자세 무릎 각도는 스타일 차이" }
      ]
    },
    "bench_press": {
      "layer1": [
        { "criterion": "팔꿈치 벌어짐", "reason": "과도한 flare → 어깨 충돌증후군 위험" },
        { "criterion": "팔꿈치 각도", "reason": "바텀 과도한 스트레치 → 어깨/흉근 파열 위험" }
      ],
      "layer2": [
        { "criterion": "바 경로", "reason": "바 경로는 체형/그립에 따라 다름" },
        { "criterion": "락아웃", "reason": "완전 락아웃 여부는 훈련 목적 차이" },
        { "criterion": "좌우 대칭", "reason": "경미한 좌우 차이는 자연스러운 범위" }
      ]
    },
    "wrist_curl": {
      "layer1": [
        { "criterion": "팔꿈치 고정도", "reason": "팔꿈치 불안정 → 관절 과부하 부상 위험" }
      ],
      "layer2": [
        { "criterion": "손목 가동범위", "reason": "ROM은 개인 유연성 차이" },
        { "criterion": "동작 일관성", "reason": "숙련도에 따른 자연스러운 차이" },
        { "criterion": "최대 수축", "reason": "훈련 목적에 따라 의도적 조절 가능" },
        { "criterion": "좌우 대칭", "reason": "경미한 차이는 자연스러움" }
      ]
    }
  }
}
```

### 설계 결정

- `criterion` 값은 `CriterionResult.name`과 정확히 매칭
- `reason`은 Gemini 프롬프트에 전달되어 피드백 근거로 활용
- 새 운동/기준 추가 시 이 파일만 수정하면 코드 변경 불필요
- `version` 필드로 포맷 변경 추적

---

## 2. 사용자 등급 시스템

### 등급 정의

| 등급 | 값 | 피드백 동작 |
|------|-----|-----------|
| 초급 | `beginner` | L1 경고 + L2 교정 안내 (원인 + 수정 방법) |
| 중급 | `intermediate` | L1 경고 + L2 참고 안내 (부드러운 제안) |
| 상급 | `advanced` | L1 경고만, L2는 출력 안 함 |

### 초기 설정

- 회원가입 또는 첫 사용 시 선택
- 기본값: `beginner`

### 저장

- **원본**: Railway PostgreSQL — `User` 테이블에 `level` 컬럼 추가 (VARCHAR, 기본값 `beginner`)
- **캐시**: SharedPreferences — 오프라인 시 로컬 캐시 사용
- 등급 변경 → 서버 API → DB 업데이트 → 성공 시 로컬 캐시 동기화

### 자동 등급 제안

평가 이력 기반으로 등급 변경을 **제안**만 하며, 최종 결정은 사용자가 함.

#### 승급 제안

| 방향 | 조건 |
|------|------|
| 초급 → 중급 | 평균 80점 이상 3회 연속 |
| 중급 → 상급 | 평균 85점 이상 3회 연속 |

#### 하향 제안

| 방향 | 조건 | 보수성 |
|------|------|--------|
| 상급 → 중급 | 평균 60점 미만 **3회 연속** | 엄격 — 상급은 L2 피드백이 침묵이므로 빠르게 감지 필요 |
| 중급 → 초급 | 평균 50점 미만 **5회 연속** | 보수적 — 감정 배려 |

#### 제안 문구

- **승급**: "최근 자세가 안정적이에요! {상위 등급}으로 올려볼까요?"
- **하향 (상급→중급)**: "최근 자세가 평소와 다른 패턴이 보여요. 중급 모드로 전환하면 더 구체적인 피드백을 받을 수 있어요."
- **하향 (중급→초급)**: "더 세부적인 코칭을 받아보시겠어요? 단계를 조정하면 원인과 수정 방법까지 안내해 드려요."
- 모든 제안에 공통 문구: "등급은 설정에서 언제든 변경할 수 있습니다."

---

## 3. 레이어 분류기 (LayerClassifier)

### 위치

`rexx_app/lib/features/pose_evaluation/engine/layer_classifier.dart`

### 입력/출력

- **입력**: `List<CriterionResult>`, `ExerciseType`
- **출력**: `LayerClassification`

### 모델

```dart
class LayerIssue {
  final CriterionResult criterion;
  final String reason;  // layer_config.json의 reason
}

class LayerClassification {
  final List<LayerIssue> layer1Issues;  // 부상 위험 (Bad/Warning만)
  final List<LayerIssue> layer2Issues;  // 스타일 허용 (Bad/Warning만)
  bool get hasLayer1 => layer1Issues.isNotEmpty;
  bool get hasLayer2Only => !hasLayer1 && layer2Issues.isNotEmpty;
  bool get hasNoIssues => layer1Issues.isEmpty && layer2Issues.isEmpty;
}
```

### 동작

1. `layer_config.json`에서 해당 운동의 L1/L2 기준 목록 로드
2. `CriterionResult` 중 `grade != Good`인 항목만 필터 (Good은 이슈 아님)
3. 필터된 항목을 `criterion.name` 기준으로 L1/L2 매칭
4. 매칭되지 않는 항목은 L2로 기본 분류 (안전 방향)

### 피드백 출력 결정

| 상황 | 초급 | 중급 | 상급 |
|------|------|------|------|
| L1 감지 | 경고 출력 | 경고 출력 | 경고 출력 |
| L2만 감지 | 교정 안내 | 참고 안내 | 출력 안 함 |
| 이슈 없음 | 출력 안 함 | 출력 안 함 | 출력 안 함 |

---

## 4. 서버 API 변경

### 요청 스키마 변경

`rexx_server/schemas/pose_schemas.py`에 추가:

```python
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
    # 신규 필드
    user_level: str                  # "beginner" / "intermediate" / "advanced"
    layer1_issues: List[LayerIssue]  # 부상 위험 항목
    layer2_issues: List[LayerIssue]  # 스타일 허용 항목
```

### 서버 로직 변경

`routers/pose_feedback.py`:
- 상급 + L2만 → Gemini 호출 스킵, 빈 응답 반환
- 이슈 없음 → Gemini 호출 스킵, 빈 응답 반환
- 그 외 → user_level + layer issues를 Gemini 프롬프트에 포함

### User 모델 변경

`auth.py`의 `User` 모델에 `level` 컬럼 추가:
- VARCHAR, 기본값 `"beginner"`
- 신규 API: `PUT /me/level` — 등급 변경

---

## 5. Gemini 프롬프트 변경

### 기존

단일 톤, `summary/reason/action/cue` 4종 출력

### 변경 후

조건부 톤, `feedback/keypoint/cause` 3종 출력

```
너는 운동 코치다.
입력된 분석 결과를 바탕으로 아래 규칙에 따라 한국어 피드백을 생성해라.

규칙:
- 레이어 1 항목: 등급 무관, 반드시 경고. 부상 위험을 명확히 전달
- 레이어 2 항목:
  - 초급: 원인과 구체적 수정 방법을 안내
  - 중급: "~해보시는 것도 좋습니다" 식의 부드러운 참고 안내
  - 상급: 언급하지 마라
- 운동 초보자도 이해할 수 있게 써라
- 가장 중요한 문제 1~2개만 말해라
- 비난하지 말고 코칭 톤으로 써라
- 추상적인 말 대신 바로 실행 가능한 행동을 써라

출력 형식(JSON):
{
  "feedback": "상세 설명 (2~3문장)",
  "keypoint": "핵심 한 문장 (8~16자)",
  "cause": "자세 문제 원인 분석 (1~2문장)"
}
```

---

## 6. UI 변경

### FeedbackCard 리디자인

기존 4섹션(`summary/reason/action/cue`) → 3섹션(`keypoint/cause/feedback`):

```
┌─────────────────────────────────┐
│  한 줄 키포인트                   │  ← 상단 강조 배너
│  "무릎이 안쪽으로 밀리고 있어요"    │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  🔍 자세 문제 원인               │
│  "발목 가동성 부족으로 인해..."    │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  📋 피드백                       │
│  "벽에 손을 짚고 발목 스트레칭..." │
└─────────────────────────────────┘
```

#### 조건별 스타일

| 상황 | 키포인트 스타일 | 카드 표시 |
|------|---------------|----------|
| L1 감지 | 빨간 경고 아이콘 + 빨간 테두리 | 3섹션 전부 |
| L2 초급 | 기본 녹색 테마 | 3섹션 전부 |
| L2 중급 | 연한 녹색, 참고 톤 | 3섹션 전부 |
| 상급 + L2만 | — | "자세가 좋습니다" 한 줄 |
| 이슈 없음 | — | "자세가 좋습니다" 한 줄 |

### 등급 설정 화면

설정 화면에 등급 선택 섹션 추가:
- 라디오 버튼: 초급 / 중급 / 상급
- 각 등급 옆에 한 줄 설명
- 하단 안내: "언제든 변경할 수 있습니다"
- 변경 시 서버 API 호출 → DB 업데이트

### 등급 변경 제안 다이얼로그

- 조건 충족 시 결과 화면에서 바텀시트로 표시
- [유지할게요] / [변경하기] 버튼
- 한 번 거절하면 다음 조건 충족까지 다시 표시하지 않음

---

## 7. 전체 데이터 흐름

```
사용자 영상
    │
    ▼
① ML Kit BlazePose (로컬) — 33개 좌표 추출
    │
    ▼
② Rule Engine (로컬) — 기준별 점수/등급 산출
    │
    ▼
③ LayerClassifier (로컬, 신규) — layer_config.json 참조, L1/L2 분류
    │
    ▼
④ 출력 결정 (로컬, 신규)
    │  상급 + L2만 → 서버 호출 스킵, "자세가 좋습니다"
    │  이슈 없음 → 서버 호출 스킵, "자세가 좋습니다"
    │  그 외 → 서버 호출
    ▼
⑤ 서버 API (Railway) — Gemini 2.5 Flash Lite → feedback/keypoint/cause
    │
    ▼
⑥ FeedbackCard (로컬) — 레이어+등급별 조건부 스타일 렌더링
    │
    ▼
⑦ 등급 자동 제안 (로컬, 신규) — 이력 누적 → 승급/하강 조건 → 다이얼로그
```

### 오프라인 동작

- ①~④ 모두 로컬 → 오프라인 작동
- 서버 호출 필요 시 → 기존 오프라인 큐 저장, 온라인 복귀 시 동기화
- 등급은 로컬 캐시(SharedPreferences) 사용

---

## 8. 변경 범위

| 영역 | 파일 | 변경 |
|------|------|------|
| 설정 파일 | `assets/config/layer_config.json` | 신규 |
| 분류기 | `engine/layer_classifier.dart` | 신규 |
| 분석기 | `engine/pose_analyzer.dart` | 수정 — LayerClassification 결과 추가 |
| 스키마 | `schemas/pose_schemas.py` | 수정 — user_level, layer issues 필드 |
| Gemini | `services/gemini_service.py` | 수정 — 조건부 프롬프트, 3종 출력 |
| 라우터 | `routers/pose_feedback.py` | 수정 — 스킵 로직 |
| UI | `widgets/feedback_card.dart` | 수정 — 3종 포맷 + 조건부 스타일 |
| 모델 | `auth.py` (User) | 수정 — level 필드 |
| 서비스 | `services/pose_feedback_service.dart` | 수정 — 레이어 데이터 전송 |
| 설정 UI | 설정 화면 | 수정 — 등급 선택 섹션 |
| 다이얼로그 | 등급 제안 위젯 | 신규 |
| 등급 서비스 | `services/level_service.dart` | 신규 — 등급 CRUD + 자동 제안 로직 |
