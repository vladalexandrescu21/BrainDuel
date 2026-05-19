#!/usr/bin/env node
/**
 * Generates all BrainDuel game sound effects as WAV files.
 * Run from project root: node tools/generate_sounds.js
 */

const fs = require('fs');
const path = require('path');

const SR = 44100; // sample rate
const OUT = path.join(__dirname, '../app/assets/sounds');

if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

// ─── Synthesis primitives ────────────────────────────────────────────────────

function sine(freq, ms, amp, { fadeIn = 5, fadeOut = 30 } = {}) {
  const n = Math.round(SR * ms / 1000);
  const fi = Math.round(SR * fadeIn / 1000);
  const fo = Math.round(SR * fadeOut / 1000);
  const buf = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    let env = 1.0;
    if (i < fi) env = i / fi;
    if (i > n - fo) env = (n - i) / fo;
    buf[i] = amp * env * Math.sin(2 * Math.PI * freq * i / SR);
  }
  return buf;
}

function sweep(f1, f2, ms, amp, { fadeIn = 5, fadeOut = 50 } = {}) {
  const n = Math.round(SR * ms / 1000);
  const fi = Math.round(SR * fadeIn / 1000);
  const fo = Math.round(SR * fadeOut / 1000);
  const buf = new Float64Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const freq = f1 + (f2 - f1) * (i / n);
    let env = 1.0;
    if (i < fi) env = i / fi;
    if (i > n - fo) env = (n - i) / fo;
    phase += 2 * Math.PI * freq / SR;
    buf[i] = amp * env * Math.sin(phase);
  }
  return buf;
}

function silence(ms) {
  return new Float64Array(Math.round(SR * ms / 1000));
}

function cat(...parts) {
  const total = parts.reduce((s, p) => s + p.length, 0);
  const out = new Float64Array(total);
  let offset = 0;
  for (const p of parts) { out.set(p, offset); offset += p.length; }
  return out;
}

function mix(a, b) {
  const n = Math.max(a.length, b.length);
  const out = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const av = i < a.length ? a[i] : 0;
    const bv = i < b.length ? b[i] : 0;
    out[i] = Math.max(-1, Math.min(1, av + bv));
  }
  return out;
}

// ─── WAV encoder ─────────────────────────────────────────────────────────────

function toWav(samples) {
  const dataBytes = samples.length * 2;
  const buf = Buffer.alloc(44 + dataBytes);
  // RIFF header
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + dataBytes, 4);
  buf.write('WAVE', 8);
  // fmt chunk
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);           // PCM
  buf.writeUInt16LE(1, 22);           // mono
  buf.writeUInt32LE(SR, 24);          // sample rate
  buf.writeUInt32LE(SR * 2, 28);      // byte rate
  buf.writeUInt16LE(2, 32);           // block align
  buf.writeUInt16LE(16, 34);          // 16-bit
  // data chunk
  buf.write('data', 36); buf.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767)));
    buf.writeInt16LE(s, 44 + i * 2);
  }
  return buf;
}

// ─── Sound definitions ────────────────────────────────────────────────────────

