'use strict';

const fs = require('fs');
const path = require('path');

const QUESTIONS_FILE = path.join(__dirname, '..', 'data', 'questions.json');

// ── In-memory question bank ───────────────────────────────────────────────────
// Load from JSON file at startup; fall back to data.js if file is missing.

let questions;
try {
  const raw = fs.readFileSync(QUESTIONS_FILE, 'utf8');
  questions = JSON.parse(raw);
  console.log(`[Questions] Loaded ${questions.length} questions from questions.json`);
} catch (err) {
  console.warn('[Questions] questions.json not found or invalid — falling back to data.js:', err.message);
  ({ questions } = require('./data'));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Fisher-Yates shuffle — mutates and returns the array.
 * @param {Array} arr
 * @returns {Array}
 */
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/**
 * Persist the in-memory questions array back to questions.json.
 */
function saveQuestions() {
  try {
    fs.writeFileSync(QUESTIONS_FILE, JSON.stringify(questions, null, 2), 'utf8');
  } catch (err) {
    console.error('[Questions] Failed to save questions.json:', err.message);
  }
}

/**
 * Generate the next ID for a given topic and language.
 * Format: ${topicPrefix}_${lang}_${3-digit-padded-number}
 * e.g. gk_ro_011
 *
 * @param {string} topic
 * @param {string} language
 * @returns {string}
 */
function generateId(topic, language) {
  // Build a short prefix from the topic (use first letters of each word, max 4 chars)
  const topicPrefixMap = {
    general_knowledge: 'gk',
    history: 'hist',
    geography: 'geo',
    gaming: 'game',
    music: 'music',
    technology: 'tech',
    tv_series: 'tv',
  };
  const prefix = topicPrefixMap[topic] || topic.replace(/[^a-z]/gi, '').slice(0, 6);
  const existing = questions.filter((q) => q.topic === topic && q.language === language);
  const nextNum = existing.length + 1;
  return `${prefix}_${language}_${String(nextNum).padStart(3, '0')}`;
}

// ── Game-facing functions (existing API — unchanged) ─────────────────────────

/**
 * Retrieve a shuffled set of questions for a game session.
 *
 * @param {string} topicId   - e.g. 'general_knowledge'
 * @param {string} language  - 'ro' | 'en'  (default: 'ro')
 * @param {number} count     - number of questions needed (default: 7)
 * @returns {object[]}
 */
function getQuestionsForGame(topicId, language = 'ro', count = 7) {
  const primary = shuffle(
    questions.filter((q) => q.topic === topicId && q.language === language)
  );

  if (primary.length >= count) {
    return primary.slice(0, count);
  }

  const otherLang = language === 'ro' ? 'en' : 'ro';
  const secondary = shuffle(
    questions.filter((q) => q.topic === topicId && q.language === otherLang)
  );

  const combined = [...primary, ...secondary];
  if (combined.length >= count) {
    return combined.slice(0, count);
  }

  const selectedIds = new Set(combined.map((q) => q.id));
  const tertiary = shuffle(
    questions.filter((q) => q.language === language && !selectedIds.has(q.id))
  );

  const final = [...combined, ...tertiary];
  return final.slice(0, Math.min(count, final.length));
}

/**
 * Return a single random question for the given topic and language.
 *
 * @param {string} topicId
 * @param {string} language
 * @returns {object | undefined}
 */
function getRandomQuestion(topicId, language) {
  const pool = questions.filter((q) => q.topic === topicId && q.language === language);
  if (pool.length > 0) {
    return pool[Math.floor(Math.random() * pool.length)];
  }

  const fallback = questions.filter((q) => q.language === language);
  if (fallback.length > 0) {
    return fallback[Math.floor(Math.random() * fallback.length)];
  }

  return undefined;
}

/**
 * Get all available topic IDs present in the question bank.
 * @returns {string[]}
 */
function getAvailableTopics() {
  return [...new Set(questions.map((q) => q.topic))];
}

// ── Admin CRUD functions ──────────────────────────────────────────────────────

/**
 * Return all questions, optionally filtered.
 *
 * @param {{ topic?: string, language?: string, difficulty?: string, search?: string }} filters
 * @returns {object[]}
 */
function getAllQuestions(filters = {}) {
  let result = questions;

  if (filters.topic) {
    result = result.filter((q) => q.topic === filters.topic);
  }
  if (filters.language) {
    result = result.filter((q) => q.language === filters.language);
  }
  if (filters.difficulty) {
    result = result.filter((q) => q.difficulty === filters.difficulty);
  }
  if (filters.search) {
    const term = filters.search.toLowerCase();
    result = result.filter((q) => q.text.toLowerCase().includes(term));
  }

  return result;
}

/**
 * Find a single question by ID.
 *
 * @param {string} id
 * @returns {object | undefined}
 */
function getQuestionById(id) {
  return questions.find((q) => q.id === id);
}

/**
 * Add a new question to the bank.
 * Generates an ID if one is not provided.
 *
 * @param {object} questionData
 * @returns {object} the newly added question
 */
function addQuestion(questionData) {
  const id = questionData.id || generateId(questionData.topic, questionData.language);
  const newQuestion = { ...questionData, id };
  questions.push(newQuestion);
  saveQuestions();
  return newQuestion;
}

/**
 * Update an existing question by ID.
 *
 * @param {string} id
 * @param {object} updates
 * @returns {object | null} updated question or null if not found
 */
function updateQuestion(id, updates) {
  const idx = questions.findIndex((q) => q.id === id);
  if (idx === -1) return null;

  // Merge updates; preserve the original ID
  questions[idx] = { ...questions[idx], ...updates, id };
  saveQuestions();
  return questions[idx];
}

/**
 * Delete a question by ID.
 *
 * @param {string} id
 * @returns {boolean} true if deleted, false if not found
 */
function deleteQuestion(id) {
  const idx = questions.findIndex((q) => q.id === id);
  if (idx === -1) return false;

  questions.splice(idx, 1);
  saveQuestions();
  return true;
}

/**
 * Return aggregate statistics about the question bank.
 *
 * @returns {{ total: number, byTopic: object, byDifficulty: object }}
 */
function getStats() {
  const byTopic = {};
  const byDifficulty = { easy: 0, medium: 0, hard: 0 };

  for (const q of questions) {
    // By topic
    if (!byTopic[q.topic]) {
      byTopic[q.topic] = { ro: 0, en: 0, total: 0 };
    }
    byTopic[q.topic][q.language] = (byTopic[q.topic][q.language] || 0) + 1;
    byTopic[q.topic].total += 1;

    // By difficulty
    if (byDifficulty[q.difficulty] !== undefined) {
      byDifficulty[q.difficulty] += 1;
    }
  }

  return { total: questions.length, byTopic, byDifficulty };
}

module.exports = {
  getQuestionsForGame,
  getRandomQuestion,
  getAvailableTopics,
  getAllQuestions,
  getQuestionById,
  addQuestion,
  updateQuestion,
  deleteQuestion,
  saveQuestions,
  getStats,
};
