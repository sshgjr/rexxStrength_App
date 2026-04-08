# 코칭 등급 온보딩 시스템 설계서

**작성일:** 2026-04-09
**작성자:** 강민재 + Claude
**상태:** 설계 승인 완료, 구현 계획 작성 대기

---

## 1. 배경과 목표

### 배경
현재 Rexx Strength는 모든 신규 가입자를 무조건 `beginner` 등급으로 시작시킨다 (`rexx_server/main.py:144-152`). `User.level` 컬럼은 존재하고 (`rexx_server/auth.py:40`), Gemini 피드백 서비스는 이미 등급별 차등 프롬프트를 작동시키고 있다 (`rexx_server/services/gemini_service.py:7-30`). 그러나 사용자가 자신의 실제 수준을 입력할 경로가 없고, 등급을 직접 변경할 UI도 없다.

### 목표
1. 회원가입 직후 신체정보·운동경력·3대 1RM을 입력받아 **자동으로 코칭 등급을 산정**한다.
2. 산정 기준은 **Strength Level 식 표준** (성별·체중 기반 1RM 컷오프) + **운동 경력 상한선**을 결합한다.
3. 사용자에게 등급을 제시할 때 **언제든 설정에서 변경 가능**함을 명시하고, **등급별 AI 피드백 차이**를 간단히 안내한다.
4. 모든 입력은 **선택사항**이며, 스킵하면 `beginner`로 진행한다.

### 비목표
- 등급별 차등 피드백 로직 자체는 이미 구현되어 있으므로 본 설계의 범위가 아니다.
- 자동 등급 재산정(예: 사용자가 운동 후 1RM이 향상되었을 때 자동 승급)은 본 범위가 아니다. `LevelService`의 기존 upgrade/downgrade 감지 로직과는 별개.

---

## 2. 데이터 모델 변경

`User` 테이블 (`rexx_server/auth.py:29-40`)에 다음 컬럼을 추가한다. 모두 nullable.

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `sex` | `String(10)` | `"male"` / `"female"` / `null` (미선택) |
| `birth_year` | `Integer` | Strength Level 나이 보정용 (선택) |
| `training_experience` | `String(20)` | `"lt_6m"` / `"6m_2y"` / `"2_5y"` / `"5y_plus"` / `null` |
| `squat_1rm` | `Float` | kg |
| `bench_1rm` | `Float` | kg |
| `deadlift_1rm` | `Float` | kg |
| `level_source` | `String(20)` | `"auto"` / `"manual"` / `"default"` — 등급이 어떻게 결정되었는지 추적 |

기존 `level` 컬럼은 그대로 사용 (`beginner`/`intermediate`/`advanced`).

### 마이그레이션
`e2a747d` 커밋의 startup 자가 마이그레이션 패턴을 따른다. `auth.py` 또는 신규 `migrations.py`에 `ensure_user_columns(engine)` 함수를 두고, FastAPI startup 이벤트에서 호출한다. PostgreSQL은 `ALTER TABLE ADD COLUMN IF NOT EXISTS`, SQLite는 `ALTER TABLE ADD COLUMN`을 try/except로 감싼다. 컬럼이 모두 nullable이라 롤백 마이그레이션은 불필요하다.

---

## 3. 자동 등급 산정 로직

**위치:** `rexx_server/services/level_calculator.py` (신규)

### 입력
```python
sex: Literal["male", "female"] | None
body_weight_kg: float | None
squat_1rm: float | None
bench_1rm: float | None
deadlift_1rm: float | None
training_experience: Literal["lt_6m", "6m_2y", "2_5y", "5y_plus"] | None
```

### 알고리즘

**1단계: Strength Level 표준 테이블 조회**

`rexx_server/data/strength_standards.py`에 하드코딩된 dict로 보관한다. 외부 API 호출 없음. 출처는 strengthlevel.com 공개 표준이며, 업데이트가 필요하면 개발자가 직접 PR로 갱신한다.

```python
STANDARDS = {
    "male": {
        "squat":   { 60: [40, 65, 95, 130, 170], 70: [50, 80, 115, 155, 200], ... },
        "bench":   { 60: [30, 50, 75, 100, 130], ... },
        "deadlift":{ 60: [55, 85, 120, 160, 205], ... },
    },
    "female": { ... },
}
```

