# 로그인 & 회원가입 리디자인 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign login screen (trust indicators + social UI) and signup screen (3-step wizard with progress bar) for the Rexx Strength fitness app.

**Architecture:** Backend-first approach — extend User model and /register API with new fields (height, weight, is_body_public, interests), then build Flutter UI. Login page becomes a standalone screen with branding + social buttons (UI only). Signup becomes a 3-step wizard using PageView with shared state.

**Tech Stack:** Flutter (Dart), FastAPI (Python), SQLAlchemy, SQLite

**Spec:** `docs/superpowers/specs/2026-03-14-login-signup-redesign-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `rexx_app/lib/pages/signup/signup_page.dart` | Wizard container — PageView + progress bar + shared signup state |
| `rexx_app/lib/pages/signup/step1_account.dart` | Step 1 — email, password, password confirm with real-time validation chips |
| `rexx_app/lib/pages/signup/step2_profile.dart` | Step 2 — nickname, height/weight, body info privacy toggle |
| `rexx_app/lib/pages/signup/step3_interests.dart` | Step 3 — circular exercise selection grid + reaction bubble |
| `docs/social-login-implementation-guide.md` | OAuth implementation guide for future social login |

### Modified Files
| File | Changes |
|------|---------|
| `rexx_server/auth.py:29-35` | Add height, weight, is_body_public, interests columns to User model |
| `rexx_server/main.py:44-65` | Extend RegisterRequest, UserResponse, AuthResponse with new fields; update /register, /login, /me responses |
| `rexx_app/lib/services/auth_service.dart:35-65` | Add new fields to register() method |
| `rexx_app/lib/pages/login_page.dart` | Complete rewrite — trust indicators, social buttons, new layout |
| `rexx_app/lib/pages/home_screen.dart:433-458` | Update navigation to use new LoginPage/SignupPage |

---

## Chunk 1: Backend — User Model & API Extension

### Task 1: Extend User Model

**Files:**
- Modify: `rexx_server/auth.py:29-35`

- [ ] **Step 1: Add new columns to User model**

In `rexx_server/auth.py`, add imports and columns:

```python
from sqlalchemy import Column, Integer, String, Float, Boolean, Text
```

Add to the User class after `hashed_password`:

```python
    height = Column(Float, nullable=True)
    weight = Column(Float, nullable=True)
    is_body_public = Column(Boolean, default=False, nullable=False)
    interests = Column(Text, nullable=True)  # JSON array string e.g. '["powerlifting","bodyweight"]'
```

- [ ] **Step 2: Delete old test.db to force schema recreation**

```bash
rm -f rexx_server/test.db
```

- [ ] **Step 3: Verify server starts and creates new schema**

```bash
cd rexx_server && source venv/bin/activate && python -c "from database import engine, Base; from auth import User; Base.metadata.create_all(bind=engine); print('OK')"
```

Expected: `OK` with no errors.

- [ ] **Step 4: Commit**

```bash
git add rexx_server/auth.py
git commit -m "feat(backend): User 모델에 height, weight, is_body_public, interests 필드 추가"
```

### Task 2: Extend API Schemas and Endpoints

**Files:**
- Modify: `rexx_server/main.py:44-65` (Pydantic models)
- Modify: `rexx_server/main.py:81-106` (/register endpoint)
- Modify: `rexx_server/main.py:111-130` (/login response)
- Modify: `rexx_server/main.py:135-144` (/me response)

- [ ] **Step 1: Update Pydantic schemas**

Replace the schema section in `main.py`:

```python
from typing import Optional, List

class RegisterRequest(BaseModel):
    username: str
    email: EmailStr
    password: str
    height: Optional[float] = None
    weight: Optional[float] = None
    is_body_public: Optional[bool] = False
    interests: Optional[List[str]] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    height: Optional[float] = None
    weight: Optional[float] = None
    is_body_public: bool = False
    interests: Optional[List[str]] = None

class AuthResponse(BaseModel):
    success: bool
    token: str
    user: UserResponse

class MeResponse(BaseModel):
    success: bool
    user: UserResponse
```

- [ ] **Step 2: Update /register endpoint to save new fields**

```python
import json

