'use strict';

const { v4: uuidv4 } = require('uuid');
const { EVENTS } = require('../socket/events');
const { getQuestionsForGame } = require('../questions/service');
const { calculatePoints, calculateRewards, getWinner } = require('./scoring');
const { applyAbility } = require('./abilities');

/**
 * Active game rooms, keyed by roomId.
 * @type {Map<string, GameRoom>}
 */
const activeRooms = new Map();

/**
 * O(1) lookup: socketId → roomId.
 * @type {Map<string, string>}
 */
const socketToRoom = new Map();

// How long (ms) a player has to answer per round
const ROUND_TIME_LIMIT_MS = 10_000;
// Extra buffer after time limit before server forces processRound
const ROUND_TIMER_BUFFER_MS = 500;
// Delay (ms) between showing round result and starting the next round / ending
const NEXT_ROUND_DELAY_MS = 200;
// Delay (ms) between match_found and first round start (countdown on client)
const GAME_START_DELAY_MS = 3000;

/**
 * Strip correctIndex from a question before sending to clients.
 * @param {object} question
 * @returns {object}
 */
function sanitizeQuestion(question) {
  const { correctIndex, ...safe } = question; // eslint-disable-line no-unused-vars
  return safe;
}

class GameRoom {
  /**
   * @param {string} roomId
   * @param {{ socketId:string, userId:string, displayName:string, level:number, avatarId:string, topicId:string }} player1
   * @param {{ socketId:string, userId:string, displayName:string, level:number, avatarId:string, topicId:string }} player2
   * @param {import('socket.io').Server} io
   */
  constructor(roomId, player1, player2, io) {
    this.roomId = roomId;
    this.io = io;

    this.players = [player1, player2];

    // Scores keyed by socketId
    this.scores = {
      [player1.socketId]: 0,
      [player2.socketId]: 0,
    };

    this.currentRound = 0; // incremented before each round (1-indexed during play)
    this.totalRounds = 7;

    /** @type {object[]} */
    this.questions = [];

    /**
     * Tracks answers submitted this round.
     * { [socketId]: { answerIndex: number|null, timeTaken: number, submitted: boolean } }
     */
    this.roundAnswers = {};

    /** @type {NodeJS.Timeout|null} */
    this.roundTimer = null;

    /**
     * Abilities queued to be applied at round start.
     * { [socketId]: string[] }
     */
    this.pendingAbilities = {};

    /**
     * Per-round active effects.
     * { [socketId]: { shielded: bool, timeBonusMs: number, timePenaltyMs: number, doubleDown: bool } }
     */
    this.activeEffects = {
      [player1.socketId]: { shielded: false, timeBonusMs: 0, timePenaltyMs: 0, doubleDown: false },
      [player2.socketId]: { shielded: false, timeBonusMs: 0, timePenaltyMs: 0, doubleDown: false },
    };

    /**
     * Tracks which abilities each player has already used this game.
     * { [socketId]: string[] }
     */
    this.usedAbilities = {
      [player1.socketId]: [],
      [player2.socketId]: [],
    };

    /**
     * Default ability sets per player.
     * In a real app the player's chosen abilities come from the client profile.
     */
    this.playerAbilitySet = {
      [player1.socketId]: ['fifty_fifty', 'time_boost', 'shield'],
      [player2.socketId]: ['sabotage', 'double_down', 'reveal'],
    };

    // Register in the global lookup maps
    activeRooms.set(roomId, this);
    socketToRoom.set(player1.socketId, roomId);
    socketToRoom.set(player2.socketId, roomId);

    console.log(`[Room ${roomId}] Created — ${player1.userId} vs ${player2.userId}`);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /**
   * Load questions and kick off the game.
   */
  async start() {
    const [p1, p2] = this.players;

    // Determine the topic to use. If both players want the same topic, use it;
    // otherwise pick player1's topic (cross-topic fallback handled in service).
    const topicId = p1.topicId === p2.topicId ? p1.topicId : p1.topicId;
    const language = 'ro'; // TODO: derive from player preference

    this.questions = getQuestionsForGame(topicId, language, this.totalRounds);

    if (this.questions.length < this.totalRounds) {
      console.warn(
        `[Room ${this.roomId}] Only ${this.questions.length} questions available for topic "${topicId}" — adjusting totalRounds.`
      );
      this.totalRounds = this.questions.length;
    }

    // Emit match_found to each player individually — each sees themselves as
    // "player" and the other as "opponent".
    this.players.forEach((self) => {
      const opponent = this.getOpponent(self.socketId);
      this.io.to(self.socketId).emit(EVENTS.SERVER_TO_CLIENT.MATCH_FOUND, {
        roomId: this.roomId,
        player: {
          socketId: self.socketId,
          userId: self.userId,
          displayName: self.displayName,
          level: self.level,
          avatarId: self.avatarId,
        },
        opponent: {
          socketId: opponent.socketId,
          userId: opponent.userId,
          displayName: opponent.displayName,
          level: opponent.level,
          avatarId: opponent.avatarId,
        },
        totalRounds: this.totalRounds,
        abilitySet: this.playerAbilitySet[self.socketId],
      });
    });

    console.log(`[Room ${this.roomId}] match_found emitted — starting in ${GAME_START_DELAY_MS}ms`);

    // Brief countdown before round 1
    setTimeout(() => {
      this.emitToBoth(EVENTS.SERVER_TO_CLIENT.GAME_START, {
        roomId: this.roomId,
        totalRounds: this.totalRounds,
      });
      this.startRound();
    }, GAME_START_DELAY_MS);
  }

  /**
   * Begin a new round: increment counter, reset state, send question, set timer.
   */
  startRound() {
    this.currentRound += 1;

    if (this.currentRound > this.totalRounds) {
      this.endGame();
      return;
    }

    const question = this.questions[this.currentRound - 1];

    // Reset per-round answer tracking
    this.roundAnswers = {};
    this.players.forEach((p) => {
      this.roundAnswers[p.socketId] = { answerIndex: null, timeTaken: ROUND_TIME_LIMIT_MS, submitted: false };
    });

    // Reset per-round effects (shield persists across rounds until triggered,
    // but timeBonusMs / timePenaltyMs / doubleDown are per-round only)
    this.players.forEach((p) => {
      const effects = this.activeEffects[p.socketId];
      effects.timeBonusMs = 0;
      effects.timePenaltyMs = 0;
      effects.doubleDown = false;
      // shielded persists until consumed
    });

    console.log(
      `[Room ${this.roomId}] Round ${this.currentRound}/${this.totalRounds} — question: ${question.id}`
    );

    const isLastRound = this.currentRound === this.totalRounds;

    // Send the question WITHOUT correctIndex
    this.emitToBoth(EVENTS.SERVER_TO_CLIENT.NEW_QUESTION, {
      round: this.currentRound,
      totalRounds: this.totalRounds,
      question: sanitizeQuestion(question),
      timeLimitMs: ROUND_TIME_LIMIT_MS,
      isLastRound,
    });

    // Set the round timeout
    if (this.roundTimer) clearTimeout(this.roundTimer);
    this.roundTimer = setTimeout(() => {
      console.log(`[Room ${this.roomId}] Round ${this.currentRound} timed out`);
      this._forceProcessRound();
    }, ROUND_TIME_LIMIT_MS + ROUND_TIMER_BUFFER_MS);
  }

  /**
   * Called by the timeout to fill in null answers for any player who hasn't
   * submitted yet, then process the round.
   */
  _forceProcessRound() {
    this.players.forEach((p) => {
      if (!this.roundAnswers[p.socketId] || !this.roundAnswers[p.socketId].submitted) {
        this.roundAnswers[p.socketId] = {
          answerIndex: null,
          timeTaken: ROUND_TIME_LIMIT_MS,
          submitted: true,
        };
      }
    });
    this.processRound();
  }

  /**
   * Handle an incoming answer from a player.
   * @param {string} socketId
   * @param {number|null} answerIndex
   * @param {number} timeTaken - ms
   */
  submitAnswer(socketId, answerIndex, timeTaken) {
    if (!this.roundAnswers[socketId]) return;
    if (this.roundAnswers[socketId].submitted) return; // already answered

    const clampedTime = Math.min(Math.max(0, timeTaken), ROUND_TIME_LIMIT_MS);
    this.roundAnswers[socketId] = { answerIndex, timeTaken: clampedTime, submitted: true };

    console.log(
      `[Room ${this.roomId}] Answer from ${socketId}: index=${answerIndex}, time=${clampedTime}ms`
    );

    // Check if both players have now answered
    const allAnswered = this.players.every((p) => this.roundAnswers[p.socketId]?.submitted);
    if (allAnswered) {
      if (this.roundTimer) {
        clearTimeout(this.roundTimer);
        this.roundTimer = null;
      }
      this.processRound();
    }
  }

  /**
   * Calculate round scores, emit results, and advance the game.
   */
  processRound() {
    const question = this.questions[this.currentRound - 1];
    const isLastRound = this.currentRound === this.totalRounds;

    const roundScores = {};

    this.players.forEach((p) => {
      const { answerIndex, timeTaken } = this.roundAnswers[p.socketId] || {
        answerIndex: null,
        timeTaken: ROUND_TIME_LIMIT_MS,
      };
      const effects = this.activeEffects[p.socketId] || {};

      let pts = calculatePoints(answerIndex, question.correctIndex, timeTaken, effects);

      // Bonus round (last round): caller (this method) doubles the points
      if (isLastRound && pts > 0) {
        pts *= 2;
      }

      roundScores[p.socketId] = pts;
      this.scores[p.socketId] = (this.scores[p.socketId] || 0) + pts;
    });

    // Emit round_result to each player individually
    this.players.forEach((p) => {
      const opponent = this.getOpponent(p.socketId);
      const { answerIndex } = this.roundAnswers[p.socketId] || { answerIndex: null };
      const opponentAnswer = this.roundAnswers[opponent.socketId] || { answerIndex: null };

      this.io.to(p.socketId).emit(EVENTS.SERVER_TO_CLIENT.ROUND_RESULT, {
        round: this.currentRound,
        correctIndex: question.correctIndex,
        player: {
          socketId: p.socketId,
          answerIndex,
          pointsEarned: roundScores[p.socketId],
          totalScore: this.scores[p.socketId],
        },
        opponent: {
          socketId: opponent.socketId,
          answerIndex: opponentAnswer.answerIndex,
          pointsEarned: roundScores[opponent.socketId],
          totalScore: this.scores[opponent.socketId],
        },
        isLastRound,
      });
    });

    console.log(
      `[Room ${this.roomId}] Round ${this.currentRound} result — ` +
        this.players.map((p) => `${p.userId}: ${this.scores[p.socketId]}`).join(' | ')
    );

    // Clear per-round state
    this.roundAnswers = {};

    // Advance after a short delay so clients can render the result screen
    setTimeout(() => {
      if (isLastRound || this.currentRound >= this.totalRounds) {
        this.endGame();
      } else {
        this.startRound();
      }
    }, NEXT_ROUND_DELAY_MS);
  }

  /**
   * Apply a player ability.
   * @param {string} socketId
   * @param {string} abilityType
   */
  useAbility(socketId, abilityType) {
    const usedList = this.usedAbilities[socketId] || [];

    // Check if already used this game
    if (usedList.includes(abilityType)) {
      this.io.to(socketId).emit(EVENTS.SERVER_TO_CLIENT.ERROR, {
        message: `Ability "${abilityType}" has already been used this game.`,
      });
      return;
    }

    // Check if in the player's ability set
    const abilitySet = this.playerAbilitySet[socketId] || [];
    if (!abilitySet.includes(abilityType)) {
      this.io.to(socketId).emit(EVENTS.SERVER_TO_CLIENT.ERROR, {
        message: `Ability "${abilityType}" is not in your ability set.`,
      });
      return;
    }

    const result = applyAbility(abilityType, socketId, this);

    if (!result.success) {
      this.io.to(socketId).emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: result.message });
      return;
    }

