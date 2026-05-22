# 운동 피드백 내역 조회 기능 구현 계획

> **목표**: 로그인한 사용자가 마이페이지에서 본인의 과거 운동 평가 기록(최근 50건)을 목록 + 단건 상세로 조회할 수 있게 한다.
>
> **결정된 방향**: 사용자용 "내 기록 보기" (관리자 페이지 아님). 회원 페이지(`MemberPage`)에 진입 카드를 추가하여 진입.

---

## 1. 현재 상태 (이미 존재 — 재활용)

| 컴포넌트 | 파일 | 상태 |
|---|---|---|
| DB 테이블 `pose_evaluations` | `rexx_server/models/pose_models.py` | ✅ 존재 (id, user_id, exercise_type, total_score, criteria_scores_json, detected_issues_json, feedback_text, created_at) |
| 저장 로직 | `rexx_server/routers/pose_feedback.py:create_feedback` | ✅ 동작 (POST /api/pose/feedback 호출 시 자동 저장) |
| 목록 엔드포인트 | `rexx_server/routers/pose_feedback.py:get_history` | ✅ 동작 (GET /api/pose/history, user_id 필터, 50건, created_at desc) |
| Flutter HTTP 클라이언트 | `rexx_app/lib/services/pose_feedback_service.dart:139 getHistory()` | ✅ 존재 |

**누락**: UI 화면 + 상세 조회 시 필요한 criteria_scores·detected_issues·feedbackText 노출.

---

## 2. 작업 범위

### 2.1 백엔드 (`rexx_server/`)

| 파일 | 변경 |
|---|---|
| `schemas/pose_schemas.py` | `PoseHistoryItem`에 다음 필드 추가:<br>• `criteria_scores: List[CriterionScore]`<br>• `detected_issues: List[str]` |
| `routers/pose_feedback.py:get_history` | 응답 매핑에 `json.loads(e.criteria_scores_json)`, `json.loads(e.detected_issues_json)` 추가 |

> **결정**: 별도 `GET /history/{id}` 엔드포인트 만들지 않음. 50건 한도라 list 호출에 상세 포함이 더 단순. 향후 페이징 도입 시 분리 검토.

### 2.2 Flutter (`rexx_app/`)

| 파일 | 변경 |
|---|---|
| `lib/services/pose_feedback_service.dart` | `getHistory()` 반환값을 `Map`이 아닌 `List<HistoryItem>` 모델로 정의. 상세 필드 파싱. |
| `lib/features/pose_evaluation/models/history_item.dart` *(신규)* | `HistoryItem` 모델: id, exerciseType, totalScore, feedbackText, criteria, detectedIssues, createdAt. `EvaluationResult.fromHistory()` 변환 헬퍼. |
| `lib/features/pose_evaluation/screens/history_list_screen.dart` *(신규)* | 목록 화면. 운동별 아이콘/색상, 점수 배지, 날짜, 한 줄 요약. 탭 → 상세 navigate. 빈 상태 + 로딩 + 에러 처리. |
| `lib/features/pose_evaluation/screens/pose_result_screen.dart` | 기존 화면 재사용 — `EvaluationResult` 받아 표시. 단, `_checkLevelSuggestion()`은 신규 평가에서만 동작하도록 옵셔널 처리(예: `fromHistory: bool`). |
| `lib/pages/member_page.dart` | "운동 기록" 카드 추가. `_ProfileCard` 아래, `_LevelSettingsSection` 위. 탭 → `HistoryListScreen` 진입. |

> **결정**: 단건 상세는 신규 화면 만들지 않고 `PoseResultScreen` 재사용. 일관된 UI(FeedbackCard, ScoreGauge, CriterionBreakdown) 그대로 활용. 단, 레벨 추천 시트는 표시되지 않게 옵셔널 가드.

---

## 3. 데이터 흐름

```
MemberPage
  ↓ "운동 기록" 카드 탭
HistoryListScreen
  ↓ initState
PoseFeedbackService.getHistory(token)
  ↓ GET /api/pose/history
[HistoryItem, ...] 50건
  ↓ ListView.builder
[운동 아이콘 | 점수 배지 | 운동명 + 날짜 | "스쿼트 - 85점 - 5월 10일"]
  ↓ 탭
EvaluationResult.fromHistory(item)
  ↓
PoseResultScreen(result: ..., token: ..., fromHistory: true)
  ↓
FeedbackCard + 점수 게이지 + 기준별 브레이크다운
```

---

## 4. 단계별 실행 순서 (세션 재개 시)

