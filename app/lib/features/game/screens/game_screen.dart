// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/core/constants/constants.dart';
import 'package:brainduel/features/game/models/game_state.dart';
import 'package:brainduel/features/game/models/ability_model.dart';
import 'package:brainduel/features/game/providers/game_provider.dart';
import 'package:brainduel/features/game/widgets/answer_button.dart';
import 'package:brainduel/features/game/widgets/timer_bar.dart';
import 'package:brainduel/features/game/widgets/ability_bar.dart';
import 'package:brainduel/features/game/widgets/player_header.dart';
import 'package:brainduel/features/profile/providers/profile_provider.dart';
import 'package:brainduel/shared/services/sound_service.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  OverlayEntry? _pointsOverlay;
  bool _hasNavigatedToResult = false;
  int _lastTickSecond = -1;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: AppConstants.normalRoundTime),
    );
    _timerController.addListener(_handleTimerTick);
    _startTimer();
  }

  void _startTimer() {
    final timeLimit = ref.read(gameProvider).timeLimit;
    _timerController.duration = Duration(seconds: timeLimit);
    _timerController.forward(from: 1.0);
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Timer reached 0 — auto-submit if no answer
        final gameState = ref.read(gameProvider);
        if (!gameState.hasAnswered && gameState.status == GameStatus.playing) {
          // Submit -1 to indicate timeout
          ref.read(gameProvider.notifier).submitAnswer(-1);
        }
      }
    });
  }

  void _resetTimer(int timeLimit) {
    _lastTickSecond = -1;
    _timerController.duration = Duration(seconds: timeLimit);
    _timerController.forward(from: 1.0);
  }

  void _handleTimerTick() {
    final progress = _timerController.value; // 1.0 = full → 0.0 = expired
    final gameState = ref.read(gameProvider);
    if (gameState.status != GameStatus.playing) return;
    final secondsLeft = (progress * gameState.timeLimit).ceil();
    if (secondsLeft > 0 && secondsLeft <= 3 && secondsLeft != _lastTickSecond) {
      _lastTickSecond = secondsLeft;
      SoundService.instance.play(SoundEffect.timerUrgent);
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pointsOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final profileState = ref.watch(profileProvider);

    ref.listen<GameState>(gameProvider, (previous, next) {
      // New question: reset timer + reset tick tracker
      if (previous?.currentRound != next.currentRound &&
          next.status == GameStatus.playing) {
        _resetTimer(next.timeLimit);
      }
      // Bonus round started
      if (next.isBonus && !(previous?.isBonus ?? false)) {
        SoundService.instance.play(SoundEffect.bonusRound);
      }
      // On round result: pause timer, play correct/wrong sound, show points
      if (previous?.status == GameStatus.playing &&
          next.status == GameStatus.roundResult) {
        _timerController.stop();
        final isCorrect =
            next.correctIndex != null && next.playerAnswer == next.correctIndex;
        SoundService.instance
            .play(isCorrect ? SoundEffect.correct : SoundEffect.wrong);
        if (next.pointsThisRound != null && next.pointsThisRound! > 0) {
          _showPointsOverlay(context, next.pointsThisRound!);
        }
      }
      // Navigate to result
      if (next.status == GameStatus.finished && !_hasNavigatedToResult) {
        _hasNavigatedToResult = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go('/result');
        });
      }
      // Handle opponent disconnect
      if (next.errorMessage == 'opponent_disconnected') {
        _showOpponentDisconnectedDialog();
        ref.read(gameProvider.notifier).clearError();
      }
    });

    if (gameState.currentQuestion == null) {
      return const _LoadingGameScreen();
    }

    final question = gameState.currentQuestion!;
    final opponent = gameState.opponent;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // Player headers top
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PlayerHeader(
                        displayName: profileState.displayName,
                        avatarId: profileState.avatarId,
                        score: gameState.playerScore,
                        isPlayer: true,
                      ),
                    ),
                    _RoundIndicator(
                      round: gameState.currentRound,
                      total: AppConstants.totalRounds,
                      isBonus: gameState.isBonus,
                    ),
                    Expanded(
                      child: PlayerHeader(
                        displayName: opponent?.displayName ?? 'Opponent',
                        avatarId: opponent?.avatarId ?? 'default',
                        score: gameState.opponentScore,
                        isPlayer: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Round label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  gameState.isBonus
                      ? S.bonusRoundLabel
                      : '${S.round} ${gameState.currentRound}',
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gameState.isBonus ? AppColors.gold : AppColors.secondary,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              // Question card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration,
                  child: Text(
                    question.text,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
                    .animate(key: ValueKey(question.id))
                    .slideY(begin: 0.1, end: 0, duration: 300.ms)
                    .fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: 12),
              // Timer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TimerBar(
                  controller: _timerController,
                  totalSeconds: gameState.timeLimit,
                ),
              ),
              const SizedBox(height: 12),
              // Answer buttons
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AnswerGrid(
                    key: ValueKey(question.id),
                    answers: question.answers,
                    playerAnswer: gameState.playerAnswer,
                    correctIndex: gameState.correctIndex,
                    opponentAnswer: gameState.opponentAnswer,
                    eliminatedAnswers: gameState.eliminatedAnswers,
                    isRoundResult: gameState.status == GameStatus.roundResult,
                    onAnswerTap: (index) {
                      if (!gameState.hasAnswered &&
                          gameState.status == GameStatus.playing) {
                        _timerController.stop();
                        SoundService.instance.play(SoundEffect.tap);
                        ref.read(gameProvider.notifier).submitAnswer(index);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Ability bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AbilityBar(
                  abilities: gameState.availableAbilities,
                  usedAbilities: gameState.usedAbilities,
                  onAbilityTap: (type) {
                    SoundService.instance.play(SoundEffect.ability);
                    ref.read(gameProvider.notifier).useAbility(type);
                  },
                  activeEffect: gameState.abilityEffectType,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPointsOverlay(BuildContext context, int points) {
    _pointsOverlay?.remove();
    final overlay = Overlay.of(context);
    _pointsOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).size.height * 0.42,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.correct.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.correct.withOpacity(0.5),
                    blurRadius: 20,
                  )
                ],
              ),
              child: Text(
                '+$points',
                style: GoogleFonts.exo2(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
                .animate()
                .scale(duration: 300.ms, curve: Curves.elasticOut)
                .then(delay: 900.ms)
                .fadeOut(duration: 300.ms),
          ),
        ),
      ),
    );
    overlay.insert(_pointsOverlay!);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _pointsOverlay?.remove();
      _pointsOverlay = null;
    });
  }

  void _showOpponentDisconnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          S.opponentDisconnected,
          style:
              GoogleFonts.exo2(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Vei fi declarat câștigător.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/home');
            },
            child: Text(S.backToHome),
          ),
        ],
      ),
    );
  }
}

