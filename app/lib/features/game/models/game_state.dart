import 'package:brainduel/features/game/models/question_model.dart';
import 'package:brainduel/features/game/models/ability_model.dart';

enum GameStatus {
  idle,
  searching,
  matchFound,
  playing,
  roundResult,
  finished,
}

class OpponentInfo {
  final String uid;
  final String displayName;
  final int level;
  final String avatarId;

  const OpponentInfo({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.avatarId,
  });

  factory OpponentInfo.fromMap(Map<String, dynamic> map) {
    return OpponentInfo(
      uid: map['userId'] as String? ?? map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Opponent',
      level: map['level'] as int? ?? 1,
      avatarId: map['avatarId'] as String? ?? 'default',
    );
  }
}

class GameResult {
  final String winnerId; // 'draw' if draw
  final int playerFinalScore;
  final int opponentFinalScore;
  final int xpGained;
  final int coinsGained;

  const GameResult({
    required this.winnerId,
    required this.playerFinalScore,
    required this.opponentFinalScore,
    required this.xpGained,
    required this.coinsGained,
  });

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      winnerId: map['winnerId'] as String? ?? '',
      playerFinalScore: map['playerFinalScore'] as int? ?? 0,
      opponentFinalScore: map['opponentFinalScore'] as int? ?? 0,
      xpGained: map['xpGained'] as int? ?? 0,
      coinsGained: map['coinsGained'] as int? ?? 0,
    );
  }
}

class GameState {
  final GameStatus status;
  final String? roomId;
  final OpponentInfo? opponent;
  final QuestionModel? currentQuestion;
  final int currentRound; // 1-7
  final bool isBonus;
  final int timeLimit; // seconds
  final int playerScore;
  final int opponentScore;
  final int? playerAnswer; // index chosen by player, null if not answered
  final int? correctIndex; // revealed after round
  final int? opponentAnswer; // revealed after round
  final int? pointsThisRound;
  final List<AbilityModel> availableAbilities;
  final List<String> usedAbilities;
  final GameResult? result; // set when game ends
  final int queuePosition;
  final List<int> eliminatedAnswers; // for 50/50 ability
  final String? abilityEffectType; // current ability effect being shown
  final String? errorMessage;

  const GameState({
    this.status = GameStatus.idle,
    this.roomId,
    this.opponent,
    this.currentQuestion,
    this.currentRound = 0,
    this.isBonus = false,
    this.timeLimit = 10,
    this.playerScore = 0,
    this.opponentScore = 0,
    this.playerAnswer,
    this.correctIndex,
    this.opponentAnswer,
    this.pointsThisRound,
    this.availableAbilities = const [],
    this.usedAbilities = const [],
    this.result,
    this.queuePosition = 0,
    this.eliminatedAnswers = const [],
    this.abilityEffectType,
    this.errorMessage,
  });

  bool get hasAnswered => playerAnswer != null;

  GameState copyWith({
    GameStatus? status,
    String? roomId,
    OpponentInfo? opponent,
    QuestionModel? currentQuestion,
    int? currentRound,
    bool? isBonus,
    int? timeLimit,
    int? playerScore,
    int? opponentScore,
    int? playerAnswer,
    int? correctIndex,
    int? opponentAnswer,
    int? pointsThisRound,
    List<AbilityModel>? availableAbilities,
    List<String>? usedAbilities,
    GameResult? result,
    int? queuePosition,
    List<int>? eliminatedAnswers,
    String? abilityEffectType,
    String? errorMessage,
    bool clearPlayerAnswer = false,
    bool clearCorrectIndex = false,
    bool clearOpponentAnswer = false,
    bool clearPointsThisRound = false,
    bool clearAbilityEffect = false,
    bool clearError = false,
  }) {
    return GameState(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      opponent: opponent ?? this.opponent,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      currentRound: currentRound ?? this.currentRound,
      isBonus: isBonus ?? this.isBonus,
      timeLimit: timeLimit ?? this.timeLimit,
      playerScore: playerScore ?? this.playerScore,
      opponentScore: opponentScore ?? this.opponentScore,
      playerAnswer: clearPlayerAnswer ? null : (playerAnswer ?? this.playerAnswer),
      correctIndex: clearCorrectIndex ? null : (correctIndex ?? this.correctIndex),
      opponentAnswer:
          clearOpponentAnswer ? null : (opponentAnswer ?? this.opponentAnswer),
      pointsThisRound:
          clearPointsThisRound ? null : (pointsThisRound ?? this.pointsThisRound),
      availableAbilities: availableAbilities ?? this.availableAbilities,
      usedAbilities: usedAbilities ?? this.usedAbilities,
      result: result ?? this.result,
      queuePosition: queuePosition ?? this.queuePosition,
      eliminatedAnswers: eliminatedAnswers ?? this.eliminatedAnswers,
      abilityEffectType:
          clearAbilityEffect ? null : (abilityEffectType ?? this.abilityEffectType),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
