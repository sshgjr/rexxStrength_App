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
  final AuthService _authService = AuthService();

  int _currentStep = 0;
  bool _loading = false;

  // 공유 회원가입 데이터
  String email = '';
  String password = '';
  String nickname = '';
  double? height;
  double? weight;
  bool isBodyPublic = false;
  List<String> interests = [];

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      final result = await _authService.register(
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

      final errorMsg = e.toString().replaceFirst('Exception: ', '');

      if (errorMsg.contains('이미 존재하는 이메일') || errorMsg.contains('already')) {
        // 이메일 중복 — 1단계로 돌아가기
        setState(() {
          _currentStep = 0;
          _loading = false;
        });
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('이미 존재하는 이메일입니다. 다른 이메일을 사용해주세요.'),
            backgroundColor: Colors.red.withValues(alpha: 0.85),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.withValues(alpha: 0.85),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // 상단 바: 뒤로가기 + 제목
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _prevStep,
                    icon: const Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      '회원가입',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // 균형 맞추기
                ],
              ),
            ),
            // 프로그레스 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: _buildProgressBar(),
            ),
            const SizedBox(height: 8),
            // 페이지뷰
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Step1Account(
                    initialEmail: email,
                    initialPassword: password,
                    onNext: (e, p) {
                      setState(() {
                        email = e;
                        password = p;
                      });
                      _nextStep();
                    },
                    onGoToLogin: () => Navigator.pop(context),
                  ),
                  Step2Profile(
                    initialNickname: nickname,
                    initialHeight: height,
                    initialWeight: weight,
                    initialIsBodyPublic: isBodyPublic,
                    onNext: (n, h, w, pub) {
                      setState(() {
                        nickname = n;
                        height = h;
                        weight = w;
                        isBodyPublic = pub;
                      });
                      _nextStep();
                    },
                  ),
                  Step3Interests(
                    initialInterests: interests,
                    loading: _loading,
                    onSubmit: (selected) {
                      setState(() => interests = selected);
                      _submit();
                    },
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
      children: List.generate(5, (index) {
        // index 0, 2, 4 = 점 (step 0, 1, 2)
        // index 1, 3 = 연결선
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < _currentStep;
          final isCurrent = stepIndex == _currentStep;

          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? primary
                  : isCurrent
                      ? primary.withValues(alpha: 0.2)
                      : primary.withValues(alpha: 0.08),
              border: Border.all(
                color: isCompleted || isCurrent
                    ? primary
                    : primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isCurrent ? primary : textSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          );
        } else {
          final lineStepIndex = index ~/ 2;
          final isCompleted = lineStepIndex < _currentStep;

          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted
                  ? primary
                  : primary.withValues(alpha: 0.15),
            ),
          );
        }
      }),
    );
  }
}
