import 'package:flutter/material.dart';

class AvatarView extends StatelessWidget {
  final String emoji;
  final int gradientIndex;
  final double size;
  final bool hasRing;
  final String? photoUrl;
  final String? cartoonPhotoUrl;
  final String avatarStyle; // 'original' | 'cartoon' | 'emoji'

  static const List<List<Color>> avatarGradients = [
    [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF22D3EE), Color(0xFF3B82F6)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF10B981), Color(0xFF22D3EE)],
    [Color(0xFFA855F7), Color(0xFFEC4899)],
    [Color(0xFF6366F1), Color(0xFF22D3EE)],
    [Color(0xFFF97316), Color(0xFFEC4899)],
  ];

  const AvatarView({
    super.key,
    this.emoji = '🦊',
    this.gradientIndex = 0,
    this.size = 48.0,
    this.hasRing = false,
    this.photoUrl,
    this.cartoonPhotoUrl,
    this.avatarStyle = 'original',
  });

  @override
  Widget build(BuildContext context) {
    final colors = avatarGradients[gradientIndex % avatarGradients.length];
    final bool isCartoon = avatarStyle == 'cartoon';
    // When in cartoon mode, prioritize the accurately generated cartoon photo URL
    final String? activeUrl = (isCartoon && cartoonPhotoUrl != null && cartoonPhotoUrl!.trim().isNotEmpty)
        ? cartoonPhotoUrl
        : photoUrl;
    final bool hasPhoto = activeUrl != null && activeUrl.trim().isNotEmpty;

    final borderGradient = isCartoon
        ? const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFFBBF24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: borderGradient,
            boxShadow: hasRing || isCartoon
                ? [
                    BoxShadow(
                      color: isCartoon
                          ? const Color(0xFFEC4899).withValues(alpha: 0.6)
                          : colors[0].withValues(alpha: 0.55),
                      blurRadius: isCartoon ? 16 : 14,
                      spreadRadius: isCartoon ? 3 : 2,
                    )
                  ]
                : null,
          ),
          padding: EdgeInsets.all(hasPhoto ? (isCartoon ? 3.0 : 2.0) : 0),
          child: ClipOval(
            child: hasPhoto
                ? _buildPhotoImage(activeUrl, colors)
                : _buildEmojiFallback(colors),
          ),
        ),
        if (isCartoon && hasPhoto && size >= 40)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: EdgeInsets.all(size >= 60 ? 4 : 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.bolt,
                size: size >= 60 ? 14 : 10,
                color: const Color(0xFFFBBF24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoImage(String url, List<Color> colors) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(colors),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF1E1B4B),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiFallback(List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.52),
        ),
      ),
    );
  }
}
