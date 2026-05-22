import 'package:flutter/material.dart';

import '../../../services/pose_feedback_service.dart';
import '../models/exercise_phase.dart';
import '../models/history_item.dart';
import 'pose_result_screen.dart';

const Color _bg = Color(0xFF0B0F0C);
const Color _card = Color(0xFF0F1612);
const Color _primary = Color(0xFF16A34A);
const Color _warning = Color(0xFFF59E0B);
const Color _danger = Color(0xFFEF4444);
const Color _textMain = Color(0xFFE9F5EF);
const Color _textSub = Color(0xFFA7B9B0);

/// 마이페이지 → 운동 기록 목록
class HistoryListScreen extends StatefulWidget {
  final String token;

  const HistoryListScreen({super.key, required this.token});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  final PoseFeedbackService _service = PoseFeedbackService();
  late Future<List<HistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getHistory(token: widget.token);
  }

  void _reload() {
    setState(() {
      _future = _service.getHistory(token: widget.token);
    });
  }

  void _openDetail(HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PoseResultScreen(
          result: item.toEvaluationResult(),
          token: widget.token,
          fromHistory: true,
        ),
      ),
    );
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
              child: FutureBuilder<List<HistoryItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primary),
                    );
                  }
                  if (snap.hasError) {
                    return _ErrorState(onRetry: _reload);
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return const _EmptyState();
                  }
                  return RefreshIndicator(
                    color: _primary,
                    backgroundColor: _card,
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _HistoryRow(
                        item: items[i],
                        onTap: () => _openDetail(items[i]),
                      ),
                    ),
                  );
                },
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: _textMain),
            splashRadius: 22,
          ),
          const Text(
            '운동 기록',
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

class _HistoryRow extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;

  const _HistoryRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(item.totalScore);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_iconFor(item.exerciseType),
                  color: scoreColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.exerciseType.displayName,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(color: _textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${item.totalScore}점',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: _textSub, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.history_edu_rounded,
                  color: _primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 평가 기록이 없어요',
              style: TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '운동 영상을 업로드하면 여기에 쌓여요.',
              style: TextStyle(color: _textSub, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _danger, size: 36),
            const SizedBox(height: 12),
            const Text(
              '기록을 불러오지 못했어요',
              style: TextStyle(
                color: _textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '네트워크 상태를 확인하고 다시 시도해 주세요.',
              style: TextStyle(color: _textSub, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 85) return _primary;
  if (score >= 50) return _warning;
  return _danger;
}

IconData _iconFor(ExerciseType type) {
  switch (type) {
    case ExerciseType.squat:
      return Icons.fitness_center_rounded;
    case ExerciseType.benchPress:
      return Icons.fitness_center_outlined;
    case ExerciseType.deadlift:
      return Icons.sports_gymnastics_rounded;
    case ExerciseType.wristCurl:
    case ExerciseType.sidePressure:
    case ExerciseType.pronationCurl:
      return Icons.sports_mma_rounded;
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return '오늘 ${_hhmm(dt)}';
  if (diff == 1) return '어제 ${_hhmm(dt)}';
  if (diff < 7) return '$diff일 전 ${_hhmm(dt)}';
  return '${dt.year}.${_pad(dt.month)}.${_pad(dt.day)} ${_hhmm(dt)}';
}

String _hhmm(DateTime dt) => '${_pad(dt.hour)}:${_pad(dt.minute)}';
String _pad(int v) => v.toString().padLeft(2, '0');
