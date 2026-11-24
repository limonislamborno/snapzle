import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cartoon Game Icon Badge wrapper with comic-styled frame, sunburst backdrop, and 3D depth
class CartoonGameBadge extends StatelessWidget {
  final Widget iconWidget;
  final List<Color> bgGradient;
  final Color glowColor;
  final String tagEmoji;
  final double size;

  const CartoonGameBadge({
    super.key,
    required this.iconWidget,
    required this.bgGradient,
    required this.glowColor,
    required this.tagEmoji,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main cartoon frame container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgGradient,
            ),
            border: Border.all(
              color: const Color(0xFF1E1035),
              width: 3.0,
            ),
            boxShadow: [
              // Dark cartoon drop shadow
              BoxShadow(
                color: const Color(0xFF0F0B1E).withValues(alpha: 0.9),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
              // Vibrant color glow
              BoxShadow(
                color: glowColor.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Subtle cartoon sunburst / diagonal stripe effect
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SunburstPainter(glowColor.withValues(alpha: 0.15)),
                  ),
                ),
                // Top gloss shine bubble
                Positioned(
                  top: 2,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Center cartoon illustration
                Center(child: iconWidget),
              ],
            ),
          ),
        ),

        // Corner shiny cartoon tag
        Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF130E26),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1E1035),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              tagEmoji,
              style: const TextStyle(fontSize: 11, height: 1.0),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cartoon Sunburst Background Painter
class _SunburstPainter extends CustomPainter {
  final Color rayColor;
  _SunburstPainter(this.rayColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = rayColor
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height);
    const int rays = 10;
    const double angleStep = (2 * math.pi) / rays;

    for (int i = 0; i < rays; i += 2) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(i * angleStep),
          center.dy + radius * math.sin(i * angleStep),
        )
        ..lineTo(
          center.dx + radius * math.cos((i + 1) * angleStep),
          center.dy + radius * math.sin((i + 1) * angleStep),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 1. CARTOON PHOTO PUZZLE ILLUSTRATION (Two interlocking cartoon pieces)
// =========================================================================
class CartoonPuzzleIllustration extends StatelessWidget {
  final double size;
  const CartoonPuzzleIllustration({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonPuzzlePainter(),
      ),
    );
  }
}

class _CartoonPuzzlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Piece 1: Purple / Fuchsia piece (background piece)
    final p1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE879F9), Color(0xFFA855F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final p1Shadow = Paint()..color = const Color(0xFF7E22CE);

    final inkBorder = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;

    final whiteGloss = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Draw background purple piece
    final r1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.44, h * 0.44),
      const Radius.circular(8),
    );
    // Shadow under r1
    canvas.drawRRect(r1.shift(const Offset(0, 3)), p1Shadow);
    canvas.drawRRect(r1, p1);
    canvas.drawRRect(r1, inkBorder);

    // Tab for piece 1 protruding right
    final tab1 = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.52, h * 0.34), radius: w * 0.12));
    canvas.drawPath(tab1, p1);
    canvas.drawPath(tab1, inkBorder);

    // Gloss on piece 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.22, h * 0.08),
        const Radius.circular(4),
      ),
      whiteGloss,
    );

    // Piece 2: Golden Amber piece (foreground interlocking piece)
    final p2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(w * 0.36, h * 0.36, w * 0.55, h * 0.55));

    final p2Shadow = Paint()..color = const Color(0xFFB45309);

    final r2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.38, h * 0.38, w * 0.48, h * 0.48),
      const Radius.circular(9),
    );
    canvas.drawRRect(r2.shift(const Offset(0, 3)), p2Shadow);
    canvas.drawRRect(r2, p2);
    canvas.drawRRect(r2, inkBorder);

    // Tab for piece 2 protruding top
    final tab2 = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.62, h * 0.36), radius: w * 0.13));
    canvas.drawPath(tab2, p2);
    canvas.drawPath(tab2, inkBorder);

    // Cute smiling eyes on piece 2
    final eyePaint = Paint()..color = const Color(0xFF1E1035);
    canvas.drawCircle(Offset(w * 0.53, h * 0.60), 2.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.71, h * 0.60), 2.2, eyePaint);

    // Smiling mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final mouth = Path()
      ..moveTo(w * 0.57, h * 0.68)
      ..quadraticBezierTo(w * 0.62, h * 0.74, w * 0.67, h * 0.68);
    canvas.drawPath(mouth, mouthPaint);

    // Gloss on piece 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.44, h * 0.42, w * 0.24, h * 0.08),
        const Radius.circular(4),
      ),
      whiteGloss,
    );

    // 4-point cartoon sparkle on top-right
    _drawSparkle(canvas, Offset(w * 0.88, h * 0.20), w * 0.11, const Color(0xFFFFFBEB));
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 2. CARTOON MEMORY MATCH ILLUSTRATION (Two fanned comic playing cards)
// =========================================================================
class CartoonMemoryIllustration extends StatelessWidget {
  final double size;
  const CartoonMemoryIllustration({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonMemoryPainter(),
      ),
    );
  }
}