@app.post("/register", response_model=AuthResponse)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = get_user_by_email(db, data.email)
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 존재하는 이메일입니다.")

    new_user = User(
        username=data.username,
        email=data.email,
        hashed_password=hash_password(data.password),
        height=data.height,
        weight=data.weight,
        is_body_public=data.is_body_public if data.is_body_public is not None else False,
        interests=json.dumps(data.interests) if data.interests else None,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    access_token = create_access_token(data={"sub": new_user.email})

    return {
        "success": True,
        "token": access_token,
        "user": _user_response(new_user),
    }
```

- [ ] **Step 3: Add helper function and update /login and /me responses**

Add helper function before the endpoints:

```python
def _user_response(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "height": user.height,
        "weight": user.weight,
        "is_body_public": user.is_body_public,
        "interests": json.loads(user.interests) if user.interests else None,
    }
```

Update /login return:
```python
    return {
        "success": True,
        "token": access_token,
        "user": _user_response(user),
    }
```

Update /me return:
```python
    return {
        "success": True,
        "user": _user_response(current_user),
    }
```

- [ ] **Step 4: Test endpoints with curl**

```bash
# Start server
cd rexx_server && source venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8000 &
sleep 2

# Register with new fields
curl -s -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"username":"테스트","email":"test@test.com","password":"test1234","height":175.0,"weight":70.0,"is_body_public":false,"interests":["powerlifting","bodyweight"]}'

# Login
curl -s -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test1234"}'

