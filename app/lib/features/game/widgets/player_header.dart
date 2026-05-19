import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/shared/widgets/player_avatar.dart';

class PlayerHeader extends StatelessWidget {
  final String displayName;
  final String avatarId;
  final int score;
  final bool isPlayer; // true = left side, false = right side

  const PlayerHeader({
    super.key,
    required this.displayName,
    required this.avatarId,
    required this.score,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final nameWidget = Flexible(
      child: Text(
        displayName,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: isPlayer ? TextAlign.left : TextAlign.right,
      ),
    );

    final avatarWidget = PlayerAvatar(
      avatarId: avatarId,
      displayName: displayName,
      size: 44,
      showBorder: true,
      borderColor: isPlayer ? AppColors.secondary : AppColors.primary,
    );

    final scoreWidget = Text(
      '$score',
      style: GoogleFonts.exo2(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isPlayer
              ? [avatarWidget, const SizedBox(width: 6), nameWidget]
              : [nameWidget, const SizedBox(width: 6), avatarWidget],
        ),
        const SizedBox(height: 4),
        scoreWidget,
      ],
    );
  }
}
