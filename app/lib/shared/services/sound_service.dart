import 'package:audioplayers/audioplayers.dart';

enum SoundEffect {
  tap('tap.wav'),
  correct('correct.wav'),
  wrong('wrong.wav'),
  timerTick('timer_tick.wav'),
  timerUrgent('timer_urgent.wav'),
  matchFound('match_found.wav'),
  win('win.wav'),
  lose('lose.wav'),
  draw('draw.wav'),
  ability('ability.wav'),
  bonusRound('bonus_round.wav'),
  coin('coin.wav');

  final String filename;
  const SoundEffect(this.filename);
}

class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  bool enabled = true;

  // Dedicated reusable player for the timer tick so we never stack tick sounds.
  final AudioPlayer _tickPlayer = AudioPlayer();

  Future<void> play(SoundEffect effect, {double volume = 1.0}) async {
    if (!enabled) return;
    try {
      if (effect == SoundEffect.timerUrgent || effect == SoundEffect.timerTick) {
        await _tickPlayer.stop();
        await _tickPlayer.setVolume(volume * 0.5);
        await _tickPlayer.play(AssetSource('sounds/${effect.filename}'));
      } else {
        final player = AudioPlayer();
        await player.setVolume(volume);
        await player.play(AssetSource('sounds/${effect.filename}'));
        // Auto-dispose once the sound finishes.
        player.onPlayerComplete.first.then((_) => player.dispose());
      }
    } catch (_) {
      // Fail silently — a missing audio file should never crash the game.
    }
  }

  void dispose() => _tickPlayer.dispose();
}
