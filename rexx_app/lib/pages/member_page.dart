import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../features/onboarding/onboarding_flow.dart';

class MemberPage extends StatefulWidget {
  final String username;
  final String email;
  final String token;

  const MemberPage({
    super.key,
    required this.username,
    required this.email,
    required this.token,
  });

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  String _currentLevel = 'beginner';
  String _currentLevelSource = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원 페이지")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("닉네임: ${widget.username}"),
            const SizedBox(height: 10),
            Text("이메일: ${widget.email}"),
            const SizedBox(height: 20),
            LevelSettingsSection(
              currentLevel: _currentLevel,
              currentLevelSource: _currentLevelSource,
              token: widget.token,
              onLevelChanged: (newLevel) {
                setState(() {
                  _currentLevel = newLevel;
                  _currentLevelSource = 'manual';
                });
              },
              onReonboard: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OnboardingFlow(
                    token: widget.token,
                    onComplete: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LevelSettingsSection extends StatefulWidget {
  final String currentLevel;
  final String currentLevelSource;
  final String token;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onReonboard;

  const LevelSettingsSection({
    super.key,
    required this.currentLevel,
    required this.currentLevelSource,
    required this.token,
    required this.onLevelChanged,
    required this.onReonboard,
  });

  @override
  State<LevelSettingsSection> createState() => _LevelSettingsSectionState();
}

class _LevelSettingsSectionState extends State<LevelSettingsSection> {
  late String _selected = widget.currentLevel;
  bool _saving = false;

  static const _options = [
    ('beginner', '초급', '매우 상세한 피드백'),
    ('intermediate', '중급', '간결한 자세 교정'),
    ('advanced', '상급', '핵심 위주, 미세 조정만'),
  ];

  static const _sourceLabel = {
    'auto': '자동 산정',
    'manual': '직접 설정',
    'default': '기본값',
  };

  String _levelKorean(String level) => switch (level) {
        'beginner' => '초급',
        'intermediate' => '중급',
        'advanced' => '상급',
        _ => level,
      };

  Future<void> _changeLevel(String newLevel) async {
    if (newLevel == _selected || _saving) return;
    final previous = _selected;
    setState(() {
      _selected = newLevel;
      _saving = true;
    });
    try {
      await AuthService().updateLevel(token: widget.token, level: newLevel);
      widget.onLevelChanged(newLevel);
    } catch (e) {
      setState(() => _selected = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등급 변경 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1612),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('코칭 등급',
                  style: TextStyle(color: Color(0xFFE9F5EF), fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                _levelKorean(_selected),
                style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '현재: ${_sourceLabel[widget.currentLevelSource] ?? widget.currentLevelSource}',
            style: const TextStyle(color: Color(0xFFA7B9B0), fontSize: 12),
          ),
          const Divider(color: Color(0xFF1F2925), height: 24),
          for (final opt in _options)
            RadioListTile<String>(
              value: opt.$1,
              groupValue: _selected,
              onChanged: _saving ? null : (v) { if (v != null) _changeLevel(v); },
              title: Text('${opt.$2} — ${opt.$3}',
                  style: const TextStyle(color: Color(0xFFE9F5EF), fontSize: 14)),
              activeColor: const Color(0xFF16A34A),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onReonboard,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF16A34A)),
            ),
            child: const Text('신체정보·1RM 다시 입력하기',
                style: TextStyle(color: Color(0xFF16A34A))),
          ),
        ],
      ),
    );
  }
}
