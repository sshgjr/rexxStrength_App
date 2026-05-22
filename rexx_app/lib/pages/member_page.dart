import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/pose_evaluation/engine/layer_classifier.dart';
import '../features/pose_evaluation/screens/history_list_screen.dart';

const Color _bg = Color(0xFF0B0F0C);
const Color _card = Color(0xFF0F1612);
const Color _primary = Color(0xFF16A34A);
const Color _danger = Color(0xFFEF4444);
const Color _textMain = Color(0xFFE9F5EF);
const Color _textSub = Color(0xFFA7B9B0);

class MemberPage extends StatefulWidget {
  final String username;
  final String email;
  final String token;
  final VoidCallback? onLogout;

  const MemberPage({
    super.key,
    required this.username,
    required this.email,
    required this.token,
    this.onLogout,
  });

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  late String _username = widget.username;
  late String _email = widget.email;
  String _level = 'beginner';
  String _levelSource = 'default';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService().getMe(widget.token);
      final user = data['user'] as Map<String, dynamic>?;
      if (!mounted || user == null) return;
      setState(() {
        _username = (user['username'] as String?) ?? _username;
        _email = (user['email'] as String?) ?? _email;
        _level = (user['level'] as String?) ?? 'beginner';
        _levelSource = (user['level_source'] as String?) ?? 'default';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 불러오기 실패: $e')),
      );
    }
  }

  void _onLevelChanged(String newLevel) {
    setState(() {
      _level = newLevel;
      _levelSource = 'manual';
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text(
          '로그아웃',
          style: TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '정말 로그아웃하시겠어요?',
          style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '취소',
                      style: TextStyle(color: _textSub, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      widget.onLogout?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(
                      username: _username,
                      email: _email,
                      level: _level,
                      levelSource: _levelSource,
                      loading: _loading,
                    ),
                    const SizedBox(height: 14),
                    _HistoryEntryCard(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              HistoryListScreen(token: widget.token),
                        ));
                      },
                    ),
                    const SizedBox(height: 14),
                    _LevelSettingsSection(
                      currentLevel: _level,
                      token: widget.token,
                      onLevelChanged: _onLevelChanged,
                      onReonboard: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => OnboardingFlow(
                            token: widget.token,
                            onComplete: () => Navigator.of(context).pop(),
                          ),
                        ));
                        if (mounted) _loadProfile();
                      },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _confirmLogout,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _danger.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(
                          color: _danger,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textMain),
            splashRadius: 22,
          ),
          const Text(
            '회원 정보',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String username;
  final String email;
  final String level;
  final String levelSource;
  final bool loading;

  const _ProfileCard({
    required this.username,
    required this.email,
    required this.level,
    required this.levelSource,
    required this.loading,
  });

  static const _sourceLabel = {
    'auto': '자동 산정',
    'manual': '직접 설정',
    'default': '기본값',
  };

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final levelKr = UserLevel.fromString(level).displayName;
    final sourceText = _sourceLabel[levelSource] ?? levelSource;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initial(username),
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(color: _textSub, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '현재 등급 · ',
                style: TextStyle(color: _textSub, fontSize: 13),
              ),
              Text(
                levelKr,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sourceText,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HistoryEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.history_rounded,
                  color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '운동 기록 보기',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '최근 평가한 자세 점수와 피드백 다시보기',
                    style: TextStyle(color: _textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _textSub, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LevelSettingsSection extends StatefulWidget {
  final String currentLevel;
  final String token;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onReonboard;

  const _LevelSettingsSection({
    required this.currentLevel,
    required this.token,
    required this.onLevelChanged,
    required this.onReonboard,
  });

  @override
  State<_LevelSettingsSection> createState() => _LevelSettingsSectionState();
}

class _LevelSettingsSectionState extends State<_LevelSettingsSection> {
  late String _selected = widget.currentLevel;
  bool _saving = false;

  static const _options = [
    ('beginner', '초급', '매우 상세한 피드백'),
    ('intermediate', '중급', '간결한 자세 교정'),
    ('advanced', '상급', '핵심 위주, 미세 조정만'),
  ];

  @override
  void didUpdateWidget(covariant _LevelSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && widget.currentLevel != oldWidget.currentLevel) {
      _selected = widget.currentLevel;
    }
  }

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '코칭 등급',
            style: TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '등급에 따라 AI 피드백 상세도가 달라집니다.',
            style: TextStyle(color: _textSub, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final opt in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LevelTile(
                label: opt.$2,
                description: opt.$3,
                selected: _selected == opt.$1,
                onTap: _saving ? null : () => _changeLevel(opt.$1),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: widget.onReonboard,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '신체정보·1RM 다시 입력하기',
              style: TextStyle(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _primary : _textSub,
                  width: selected ? 2 : 1.5,
                ),
                color: selected ? _primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? _primary : _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: _textSub,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