각 1RM 배열은 `[Beginner, Novice, Intermediate, Advanced, Elite]` 컷오프이다. 체중 구간 사이는 선형 보간하고, 표준 범위를 벗어나면 양 끝 구간으로 clamp한다. 성별 미입력 시 `male` 표준으로 fallback한다.

**2단계: 종목별 단계 점수 산정**

각 종목의 1RM을 컷오프와 비교해 0~4 단계 점수를 부여한다:
- Beginner 미만 = 0
- Beginner ≤ x < Novice = 1
- Novice ≤ x < Intermediate = 2
- ...
- Elite ≤ x = 4

(필요시 컷오프 사이를 선형 보간해 소수 점수 부여 가능)

1RM 미입력 종목은 평균 계산에서 제외한다.

**3단계: 평균 → 3단계 매핑**

```
입력된 종목들의 평균 단계 점수 (0.0 ~ 4.0)
  < 2.0     → 초급 (beginner)
  2.0 ~ 3.5 → 중급 (intermediate)
  ≥ 3.5     → 상급 (advanced)
```

이 컷오프는 자연스럽게 피라미드 분포를 만든다. 상급은 평균 1RM이 Advanced와 Elite 사이여야 도달 가능하므로 소수만 진입한다.

**4단계: 경력 기반 상한선 적용**

```
lt_6m   → 최대 초급
6m_2y   → 최대 중급
2_5y    → 제한 없음
5y_plus → 제한 없음
None    → 제한 없음
```

자세·신경계 적응이 부족한 상태에서 1RM만 높아 과대평가되는 것을 방지한다.

**5단계: 결과 반환**

```python
@dataclass
class LevelCalculation:
    level: Literal["beginner", "intermediate", "advanced"]
    avg_tier_score: float          # 0.0~4.0
    capped_by_experience: bool     # 경력 상한 적용 여부
    per_lift: dict[str, int]       # {"squat": 2, "bench": 1, "deadlift": 2}
```

### 산정 불가 케이스 및 사유 보고

`level_calculator.calculate(...)`는 산정이 가능하면 `LevelCalculation`을 반환하고, 불가능하면 다음 dataclass를 반환한다:

```python
@dataclass
class LevelCalculationFailure:
    missing_reasons: list[Literal[
        "missing_body_weight",   # 체중 정보 없음
        "no_lift_inputs",        # 1RM 세 종목 모두 미입력
        "internal_error",        # 표준 테이블 lookup 실패 등 예외
    ]]
```

호출자(`POST /me/onboarding`)는 실패를 받으면 `level="beginner"` + `level_source="default"`로 저장하고, `missing_reasons`를 한국어 안내 문구로 매핑해 응답에 포함한다:

| 사유 | 사용자 안내 문구 |
|---|---|
| `missing_body_weight` | "체중 정보가 없어 자동 산정을 할 수 없었어요. 회원 페이지에서 체중을 입력하시면 정확한 등급을 받아보실 수 있어요." |
| `no_lift_inputs` | "3대 중량(스쿼트·벤치·데드리프트)을 한 종목도 입력하지 않으셔서 자동 산정을 할 수 없었어요. 한 종목이라도 입력하시면 등급이 결정돼요." |
| `internal_error` | "산정 중 일시적인 문제가 발생했어요. 설정에서 다시 시도해보세요." |

여러 사유가 동시에 발생하면 모두 나열한다 (예: 체중 + 1RM 둘 다 없으면 두 줄).

---

## 4. API 엔드포인트

### 4-1. `POST /me/onboarding` (신규)

사용자가 온보딩 화면에서 입력한 데이터를 받아 자동 등급 산정 후 저장한다.

**Request:**
```json
{
  "sex": "male" | "female" | null,
  "birth_year": 1995 | null,
  "training_experience": "lt_6m" | "6m_2y" | "2_5y" | "5y_plus" | null,
  "squat_1rm": 100.0 | null,
  "bench_1rm": 70.0 | null,
  "deadlift_1rm": 140.0 | null
}
```

**처리 순서:**
1. 모든 필드를 `User`에 저장 (모두 nullable)
2. `level_calculator.calculate(...)` 호출
3. 산정 가능 → `user.level = result.level`, `user.level_source = "auto"`
4. 산정 불가 → `user.level = "beginner"`, `user.level_source = "default"`

