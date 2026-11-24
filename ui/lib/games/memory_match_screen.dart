import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_chip.dart';
import '../widgets/quit_game_dialog.dart';
import '../services/game_progress_service.dart';
import 'game_result_dialog.dart';

class MemoryCardItem {
  final int id;
  final String imagePath;
  bool isFlipped;
  bool isMatched;

  MemoryCardItem({
    required this.id,
    required this.imagePath,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class MemoryMatchScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int pairsCount; // 6 (Easy), 8 (Med), 10 (Hard)

  const MemoryMatchScreen({
    super.key,
    required this.photoUrls,
    this.pairsCount = 6,
  });

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  late List<MemoryCardItem> cards;
  int? firstSelectedIdx;
  bool isBusy = false;
  int moves = 0;
  int seconds = 0;
  int matchedPairs = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _initCards();
    _startTimer();
  }

  void _initCards() {
    cards = [];
    int count = widget.pairsCount;

    for (int i = 0; i < count; i++) {
      String url = widget.photoUrls[i % widget.photoUrls.length];
      cards.add(MemoryCardItem(id: i, imagePath: url));
      cards.add(MemoryCardItem(id: i, imagePath: url));
    }
    cards.shuffle();
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _onCardTap(int idx) {
    if (isBusy || cards[idx].isFlipped || cards[idx].isMatched) return;

    setState(() {
      cards[idx].isFlipped = true;
    });

    if (firstSelectedIdx == null) {
      firstSelectedIdx = idx;
    } else {
      moves++;
      int firstIdx = firstSelectedIdx!;
      firstSelectedIdx = null;

      if (cards[firstIdx].id == cards[idx].id) {
        // Matched!
        setState(() {
          cards[firstIdx].isMatched = true;
          cards[idx].isMatched = true;
          matchedPairs++;
        });

        if (matchedPairs == widget.pairsCount) {
          timer?.cancel();
          GameProgressService.recordMemoryMatchWin(widget.pairsCount).then((res) {
            if (!mounted) return;
            String? unlockMsg;
            if (res.unlockedNextTier) {
              unlockMsg = widget.pairsCount == 6
                  ? '🎉 8-Pairs (Medium) Unlocked! (5/5 matches cleared)'
                  : '🎉 10-Pairs (Hard) Unlocked! (5/5 matches cleared)';
            } else if (res.totalWins < GameProgressService.requiredPhotosToUnlock) {
              unlockMsg = '🌟 Match Cleared! (${res.totalWins}/5 wins for next tier)';
            }

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => GameResultDialog(
                gameTitle: 'Memory Match (${widget.pairsCount} Pairs)',
                moves: moves,
                elapsedSeconds: seconds,
                score: (widget.pairsCount * 200) + Math.max(0, 500 - (seconds * 5)),
                isPerfect: moves == widget.pairsCount,
                unlockMessage: unlockMsg,
                onPlayAgain: () {
                  Navigator.pop(context);
                  setState(() {
                    moves = 0;
                    seconds = 0;
                    matchedPairs = 0;
                    _initCards();
                    _startTimer();
                  });
                },
              ),
            );
          });
        }
      } else {
        // Mismatch - flip back after 700ms
        isBusy = true;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              cards[firstIdx].isFlipped = false;
              cards[idx].isFlipped = false;
              isBusy = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldQuit = await showQuitGameConfirmation(context);
        if (shouldQuit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () async {
              final shouldQuit = await showQuitGameConfirmation(context);
              if (shouldQuit && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text('Memory Match · ${widget.pairsCount} Pairs'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatChip(
                      icon: LucideIcons.timer,
                      label: 'Time',
                      value: '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      tone: AppColors.accentCyan,
                    ),
                    StatChip(
                      icon: LucideIcons.footprints,
                      label: 'Moves',
                      value: '$moves',
                      tone: AppColors.accentPink,
                    ),
                    StatChip(
                      icon: LucideIcons.sparkles,
                      label: 'Matched',
                      value: '$matchedPairs/${widget.pairsCount}',
                      tone: AppColors.accentEmerald,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Auto-sizing single-screen grid (zero vertical scrolling guaranteed)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double availW = constraints.maxWidth;
                      final double availH = constraints.maxHeight;
                      final bool isLandscape = availW > availH;

                      // Determine optimal columns & rows so all cards fit without scrolling
                      int cols;
                      if (isLandscape) {
                        if (cards.length <= 12) {
                          cols = 4; // 4x3
                        } else if (cards.length <= 16) {
                          cols = 4; // 4x4
                        } else {
                          cols = 5; // 5x4
                        }
                      } else {
                        if (cards.length <= 12) {
                          cols = 3; // 3x4
                        } else if (cards.length <= 16) {
                          cols = 4; // 4x4
                        } else {
                          cols = 4; // 4x5
                        }
                      }

                      final int rows = (cards.length + cols - 1) ~/ cols;
                      final double spacing = (cards.length >= 20 || rows >= 5) ? 6.0 : 8.0;

                      // Maximum card dimensions
                      final double maxCardW = (availW - (cols - 1) * spacing) / cols;
                      final double maxCardH = (availH - (rows - 1) * spacing) / rows;

                      // Optimal aspect ratio
                      double cardAspect = (maxCardW / maxCardH).clamp(0.70, 1.05);

                      double gridW = cols * (maxCardH * cardAspect) + (cols - 1) * spacing;
                      double gridH = rows * maxCardH + (rows - 1) * spacing;

                      if (gridW > availW) {
                        gridW = availW;
                        final double actualCardW = (gridW - (cols - 1) * spacing) / cols;
                        cardAspect = (actualCardW / maxCardH).clamp(0.70, 1.05);
                        gridH = rows * (actualCardW / cardAspect) + (rows - 1) * spacing;
                      }

                      final double cardRadius = maxCardH < 90 ? 10.0 : 13.0;

                      return Center(
                        child: SizedBox(
                          width: gridW,
                          height: gridH,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: cardAspect,
                            ),
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];

                              return GestureDetector(
                                onTap: () => _onCardTap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(cardRadius),
                                    color: card.isFlipped || card.isMatched
                                        ? AppColors.glassStrong
                                        : AppColors.glassFill,
                                    border: Border.all(
                                      color: card.isMatched
                                          ? AppColors.accentEmerald
                                          : AppColors.glassBorder,
                                      width: card.isMatched ? 2 : 1,
                                    ),
                                    boxShadow: card.isMatched
                                        ? [
                                            BoxShadow(
                                              color: AppColors.accentEmerald.withValues(alpha: 0.45),
                                              blurRadius: 8,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(cardRadius - 1),
                                    child: card.isFlipped || card.isMatched
                                        ? Image.network(
                                            card.imagePath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Center(
                                              child: Icon(LucideIcons.image, color: Colors.white70, size: 24),
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              LucideIcons.brain,
                                              color: Colors.white38,
                                              size: maxCardH < 90 ? 20 : 26,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Math {
  static int max(int a, int b) => a > b ? a : b;
}
