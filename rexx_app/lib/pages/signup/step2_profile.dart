import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Step2Profile extends StatefulWidget {
  final String initialNickname;
  final double? initialHeight;
  final double? initialWeight;
  final bool initialIsBodyPublic;
  final void Function(String nickname, double? height, double? weight, bool isBodyPublic) onNext;

  const Step2Profile({
    super.key,
    required this.initialNickname,
    required this.initialHeight,
    required this.initialWeight,
    required this.initialIsBodyPublic,
    required this.onNext,
  });

  @override
  State<Step2Profile> createState() => _Step2ProfileState();
}

class _Step2ProfileState extends State<Step2Profile> {
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  late final TextEditingController _nicknameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late bool _isBodyPublic;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
    _heightController = TextEditingController(
      text: widget.initialHeight != null ? widget.initialHeight!.toStringAsFixed(0) : '',
    );
    _weightController = TextEditingController(
      text: widget.initialWeight != null ? widget.initialWeight!.toStringAsFixed(0) : '',
    );
    _isBodyPublic = widget.initialIsBodyPublic;

    _nicknameController.addListener(_onChanged);
    _heightController.addListener(_onChanged);
    _weightController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get _isNicknameValid {
    final nick = _nicknameController.text.trim();
    return nick.length >= 2 && nick.length <= 20;
  }

  bool get _isHeightValid {
    if (_heightController.text.isEmpty) return true; // 선택사항
    final val = double.tryParse(_heightController.text);
    return val != null && val >= 50 && val <= 300;
  }

  bool get _isWeightValid {
    if (_weightController.text.isEmpty) return true; // 선택사항
    final val = double.tryParse(_weightController.text);
    return val != null && val >= 20 && val <= 500;
  }

  bool get _canProceed => _isNicknameValid && _isHeightValid && _isWeightValid;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            '프로필 설정',
            style: TextStyle(
              color: textMain,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '나를 나타낼 닉네임과 신체 정보를 입력해주세요.',
            style: TextStyle(color: textSub, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // 닉네임
          _buildLabel('닉네임'),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _nicknameController,
            icon: Icons.person_outline,
            hint: '2~20자 닉네임',
          ),
          if (_nicknameController.text.isNotEmpty && !_isNicknameValid)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '닉네임은 2~20자로 입력해주세요.',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // 키 / 몸무게
          _buildLabel('신체 정보 (선택)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _heightController,
                  hint: '키 (cm)',
                  suffix: 'cm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _weightController,
                  hint: '몸무게 (kg)',
                  suffix: 'kg',
                ),
              ),
            ],
          ),
          if (!_isHeightValid || !_isWeightValid)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                !_isHeightValid ? '키는 50~300cm 범위로 입력해주세요.' : '몸무게는 20~500kg 범위로 입력해주세요.',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // 비공개 토글
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '신체 정보 비공개',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: !_isBodyPublic, // 비공개 = !isBodyPublic
                  onChanged: (val) => setState(() => _isBodyPublic = !val),
                  activeThumbColor: primary,
                  activeTrackColor: primary.withValues(alpha: 0.3),
                  inactiveThumbColor: textSub,
                  inactiveTrackColor: primary.withValues(alpha: 0.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 안내 박스
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: textSub.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '신체 정보는 운동 자세 분석의 정확도를 높이는 데 사용됩니다. '
                    '비공개로 설정하면 다른 사용자에게 표시되지 않습니다.',
                    style: TextStyle(color: textSub, fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // CTA 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _canProceed
                  ? () {
                      final h = _heightController.text.isNotEmpty
                          ? double.tryParse(_heightController.text)
                          : null;
                      final w = _weightController.text.isNotEmpty
                          ? double.tryParse(_weightController.text)
                          : null;
                      widget.onNext(
                        _nicknameController.text.trim(),
                        h,
                        w,
                        _isBodyPublic,
                      );
                    }
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
                  color: _canProceed ? Colors.white : textSub.withValues(alpha: 0.5),
                ),
              ),
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
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: textSub, size: 20),
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

  Widget _buildNumberField({
    required TextEditingController controller,
    required String hint,
    required String suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSub, fontSize: 13),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: textSub, fontSize: 13),
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
}
