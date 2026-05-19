/* ============================================================
   BrainDuel Admin Panel — app.js
   Pure vanilla JS, no external dependencies
   ============================================================ */

'use strict';

// ============================================================
// SECTION 1: STATE
// ============================================================

const state = {
  currentView: 'dashboard',
  secret: localStorage.getItem('adminSecret') || '',
  questions: [],
  filteredQuestions: [],
  currentPage: 1,
  pageSize: 20,
  filters: { topic: '', language: '', difficulty: '', search: '' },
  stats: null,
  rooms: [],
  topics: [],
  editingQuestion: null,   // null = new, object = editing
  topicsMap: {},           // id → topic object
  liveRefreshTimer: null,
  dashboardRefreshTimer: null,
};

// ============================================================
// SECTION 2: API HELPER
// ============================================================

const BASE = '';  // same origin

async function api(method, path, body) {
  try {
    const res = await fetch(BASE + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'x-admin-secret': state.secret,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (res.status === 401) {
      showLogin();
      return null;
    }

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: `HTTP ${res.status}` }));
      throw new Error(err.error || err.message || `HTTP ${res.status}`);
    }

    return await res.json();
  } catch (err) {
    if (err.name === 'TypeError' && err.message.includes('fetch')) {
      updateServerStatus(false);
    }
    throw err;
  }
}

// ============================================================
// SECTION 3: AUTH / LOGIN
// ============================================================

function showLogin() {
  el('login-screen').classList.remove('hidden');
  el('app').classList.add('hidden');
  state.secret = '';
  localStorage.removeItem('adminSecret');
  stopAllTimers();
}

function showApp() {
  el('login-screen').classList.add('hidden');
  el('app').classList.remove('hidden');
}

async function handleLogin(e) {
  e.preventDefault();
  const secret = el('login-secret').value.trim();
  if (!secret) return;

  const btn = el('login-btn');
  const spinner = el('login-spinner');
  const errEl = el('login-error');

  btn.disabled = true;
  spinner.classList.remove('hidden');
  errEl.classList.add('hidden');

  try {
    state.secret = secret;
    const data = await api('GET', '/admin/api/stats');
    if (data) {
      localStorage.setItem('adminSecret', secret);
      showApp();
      initApp();
    }
  } catch (err) {
    state.secret = '';
    errEl.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    spinner.classList.add('hidden');
  }
}

// ============================================================
// SECTION 4: ROUTER / VIEW NAVIGATION
// ============================================================

function navigateTo(view) {
  // Stop live-game and dashboard timers when leaving those views
  if (state.currentView === 'live-games') stopLiveRefresh();
  if (state.currentView === 'dashboard') stopDashboardRefresh();

  state.currentView = view;

  // Update nav items
  qAll('.nav-item').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.view === view);
  });

  // Update visible section
  qAll('.view').forEach(section => {
    section.classList.remove('active', 'entering');
  });

  const target = el(`view-${view}`);
  if (target) {
    target.classList.add('active', 'entering');
    // Remove animation class after it plays
    target.addEventListener('animationend', () => {
      target.classList.remove('entering');
    }, { once: true });
  }

  // Load the view's data
  loadView(view);

  // Close mobile sidebar
  closeMobileSidebar();
}

async function loadView(view) {
  switch (view) {
    case 'dashboard':
      await loadDashboard();
      startDashboardRefresh();
      break;
    case 'questions':
      await loadTopics();
      await loadQuestions();
      break;
    case 'live-games':
      await loadLiveGames();
      startLiveRefresh();
      break;
    case 'topics':
      await loadTopicsView();
      break;
  }
}

// ============================================================
// SECTION 5: TIMERS
// ============================================================

function startDashboardRefresh() {
  stopDashboardRefresh();
  state.dashboardRefreshTimer = setInterval(async () => {
    if (state.currentView === 'dashboard') {
      try {
        const data = await api('GET', '/admin/api/stats');
        if (data) {
          state.stats = data;
          updateStatCards(data);
          updateServerStatus(true, data.uptime);
        }
      } catch (_) { updateServerStatus(false); }
    }
  }, 5000);
}

function stopDashboardRefresh() {
  if (state.dashboardRefreshTimer) {
    clearInterval(state.dashboardRefreshTimer);
    state.dashboardRefreshTimer = null;
  }
}

function startLiveRefresh() {
  stopLiveRefresh();
  state.liveRefreshTimer = setInterval(async () => {
    if (state.currentView === 'live-games') {
      try {
        const data = await api('GET', '/admin/api/rooms');
        if (data) {
          state.rooms = data.rooms || [];
          renderRooms();
        }
      } catch (_) {}
    }
  }, 3000);
}

