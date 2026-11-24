import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_chip.dart';
import '../widgets/quit_game_dialog.dart';
import '../services/game_progress_service.dart';
import 'game_result_dialog.dart';

class SlidingPuzzleScreen extends StatefulWidget {
  final String imageUrl;
  final String photoId;
  final int gridDim; // 3 for 3x3, 4 for 4x4

  const SlidingPuzzleScreen({
    super.key,
    required this.imageUrl,
    this.photoId = '',
    this.gridDim = 3,
  });

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  late List<int> tiles;
  int emptyIdx = 0;
  int moves = 0;
  int seconds = 0;
  Timer? timer;
  ui.Image? _decodedImage;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _initBoard();
    _loadImage();
  }

  void _loadImage() {
    final ImageProvider provider = NetworkImage(widget.imageUrl);
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener(
      (ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _decodedImage = info.image;
            _isLoadingImage = false;
          });
          _startTimer();
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        if (mounted) {
          setState(() => _isLoadingImage = false);
          _startTimer();
        }
      },
    ));
  }

  void _initBoard() {
    int total = widget.gridDim * widget.gridDim;
    // Solved initial state: [0, 1, 2, ..., total - 2, -1]
    // -1 represents the single empty slot at the bottom-right
    tiles = List.generate(total - 1, (i) => i)..add(-1);
    emptyIdx = total - 1;

    // Simulate random legal moves from the winning state to ensure solvability
    int prevSwap = -1;
    for (int i = 0; i < 100; i++) {
      List<int> validMoves = _getNeighbors(emptyIdx);
      if (prevSwap != -1 && validMoves.length > 1) {
        validMoves.remove(prevSwap);
      }
      int swapWith = (validMoves..shuffle()).first;
      tiles[emptyIdx] = tiles[swapWith];
      tiles[swapWith] = -1;
      prevSwap = emptyIdx;
      emptyIdx = swapWith;
    }
  }

  List<int> _getNeighbors(int idx) {
    List<int> neighbors = [];
    int row = idx ~/ widget.gridDim;
    int col = idx % widget.gridDim;

    if (row > 0) neighbors.add(idx - widget.gridDim);
    if (row < widget.gridDim - 1) neighbors.add(idx + widget.gridDim);
    if (col > 0) neighbors.add(idx - 1);
    if (col < widget.gridDim - 1) neighbors.add(idx + 1);

    return neighbors;
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _onTileTap(int idx) {
    if (_getNeighbors(emptyIdx).contains(idx)) {
      setState(() {
        tiles[emptyIdx] = tiles[idx];
        tiles[idx] = -1;
        emptyIdx = idx;
        moves++;
      });

      _checkWin();
    }
  }

  void _checkWin() {
    bool solved = true;
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i) {
        solved = false;
        break;
      }
    }

    if (solved && emptyIdx == tiles.length - 1) {
      timer?.cancel();
      final effectivePhotoId = widget.photoId.isNotEmpty ? widget.photoId : widget.imageUrl;
      GameProgressService.recordSlidingPuzzleWin(
        dim: widget.gridDim,
        photoId: effectivePhotoId,
      ).then((res) {
        if (!mounted) return;
        String? unlockMsg;
        if (res.unlockedNextTier) {
          unlockMsg = '🎉 4×4 Sliding Grid Unlocked! (5/5 photos cleared)';
        } else if (res.isNewPhoto && res.totalCleared < GameProgressService.requiredPhotosToUnlock) {
          unlockMsg = '🌟 Photo Cleared! (${res.totalCleared}/5 for 4×4)';
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => GameResultDialog(
            gameTitle: 'Sliding Puzzle ${widget.gridDim}×${widget.gridDim}',
            moves: moves,
            elapsedSeconds: seconds,
            score: (widget.gridDim * 350) + math.max(0, 450 - (seconds * 3)),
            isPerfect: moves <= (widget.gridDim * 12),
            unlockMessage: unlockMsg,
            onPlayAgain: () {
              Navigator.pop(context);
              setState(() {
                moves = 0;
                seconds = 0;
                _initBoard();
                _startTimer();
              });
            },
          ),
        );
      });
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
          title: Text('Sliding Puzzle ${widget.gridDim}×${widget.gridDim}'),
        ),
      body: SafeArea(
        child: _isLoadingImage
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Slicing your photo into sliding tiles...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: GlassCard(
                            padding: const EdgeInsets.all(6.0),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: widget.gridDim,
                                crossAxisSpacing: 5,
                                mainAxisSpacing: 5,
                              ),
                              itemCount: tiles.length,
                              itemBuilder: (context, index) {
                                int val = tiles[index];

                                // Empty slot (where adjacent tiles can slide into)
                                if (val == -1) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        style: BorderStyle.solid,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        LucideIcons.arrowDownUp,
                                        size: 18,
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                  );
                                }

                                bool canMove = _getNeighbors(emptyIdx).contains(index);

                                return GestureDetector(
                                  onTap: () => _onTileTap(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: canMove
                                            ? AppColors.primary.withValues(alpha: 0.8)
                                            : AppColors.glassBorder,
                                        width: canMove ? 2.0 : 1.0,
                                      ),
                                      boxShadow: canMove
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (_decodedImage != null)
                                            CustomPaint(
                                              painter: _TileImagePainter(
                                                image: _decodedImage,
                                                tileIndex: val,
                                                gridDim: widget.gridDim,
                                              ),
                                            )
                                          else
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: AppColors.brandGradient,
                                              ),
                                            ),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                ),
                                              ),
                                              child: Text(
                                                '${val + 1}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap any tile adjacent to the empty slot to slide it.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
      ),
    ),
    );
  }
}

class _TileImagePainter extends CustomPainter {
  final ui.Image? image;
  final int tileIndex;
  final int gridDim;

  _TileImagePainter({
    required this.image,
    required this.tileIndex,
    required this.gridDim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;

    final double tileW = image!.width / gridDim;
    final double tileH = image!.height / gridDim;
    final int srcRow = tileIndex ~/ gridDim;
    final int srcCol = tileIndex % gridDim;

    final srcRect = Rect.fromLTWH(srcCol * tileW, srcRow * tileH, tileW, tileH);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image!, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _TileImagePainter oldDelegate) {
    return oldDelegate.tileIndex != tileIndex || oldDelegate.image != image;
  }
}
