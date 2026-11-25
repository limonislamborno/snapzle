import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GamingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final Border? border;
  final Gradient? gradient;

  const GamingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? Colors.white;
    final effectiveGradient = gradient ?? (color == null ? AppColors.brandGradient : null);
    final shadowColor = effectiveGradient is LinearGradient && effectiveGradient.colors.isNotEmpty
        ? effectiveGradient.colors.first
        : (color ?? AppColors.primaryOrange);

    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        color: effectiveGradient == null ? color : null,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: color != null && border != null
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: effectiveTextColor, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: effectiveTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