function stopLiveRefresh() {
  if (state.liveRefreshTimer) {
    clearInterval(state.liveRefreshTimer);
    state.liveRefreshTimer = null;
  }
}

function stopAllTimers() {
  stopDashboardRefresh();
  stopLiveRefresh();
}

// ============================================================
// SECTION 6: SERVER STATUS
// ============================================================

function updateServerStatus(live, uptime) {
  const dot = el('status-dot');
  const text = el('status-text');
  const uptimeEl = el('uptime-text');

  if (live) {
    dot.className = 'status-dot status-dot--live';
    text.textContent = 'Server: LIVE';
    if (uptime !== undefined) uptimeEl.textContent = formatUptime(uptime);
  } else {
    dot.className = 'status-dot status-dot--error';
    text.textContent = 'Server: OFFLINE';
  }
}

function formatUptime(seconds) {
  if (seconds === undefined || seconds === null) return '--';
  const s = Math.floor(seconds);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m ${s % 60}s`;
}

// ============================================================
// SECTION 7: DASHBOARD
// ============================================================

async function loadDashboard() {
  try {
    const [statsData, topicsData] = await Promise.all([
      api('GET', '/admin/api/stats'),
      api('GET', '/admin/api/topics'),
    ]);

    if (statsData) {
      state.stats = statsData;
      updateStatCards(statsData);
      updateServerStatus(true, statsData.uptime);
    }

    if (topicsData) {
      state.topics = topicsData.topics || [];
      renderTopicDistTable(statsData?.questionsByTopic);
    }

    renderRecentActivity(statsData);
  } catch (err) {
    updateServerStatus(false);
    showToast('Failed to load dashboard data', 'error');
  }
}

function updateStatCards(data) {
  animateNumber(el('stat-active-games'), data.activeRooms ?? 0);
  animateNumber(el('stat-queue'), data.queueSize ?? 0);
  animateNumber(el('stat-total-questions'), data.totalQuestions ?? 0);
  el('stat-uptime').textContent = formatUptime(data.uptime);
  el('uptime-text').textContent = formatUptime(data.uptime);
}

function animateNumber(el, target) {
  if (!el) return;
  const current = parseInt(el.textContent) || 0;
  if (current === target) return;

  const duration = 600;
  const start = performance.now();
  const diff = target - current;

  function step(now) {
    const elapsed = now - start;
    const progress = Math.min(elapsed / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    el.textContent = Math.round(current + diff * eased);
    if (progress < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

function renderTopicDistTable(byTopic) {
  const container = el('topic-table-container');
  const topics = state.topics;

  if (!topics.length) {
    container.innerHTML = '<div class="empty-state"><div class="empty-sub">No topic data available</div></div>';
    return;
  }

  let maxTotal = 1;
  topics.forEach(t => {
    const total = (t.questionCount?.total) || 0;
    if (total > maxTotal) maxTotal = total;
  });

  const rows = topics.map(t => {
    const ro = t.questionCount?.ro || 0;
    const en = t.questionCount?.en || 0;
    const total = t.questionCount?.total || (ro + en);
    const roPct = total > 0 ? Math.round((ro / total) * 100) : 50;
    const enPct = 100 - roPct;

    return `
      <tr>
        <td class="topic-name"><span class="topic-emoji">${t.emoji || '📚'}</span>${t.nameRo || t.id}</td>
        <td>${t.nameEn || ''}</td>
        <td><span class="count-badge count-badge--ro">${ro}</span></td>
        <td><span class="count-badge count-badge--en">${en}</span></td>
        <td><span class="count-badge count-badge--total">${total}</span></td>
        <td>
          <div class="mini-bar">
            <div class="mini-bar-ro" style="width:${roPct}%"></div>
            <div class="mini-bar-en" style="width:${enPct}%"></div>
          </div>
        </td>
      </tr>`;
  }).join('');

  container.innerHTML = `
    <table class="topic-dist-table">
      <thead>
        <tr>
          <th>Topic (RO)</th>
          <th>Topic (EN)</th>
          <th>RO</th>
          <th>EN</th>
          <th>Total</th>
          <th>Distribution</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function renderRecentActivity(data) {
  const list = el('activity-list');
  const serverTime = data?.serverTime ? new Date(data.serverTime) : new Date();

  const events = [
    { dot: 'green', text: 'Dashboard loaded successfully', time: 'just now' },
    { dot: 'purple', text: `Server uptime: ${formatUptime(data?.uptime)}`, time: formatTime(serverTime) },
    { dot: 'cyan', text: `${data?.activeRooms ?? 0} active game room(s)`, time: formatTime(serverTime) },
    { dot: 'amber', text: `${data?.queueSize ?? 0} player(s) in matchmaking queue`, time: formatTime(serverTime) },
    { dot: 'green', text: `${data?.totalQuestions ?? 0} questions in database`, time: formatTime(serverTime) },
  ];

  list.innerHTML = events.map(e => `
    <li class="activity-item">
      <div class="activity-dot activity-dot--${e.dot}"></div>
      <div class="activity-text">${e.text}</div>
      <div class="activity-time">${e.time}</div>
    </li>`).join('');
}

function formatTime(date) {
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// ============================================================
// SECTION 8: QUESTIONS — LOAD & FILTER
// ============================================================

async function loadTopics() {
  try {
    const data = await api('GET', '/admin/api/topics');
    if (data) {
      state.topics = data.topics || [];
      state.topicsMap = {};
      state.topics.forEach(t => { state.topicsMap[t.id] = t; });
      populateTopicDropdowns();
    }
  } catch (_) {}
}

function populateTopicDropdowns() {
  const selects = [el('filter-topic'), el('q-topic')];
  selects.forEach(sel => {
    if (!sel) return;
    const savedVal = sel.value;
    // Keep the first "All Topics" / "Select topic…" option
    while (sel.options.length > 1) sel.remove(1);
    state.topics.forEach(t => {
      const opt = document.createElement('option');
      opt.value = t.id;
      opt.textContent = `${t.emoji || '📚'} ${t.nameRo} / ${t.nameEn}`;
      sel.appendChild(opt);
    });
    if (savedVal) sel.value = savedVal;
  });
}

async function loadQuestions() {
  showQuestionsLoading(true);

  try {
    const params = new URLSearchParams();
    if (state.filters.topic)      params.set('topic', state.filters.topic);
    if (state.filters.language)   params.set('language', state.filters.language);
    if (state.filters.difficulty) params.set('difficulty', state.filters.difficulty);
    if (state.filters.search)     params.set('search', state.filters.search);

    const data = await api('GET', `/admin/api/questions?${params}`);
    if (data) {
      state.questions = data.questions || [];
      state.filteredQuestions = state.questions;
      state.currentPage = 1;
      renderQuestionsTable();
    }
  } catch (err) {
    showToast(`Failed to load questions: ${err.message}`, 'error');
  } finally {
    showQuestionsLoading(false);
  }
}

function showQuestionsLoading(loading) {
  el('questions-loading').style.display = loading ? 'flex' : 'none';
  el('questions-table').style.display = loading ? 'none' : 'table';
}

function renderQuestionsTable() {
  const tbody = el('questions-tbody');
  const qs = state.filteredQuestions;
  const empty = el('questions-empty');
  const table = el('questions-table');

  if (qs.length === 0) {
    empty.classList.remove('hidden');
    table.style.display = 'none';
    el('questions-pagination').style.display = 'none';
    return;
  }

  empty.classList.add('hidden');
  table.style.display = 'table';
  el('questions-pagination').style.display = 'flex';

  const totalPages = Math.ceil(qs.length / state.pageSize);
  const start = (state.currentPage - 1) * state.pageSize;
  const page = qs.slice(start, start + state.pageSize);

  tbody.innerHTML = page.map(q => renderQuestionRow(q)).join('');

  // Bind action buttons
  tbody.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', e => {
      const row = btn.closest('tr');
      const id = btn.dataset.id;
      const action = btn.dataset.action;
      if (action === 'edit')    openEditModal(id);
      if (action === 'preview') openPreviewModal(id);
      if (action === 'delete')  showDeleteConfirm(row, id);
      if (action === 'confirm-delete') confirmDelete(row, id);
      if (action === 'cancel-delete')  cancelDelete(row, id, q);
    });
  });

  updatePagination(qs.length, totalPages);
}

