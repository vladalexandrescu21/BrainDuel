// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/shared/services/firestore_service.dart';
import 'package:brainduel/shared/widgets/player_avatar.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _selectedTab = 0; // 0 = global, 1 = friends
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await FirestoreService().getLeaderboard(limit: 50);
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.uid ?? '';

    return Container(
      decoration: AppTheme.backgroundGradient,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabToggle(),
            if (_selectedTab == 1) _buildFriendsPlaceholder() else _buildLeaderboardList(currentUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        S.leaderboard,
        style: GoogleFonts.exo2(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _TabButton(
              label: S.global,
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _TabButton(
              label: S.friends,
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(String currentUserId) {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_leaderboard.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'Nu există date disponibile',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          final player = _leaderboard[index];
          final isCurrentUser = (player['uid'] as String?) == currentUserId;
          return _LeaderboardRow(
            rank: index + 1,
            player: player,
            isCurrentUser: isCurrentUser,
          );
        },
      ),
    );
  }

  Widget _buildFriendsPlaceholder() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              S.comingSoon,
              style: GoogleFonts.exo2(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Clasamentul prietenilor va fi disponibil în curând!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> player;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.rank,
    required this.player,
    required this.isCurrentUser,
  });

  Color _rankColor() {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = player['displayName'] as String? ?? 'Player';
    final level = player['level'] as int? ?? 1;
    final wins = player['wins'] as int? ?? 0;
    final avatarId = player['avatarId'] as String? ?? 'default';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.07),
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              rank <= 3 ? _rankEmoji() : '#$rank',
              style: TextStyle(
                fontSize: rank <= 3 ? 20 : 14,
                color: _rankColor(),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          PlayerAvatar(
            avatarId: avatarId,
            displayName: displayName,
            size: 38,
          ),
          const SizedBox(width: 12),
          // Name + level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        isCurrentUser ? FontWeight.bold : FontWeight.w500,
                    color: isCurrentUser ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  S.levelLabel(level),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Wins
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: AppColors.gold, size: 16),
              const SizedBox(width: 4),
              Text(
                '$wins',
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rankEmoji() {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }
}