**Response (자동 산정 성공):**
```json
{
  "level": "intermediate",
  "level_source": "auto",
  "avg_tier_score": 2.3,
  "capped_by_experience": false,
  "per_lift": { "squat": 2, "bench": 1, "deadlift": 3 },
  "feedback_style_preview": "중급 사용자에게는 간결한 자세 교정 위주로 피드백을 드려요.",
  "changeable_in_settings": true,
  "missing_reasons": []
}
```

**Response (default fallback):**
```json
{
  "level": "beginner",
  "level_source": "default",
  "avg_tier_score": null,
  "capped_by_experience": false,
  "per_lift": {},
  "feedback_style_preview": "초급 사용자에게는 매우 상세한 자세 교정과 친절한 설명을 드려요.",
  "changeable_in_settings": true,
  "missing_reasons": [
    {
      "code": "missing_body_weight",
      "message": "체중 정보가 없어 자동 산정을 할 수 없었어요. 회원 페이지에서 체중을 입력하시면 정확한 등급을 받아보실 수 있어요."
    },
    {
      "code": "no_lift_inputs",
      "message": "3대 중량을 한 종목도 입력하지 않으셔서 자동 산정을 할 수 없었어요. 한 종목이라도 입력하시면 등급이 결정돼요."
    }
  ]
}
```

### 4-2. `GET /me/onboarding-status` (신규)

앱 부팅 시 호출. 온보딩 미완료 사용자에게 온보딩 화면을 띄우기 위한 분기.

**Response:** `{ "needs_onboarding": true | false }`

**판정 기준:** `level_source IS NULL` (한 번도 온보딩을 안 한 상태). "나중에" 스킵 시 `level_source="default"`로 저장되어 다음 부팅 때 다시 뜨지 않는다.

### 4-3. `PUT /me/level` (기존 확장)

이미 존재 (`main.py:193-202`). 사용자가 설정 화면에서 직접 등급 변경 시 호출. 호출 시 `level_source = "manual"`로 함께 업데이트되도록 소폭 확장한다.

---

## 5. Flutter 온보딩 플로우

**위치:** `rexx_app/lib/features/onboarding/` (신규 디렉토리)

**진입점:** 로그인 성공 직후 `home_screen.dart`가 `GET /me/onboarding-status`를 호출 → `needs_onboarding=true`이면 `OnboardingFlow`로 라우팅.

### 5단계 PageView

**Step 1: 환영 + 설명**
```
더 정확한 코칭을 위해
몇 가지만 알려주세요

• 약 30초 소요
• 언제든 설정에서 변경 가능
• 모두 선택 입력

[시작하기]  [나중에 (초급자로 설정)]
```

**Step 2: 신체정보**
- 성별: 남 / 여 / 선택안함 (라디오)
- 출생연도: 숫자 입력 (선택)
- 다음 / 건너뛰기

**Step 3: 운동 경력**
- 4단계 라디오: ≤6개월 / 6개월~2년 / 2~5년 / 5년+
- 다음 / 건너뛰기

**Step 4: 3대 중량**
- 스쿼트 1RM: `[___] kg  ☐ 모름`
- 벤치프레스 1RM: `[___] kg  ☐ 모름`
- 데드리프트 1RM: `[___] kg  ☐ 모름`
- "모름" 체크 시 해당 필드 비활성 + null 전송
- [완료]

완료 액션: `POST /me/onboarding` 호출 → 응답 받아 Step 5로.

**Step 5-A: 결과 화면 (자동 산정 성공)**
```
회원님의 코칭 등급은

    🥈 중급

자동 산정됨

📝 중급 사용자에게는...
  (등급별 피드백 차이 안내)

⚙️ 언제든지 [설정]에서
   변경할 수 있어요

[확인]
```

**Step 5-B: 결과 화면 (default fallback — 정보 부족)**
```
회원님은 일단

    🥉 초급으로

시작할게요

ℹ️ 자동 산정을 못 한 이유:
  • 3대 중량을 한 종목도
    입력하지 않으셨어요.
    한 종목이라도 입력하시면
    등급이 결정돼요.
  • (체중이 없으면 추가 안내)

📝 초급 사용자에게는 매우 상세한
   자세 교정과 친절한 설명을 드려요.

⚙️ 언제든지 [설정]에서
   정보를 채우거나 등급을
   변경할 수 있어요

[확인]
```