# Kill server
kill %1
```

Expected: Both return JSON with new fields in user object.

- [ ] **Step 5: Commit**

```bash
git add rexx_server/main.py
git commit -m "feat(backend): /register, /login, /me API에 신체정보 및 관심운동 필드 추가"
```

---

## Chunk 2: Flutter — AuthService & Login Page

### Task 3: Update AuthService

**Files:**
- Modify: `rexx_app/lib/services/auth_service.dart`

- [ ] **Step 1: Extend register() method with new parameters**

```dart
Future<Map<String, dynamic>> register({
  required String username,
  required String email,
  required String password,
  double? height,
  double? weight,
  bool? isBodyPublic,
  List<String>? interests,
}) async {
  try {
    debugPrint('[AuthService] 회원가입 요청: ${ApiConfig.baseUrl}/register');

    final body = <String, dynamic>{
      "username": username,
      "email": email,
      "password": password,
    };
    if (height != null) body["height"] = height;
    if (weight != null) body["weight"] = weight;
    if (isBodyPublic != null) body["is_body_public"] = isBodyPublic;
    if (interests != null) body["interests"] = interests;

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    debugPrint('[AuthService] 회원가입 응답: ${response.statusCode}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final detail = jsonDecode(response.body)['detail'] ?? '회원가입 실패';
      throw Exception(detail);
    }
  } on SocketException catch (e) {
    debugPrint('[AuthService] 네트워크 연결 오류: $e');
    throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
  } catch (e) {
    debugPrint('[AuthService] 회원가입 오류: $e');
    rethrow;
  }
}
```

Also update `login()` to parse error detail:

```dart
} else {
  final detail = jsonDecode(response.body)['detail'] ?? '로그인 실패';
  throw Exception(detail);
}
```

- [ ] **Step 2: Commit**

```bash
git add rexx_app/lib/services/auth_service.dart
git commit -m "feat(flutter): AuthService에 회원가입 신체정보/관심운동 필드 추가"
```

### Task 4: Rewrite Login Page

**Files:**
- Rewrite: `rexx_app/lib/pages/login_page.dart`

- [ ] **Step 1: Rewrite login_page.dart with trust indicators + social buttons**

Complete rewrite of `rexx_app/lib/pages/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  bool loading = false;
  String? errorMessage;

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = '이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await authService.login(email: email, password: password);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  void _goToSignup() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('준비 중입니다'),
        backgroundColor: primary.withOpacity(0.8),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // 앱 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.12),
                  border: Border.all(color: primary.withOpacity(0.25), width: 2),
                ),
                child: const Center(
                  child: Text('💪', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 14),
              // 타이틀
              const Text(
                'REXX Strength',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI 자세 분석 코칭',
                style: TextStyle(fontSize: 13, color: textSub),
              ),
              const SizedBox(height: 20),
              // 신뢰 지표
              _buildTrustIndicators(),
              const SizedBox(height: 32),
              // 에러 메시지
              if (errorMessage != null) _buildErrorBanner(),
              // 입력 필드
              _buildInputField(
                controller: emailController,
                icon: Icons.email_outlined,
                hint: '이메일',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: passwordController,
                icon: Icons.lock_outline,
                hint: '비밀번호',
                obscureText: true,
              ),
              const SizedBox(height: 18),
              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              // 구분선
              _buildDivider(),
              const SizedBox(height: 20),
              // 소셜 로그인 버튼
              _buildSocialButtons(),
              const SizedBox(height: 24),
              // 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '계정이 없으신가요? ',
                    style: TextStyle(fontSize: 13, color: textSub),
                  ),
                  GestureDetector(
                    onTap: _goToSignup,
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStat('1.2K', '활성 사용자'),
        Container(
          width: 1,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: primary.withOpacity(0.15),
        ),
        _buildStat('15K+', '자세 평가'),
        Container(
          width: 1,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: primary.withOpacity(0.15),
        ),
        _buildStat('4.8', '만족도'),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: textSub),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: textSub, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: textSub, fontSize: 13),
        filled: true,
        fillColor: primary.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: primary.withOpacity(0.15))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('또는', style: TextStyle(fontSize: 12, color: textSub)),
        ),
        Expanded(child: Container(height: 1, color: primary.withOpacity(0.15))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(Icons.apple, ''),
        const SizedBox(width: 12),
        _socialButton(null, 'G'),
        const SizedBox(width: 12),
        _socialButton(Icons.chat_bubble, ''),
      ],
    );
  }

  Widget _socialButton(IconData? icon, String text) {
    return GestureDetector(
      onTap: _showComingSoon,
      child: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withOpacity(0.12)),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textSub, size: 22)
              : Text(
                  text,
                  style: const TextStyle(
                    color: textSub,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd rexx_app && flutter analyze lib/pages/login_page.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add rexx_app/lib/pages/login_page.dart
git commit -m "feat(flutter): 로그인 페이지 리디자인 — 신뢰 지표, 소셜 버튼, 에러 처리"
```

---

## Chunk 3: Flutter — Signup Wizard (3 Steps)

### Task 5: Create Signup Page Container

**Files:**
- Create: `rexx_app/lib/pages/signup/signup_page.dart`

- [ ] **Step 1: Create signup directory**

```bash
mkdir -p rexx_app/lib/pages/signup
```

- [ ] **Step 2: Write signup_page.dart — wizard container with progress bar and PageView**

```dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'step1_account.dart';
import 'step2_profile.dart';
import 'step3_interests.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 data
  String email = '';
  String password = '';

  // Step 2 data
  String nickname = '';
  double? height;
  double? weight;
  bool isBodyPublic = false;

  // Step 3 data
  List<String> interests = [];

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    try {
      final result = await AuthService().register(
        username: nickname,
        email: email,
        password: password,
        height: height,
        weight: weight,
        isBodyPublic: isBodyPublic,
        interests: interests,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('이미 존재하는 이메일')) {
        // 이메일 중복 → Step 1로 돌아가기
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('이미 사용 중인 이메일입니다. 다른 이메일을 입력해주세요.'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원가입 실패: $msg'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 뒤로가기 + 프로그레스 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: textSub, size: 20),
                    onPressed: _prevStep,
                  ),
                  Expanded(child: _buildProgressBar()),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 페이지 뷰
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Step1Account(
                    onNext: (e, p) {
                      email = e;
                      password = p;
                      _nextStep();
                    },
                  ),
                  Step2Profile(
                    onNext: (name, h, w, pub) {
                      nickname = name;
                      height = h;
                      weight = w;
                      isBodyPublic = pub;
                      _nextStep();
                    },
                    onPrev: _prevStep,
                  ),
                  Step3Interests(
                    onSubmit: (selected) {
                      interests = selected;
                      _submit();
                    },
                    onPrev: _prevStep,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        _buildDot(0),
        _buildLine(0),
        _buildDot(1),
        _buildLine(1),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int step) {
    final isActive = step == _currentStep;
    final isDone = step < _currentStep;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isActive || isDone) ? primary : primary.withOpacity(0.15),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '${step + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildLine(int afterStep) {
    final isDone = afterStep < _currentStep;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? primary : primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add rexx_app/lib/pages/signup/signup_page.dart
git commit -m "feat(flutter): 회원가입 위저드 컨테이너 — 프로그레스 바 + PageView"
```

### Task 6: Create Step 1 — Account

**Files:**
- Create: `rexx_app/lib/pages/signup/step1_account.dart`

- [ ] **Step 1: Write step1_account.dart**

```dart
import 'package:flutter/material.dart';

class Step1Account extends StatefulWidget {
  final void Function(String email, String password) onNext;

  const Step1Account({super.key, required this.onNext});

  @override
  State<Step1Account> createState() => _Step1AccountState();
}

class _Step1AccountState extends State<Step1Account> {
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  String? _emailError;

  bool get _isLengthOk => _pwCtrl.text.length >= 8;
  bool get _hasAlphaNum =>
      RegExp(r'[a-zA-Z]').hasMatch(_pwCtrl.text) &&
      RegExp(r'[0-9]').hasMatch(_pwCtrl.text);
  bool get _isMatch =>
      _pwCtrl.text.isNotEmpty && _pwCtrl.text == _pwConfirmCtrl.text;
  bool get _isEmailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailCtrl.text.trim());
  bool get _canProceed =>
      _isEmailValid && _isLengthOk && _hasAlphaNum && _isMatch;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onChanged);
    _pwCtrl.addListener(_onChanged);
    _pwConfirmCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {
    if (_emailCtrl.text.isNotEmpty && !_isEmailValid) {
      _emailError = '올바른 이메일 형식을 입력해주세요';
    } else {
      _emailError = null;
    }
  });

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '계정을 만들어볼까요?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '이메일과 비밀번호를 설정해주세요',
            style: TextStyle(fontSize: 13, color: textSub),
          ),
          const SizedBox(height: 28),
          _buildField(_emailCtrl, Icons.email_outlined, '이메일 주소',
              keyboardType: TextInputType.emailAddress, errorText: _emailError),
          const SizedBox(height: 10),
          _buildField(_pwCtrl, Icons.lock_outline, '비밀번호 (8자 이상)',
              obscure: true),
          const SizedBox(height: 10),
          _buildField(_pwConfirmCtrl, Icons.lock_outline, '비밀번호 확인',
              obscure: true),
          const SizedBox(height: 16),
          // 검증 칩
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('8자 이상', _isLengthOk),
              _chip('영문+숫자', _hasAlphaNum),
              _chip('일치', _isMatch),
            ],
          ),
          const SizedBox(height: 24),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canProceed
                  ? () => widget.onNext(
                        _emailCtrl.text.trim(),
                        _pwCtrl.text,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '다음 단계 →',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '이미 계정이 있나요? ',
                  style: TextStyle(fontSize: 12, color: textSub),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: textMain, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: textSub, size: 20),
            hintText: hint,
            hintStyle: const TextStyle(color: textSub, fontSize: 13),
            filled: true,
            fillColor: primary.withOpacity(0.08),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null ? Colors.red : primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null ? Colors.red : primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null ? Colors.red : primary),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? primary.withOpacity(0.15) : primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ok ? '✓ $label' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ok ? primary : textSub,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add rexx_app/lib/pages/signup/step1_account.dart
