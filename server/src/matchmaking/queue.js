'use strict';

/**
 * In-memory matchmaking queue.
 *
 * A single flat array stores all waiting players sorted by the time they
 * joined.  `findMatch` first tries to pair two players who want the same
 * topic, then falls back to pairing the two oldest entries regardless of
 * topic when no same-topic pair exists.
 */

/** @type {Array<{socketId:string, userId:string, topicId:string, displayName:string, level:number, avatarId:string, joinedAt:number}>} */
const queue = [];

/**
 * Add a player to the matchmaking queue.
 * If the player is already in the queue (same socketId) this is a no-op.
 *
 * @param {{ socketId: string, userId: string, topicId: string, displayName: string, level: number, avatarId: string }} player
 */
function addToQueue(player) {
  // Prevent duplicate entries
  if (queue.some((p) => p.socketId === player.socketId)) {
    return;
  }

  queue.push({
    ...player,
    joinedAt: Date.now(),
  });

  console.log(
    `[Queue] Player ${player.userId} (${player.socketId}) joined — topic: ${player.topicId} — queue size: ${queue.length}`
  );
}

/**
 * Remove a player from the queue by socketId.
 *
 * @param {string} socketId
 * @returns {boolean} true if the player was found and removed
 */
function removeFromQueue(socketId) {
  const idx = queue.findIndex((p) => p.socketId === socketId);
  if (idx === -1) return false;

  const [removed] = queue.splice(idx, 1);
  console.log(
    `[Queue] Player ${removed.userId} (${socketId}) removed — queue size: ${queue.length}`
  );
  return true;
}

/**
 * Attempt to find a match from the current queue.
 *
 * Strategy:
 *  1. Look for the first pair of players that share the same topicId.
 *  2. If no same-topic pair exists and the queue has >= 2 players, match
 *     the two oldest entries (index 0 and 1).
 *
 * The two matched players are removed from the queue.
 *
 * @returns {{ player1: object, player2: object } | null}
 */
function findMatch() {
  if (queue.length < 2) return null;

  // --- Pass 1: same-topic match ---
  for (let i = 0; i < queue.length; i++) {
    for (let j = i + 1; j < queue.length; j++) {
      if (queue[i].topicId === queue[j].topicId) {
        const player1 = queue[i];
        const player2 = queue[j];
        // Remove higher index first to preserve lower index validity
        queue.splice(j, 1);
        queue.splice(i, 1);
        console.log(
          `[Queue] Same-topic match: ${player1.userId} vs ${player2.userId} (topic: ${player1.topicId})`
        );
        return { player1, player2 };
      }
    }
  }

  // --- Pass 2: fallback — match first two players regardless of topic ---
  const player1 = queue.shift();
  const player2 = queue.shift();
  console.log(
    `[Queue] Cross-topic match: ${player1.userId} (${player1.topicId}) vs ${player2.userId} (${player2.topicId})`
  );
  return { player1, player2 };
}

/**
 * Return the 1-based position of a player in the queue.
 * Returns -1 if the player is not in the queue.
 *
 * @param {string} socketId
 * @returns {number}
 */
function getPosition(socketId) {
  const idx = queue.findIndex((p) => p.socketId === socketId);
  return idx === -1 ? -1 : idx + 1;
}

/**
 * Return a snapshot of the current queue (read-only copy).
 * Useful for debugging / admin endpoints.
 */
function getQueue() {
  return [...queue];
}

module.exports = { addToQueue, removeFromQueue, findMatch, getPosition, getQueue };
