'use strict';

/**
 * All socket event name constants used by BrainDuel.
 * Centralising them here prevents typos and makes refactoring easy.
 */
const EVENTS = {
  // ── Client → Server ────────────────────────────────────────────────────────
  CLIENT_TO_SERVER: {
    /** Player wants to enter the matchmaking queue */
    JOIN_QUEUE: 'join_queue',
    /** Player wants to leave the matchmaking queue before a match is found */
    LEAVE_QUEUE: 'leave_queue',
    /** Player submits their chosen answer for the current round */
    SUBMIT_ANSWER: 'submit_answer',
    /** Player activates one of their abilities */
    USE_ABILITY: 'use_ability',
  },

  // ── Server → Client ────────────────────────────────────────────────────────
  SERVER_TO_CLIENT: {
    /** Acknowledgement that the player has entered the queue */
    QUEUE_JOINED: 'queue_joined',
    /** A suitable opponent has been found; the game room is being prepared */
    MATCH_FOUND: 'match_found',
    /** All players are ready; the first question is about to be sent */
    GAME_START: 'game_start',
    /** A new question is being presented for this round */
    NEW_QUESTION: 'new_question',
    /** Results for the round just played (scores, correct answer, etc.) */
    ROUND_RESULT: 'round_result',
    /** An ability has been activated and its effect is now in play */
    ABILITY_EFFECT: 'ability_effect',
    /** The game has finished; final scores and rewards are included */
    GAME_END: 'game_end',
    /** Opponent disconnected mid-game; the remaining player wins by default */
    OPPONENT_DISCONNECTED: 'opponent_disconnected',
    /** Generic error notification */
    ERROR: 'error',
  },
};

module.exports = { EVENTS };