git commit -m "feat(flutter): 회원가입 Step 1 — 계정 정보 (이메일/비밀번호 실시간 검증)"
```

### Task 7: Create Step 2 — Profile

**Files:**
- Create: `rexx_app/lib/pages/signup/step2_profile.dart`

- [ ] **Step 1: Write step2_profile.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Step2Profile extends StatefulWidget {
  final void Function(String nickname, double? height, double? weight, bool isBodyPublic) onNext;
  final VoidCallback onPrev;

  const Step2Profile({super.key, required this.onNext, required this.onPrev});

  @override
  State<Step2Profile> createState() => _Step2ProfileState();
}

class _Step2ProfileState extends State<Step2Profile> {
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  final _nicknameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _isBodyPublic = false;

  bool get _canProceed {
    final name = _nicknameCtrl.text.trim();
    if (name.length < 2 || name.length > 20) return false;
    // height/weight 선택 입력 — 입력한 경우 범위 체크
    if (_heightCtrl.text.isNotEmpty) {
      final h = double.tryParse(_heightCtrl.text);
      if (h == null || h < 50 || h > 300) return false;
    }
    if (_weightCtrl.text.isNotEmpty) {
      final w = double.tryParse(_weightCtrl.text);
      if (w == null || w < 20 || w > 500) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _nicknameCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
    _weightCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '당신에 대해 알려주세요',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 4),
          const Text(
            '맞춤 피드백을 위한 기본 정보입니다',
            style: TextStyle(fontSize: 13, color: textSub),
          ),
          const SizedBox(height: 28),
          // 닉네임
          _buildField(_nicknameCtrl, Icons.person_outline, '닉네임 (2~20자)'),
          const SizedBox(height: 18),
          // 신체 정보 라벨
          const Text(
            '신체 정보',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSub),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildNumberField(_heightCtrl, '📏', '신장', 'cm')),
              const SizedBox(width: 10),
              Expanded(child: _buildNumberField(_weightCtrl, '⚖️', '체중', 'kg')),
            ],
          ),
          const SizedBox(height: 14),
          // 비공개 토글
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔒 신체 정보 비공개',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '커뮤니티에서 다른 회원에게 숨깁니다',
                        style: TextStyle(fontSize: 10, color: textSub),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: !_isBodyPublic,
                  onChanged: (v) => setState(() => _isBodyPublic = !v),
                  activeColor: primary,
                  activeTrackColor: primary.withOpacity(0.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 안내
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ℹ️ 신체 정보는 자세 분석 피드백에 활용됩니다. 공개 설정은 마이페이지에서 변경 가능합니다.',
              style: TextStyle(fontSize: 10, color: textSub, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canProceed
                  ? () => widget.onNext(
                        _nicknameCtrl.text.trim(),
                        _heightCtrl.text.isNotEmpty
                            ? double.tryParse(_heightCtrl.text)
                            : null,
                        _weightCtrl.text.isNotEmpty
                            ? double.tryParse(_weightCtrl.text)
                            : null,
                        _isBodyPublic,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '다음 단계 →',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: widget.onPrev,
              child: Text(
                '← 이전',
                style: TextStyle(fontSize: 13, color: primary.withOpacity(0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, IconData icon, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: textSub, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: textSub, fontSize: 13),
        filled: true,
        fillColor: primary.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary),
        ),
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController ctrl,
    String emoji,
    String hint,
    String unit,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: hint,
        hintStyle: const TextStyle(color: textSub, fontSize: 13),
        suffixText: unit,
        suffixStyle: const TextStyle(color: textSub, fontSize: 11),
        filled: true,
        fillColor: primary.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add rexx_app/lib/pages/signup/step2_profile.dart
git commit -m "feat(flutter): 회원가입 Step 2 — 프로필 (닉네임/신장/체중/비공개 토글)"
```

