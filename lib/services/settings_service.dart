import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/backgammon_themes.dart';

/// Persisted settings + stats for Backgammon. Survives app restarts.
///
/// Stores: audio toggles, player names (2 slots: White, Black), theme and
/// appearance choices (incl. custom theme colors), mode setup (vs bot with
/// difficulty, or pass-and-play), match length, Pro unlock state, and
/// lifetime stats.
class SultanSettings extends ChangeNotifier {
  static const _kMusic = 'bg_music_on';
  static const _kSfx = 'bg_sfx_on';
  static const _kVolume = 'bg_volume';
  static const _kMode = 'bg_mode'; // 0 = vs bot, 1 = two players
  static const _kDifficulty = 'bg_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kMatch = 'bg_match_length'; // 1, 5, 7, 11
  static const _kNames = 'bg_player_names'; // StringList, [white, black]
  static const _kTheme = 'bg_theme_id';
  static const _kChecker = 'bg_checker_style';
  static const _kDice = 'bg_dice_style';
  static const _kPoints = 'bg_point_style';
  static const _kWins = 'bg_wins';
  static const _kGames = 'bg_games_played';
  static const _kBest = 'bg_best_match'; // fewest games to win a match
  static const _kIsPro = 'bg_is_pro';
  static const _kCustomPrefix = 'bg_custom_';

  static const defaultNames = ['You', 'Sultan Bot'];

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int mode = 0;
  int difficulty = 1; // medium default
  int matchLength = 1;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'walnut';
  int checkerStyle = 0;
  int diceStyle = 0;
  int pointStyle = 0;
  int wins = 0;
  int gamesPlayed = 0;
  int bestMatch = 0;
  bool isPro = false;

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'woodDark': 0xFF3B2417,
    'woodMid': 0xFF5C3A21,
    'woodDeep': 0xFF1A0F08,
    'accent': 0xFFB08D3E,
    'accentLight': 0xFFD9B96A,
    'accentDark': 0xFF7A6128,
    'ivory': 0xFFEDE4D3,
    'felt': 0xFF2E4A38,
    'pointLight': 0xFFE8D9B8,
    'pointDark': 0xFF7A4A2E,
    'checkerWhite': 0xFFEDE4D3,
    'checkerBlack': 0xFF3A2418,
  };

  SultanThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return SultanThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      woodDeep: c('woodDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      felt: c('felt'),
      pointLight: c('pointLight'),
      pointDark: c('pointDark'),
      checkerWhite: c('checkerWhite'),
      checkerBlack: c('checkerBlack'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    matchLength = p.getInt(_kMatch) ?? 1;
    if (![1, 5, 7, 11].contains(matchLength)) matchLength = 1;
    final names = p.getStringList(_kNames);
    if (names != null && names.length == 2) {
      playerNames = [
        for (int i = 0; i < 2; i++)
          names[i].trim().isEmpty ? defaultNames[i] : names[i].trim()
      ];
    }
    themeId = p.getString(_kTheme) ?? 'walnut';
    checkerStyle = (p.getInt(_kChecker) ?? 0).clamp(0, CheckerStyles.count - 1);
    diceStyle = (p.getInt(_kDice) ?? 0).clamp(0, DiceStyles.count - 1);
    pointStyle = (p.getInt(_kPoints) ?? 0).clamp(0, 2);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestMatch = p.getInt(_kBest) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMatch, matchLength);
    await p.setStringList(_kNames, playerNames);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kChecker, checkerStyle);
    await p.setInt(_kDice, diceStyle);
    await p.setInt(_kPoints, pointStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBest, bestMatch);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (SultanThemes.isProTheme(themeId)) {
      themeId = 'walnut';
      changed = true;
    }
    if (CheckerStyles.isPro(checkerStyle)) {
      checkerStyle = 0;
      changed = true;
    }
    if (DiceStyles.isPro(diceStyle)) {
      diceStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // Hard is a Pro feature.
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMatchLength(int v) async {
    matchLength = [1, 5, 7, 11].contains(v) ? v : 1;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && SultanThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCheckerStyle(int v) async {
    v = v.clamp(0, CheckerStyles.count - 1);
    if (!isPro && CheckerStyles.isPro(v)) return;
    checkerStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDiceStyle(int v) async {
    v = v.clamp(0, DiceStyles.count - 1);
    if (!isPro && DiceStyles.isPro(v)) return;
    diceStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPointStyle(int v) async {
    pointStyle = v.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won the game.
  Future<void> recordGame({required bool humanWon}) async {
    gamesPlayed++;
    if (humanWon) wins++;
    notifyListeners();
    await _save();
  }
}