const sounds = {
  // Quick UI tap / button click
  'tap.wav': sine(800, 55, 0.55, { fadeIn: 2, fadeOut: 40 }),

  // Correct answer: rising major arpeggio C5 → E5 → G5
  'correct.wav': cat(
    sine(523.25, 90,  0.65, { fadeIn: 3, fadeOut: 15 }),
    sine(659.25, 120, 0.70, { fadeIn: 3, fadeOut: 20 }),
    sine(783.99, 260, 0.72, { fadeIn: 3, fadeOut: 180 }),
  ),

  // Wrong answer: descending minor tones
  'wrong.wav': cat(
    sine(311.13, 120, 0.60, { fadeIn: 5, fadeOut: 20 }),
    sine(277.18, 130, 0.55, { fadeIn: 3, fadeOut: 25 }),
    sine(246.94, 220, 0.48, { fadeIn: 3, fadeOut: 170 }),
  ),

  // Metronome tick (used for normal timer)
  'timer_tick.wav': sine(1000, 70, 0.45, { fadeIn: 2, fadeOut: 45 }),

  // Double-beep — last 3 seconds warning
  'timer_urgent.wav': cat(
    sine(1400, 60, 0.50, { fadeIn: 2, fadeOut: 25 }),
    silence(30),
    sine(1400, 60, 0.50, { fadeIn: 2, fadeOut: 25 }),
  ),

  // Match found: C4 E4 G4 → C5 flourish
  'match_found.wav': cat(
    sine(261.63,  75, 0.60, { fadeIn: 3, fadeOut: 10 }),
    sine(329.63,  75, 0.65, { fadeIn: 3, fadeOut: 10 }),
    sine(392.00,  75, 0.68, { fadeIn: 3, fadeOut: 10 }),
    sine(523.25, 320, 0.72, { fadeIn: 5, fadeOut: 230 }),
  ),

  // Victory fanfare: C5 E5 G5 → C6 long hold
  'win.wav': cat(
    sine(523.25,  110, 0.65, { fadeIn: 3, fadeOut: 12 }),
    sine(659.25,  110, 0.68, { fadeIn: 3, fadeOut: 12 }),
    sine(783.99,  110, 0.70, { fadeIn: 3, fadeOut: 12 }),
    sine(1046.50, 750, 0.75, { fadeIn: 8, fadeOut: 600 }),
  ),

  // Defeat: descending G4 → F4 → Eb4 → C4
  'lose.wav': cat(
    sine(392.00, 180, 0.58, { fadeIn: 5, fadeOut: 20 }),
    sine(349.23, 180, 0.53, { fadeIn: 3, fadeOut: 20 }),
    sine(311.13, 180, 0.48, { fadeIn: 3, fadeOut: 20 }),
    sine(261.63, 380, 0.43, { fadeIn: 3, fadeOut: 300 }),
  ),

  // Draw: held open fifth G4 + C4
  'draw.wav': mix(
    sine(392.00, 720, 0.48, { fadeIn: 10, fadeOut: 550 }),
    sine(261.63, 720, 0.44, { fadeIn: 10, fadeOut: 550 }),
  ),

  // Ability used: sci-fi frequency sweep
  'ability.wav': sweep(350, 1100, 270, 0.62, { fadeIn: 5, fadeOut: 50 }),

  // Bonus round: fast energetic arpeggio E5 G5 B5 D6 → E6
  'bonus_round.wav': cat(
    sine( 659.25,  75, 0.65, { fadeIn: 2, fadeOut: 8 }),
    sine( 783.99,  75, 0.68, { fadeIn: 2, fadeOut: 8 }),
    sine( 987.77,  75, 0.70, { fadeIn: 2, fadeOut: 8 }),
    sine(1174.66,  75, 0.73, { fadeIn: 2, fadeOut: 8 }),
    sine(1318.51, 360, 0.75, { fadeIn: 5, fadeOut: 290 }),
  ),

  // Coin / reward ping: C6 → E6
  'coin.wav': cat(
    sine(1046.50, 100, 0.58, { fadeIn: 3, fadeOut: 18 }),
    sine(1318.51, 140, 0.63, { fadeIn: 3, fadeOut: 110 }),
  ),
};

// ─── Write files ─────────────────────────────────────────────────────────────

for (const [name, samples] of Object.entries(sounds)) {
  const outPath = path.join(OUT, name);
  fs.writeFileSync(outPath, toWav(samples));
  const ms = Math.round(samples.length / SR * 1000);
  console.log(`✓ ${name.padEnd(22)} ${ms}ms`);
}

console.log(`\nDone. ${Object.keys(sounds).length} files → app/assets/sounds/`);
