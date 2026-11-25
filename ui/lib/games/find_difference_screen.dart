import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_chip.dart';
import '../widgets/quit_game_dialog.dart';
import 'game_result_dialog.dart';

class SpotDifference {
  final int id;
  final double xPct;
  final double yPct;
  final double radiusPct;
  bool isFound;

  SpotDifference({
    required this.id,
    required this.xPct,
    required this.yPct,
    this.radiusPct = 8.0,
    this.isFound = false,
  });
}

class FindDifferenceScreen extends StatefulWidget {
  final List<SpotDifference> spots;
  final Widget originalImage;
  final Widget modifiedImage;

  const FindDifferenceScreen({
    super.key,
    required this.spots,
    required this.originalImage,
    required this.modifiedImage,
  });

  @override
  State<FindDifferenceScreen> createState() => _FindDifferenceScreenState();
}

class _FindDifferenceScreenState extends State<FindDifferenceScreen> {
  int foundCount = 0;
  int mistakes = 0;
  int seconds = 0;
  Timer? timer;
  List<Offset> foundPoints = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
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

  void _onTapImage(TapUpDetails details, BoxConstraints constraints) {
    double tapXPct = (details.localPosition.dx / constraints.maxWidth) * 100;
    double tapYPct = (details.localPosition.dy / constraints.maxHeight) * 100;

    bool hit = false;
    for (var spot in widget.spots) {
      if (!spot.isFound) {
        double dist = (tapXPct - spot.xPct) * (tapXPct - spot.xPct) +
            (tapYPct - spot.yPct) * (tapYPct - spot.yPct);
        if (dist <= (spot.radiusPct * spot.radiusPct)) {
          hit = true;
          setState(() {
            spot.isFound = true;
            foundCount++;
            foundPoints.add(Offset(
              (spot.xPct / 100) * constraints.maxWidth,
              (spot.yPct / 100) * constraints.maxHeight,
            ));
          });
          break;
        }
      }
    }

    if (!hit) {
      setState(() => mistakes++);
    }

    if (foundCount == widget.spots.length) {
      timer?.cancel();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GameResultDialog(
          gameTitle: 'Find the Difference',
          moves: foundCount + mistakes,
          elapsedSeconds: seconds,
          score: 800 + math.max(0, 400 - (seconds * 4)),
          isPerfect: mistakes == 0,
          onPlayAgain: () => Navigator.pop(context),
        ),
      );
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
          title: const Text('Find the Difference'),
        ),
      body: SafeArea(
        child: Padding(
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
                  ),
                  StatChip(
                    icon: LucideIcons.sparkles,
                    label: 'Found',
                    value: '$foundCount / ${widget.spots.length}',
                    tone: AppColors.accentEmerald,
                  ),
                  StatChip(
                    icon: LucideIcons.circleAlert,
                    label: 'Misses',
                    value: '$mistakes',
                    tone: AppColors.accentPink,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapUp: (details) => _onTapImage(details, constraints),
                      child: Stack(
                        children: [
                          Center(child: widget.modifiedImage),
                          ...foundPoints.map((pt) => Positioned(
                                left: pt.dx - 20,
                                top: pt.dy - 20,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.accentEmerald,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentEmerald.withValues(alpha: 0.6),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                ),
                              )),
                        ],
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
