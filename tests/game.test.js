'use strict';

/**
 * BrainDuel — Server Integration Tests
 *
 * Simulates 2 real players through a full game:
 *   Suite 1 — Server health
 *   Suite 2 — Matchmaking
 *   Suite 3 — All 7 rounds (score formula verified manually)
 *   Suite 4 — Abilities (50/50, double_down, sabotage, time_boost, shield)
 *   Suite 5 — Round timeout (player doesn't answer)
 *   Suite 6 — Game end + rewards
 *   Suite 7 — Mid-game disconnect
 *   Suite 8 — Error handling (rogue ability, double ability use)
 *
 * Prerequisites: server running on http://localhost:3001 with SKIP_AUTH=true
 *   cd server && SKIP_AUTH=true npm run dev
 */

const { io: ioClient } = require('socket.io-client');

const SERVER_URL = process.env.SERVER_URL || 'http://localhost:3001';
const VERBOSE    = process.env.VERBOSE === 'true';

// ── Terminal colours ──────────────────────────────────────────────────────────
const C = {
  reset:   '\x1b[0m',
  bold:    '\x1b[1m',
  green:   '\x1b[32m',
  red:     '\x1b[31m',
  yellow:  '\x1b[33m',
  cyan:    '\x1b[36m',
  magenta: '\x1b[35m',
  blue:    '\x1b[34m',
  gray:    '\x1b[90m',
};
const col = (color, ...args) => `${C[color]}${args.join(' ')}${C.reset}`;
const log  = (color, ...args) => console.log(col(color, ...args));
const verb = (...args) => VERBOSE && console.log(col('gray', ...args));

// ── Assertion helpers ─────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;
const failures = [];

function assert(condition, label, actual, expected) {
  if (condition) {
    passed++;
    console.log(col('green', `  ✓ ${label}`));
  } else {
    failed++;
    const msg = expected !== undefined
      ? `  ✗ ${label} — got: ${JSON.stringify(actual)}, want: ${JSON.stringify(expected)}`
      : `  ✗ ${label}`;
    console.log(col('red', msg));
    failures.push(msg);
  }
}

