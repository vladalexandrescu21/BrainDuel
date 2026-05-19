'use strict';

/**
 * Scoring logic for BrainDuel.
 *
 * Point scale per round
 * ─────────────────────
 * Wrong answer  →  0 pts
 * Correct answer → 20 pts minus 1 pt per second elapsed, floored to min 11 pts.
 *   e.g. answered in 0-999 ms  → 20 pts
 *        answered in 1000 ms   → 19 pts
 *        answered in 9000 ms   → 11 pts  (cap)
 *        answered in 10 s      → 10 pts? No — min is 11 by design.
 *
 * Effects applied before / after base calculation:
 *   timeBonusMs  — subtracted from timeTaken before calculation (timeTaken floored at 0)
 *   timePenaltyMs — added to timeTaken before calculation
 *   doubleDown   — doubles the final point value
 */

/**
 * Calculate points earned for one answer.
 *
 * @param {number|null} answerIndex  - Player's chosen answer index (null = no answer)
 * @param {number}      correctIndex - Index of the correct answer
 * @param {number}      timeTaken    - Time in milliseconds the player took to answer
 * @param {{
 *   doubleDown?: boolean,
 *   timeBonusMs?: number,
 *   timePenaltyMs?: number
 * }} effects - Active ability effects for this player this round
 * @returns {number} Points earned (non-negative integer)
 */
function calculatePoints(answerIndex, correctIndex, timeTaken, effects = {}) {
  // No answer submitted (timeout)
  if (answerIndex === null || answerIndex === undefined) {
    return 0;
  }

  // Wrong answer
  if (answerIndex !== correctIndex) {
    return 0;
  }

  // Adjust timeTaken with ability effects
  let adjustedTime = timeTaken;

  if (effects.timeBonusMs && effects.timeBonusMs > 0) {
    adjustedTime = Math.max(0, adjustedTime - effects.timeBonusMs);
  }

  if (effects.timePenaltyMs && effects.timePenaltyMs > 0) {
    adjustedTime = adjustedTime + effects.timePenaltyMs;
  }

  // Base score: 20 minus floor(seconds elapsed), minimum 11
  const secondsElapsed = Math.floor(adjustedTime / 1000);
  const basePoints = Math.max(11, 20 - secondsElapsed);

  // Apply double_down effect
  if (effects.doubleDown) {
    return basePoints * 2;
  }

  return basePoints;
}

/**
 * Calculate XP and coin rewards for all players after a game ends.
 *
 * Reward tiers:
 *   Win  → 100 XP, 50 coins
 *   Draw → 50 XP,  25 coins
 *   Loss → 25 XP,  10 coins
 *
 * @param {string} player1SocketId
 * @param {string} player2SocketId
 * @param {{ [socketId: string]: number }} scores - Final scores keyed by socketId
 * @returns {{ [socketId: string]: { xp: number, coins: number } }}
 */
function calculateRewards(player1SocketId, player2SocketId, scores) {
  const score1 = scores[player1SocketId] || 0;
  const score2 = scores[player2SocketId] || 0;

  const rewards = {};

  if (score1 === score2) {
    // Draw
    rewards[player1SocketId] = { xp: 50, coins: 25 };
    rewards[player2SocketId] = { xp: 50, coins: 25 };
  } else if (score1 > score2) {
    // Player 1 wins
    rewards[player1SocketId] = { xp: 100, coins: 50 };
    rewards[player2SocketId] = { xp: 25, coins: 10 };
  } else {
    // Player 2 wins
    rewards[player1SocketId] = { xp: 25, coins: 10 };
    rewards[player2SocketId] = { xp: 100, coins: 50 };
  }

  return rewards;
}

/**
 * Determine the winner socketId from a scores object.
 * Returns null on a draw.
 *
 * @param {{ [socketId: string]: number }} scores
 * @returns {string|null}
 */
function getWinner(scores) {
  const entries = Object.entries(scores);
  if (entries.length < 2) return entries[0]?.[0] || null;

  const [id1, s1] = entries[0];
  const [id2, s2] = entries[1];

  if (s1 === s2) return null;
  return s1 > s2 ? id1 : id2;
}

module.exports = { calculatePoints, calculateRewards, getWinner };