function renderQuestionRow(q) {
  const topicObj = state.topicsMap[q.topic] || {};
  const topicName = topicObj.nameRo || q.topic || '—';
  const answers = q.answers || [];
  const correctAnswer = answers[q.correctIndex] || '—';
  const textTrunc = (q.text || '').slice(0, 60) + ((q.text || '').length > 60 ? '…' : '');

  return `
    <tr data-id="${q.id || q._id}">
      <td class="q-id">${(q.id || q._id || '').toString().slice(-6)}</td>
      <td class="q-text"><div class="q-text-inner" title="${escHtml(q.text || '')}">${escHtml(textTrunc)}</div></td>
      <td><span class="topic-emoji">${topicObj.emoji || '📚'}</span>${escHtml(topicName)}</td>
      <td><span class="lang-badge lang-badge--${q.language || 'ro'}">${(q.language || 'ro').toUpperCase()}</span></td>
      <td><span class="difficulty-badge difficulty-badge--${q.difficulty || 'easy'}">${q.difficulty || 'easy'}</span></td>
      <td class="q-correct" title="${escHtml(correctAnswer)}">
        <span class="answer-letter answer-letter--${['a','b','c','d'][q.correctIndex]}">${['A','B','C','D'][q.correctIndex] || '?'}</span>
        ${escHtml(correctAnswer.slice(0, 30))}${correctAnswer.length > 30 ? '…' : ''}
      </td>
      <td>
        <div class="actions-cell" id="actions-${q.id || q._id}">
          <button class="btn-icon" data-action="edit" data-id="${q.id || q._id}" title="Edit">✏️</button>
          <button class="btn-icon" data-action="preview" data-id="${q.id || q._id}" title="Preview">👁️</button>
          <button class="btn-icon" data-action="delete" data-id="${q.id || q._id}" title="Delete">🗑️</button>
        </div>
      </td>
    </tr>`;
}

