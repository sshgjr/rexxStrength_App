import 'package:flutter/material.dart';
import '../models/evaluation_result.dart';

/// 기준별 상세 점수 위젯
class CriterionBreakdown extends StatefulWidget {
  final List<CriterionResult> criteria;

  const CriterionBreakdown({super.key, required this.criteria});

  @override
  State<CriterionBreakdown> createState() => _CriterionBreakdownState();
}

class _CriterionBreakdownState extends State<CriterionBreakdown> {
  bool _isExpanded = false;

  static const Color card = Color(0xFF0F1612);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  Color _gradeColor(CriterionGrade grade) {
    switch (grade) {
      case CriterionGrade.good:
        return const Color(0xFF16A34A);
      case CriterionGrade.warning:
        return const Color(0xFFF59E0B);
      case CriterionGrade.bad:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // 헤더 (펼치기/접기)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: textSub, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '기준별 상세 점수',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: textSub,
                  ),
                ],
              ),
            ),
          ),

          // 요약 바 (항상 표시)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: widget.criteria.map((c) {
                return Expanded(
                  flex: (c.weight * 100).round(),
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _gradeColor(c.grade),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 상세 (펼쳤을 때)
          if (_isExpanded)
            ...widget.criteria.map((c) => _buildCriterionItem(c)),
        ],
      ),
    );
  }

  Widget _buildCriterionItem(CriterionResult criterion) {
    final color = _gradeColor(criterion.grade);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.name,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '가중치 ${(criterion.weight * 100).round()}%',
                  style: const TextStyle(
                    color: textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${criterion.score.round()}점',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            criterion.grade.displayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
