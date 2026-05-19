'use strict';

const { EVENTS } = require('./events');
const { verifyIdToken } = require('../config/firebase');
const { addToQueue, removeFromQueue, findMatch, getPosition } = require('../matchmaking/queue');
const { createRoom, getRoomBySocket } = require('../game/room');

/**
 * Register all BrainDuel Socket.io event handlers on the given server instance.
 *
 * @param {import('socket.io').Server} io
 */
function registerHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    // ── join_queue ─────────────────────────────────────────────────────────
    socket.on(EVENTS.CLIENT_TO_SERVER.JOIN_QUEUE, async (payload) => {
      try {
        const { topicId, userId, token, displayName: clientDisplayName, level, avatarId, language } = payload || {};

        if (!token) {
          socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'Authentication token is required.' });
          return;
        }

        // Verify token
        let decoded;
        try {
          decoded = await verifyIdToken(token);
        } catch (authErr) {
          console.warn(`[Socket] Auth failed for ${socket.id}:`, authErr.message);
          socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, {
            message: 'Invalid or expired authentication token.',
          });
          return;
        }

        const verifiedUserId = decoded.uid || userId || socket.id;
        const displayName =
          decoded.name || clientDisplayName || verifiedUserId;

        const player = {
          socketId: socket.id,
          userId: verifiedUserId,
          topicId: topicId || 'general_knowledge',
          displayName,
          level: level || 1,
          avatarId: avatarId || 'default',
          language: language || 'ro',
        };

        addToQueue(player);

        const position = getPosition(socket.id);
        socket.emit(EVENTS.SERVER_TO_CLIENT.QUEUE_JOINED, {
          position,
          topicId: player.topicId,
          message: `You are in position ${position} in the queue.`,
        });

        console.log(`[Socket] ${verifiedUserId} (${socket.id}) joined queue — topic: ${player.topicId}`);

        // Attempt to create a match
        _tryMatch(io);
      } catch (err) {
        console.error(`[Socket] join_queue error for ${socket.id}:`, err);
        socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'Failed to join queue. Please try again.' });
      }
    });

    // ── leave_queue ────────────────────────────────────────────────────────
    socket.on(EVENTS.CLIENT_TO_SERVER.LEAVE_QUEUE, () => {
      const removed = removeFromQueue(socket.id);
      if (removed) {
        console.log(`[Socket] ${socket.id} left the queue voluntarily.`);
        socket.emit(EVENTS.SERVER_TO_CLIENT.QUEUE_JOINED, {
          position: -1,
          message: 'You have left the matchmaking queue.',
        });
      }
    });

    // ── submit_answer ──────────────────────────────────────────────────────
    socket.on(EVENTS.CLIENT_TO_SERVER.SUBMIT_ANSWER, (payload) => {
      try {
        const { answerIndex, timeTaken } = payload || {};

        const room = getRoomBySocket(socket.id);
        if (!room) {
          socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'You are not in an active game.' });
          return;
        }

        const parsedAnswer = typeof answerIndex === 'number' ? answerIndex : null;
        const parsedTime = typeof timeTaken === 'number' ? timeTaken : 10_000;

        room.submitAnswer(socket.id, parsedAnswer, parsedTime);
      } catch (err) {
        console.error(`[Socket] submit_answer error for ${socket.id}:`, err);
        socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'Failed to submit answer.' });
      }
    });

    // ── use_ability ────────────────────────────────────────────────────────
    socket.on(EVENTS.CLIENT_TO_SERVER.USE_ABILITY, (payload) => {
      try {
        const { abilityType } = payload || {};

        if (!abilityType) {
          socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'abilityType is required.' });
          return;
        }

        const room = getRoomBySocket(socket.id);
        if (!room) {
          socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'You are not in an active game.' });
          return;
        }

        room.useAbility(socket.id, abilityType);
      } catch (err) {
        console.error(`[Socket] use_ability error for ${socket.id}:`, err);
        socket.emit(EVENTS.SERVER_TO_CLIENT.ERROR, { message: 'Failed to use ability.' });
      }
    });

    // ── disconnect ─────────────────────────────────────────────────────────
    socket.on('disconnect', (reason) => {
      console.log(`[Socket] Disconnected: ${socket.id} — reason: ${reason}`);

      // Remove from matchmaking queue if waiting
      removeFromQueue(socket.id);

      // If the player was in an active game, notify the opponent
      const room = getRoomBySocket(socket.id);
      if (room) {
        room.handleDisconnect(socket.id);
      }
    });
  });
}

// ── Internal helpers ─────────────────────────────────────────────────────────

/**
 * Attempt to create a match from the current queue.
 * Called whenever a new player joins.
 * @param {import('socket.io').Server} io
 */
function _tryMatch(io) {
  const match = findMatch();
  if (!match) return;

  const { player1, player2 } = match;
  console.log(`[Matchmaking] Pairing ${player1.userId} vs ${player2.userId}`);

  createRoom(player1, player2, io);

  // Recursively try to create more matches if the queue still has enough players
  _tryMatch(io);
}

module.exports = { registerHandlers };
