# 비로그인 AI 피드백 & 회원가입 유도 팝업 구현 계획

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비로그인 사용자도 AI 코칭을 2회까지 체험할 수 있게 하고, 결과 화면에서 나갈 때 점수별 맞춤 회원가입 유도 팝업을 표시한다.

**Architecture:** 서버의 `/api/pose/feedback` 엔드포인트에 optional 인증을 추가하고, 앱의 `PoseFeedbackService`에서 게스트 횟수를 관리한다. `PoseResultScreen`에서 비로그인 사용자의 나가기를 `PopScope`로 가로채고 `SignupPromptSheet` BottomSheet를 표시한다.

**Tech Stack:** FastAPI (Python), Flutter (Dart), SharedPreferences, slowapi (rate limiting)

**Spec:** `docs/superpowers/specs/2026-03-14-guest-ai-feedback-signup-prompt-design.md`

---

## Chunk 1: 서버 변경

### Task 1: 서버 rate limiting 의존성 추가

**Files:**
- Modify: `rexx_server/requirements.txt`

- [ ] **Step 1: requirements.txt에 slowapi 추가**

`rexx_server/requirements.txt` 끝에 추가:
```
slowapi
```

- [ ] **Step 2: 의존성 설치 확인**

Run: `cd rexx_server && source venv/bin/activate && pip install -r requirements.txt`
Expected: slowapi 설치 성공

- [ ] **Step 3: 커밋**

```bash
git add rexx_server/requirements.txt
git commit -m "chore: slowapi 의존성 추가 (비인증 rate limiting용)"
```

---

### Task 2: PoseFeedbackResponse 스키마 수정

**Files:**
- Modify: `rexx_server/schemas/pose_schemas.py:21-24`

- [ ] **Step 1: session_id를 Optional로 변경**

`rexx_server/schemas/pose_schemas.py` 21-24번 줄을 수정:

```python
class PoseFeedbackResponse(BaseModel):
    success: bool
    feedback: str
    session_id: Optional[int] = None
```

- [ ] **Step 2: 커밋**

```bash
git add rexx_server/schemas/pose_schemas.py
git commit -m "feat: PoseFeedbackResponse.session_id를 Optional로 변경 (게스트 지원)"
```

---

### Task 3: get_optional_current_user 함수 추가

**Files:**
- Modify: `rexx_server/auth.py`

- [ ] **Step 1: auto_error=False OAuth2 인스턴스와 get_optional_current_user 추가**

`rexx_server/auth.py`에서 기존 `oauth2_scheme` 정의(22번 줄) 바로 아래에 추가:

```python
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)
```

파일 맨 끝(80번 줄 이후)에 추가:

```python
def get_optional_current_user(
    token: Optional[str] = Depends(oauth2_scheme_optional),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """토큰이 없으면 None 반환, 있으면 기존 인증 로직 수행."""
    if token is None:
        return None

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str | None = payload.get("sub")
        if email is None:
            return None
    except JWTError:
        return None

    user = get_user_by_email(db, email)
    return user
```

- [ ] **Step 2: 커밋**

```bash
git add rexx_server/auth.py
git commit -m "feat: get_optional_current_user 추가 (비인증 요청 시 None 반환)"
```

---

### Task 4: /feedback 엔드포인트에 optional 인증 + rate limiting 적용

**Files:**
- Modify: `rexx_server/routers/pose_feedback.py:1-61`

- [ ] **Step 1: import 및 rate limiter 설정 추가**

`rexx_server/routers/pose_feedback.py`의 import 영역(1-20번 줄)을 수정:

```python
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
from services.haiku_service import generate_feedback

# 테이블 생성
Base.metadata.create_all(bind=engine)

limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/api/pose", tags=["pose"])
```

- [ ] **Step 2: create_feedback 함수를 optional 인증으로 수정**

기존 `create_feedback` 함수(28-61번 줄)를 다음으로 교체:

```python
@router.post("/feedback", response_model=PoseFeedbackResponse)
@limiter.limit("5/minute")
def create_feedback(
    request: Request,
    data: PoseFeedbackRequest,
    current_user: User | None = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
):
    # Claude Haiku로 피드백 생성
    feedback_text = generate_feedback(
        exercise_type=data.exercise_type,
        total_score=data.total_score,
        criteria_scores=[c.model_dump() for c in data.criteria_scores],
        detected_issues=data.detected_issues,
    )

    session_id = None

    # 로그인 사용자만 DB 저장
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
```

- [ ] **Step 3: main.py에 slowapi 미들웨어 등록**

