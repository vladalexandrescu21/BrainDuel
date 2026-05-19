// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/core/constants/constants.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/features/game/models/game_state.dart';
import 'package:brainduel/features/game/providers/game_provider.dart';
import 'package:brainduel/shared/services/sound_service.dart';
import 'package:brainduel/shared/widgets/star_background.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  final String topicId;

  const MatchmakingScreen({super.key, required this.topicId});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  Timer? _dotsTimer;
  int _dotsCount = 1;
  bool _hasJoinedQueue = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() {
          _dotsCount = (_dotsCount % 3) + 1;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _joinQueue());
  }

  Future<void> _joinQueue() async {
    if (_hasJoinedQueue) return;
    _hasJoinedQueue = true;

    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    final token = await ref.read(authProvider.notifier).getIdToken() ?? '';
    ref.read(gameProvider.notifier).joinQueue(
          widget.topicId,
          authState.user!.uid,
          token,
        );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    // Navigate to game when match is found and game starts
    ref.listen<GameState>(gameProvider, (previous, next) {
      if (next.status == GameStatus.matchFound &&
          previous?.status != GameStatus.matchFound) {
        SoundService.instance.play(SoundEffect.matchFound);
      }
      if (next.status == GameStatus.playing ||
          next.status == GameStatus.matchFound) {
        if (next.status == GameStatus.playing && mounted) {
          context.go('/game');
        }
      }
      if (next.errorMessage != null && mounted) {
        _showErrorDialog(next.errorMessage!);
      }
    });

    final dots = '.' * _dotsCount;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: StarBackground(
          child: SafeArea(
            child: Stack(
            children: [
              // Back button
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    ref.read(gameProvider.notifier).leaveQueue();
                    context.go('/home');
                  },
                ),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TopicBadge(topicId: widget.topicId),
                    const SizedBox(height: 48),
                    _PulsingCircle(controller: _pulseController),
                    const SizedBox(height: 40),
                    Text(
                      '${S.findOpponent}$dots',
                      style: GoogleFonts.exo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms),
                    if (gameState.queuePosition > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${S.queuePosition}: #${gameState.queuePosition}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (gameState.status == GameStatus.matchFound) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Meci găsit! Se pornește...',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          color: AppColors.correct,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.elasticOut),
                    ],
                  ],
                ),
              ),
              // Cancel button at bottom
              Positioned(
                bottom: 32,
                left: 28,
                right: 28,
                child: TextButton(
                  onPressed: () {
                    ref.read(gameProvider.notifier).leaveQueue();
                    context.go('/home');
                  },
                  child: Text(
                    S.cancel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eroare',
            style: GoogleFonts.exo2(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/home');
            },
            child: Text(S.backToHome,
                style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _TopicBadge extends StatelessWidget {
  final String topicId;

  const _TopicBadge({required this.topicId});

  @override
  Widget build(BuildContext context) {
    final topic = kTopics.firstWhere(
      (t) => t.id == topicId,
      orElse: () => kTopics.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.topicGradient(topicId),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.topicAccentColor(topicId).withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(topic.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            topic.localizedName(S.isRomanian),
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.3, end: 0, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }
}

class _PulsingCircle extends StatelessWidget {
  final AnimationController controller;

  const _PulsingCircle({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + controller.value * 0.08;
        final glowRadius = 30.0 + controller.value * 20;
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35 + controller.value * 0.2),
                      blurRadius: glowRadius,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Background circle
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B1D8A).withOpacity(0.95),
                      const Color(0xFF0D1B2A).withOpacity(0.9),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.6 + controller.value * 0.4),
                    width: 2,
                  ),
                ),
              ),
              // Logo icon
              SvgPicture.asset(
                'assets/images/logo_icon.svg',
                width: 90,
                height: 90,
              ),
            ],
          ),
        );
      },
    );
  }
}
