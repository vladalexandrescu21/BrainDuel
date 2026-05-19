/// Run from the project root:
///   dart run tools/generate_sounds.dart
///
/// Generates all game sound effects as WAV files into app/assets/sounds/.
/// Uses pure mathematical synthesis — no external dependencies needed.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sr = 44100; // sample rate

// ─── Entry point ─────────────────────────────────────────────────────────────

void main() async {
  final dir = Directory('app/assets/sounds');
  if (!await dir.exists()) await dir.create(recursive: true);

  final sounds = <String, List<double>>{
    'tap.wav':           _tap(),
    'correct.wav':       _correct(),
    'wrong.wav':         _wrong(),
    'timer_tick.wav':    _timerTick(),
    'timer_urgent.wav':  _timerUrgent(),
    'match_found.wav':   _matchFound(),
    'win.wav':           _win(),
    'lose.wav':          _lose(),
    'draw.wav':          _draw(),
    'ability.wav':       _ability(),
    'bonus_round.wav':   _bonusRound(),
    'coin.wav':          _coin(),
  };

  for (final entry in sounds.entries) {
    final file = File('app/assets/sounds/${entry.key}');
    await file.writeAsBytes(_toWav(entry.value));
    final ms = (entry.value.length / _sr * 1000).round();
    print('✓ ${entry.key.padRight(20)} ${ms}ms');
  }

  print('\nDone. ${sounds.length} files written to app/assets/sounds/');
}

// ─── Sound definitions ────────────────────────────────────────────────────────

// Quick tap click (UI button)
List<double> _tap() =>
    _sine(800, 55, 0.55, fadeIn: 2, fadeOut: 40);

// Correct answer: rising major arpeggio C5 → E5 → G5
List<double> _correct() => _cat([
      _sine(523.25, 90,  0.65, fadeIn: 3, fadeOut: 15),  // C5
      _sine(659.25, 120, 0.70, fadeIn: 3, fadeOut: 20),  // E5
      _sine(783.99, 250, 0.72, fadeIn: 3, fadeOut: 180), // G5
    ]);

// Wrong answer: descending minor tones
List<double> _wrong() => _cat([
      _sine(311.13, 120, 0.60, fadeIn: 5, fadeOut: 20),  // Eb4
      _sine(277.18, 130, 0.55, fadeIn: 3, fadeOut: 25),  // C#4
      _sine(246.94, 210, 0.48, fadeIn: 3, fadeOut: 170), // B3
    ]);

// Metronome tick (normal timer)
List<double> _timerTick() =>
    _sine(1000, 70, 0.45, fadeIn: 2, fadeOut: 45);

// Double-beep (timer < 3 s left — urgent!)
List<double> _timerUrgent() => _cat([
      _sine(1400, 60, 0.50, fadeIn: 2, fadeOut: 25),
      _silence(30),
      _sine(1400, 60, 0.50, fadeIn: 2, fadeOut: 25),
    ]);

// Match found: C4 E4 G4 → C5 flourish
List<double> _matchFound() => _cat([
      _sine(261.63, 75, 0.60, fadeIn: 3, fadeOut: 10),  // C4
      _sine(329.63, 75, 0.65, fadeIn: 3, fadeOut: 10),  // E4
      _sine(392.00, 75, 0.68, fadeIn: 3, fadeOut: 10),  // G4
      _sine(523.25, 320, 0.72, fadeIn: 5, fadeOut: 230),// C5
    ]);

// Victory fanfare: C5 E5 G5 → C6 long
List<double> _win() => _cat([
      _sine(523.25, 110, 0.65, fadeIn: 3, fadeOut: 12), // C5
      _sine(659.25, 110, 0.68, fadeIn: 3, fadeOut: 12), // E5
      _sine(783.99, 110, 0.70, fadeIn: 3, fadeOut: 12), // G5
      _sine(1046.50, 750, 0.75, fadeIn: 8, fadeOut: 600),// C6
    ]);

// Defeat: descending G4 → F4 → Eb4 → C4
List<double> _lose() => _cat([
      _sine(392.00, 180, 0.58, fadeIn: 5, fadeOut: 20),  // G4
      _sine(349.23, 180, 0.53, fadeIn: 3, fadeOut: 20),  // F4
      _sine(311.13, 180, 0.48, fadeIn: 3, fadeOut: 20),  // Eb4
      _sine(261.63, 370, 0.43, fadeIn: 3, fadeOut: 300), // C4
    ]);