`rexx_server/main.py`에서 FastAPI app 생성 후, slowapi의 에러 핸들러를 등록해야 합니다. app 생성 코드 아래에 추가:

```python
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from routers.pose_feedback import limiter

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
```

- [ ] **Step 4: 서버 실행 테스트**

Run: `cd rexx_server && source venv/bin/activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000`
Expected: 서버 정상 시작, 에러 없음

- [ ] **Step 5: 커밋**

```bash
git add rexx_server/routers/pose_feedback.py rexx_server/main.py
git commit -m "feat: /feedback 엔드포인트 비인증 허용 + IP rate limiting 적용"
```

---

## Chunk 2: 앱 서비스 레이어 변경

### Task 5: FeedbackError에 guestLimitReached 추가

**Files:**
- Modify: `rexx_app/lib/services/pose_feedback_service.dart:21-49`

- [ ] **Step 1: enum에 guestLimitReached 추가**

`rexx_app/lib/services/pose_feedback_service.dart` 21-32번 줄의 `FeedbackError` enum에 값 추가:

```dart
enum FeedbackError {
  /// 기기가 오프라인 상태
  offline,
  /// 로그인 토큰 없음
  noToken,
  /// 서버에 연결되었으나 API 처리 실패 (Claude API 오류 등)
  apiError,
  /// 요청 시간 초과
  timeout,
  /// 게스트 무료 체험 횟수 소진
  guestLimitReached,
  /// 알 수 없는 오류
  unknown,
}
```

- [ ] **Step 2: extension에 guestLimitReached 메시지 추가**

34-49번 줄의 `FeedbackErrorMessage` extension의 switch문에 추가:

```dart
extension FeedbackErrorMessage on FeedbackError {
  String get message {
    switch (this) {
      case FeedbackError.offline:
        return '인터넷 연결이 되어 있지 않습니다.';
      case FeedbackError.noToken:
        return '로그인이 필요합니다. 다시 로그인해 주세요.';
      case FeedbackError.apiError:
        return '서버에서 AI 피드백을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      case FeedbackError.timeout:
        return '서버 응답 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.';
      case FeedbackError.guestLimitReached:
        return '무료 AI 코칭 체험이 끝났습니다. 회원가입하면 계속 이용할 수 있어요!';
      case FeedbackError.unknown:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }
}
```

- [ ] **Step 3: 커밋**

```bash
cd rexx_app && git add lib/services/pose_feedback_service.dart
git commit -m "feat: FeedbackError.guestLimitReached 열거형 값 추가"
```

---

### Task 6: PoseFeedbackService에 게스트 피드백 로직 추가

**Files:**
- Modify: `rexx_app/lib/services/pose_feedback_service.dart:55-109`

- [ ] **Step 1: 게스트 카운트 관리 메서드 추가**

`PoseFeedbackService` 클래스(52번 줄) 안에, `requestFeedback` 메서드 앞에 게스트 관련 상수와 메서드 추가:

```dart
class PoseFeedbackService {
  static const int _maxGuestFeedbackCount = 2;
  static const String _guestCountKey = 'guest_feedback_count';

  /// 게스트 AI 피드백 남은 횟수 확인
  Future<bool> canUseGuestFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_guestCountKey) ?? 0;
    return count < _maxGuestFeedbackCount;
  }

  /// 게스트 사용 횟수 증가 (성공 시에만 호출)
  Future<void> _incrementGuestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_guestCountKey) ?? 0;
    await prefs.setInt(_guestCountKey, count + 1);
  }
```

- [ ] **Step 2: requestFeedback에서 토큰 null 처리 로직 수정**

기존 `requestFeedback` 메서드의 토큰 확인 부분(59-64번 줄)을 게스트 로직으로 교체:

기존 코드:
```dart
    // 1. 토큰 확인
    if (token == null) {
      debugPrint('[PoseFeedbackService] ❌ 토큰 없음');
      await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.noToken);
    }
```

새 코드:
```dart
    // 1. 토큰 확인 — 게스트 모드 처리
    final bool isGuest = token == null;
    if (isGuest) {
      final canUse = await canUseGuestFeedback();
      if (!canUse) {
        debugPrint('[PoseFeedbackService] ❌ 게스트 무료 체험 소진');
        return FeedbackResult.failure(FeedbackError.guestLimitReached);
      }
      debugPrint('[PoseFeedbackService] 🎁 게스트 무료 체험 모드');
    }
```

- [ ] **Step 3: 오프라인 체크에서 게스트 큐잉 제외**

