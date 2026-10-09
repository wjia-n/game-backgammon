/// Backgammon rules engine. Deterministic, UI-independent.
///
/// Board indexing: points 0..23 map to backgammon points 1..24.
/// White moves 24 -> 1 (index 23 -> 0); Black moves 1 -> 24 (index 0 -> 23).
/// +white / -black checker counts per point.
/// Special locations: from == -1 is the bar, to == 24 is bear-off.
class BgMove {
  final int from; // 0-23, or -1 = from bar
  final int to; // 0-23, or 24 = bear off
  final int die;
  const BgMove(this.from, this.to, this.die);
}

/// Immutable snapshot of engine state, used for Undo.
class BgSnapshot {
  final List<int> points;
  final int whiteBar, blackBar, whiteOff, blackOff;
  final bool whiteTurn;
  final List<int> dice;
  const BgSnapshot({
    required this.points,
    required this.whiteBar,
    required this.blackBar,
    required this.whiteOff,
    required this.blackOff,
    required this.whiteTurn,
    required this.dice,
  });
}

class BgEngine {
  List<int> points = List.filled(24, 0); // +white, -black
  int whiteBar = 0, blackBar = 0;
  int whiteOff = 0, blackOff = 0;
  bool whiteTurn = true;
  List<int> dice = [];

  void reset() {
    points = List.filled(24, 0);
    points[23] = 2;
    points[12] = 5;
    points[7] = 3;
    points[5] = 5;
    points[0] = -2;
    points[11] = -5;
    points[16] = -3;
    points[18] = -5;
    whiteBar = blackBar = whiteOff = blackOff = 0;
    whiteTurn = true;
    dice = [];
  }

  BgSnapshot snapshot() => BgSnapshot(
        points: List<int>.from(points),
        whiteBar: whiteBar,
        blackBar: blackBar,
        whiteOff: whiteOff,
        blackOff: blackOff,
        whiteTurn: whiteTurn,
        dice: List<int>.from(dice),
      );

  void restore(BgSnapshot s) {
    points = List<int>.from(s.points);
    whiteBar = s.whiteBar;
    blackBar = s.blackBar;
    whiteOff = s.whiteOff;
    blackOff = s.blackOff;
    whiteTurn = s.whiteTurn;
    dice = List<int>.from(s.dice);
  }

  /// Number of checkers that must always sum to 15 per side.
  int checkerTotal(bool white) {
    int t = white ? whiteBar + whiteOff : blackBar + blackOff;
    for (final p in points) {
      t += white ? (p > 0 ? p : 0) : (p < 0 ? -p : 0);
    }
    return t;
  }

  bool get _white => whiteTurn;
  int get _bar => _white ? whiteBar : blackBar;
  int _cnt(int i) => _white ? points[i] : -points[i]; // own checkers
  int _foe(int i) => _white ? -points[i] : points[i]; // enemy checkers

  /// Exposed for UI/AI (read-only helpers).
  int ownCount(int i) => _cnt(i);
  int foeCount(int i) => _foe(i);
  int barCount(bool white) => white ? whiteBar : blackBar;
  int offCount(bool white) => white ? whiteOff : blackOff;

  bool allInHome(bool white) {
    final bar = white ? whiteBar : blackBar;
    if (bar > 0) return false;
    for (int i = 0; i < 24; i++) {
      final c = white ? points[i] : -points[i];
      if (c == 0) continue;
      if (white && i > 5) return false;
      if (!white && i < 18) return false;
    }
    return true;
  }

  bool _allInHome() => allInHome(_white);

  /// All legal single-die moves for one die value.
  List<BgMove> movesForDie(int die) {
    final ms = <BgMove>[];
    final dir = _white ? -1 : 1;
    if (_bar > 0) {
      final to = _white ? 24 - die : die - 1;
      if (_foe(to) <= 1) ms.add(BgMove(-1, to, die));
      return ms;
    }
    final home = _allInHome();
    for (int i = 0; i < 24; i++) {
      if (_cnt(i) == 0) continue;
      final to = i + dir * die;
      if (to >= 0 && to < 24) {
        if (_foe(to) <= 1) ms.add(BgMove(i, to, die));
      } else if (home) {
        // bear off
        final need = _white ? i + 1 : 24 - i;
        if (die == need) {
          ms.add(BgMove(i, 24, die));
        } else if (die > need) {
          bool higher = false;
          if (_white) {
            for (int j = i + 1; j < 6; j++) {
              if (_cnt(j) > 0) higher = true;
            }
          } else {
            for (int j = 18; j < i; j++) {
              if (_cnt(j) > 0) higher = true;
            }
          }
          if (!higher) ms.add(BgMove(i, 24, die));
        }
      }
    }
    return ms;
  }

  bool get hasAnyMove => dice.any((d) => movesForDie(d).isNotEmpty);

  void rollDice(List<int> ds) {
    dice = ds[0] == ds[1] ? [ds[0], ds[0], ds[0], ds[0]] : [ds[0], ds[1]];
  }

  /// Applies a move; returns the winner (0 white, 1 black) or -1.
  int doMove(BgMove m) {
    dice.remove(m.die);
    if (m.from == -1) {
      if (_white) {
        whiteBar--;
      } else {
        blackBar--;
      }
    } else {
      points[m.from] += _white ? -1 : 1;
    }
    if (m.to == 24) {
      if (_white) {
        whiteOff++;
        if (whiteOff == 15) return 0;
      } else {
        blackOff++;
        if (blackOff == 15) return 1;
      }
    } else {
      if (_foe(m.to) == 1) {
        // hit the blot!
        if (_white) {
          blackBar++;
        } else {
          whiteBar++;
        }
        points[m.to] = 0;
      }
      points[m.to] += _white ? 1 : -1;
    }
    return -1;
  }

  int pipCount(bool white) {
    int p = 0;
    for (int i = 0; i < 24; i++) {
      final c = white ? points[i] : -points[i];
      if (c > 0) p += c * (white ? i + 1 : 24 - i);
    }
    p += (white ? whiteBar : blackBar) * 25;
    return p;
  }
}
