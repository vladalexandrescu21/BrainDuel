// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/core/constants/constants.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/features/profile/providers/profile_provider.dart';
import 'package:brainduel/features/home/widgets/topic_card.dart';
import 'package:brainduel/shared/widgets/player_avatar.dart';
import 'package:brainduel/shared/widgets/star_background.dart';
import 'package:brainduel/shared/services/sound_service.dart';

/// The tab content for the Home tab (used inside HomeShell)
class HomeTabContent extends ConsumerWidget {
  const HomeTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);

    return Container(
      decoration: AppTheme.backgroundGradient,
      child: StarBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, authState, profileState),
                const SizedBox(height: 28),
                _buildQuickMatchButton(context, profileState),
                const SizedBox(height: 28),
                _buildTopicsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthState authState,
      ProfileState profileState) {
    return Row(
      children: [
        PlayerAvatar(
          avatarId: profileState.avatarId,
          displayName: profileState.displayName,
          size: 52,
          showBorder: true,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${S.heyUser}, ${profileState.displayName}!',
                style: GoogleFonts.exo2(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  S.levelLabel(profileState.level),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        _CoinDisplay(coins: profileState.coins),
      ],
    );
  }

  Widget _buildQuickMatchButton(
      BuildContext context, ProfileState profileState) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(SoundEffect.tap);
        context.go('/matchmaking/general_knowledge');
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flash_on, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              S.quickMatch,
              style: GoogleFonts.exo2(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.chooseATopic,
          style: GoogleFonts.exo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: kTopics.length,
          itemBuilder: (context, index) {
            final topic = kTopics[index];
            return TopicCard(
              topic: topic,
              onTap: () {
                SoundService.instance.play(SoundEffect.tap);
                context.go('/matchmaking/${topic.id}');
              },
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// HomeScreen wrapper — only used if navigating to '/home' directly
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const HomeTabContent();
  }
}

class _CoinDisplay extends StatelessWidget {
  final int coins;

  const _CoinDisplay({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 18),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}