function updatePagination(total, totalPages) {
  const info = el('pagination-info');
  const prev = el('prev-page');
  const next = el('next-page');

  const start = (state.currentPage - 1) * state.pageSize + 1;
  const end = Math.min(state.currentPage * state.pageSize, total);
  info.textContent = `Showing ${start}–${end} of ${total} questions`;

  prev.disabled = state.currentPage <= 1;
  next.disabled = state.currentPage >= totalPages;
}

// ============================================================
// SECTION 9: FILTER LOGIC
// ============================================================

function applyFilters() {
  state.currentPage = 1;
  loadQuestions();
}

let searchDebounce = null;
function onSearchInput(e) {
  state.filters.search = e.target.value;
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(applyFilters, 300);
}

function setupFilterListeners() {
  el('filter-topic').addEventListener('change', e => {
    state.filters.topic = e.target.value;
    applyFilters();
  });

  setupToggleGroup(el('filter-language'), val => {
    state.filters.language = val;
    applyFilters();
  });

  setupToggleGroup(el('filter-difficulty'), val => {
    state.filters.difficulty = val;
    applyFilters();
  });

  el('filter-search').addEventListener('input', onSearchInput);

  el('prev-page').addEventListener('click', () => {
    if (state.currentPage > 1) { state.currentPage--; renderQuestionsTable(); }
  });

  el('next-page').addEventListener('click', () => {
    const total = Math.ceil(state.filteredQuestions.length / state.pageSize);
    if (state.currentPage < total) { state.currentPage++; renderQuestionsTable(); }
  });
}

// ============================================================
// SECTION 10: QUESTION MODAL (ADD / EDIT)
// ============================================================

function openNewModal() {
  state.editingQuestion = null;
  el('modal-title').textContent = 'New Question';
  el('edit-question-id').value = '';
  resetQuestionForm();
  el('question-modal').classList.remove('hidden');
  el('q-text').focus();
}

async function openEditModal(id) {
  try {
    const data = await api('GET', `/admin/api/questions/${id}`);
    if (!data) return;
    const q = data.question || data;
    state.editingQuestion = q;

    el('modal-title').textContent = 'Edit Question';
    el('edit-question-id').value = q.id || q._id;

    // Topic
    if (q.topic) el('q-topic').value = q.topic;

    // Language
    setToggleGroup(el('q-language'), q.language || 'ro');

    // Difficulty
    setToggleGroup(el('q-difficulty'), q.difficulty || 'easy');

    // Text
    el('q-text').value = q.text || '';

    // Answers
    const answers = q.answers || [];
    el('q-a').value = answers[0] || '';
    el('q-b').value = answers[1] || '';
    el('q-c').value = answers[2] || '';
    el('q-d').value = answers[3] || '';

    // Correct
    const radios = document.querySelectorAll('input[name="correct"]');
    radios.forEach(r => { r.checked = parseInt(r.value) === q.correctIndex; });

    el('question-modal').classList.remove('hidden');
    updatePreview();
  } catch (err) {
    showToast(`Failed to load question: ${err.message}`, 'error');
  }
}

function resetQuestionForm() {
  el('question-form').querySelectorAll('.error').forEach(el => el.classList.remove('error'));
  el('q-topic').value = '';
  setToggleGroup(el('q-language'), 'ro');
  setToggleGroup(el('q-difficulty'), 'easy');
  el('q-text').value = '';
  el('q-a').value = '';
  el('q-b').value = '';
  el('q-c').value = '';
  el('q-d').value = '';
  document.querySelectorAll('input[name="correct"]').forEach(r => r.checked = false);
  updatePreview();
}

function closeModal() {
  el('question-modal').classList.add('hidden');
  state.editingQuestion = null;
}