function assertEq(actual, expected, label) {
  assert(actual === expected, label, actual, expected);
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ── Scoring formula (mirrors server's scoring.js) ─────────────────────────────
function expectedPoints(answerIndex, correctIndex, timeTaken, effects = {}) {
  if (answerIndex === null || answerIndex === undefined) return 0;
  if (answerIndex !== correctIndex) return 0;

  let t = timeTaken;
  if (effects.timeBonusMs)   t = Math.max(0, t - effects.timeBonusMs);
  if (effects.timePenaltyMs) t = t + effects.timePenaltyMs;

  const secs = Math.floor(t / 1000);
  let pts = Math.max(11, 20 - secs);
  if (effects.doubleDown) pts *= 2;
  return pts;
}

// ── TestPlayer ────────────────────────────────────────────────────────────────
class TestPlayer {
  constructor(name) {
    this.name       = name;
    this.socket     = null;
    this.waiters    = {};   // event → [{resolve, reject, timer}]
    this.log        = [];   // all received events
    this.socketId   = null;
    this.abilitySet = [];
    this.usedAbilities = [];
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.socket = ioClient(SERVER_URL, { transports: ['websocket'], timeout: 5000 });

      this.socket.on('connect', () => {
        this.socketId = this.socket.id;
        verb(`  [${this.name}] connected: ${this.socketId}`);
        resolve();
      });
      this.socket.on('connect_error', reject);

      const events = [
        'queue_joined', 'match_found', 'game_start', 'new_question',
        'round_result', 'ability_effect', 'game_end',
        'opponent_disconnected', 'error',
      ];
      events.forEach(evt => {
        this.socket.on(evt, data => {
          verb(`  [${this.name}] ← ${evt}: ${JSON.stringify(data).slice(0, 120)}`);
          this.log.push({ evt, data, ts: Date.now() });
          const queue = this.waiters[evt];
          if (queue && queue.length > 0) {
            const w = queue.shift();
            clearTimeout(w.timer);
            w.resolve(data);
          }
        });
      });
    });
  }

  waitFor(event, timeoutMs = 20000) {
    return new Promise((resolve, reject) => {
      if (!this.waiters[event]) this.waiters[event] = [];
      const timer = setTimeout(() => {
        const q = this.waiters[event];
        if (q) {
          const idx = q.findIndex(w => w.resolve === wrapped);
          if (idx !== -1) q.splice(idx, 1);
        }
        reject(new Error(`[${this.name}] timeout waiting for "${event}" (${timeoutMs}ms)`));
      }, timeoutMs);

      const wrapped = (data) => { clearTimeout(timer); resolve(data); };
      this.waiters[event].push({ resolve: wrapped, reject, timer });
    });
  }

  emit(event, data) {
    verb(`  [${this.name}] → ${event}: ${JSON.stringify(data).slice(0, 120)}`);
    this.socket.emit(event, data);
  }

  joinQueue(topicId) {
    this.emit('join_queue', {
      topicId,
      userId: `user_${this.name.toLowerCase()}`,
      token: this.name.toLowerCase(),   // SKIP_AUTH → uid = 'dev_' + token
      displayName: this.name,
    });
  }

  submitAnswer(answerIndex, timeTaken = 1000) {
    this.emit('submit_answer', { answerIndex, timeTaken });
  }

  useAbility(type) {
    if (this.usedAbilities.includes(type)) {
      verb(`  [${this.name}] skipping ${type} — already used`);
      return false;
    }
    if (!this.abilitySet.includes(type)) {
      verb(`  [${this.name}] skipping ${type} — not in set ${JSON.stringify(this.abilitySet)}`);
      return false;
    }
    this.usedAbilities.push(type);
    this.emit('use_ability', { abilityType: type });
    return true;
  }

  disconnect() {
    this.socket && this.socket.disconnect();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
async function bothWait(pa, pb, event, ms = 20000) {
  return Promise.all([pa.waitFor(event, ms), pb.waitFor(event, ms)]);
}

function banner(title) {
  log('cyan', `\n── ${title} ──`);
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN TEST RUNNER
// =════════════════════════════════════════════════════════════════════════════
async function run() {
  log('bold', '\n╔══════════════════════════════════════════════════════╗');
  log('bold', '║     BrainDuel — Server Integration Tests             ║');
  log('bold', `║     Server: ${SERVER_URL.padEnd(38)}║`);
  log('bold', '╚══════════════════════════════════════════════════════╝');

  // ── Suite 1: Health ─────────────────────────────────────────────────────
  banner('Suite 1 — Server Health');
  try {
    const res  = await fetch(`${SERVER_URL}/health`);
    const body = await res.json();
    assert(res.ok,              'GET /health → 200 OK',       res.status, 200);
    assertEq(body.status, 'ok', '/health body.status === "ok"');
    log('gray', `  timestamp: ${body.timestamp}`);
  } catch (e) {
    log('red', `\n❌  Cannot reach ${SERVER_URL}`);
    log('red', '    Start the server first:  cd server && SKIP_AUTH=true npm run dev\n');
    process.exit(1);
  }

  // ── Suite 2: Matchmaking ────────────────────────────────────────────────
  banner('Suite 2 — Matchmaking');

  const alice = new TestPlayer('Alice');
  const bob   = new TestPlayer('Bob');
  await Promise.all([alice.connect(), bob.connect()]);

  assert(alice.socket.connected, 'Alice connected');
  assert(bob.socket.connected,   'Bob connected');

  // Alice joins first
  alice.joinQueue('general_knowledge');
  const qj = await alice.waitFor('queue_joined', 3000);
  assert(typeof qj.position === 'number', 'Alice gets queue_joined { position }');

  // Bob joins — should trigger a match
  bob.joinQueue('general_knowledge');

  const [mAlice, mBob] = await bothWait(alice, bob, 'match_found', 6000);
  assert(!!mAlice.roomId,                          'Alice receives match_found with roomId');
  assert(!!mBob.roomId,                            'Bob receives match_found with roomId');
  assertEq(mAlice.roomId, mBob.roomId,             'Both players in same room');
  assertEq(mAlice.opponent.userId, 'dev_bob',   'Alice sees opponent = dev_bob');
  assertEq(mBob.opponent.userId,   'dev_alice', 'Bob sees opponent = dev_alice');
  assert(Array.isArray(mAlice.abilitySet),         'Alice receives her abilitySet');
  assert(Array.isArray(mBob.abilitySet),           'Bob receives his abilitySet');

  alice.abilitySet = mAlice.abilitySet;
  bob.abilitySet   = mBob.abilitySet;
  log('gray', `  Alice abilities: [${alice.abilitySet}]`);
  log('gray', `  Bob abilities:   [${bob.abilitySet}]`);

  // Wait for game_start (3 s server delay)
  log('yellow', '  Waiting for game_start (~3 s)...');
  await bothWait(alice, bob, 'game_start', 5000);
  assert(true, 'Both players receive game_start');

  // ── Suite 3: Round Mechanics (Rounds 1-5) ───────────────────────────────
  banner('Suite 3 — Round Mechanics & Score Verification');

  let aliceScore = 0;
  let bobScore   = 0;

  // ── Round 1 — both correct, fast ──────────────────────────────────────
  log('yellow', '\n  Round 1: Both answer index 0 at 1 000 ms');
  const [q1a, q1b] = await bothWait(alice, bob, 'new_question', 3000);

  assertEq(q1a.round, 1,    'Round 1 question — round number');
  assert(!('correctIndex' in q1a.question),
    '⚠  Security: correctIndex NOT sent to client in new_question');
  assertEq(q1a.question.answers.length, 4, 'Question has exactly 4 answers');

  alice.submitAnswer(0, 1000);
  bob.submitAnswer(0, 1000);

  const [r1a, r1b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r1a.round, 1, 'round_result.round === 1');
  assert(typeof r1a.correctIndex === 'number', 'correctIndex revealed in round_result');

  // Verify score formula
  const ci1       = r1a.correctIndex;
  const expAlice1 = expectedPoints(0, ci1, 1000);
  const expBob1   = expectedPoints(0, ci1, 1000);
  assertEq(r1a.player.pointsEarned,   expAlice1, `Alice R1 points match formula (${expAlice1})`);
  assertEq(r1b.player.pointsEarned,   expBob1,   `Bob R1 points match formula (${expBob1})`);

  // Cross-verify: Alice's totalScore === Bob's view of opponent totalScore
  assert(r1a.player.totalScore === r1b.opponent.totalScore,
    "Alice's totalScore === Bob's view of opponent totalScore",
    r1b.opponent.totalScore, r1a.player.totalScore);

  aliceScore = r1a.player.totalScore;
  bobScore   = r1b.player.totalScore;
  log('gray', `  After R1 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Round 2 — Alice answers wrong, Bob correct ────────────────────────
  log('yellow', '\n  Round 2: Alice answers wrong index, Bob correct at 3 000 ms');
  const [q2a] = await bothWait(alice, bob, 'new_question', 3000);
  assertEq(q2a.round, 2, 'Round 2 question received');

  // We don't know correctIndex yet, so use a deliberately wrong approach:
  // Alice sends index 3, Bob sends index 0 — one of them will be correct.
  alice.submitAnswer(3, 3000);
  bob.submitAnswer(0, 3000);

  const [r2a, r2b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r2a.round, 2, 'round_result.round === 2');

  const ci2       = r2a.correctIndex;
  const expAlice2 = expectedPoints(3, ci2, 3000);
  const expBob2   = expectedPoints(0, ci2, 3000);
  assertEq(r2a.player.pointsEarned, expAlice2, `Alice R2 points match formula (${expAlice2})`);
  assertEq(r2b.player.pointsEarned, expBob2,   `Bob R2 points match formula (${expBob2})`);

  aliceScore = r2a.player.totalScore;
  bobScore   = r2b.player.totalScore;
  log('gray', `  After R2 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Suite 4: Abilities ─────────────────────────────────────────────────
  banner('Suite 4 — Abilities');

  // ── Round 3 — 50/50 ──────────────────────────────────────────────────
  log('yellow', '\n  Round 3: 50/50 ability');
  const [q3a] = await bothWait(alice, bob, 'new_question', 3000);
  assertEq(q3a.round, 3, 'Round 3 question received');

  const fifty_user   = alice.abilitySet.includes('fifty_fifty') ? alice : bob;
  const fifty_unused = fifty_user === alice ? bob : alice;

  const didUse50 = fifty_user.useAbility('fifty_fifty');
  if (didUse50) {
    const effect50 = await fifty_user.waitFor('ability_effect', 3000);
    assertEq(effect50.abilityType,                   'fifty_fifty',    '50/50 ability_effect received');
    assert(Array.isArray(effect50.effect.removedIndices),              '50/50 effect has removedIndices[]');
    assertEq(effect50.effect.removedIndices.length,  2,                '50/50 removes exactly 2 indices');
    const ci3 = q3a.question.answers.length; // 4
    assert(
      !effect50.effect.removedIndices.includes(undefined),
      '50/50 removedIndices are valid numbers (not undefined)',
    );
    log('gray', `  Removed indices: [${effect50.effect.removedIndices}]`);
  } else {
    log('gray', '  Neither player has 50/50 — skipping');
  }

  fifty_user.submitAnswer(0, 2000);
  fifty_unused.submitAnswer(1, 2000);
  const [r3a, r3b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r3a.round, 3, 'round_result.round === 3');
  aliceScore = r3a.player.totalScore;
  bobScore   = r3b.player.totalScore;
  log('gray', `  After R3 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Round 4 — double_down ─────────────────────────────────────────────
  log('yellow', '\n  Round 4: double_down ability');
  const [q4a] = await bothWait(alice, bob, 'new_question', 3000);
  assertEq(q4a.round, 4, 'Round 4 question received');

  const dd_user   = bob.abilitySet.includes('double_down') ? bob : alice;
  const dd_unused = dd_user === bob ? alice : bob;
  const ddR4Before = dd_user === bob ? bobScore : aliceScore;

  const didDD = dd_user.useAbility('double_down');
  if (didDD) {
    const effectDD = await dd_user.waitFor('ability_effect', 3000);
    assertEq(effectDD.abilityType,        'double_down',  'double_down ability_effect received');
    assertEq(effectDD.effect.doubleDown,  true,           'double_down effect.doubleDown === true');
  } else {
    log('gray', '  No double_down available — skipping');
  }

  // Both answer at 0 ms so we get max points (20, or 40 with DD)
  dd_user.submitAnswer(0, 0);
  dd_unused.submitAnswer(0, 0);

  const [r4a, r4b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r4a.round, 4, 'round_result.round === 4');

  const ci4 = r4a.correctIndex;
  if (didDD && dd_user === bob) {
    const expBobDD = expectedPoints(0, ci4, 0, { doubleDown: true });
    assertEq(r4b.player.pointsEarned, expBobDD,
      `double_down doubles points (${expBobDD}, ci=${ci4})`);
  }

  aliceScore = r4a.player.totalScore;
  bobScore   = r4b.player.totalScore;
  log('gray', `  After R4 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Round 5 — sabotage (or time_boost) ───────────────────────────────
  log('yellow', '\n  Round 5: sabotage / time_boost ability');
  await bothWait(alice, bob, 'new_question', 3000);

  const sab_user   = bob.abilitySet.includes('sabotage') ? bob : alice;
  const sab_target = sab_user === bob ? alice : bob;

  const didSab = sab_user.useAbility('sabotage');
  if (didSab) {
    // sab_target should receive an ability_effect notification
    const targetNotif = await sab_target.waitFor('ability_effect', 3000);
    assertEq(targetNotif.abilityType, 'sabotage', 'Sabotage target receives ability_effect');
    assert(targetNotif.target === 'opponent', 'Target receives target="opponent"');
    log('gray', `  Sabotage effect on target: ${JSON.stringify(targetNotif.effect).slice(0,80)}`);
  } else if (alice.abilitySet.includes('time_boost')) {
    const didTB = alice.useAbility('time_boost');
    if (didTB) {
      const effTB = await alice.waitFor('ability_effect', 3000);
      assertEq(effTB.abilityType, 'time_boost', 'time_boost ability_effect received');
      log('gray', `  time_boost effect: ${JSON.stringify(effTB.effect)}`);
    }
  } else {
    log('gray', '  No sabotage/time_boost available — skipping');
  }

  alice.submitAnswer(2, 4000);
  bob.submitAnswer(2, 4000);
  const [r5a, r5b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r5a.round, 5, 'round_result.round === 5');
  aliceScore = r5a.player.totalScore;
  bobScore   = r5b.player.totalScore;
  log('gray', `  After R5 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Suite 5: Timeout ───────────────────────────────────────────────────
  banner('Suite 5 — Round Timeout (Bob does NOT answer)');

  log('yellow', '  Round 6: Alice answers, Bob stays silent — waiting ~11 s for timeout...');
  await bothWait(alice, bob, 'new_question', 3000);

  alice.submitAnswer(0, 500);
  // Bob deliberately silent

  const [r6a, r6b] = await bothWait(alice, bob, 'round_result', 15000);
  assertEq(r6a.round, 6, 'round_result received for round 6');
  assertEq(r6b.player.answerIndex,   null, 'Bob answerIndex === null (timeout)');
  assertEq(r6b.player.pointsEarned,  0,    'Bob scores 0 pts for timeout');

  aliceScore = r6a.player.totalScore;
  bobScore   = r6b.player.totalScore;
  log('gray', `  After R6 — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Round 7: Bonus ─────────────────────────────────────────────────────
  banner('Suite 3 (cont.) — Round 7: Bonus Round');
  log('yellow', '  Round 7 (BONUS): both answer at 500 ms');

  const [q7a] = await bothWait(alice, bob, 'new_question', 3000);
  assertEq(q7a.round,       7,    'Round 7 received');
  assertEq(q7a.isLastRound, true, 'isLastRound === true for round 7');

  alice.submitAnswer(0, 500);
  bob.submitAnswer(0, 500);

  const [r7a, r7b] = await bothWait(alice, bob, 'round_result', 6000);
  assertEq(r7a.round,       7,    'round_result.round === 7');
  assertEq(r7a.isLastRound, true, 'round_result.isLastRound === true');

  const ci7 = r7a.correctIndex;
  if (ci7 === 0) {
    // Both answered correctly at 500 ms → base = 20, bonus doubles → 40
    const expBonus = expectedPoints(0, 0, 500) * 2;
    assertEq(r7a.player.pointsEarned, expBonus,
      `Bonus round: Alice earned ${expBonus} pts (formula ×2)`);
  }

  aliceScore = r7a.player.totalScore;
  bobScore   = r7b.player.totalScore;
  log('gray', `  FINAL — Alice: ${aliceScore}, Bob: ${bobScore}`);

  // ── Suite 6: Game End & Rewards ────────────────────────────────────────
  banner('Suite 6 — Game End & Rewards');

  const [geA, geB] = await bothWait(alice, bob, 'game_end', 5000);

  assert(typeof geA.scores === 'object',         'game_end has scores object');
  assert(typeof geA.rewards === 'object',        'game_end has rewards for Alice');
  assert(typeof geA.rewards.xp    === 'number',  'rewards.xp is a number');
  assert(typeof geA.rewards.coins === 'number',  'rewards.coins is a number');
  assert(typeof geA.isDraw       === 'boolean',  'game_end.isDraw is boolean');
  assert(typeof geA.isWinner     === 'boolean',  'game_end.isWinner is boolean');

  // Winner gets 100 xp / 50 coins, loser gets 25 / 10, draw = 50 / 25
  if (geA.isDraw) {
    assertEq(geA.rewards.xp,    50, 'Draw: Alice gets 50 XP');
    assertEq(geB.rewards.xp,    50, 'Draw: Bob gets 50 XP');
    assertEq(geA.rewards.coins, 25, 'Draw: Alice gets 25 coins');
  } else if (geA.isWinner) {
    assertEq(geA.rewards.xp,    100, 'Alice (winner) gets 100 XP');
    assertEq(geA.rewards.coins,  50, 'Alice (winner) gets 50 coins');
    assertEq(geB.rewards.xp,     25, 'Bob (loser) gets 25 XP');
    assertEq(geB.rewards.coins,  10, 'Bob (loser) gets 10 coins');
  } else {
    assertEq(geB.rewards.xp,    100, 'Bob (winner) gets 100 XP');
    assertEq(geB.rewards.coins,  50, 'Bob (winner) gets 50 coins');
    assertEq(geA.rewards.xp,     25, 'Alice (loser) gets 25 XP');
    assertEq(geA.rewards.coins,  10, 'Alice (loser) gets 10 coins');
  }

  const winner = geA.isDraw ? 'DRAW' : geA.isWinner ? 'Alice' : 'Bob';
  log('gray', `  Result: ${winner} | Alice ${aliceScore} - ${bobScore} Bob`);
  log('gray', `  Alice rewards: ${geA.rewards.xp} XP, ${geA.rewards.coins} coins`);
  log('gray', `  Bob rewards:   ${geB.rewards.xp} XP, ${geB.rewards.coins} coins`);

  alice.disconnect();
  bob.disconnect();

  // ── Suite 7: Disconnect Mid-Game ───────────────────────────────────────
  banner('Suite 7 — Mid-Game Disconnect');

  const charlie = new TestPlayer('Charlie');
  const diana   = new TestPlayer('Diana');
  await Promise.all([charlie.connect(), diana.connect()]);

  charlie.joinQueue('history');
  diana.joinQueue('history');

  await bothWait(charlie, diana, 'match_found', 6000);
  await bothWait(charlie, diana, 'game_start', 5000);
  await bothWait(charlie, diana, 'new_question', 3000);

  log('yellow', '  Charlie disconnects mid-round...');
  charlie.disconnect();

  const disconnectMsg = await diana.waitFor('opponent_disconnected', 5000);
  assert(typeof disconnectMsg.message === 'string',  'Diana receives opponent_disconnected with message');
  assert(typeof disconnectMsg.rewards === 'object',  'Diana receives partial win rewards');
  assert(disconnectMsg.rewards.xp > 0,               'Diana\'s partial win XP > 0');

  log('gray', `  Diana partial win rewards: ${JSON.stringify(disconnectMsg.rewards)}`);
  diana.disconnect();

  // ── Suite 8: Error Handling ────────────────────────────────────────────
  banner('Suite 8 — Error Handling');

  const eve = new TestPlayer('Eve');
  await eve.connect();

  // Try ability outside game — server should not crash
  eve.emit('use_ability', { abilityType: 'fifty_fifty' });
  await sleep(400);
  assert(eve.socket.connected, 'Server stable after ability used outside game');

  // Try leave_queue when not in queue
  eve.emit('leave_queue', {});
  await sleep(300);
  assert(eve.socket.connected, 'Server stable after leave_queue when not in queue');

  // Try submit_answer with no active game
  eve.emit('submit_answer', { answerIndex: 0, timeTaken: 500 });
  await sleep(300);
  assert(eve.socket.connected, 'Server stable after submit_answer outside game');

  // ── Double ability use in a real game ─────────────────────────────────
  const frank = new TestPlayer('Frank');
  const grace = new TestPlayer('Grace');
  await Promise.all([frank.connect(), grace.connect()]);

  frank.joinQueue('music');
  grace.joinQueue('music');

  await bothWait(frank, grace, 'match_found', 6000);
  frank.abilitySet = (await frank.waitFor('match_found', 0).catch(() => null))?.abilitySet || ['fifty_fifty'];
  // frank.abilitySet was already set by the match_found above — re-extract:
  const fMatch = frank.log.find(e => e.evt === 'match_found');
  frank.abilitySet = fMatch ? fMatch.data.abilitySet : ['fifty_fifty', 'time_boost', 'shield'];

  await bothWait(frank, grace, 'game_start', 5000);
  await bothWait(frank, grace, 'new_question', 3000);

  const firstAbility = frank.abilitySet[0];
  frank.emit('use_ability', { abilityType: firstAbility });
  await sleep(400);
  // Try to use same ability again
  const errorPromise = frank.waitFor('error', 2000).catch(() => null);
  frank.emit('use_ability', { abilityType: firstAbility });
  const dupError = await errorPromise;
  assert(dupError !== null && typeof dupError.message === 'string',
    'Server sends error on duplicate ability use');
  log('gray', `  Error msg: ${dupError?.message}`);

  frank.disconnect();
  grace.disconnect();
  eve.disconnect();

  // ── Final Report ──────────────────────────────────────────────────────
  const total = passed + failed;
  console.log('');
  log('bold', '╔══════════════════════════════════════════════════════╗');
  if (failed === 0) {
    log('bold', `║  ${col('green', `✓  All ${total} tests PASSED`)}${' '.repeat(Math.max(0, 38 - String(total).length))}║`);
  } else {
    log('bold', `║  ${col('green', `${passed} passed`)}  ${col('red', `${failed} FAILED`)}  (${total} total)${' '.repeat(Math.max(0, 25 - String(total).length))}║`);
    console.log(col('bold', '║') + col('red', '  Failed assertions:') + col('bold', ' '.repeat(34) + '║'));
    failures.forEach(f => console.log(col('bold', '║') + col('red', '  ' + f.slice(0, 50)) + col('bold', '║')));
  }
  log('bold', '╚══════════════════════════════════════════════════════╝');
  console.log('');

  process.exit(failed > 0 ? 1 : 0);
}

run().catch(err => {
  log('red', `\n❌  Unhandled error: ${err.message}`);
  console.error(err.stack);
  process.exit(1);
});
