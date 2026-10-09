import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central audio for Backgammon: oud-flavoured procedural SFX + looping music,
/// with persisted music/SFX toggles and separate volume sliders.
class BgAudio {
  BgAudio._();
  static final BgAudio instance = BgAudio._();

  final AudioPlayer _music = AudioPlayer();

  bool musicOn = true;
  bool sfxOn = true;
  double musicVolume = 0.7;
  double sfxVolume = 0.8;
  bool _ready = false;
  String? _currentTrack;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool('bg_music') ?? true;
    sfxOn = p.getBool('bg_sfx') ?? true;
    musicVolume = p.getDouble('bg_music_vol') ?? 0.7;
    sfxVolume = p.getDouble('bg_sfx_vol') ?? 0.8;
    await _music.setReleaseMode(ReleaseMode.loop);
    _ready = true;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bg_music', musicOn);
    await p.setBool('bg_sfx', sfxOn);
    await p.setDouble('bg_music_vol', musicVolume);
    await p.setDouble('bg_sfx_vol', sfxVolume);
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    await _save();
    if (!v) {
      _currentTrack = null;
      try {
        await _music.stop();
      } catch (_) {}
    }
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    await _save();
  }

  Future<void> setMusicVolume(double v) async {
    musicVolume = v.clamp(0.0, 1.0);
    await _save();
    try {
      await _music.setVolume(musicVolume * 0.7);
    } catch (_) {}
  }

  Future<void> setSfxVolume(double v) async {
    sfxVolume = v.clamp(0.0, 1.0);
    await _save();
  }

  Future<void> playMusic(String asset) async {
    if (!musicOn) return;
    if (_currentTrack == asset) return;
    _currentTrack = asset;
    try {
      await _music.setVolume(musicVolume * 0.7);
      await _music.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  /// One-shot SFX on a throwaway player so rapid sounds can overlap.
  Future<void> _play(String asset, {double vol = 1.0}) async {
    if (!sfxOn) return;
    try {
      final p = AudioPlayer();
      await p.setVolume((sfxVolume * vol).clamp(0.0, 1.0));
      p.onPlayerComplete.listen((_) {
        p.dispose();
      });
      await p.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> click() => _play('audio/click.wav', vol: 0.8);
  Future<void> dice() => _play('audio/dice_rattle.wav');
  Future<void> slide() => _play('audio/checker_slide.wav');
  Future<void> hit() => _play('audio/hit.wav');
  Future<void> bearOff() => _play('audio/bearoff.wav');
  Future<void> invalid() => _play('audio/invalid.wav', vol: 0.7);
  Future<void> doubleTurn() => _play('audio/double.wav');
  Future<void> start() => _play('audio/start.wav');
  Future<void> win() => _play('audio/win.wav');
  Future<void> lose() => _play('audio/lose.wav');

  void dispose() {
    _music.dispose();
  }
}
