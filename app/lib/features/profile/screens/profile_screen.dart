// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/features/profile/providers/profile_provider.dart';
import 'package:brainduel/features/game/models/ability_model.dart';
import 'package:brainduel/shared/widgets/player_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    if (profileState.isLoading) {
      return Container(
        decoration: AppTheme.backgroundGradient,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Container(
      decoration: AppTheme.backgroundGradient,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarSection(context, ref, profileState),
              const SizedBox(height: 20),
              _buildLevelAndXp(profileState),
              const SizedBox(height: 24),
              _buildStatsGrid(profileState),
              const SizedBox(height: 24),
              _buildSelectedAbilities(profileState),
              const SizedBox(height: 24),
              _buildCoinDisplay(profileState),
              const SizedBox(height: 32),
              _buildSignOutButton(context, ref),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(
      BuildContext context, WidgetRef ref, ProfileState profileState) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PlayerAvatar(
          avatarId: profileState.avatarId,
          displayName: profileState.displayName,
          size: 100,
          showBorder: true,
          borderColor: AppColors.primary,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: GestureDetector(
            onTap: () => _showEditNameDialog(context, ref, profileState),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    )
        .animate()
        .scale(duration: 500.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms);
  }

  Widget _buildLevelAndXp(ProfileState profileState) {
    return Column(
      children: [
        Text(
          profileState.displayName,
          style: GoogleFonts.exo2(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            S.levelLabel(profileState.level),
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // XP Progress bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.xpProgress(profileState.xp, profileState.xpToNextLevel),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: profileState.xpProgress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ProfileState profileState) {
    final stats = profileState.stats;
    final items = [
      _StatItem(label: S.wins, value: '${stats['wins'] ?? 0}', color: AppColors.correct),
      _StatItem(label: S.losses, value: '${stats['losses'] ?? 0}', color: AppColors.wrong),
      _StatItem(label: S.draws, value: '${stats['draws'] ?? 0}', color: AppColors.secondary),
      _StatItem(
          label: S.totalGames,
          value: '${stats['totalGames'] ?? 0}',
          color: AppColors.gold),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.value,
                style: GoogleFonts.exo2(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedAbilities(ProfileState profileState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.selectedAbilities,
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: profileState.selectedAbilities.map((abilityStr) {
            final abilityType = AbilityModel.fromString(abilityStr);
            final ability = AbilityModel.fromType(abilityType);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ability.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ability.color.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ability.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      ability.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ability.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCoinDisplay(ProfileState profileState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 28),
          const SizedBox(width: 10),
          Text(
            '${profileState.coins}',
            style: GoogleFonts.exo2(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            S.coins,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        await ref.read(authProvider.notifier).signOut();
        if (context.mounted) context.go('/login');
      },
      icon: const Icon(Icons.logout, color: AppColors.wrong),
      label: Text(
        S.signOut,
        style: GoogleFonts.inter(color: AppColors.wrong),
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, ProfileState profileState) {
    final controller =
        TextEditingController(text: profileState.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          S.editProfile,
          style: GoogleFonts.exo2(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nume',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(profileProvider.notifier)
                    .updateDisplayName(controller.text.trim());
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Salvează',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
}
