import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_chip.dart';
import '../widgets/quit_game_dialog.dart';
import '../services/game_progress_service.dart';
import 'game_result_dialog.dart';

class PhotoPuzzleScreen extends StatefulWidget {
  final String imageUrl;
  final String photoId;
  final int gridDim; // 3 for 3x3, 4 for 4x4, 5 for 5x5
  final String? sessionId;

  const PhotoPuzzleScreen({
    super.key,
    required this.imageUrl,
    this.photoId = '',
    this.gridDim = 3,
    this.sessionId,
  });

  @override
  State<PhotoPuzzleScreen> createState() => _PhotoPuzzleScreenState();
}

class _PhotoPuzzleScreenState extends State<PhotoPuzzleScreen> {
  late List<int> tiles;
  int moves = 0;
  int seconds = 0;
  Timer? timer;
  int? selectedTileIndex;
  ui.Image? _decodedImage;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
    _loadImage();
  }

  void _initPuzzle() {
    int count = widget.gridDim * widget.gridDim;
    tiles = List.generate(count, (i) => i);
    tiles.shuffle();
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
        if (mounted) setState(() => _isLoadingImage = false);
      },
    ));
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

  void _onTileTap(int index) {
    if (selectedTileIndex == null) {
      setState(() => selectedTileIndex = index);
    } else {
      setState(() {
        int temp = tiles[selectedTileIndex!];
        tiles[selectedTileIndex!] = tiles[index];
        tiles[index] = temp;
        moves++;
        selectedTileIndex = null;
      });

      _checkWin();
    }
  }

  void _checkWin() {
    bool isSolved = true;
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) {
        isSolved = false;
        break;
      }
    }

    if (isSolved) {
      timer?.cancel();
      final effectivePhotoId = widget.photoId.isNotEmpty ? widget.photoId : widget.imageUrl;
      GameProgressService.recordPhotoPuzzleWin(
        dim: widget.gridDim,
        photoId: effectivePhotoId,
      ).then((res) {
        if (!mounted) return;
        String? unlockMsg;
        if (res.unlockedNextTier) {
          unlockMsg = widget.gridDim == 3
              ? '🎉 4×4 Grid Unlocked! (5/5 photos cleared)'
              : '🎉 5×5 Master Grid Unlocked! (5/5 photos cleared)';
        } else if (res.isNewPhoto && res.totalCleared < GameProgressService.requiredPhotosToUnlock) {
          unlockMsg = '🌟 Photo Cleared! (${res.totalCleared}/5 for ${widget.gridDim == 3 ? '4×4' : '5×5'})';
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => GameResultDialog(
            gameTitle: 'Photo Puzzle ${widget.gridDim}×${widget.gridDim}',
            moves: moves,
            elapsedSeconds: seconds,
            score: (widget.gridDim * 300) + (1000 ~/ (seconds + 1)),
            isPerfect: moves <= (widget.gridDim * widget.gridDim),
            unlockMessage: unlockMsg,
            onPlayAgain: () {
              Navigator.pop(context);
              setState(() {
                moves = 0;
                seconds = 0;
                _initPuzzle();
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
          title: Text('Photo Puzzle ${widget.gridDim}×${widget.gridDim}'),
        ),
      body: SafeArea(
        child: _isLoadingImage
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Slicing your photo into puzzle pieces...', style: TextStyle(color: Colors.white70)),
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
                                crossAxisSpacing: 4.0,
                                mainAxisSpacing: 4.0,
                              ),
                              itemCount: tiles.length,
                              itemBuilder: (context, index) {
                                int tileValue = tiles[index];
                                bool isSelected = selectedTileIndex == index;

                                return GestureDetector(
                                  onTap: () => _onTileTap(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppColors.accentPink : AppColors.glassBorder,
                                        width: isSelected ? 3.0 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.accentPink.withValues(alpha: 0.6),
                                                blurRadius: 12,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CustomPaint(
                                            painter: _TileImagePainter(
                                              image: _decodedImage,
                                              tileIndex: tileValue,
                                              gridDim: widget.gridDim,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.55),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                ),
                                              ),
                                              child: Text(
                                                '${tileValue + 1}',
                                                style: const TextStyle(
                                                  fontSize: 10,
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
                      'Tap one piece and then another to swap them.',
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
    if (image == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF1E1645));
      return;
    }

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