class _CartoonMemoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final inkBorder = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;

    final whiteGloss = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // CARD 1 (Back card, tilted -14 degrees, Violet mystery card with "?")
    canvas.save();
    canvas.translate(w * 0.32, h * 0.48);
    canvas.rotate(-14 * math.pi / 180);

    final card1Rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.48, height: h * 0.64),
      const Radius.circular(8),
    );

    // Card 1 shadow
    canvas.drawRRect(card1Rect.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF1E1B4B));
    // Card 1 fill
    canvas.drawRRect(
      card1Rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(card1Rect.outerRect),
    );
    canvas.drawRRect(card1Rect, inkBorder);

    // Draw yellow Question Mark "?" on Card 1
    final textPainter1 = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Color(0xFFFDE047),
          fontSize: 19,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Color(0xFF1E1035), blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter1.paint(canvas, Offset(-textPainter1.width / 2, -textPainter1.height / 2));

    canvas.restore();

    // CARD 2 (Front card, tilted +12 degrees, Cyan card with matching Star ⭐)
    canvas.save();
    canvas.translate(w * 0.62, h * 0.54);
    canvas.rotate(12 * math.pi / 180);

    final card2Rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.48, height: h * 0.64),
      const Radius.circular(8),
    );

    // Card 2 shadow
    canvas.drawRRect(card2Rect.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF0369A1));
    // Card 2 fill
    canvas.drawRRect(
      card2Rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(card2Rect.outerRect),
    );
    canvas.drawRRect(card2Rect, inkBorder);

    // Draw Golden Star ⭐ icon on Card 2
    final textPainter2 = TextPainter(
      text: const TextSpan(
        text: '⭐',
        style: TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter2.paint(canvas, Offset(-textPainter2.width / 2, -textPainter2.height / 2));

    // Gloss strip on card 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.18, -h * 0.26, w * 0.36, h * 0.08),
        const Radius.circular(3),
      ),
      whiteGloss,
    );

    canvas.restore();

    // Floating comic lightning bolt ⚡ on top-right
    final zapPainter = TextPainter(
      text: const TextSpan(
        text: '⚡',
        style: TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zapPainter.paint(canvas, Offset(w * 0.72, h * 0.02));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 3. CARTOON SLIDING PUZZLE ILLUSTRATION (Colorful 3D puzzle grid with slide arrow)
// =========================================================================
class CartoonSlidingIllustration extends StatelessWidget {
  final double size;
  const CartoonSlidingIllustration({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonSlidingPainter(),
      ),
    );
  }
}

class _CartoonSlidingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final inkBorder = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;

    final whiteGloss = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Tray background
    final trayRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88),
      const Radius.circular(12),
    );
    // Tray shadow
    canvas.drawRRect(trayRect.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF0F0B1E));
    canvas.drawRRect(trayRect, Paint()..color = const Color(0xFF1E1B4B));
    canvas.drawRRect(trayRect, inkBorder);

    // 4 tiles (3 filled, 1 empty slot with slide arrow)
    final double tw = w * 0.36;
    final double th = h * 0.36;
    final double pad = w * 0.10;

    // Tile 1: Top-Left (Coral Pink "1")
    _drawTile(
      canvas: canvas,
      rect: Rect.fromLTWH(pad, pad, tw, th),
      gradientColors: const [Color(0xFFFB7185), Color(0xFFE11D48)],
      shadowColor: const Color(0xFF9F1239),
      numberText: '1',
      inkBorder: inkBorder,
      whiteGloss: whiteGloss,
    );

    // Tile 2: Top-Right (Sunny Yellow "2")
    _drawTile(
      canvas: canvas,
      rect: Rect.fromLTWH(pad + tw + 4, pad, tw, th),
      gradientColors: const [Color(0xFFFDE047), Color(0xFFF59E0B)],
      shadowColor: const Color(0xFFB45309),
      numberText: '2',
      inkBorder: inkBorder,
      whiteGloss: whiteGloss,
    );

    // Tile 3: Bottom-Left (Emerald Mint "3")
    _drawTile(
      canvas: canvas,
      rect: Rect.fromLTWH(pad, pad + th + 4, tw, th),
      gradientColors: const [Color(0xFF34D399), Color(0xFF059669)],
      shadowColor: const Color(0xFF065F46),
      numberText: '3',
      inkBorder: inkBorder,
      whiteGloss: whiteGloss,
    );

    // Tile 4 (Bottom-Right): Empty slot with comic dashed cavity and curved slide arrow
    final emptySlot = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad + tw + 4, pad + th + 4, tw, th),
      const Radius.circular(7),
    );
    canvas.drawRRect(emptySlot, Paint()..color = const Color(0xFF0F0B1E));

    final dashPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(emptySlot, dashPaint);

    // Slide arrow inside empty slot
    final arrowPainter = TextPainter(
      text: const TextSpan(
        text: '➜',
        style: TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    arrowPainter.paint(
      canvas,
      Offset(pad + tw + 4 + (tw - arrowPainter.width) / 2, pad + th + 4 + (th - arrowPainter.height) / 2),
    );
  }

  void _drawTile({
    required Canvas canvas,
    required Rect rect,
    required List<Color> gradientColors,
    required Color shadowColor,
    required String numberText,
    required Paint inkBorder,
    required Paint whiteGloss,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    // 3D bottom bevel
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), Paint()..color = shadowColor);
    // Face gradient
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    canvas.drawRRect(rrect, inkBorder);

    // Top gloss
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width - 6, 4),
        const Radius.circular(2),
      ),
      whiteGloss,
    );

    // Number text
    final tp = TextPainter(
      text: TextSpan(
        text: numberText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Color(0xFF1E1035), blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.left + (rect.width - tp.width) / 2, rect.top + (rect.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
