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
  String? emailError;
  String? passwordError;

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      emailError = email.isEmpty ? '이메일을 입력해주세요' : null;
      passwordError = password.isEmpty ? '비밀번호를 입력해주세요' : null;
      errorMessage = null;
    });

    if (email.isEmpty || password.isEmpty) return;

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
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('서버에 연결할 수 없습니다')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
          ),
        );
        setState(() => loading = false);
      } else {
        setState(() {
          errorMessage = msg;
          loading = false;
        });
      }
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
        backgroundColor: primary.withValues(alpha: 0.8),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.12),
                  border: Border.all(color: primary.withValues(alpha: 0.25), width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.sports_gymnastics,
                    size: 32,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'REXX Strength',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI 자세 분석 코칭',
                style: TextStyle(fontSize: 13, color: textSub),
              ),
              const SizedBox(height: 20),
              _buildTrustIndicators(),
              const SizedBox(height: 32),
              if (errorMessage != null) _buildErrorBanner(),
              _buildInputField(
                controller: emailController,
                icon: Icons.email_outlined,
                hint: '이메일',
                keyboardType: TextInputType.emailAddress,
                errorText: emailError,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: passwordController,
                icon: Icons.lock_outline,
                hint: '비밀번호',
                obscureText: true,
                errorText: passwordError,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              _buildDivider(),
              const SizedBox(height: 20),
              _buildSocialButtons(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('계정이 없으신가요? ', style: TextStyle(fontSize: 13, color: textSub)),
                  GestureDetector(
                    onTap: _goToSignup,
                    child: const Text('회원가입', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
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
        Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 20), color: primary.withValues(alpha: 0.15)),
        _buildStat('15K+', '자세 평가'),
        Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 20), color: primary.withValues(alpha: 0.15)),
        _buildStat('4.8', '만족도'),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: textSub)),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: textMain, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: textSub, size: 20),
            hintText: hint,
            hintStyle: const TextStyle(color: textSub, fontSize: 13),
            filled: true,
            fillColor: primary.withValues(alpha: 0.08),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasError ? Colors.red : primary.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasError ? Colors.red : primary.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasError ? Colors.red : primary)),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: primary.withValues(alpha: 0.15))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('또는', style: TextStyle(fontSize: 12, color: textSub)),
        ),
        Expanded(child: Container(height: 1, color: primary.withValues(alpha: 0.15))),
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
        width: 64, height: 48,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textSub, size: 22)
              : Text(text, style: const TextStyle(color: textSub, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
