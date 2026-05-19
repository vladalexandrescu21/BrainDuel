'use strict';

const express = require('express');
const router = express.Router();

const adminAuth = require('../middleware/adminAuth');
const {
  getAllQuestions,
  getQuestionById,
  addQuestion,
  updateQuestion,
  deleteQuestion,
  getStats: getQuestionStats,
} = require('../questions/service');
const { activeRooms } = require('../game/room');
const { getQueue } = require('../matchmaking/queue');

// Apply admin auth to every route in this router
router.use(adminAuth);

// ── Topic metadata ────────────────────────────────────────────────────────────

const VALID_TOPICS = [
  'general_knowledge',
  'history',
  'geography',
  'gaming',
  'music',
  'technology',
  'tv_series',
  'football',
  'tennis',
  'basketball',
];

const TOPIC_NAMES = {
  general_knowledge: { nameRo: 'Cultură Generală', nameEn: 'General Knowledge' },
  history:           { nameRo: 'Istorie',           nameEn: 'History' },
  geography:         { nameRo: 'Geografie',         nameEn: 'Geography' },
  gaming:            { nameRo: 'Jocuri Video',      nameEn: 'Video Games' },
  music:             { nameRo: 'Muzică',            nameEn: 'Music' },
  technology:        { nameRo: 'Tehnologie',        nameEn: 'Technology' },
  tv_series:         { nameRo: 'Seriale',           nameEn: 'TV Series' },
  football:          { nameRo: 'Fotbal',            nameEn: 'Football' },
  tennis:            { nameRo: 'Tenis',             nameEn: 'Tennis' },
  basketball:        { nameRo: 'Baschet',           nameEn: 'Basketball' },
};

// ── GET /admin/api/stats ──────────────────────────────────────────────────────

router.get('/admin/api/stats', (req, res) => {
  const qStats = getQuestionStats();

  res.json({
    activeRooms: activeRooms.size,
    queueSize: getQueue().length,
    totalQuestions: qStats.total,
    questionsByTopic: qStats.byTopic,
    uptime: process.uptime(),
    serverTime: new Date().toISOString(),
  });
});

// ── GET /admin/api/questions ──────────────────────────────────────────────────

router.get('/admin/api/questions', (req, res) => {
  const { topic, language, difficulty, search } = req.query;
  const result = getAllQuestions({ topic, language, difficulty, search });
  res.json({ questions: result, total: result.length });
});

// ── GET /admin/api/questions/:id ──────────────────────────────────────────────

router.get('/admin/api/questions/:id', (req, res) => {
  const question = getQuestionById(req.params.id);
  if (!question) {
    return res.status(404).json({ error: `Question "${req.params.id}" not found` });
  }
  return res.json({ question });
});

// ── POST /admin/api/questions ─────────────────────────────────────────────────

router.post('/admin/api/questions', (req, res) => {
  const { text, answers, correctIndex, topic, difficulty, language } = req.body || {};

  // Validation
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'text is required and must be a non-empty string' });
  }
  if (!Array.isArray(answers) || answers.length !== 4 || answers.some((a) => typeof a !== 'string')) {
    return res.status(400).json({ error: 'answers must be an array of exactly 4 strings' });
  }
  if (typeof correctIndex !== 'number' || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
    return res.status(400).json({ error: 'correctIndex must be an integer between 0 and 3' });
  }
  if (!VALID_TOPICS.includes(topic)) {
    return res.status(400).json({ error: `topic must be one of: ${VALID_TOPICS.join(', ')}` });
  }
  if (!['easy', 'medium', 'hard'].includes(difficulty)) {
    return res.status(400).json({ error: 'difficulty must be easy, medium, or hard' });
  }
  if (!['ro', 'en'].includes(language)) {
    return res.status(400).json({ error: 'language must be ro or en' });
  }

  const question = addQuestion({ text: text.trim(), answers, correctIndex, topic, difficulty, language });
  return res.status(201).json({ question });
});

// ── PUT /admin/api/questions/:id ──────────────────────────────────────────────

router.put('/admin/api/questions/:id', (req, res) => {
  const { text, answers, correctIndex, topic, difficulty, language } = req.body || {};
  const updates = {};

  // Validate only the fields that were provided
  if (text !== undefined) {
    if (typeof text !== 'string' || text.trim() === '') {
      return res.status(400).json({ error: 'text must be a non-empty string' });
    }
    updates.text = text.trim();
  }

  if (answers !== undefined) {
    if (!Array.isArray(answers) || answers.length !== 4 || answers.some((a) => typeof a !== 'string')) {
      return res.status(400).json({ error: 'answers must be an array of exactly 4 strings' });
    }
    updates.answers = answers;
  }

  if (correctIndex !== undefined) {
    if (typeof correctIndex !== 'number' || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
      return res.status(400).json({ error: 'correctIndex must be an integer between 0 and 3' });
    }
    updates.correctIndex = correctIndex;
  }

  if (topic !== undefined) {
    if (!VALID_TOPICS.includes(topic)) {
      return res.status(400).json({ error: `topic must be one of: ${VALID_TOPICS.join(', ')}` });
    }
    updates.topic = topic;
  }

  if (difficulty !== undefined) {
    if (!['easy', 'medium', 'hard'].includes(difficulty)) {
      return res.status(400).json({ error: 'difficulty must be easy, medium, or hard' });
    }
    updates.difficulty = difficulty;
  }

  if (language !== undefined) {
    if (!['ro', 'en'].includes(language)) {
      return res.status(400).json({ error: 'language must be ro or en' });
    }
    updates.language = language;
  }

  const question = updateQuestion(req.params.id, updates);
  if (!question) {
    return res.status(404).json({ error: `Question "${req.params.id}" not found` });
  }
  return res.json({ question });
});

// ── DELETE /admin/api/questions/:id ──────────────────────────────────────────

router.delete('/admin/api/questions/:id', (req, res) => {
  const deleted = deleteQuestion(req.params.id);
  if (!deleted) {
    return res.status(404).json({ error: `Question "${req.params.id}" not found` });
  }
  return res.json({ success: true, deletedId: req.params.id });
});

// ── GET /admin/api/rooms ──────────────────────────────────────────────────────

router.get('/admin/api/rooms', (req, res) => {
  const rooms = [];

  for (const [roomId, room] of activeRooms) {
    rooms.push({
      roomId,
      players: room.players.map((p) => ({
        userId: p.userId,
        displayName: p.displayName,
        score: room.scores[p.socketId] || 0,
      })),
      currentRound: room.currentRound,
      totalRounds: room.totalRounds,
      status: room.currentRound === 0 ? 'waiting' : 'playing',
    });
  }

  res.json({ rooms, total: rooms.length });
});

// ── GET /admin/api/topics ─────────────────────────────────────────────────────

router.get('/admin/api/topics', (req, res) => {
  const { byTopic } = getQuestionStats();

  const topics = VALID_TOPICS.map((id) => ({
    id,
    nameRo: TOPIC_NAMES[id].nameRo,
    nameEn: TOPIC_NAMES[id].nameEn,
    questionCount: byTopic[id] || { ro: 0, en: 0, total: 0 },
  }));

  res.json({ topics });
});

module.exports = router;