async function handleSaveQuestion(e) {
  e.preventDefault();
  if (!validateQuestionForm()) return;

  const btn = el('modal-save');
  const spinner = el('save-spinner');
  btn.disabled = true;
  spinner.classList.remove('hidden');

  const language = getToggleValue(el('q-language')) || 'ro';
  const difficulty = getToggleValue(el('q-difficulty')) || 'easy';
  const correctRadio = document.querySelector('input[name="correct"]:checked');

  const body = {
    text: el('q-text').value.trim(),
    answers: [
      el('q-a').value.trim(),
      el('q-b').value.trim(),
      el('q-c').value.trim(),
      el('q-d').value.trim(),
    ],
    correctIndex: correctRadio ? parseInt(correctRadio.value) : 0,
    topic: el('q-topic').value,
    difficulty,
    language,
  };

  try {
    const editId = el('edit-question-id').value;
    if (editId) {
      await api('PUT', `/admin/api/questions/${editId}`, body);
      showToast('Question updated ✓', 'success');
    } else {
      await api('POST', '/admin/api/questions', body);
      showToast('Question saved ✓', 'success');
    }
    closeModal();
    await loadQuestions();
  } catch (err) {
    showToast(`Error: ${err.message}`, 'error');
  } finally {
    btn.disabled = false;
    spinner.classList.add('hidden');
  }
}

function validateQuestionForm() {
  let valid = true;
  const required = [
    { el: el('q-topic'),    check: v => v !== '' },
    { el: el('q-text'),     check: v => v.trim() !== '' },
    { el: el('q-a'),        check: v => v.trim() !== '' },
    { el: el('q-b'),        check: v => v.trim() !== '' },
    { el: el('q-c'),        check: v => v.trim() !== '' },
    { el: el('q-d'),        check: v => v.trim() !== '' },
  ];

  required.forEach(({ el: field, check }) => {
    if (!check(field.value)) {
      field.classList.add('error');
      valid = false;
    } else {
      field.classList.remove('error');
    }
  });

  const correctRadio = document.querySelector('input[name="correct"]:checked');
  const radiosGroup = el('correct-answer-group');
  if (!correctRadio) {
    radiosGroup.style.outline = '1px solid var(--color-red)';
    radiosGroup.style.borderRadius = 'var(--radius-sm)';
    valid = false;
  } else {
    radiosGroup.style.outline = '';
  }

  return valid;
}

// ============================================================
// SECTION 11: PREVIEW MODAL
// ============================================================

async function openPreviewModal(id) {
  try {
    const data = await api('GET', `/admin/api/questions/${id}`);
    if (!data) return;
    const q = data.question || data;

    const topicObj = state.topicsMap[q.topic] || {};
    const topicName = topicObj.nameRo || q.topic || 'Unknown';
    const answers = q.answers || [];

    el('preview-modal-id').textContent = `Question ID: ${q.id || q._id}`;

    const content = el('preview-modal-content');
    content.innerHTML = `
      <div class="preview-meta">
        <span class="preview-badge">${topicObj.emoji || '📚'} ${escHtml(topicName)}</span>
        <span class="preview-badge preview-badge--lang">${(q.language || 'ro').toUpperCase()}</span>
        <span class="preview-badge preview-badge--diff ${q.difficulty || 'easy'}">${q.difficulty || 'easy'}</span>
      </div>
      <div class="preview-text">${escHtml(q.text || '')}</div>
      <div class="preview-answers">
        ${answers.map((a, i) => `
          <div class="preview-answer${i === q.correctIndex ? ' correct' : ''}">
            <span class="preview-answer-letter">${['A','B','C','D'][i]}</span>
            <span class="preview-answer-text">${escHtml(a)}</span>
          </div>`).join('')}
      </div>`;

    el('preview-modal').classList.remove('hidden');
  } catch (err) {
    showToast(`Failed to load question: ${err.message}`, 'error');
  }
}

function closePreviewModal() {
  el('preview-modal').classList.add('hidden');
}

// ============================================================
// SECTION 12: DELETE CONFIRMATION (INLINE)
// ============================================================

function showDeleteConfirm(row, id) {
  row.classList.add('deleting');
  const actionsCell = el(`actions-${id}`);
  actionsCell.innerHTML = `
    <span class="confirm-cell">
      <span>Delete?</span>
      <button class="btn btn-danger btn-sm" data-action="confirm-delete" data-id="${id}">Yes</button>
      <button class="btn btn-ghost btn-sm" data-action="cancel-delete" data-id="${id}">No</button>
    </span>`;

  // Re-bind
  actionsCell.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      if (btn.dataset.action === 'confirm-delete') confirmDelete(row, id);
      if (btn.dataset.action === 'cancel-delete')  cancelDelete(row, id);
    });
  });
}

