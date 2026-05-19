import 'package:flutter/material.dart';
import 'package:brainduel/core/theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  final String avatarId;
  final String displayName;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const PlayerAvatar({
    super.key,
    required this.avatarId,
    required this.displayName,
    this.size = 48,
    this.showBorder = false,
    this.borderColor,
  });

  Color _avatarColor() {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.gold,
      AppColors.correct,
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
    ];
    final index = displayName.isNotEmpty
        ? displayName.codeUnitAt(0) % colors.length
        : 0;
    return colors[index];
  }

  String _initials() {
    if (displayName.isEmpty) return '?';
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, displayName.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [avatarColor, avatarColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.primary,
                width: 2.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: avatarColor.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