### Task 8: Create Step 3 — Interests

**Files:**
- Create: `rexx_app/lib/pages/signup/step3_interests.dart`

- [ ] **Step 1: Write step3_interests.dart**

```dart
import 'package:flutter/material.dart';

class Step3Interests extends StatefulWidget {
  final void Function(List<String> selected) onSubmit;
  final VoidCallback onPrev;

  const Step3Interests({super.key, required this.onSubmit, required this.onPrev});

  @override
  State<Step3Interests> createState() => _Step3InterestsState();
}

class _Step3InterestsState extends State<Step3Interests> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  static const List<Map<String, String>> _exercises = [
    {'key': 'powerlifting', 'label': '3대 운동', 'emoji': '🏋️',
     'reaction': '오, 3대 운동을 좋아하시는군요! 스쿼트·벤치·데드리프트 자세 분석으로 함께 성장해봐요!'},
    {'key': 'bodyweight', 'label': '맨몸 운동', 'emoji': '🤸',
     'reaction': '어디서든 할 수 있는 맨몸 운동! 기본기가 탄탄하시겠네요!'},
    {'key': 'cardio', 'label': '유산소', 'emoji': '🏃',
     'reaction': '꾸준한 유산소 운동, 체력의 기본이죠! 응원합니다!'},
    {'key': 'yoga', 'label': '요가/필라', 'emoji': '🧘',
     'reaction': '유연성과 코어를 동시에! 자세에 대한 감각이 남다르시겠네요!'},
    {'key': 'martial_arts', 'label': '격투기', 'emoji': '🥊',
     'reaction': '격투기 좋아하시는군요! 강인한 정신력이 느껴집니다!'},
    {'key': 'swimming', 'label': '수영', 'emoji': '🏊',
     'reaction': '전신 운동의 왕, 수영! 균형 잡힌 체력을 가지고 계시겠네요!'},
  ];

  final Set<String> _selected = {};
  String? _lastSelectedKey;

  String? get _reactionMessage {
    if (_selected.isEmpty) return null;
    final lastItem = _exercises.firstWhere((e) => e['key'] == _lastSelectedKey);
    if (_selected.length == 1) {
      return '💪 ${lastItem['reaction']}';
    }
    return '💪 ${_selected.length}개나 선택하셨네요! ${lastItem['reaction']}';
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
        if (_lastSelectedKey == key && _selected.isNotEmpty) {
          _lastSelectedKey = _selected.last;
        } else if (_selected.isEmpty) {
          _lastSelectedKey = null;
        }
      } else {
        _selected.add(key);
        _lastSelectedKey = key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '어떤 운동을 좋아하세요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 4),
          const Text(
            '관심 운동을 선택해주세요 (복수 선택 가능)',
            style: TextStyle(fontSize: 13, color: textSub),
          ),
          const SizedBox(height: 24),
          // 원형 그리드
          Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 18,
              alignment: WrapAlignment.center,
              children: _exercises
                  .map((e) => _buildCircle(e))
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          // 리액션 버블
          if (_reactionMessage != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _reactionMessage != null ? 1.0 : 0.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Text(
                  _reactionMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMain,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selected.isNotEmpty
                  ? () => widget.onSubmit(_selected.toList())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '🎉 시작하기!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: widget.onPrev,
              child: Text(
                '← 이전',
                style: TextStyle(fontSize: 13, color: primary.withOpacity(0.6)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCircle(Map<String, String> exercise) {
    final key = exercise['key']!;
    final isSelected = _selected.contains(key);
    return GestureDetector(
      onTap: () => _toggle(key),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? primary.withOpacity(0.15)
                    : primary.withOpacity(0.08),
                border: Border.all(
                  color: isSelected ? primary : primary.withOpacity(0.2),
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 16)]
                    : [],
              ),
              child: Center(
                child: Text(
                  exercise['emoji']!,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exercise['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? primary : textSub,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add rexx_app/lib/pages/signup/step3_interests.dart
git commit -m "feat(flutter): 회원가입 Step 3 — 관심 운동 원형 선택 + 리액션 버블"
```

