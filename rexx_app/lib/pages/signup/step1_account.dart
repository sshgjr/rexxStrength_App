import 'package:flutter/material.dart';

class Step1Account extends StatefulWidget {
  final String initialEmail;
  final String initialPassword;
  final void Function(String email, String password) onNext;
  final VoidCallback onGoToLogin;

  const Step1Account({
    super.key,
    required this.initialEmail,
    required this.initialPassword,
    required this.onNext,
    required this.onGoToLogin,
  });

  @override
  State<Step1Account> createState() => _Step1AccountState();
}

class _Step1AccountState extends State<Step1Account> {
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _confirmController = TextEditingController(
      text: widget.initialPassword.isNotEmpty ? widget.initialPassword : '',
    );

    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // 이메일 형식 검증
  bool get _isEmailValid {
    final email = _emailController.text.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  // 비밀번호 8자 이상
  bool get _isLengthValid => _passwordController.text.length >= 8;

  // 영문 + 숫자 포함
  bool get _isFormatValid {
    final pw = _passwordController.text;
    return RegExp(r'[a-zA-Z]').hasMatch(pw) && RegExp(r'[0-9]').hasMatch(pw);
  }

  // 비밀번호 일치
  bool get _isMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  bool get _allValid => _isEmailValid && _isLengthValid && _isFormatValid && _isMatch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            '계정 정보',
            style: TextStyle(
              color: textMain,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '로그인에 사용할 이메일과 비밀번호를 입력해주세요.',
            style: TextStyle(color: textSub, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // 이메일 입력
          _buildLabel('이메일'),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _emailController,
            icon: Icons.email_outlined,
            hint: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
          ),
          if (_emailController.text.isNotEmpty && !_isEmailValid)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '올바른 이메일 형식을 입력해주세요.',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // 비밀번호 입력
          _buildLabel('비밀번호'),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _passwordController,
            icon: Icons.lock_outline,
            hint: '비밀번호를 입력하세요',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: textSub,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 10),

          // 비밀번호 확인 입력
          _buildInputField(
            controller: _confirmController,
            icon: Icons.lock_outline,
            hint: '비밀번호를 다시 입력하세요',
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: textSub,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 14),

          // 검증 칩들
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildValidationChip('8자 이상', _isLengthValid),
              _buildValidationChip('영문+숫자', _isFormatValid),
              _buildValidationChip('일치', _isMatch),
            ],
          ),
          const SizedBox(height: 32),

          // CTA 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _allValid
                  ? () => widget.onNext(
                        _emailController.text.trim(),
                        _passwordController.text,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                '다음 단계 →',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _allValid ? Colors.white : textSub.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 로그인 링크
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '이미 계정이 있나요? ',
                  style: TextStyle(fontSize: 13, color: textSub),
                ),
                GestureDetector(
                  onTap: widget.onGoToLogin,
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: textMain,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: textSub, size: 20),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: const TextStyle(color: textSub, fontSize: 13),
        filled: true,
        fillColor: primary.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary),
        ),
      ),
    );
  }

  Widget _buildValidationChip(String label, bool isValid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isValid
            ? primary.withValues(alpha: 0.15)
            : primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isValid
              ? primary.withValues(alpha: 0.5)
              : primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isValid ? primary : textSub.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isValid ? primary : textSub.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
