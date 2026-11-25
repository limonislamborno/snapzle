import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/gaming_button.dart';
import '../widgets/glass_card.dart';
import '../services/supabase_service.dart';

class GameResultDialog extends StatefulWidget {
  final String gameTitle;
  final int moves;
  final int elapsedSeconds;
  final int score;
  final bool isPerfect;
  final String? unlockMessage;
  final VoidCallback onPlayAgain;

  const GameResultDialog({
    super.key,
    required this.gameTitle,
    required this.moves,
    required this.elapsedSeconds,
    required this.score,
    this.isPerfect = false,
    this.unlockMessage,
    required this.onPlayAgain,
  });

  @override
  State<GameResultDialog> createState() => _GameResultDialogState();
}

class _GameResultDialogState extends State<GameResultDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    SupabaseService.recordGameWin(
      widget.score,
      gameType: widget.gameTitle,
      moves: widget.moves,
      elapsedSeconds: widget.elapsedSeconds,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            isStrong: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.trophy,
                  color: Color(0xFFFBBF24),
                  size: 54,
                ),
                const SizedBox(height: 12),
                const Text(
                  'VICTORY!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.gameTitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol('SCORE', '+${widget.score}', AppColors.accentCyan),
                      _statCol('TIME', '${widget.elapsedSeconds}s', AppColors.primary),
                      _statCol('MOVES', '${widget.moves}', AppColors.accentPink),
                    ],
                  ),
                ),
                if (widget.isPerfect) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(LucideIcons.sparkles, color: AppColors.accentAmber, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'PERFECT RUN BONUS (+150)',
                        style: TextStyle(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.unlockMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.lockOpen, color: AppColors.accentEmerald, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.unlockMessage!,
                          style: const TextStyle(
                            color: AppColors.accentEmerald,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GamingButton(
                  label: 'Play Again',
                  icon: LucideIcons.rotateCcw,
                  onPressed: widget.onPlayAgain,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Back to Games',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            AppColors.primary,
            AppColors.primaryBlue,
            AppColors.accentPink,
            AppColors.accentCyan,
            Colors.amber,
          ],
        ),
      ],
    );
  }

  Widget _statCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