---

## Chunk 4: Integration & Documentation

### Task 9: Update Home Screen Navigation

**Files:**
- Modify: `rexx_app/lib/pages/home_screen.dart:4,433-458`

- [ ] **Step 1: Update import and navigation in home_screen.dart**

Replace the import:
```dart
import 'login_page.dart';
```

The `LoginPage` now handles navigation to `SignupPage` internally, so `_handleLoginButton` stays mostly the same — just ensure the LoginPage import still works (it does, same file path).

No changes needed to home_screen.dart beyond confirming the existing `LoginPage` import and navigation still work, since LoginPage now internally navigates to SignupPage.

- [ ] **Step 2: Verify full app compiles**

```bash
cd rexx_app && flutter analyze
```

Expected: No issues found.

- [ ] **Step 3: Commit (if any changes were needed)**

### Task 10: Create Social Login Implementation Guide

**Files:**
- Create: `docs/social-login-implementation-guide.md`

- [ ] **Step 1: Write the guide**

```markdown
# 소셜 로그인 구현 가이드

## 개요
현재 로그인 화면에 Apple / Google / 카카오 소셜 로그인 버튼이 UI로만 배치되어 있음.
이 문서는 실제 기능 구현 시 필요한 작업을 정리한다.

## Flutter 패키지
- Apple: `sign_in_with_apple` (^6.0.0)
- Google: `google_sign_in` (^6.2.0)
- 카카오: `kakao_flutter_sdk_user` (^1.9.0)

## 백엔드 엔드포인트 설계

### POST /auth/social
```json
{
  "provider": "apple" | "google" | "kakao",
  "id_token": "...",
  "access_token": "..."  // 카카오의 경우
}
```

### 처리 흐름
1. 클라이언트에서 소셜 SDK로 인증 → id_token 획득
2. id_token을 백엔드로 전송
3. 백엔드에서 provider별 토큰 검증:
   - Apple: `python-jose`로 Apple 공개키 기반 JWT 검증
   - Google: `google-auth` 라이브러리로 id_token 검증
   - 카카오: 카카오 API (`/v2/user/me`)로 access_token 검증
4. 이메일 추출 → 기존 사용자면 로그인, 없으면 자동 회원가입
5. JWT 토큰 발급하여 반환

### User 모델 변경
```python
class User(Base):
    # 기존 필드...
    social_provider = Column(String(20), nullable=True)  # "apple", "google", "kakao"
    social_id = Column(String(255), nullable=True, unique=True)
