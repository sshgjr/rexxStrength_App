# 비로그인 AI 피드백 & 회원가입 유도 팝업 설계

## 개요

비로그인 사용자도 AI 코칭 피드백을 2회까지 무료로 체험할 수 있도록 하고, 결과 화면에서 나갈 때 점수별 맞춤 메시지로 회원가입을 유도하는 기능.

## 1. 비로그인 AI 피드백 흐름

### 서버 변경

- `POST /api/pose/feedback` 엔드포인트의 인증을 optional로 변경
- 새로운 의존성 함수 `get_optional_current_user` 생성 — 별도의 `OAuth2PasswordBearer(auto_error=False)` 인스턴스 사용, `Authorization` 헤더가 없으면 `None` 반환, 있으면 기존 `get_current_user` 로직 수행
- 토큰 있으면 기존대로 DB에 평가 기록 저장
- 토큰 없으면 AI 피드백은 반환하되, DB에 기록 저장하지 않음
- `PoseFeedbackResponse` 스키마의 `session_id`를 `Optional[int]`로 변경 (게스트는 `None`)
- 비인증 요청에 대한 IP 기반 rate limiting 추가 (분당 5회 제한, `slowapi` 또는 인메모리 카운터)

### 앱 변경

- `SharedPreferences`에 `guest_feedback_count` 키로 게스트 사용 횟수 저장 (앱 삭제 전까지 유지)
- `ExerciseSelectScreen` → 토큰 없이도 진입 가능 (`token` 파라미터 nullable)
- `PoseFeedbackService`가 게스트 피드백 로직을 전담:
  - 토큰 없이도 API 호출 가능
  - 기존 `noToken` 가드(토큰 null → 즉시 실패) 수정: 토큰 null이면 게스트 카운트 확인 → 2회 미만이면 토큰 없이 API 호출, 2회 이상이면 `guestLimitReached` 반환
  - 게스트 카운트는 API 호출 성공(HTTP 200) 시에만 증가 (실패 시 카운트 안 함)
  - 게스트 사용자의 오프라인 큐잉은 지원하지 않음 — 오프라인 시 기본 피드백만 표시

### 게스트 피드백 흐름

```
비로그인 사용자가 "자세 평가" 탭
→ ExerciseSelectScreen (토큰 없이 진입)
→ 운동 선택 → 영상 업로드 → 분석
→ guest_feedback_count 확인:
   - 2회 미만: API 호출 (토큰 없이), 성공 시 카운트 +1, AI 피드백 표시
   - 2회 이상: API 호출 안 함, 기본 피드백 + guestLimitReached 에러 표시
→ 결과 화면 표시
```

## 2. 회원가입 유도 팝업

### 트리거 조건

- 결과 화면에서 나가려 할 때 (홈으로 돌아가기 버튼, AppBar 뒤로가기, 시스템 백 버튼)
- 비로그인 사용자만 대상 (로그인 사용자는 팝업 없이 바로 이동)
- 로그인 여부 판단을 위해 `PoseResultScreen`에 `token` 파라미터 추가 (`String?`)

### 팝업 형태

화면 하단에서 올라오는 모달 BottomSheet 스타일.

### 점수별 컨텐츠

| 점수 구간 | 헤더 | 서브 메시지 | 시각 요소 |
|-----------|------|------------|----------|
| 70-100 | "축하합니다! 상위 랭커의 자질이 보여요" | "회원가입하고 랭킹에 이름을 올리세요" | 점수 게이지 + 정적 랭킹 보드 일러스트 (흐릿하게) |
| 50-69 | "좋은 시작이에요!" | "첫 기록을 저장하고 성장을 추적하세요" | 현재 점수 → 미래 예상 점수 성장 그래프 (정적 일러스트) |
| 0-49 | "모든 챔피언은 여기서 시작했어요" | "AI 코치가 함께할게요. 시작해볼까요?" | 격려 아이콘 + 성장 가능성 메시지 |

### 버튼 구성

- 메인 CTA: "회원가입하고 기록 저장하기" (초록색, 크게)
- 서브: "나중에" (작은 텍스트 버튼)

### 2차 확인 (나중에 클릭 시)

"나중에"를 누르면 시트 내용이 전환:

- 텍스트: "이 기록은 저장되지 않아요. 다음에 또 처음부터 시작해야 해요."
- "그래도 나가기" (회색 버튼) → 홈으로 이동
- "역시 가입할게요" (초록색 버튼) → 회원가입 화면으로

### 네비게이션 가로채기

- `PopScope`로 시스템 백 버튼 가로채기
- "홈으로 돌아가기" 버튼에도 동일 로직 적용

### 회원가입 후 상태 전파

- BottomSheet에서 "회원가입" → `LoginPage`로 `Navigator.push`
- `LoginPage`에서 가입/로그인 완료 시 결과를 `Navigator.pop`으로 반환
- BottomSheet에서 결과를 받아 `Navigator.popUntil(isFirst)` + 홈 화면 상태 갱신
- 홈 화면은 기존 `then()` 콜백 패턴으로 로그인 상태 업데이트

## 3. 파일별 변경 사항

### 서버

| 파일 | 변경 내용 |
|------|----------|
| `rexx_server/auth.py` | `get_optional_current_user` 함수 추가 |
| `rexx_server/routers/pose_feedback.py` | `get_optional_current_user` 사용, 비인증 시 DB 저장 스킵, rate limiting |
| `rexx_server/schemas/pose_schemas.py` | `session_id`를 `Optional[int]`로 변경 |

### 앱

| 파일 | 변경 내용 |
|------|----------|
| `rexx_app/lib/services/pose_feedback_service.dart` | 게스트 피드백 로직 전담: 토큰 없이 API 호출, 게스트 횟수 관리 (`canUseGuestFeedback()`, `incrementGuestCount()`), 기존 `noToken` 가드 수정, 오프라인 큐잉 게스트 제외, `FeedbackError.guestLimitReached` 추가 |
| `rexx_app/lib/pages/home_screen.dart` | 비로그인도 자세 평가 진입 허용 |
| `rexx_app/lib/features/pose_evaluation/screens/exercise_select_screen.dart` | `token` nullable 확인 (이미 nullable이면 변경 없음) |
| `rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart` | `PoseResultScreen`에 `token` 전달 추가 |
| `rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart` | `token` 파라미터 추가, `PopScope` + 팝업 로직 |
| `rexx_app/lib/features/pose_evaluation/widgets/signup_prompt_sheet.dart` | 신규 — 점수별 BottomSheet 위젯 (2차 확인 포함) |
| `rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart` | `guestLimitReached` 에러 타입 전용 메시지 추가 |
