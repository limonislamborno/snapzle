import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

Future<bool> showQuitGameConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      title: const Row(
        children: [
          Icon(LucideIcons.circleAlert, color: AppColors.accentPink, size: 24),
          SizedBox(width: 10),
          Text(
            'Quit Game?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to leave? Your current puzzle progress will be lost.',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Keep Playing',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Quit Game', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return result ?? false;
}
