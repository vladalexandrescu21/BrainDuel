'use strict';

/**
 * Ability system for BrainDuel.
 *
 * Available abilities
 * ───────────────────
 * fifty_fifty  — Removes 2 incorrect answer options from the current question.
 * time_boost   — Grants the user 4 000 ms of "bonus time" (subtracted from their
 *                timeTaken during scoring, floored at 0).
 * sabotage     — Adds 3 000 ms penalty to the opponent's timeTaken this round.
 *                Blocked by the opponent's shield if active (shield is consumed).
 * double_down  — Doubles the user's point total for this round.
 * shield       — Blocks the next sabotage directed at this player.
 * reveal       — Returns a hint token; the client uses this to show a subtle visual
 *                cue (e.g. highlight the correct quadrant).  The server marks the
 *                ability used but does not expose correctIndex directly.
 *
 * Each ability can only be used ONCE per player per game.
 * That constraint is enforced in GameRoom.useAbility(); this module only handles
 * the per-ability effect logic.
 */

const ABILITY_TYPES = [
  'fifty_fifty',
  'time_boost',
  'sabotage',
  'double_down',
  'shield',
  'reveal',
];

/**
 * Apply an ability for the using player inside a GameRoom.
 *
 * @param {string}   abilityType          - One of ABILITY_TYPES
 * @param {string}   usingPlayerSocketId  - Socket ID of the player using the ability
 * @param {object}   room                 - The GameRoom instance
 * @returns {{ success: boolean, effect: object, message: string }}
 */
function applyAbility(abilityType, usingPlayerSocketId, room) {
  const opponent = room.getOpponent(usingPlayerSocketId);

  // Ensure activeEffects slots exist
  if (!room.activeEffects[usingPlayerSocketId]) {
    room.activeEffects[usingPlayerSocketId] = {
      shielded: false,
      timeBonusMs: 0,
      timePenaltyMs: 0,
      doubleDown: false,
    };
  }
  if (opponent && !room.activeEffects[opponent.socketId]) {
    room.activeEffects[opponent.socketId] = {
      shielded: false,
      timeBonusMs: 0,
      timePenaltyMs: 0,
      doubleDown: false,
    };
  }

  const userEffects = room.activeEffects[usingPlayerSocketId];
  const opponentEffects = opponent ? room.activeEffects[opponent.socketId] : null;

  switch (abilityType) {
    // ── fifty_fifty ────────────────────────────────────────────────────────
    case 'fifty_fifty': {
      const currentQuestion = room.questions[room.currentRound - 1];
      if (!currentQuestion) {
        return { success: false, effect: {}, message: 'No active question.' };
      }

      const wrongIndices = [];
      for (let i = 0; i < currentQuestion.answers.length; i++) {
        if (i !== currentQuestion.correctIndex) {
          wrongIndices.push(i);
        }
      }

      // Shuffle wrong indices and pick 2 to remove
      for (let i = wrongIndices.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [wrongIndices[i], wrongIndices[j]] = [wrongIndices[j], wrongIndices[i]];
      }
      const removedIndices = wrongIndices.slice(0, 2);

      return {
        success: true,
        effect: { removedIndices },
        message: `50/50 applied — indices [${removedIndices.join(', ')}] removed.`,
      };
    }

    // ── time_boost ─────────────────────────────────────────────────────────
    case 'time_boost': {
      userEffects.timeBonusMs = (userEffects.timeBonusMs || 0) + 4000;
      return {
        success: true,
        effect: { timeBonusMs: userEffects.timeBonusMs },
        message: 'Time boost active: +4 s bonus time this round.',
      };
    }

    // ── sabotage ───────────────────────────────────────────────────────────
    case 'sabotage': {
      if (!opponent) {
        return { success: false, effect: {}, message: 'No opponent found.' };
      }

      // Check if opponent has an active shield
      if (opponentEffects.shielded) {
        // Consume the shield
        opponentEffects.shielded = false;
        return {
          success: true,
          effect: { blocked: true, opponentSocketId: opponent.socketId },
          message: 'Sabotage was blocked by opponent\'s shield! Shield consumed.',
        };
      }

      // Apply time penalty to opponent
      opponentEffects.timePenaltyMs = (opponentEffects.timePenaltyMs || 0) + 3000;
      return {
        success: true,
        effect: {
          blocked: false,
          opponentSocketId: opponent.socketId,
          timePenaltyMs: opponentEffects.timePenaltyMs,
        },
        message: 'Sabotage applied: opponent gets +3 s time penalty this round.',
      };
    }

    // ── double_down ────────────────────────────────────────────────────────
    case 'double_down': {
      userEffects.doubleDown = true;
      return {
        success: true,
        effect: { doubleDown: true },
        message: 'Double Down active: your points will be doubled this round.',
      };
    }

    // ── shield ─────────────────────────────────────────────────────────────
    case 'shield': {
      userEffects.shielded = true;
      return {
        success: true,
        effect: { shielded: true },
        message: 'Shield active: next sabotage against you will be blocked.',
      };
    }

    // ── reveal ─────────────────────────────────────────────────────────────
    case 'reveal': {
      // The server does NOT send correctIndex to the client.
      // Instead it emits a 'reveal_active' hint token; the client displays
      // a visual indicator (e.g. a glow on the correct answer button).
      // The client must already hold the question object; correctIndex is
      // intentionally withheld, so the hint is purely aesthetic here.
      // A production implementation could send a partial hint like the
      // first letter of the correct answer.
      return {
        success: true,
        effect: { hint: 'reveal_active' },
        message: 'Reveal activated: a subtle hint has been shown.',
      };
    }

    default:
      return {
        success: false,
        effect: {},
        message: `Unknown ability type: ${abilityType}`,
      };
  }
}

module.exports = { ABILITY_TYPES, applyAbility };
