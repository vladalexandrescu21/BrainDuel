import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brainduel/core/constants/constants.dart';
import 'package:brainduel/features/game/models/game_state.dart';
import 'package:brainduel/features/game/models/question_model.dart';
import 'package:brainduel/features/game/models/ability_model.dart';
import 'package:brainduel/shared/services/socket_service.dart';
import 'package:brainduel/shared/services/firestore_service.dart';

class GameNotifier extends StateNotifier<GameState> {
  final SocketService _socket;
  final FirestoreService _firestore;
  DateTime? _roundStartTime;
  Timer? _autoAdvanceTimer;
  String? _currentUserId;

  GameNotifier({
    required SocketService socket,
    required FirestoreService firestore,
  })  : _socket = socket,
        _firestore = firestore,
        super(const GameState()) {
    _setupSocketCallbacks();
  }

  void _setupSocketCallbacks() {
    _socket.onQueueJoined = _onQueueJoined;
    _socket.onMatchFound = _onMatchFound;
    _socket.onGameStart = _onGameStart;
    _socket.onNewQuestion = _onNewQuestion;
    _socket.onRoundResult = _onRoundResult;
    _socket.onAbilityEffect = _onAbilityEffect;
    _socket.onGameEnd = _onGameEnd;
    _socket.onOpponentDisconnected = _onOpponentDisconnected;
    _socket.onError = _onSocketError;
  }

  Future<void> joinQueue(
      String topicId, String userId, String token) async {
    _currentUserId = userId;
    state = state.copyWith(
      status: GameStatus.searching,
      clearError: true,
    );
    _socket.connect(AppConstants.serverUrl);

    // Wait until connected before emitting (max 5 seconds)
    int waited = 0;
    while (!_socket.isConnected && waited < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }
    _socket.joinQueue(topicId: topicId, userId: userId, token: token);
  }

  void leaveQueue() {
    _socket.leaveQueue();
    state = const GameState();
  }

  void submitAnswer(int answerIndex) {
    if (state.hasAnswered) return;
    final timeTaken = _roundStartTime != null
        ? DateTime.now().difference(_roundStartTime!).inMilliseconds
        : 0;

    state = state.copyWith(playerAnswer: answerIndex);
    _socket.submitAnswer(answerIndex: answerIndex, timeTaken: timeTaken);
  }

  void useAbility(AbilityType type) {
    final abilityString = AbilityModel.fromType(type).toTypeString();
    if (state.usedAbilities.contains(abilityString)) return;

    final newUsed = [...state.usedAbilities, abilityString];
    state = state.copyWith(usedAbilities: newUsed);
    _socket.useAbility(abilityType: abilityString);
  }

