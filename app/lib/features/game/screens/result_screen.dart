// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/features/game/models/game_state.dart';
import 'package:brainduel/features/game/providers/game_provider.dart';
import 'package:brainduel/features/profile/providers/profile_provider.dart';
import 'package:brainduel/shared/services/sound_service.dart';
import 'package:brainduel/shared/widgets/brain_button.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playResultSounds());
  }

  void _playResultSounds() {
    final gameState = ref.read(gameProvider);
    final authState = ref.read(authProvider);
    final result = gameState.result;
    if (result == null) return;

    final userId = authState.user?.uid ?? '';
    final isWin = result.winnerId == userId;
    final isDraw = result.winnerId == 'draw';

    if (isWin) {
      SoundService.instance.play(SoundEffect.win);
      // Coin sound after win fanfare
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) SoundService.instance.play(SoundEffect.coin);
      });
    } else if (isDraw) {
      SoundService.instance.play(SoundEffect.draw);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) SoundService.instance.play(SoundEffect.coin);
      });
    } else {
      SoundService.instance.play(SoundEffect.lose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);

    final result = gameState.result;
    if (result == null) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final userId = authState.user?.uid ?? '';
    final isWin = result.winnerId == userId;
    final isDraw = result.winnerId == 'draw';

    final gradient = isWin
        ? AppTheme.winGradient
        : isDraw
            ? AppTheme.drawGradient
            : AppTheme.loseGradient;

    final titleText = isWin
        ? '${S.youWin} 🎉'
        : isDraw
            ? '${S.draw} 🤝'
            : '${S.youLose} 😔';

    final titleColor = isWin
        ? AppColors.gold
        : isDraw
            ? AppColors.secondary
            : AppColors.textSecondary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Title
                Text(
                  titleText,
                  style: GoogleFonts.exo2(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 32),
                // Score comparison
                _ScoreComparison(
                  playerName: profileState.displayName,
                  opponentName: gameState.opponent?.displayName ?? 'Opponent',
                  playerScore: result.playerFinalScore,
                  opponentScore: result.opponentFinalScore,
                )
                    .animate()
                    .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 200.ms)
                    .fadeIn(duration: 500.ms, delay: 200.ms),
                const SizedBox(height: 28),
                // Rewards
                _RewardBanner(
                  xpGained: result.xpGained,
                  coinsGained: result.coinsGained,
                )
                    .animate()
                    .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 400.ms)
                    .fadeIn(duration: 500.ms, delay: 400.ms),
                const Spacer(),
                // Buttons
                BrainButton(
                  label: S.playAgain,
                  onPressed: () {
                    SoundService.instance.play(SoundEffect.tap);
                    ref.read(gameProvider.notifier).resetGame();
                    context.go('/home');
                  },
                )
                    .animate()
                    .slideY(begin: 0.4, end: 0, duration: 500.ms, delay: 600.ms)
                    .fadeIn(duration: 500.ms, delay: 600.ms),
                const SizedBox(height: 12),
                BrainButton(
                  label: S.backToHome,
                  isOutlined: true,
                  onPressed: () {
                    SoundService.instance.play(SoundEffect.tap);
                    ref.read(gameProvider.notifier).resetGame();
                    context.go('/home');
                  },
                )
                    .animate()
                    .slideY(begin: 0.4, end: 0, duration: 500.ms, delay: 700.ms)
                    .fadeIn(duration: 500.ms, delay: 700.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreComparison extends StatelessWidget {
  final String playerName;
  final String opponentName;
  final int playerScore;
  final int opponentScore;

  const _ScoreComparison({
    required this.playerName,
    required this.opponentName,
    required this.playerScore,
    required this.opponentScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScoreColumn(
            name: playerName,
            score: playerScore,
            isHighlighted: playerScore >= opponentScore,
          ),
          Text(
            ':',
            style: GoogleFonts.exo2(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          _ScoreColumn(
            name: opponentName,
            score: opponentScore,
            isHighlighted: opponentScore > playerScore,
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final int score;
  final bool isHighlighted;

  const _ScoreColumn({
    required this.name,
    required this.score,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$score',
          style: GoogleFonts.exo2(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? AppColors.gold : Colors.white.withOpacity(0.7),
          ),
        ),
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RewardBanner extends StatelessWidget {
  final int xpGained;
  final int coinsGained;

  const _RewardBanner({
    required this.xpGained,
    required this.coinsGained,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RewardItem(
            icon: Icons.star,
            color: AppColors.secondary,
            label: S.xpGained,
            value: '+$xpGained',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.15),
          ),
          _RewardItem(
            icon: Icons.monetization_on,
            color: AppColors.gold,
            label: S.coinsGained,
            value: '+$coinsGained',
          ),
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RewardItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