    // Mark as used
    this.usedAbilities[socketId].push(abilityType);

    console.log(`[Room ${this.roomId}] Ability "${abilityType}" used by ${socketId}: ${result.message}`);

    const opponent = this.getOpponent(socketId);

    // Notify the user
    this.io.to(socketId).emit(EVENTS.SERVER_TO_CLIENT.ABILITY_EFFECT, {
      abilityType,
      usedBy: socketId,
      target: 'self',
      effect: result.effect,
      message: result.message,
    });

    // Notify opponent (without sensitive details like removedIndices for fifty_fifty
    // since the opponent didn't use it — but we do tell them an ability was played)
    if (opponent) {
      // For sabotage, send full effect so client can show penalty warning
      const opponentPayload =
        abilityType === 'sabotage'
          ? { effect: result.effect, message: 'Opponent used Sabotage on you!' }
          : { effect: {}, message: `Opponent used ${abilityType}!` };

      this.io.to(opponent.socketId).emit(EVENTS.SERVER_TO_CLIENT.ABILITY_EFFECT, {
        abilityType,
        usedBy: socketId,
        target: 'opponent',
        ...opponentPayload,
      });
    }
  }

  /**
   * Finish the game, emit final scores and rewards, clean up.
   */
  endGame() {
    if (this.roundTimer) {
      clearTimeout(this.roundTimer);
      this.roundTimer = null;
    }

    const [p1, p2] = this.players;
    const rewards = calculateRewards(p1.socketId, p2.socketId, this.scores);
    const winnerSocketId = getWinner(this.scores);
    const isDraw = winnerSocketId === null;

    this.players.forEach((p) => {
      const opponent = this.getOpponent(p.socketId);
      this.io.to(p.socketId).emit(EVENTS.SERVER_TO_CLIENT.GAME_END, {
        roomId: this.roomId,
        winner: isDraw ? null : winnerSocketId,
        isDraw,
        isWinner: !isDraw && winnerSocketId === p.socketId,
        scores: {
          [p.socketId]: this.scores[p.socketId],
          [opponent.socketId]: this.scores[opponent.socketId],
        },
        rewards: rewards[p.socketId],
        opponentRewards: rewards[opponent.socketId],
      });
    });

    console.log(
      `[Room ${this.roomId}] Game over — ${isDraw ? 'DRAW' : `Winner: ${winnerSocketId}`} | ` +
        this.players.map((p) => `${p.userId}: ${this.scores[p.socketId]}`).join(' | ')
    );

    this._cleanup();
  }

  /**
   * Handle one player disconnecting mid-game.
   * The remaining player wins by default.
   * @param {string} disconnectedSocketId
   */
  handleDisconnect(disconnectedSocketId) {
    if (this.roundTimer) {
      clearTimeout(this.roundTimer);
      this.roundTimer = null;
    }

    const opponent = this.getOpponent(disconnectedSocketId);
    if (opponent) {
      this.io.to(opponent.socketId).emit(EVENTS.SERVER_TO_CLIENT.OPPONENT_DISCONNECTED, {
        roomId: this.roomId,
        message: 'Your opponent disconnected. You win!',
        finalScores: { ...this.scores },
        rewards: { xp: 75, coins: 35 }, // partial win bonus
      });
    }

    console.log(
      `[Room ${this.roomId}] Player ${disconnectedSocketId} disconnected — opponent wins by default.`
    );

    this._cleanup();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /**
   * Return the other player object.
   * @param {string} socketId
   * @returns {{ socketId:string, userId:string, displayName:string, level:number, avatarId:string }}
   */
  getOpponent(socketId) {
    return this.players.find((p) => p.socketId !== socketId);
  }

  /**
   * Emit an event with payload to both players.
   * @param {string} event
   * @param {object} data
   */
  emitToBoth(event, data) {
    this.players.forEach((p) => {
      this.io.to(p.socketId).emit(event, data);
    });
  }

  /**
   * Remove room and socket references from the global maps.
   */
  _cleanup() {
    this.players.forEach((p) => {
      socketToRoom.delete(p.socketId);
    });
    activeRooms.delete(this.roomId);
    console.log(`[Room ${this.roomId}] Cleaned up. Active rooms: ${activeRooms.size}`);
  }
}

/**
 * Convenience factory — create a room, register it, and call start().
 *
 * @param {object} player1
 * @param {object} player2
 * @param {import('socket.io').Server} io
 * @returns {GameRoom}
 */
function createRoom(player1, player2, io) {
  const roomId = uuidv4();
  const room = new GameRoom(roomId, player1, player2, io);
  room.start().catch((err) => {
    console.error(`[Room ${roomId}] Error during start():`, err);
  });
  return room;
}

/**
 * Look up the room for a given socket, or null.
 * @param {string} socketId
 * @returns {GameRoom|null}
 */
function getRoomBySocket(socketId) {
  const roomId = socketToRoom.get(socketId);
  if (!roomId) return null;
  return activeRooms.get(roomId) || null;
}

module.exports = { GameRoom, activeRooms, socketToRoom, createRoom, getRoomBySocket };