async function confirmDelete(row, id) {
  try {
    await api('DELETE', `/admin/api/questions/${id}`);
    row.style.transition = 'opacity 0.3s, transform 0.3s';
    row.style.opacity = '0';
    row.style.transform = 'translateX(20px)';
    setTimeout(() => row.remove(), 300);
    state.questions = state.questions.filter(q => (q.id || q._id) !== id);
    state.filteredQuestions = state.filteredQuestions.filter(q => (q.id || q._id) !== id);
    showToast('Question deleted ✓', 'success');
    updatePagination(state.filteredQuestions.length, Math.ceil(state.filteredQuestions.length / state.pageSize));
  } catch (err) {
    showToast(`Error: ${err.message}`, 'error');
    cancelDelete(row, id);
  }
}

function cancelDelete(row, id) {
  row.classList.remove('deleting');
  // Find the original question to re-render the row
  const q = state.questions.find(q => (q.id || q._id) === id || (q.id || q._id).toString() === id);
  if (q) {
    const actionsCell = el(`actions-${id}`);
    actionsCell.innerHTML = `
      <button class="btn-icon" data-action="edit" data-id="${id}" title="Edit">✏️</button>
      <button class="btn-icon" data-action="preview" data-id="${id}" title="Preview">👁️</button>
      <button class="btn-icon" data-action="delete" data-id="${id}" title="Delete">🗑️</button>`;

    actionsCell.querySelectorAll('[data-action]').forEach(btn => {
      btn.addEventListener('click', () => {
        if (btn.dataset.action === 'edit')    openEditModal(id);
        if (btn.dataset.action === 'preview') openPreviewModal(id);
        if (btn.dataset.action === 'delete')  showDeleteConfirm(row, id);
      });
    });
  }
}

// ============================================================
// SECTION 13: LIVE PREVIEW (IN MODAL)
// ============================================================

function updatePreview() {
  const text = el('q-text').value || 'Question text will appear here…';
  const a = el('q-a').value || 'Answer A';
  const b = el('q-b').value || 'Answer B';
  const c = el('q-c').value || 'Answer C';
  const d = el('q-d').value || 'Answer D';
  const lang = getToggleValue(el('q-language')) || 'ro';
  const diff = getToggleValue(el('q-difficulty')) || 'easy';
  const topicId = el('q-topic').value;
  const topicObj = state.topicsMap[topicId] || {};
  const topicName = topicObj.nameRo || topicId || 'Topic';
  const correctRadio = document.querySelector('input[name="correct"]:checked');
  const correctIdx = correctRadio ? parseInt(correctRadio.value) : -1;

  el('preview-text').textContent = text;
  el('preview-topic-badge').textContent = `${topicObj.emoji || '📚'} ${topicName}`;
  el('preview-lang-badge').textContent = lang.toUpperCase();
  el('preview-diff-badge').textContent = diff;
  el('preview-diff-badge').className = `preview-badge preview-badge--diff ${diff}`;

  const answers = [a, b, c, d];
  el('preview-answers').querySelectorAll('.preview-answer').forEach((div, i) => {
    div.querySelector('.preview-answer-text').textContent = answers[i];
    div.classList.toggle('correct', i === correctIdx);
  });
}

function setupPreviewListeners() {
  const inputs = [el('q-text'), el('q-a'), el('q-b'), el('q-c'), el('q-d')];
  inputs.forEach(inp => inp.addEventListener('input', updatePreview));
  document.querySelectorAll('input[name="correct"]').forEach(r => r.addEventListener('change', updatePreview));
}

// ============================================================
// SECTION 14: LIVE GAMES VIEW
// ============================================================

async function loadLiveGames() {
  try {
    const data = await api('GET', '/admin/api/rooms');
    if (data) {
      state.rooms = data.rooms || [];
      renderRooms();
    }
  } catch (err) {
    showToast(`Failed to load rooms: ${err.message}`, 'error');
  }
}

function renderRooms() {
  const container = el('live-games-container');

  if (state.rooms.length === 0) {
    container.innerHTML = `
      <div class="no-games">
        <div class="no-games-icon">🎮</div>
        <div class="no-games-title">No active games right now</div>
        <div class="no-games-sub">Games will appear here when players are matched.</div>
      </div>`;
    return;
  }

  container.innerHTML = `<div class="rooms-grid">${state.rooms.map(renderRoomCard).join('')}</div>`;
}

