import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'login_page.dart';
import 'member_page.dart';
import 'waiting_screen.dart';
import 'one_rm_page.dart';
import '../features/pose_evaluation/screens/exercise_select_screen.dart';

class RexxHomeScreen extends StatefulWidget {
  const RexxHomeScreen({super.key});

  @override
  State<RexxHomeScreen> createState() => _RexxHomeScreenState();
}

class _RexxHomeScreenState extends State<RexxHomeScreen> {
  bool isLoggedIn = false;
  String nickname = '현민';
  String? token;
  String? email;

  /// 네트워크 상태
  bool _isOnline = true;
  bool _isOfflineMode = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final List<String> menuItems = const [
    '1RM 계산',
    '자세 평가',
    '명예의 전당',
    '인증 피드',
    '칼로리 계산',
    '손목힘 알아보기',
  ];

  final List<Map<String, dynamic>> rankings = const [];
  final List<Map<String, dynamic>> feeds = const [];

  static const Color bg = Color(0xFF0B0F0C);
  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// 초기 네트워크 상태 확인 및 실시간 감지 시작
  Future<void> _initConnectivity() async {
    // 현재 상태 확인
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    setState(() => _isOnline = online);

    // 오프라인이면 다이얼로그 표시
    if (!online) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOfflineDialog();
      });
    }

    // 상태 변화 리스닝
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;

      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);

      if (!online && !_isOfflineMode) {
        _showOfflineDialog();
      } else if (online && wasOffline) {
        // 온라인 복귀 시 오프라인 모드 해제
        setState(() => _isOfflineMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('온라인 상태로 전환되었습니다.'),
            backgroundColor: primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// 오프라인 상태 알림 다이얼로그
  Future<void> _showOfflineDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '오프라인 상태',
                style: TextStyle(
                  color: textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          '현재 기기가 오프라인 상태입니다.\n오프라인 모드로 진행할까요?',
          style: TextStyle(color: textSub, fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              // 연결 대기 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '연결 대기',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 오프라인 모드 진행 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '계속 진행',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (accepted == true) {
      // 오프라인 모드 수락 -> 안내 다이얼로그 표시
      setState(() => _isOfflineMode = true);
      _showOfflineInfoDialog();
    } else {
      // 연결 대기 -> 대기 화면으로 이동
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const WaitingScreen()),
      );

      if (result == true && mounted) {
        // 온라인 복귀
        setState(() {
          _isOnline = true;
          _isOfflineMode = false;
        });
      } else if (mounted) {
        // 대기 화면에서 오프라인 모드로 돌아옴
        setState(() => _isOfflineMode = true);
      }
    }
  }

  /// 오프라인 모드 안내 다이얼로그
  void _showOfflineInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '오프라인 모드 안내',
                style: TextStyle(
                  color: textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              Icons.check_circle_outline,
              primary,
              '사용 가능',
              '자세 평가 (촬영 + 점수 확인)',
            ),
            const SizedBox(height: 14),
            _buildInfoItem(
              Icons.check_circle_outline,
              primary,
              '사용 가능',
              '1RM 계산',
            ),
            const SizedBox(height: 14),
            _buildInfoItem(
              Icons.cancel_outlined,
              Colors.redAccent,
              '제한됨',
              'AI 코칭 피드백 (연결 후 자동 전송)',
            ),
            const SizedBox(height: 14),
            _buildInfoItem(
              Icons.cancel_outlined,
              Colors.redAccent,
              '제한됨',
              '랭킹 / 인증 피드 조회',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync_rounded, size: 18, color: primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '오프라인에서 평가한 결과는 인터넷 연결 시 자동으로 서버에 전송됩니다.',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 오프라인 안내 다이얼로그 내 항목 위젯
  Widget _buildInfoItem(
    IconData icon,
    Color iconColor,
    String label,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onMenuTap(int index) async {
    final item = menuItems[index];

    /// ✅ 1RM 계산기 이동 추가
    if (item == '1RM 계산') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OneRMPage()),
      );
      return;
    }

    if (item == '자세 평가') {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => ExerciseSelectScreen(token: token)),
      );

      if (result != null && mounted) {
        setState(() {
          isLoggedIn = true;
          nickname = result['user']?['username'] ?? '사용자';
          email = result['user']?['email'] ?? '';
          token = result['token'] ?? '';
        });
      }
    }
  }

  // 게스트가 회원가입 후 돌아온 경우 로그인 상태 업데이트

  Future<void> _handleLoginButton() async {
    if (isLoggedIn) {
      setState(() {
        isLoggedIn = false;
        nickname = '현민';
        email = null;
        token = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃 되었습니다.')));
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    if (result != null) {
      setState(() {
        isLoggedIn = true;
        nickname = result['user']?['username'] ?? '사용자';
        email = result['user']?['email'] ?? '';
        token = result['token'] ?? '';
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberPage(
            username: nickname,
            email: email ?? '',
            token: token ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(context),
                    _buildRankingSection(),
                    _buildFeedSection(),
                    const SizedBox(height: 28),
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
        color: bg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: primary,
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Rexx Strength',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 온라인/오프라인 상태 표시
                GestureDetector(
                  onTap: !_isOnline ? _showOfflineDialog : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? primary.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isOnline
                            ? primary.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _isOnline ? primary : Colors.orange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _isOnline ? primary : Colors.orange,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isOnline ? '온라인' : '오프라인',
                          style: TextStyle(
                            color: _isOnline ? primary : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: GestureDetector(
                    onTap: _handleLoginButton,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isLoggedIn
                            ? Colors.white.withOpacity(0.10)
                            : primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLoggedIn
                              ? Colors.white.withOpacity(0.20)
                              : primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isLoggedIn) ...[
                            const Icon(
                              Icons.person_outline,
                              size: 20,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              isLoggedIn ? '$nickname님 (로그아웃)' : '로그인',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLoggedIn ? textSub : primary,
                                fontSize: 13,
                                fontWeight: isLoggedIn
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _onMenuTap(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Center(
                    child: Text(
                      menuItems[index],
                      style: const TextStyle(
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: menuItems.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final height = MediaQuery.of(context).size.width >= 900 ? 500.0 : 380.0;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1470&auto=format&fit=crop',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.60)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '증명하고,\n랭커가 되세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    '당신의 1RM을 측정하고, 인증샷을 올려\n최고의 자리에 도전하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSub,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OneRMPage(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '1RM 측정하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '인증 올리기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 24, color: primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '실시간 종합 랭킹',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                children: const [
                  Text(
                    '전체보기',
                    style: TextStyle(
                      color: primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 14, color: primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: rankings.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(
                      children: const [
                        Icon(Icons.fitness_center, size: 40, color: primary),
                        SizedBox(height: 10),
                        Text(
                          '지금 바로 3대를 입력하여\n자신의 랭킹을 증명하세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSub,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: rankings
                        .asMap()
                        .entries
                        .map((entry) => _buildRankItem(entry.key, entry.value))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankItem(int index, Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${user['rank'] ?? index + 1}',
              style: const TextStyle(
                color: primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${user['name'] ?? user['nickname'] ?? '이름 없음'}',
              style: const TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${user['score'] ?? user['composite_score'] ?? 0}',
              style: const TextStyle(
                color: textMain,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.fitness_center, size: 24, color: primary),
              SizedBox(width: 6),
              Text(
                '방금 올라온 인증',
                style: TextStyle(
                  color: textMain,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '멋진 자세에 투표해주세요!',
            style: TextStyle(color: textSub, fontSize: 13),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 290,
            child: feeds.isEmpty
                ? Container(
                    width: 300,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 32,
                          color: primary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '아직 올라온 인증이 없어요.\n첫 인증의 주인공이 되어보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSub,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) =>
                        _buildFeedCard(feeds[index]),
                    separatorBuilder: (_, __) => const SizedBox(width: 15),
                    itemCount: feeds.length,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> item) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Image.network(
                    item['imageUrl'] ??
                        'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=1200&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item['badgeColor'] ?? primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    item['badgeText'] ?? '자유운동',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle, size: 16, color: textSub),
                    const SizedBox(width: 6),
                    Text(
                      item['nickname'] ?? '익명 랭커',
                      style: const TextStyle(
                        color: textSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: '${item['total1rm'] ?? 500}kg',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const TextSpan(text: ' 성공!'),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (item['isLiked'] ?? false)
                            ? primary.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (item['isLiked'] ?? false)
                              ? primary.withOpacity(0.50)
                              : Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (item['isLiked'] ?? false)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: (item['isLiked'] ?? false)
                                ? primary
                                : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item['likes'] ?? 0}',
                            style: TextStyle(
                              color: (item['isLiked'] ?? false)
                                  ? primary
                                  : Colors.white,
                              fontSize: 13,
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
          ),
        ],
      ),
    );
  }
}