`level_source`가 `"auto"`면 5-A, `"default"`면 5-B를 표시한다. 5-B는 응답의 `missing_reasons[].message`를 그대로 불릿으로 렌더링한다.

"나중에 (초급자로 설정)" 버튼을 눌러 명시적으로 스킵한 경우에도 같은 5-B 화면을 보여주되, `missing_reasons` 대신 "직접 건너뛰기를 선택하셨어요" 한 줄 메시지를 표시한다 (이를 위해 백엔드는 스킵 호출인지 구분할 수 있도록 빈 본문 vs 모든 필드 명시 null을 동일 처리하고, 클라이언트에서 표시 분기).

---

## 6. 회원 페이지 인라인 등급 설정

`rexx_app/lib/pages/member.dart`에 "코칭 등급 설정" 섹션을 추가한다.

```
┌──────────────────────────────────┐
│ 코칭 등급                  🥈 중급 │
│ ─────────────────────────────────│
│ 현재 등급: 중급 (자동 산정)       │
│                                  │
│ ○ 초급 — 매우 상세한 피드백        │
│ ● 중급 — 간결한 자세 교정          │
│ ○ 상급 — 핵심 위주, 미세 조정만    │
│                                  │
│ [신체정보·1RM 다시 입력하기 →]    │
└──────────────────────────────────┘
```

**동작:**
- 라디오 직접 선택 → `PUT /me/level` (`level_source="manual"`)
- "다시 입력하기" → 온보딩 플로우 재실행 (Step 2부터, 기존 값 prefill)

---

## 7. AI 피드백 연동

`gemini_service.py:7-30`이 이미 `user_level`을 받아 분기 처리 중이다. 추가 작업 없음. `routers/pose_feedback.py`가 `current_user.level`을 Gemini 호출 시 정확히 전달하는지 검증만 하면 된다.

---

## 8. 에러 처리

### 백엔드

| 시나리오 | 처리 |
|---|---|
| 음수/0/비현실적 1RM (예: 1000kg) | Pydantic validator로 거부 → 400 + 한국어 메시지 |
| 출생연도 1900 미만 또는 미래 | Pydantic validator로 거부 → 400 |
| 체중 미입력 + 1RM 입력됨 | 산정 불가, default 처리 + `missing_reasons: ["missing_body_weight"]` 응답 포함 |
| `level_calculator` 내부 예외 | try/except로 감싸 default fallback. 서버 로그 + 200 응답 + `missing_reasons: ["internal_error"]` |
| 마이그레이션 실패 (이미 컬럼 존재) | `IF NOT EXISTS` 또는 try/except로 부팅 차단 방지 |
| 같은 유저가 두 번 onboarding 호출 | 멱등 — 마지막 호출 결과로 덮어쓰기 |

### Flutter

| 시나리오 | 처리 |
|---|---|
| 온보딩 중 네트워크 오류 | "지금은 저장할 수 없어요. 나중에 설정에서 입력할 수 있어요" + 홈 이동 |
| `GET /me/onboarding-status` 실패 | 온보딩 화면 미표시 (조용히 실패, 다음 부팅 재시도) |
| 1RM 필드에 숫자 아닌 값 | `TextInputType.number` + form validator |
| 회원 페이지 등급 변경 PUT 실패 | 이전 값 롤백 + 토스트 |

---

## 9. 테스트 계획

### 백엔드 신규 테스트

**`tests/test_level_calculator.py`**
- 70kg 남성 / 100·70·140 → 중급
- 60kg 여성 / 80·40·100 → 자동 산정 검증
- `lt_6m` + Advanced 1RM → 초급으로 강제
- `6m_2y` + Elite 1RM → 중급으로 강제
- 부분 입력 (스쿼트만) → 한 종목 기준 산정
- 모두 None → `LevelCalculationFailure(missing_reasons=["no_lift_inputs"])` 반환
- 체중 None + 1RM 일부 있음 → `LevelCalculationFailure(missing_reasons=["missing_body_weight"])` 반환
- 체중 None + 1RM 전부 None → `LevelCalculationFailure(missing_reasons=["missing_body_weight", "no_lift_inputs"])` 반환 (둘 다 나열)
- 성별 None → male 표준 사용
- 체중 30kg / 200kg → clamp 동작
- 컷오프 경계: 1.99→초급, 2.0→중급, 3.49→중급, 3.5→상급