function renderRoomCard(room) {
  const players = room.players || [];
  const p1 = players[0] || { displayName: 'Player 1', score: 0 };
  const p2 = players[1] || { displayName: 'Player 2', score: 0 };
  const round = room.currentRound || 1;
  const total = room.totalRounds || 7;
  const pct = Math.round((round / total) * 100);

  return `
    <div class="room-card">
      <div class="room-header">
        <span class="room-id">Room: ${escHtml(room.roomId || '')}</span>
        <span class="room-round">Round ${round} / ${total}</span>
      </div>
      <div class="room-players">
        <div class="player-card">
          <div class="player-name">👤 ${escHtml(p1.displayName || 'Player 1')}</div>
          <div class="player-score">${p1.score ?? 0}</div>
          <div class="player-label">pts</div>
        </div>
        <div class="room-vs">VS</div>
        <div class="player-card">
          <div class="player-name">👤 ${escHtml(p2.displayName || 'Player 2')}</div>
          <div class="player-score">${p2.score ?? 0}</div>
          <div class="player-label">pts</div>
        </div>
      </div>
      <div class="room-round-bar">
        <div class="room-round-fill" style="width:${pct}%"></div>
      </div>
    </div>`;
}

// ============================================================
// SECTION 15: TOPICS VIEW
// ============================================================

async function loadTopicsView() {
  const grid = el('topics-grid');
  grid.innerHTML = '<div class="loading-state"><span class="spinner"></span> Loading…</div>';

  try {
    const data = await api('GET', '/admin/api/topics');
    if (data) {
      state.topics = data.topics || [];
      state.topicsMap = {};
      state.topics.forEach(t => { state.topicsMap[t.id] = t; });
      renderTopicsGrid();
    }
  } catch (err) {
    grid.innerHTML = `<div class="empty-state"><div class="empty-sub">Failed to load topics: ${err.message}</div></div>`;
  }
}

function renderTopicsGrid() {
  const grid = el('topics-grid');

  if (state.topics.length === 0) {
    grid.innerHTML = `
      <div class="empty-state" style="grid-column:1/-1">
        <div class="empty-icon">📚</div>
        <div class="empty-title">No topics found</div>
      </div>`;
    return;
  }

  grid.innerHTML = state.topics.map(t => {
    const ro = t.questionCount?.ro || 0;
    const en = t.questionCount?.en || 0;
    const total = t.questionCount?.total || (ro + en);
    const roPct = total > 0 ? Math.round((ro / total) * 100) : 50;
    const enPct = 100 - roPct;

    return `
      <div class="topic-card">
        <div class="topic-card-header">
          <span class="topic-card-emoji">${t.emoji || '📚'}</span>
          <div class="topic-card-names">
            <div class="topic-card-name-ro">${escHtml(t.nameRo || t.id)}</div>
            <div class="topic-card-name-en">${escHtml(t.nameEn || '')}</div>
          </div>
          <span class="topic-card-count">${total}</span>
        </div>
        <div class="topic-card-stats">
          <span><span class="topic-stat-ro">${ro}</span><span class="topic-stat-label">RO</span></span>
          <span><span class="topic-stat-en">${en}</span><span class="topic-stat-label">EN</span></span>
        </div>
        <div class="topic-dist-bar">
          <div class="topic-dist-ro" style="width:${roPct}%"></div>
          <div class="topic-dist-en" style="width:${enPct}%"></div>
        </div>
        <button class="btn btn-ghost btn-sm" onclick="filterByTopic('${escHtml(t.id)}')">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="3" y1="6" x2="21" y2="6" stroke-width="2"/>
            <line x1="8" y1="12" x2="16" y2="12" stroke-width="2"/>
            <line x1="10" y1="18" x2="14" y2="18" stroke-width="2"/>
          </svg>
          View Questions
        </button>
      </div>`;
  }).join('');
}

function filterByTopic(topicId) {
  state.filters.topic = topicId;
  state.filters.language = '';
  state.filters.difficulty = '';
  state.filters.search = '';
  navigateTo('questions');
  // After navigation, set the filter dropdown
  setTimeout(() => {
    el('filter-topic').value = topicId;
    // Reset toggles
    setToggleGroup(el('filter-language'), '');
    setToggleGroup(el('filter-difficulty'), '');
    el('filter-search').value = '';
  }, 50);
}

// ============================================================
// SECTION 16: TOAST NOTIFICATIONS
// ============================================================

function showToast(message, type = 'info') {
  const container = el('toast-container');

  const icons = { success: '✅', error: '❌', info: 'ℹ️' };

  const toast = document.createElement('div');
  toast.className = `toast toast--${type}`;
  toast.innerHTML = `
    <span class="toast-icon">${icons[type] || icons.info}</span>
    <span class="toast-text">${escHtml(message)}</span>
    <button class="toast-close" aria-label="Dismiss">✕</button>`;

  container.appendChild(toast);

  toast.querySelector('.toast-close').addEventListener('click', () => dismissToast(toast));

  const timer = setTimeout(() => dismissToast(toast), 3000);
  toast._timer = timer;
}