기존 connectivity 체크 부분(66-72번 줄)을 수정:

기존 코드:
```dart
    // 2. 서버 연결 확인
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      debugPrint('[PoseFeedbackService] ❌ 오프라인 상태');
      await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.offline);
    }
```

새 코드:
```dart
    // 2. 서버 연결 확인
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      debugPrint('[PoseFeedbackService] ❌ 오프라인 상태');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.offline);
    }
```

- [ ] **Step 4: API 호출 시 토큰 없으면 Authorization 헤더 제외**

기존 HTTP 요청 부분(76-83번 줄)의 headers 생성을 조건부로 변경:

기존 코드:
```dart
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/pose/feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(result.toJson()),
      ).timeout(const Duration(seconds: 30));
```

새 코드:
```dart
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/pose/feedback'),
        headers: headers,
        body: jsonEncode(result.toJson()),
      ).timeout(const Duration(seconds: 30));
```

- [ ] **Step 5: 성공 시 게스트 카운트 증가 로직 추가**

기존 성공 처리 부분(85-89번 줄)을 수정:

기존 코드:
```dart
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedback = data['feedback'] as String?;
        debugPrint('[PoseFeedbackService] ✅ AI 피드백 수신 성공');
        return FeedbackResult.success(feedback);
      }
```

새 코드:
```dart
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedback = data['feedback'] as String?;
        if (isGuest) {
          await _incrementGuestCount();
          debugPrint('[PoseFeedbackService] ✅ 게스트 AI 피드백 수신 성공 (카운트 증가)');
        } else {
          debugPrint('[PoseFeedbackService] ✅ AI 피드백 수신 성공');
        }
        return FeedbackResult.success(feedback);
      }
```

- [ ] **Step 6: 게스트 오프라인 큐잉 제외 (catch 블록)**

오류 처리 부분에서 `_saveToQueue`를 게스트일 때 호출하지 않도록 변경. 기존 catch 블록들(96-108번 줄)을 수정:

기존 코드:
```dart
    } on TimeoutException {
      debugPrint('[PoseFeedbackService] ❌ 요청 시간 초과');
      await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.timeout);
    } on SocketException catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 네트워크 연결 실패: $e');
      await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.offline);
    } catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 알 수 없는 오류: $e');
      await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.unknown);
    }
```

새 코드:
```dart
    } on TimeoutException {
      debugPrint('[PoseFeedbackService] ❌ 요청 시간 초과');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.timeout);
    } on SocketException catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 네트워크 연결 실패: $e');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.offline);
    } catch (e) {
      debugPrint('[PoseFeedbackService] ❌ 알 수 없는 오류: $e');
      if (!isGuest) await _saveToQueue(result);
      return FeedbackResult.failure(FeedbackError.unknown);
    }
```

- [ ] **Step 7: 커밋**

```bash
cd rexx_app && git add lib/services/pose_feedback_service.dart
git commit -m "feat: PoseFeedbackService 게스트 피드백 로직 추가 (2회 무료 체험)"
```

---

## Chunk 3: 앱 화면 변경 (네비게이션 + 결과 화면)

### Task 7: FeedbackCard에 guestLimitReached 에러 표시 추가

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart:107-146`

- [ ] **Step 1: _getErrorInfo()에 guestLimitReached 케이스 추가**

`feedback_card.dart`의 `_getErrorInfo()` 메서드(107번 줄)의 switch문에서, `case FeedbackError.unknown:` 앞에 추가:

```dart
      case FeedbackError.guestLimitReached:
        return _ErrorInfo(
          icon: Icons.card_giftcard,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          message: '무료 AI 코칭 체험이 끝났어요. 회원가입하면 무제한으로 이용할 수 있습니다!',
        );
```

- [ ] **Step 2: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/widgets/feedback_card.dart
git commit -m "feat: FeedbackCard에 guestLimitReached 에러 표시 추가"
```

---

### Task 8: VideoUploadScreen에서 PoseResultScreen에 token 전달

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart:108-113`

- [ ] **Step 1: PoseResultScreen 생성 시 token 전달**

`video_upload_screen.dart` 108-113번 줄 수정:

기존 코드:
```dart
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PoseResultScreen(result: finalResult),
        ),
      );
```

새 코드:
```dart
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PoseResultScreen(
            result: finalResult,
            token: widget.token,
          ),
        ),
      );
```

- [ ] **Step 2: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/screens/video_upload_screen.dart
git commit -m "feat: VideoUploadScreen에서 PoseResultScreen에 token 전달"
```

---

