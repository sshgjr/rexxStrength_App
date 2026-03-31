import 'package:flutter/material.dart';
import '../../../services/level_service.dart';
import '../engine/layer_classifier.dart';

class LevelSuggestionSheet {
  static Future<bool?> show(
    BuildContext context, {
    required LevelSuggestion suggestion,
    required UserLevel currentLevel,
  }) {
    final message = LevelService.suggestionMessage(suggestion, currentLevel);
    final targetLevel = LevelService.suggestedLevel(suggestion, currentLevel);

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0F1612),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: suggestion == LevelSuggestion.upgrade
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  suggestion == LevelSuggestion.upgrade
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: suggestion == LevelSuggestion.upgrade
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE9F5EF),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '등급은 설정에서 언제든 변경할 수 있습니다.',
                style: TextStyle(
                  color: const Color(0xFFA7B9B0),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA7B9B0),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('유지할게요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('${targetLevel.displayName}으로 변경'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