```

### 백엔드 패키지 추가
```
google-auth>=2.0.0
httpx>=0.27.0  # 카카오 API 호출용
```

## 플랫폼별 설정

### Apple Sign In
- Apple Developer에서 Sign In with Apple capability 활성화
- Service ID 생성 (redirect URL 등록)
- iOS: Xcode에서 Sign In with Apple capability 추가
- Android: 웹 기반 Apple Sign In 사용

### Google Sign In
- Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성
- iOS: `GoogleService-Info.plist` 추가
- Android: `google-services.json` 추가, SHA-1 등록

### 카카오 로그인
- Kakao Developers에서 앱 등록
- iOS: URL Scheme 설정 (`kakao{APP_KEY}`)
- Android: 키 해시 등록
- `pubspec.yaml`에 카카오 SDK 추가

## 예상 작업량
- 백엔드 소셜 인증 엔드포인트: 1일
- Flutter 소셜 SDK 연동 (3개 provider): 2일
- 플랫폼별 설정 + 테스트: 1일
- 총 예상: 4일
```

- [ ] **Step 2: Delete old test.db (clean state for deployment)**

```bash
rm -f rexx_server/test.db
```

- [ ] **Step 3: Commit all remaining files**

```bash
git add docs/social-login-implementation-guide.md
git commit -m "docs: 소셜 로그인 구현 가이드 문서 추가"
```

### Task 11: Final Verification

- [ ] **Step 1: Start backend server**

```bash
cd rexx_server && source venv/bin/activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- [ ] **Step 2: Run Flutter app on device/simulator**

```bash
cd rexx_app && flutter run
```

- [ ] **Step 3: Manual test checklist**
- [ ] 로그인 화면: 신뢰 지표 표시 확인
- [ ] 로그인 화면: 소셜 버튼 탭 → "준비 중입니다" 토스트
- [ ] 로그인 화면: 빈 필드 → 에러 메시지
- [ ] 로그인 화면: 잘못된 로그인 → 에러 배너
- [ ] "회원가입" 탭 → Step 1 화면 전환
- [ ] Step 1: 비밀번호 검증 칩 실시간 반응
- [ ] Step 1: 이메일 형식 검증
- [ ] Step 1: 모든 검증 통과 시 CTA 활성화 → Step 2
- [ ] Step 2: 닉네임 필수 / 신장·체중 선택
- [ ] Step 2: 비공개 토글 동작
- [ ] Step 3: 원형 운동 선택 + 글로우 효과
- [ ] Step 3: 리액션 버블 표시
- [ ] Step 3: "시작하기" → 회원가입 성공 → 홈 화면
- [ ] 프로그레스 바: 각 단계 전환 시 진행 상황 반영