function dismissToast(toast) {
  if (toast._timer) clearTimeout(toast._timer);
  toast.classList.add('leaving');
  toast.addEventListener('animationend', () => toast.remove(), { once: true });
}

// ============================================================
// SECTION 17: SIDEBAR / MOBILE
// ============================================================

let sidebarOverlay = null;

function setupSidebar() {
  // Create overlay for mobile
  sidebarOverlay = document.createElement('div');
  sidebarOverlay.className = 'sidebar-overlay';
  document.body.appendChild(sidebarOverlay);
  sidebarOverlay.addEventListener('click', closeMobileSidebar);

  el('sidebar-toggle').addEventListener('click', toggleSidebar);
}

function toggleSidebar() {
  const sidebar = el('sidebar');
  const isMobile = window.innerWidth <= 768;

  if (isMobile) {
    sidebar.classList.toggle('mobile-open');
    sidebarOverlay.classList.toggle('visible', sidebar.classList.contains('mobile-open'));
  } else {
    sidebar.classList.toggle('collapsed');
  }
}

function closeMobileSidebar() {
  if (window.innerWidth <= 768) {
    el('sidebar').classList.remove('mobile-open');
    if (sidebarOverlay) sidebarOverlay.classList.remove('visible');
  }
}

// ============================================================
// SECTION 18: TOGGLE GROUP HELPERS
// ============================================================

function setupToggleGroup(groupEl, onChange) {
  if (!groupEl) return;
  groupEl.querySelectorAll('.toggle-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      groupEl.querySelectorAll('.toggle-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      if (onChange) onChange(btn.dataset.value);
    });
  });
}

function setToggleGroup(groupEl, value) {
  if (!groupEl) return;
  groupEl.querySelectorAll('.toggle-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.value === value);
  });
}

function getToggleValue(groupEl) {
  if (!groupEl) return '';
  const active = groupEl.querySelector('.toggle-btn.active');
  return active ? active.dataset.value : '';
}

// ============================================================
// SECTION 19: KEYBOARD & CLICK-OUTSIDE
// ============================================================

function setupGlobalListeners() {
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      if (!el('question-modal').classList.contains('hidden')) closeModal();
      if (!el('preview-modal').classList.contains('hidden')) closePreviewModal();
    }
  });

  el('question-modal').addEventListener('click', e => {
    if (e.target === el('question-modal')) closeModal();
  });

  el('preview-modal').addEventListener('click', e => {
    if (e.target === el('preview-modal')) closePreviewModal();
  });
}

// ============================================================
// SECTION 20: UTILITIES
// ============================================================

function el(id) { return document.getElementById(id); }
function qAll(sel) { return document.querySelectorAll(sel); }

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// ============================================================
// SECTION 21: APP INITIALIZATION
// ============================================================

async function initApp() {
  // Populate topic dropdowns (async, don't block)
  loadTopics().catch(() => {});

  // Set up all event listeners
  setupSidebar();
  setupFilterListeners();
  setupPreviewListeners();
  setupGlobalListeners();

  // Nav items
  qAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => navigateTo(btn.dataset.view));
  });

  // Logout
  el('logout-btn').addEventListener('click', () => {
    if (confirm('Log out of the admin panel?')) showLogin();
  });

  // Modal buttons
  el('new-question-btn').addEventListener('click', openNewModal);
  el('modal-close').addEventListener('click', closeModal);
  el('modal-cancel').addEventListener('click', closeModal);
  el('preview-modal-close').addEventListener('click', closePreviewModal);
  el('question-form').addEventListener('submit', handleSaveQuestion);

  // Toggle groups in modal update preview
  setupToggleGroup(el('q-language'), () => updatePreview());
  setupToggleGroup(el('q-difficulty'), () => updatePreview());
  el('q-topic').addEventListener('change', updatePreview);

  // Clear error highlighting on input
  qAll('.form-input, .form-select').forEach(inp => {
    inp.addEventListener('input', () => inp.classList.remove('error'));
    inp.addEventListener('change', () => inp.classList.remove('error'));
  });

  // Navigate to default view
  navigateTo('dashboard');
}

// ============================================================
// SECTION 22: BOOTSTRAP
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
  if (state.secret) {
    // Verify the stored secret is still valid
    api('GET', '/admin/api/stats')
      .then(data => {
        if (data) {
          showApp();
          initApp();
        } else {
          showLogin();
        }
      })
      .catch(() => showLogin());
  } else {
    showLogin();
  }

  // Login form
  el('login-form').addEventListener('submit', handleLogin);

  // Show login screen (it starts hidden)
  if (!state.secret) {
    el('login-screen').classList.remove('hidden');
  }
});