### Task 9: SignupPromptSheet 위젯 생성

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/widgets/signup_prompt_sheet.dart`

- [ ] **Step 1: SignupPromptSheet 위젯 파일 생성**

```dart
import 'package:flutter/material.dart';

/// 비로그인 사용자에게 회원가입을 유도하는 BottomSheet 위젯.
/// 점수에 따라 다른 메시지를 표시하고, "나중에" 클릭 시 2차 확인을 보여준다.
class SignupPromptSheet extends StatefulWidget {
  final int totalScore;

  const SignupPromptSheet({super.key, required this.totalScore});

  /// BottomSheet를 표시하고, 사용자의 선택을 반환한다.
  /// - true: 회원가입 선택
  /// - false: 나가기 선택
  /// - null: 시트가 닫힘 (외부 탭 등)
  static Future<bool?> show(BuildContext context, int totalScore) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SignupPromptSheet(totalScore: totalScore),
    );
  }

  @override
  State<SignupPromptSheet> createState() => _SignupPromptSheetState();
}

class _SignupPromptSheetState extends State<SignupPromptSheet> {
  static const Color bg = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  bool _showConfirmation = false;

  _PromptContent get _content {
    if (widget.totalScore >= 70) {
      return _PromptContent(
        icon: Icons.emoji_events,
        iconColor: const Color(0xFFFFD700),
        header: '축하합니다! 상위 랭커의 자질이 보여요',
        subMessage: '회원가입하고 랭킹에 이름을 올리세요',
        illustration: _buildRankingPreview(),
      );
    } else if (widget.totalScore >= 50) {
      return _PromptContent(
        icon: Icons.trending_up,
        iconColor: primary,
        header: '좋은 시작이에요!',
        subMessage: '첫 기록을 저장하고 성장을 추적하세요',
        illustration: _buildGrowthGraph(),
      );
    } else {
      return _PromptContent(
        icon: Icons.local_fire_department,
        iconColor: const Color(0xFFF97316),
        header: '모든 챔피언은 여기서 시작했어요',
        subMessage: 'AI 코치가 함께할게요. 시작해볼까요?',
        illustration: _buildEncouragement(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: _showConfirmation ? _buildConfirmation() : _buildMainPrompt(),
    );
  }

  Widget _buildMainPrompt() {
    final content = _content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),

        // 아이콘
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: content.iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(content.icon, color: content.iconColor, size: 32),
        ),
        const SizedBox(height: 20),

        // 헤더
        Text(
          content.header,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textMain,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // 서브 메시지
        Text(
          content.subMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: textSub, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),

        // 시각 요소
        content.illustration,
        const SizedBox(height: 28),

        // 메인 CTA 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '회원가입하고 기록 저장하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 나중에 버튼
        TextButton(
          onPressed: () {
            setState(() => _showConfirmation = true);
          },
          child: const Text(
            '나중에',
            style: TextStyle(color: textSub, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),

        // 경고 아이콘
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.history,
            color: Color(0xFFF59E0B),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          '이 기록은 저장되지 않아요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        const Text(
          '다음에 또 처음부터 시작해야 해요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSub, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),

        // 역시 가입할게요 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '역시 가입할게요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 그래도 나가기 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: textSub,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '그래도 나가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  /// 70+ 점수: 흐릿한 랭킹 보드 미리보기
  Widget _buildRankingPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Text(
            '실시간 랭킹',
            style: TextStyle(
              color: textSub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // 흐릿한 랭킹 항목들
          for (int i = 0; i < 3; i++) ...[
            Opacity(
              opacity: 0.4 - (i * 0.1),
              child: Container(
                height: 36,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFFFFD700).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? const Color(0xFFFFD700) : textSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: textSub, size: 14),
              const SizedBox(width: 4),
              Text(
                '회원가입 후 확인 가능',
                style: TextStyle(
                  color: textSub.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 50-69 점수: 성장 그래프 일러스트
  Widget _buildGrowthGraph() {
    return Container(
      width: double.infinity,
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildGraphBar('오늘', widget.totalScore / 100, primary),
          _buildGraphBar('2주 후', (widget.totalScore + 15) / 100, primary.withValues(alpha: 0.6)),
          _buildGraphBar('1개월', (widget.totalScore + 25) / 100, primary.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildGraphBar(String label, double ratio, Color color) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 50 * clampedRatio,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: textSub, fontSize: 11),
        ),
      ],
    );
  }

  /// 0-49 점수: 격려 메시지
  Widget _buildEncouragement() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.1),
        ),
      ),
      child: const Row(
        children: [
          Text('💪', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI 코치의 맞춤 피드백으로\n더 빠르게 성장할 수 있어요',
              style: TextStyle(
                color: textMain,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptContent {
  final IconData icon;
  final Color iconColor;
  final String header;
  final String subMessage;
  final Widget illustration;

  const _PromptContent({
    required this.icon,
    required this.iconColor,
    required this.header,
    required this.subMessage,
    required this.illustration,
  });
}
```

- [ ] **Step 2: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/widgets/signup_prompt_sheet.dart
git commit -m "feat: SignupPromptSheet 위젯 생성 (점수별 메시지 + 2차 확인)"
```

---

### Task 10: PoseResultScreen에 token 파라미터 추가 + 나가기 가로채기

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart`

- [ ] **Step 1: PoseResultScreen을 StatefulWidget으로 변경하고 token 추가, PopScope + 팝업 로직 적용**

`pose_result_screen.dart` 전체를 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import '../models/evaluation_result.dart';
import '../widgets/score_gauge.dart';
import '../widgets/criterion_breakdown.dart';
import '../widgets/feedback_card.dart';
import '../widgets/signup_prompt_sheet.dart';
import '../../../pages/login_page.dart';

class PoseResultScreen extends StatefulWidget {
  final EvaluationResult result;
  final String? token;

  const PoseResultScreen({
    super.key,
    required this.result,
    this.token,
  });

  @override
  State<PoseResultScreen> createState() => _PoseResultScreenState();
}

class _PoseResultScreenState extends State<PoseResultScreen> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  bool get _isGuest => widget.token == null;

  /// 회원가입 유도 팝업을 표시하고 결과에 따라 처리
  Future<bool> _handleGuestExit() async {
    final result = await SignupPromptSheet.show(
      context,
      widget.result.totalScore,
    );

    if (!mounted) return false;

    if (result == true) {
      // 회원가입 선택 → LoginPage로 이동
      final loginResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

      if (loginResult != null && mounted) {
        // 가입/로그인 성공 → 홈으로 돌아가기
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      return false; // 이미 네비게이션 처리됨
    } else if (result == false) {
      // "그래도 나가기" 선택
      return true;
    }

    // null (시트 닫힘) — 아무 것도 안 함
    return false;
  }

  void _onHomePressed() async {
    if (_isGuest) {
      final shouldExit = await _handleGuestExit();
      if (shouldExit && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isGuest,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleGuestExit();
        if (shouldExit && mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: textMain,
          title: Text(
            '${widget.result.exerciseType.displayName} 평가 결과',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 원형 점수 게이지
              ScoreGauge(score: widget.result.totalScore),
              const SizedBox(height: 30),

              // LLM 피드백 카드
              FeedbackCard(
                feedbackText: widget.result.feedbackText,
                offlineFeedback: widget.result.offlineFeedback,
                error: widget.result.feedbackError,
              ),
              const SizedBox(height: 24),

              // 기준별 상세 점수
              CriterionBreakdown(criteria: widget.result.criteria),
              const SizedBox(height: 30),

              // 홈으로 돌아가기
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onHomePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/screens/pose_result_screen.dart
git commit -m "feat: PoseResultScreen에 게스트 나가기 가로채기 + 회원가입 유도 팝업"
```

---

### Task 11: Flutter 정적 분석 확인

- [ ] **Step 1: flutter analyze 실행**

Run: `cd rexx_app && flutter analyze`
Expected: 에러 없음 (warning은 허용)

- [ ] **Step 2: 문제가 있으면 수정 후 커밋**

---

## 요약

| Task | 파일 | 내용 |
|------|------|------|
| 1 | `requirements.txt` | slowapi 의존성 추가 |
| 2 | `schemas/pose_schemas.py` | session_id Optional |
| 3 | `auth.py` | get_optional_current_user |
| 4 | `routers/pose_feedback.py`, `main.py` | 비인증 허용 + rate limiting |
| 5 | `pose_feedback_service.dart` | guestLimitReached enum |
| 6 | `pose_feedback_service.dart` | 게스트 피드백 로직 |
| 7 | `feedback_card.dart` | guestLimitReached 표시 |
| 8 | `video_upload_screen.dart` | token 전달 |
| 9 | `signup_prompt_sheet.dart` | 신규 위젯 |
| 10 | `pose_result_screen.dart` | PopScope + 팝업 |
| 11 | - | flutter analyze 확인 |

> **참고:** `home_screen.dart`는 이미 `token`을 nullable로 전달하고 있어 변경 불필요.