**`tests/test_onboarding_endpoint.py`**
- 정상 전체 입력 → 200 + auto
- 모두 null → 200 + default + `missing_reasons` 두 사유 포함
- 체중만 null + 1RM 입력 → 200 + default + `missing_body_weight` 단독
- 체중 있음 + 1RM 셋 다 null → 200 + default + `no_lift_inputs` 단독
- 부분 입력 (체중 + 1RM 일부) → 200 + auto + `missing_reasons` 빈 배열
- 음수 1RM → 400
- 비현실적 출생연도 → 400
- 인증 없음 → 401
- 두 번 호출 → 멱등
- `GET /me/onboarding-status` — 신규 true / 완료 false

**`tests/test_user_migration.py` (확장)**
- 신규 컬럼 7개가 startup 시 자동 추가
- 두 번째 부팅 시 중복 추가 시도 → 무시

### Flutter 신규 테스트

**`test/onboarding_flow_test.dart`**
- 5단계 PageView 네비게이션
- "나중에 (초급자로 설정)" → 모두 null POST + Step 5-B 표시 ("직접 건너뛰기" 메시지)
- "모름" 체크 시 1RM 필드 비활성 + null 전송
- Step 5-A: 자동 산정 응답이 등급/게이지/피드백 안내 정확히 표시
- Step 5-B: `missing_reasons` 배열의 message가 불릿 리스트로 정확히 렌더링됨
- 응답에 `missing_reasons`가 두 개 있을 때 두 줄 모두 표시

**`test/level_settings_test.dart`**
- Member 페이지 등급 라디오 → PUT + `level_source="manual"`
- "다시 입력하기" → 온보딩 재실행 + prefill 검증

---

## 10. 변경 영향 범위

| 파일 | 변경 |
|---|---|
| `rexx_server/auth.py` | User 모델에 컬럼 7개 추가 + 마이그레이션 함수 |
| `rexx_server/main.py` | startup에서 `ensure_user_columns()` 호출, `PUT /me/level`에 `level_source` 갱신 추가 |
| `rexx_server/services/level_calculator.py` | **신규** |
| `rexx_server/data/strength_standards.py` | **신규** (하드코딩 표준 테이블) |
| `rexx_server/routers/onboarding.py` | **신규** (`POST /me/onboarding`, `GET /me/onboarding-status`) |
| `rexx_server/schemas/onboarding_schemas.py` | **신규** (Pydantic 모델 + validator) |
| `rexx_server/tests/test_level_calculator.py` | **신규** |
| `rexx_server/tests/test_onboarding_endpoint.py` | **신규** |
| `rexx_app/lib/features/onboarding/` | **신규 디렉토리** (5단계 화면 + 라우터) |
| `rexx_app/lib/services/auth_service.dart` | `getOnboardingStatus()`, `submitOnboarding()`, `updateLevel()` 추가 |
| `rexx_app/lib/pages/home_screen.dart` | 부팅 시 onboarding-status 체크 + 라우팅 |
| `rexx_app/lib/pages/member.dart` | 등급 설정 인라인 섹션 추가 |
| `rexx_app/test/onboarding_flow_test.dart` | **신규** |
| `rexx_app/test/level_settings_test.dart` | **신규** |

---

## 11. 배포 고려사항

- **Railway CLI 불필요**: DB 자가 마이그레이션이 startup hook에서 자동 실행되므로 git push만으로 완료된다.
- **새 환경변수 없음**: 기존 `DATABASE_URL`, `GEMINI_API_KEY`만 사용.
- **롤백 안전성**: 신규 컬럼이 모두 nullable이므로 코드만 되돌려도 DB 정합성 유지.
- **기존 사용자**: `level_source IS NULL`이라 다음 로그인 때 온보딩 화면이 한 번 뜬다. "나중에"로 스킵 가능.