  void resetGame() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _roundStartTime = null;
    state = const GameState();
  }

  void clearAbilityEffect() {
    state = state.copyWith(clearAbilityEffect: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ---- Socket event handlers ----

  void _onQueueJoined(dynamic data) {
    if (data is! Map) return;
    final position = data['position'] as int? ?? 0;
    state = state.copyWith(queuePosition: position);
  }

  void _onMatchFound(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);
    final opponentData = dataMap['opponent'];
    OpponentInfo? opponent;
    if (opponentData is Map) {
      opponent = OpponentInfo.fromMap(Map<String, dynamic>.from(opponentData));
    }
    state = state.copyWith(
      status: GameStatus.matchFound,
      roomId: dataMap['roomId'] as String?,
      opponent: opponent,
    );
  }

  void _onGameStart(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);
    _roundStartTime = DateTime.now();

    final questionData = dataMap['question'];
    QuestionModel? question;
    if (questionData is Map) {
      question = QuestionModel.fromMap(Map<String, dynamic>.from(questionData));
    }

    final abilitiesData = dataMap['abilities'] as List? ?? [];
    final abilities = abilitiesData.map((a) {
      final abilityType = AbilityModel.fromString(a.toString());
      return AbilityModel.fromType(abilityType);
    }).toList();

    state = state.copyWith(
      status: GameStatus.playing,
      currentQuestion: question,
      currentRound: dataMap['round'] as int? ?? 1,
      isBonus: dataMap['isBonus'] as bool? ?? false,
      timeLimit: dataMap['timeLimit'] as int? ?? AppConstants.normalRoundTime,
      availableAbilities: abilities,
      usedAbilities: [],
      eliminatedAnswers: [],
      clearPlayerAnswer: true,
      clearCorrectIndex: true,
      clearOpponentAnswer: true,
      clearPointsThisRound: true,
    );
  }

  void _onNewQuestion(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);
    _roundStartTime = DateTime.now();

    final questionData = dataMap['question'];
    QuestionModel? question;
    if (questionData is Map) {
      question = QuestionModel.fromMap(Map<String, dynamic>.from(questionData));
    }

    state = state.copyWith(
      status: GameStatus.playing,
      currentQuestion: question,
      currentRound: dataMap['round'] as int? ?? state.currentRound,
      isBonus: dataMap['isBonus'] as bool? ?? false,
      timeLimit: dataMap['timeLimit'] as int? ?? AppConstants.normalRoundTime,
      eliminatedAnswers: [],
      clearPlayerAnswer: true,
      clearCorrectIndex: true,
      clearOpponentAnswer: true,
      clearPointsThisRound: true,
    );
  }

  void _onRoundResult(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);

    state = state.copyWith(
      status: GameStatus.roundResult,
      correctIndex: dataMap['correctIndex'] as int?,
      playerAnswer: dataMap['playerAnswer'] as int?,
      opponentAnswer: dataMap['opponentAnswer'] as int?,
      playerScore: dataMap['playerTotal'] as int? ?? state.playerScore,
      opponentScore: dataMap['opponentTotal'] as int? ?? state.opponentScore,
      pointsThisRound: dataMap['playerPoints'] as int? ?? 0,
    );

    // Auto-advance after 2 seconds (server will send new_question anyway)
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
      if (state.status == GameStatus.roundResult) {
        // If server doesn't send new_question soon, stay in roundResult
        // The server drives next round timing
      }
    });
  }

  void _onAbilityEffect(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);
    final type = dataMap['type'] as String? ?? '';
    final targetPlayerId = dataMap['targetPlayerId'] as String? ?? '';

    state = state.copyWith(abilityEffectType: type);

    // Handle 50/50 on the current player: eliminate two wrong answers
    if (type == 'fiftyFifty' && targetPlayerId == _currentUserId) {
      final question = state.currentQuestion;
      if (question != null) {
        // We don't know correct answer yet, so eliminate answers with indices != player answer
        // Visually mark two non-chosen answers as eliminated
        final correctHint = dataMap['correctIndex'] as int?;
        if (correctHint != null) {
          final toEliminate = <int>[];
          for (int i = 0; i < question.answers.length && toEliminate.length < 2; i++) {
            if (i != correctHint && i != state.playerAnswer) {
              toEliminate.add(i);
            }
          }
          state = state.copyWith(eliminatedAnswers: toEliminate);
        }
      }
    }

    // Clear effect after 1.5s
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) clearAbilityEffect();
    });
  }

  void _onGameEnd(dynamic data) {
    if (data is! Map) return;
    final dataMap = Map<String, dynamic>.from(data);

    final result = GameResult(
      winnerId: dataMap['winnerId'] as String? ?? '',
      playerFinalScore:
          dataMap['playerFinalScore'] as int? ?? state.playerScore,
      opponentFinalScore:
          dataMap['opponentFinalScore'] as int? ?? state.opponentScore,
      xpGained: dataMap['xpGained'] as int? ?? 0,
      coinsGained: dataMap['coinsGained'] as int? ?? 0,
    );

    state = state.copyWith(
      status: GameStatus.finished,
      result: result,
    );

    // Update Firestore stats
    if (_currentUserId != null) {
      final isWin = result.winnerId == _currentUserId;
      final isDraw = result.winnerId == 'draw';
      _firestore.addXpAndCoins(
          _currentUserId!, result.xpGained, result.coinsGained);
      _firestore.incrementGameStats(
        _currentUserId!,
        isWin: isWin,
        isDraw: isDraw,
      );
    }
  }

  void _onOpponentDisconnected(dynamic data) {
    state = state.copyWith(
      errorMessage: 'opponent_disconnected',
    );
  }

  void _onSocketError(dynamic data) {
    String message = 'Unknown error';
    if (data is Map) {
      message = data['message'] as String? ?? message;
    }
    state = state.copyWith(errorMessage: message);
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _socket.clearCallbacks();
    super.dispose();
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier(
    socket: SocketService(),
    firestore: FirestoreService(),
  );
});
