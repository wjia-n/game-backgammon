import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + match tally for Backgammon.
class BgSettings {
  BgSettings._();
  static final BgSettings instance = BgSettings._();

  /// 0 = easy, 1 = medium, 2 = hard
  int difficulty = 1;

  /// 0 = walnut, 1 = ebony
  int boardTheme = 0;

  /// Match target points (5, 7 or 11)
  int matchLength = 5;

  int whiteMatch = 0;
  int blackMatch = 0;
  int gamesPlayed = 0;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    difficulty = p.getInt('bg_difficulty') ?? 1;
    boardTheme = p.getInt('bg_board_theme') ?? 0;
    matchLength = p.getInt('bg_match_length') ?? 5;
    whiteMatch = p.getInt('bg_white_match') ?? 0;
    blackMatch = p.getInt('bg_black_match') ?? 0;
    gamesPlayed = p.getInt('bg_games_played') ?? 0;
    _ready = true;
  }

  Future<void> setDifficulty(int v) async {
    difficulty = v.clamp(0, 2);
    (await SharedPreferences.getInstance()).setInt('bg_difficulty', difficulty);
  }

  Future<void> setBoardTheme(int v) async {
    boardTheme = v.clamp(0, 1);
    (await SharedPreferences.getInstance()).setInt('bg_board_theme', boardTheme);
  }

  Future<void> setMatchLength(int v) async {
    matchLength = v;
    (await SharedPreferences.getInstance()).setInt('bg_match_length', matchLength);
  }

  /// Adds points to the match tally. Returns true if the match is decided.
  Future<bool> recordGame(bool whiteWon, int points) async {
    final p = await SharedPreferences.getInstance();
    if (whiteWon) {
      whiteMatch += points;
      await p.setInt('bg_white_match', whiteMatch);
    } else {
      blackMatch += points;
      await p.setInt('bg_black_match', blackMatch);
    }
    gamesPlayed++;
    await p.setInt('bg_games_played', gamesPlayed);
    return whiteMatch >= matchLength || blackMatch >= matchLength;
  }

  Future<void> resetMatch() async {
    final p = await SharedPreferences.getInstance();
    whiteMatch = 0;
    blackMatch = 0;
    await p.setInt('bg_white_match', 0);
    await p.setInt('bg_black_match', 0);
  }

  static const difficulties = ['Easy', 'Medium', 'Hard'];
  static const themes = ['Walnut', 'Ebony'];
  static const matchLengths = [5, 7, 11];
}