class _LoadingGameScreen extends StatelessWidget {
  const _LoadingGameScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.backgroundGradient,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _RoundIndicator extends StatelessWidget {
  final int round;
  final int total;
  final bool isBonus;

  const _RoundIndicator({
    required this.round,
    required this.total,
    required this.isBonus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VS',
          style: GoogleFonts.exo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isBonus
                ? AppColors.gold.withOpacity(0.2)
                : AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isBonus ? AppColors.gold : AppColors.primary,
              width: 1,
            ),
          ),
          child: Text(
            isBonus ? 'BONUS' : S.roundOf(round, total),
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isBonus ? AppColors.gold : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  final List<String> answers;
  final int? playerAnswer;
  final int? correctIndex;
  final int? opponentAnswer;
  final List<int> eliminatedAnswers;
  final bool isRoundResult;
  final void Function(int index) onAnswerTap;

  const _AnswerGrid({
    super.key,
    required this.answers,
    required this.playerAnswer,
    required this.correctIndex,
    required this.opponentAnswer,
    required this.eliminatedAnswers,
    required this.isRoundResult,
    required this.onAnswerTap,
  });

  AnswerButtonState _stateForIndex(int index) {
    if (eliminatedAnswers.contains(index)) {
      return AnswerButtonState.eliminated;
    }

    if (isRoundResult) {
      final isCorrect = correctIndex == index;
      final isPlayerChoice = playerAnswer == index;
      final isOpponentChoice = opponentAnswer == index;

      if (isCorrect) return AnswerButtonState.correct;
      if (isPlayerChoice && !isCorrect) return AnswerButtonState.wrong;
      if (isOpponentChoice && !isCorrect) return AnswerButtonState.opponentChose;
      return AnswerButtonState.disabled;
    }

    if (playerAnswer == index) return AnswerButtonState.selected;
    if (playerAnswer != null) return AnswerButtonState.disabled;
    return AnswerButtonState.normal;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
      ),
      itemCount: answers.length,
      itemBuilder: (context, index) {
        return AnswerButton(
          index: index,
          text: answers[index],
          buttonState: _stateForIndex(index),
          onTap: () => onAnswerTap(index),
        )
            .animate(delay: Duration(milliseconds: index * 80))
            .slideY(begin: 0.2, end: 0, duration: 300.ms)
            .fadeIn(duration: 300.ms);
      },
    );
  }
}