1. **백엔드 스키마 확장** — `pose_schemas.py:PoseHistoryItem` 필드 추가, `pose_feedback.py:get_history` JSON 파싱 추가
2. **백엔드 검증** — `uvicorn main:app --reload` → `curl -H "Authorization: Bearer <token>" /api/pose/history` 응답에 criteria_scores·detected_issues 포함 확인
3. **Flutter 모델** — `HistoryItem` 신규, `getHistory()` 반환 타입 변경
4. **Flutter 목록 화면** — `HistoryListScreen` 작성. 다크 테마 일관성, 빈 상태("아직 평가 기록이 없어요"), 에러 처리
5. **PoseResultScreen 가드** — `fromHistory` flag 추가, 레벨 추천 시트 조건부
6. **MemberPage 진입 카드** — `_ProfileCard` 다음에 `_HistoryEntryCard` 추가, `Icons.history` + "운동 기록 보기"
7. **flutter analyze** — 경고 0개 (신규 코드 기준)
8. **실기 테스트** — Xcode 시뮬레이터, 로그인 → 마이페이지 → 운동 기록 → 목록 → 단건 상세
9. **커밋·푸시·PR** — 별도 브랜치 `feature/feedback-history` 또는 PR #2에 추가 커밋

---

## 5. UI 디테일 가이드

### 5.1 HistoryListScreen

- 다크 테마 (`#0B0F0C` bg, `#0F1612` card, `#16A34A` primary)
- 커스텀 헤더: 뒤로가기 + "운동 기록"
- 카드 내부: `Row(운동 아이콘 + Column(운동명 + 날짜) + Spacer + 점수 배지)`
- 점수 색상: good (≥85) → primary, warning (50-84) → orange, bad (<50) → danger
- 운동 아이콘: squat 🏋️, bench_press 💪, deadlift 🦵 (또는 Material 아이콘 매핑)
- 날짜 포맷: `intl` 패키지로 "2026.05.10 (화)" 또는 "오늘", "어제", "3일 전"

### 5.2 MemberPage 운동 기록 카드

- `_ProfileCard` 아래, 14px 간격
- 카드 외관 동일 (`_card` bg, radius 16, border)
- 내용: `Row(Icon(Icons.history, primary) + Text("운동 기록 보기") + Spacer + Icon(chevron_right, textSub))`
- 하단에 작은 부제: "최근 평가 N건" — 가능하면 현재 카운트 prefetch (선택적)

---

## 6. 검증 체크리스트

- [ ] `flutter analyze` — member_page, history_list_screen, pose_result_screen 경고 없음
- [ ] 빈 기록 상태: 로그인 직후 신규 사용자 → 목록 화면 빈 상태 메시지 표시
- [ ] 1건 이상 기록: 평가 수행 후 → 마이페이지 → 운동 기록 → 목록에 표시
- [ ] 단건 탭 → PoseResultScreen 정상 표시, 레벨 추천 시트 미표시
- [ ] 오프라인: 목록 로딩 실패 → snackbar + 재시도 버튼
- [ ] 백엔드: `/api/pose/history` 응답에 criteria_scores·detected_issues 포함 (curl로 검증)

---

## 7. 범위 외 (이번엔 안 함)

- 페이징 (50건 한도 충분, 나중에 무한 스크롤 검토)
- 운동 유형 필터, 기간 필터
- 통계 그래프 (점수 추이, 운동별 평균)
- 단건 삭제·재평가 요청
- 관리자 페이지 (별도 권한 시스템 필요)

---

## 8. 의존성 / 영향

- **DB 스키마 변경 없음** — 기존 컬럼 그대로 사용
- **마이그레이션 불필요**
- **API 호환성**: `PoseHistoryItem`에 필드 추가는 기존 클라이언트 영향 없음 (JSON 추가 필드 무시)
- **Railway 배포 필요**: 백엔드 변경분이 머지·배포되어야 Flutter 앱에서 상세 데이터 받을 수 있음
- **선행 PR**: #2 (회원 페이지 다크 테마 + /me 실데이터 연동) — 머지 후 진행 권장 (MemberPage 진입 카드가 PR #2 코드에 의존)

---

## 9. 참고 — PR #2 컨텍스트

- 브랜치: `feature/member-page-polish`
- PR URL: https://github.com/sshgjr/rexxStrength_App/pull/2
- 마지막 커밋(2026-05-10 기준): `1489308 fix(home): 우측 상단 버튼 → 마이페이지 진입`
- PR #2가 머지되어 main에 들어간 후, **새 브랜치 `feature/feedback-history`로 분기**하여 이번 작업 진행