// Draw: held open fifth G4+C4 chord
List<double> _draw() {
  final g4 = _sine(392.00, 720, 0.48, fadeIn: 10, fadeOut: 550);
  final c4 = _sine(261.63, 720, 0.44, fadeIn: 10, fadeOut: 550);
  return _mix(g4, c4);
}

// Ability used: sci-fi frequency sweep up
List<double> _ability() =>
    _sweep(350, 1100, 270, 0.62, fadeIn: 5, fadeOut: 50);

// Bonus round: fast energetic arpeggio E5 G5 B5 D6 → E6
List<double> _bonusRound() => _cat([
      _sine(659.25,  75, 0.65, fadeIn: 2, fadeOut: 8),   // E5
      _sine(783.99,  75, 0.68, fadeIn: 2, fadeOut: 8),   // G5
      _sine(987.77,  75, 0.70, fadeIn: 2, fadeOut: 8),   // B5
      _sine(1174.66, 75, 0.73, fadeIn: 2, fadeOut: 8),   // D6
      _sine(1318.51, 360, 0.75, fadeIn: 5, fadeOut: 290),// E6
    ]);

// Coin reward: C6 → E6 ping
List<double> _coin() => _cat([
      _sine(1046.50, 100, 0.58, fadeIn: 3, fadeOut: 18), // C6
      _sine(1318.51, 140, 0.63, fadeIn: 3, fadeOut: 110),// E6
    ]);

// ─── Synthesis primitives ─────────────────────────────────────────────────────

List<double> _sine(
  double freq,
  double ms,
  double amp, {
  double fadeIn = 5,
  double fadeOut = 30,
}) {
  final n = (_sr * ms / 1000).round();
  final fi = (_sr * fadeIn / 1000).round();
  final fo = (_sr * fadeOut / 1000).round();
  return List.generate(n, (i) {
    double env = 1.0;
    if (i < fi) env = i / fi;
    if (i > n - fo) env = (n - i) / fo;
    return amp * env * sin(2 * pi * freq * i / _sr);
  });
}

List<double> _sweep(
  double f1,
  double f2,
  double ms,
  double amp, {
  double fadeIn = 5,
  double fadeOut = 30,
}) {
  final n = (_sr * ms / 1000).round();
  final fi = (_sr * fadeIn / 1000).round();
  final fo = (_sr * fadeOut / 1000).round();
  double phase = 0.0;
  return List.generate(n, (i) {
    final freq = f1 + (f2 - f1) * (i / n);
    double env = 1.0;
    if (i < fi) env = i / fi;
    if (i > n - fo) env = (n - i) / fo;
    phase += 2 * pi * freq / _sr;
    return amp * env * sin(phase);
  });
}

List<double> _silence(double ms) =>
    List.filled((_sr * ms / 1000).round(), 0.0);

List<double> _cat(List<List<double>> parts) =>
    parts.expand((p) => p).toList();

List<double> _mix(List<double> a, List<double> b) {
  final n = max(a.length, b.length);
  return List.generate(n, (i) {
    final av = i < a.length ? a[i] : 0.0;
    final bv = i < b.length ? b[i] : 0.0;
    return (av + bv).clamp(-1.0, 1.0);
  });
}

// ─── WAV encoder ─────────────────────────────────────────────────────────────

Uint8List _toWav(List<double> samples) {
  final dataBytes = samples.length * 2;
  final buf = ByteData(44 + dataBytes);

  // RIFF header
  buf.setUint32(0, 0x52494646, Endian.big);       // "RIFF"
  buf.setUint32(4, 36 + dataBytes, Endian.little);
  buf.setUint32(8, 0x57415645, Endian.big);        // "WAVE"

  // fmt chunk
  buf.setUint32(12, 0x666D7420, Endian.big);       // "fmt "
  buf.setUint32(16, 16, Endian.little);            // chunk size
  buf.setUint16(20, 1, Endian.little);             // PCM
  buf.setUint16(22, 1, Endian.little);             // mono
  buf.setUint32(24, _sr, Endian.little);           // sample rate
  buf.setUint32(28, _sr * 2, Endian.little);       // byte rate
  buf.setUint16(32, 2, Endian.little);             // block align
  buf.setUint16(34, 16, Endian.little);            // 16-bit

  // data chunk
  buf.setUint32(36, 0x64617461, Endian.big);       // "data"
  buf.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final s = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    buf.setInt16(44 + i * 2, s, Endian.little);
  }

  return buf.buffer.asUint8List();
}
