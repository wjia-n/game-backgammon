/// Backgammon engine: pure rules, AI, and the engine-owned turn state machine.
///
/// Board indexing: points 0..23 map to backgammon points 1..24.
/// White moves 24 -> 1 (index 23 -> 0); Black moves 1 -> 24 (index 0 -> 23).
/// +white / -black checker counts per point.
/// Special locations: from == -1 is the bar, to == 24 is bear-off.
///
/// The turn state machine is owned HERE (never by UI timers):
///   rollOff -> awaitingDecision -> diceRolling -> awaitingMoves/botActing
///   -> animating -> awaitingDecision ... -> gameOver
/// A watchdog ([_watchdog]) periodically verifies every phase has a live
/// timer or a human pending on it; any orphaned phase is recovered.
/// Stuck states are impossible by construction.
library;

import 'dart:async';
import 'dart:math';

/// A single checker move. from == -1 means the move starts on the bar,
/// to == 24 means the checker bears off.
class BgMove {
  final int from;
  final int to;
  final int die;
  const BgMove(this.from, this.to, this.die);

  @override
  String toString() => 'BgMove($from -> $to, d$die)';

  @override
  bool operator ==(Object other) =>
      other is BgMove &&
          other.from == from &&
          other.to == to &&
          other.die == die;

  @override
  int get hashCode => Object.hash(from, to, die);
}

/// Mutable board position. Clone before speculative play.
class BgPosition {
  List<int> points = List.filled(24, 0); // +white, -black
  int whiteBar = 0, blackBar = 0;
  int whiteOff = 0, blackOff = 0;

  BgPosition();

  BgPosition.initial() {
    points[23] = 2; // 24-point
    points[12] = 5; // 13-point
    points[7] = 3; // 8-point
    points[5] = 5; // 6-point
    points[0] = -2; // 1-point
    points[11] = -5; // 12-point
    points[16] = -3; // 17-point
    points[18] = -5; // 19-point
  }

  BgPosition clone() {
    final p = BgPosition();
    p.points = List<int>.from(points);
    p.whiteBar = whiteBar;
    p.blackBar = blackBar;
    p.whiteOff = whiteOff;
    p.blackOff = blackOff;
    return p;
  }

  void copyFrom(BgPosition other) {
    points = List<int>.from(other.points);
    whiteBar = other.whiteBar;
    blackBar = other.blackBar;
    whiteOff = other.whiteOff;
    blackOff = other.blackOff;
  }
}

/// Doubling cube state.
class BgCube {
  int value = 1; // 1, 2, 4, 8, 16, 32, 64
  int owner = -1; // -1 centered, 0 white, 1 black
  BgCube();
  BgCube.cloneOf(BgCube o) {
    value = o.value;
    owner = o.owner;
  }

  BgCube clone() => BgCube.cloneOf(this);
}

/// Result of a finished game.
class BgResult {
  final int points;
  final String kind; // 'single' | 'gammon' | 'backgammon' | 'double-decline'
  const BgResult(this.points, this.kind);
}

// ---------------------------------------------------------------------------
// Pure rules
// ---------------------------------------------------------------------------

class BgRules {
  static int _own(BgPosition p, bool white, int i) =>
      white ? p.points[i] : -p.points[i];
  static int _foe(BgPosition p, bool white, int i) =>
      white ? -p.points[i] : p.points[i];
  static int _bar(BgPosition p, bool white) => white ? p.whiteBar : p.blackBar;

  /// Read-only helpers for UI/AI.
  static int ownCount(BgPosition p, bool white, int i) => _own(p, white, i);
  static int foeCount(BgPosition p, bool white, int i) => _foe(p, white, i);
  static int barCount(BgPosition p, bool white) => _bar(p, white);
  static int offCount(BgPosition p, bool white) =>
      white ? p.whiteOff : p.blackOff;

  /// Every checker must always be on the board, the bar, or borne off.
  static bool invariantHolds(BgPosition p) {
    int w = p.whiteBar + p.whiteOff, b = p.blackBar + p.blackOff;
    for (final c in p.points) {
      if (c > 0) {
        w += c;
      } else {
        b += -c;
      }
    }
    return w == 15 && b == 15;
  }

  static bool allInHome(BgPosition p, bool white) {
    if (_bar(p, white) > 0) return false;
    for (int i = 0; i < 24; i++) {
      final c = _own(p, white, i);
      if (c <= 0) continue; // empty or opponent's checkers
      if (white && i > 5) return false;
      if (!white && i < 18) return false;
    }
    return true;
  }

  /// All legal single-die moves for one die value.
  static List<BgMove> movesForDie(BgPosition p, bool white, int die) {
    final ms = <BgMove>[];
    final dir = white ? -1 : 1;
    if (_bar(p, white) > 0) {
      final to = white ? 24 - die : die - 1;
      if (_foe(p, white, to) <= 1) ms.add(BgMove(-1, to, die));
      return ms;
    }
    final home = allInHome(p, white);
    for (int i = 0; i < 24; i++) {
      if (_own(p, white, i) <= 0) continue; // empty or opponent's point
      final to = i + dir * die;
      if (to >= 0 && to < 24) {
        if (_foe(p, white, to) <= 1) ms.add(BgMove(i, to, die));
      } else if (home) {
        final need = white ? i + 1 : 24 - i;
        if (die == need) {
          ms.add(BgMove(i, 24, die));
        } else if (die > need) {
          // Bear off from the highest occupied point only when nothing
          // sits on a higher point.
          bool higher = false;
          if (white) {
            for (int j = i + 1; j < 6 && !higher; j++) {
              if (_own(p, white, j) > 0) higher = true;
            }
          } else {
            for (int j = i + 1; j < 24 && !higher; j++) {
              if (_own(p, white, j) > 0) higher = true;
            }
          }
          if (!higher) ms.add(BgMove(i, 24, die));
        }
      }
    }
    return ms;
  }

  /// All legal move SEQUENCES for the rolled dice, enforcing:
  /// - the maximum-moves rule (use as many dice as legally possible),
  /// - the forced-higher-die rule (only one playable -> the higher die).
  /// Both dice orders are tried; every intermediate step is legality-checked
  /// (hits, blocked intermediate points, bar priority, bear-off rules).
  static List<List<BgMove>> legalSequences(
      BgPosition pos, bool white, List<int> dice) {
    final seqs = <List<BgMove>>[];
    if (dice.isEmpty) return seqs;
    if (dice.length == 1) {
      for (final m in movesForDie(pos, white, dice[0])) {
        seqs.add([m]);
      }
    } else {
      final orders = <List<int>>[];
      if (dice.length == 2 && dice[0] != dice[1]) {
        orders.add([dice[0], dice[1]]);
        orders.add([dice[1], dice[0]]);
      } else {
        orders.add(List<int>.from(dice)); // doubles: one ordering
      }
      for (final order in orders) {
        _gen(pos.clone(), white, order, 0, <BgMove>[], seqs);
      }
    }
    if (seqs.isEmpty) return seqs;
    // Maximum-moves rule.
    var maxLen = 0;
    for (final s in seqs) {
      if (s.length > maxLen) maxLen = s.length;
    }
    var best = seqs.where((s) => s.length == maxLen).toList();
    // Forced higher die: only one of two distinct dice playable.
    if (maxLen == 1 && dice.length == 2 && dice[0] != dice[1]) {
      final hi = max(dice[0], dice[1]);
      final hiSeqs = best.where((s) => s[0].die == hi).toList();
      if (hiSeqs.isNotEmpty) best = hiSeqs;
    }
    return best;
  }

  static void _gen(BgPosition p, bool white, List<int> dice, int k,
      List<BgMove> cur, List<List<BgMove>> out) {
    if (k >= dice.length) {
      if (cur.isNotEmpty) out.add(List<BgMove>.of(cur));
      return;
    }
    final moves = movesForDie(p, white, dice[k]);
    if (moves.isEmpty) {
      // Dead die: forfeited, continue with the rest.
      _gen(p, white, dice, k + 1, cur, out);
      return;
    }
    for (final m in moves) {
      final np = p.clone();
      applyMove(np, white, m);
      cur.add(m);
      _gen(np, white, dice, k + 1, cur, out);
      cur.removeLast();
    }
  }

  /// Applies a move. Returns true if a blot was hit.
  static bool applyMove(BgPosition p, bool white, BgMove m) {
    bool hit = false;
    if (m.from == -1) {
      if (white) {
        p.whiteBar--;
      } else {
        p.blackBar--;
      }
    } else {
      p.points[m.from] += white ? -1 : 1;
    }
    if (m.to == 24) {
      if (white) {
        p.whiteOff++;
      } else {
        p.blackOff++;
      }
    } else {
      if (_foe(p, white, m.to) == 1) {
        hit = true;
        if (white) {
          p.blackBar++;
        } else {
          p.whiteBar++;
        }
        p.points[m.to] = 0;
      }
      p.points[m.to] += white ? 1 : -1;
    }
    assert(invariantHolds(p), 'checker invariant broken by $m');
    return hit;
  }

  static int pipCount(BgPosition p, bool white) {
    int total = 0;
    for (int i = 0; i < 24; i++) {
      final c = _own(p, white, i);
      if (c > 0) total += c * (white ? i + 1 : 24 - i);
    }
    total += _bar(p, white) * 25;
    return total;
  }

  /// Number of opponent direct-shot dice values that hit the blot at [idx].
  static int blotExposure(BgPosition p, bool white, int idx) {
    int n = 0;
    final dir = white ? 1 : -1; // opponent moves opposite
    for (int d = 1; d <= 6; d++) {
      final from = idx - dir * d;
      if (from < 0 || from >= 24) continue;
      if (_foe(p, white, from) <= 0) continue; // no enemy checker there
      // Path check: the intermediate landing must be the blot itself for a
      // direct shot (single-die hit).
      n++;
      if (n >= 6) break;
    }
    return n;
  }

  static BgResult scoreGame(BgPosition p, bool whiteWon, int cubeValue) {
    final loserOff = whiteWon ? p.blackOff : p.whiteOff;
    final loserBar = whiteWon ? p.blackBar : p.whiteBar;
    bool loserInWinnersHome = false;
    final homeLo = whiteWon ? 0 : 18, homeHi = whiteWon ? 5 : 23;
    for (int i = homeLo; i <= homeHi; i++) {
      if (_own(p, !whiteWon, i) > 0) {
        loserInWinnersHome = true;
        break;
      }
    }
    if (loserOff > 0) return BgResult(1 * cubeValue, 'single');
    if (loserBar > 0 || loserInWinnersHome) {
      return BgResult(3 * cubeValue, 'backgammon');
    }
    return BgResult(2 * cubeValue, 'gammon');
  }

  /// Point-name for narration, e.g. "the 5-point" (1-24 numbering).
  static String pointName(int idx) => 'the ${idx + 1}-point';
}

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------

/// Difficulty: 0 easy, 1 medium, 2 hard.
class BgAi {
  static final Random _rnd = Random();

  /// Opening book (white coordinates, point numbers 1-24): dice key ->
  /// preferred first-two-move signatures as "from>to,from>to".
  static const Map<String, List<String>> _book = {
    '1-3': ['8>5,6>5'],
    '1-6': ['13>7,8>7'],
    '2-4': ['8>4,6>4'],
    '4-6': ['8>2,6>2', '24>18,13>7'],
    '2-6': ['24>18,13>11'],
    '3-6': ['24>18,13>10'],
    '4-5': ['13>9,13>8'],
    '5-6': ['24>13'],
    '3-4': ['13>10,13>9'],
    '3-5': ['8>3,6>3'],
    '1-5': ['13>8,6>5'],
    '1-4': ['13>9,6>5'],
    '2-3': ['13>11,13>10'],
    '1-2': ['13>11,6>5'],
    '2-5': ['24>22,13>8'],
    '6-6': ['24>18,24>18,13>7,13>7'],
  };

  static String _bookKey(List<int> dice) {
    final ds = dice.toSet().toList()..sort();
    return ds.join('-');
  }

  static String _sig(List<BgMove> seq) {
    final parts = seq
        .take(2)
        .map((m) =>
            '${m.from == -1 ? 25 : m.from + 1}>${m.to == 24 ? 0 : m.to + 1}')
        .join(',');
    return parts;
  }

  static String _mirrorSig(String sig) {
    // Mirror white point numbers to black coordinates.
    return sig.split(',').map((pair) {
      final ab = pair.split('>');
      int f = int.parse(ab[0]), t = int.parse(ab[1]);
      f = f == 25 ? 25 : 25 - f;
      t = t == 0 ? 0 : 25 - t;
      return '$f>$t';
    }).join(',');
  }

  static double _bookBonus(
      BgPosition pos, bool white, List<int> dice, List<BgMove> seq) {
    final entries = _book[_bookKey(dice)];
    if (entries == null || seq.length < 2) return 0;
    final sig = _sig(seq);
    for (final e in entries) {
      if (white && sig == e) return 6.0;
      if (!white && sig == _mirrorSig(e)) return 6.0;
    }
    return 0;
  }

  /// Heuristic evaluation from [white]'s perspective. Higher is better.
  static double evaluate(BgPosition p, bool white) {
    double s = 0;
    final myPip = BgRules.pipCount(p, white);
    final opPip = BgRules.pipCount(p, !white);
    s += (opPip - myPip) * 1.0;
    for (int i = 0; i < 24; i++) {
      final my = BgRules.ownCount(p, white, i);
      final op = BgRules.foeCount(p, white, i);
      if (my >= 2) {
        s += 3.0;
        final pt = i + 1;
        // Key points: the 5-point, 4-point and bar-point (7-point) —
        // mirrored for black.
        final key = white
            ? (pt == 5 || pt == 4 || pt == 7)
            : (pt == 20 || pt == 21 || pt == 18);
        if (key) s += 2.5;
        final inHome = white ? pt <= 6 : pt >= 19;
        if (inHome) s += 1.0;
      } else if (my == 1) {
        final exposure = BgRules.blotExposure(p, white, i);
        s -= 1.2 + exposure * 0.9;
      }
      if (op >= 2) {
        // Opponent made points slightly bad for us.
        s -= 0.6;
      }
    }
    s -= BgRules.barCount(p, white) * 9.0;
    s += BgRules.barCount(p, !white) * 7.0;
    s += BgRules.offCount(p, white) * 5.0;
    s -= BgRules.offCount(p, !white) * 5.0;
    return s;
  }

  static double _applyEval(
      BgPosition p, bool white, List<BgMove> seq, List<int> dice) {
    final np = p.clone();
    for (final m in seq) {
      BgRules.applyMove(np, white, m);
    }
    return evaluate(np, white);
  }

  /// Choose a full move sequence for the bot.
  static List<BgMove> chooseSequence(
    BgPosition pos,
    bool white,
    List<List<BgMove>> seqs,
    List<int> dice,
    int difficulty, {
    bool isOpening = false,
    Random? rnd,
  }) {
    rnd ??= _rnd;
    if (seqs.isEmpty) return const [];
    if (seqs.length == 1) return seqs.first;
    switch (difficulty) {
      case 0: // Easy: 40% random, otherwise noisy shallow heuristic, never doubles.
        if (rnd.nextDouble() < 0.4) {
          return seqs[rnd.nextInt(seqs.length)];
        }
        return _bestOf(pos, white, seqs, dice, noise: 6.0, rnd: rnd,
            book: false, isOpening: isOpening);
      case 2: // Hard: 2-ply expected value over the 21 dice outcomes.
        return _bestTwoPly(pos, white, seqs, dice, rnd: rnd);
      case 1:
      default: // Medium: 1-ply full heuristic + light noise + opening book.
        return _bestOf(pos, white, seqs, dice, noise: 1.2, rnd: rnd,
            book: true, isOpening: isOpening);
    }
  }

  static List<BgMove> _bestOf(
    BgPosition pos,
    bool white,
    List<List<BgMove>> seqs,
    List<int> dice, {
    required double noise,
    required Random rnd,
    required bool book,
    required bool isOpening,
  }) {
    List<BgMove> best = seqs.first;
    var bestScore = double.negativeInfinity;
    for (final seq in seqs) {
      var sc = _applyEval(pos, white, seq, dice);
      if (book && isOpening) sc += _bookBonus(pos, white, dice, seq);
      sc += (rnd.nextDouble() * 2 - 1) * noise;
      if (sc > bestScore) {
        bestScore = sc;
        best = seq;
      }
    }
    return best;
  }

  static const List<List<int>> _diceOutcomes = [
    [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], // doubles, weight 1
    [1, 2], [1, 3], [1, 4], [1, 5], [1, 6],
    [2, 3], [2, 4], [2, 5], [2, 6],
    [3, 4], [3, 5], [3, 6],
    [4, 5], [4, 6],
    [5, 6],
  ];

  static List<BgMove> _bestTwoPly(
    BgPosition pos,
    bool white,
    List<List<BgMove>> seqs,
    List<int> dice, {
    required Random rnd,
  }) {
    // Rank by 1-ply, keep the top candidates, then expected value over the
    // opponent's 21 dice outcomes (opponent replies with 1-ply best).
    final ranked = seqs.toList()
      ..sort((a, b) => _applyEval(pos, white, b, dice)
          .compareTo(_applyEval(pos, white, a, dice)));
    final candidates = ranked.take(4).toList();
    List<BgMove> best = candidates.first;
    var bestEv = double.negativeInfinity;
    for (final seq in candidates) {
      final np = pos.clone();
      for (final m in seq) {
        BgRules.applyMove(np, white, m);
      }
      double ev = 0, wsum = 0;
      for (final od in _diceOutcomes) {
        final w = od[0] == od[1] ? 1.0 : 2.0; // 36-outcome weighting
        final oppDice = od[0] == od[1]
            ? [od[0], od[0], od[0], od[0]]
            : [od[0], od[1]];
        final replies = BgRules.legalSequences(np, !white, oppDice);
        double replyVal;
        if (replies.isEmpty) {
          replyVal = evaluate(np, white);
        } else {
          replyVal = double.negativeInfinity;
          for (final r in replies.take(8)) {
            final rp = np.clone();
            for (final m in r) {
              BgRules.applyMove(rp, !white, m);
            }
            final v = evaluate(rp, white);
            if (v > replyVal) replyVal = v;
          }
        }
        ev += replyVal * w;
        wsum += w;
      }
      ev /= wsum;
      if (ev > bestEv) {
        bestEv = ev;
        best = seq;
      }
    }
    return best;
  }

  /// Rough winning-chance estimate from the evaluation (logistic squash).
  static double winChance(BgPosition p, bool white) {
    final e = evaluate(p, white);
    return 1.0 / (1.0 + exp(-e / 18.0));
  }

  /// Should the bot offer the doubling cube now?
  static bool shouldDouble(
      BgPosition p, bool white, int difficulty, BgCube cube, bool crawford) {
    if (crawford || difficulty == 0) return false;
    if (cube.value >= 64) return false;
    final owned = cube.owner == -1 ||
        cube.owner == (white ? 0 : 1);
    if (!owned) return false;
    final wc = winChance(p, white);
    if (difficulty == 1) {
      // Medium: double only clearly ahead.
      final pipLead =
          BgRules.pipCount(p, !white) - BgRules.pipCount(p, white);
      return wc >= 0.68 && pipLead >= 12;
    }
    // Hard: double when winning chance is high and opponent's take doubtful.
    return wc >= 0.66;
  }

  /// Should the bot accept a double?
  static bool shouldTake(
      BgPosition p, bool white, int difficulty, BgCube cube) {
    final wc = winChance(p, white);
    if (difficulty == 0) {
      // Easy: accepts only if clearly ahead on pips.
      return BgRules.pipCount(p, white) <
          BgRules.pipCount(p, !white) - 10;
    }
    if (difficulty == 1) {
      return wc >= 0.30;
    }
    return wc >= 0.25; // Hard: standard take threshold.
  }
}

// ---------------------------------------------------------------------------
// Game controller: engine-owned turn state machine + watchdog
// ---------------------------------------------------------------------------

enum BgPhase {
  rollOff,
  awaitingDecision, // roll the dice or offer the cube
  diceRolling,
  awaitingMoves, // human is choosing moves
  botActing, // bot is thinking/playing
  animating, // a move/checker animation is playing
  doubleOffer, // waiting for the opponent's take/pass
  gameOver,
}

class BgPlayer {
  String name;
  final bool isBot;
  final int difficulty; // 0 easy, 1 medium, 2 hard
  BgPlayer({required this.name, required this.isBot, this.difficulty = 1});
}

/// Events the UI subscribes to for narration and audio.
class BgEvent {
  final String kind;
  // 'roll' | 'move' | 'hit' | 'bearoff' | 'nomove' | 'turn' | 'double-offer'
  // | 'double-take' | 'double-pass' | 'game' | 'info' | 'reenter'
  final String message;
  final BgMove? move;
  const BgEvent(this.kind, this.message, [this.move]);
}

class _Snapshot {
  final BgPosition pos;
  final BgCube cube;
  final bool whiteTurn;
  final List<int> dice;
  _Snapshot(this.pos, this.cube, this.whiteTurn, this.dice);
}

class BgGame {
  final List<BgPlayer> players; // [white, black]
  final int matchLength; // 1 = single game
  final List<int> matchScore = [0, 0];
  final Random rnd;

  BgPosition pos = BgPosition.initial();
  BgCube cube = BgCube();
  bool crawford = false;
  bool whiteTurn = true;

  BgPhase phase = BgPhase.rollOff;
  List<int> dice = []; // rolled values (expanded for doubles)
  List<int> remainingDice = [];
  List<List<BgMove>> currentSeqs = []; // maximal legal sequences
  List<BgMove> botPlan = []; // bot's chosen sequence, played step by step
  BgMove? animMove; // move currently animating
  bool animHit = false;
  int moveNumber = 0; // moves made this game (for opening book)
  BgResult? lastResult;
  bool lastWinnerWhite = true;
  bool gameOver = false;

  // Roll-off state.
  int rollOffWhite = 0, rollOffBlack = 0;

  void Function()? onUpdate;
  void Function(BgEvent)? onEvent;

  Timer? _phaseTimer; // the single live phase-transition timer
  Timer? _watchdog;
  _Snapshot? _undoSnap;
  bool _disposed = false;
  int _doubleResponder = -1; // side index asked to take/pass

  BgGame({
    required this.players,
    this.matchLength = 1,
    Random? rnd,
  }) : rnd = rnd ?? Random();

  bool get white => whiteTurn;
  BgPlayer get current => players[whiteTurn ? 0 : 1];
  BgPlayer get other => players[whiteTurn ? 1 : 0];

  // ------------------------------------------------------------ lifecycle
  void start() {
    _watchdog =
        Timer.periodic(const Duration(seconds: 2), (_) => _recover());
    newGame();
  }

  void dispose() {
    _disposed = true;
    _phaseTimer?.cancel();
    _watchdog?.cancel();
  }

  void _after(Duration d, void Function() fn) {
    _phaseTimer?.cancel();
    if (_disposed || paused) {
      // Paused: the watchdog kick on resume() will recover the phase.
      _phaseTimer = null;
      return;
    }
    _phaseTimer = Timer(d, () {
      _phaseTimer = null;
      if (_disposed) return;
      fn();
    });
  }

  /// Pause/resume: freezes all engine timers; resume() re-kicks the phase.
  bool paused = false;

  void setPaused(bool v) {
    if (v == paused || _disposed) return;
    paused = v;
    if (v) {
      _phaseTimer?.cancel();
      _phaseTimer = null;
    } else {
      _recover();
    }
    onUpdate?.call();
  }

  /// Watchdog: every phase must have a live timer or a human pending on it.
  /// Any orphaned phase is kicked forward; the invariant is re-checked.
  void _recover() {
    if (_disposed || gameOver || paused) return;
    if (!BgRules.invariantHolds(pos)) {
      // Should never happen; restore the last snapshot rather than continue
      // with an impossible position.
      if (_undoSnap != null) _restore(_undoSnap!);
    }
    switch (phase) {
      case BgPhase.diceRolling:
        if (_phaseTimer == null) _resolveDice();
        break;
      case BgPhase.awaitingMoves:
        if (current.isBot && _phaseTimer == null) {
          phase = BgPhase.botActing;
          _botChoose();
        } else if (_phaseTimer == null && currentSeqs.isEmpty) {
          _endTurn();
        }
        break;
      case BgPhase.botActing:
        if (_phaseTimer == null) _botStep();
        break;
      case BgPhase.animating:
        if (_phaseTimer == null) {
          if (animMove != null) {
            _finishAnim();
          } else if (currentSeqs.isEmpty) {
            // Commit happened but the follow-up was lost (e.g. pause).
            _endTurn();
          } else {
            phase = current.isBot ? BgPhase.botActing : BgPhase.awaitingMoves;
            if (current.isBot) _botStep();
          }
        }
        break;
      case BgPhase.awaitingDecision:
        if (current.isBot && _phaseTimer == null) _botStartTurn();
        break;
      case BgPhase.doubleOffer:
        if (_phaseTimer == null && _doubleResponder >= 0) {
          _askDouble(_doubleResponder);
        }
        break;
      case BgPhase.rollOff:
        if (_phaseTimer == null) _doRollOff();
        break;
      case BgPhase.gameOver:
        break;
    }
    onUpdate?.call();
  }

  // ------------------------------------------------------------ game flow
  void newGame() {
    pos = BgPosition.initial();
    cube = BgCube();
    // Crawford: when someone is 1 point from the match, the cube is dead.
    crawford = matchLength > 1 &&
        (matchScore[0] == matchLength - 1 ||
            matchScore[1] == matchLength - 1);
    whiteTurn = true;
    dice = [];
    remainingDice = [];
    currentSeqs = [];
    botPlan = [];
    animMove = null;
    moveNumber = 0;
    lastResult = null;
    gameOver = false;
    rollOffWhite = 0;
    rollOffBlack = 0;
    _undoSnap = null;
    phase = BgPhase.rollOff;
    _emit(const BgEvent('info', 'Rolling off to see who starts…'));
    _after(const Duration(milliseconds: 900), _doRollOff);
    onUpdate?.call();
  }

  void _doRollOff() {
    if (phase != BgPhase.rollOff || _disposed) return;
    rollOffWhite = 1 + rnd.nextInt(6);
    rollOffBlack = 1 + rnd.nextInt(6);
    onUpdate?.call();
    if (rollOffWhite == rollOffBlack) {
      _emit(BgEvent('roll',
          'Both rolled $rollOffWhite — rolling off again…'));
      _after(const Duration(milliseconds: 1400), _doRollOff);
      return;
    }
    final whiteStarts = rollOffWhite > rollOffBlack;
    whiteTurn = whiteStarts;
    dice = [rollOffWhite, rollOffBlack];
    remainingDice = List<int>.from(dice);
    final starter = current.name;
    _emit(BgEvent('roll',
        '$starter wins the roll-off ($rollOffWhite vs $rollOffBlack) and opens with ${dice[0]}–${dice[1]}'));
    _takeUndoSnapshot();
    _after(const Duration(milliseconds: 1500), _beginMovesPhase);
  }

  void _takeUndoSnapshot() {
    _undoSnap = _Snapshot(pos.clone(), cube.clone(), whiteTurn,
        List<int>.from(dice));
  }

  /// Human (or bot) asks to roll the dice.
  void requestRoll() {
    if (gameOver || phase != BgPhase.awaitingDecision) return;
    if (current.isBot) return; // bots roll through their own timers
    phase = BgPhase.diceRolling;
    _emit(BgEvent('roll', '${current.name} shakes the dice cup…'));
    onUpdate?.call();
    _after(const Duration(milliseconds: 950), _resolveDice);
  }

  void _botStartTurn() {
    if (gameOver || phase != BgPhase.awaitingDecision) return;
    if (!current.isBot) return;
    // Cube decision first.
    if (BgAi.shouldDouble(
        pos, whiteTurn, current.difficulty, cube, crawford)) {
      _offerDouble(botInitiated: true);
      return;
    }
    phase = BgPhase.diceRolling;
    _emit(BgEvent('roll', '${current.name} shakes the dice cup…'));
    onUpdate?.call();
    _after(const Duration(milliseconds: 1100), _resolveDice);
  }

  void _resolveDice() {
    if (gameOver) return;
    if (phase != BgPhase.diceRolling && phase != BgPhase.rollOff) return;
    final d1 = 1 + rnd.nextInt(6), d2 = 1 + rnd.nextInt(6);
    dice = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
    remainingDice = List<int>.from(dice);
    _emit(BgEvent('roll',
        '${current.name} rolled ${d1 == d2 ? 'double ${d1}s' : '$d1 and $d2'}'));
    _beginMovesPhase();
  }

  void _beginMovesPhase() {
    if (gameOver || _disposed) return;
    currentSeqs = BgRules.legalSequences(pos, whiteTurn, remainingDice);
    if (currentSeqs.isEmpty) {
      // No legal move: the turn passes. Phase is set to awaitingMoves with
      // empty sequences so the watchdog can recover the pass if paused.
      phase = BgPhase.awaitingMoves;
      _emit(BgEvent(
          'nomove', '${current.name} has no legal move — turn passes.'));
      onUpdate?.call();
      _after(const Duration(milliseconds: 1400), _endTurn);
      return;
    }
    if (current.isBot) {
      phase = BgPhase.botActing;
      onUpdate?.call();
      _after(const Duration(milliseconds: 700), _botChoose);
    } else {
      phase = BgPhase.awaitingMoves;
      onUpdate?.call();
    }
  }

  // ------------------------------------------------------------ bot play
  void _botChoose() {
    if (gameOver || phase != BgPhase.botActing) return;
    botPlan = BgAi.chooseSequence(pos, whiteTurn, currentSeqs,
        List<int>.from(remainingDice), current.difficulty,
        isOpening: moveNumber < 2, rnd: rnd);
    _botStep();
  }

  void _botStep() {
    if (gameOver) return;
    if (botPlan.isEmpty) {
      _endTurn();
      return;
    }
    final m = botPlan.removeAt(0);
    _playMoveAnimated(m, byBot: true);
  }

  // ------------------------------------------------------------ moves
  /// Legal first-step (from -> to) options for the current human turn.
  List<BgMove> humanOptions() {
    if (phase != BgPhase.awaitingMoves || current.isBot) return const [];
    final seen = <BgMove>{};
    final opts = <BgMove>[];
    for (final seq in currentSeqs) {
      if (!seen.contains(seq.first)) {
        seen.add(seq.first);
        opts.add(seq.first);
      }
    }
    return opts;
  }

  /// Destinations for a selected checker (from == -1 = bar).
  List<int> destinationsFor(int from) {
    return humanOptions()
        .where((m) => m.from == from)
        .map((m) => m.to)
        .toList();
  }

  /// Human plays from -> to. Returns false if illegal (UI plays invalid sfx).
  bool humanPlay(int from, int to) {
    if (gameOver || phase != BgPhase.awaitingMoves || current.isBot) {
      return false;
    }
    BgMove? pick;
    for (final seq in currentSeqs) {
      final f = seq.first;
      if (f.from == from && f.to == to) {
        pick = f;
        break;
      }
    }
    if (pick == null) return false;
    _playMoveAnimated(pick, byBot: false);
    return true;
  }

  void _playMoveAnimated(BgMove m, {required bool byBot}) {
    phase = BgPhase.animating;
    animMove = m;
    remainingDice.remove(m.die);
    final willHit = _wouldHit(pos, whiteTurn, m);
    animHit = willHit;
    onUpdate?.call();
    final who = current.name;
    _after(const Duration(milliseconds: 620), () => _finishAnim(who, m));
  }

  bool _wouldHit(BgPosition p, bool white, BgMove m) {
    if (m.to == 24 || m.to < 0) return false;
    return BgRules.foeCount(p, white, m.to) == 1;
  }

  void _finishAnim([String? who, BgMove? m]) {
    m ??= animMove;
    if (m == null || gameOver) return;
    final hit = BgRules.applyMove(pos, whiteTurn, m);
    moveNumber++;
    animMove = null;
    final mover = who ?? current.name;
    final dest = m.to == 24
        ? 'off the board'
        : (m.from == -1
            ? 'back in on ${BgRules.pointName(m.to)}'
            : BgRules.pointName(m.to));
    if (m.to == 24) {
      _emit(BgEvent('bearoff', '$mover bears a checker off!', m));
    } else if (hit) {
      _emit(BgEvent('hit',
          '$mover hits a blot on ${BgRules.pointName(m.to)}!', m));
    } else if (m.from == -1) {
      _emit(BgEvent('reenter', '$mover re-enters on $dest.', m));
    } else {
      _emit(BgEvent('move',
          '$mover plays ${BgRules.pointName(m.from)} → $dest.', m));
    }
    // Win check: 15 borne off.
    final off = whiteTurn ? pos.whiteOff : pos.blackOff;
    if (off == 15) {
      _finishGame(whiteWon: whiteTurn, kind: 'bearoff');
      return;
    }
    // Recompute legal sequences for the remaining dice (max-moves rule
    // re-applied at every step).
    currentSeqs = BgRules.legalSequences(pos, whiteTurn, remainingDice);
    if (currentSeqs.isEmpty) {
      onUpdate?.call();
      _after(const Duration(milliseconds: 650), _endTurn);
      return;
    }
    if (current.isBot) {
      phase = BgPhase.botActing;
      onUpdate?.call();
      _after(const Duration(milliseconds: 750), _botStep);
    } else {
      phase = BgPhase.awaitingMoves;
      onUpdate?.call();
    }
  }

  /// Undo the whole current turn (human only, before the turn ends).
  bool undoTurn() {
    if (gameOver || current.isBot) return false;
    if (phase != BgPhase.awaitingMoves &&
        phase != BgPhase.awaitingDecision) {
      return false;
    }
    final s = _undoSnap;
    if (s == null) return false;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _restore(s);
    phase = BgPhase.awaitingDecision;
    _emit(const BgEvent('info', 'Turn taken back — roll again.'));
    onUpdate?.call();
    return true;
  }

  /// Test/maintenance hook: cancel any pending phase timer so the game
  /// can be driven synchronously (e.g. bot-vs-bot sims).
  void cancelPendingTimers() {
    _phaseTimer?.cancel();
    _phaseTimer = null;
  }

  void _restore(_Snapshot s) {    pos.copyFrom(s.pos);
    cube = s.cube.clone();
    whiteTurn = s.whiteTurn;
    dice = List<int>.from(s.dice);
    remainingDice = List<int>.from(dice);
    currentSeqs = [];
    botPlan = [];
    animMove = null;
  }

  void _endTurn() {
    if (gameOver || _disposed) return;
    whiteTurn = !whiteTurn;
    dice = [];
    remainingDice = [];
    currentSeqs = [];
    botPlan = [];
    animMove = null;
    _takeUndoSnapshot();
    phase = BgPhase.awaitingDecision;
    _emit(BgEvent('turn', "${current.name}'s turn."));
    onUpdate?.call();
    if (current.isBot) {
      _after(const Duration(milliseconds: 900), _botStartTurn);
    }
  }

  // ------------------------------------------------------------ doubling cube
  bool get cubeDead => crawford;
  bool get canDoubleNow {
    if (gameOver ||
        phase != BgPhase.awaitingDecision ||
        crawford ||
        cube.value >= 64) {
      return false;
    }
    final side = whiteTurn ? 0 : 1;
    return cube.owner == -1 || cube.owner == side;
  }

  /// Offer the doubling cube. Returns false if not allowed.
  bool offerDouble() {
    if (!canDoubleNow || current.isBot) return false;
    _offerDouble(botInitiated: false);
    return true;
  }

  void _offerDouble({required bool botInitiated}) {
    phase = BgPhase.doubleOffer;
    _doubleResponder = whiteTurn ? 1 : 0;
    final doubler = current.name;
    final responder = players[_doubleResponder].name;
    _emit(BgEvent('double-offer',
        '$doubler offers the cube at ${cube.value * 2}! $responder, take or pass?'));
    onUpdate?.call();
    _askDouble(_doubleResponder);
  }

  void _askDouble(int responder) {
    if (phase != BgPhase.doubleOffer || _disposed) return;
    final p = players[responder];
    if (!p.isBot) {
      // Human responder: the UI shows the take/pass dialog from onUpdate.
      onUpdate?.call();
      return;
    }
    _after(const Duration(milliseconds: 1100), () {
      if (phase != BgPhase.doubleOffer) return;
      final take = BgAi.shouldTake(
          pos, responder == 0, p.difficulty, cube);
      respondDouble(accept: take);
    });
  }

  /// The responder takes or passes the double.
  void respondDouble({required bool accept}) {
    if (phase != BgPhase.doubleOffer || _doubleResponder < 0) return;
    final responder = _doubleResponder;
    _doubleResponder = -1;
    if (!accept) {
      // Game ends immediately; the doubler scores the CURRENT cube value.
      _finishGame(
          whiteWon: whiteTurn,
          kind: 'double-decline',
          forcedPoints: cube.value);
      return;
    }
    cube.value *= 2;
    cube.owner = responder; // taker owns the cube
    _emit(BgEvent('double-take',
        '${players[responder].name} takes! Cube is now ${cube.value}.'));
    phase = BgPhase.awaitingDecision;
    onUpdate?.call();
    if (current.isBot) {
      _after(const Duration(milliseconds: 800), _botStartTurn);
    }
  }

  // ------------------------------------------------------------ game over
  void _finishGame(
      {required bool whiteWon, required String kind, int? forcedPoints}) {
    gameOver = true;
    phase = BgPhase.gameOver;
    final BgResult result;
    if (forcedPoints != null) {
      result = BgResult(forcedPoints, kind);
    } else {
      result = BgRules.scoreGame(pos, whiteWon, cube.value);
    }
    lastResult = result;
    lastWinnerWhite = whiteWon;
    final wi = whiteWon ? 0 : 1;
    matchScore[wi] += result.points;
    final winner = players[wi].name;
    final label = result.kind == 'backgammon'
        ? 'BACKGAMMON'
        : result.kind == 'gammon'
            ? 'GAMMON'
            : result.kind == 'double-decline'
                ? 'DOUBLE DECLINED'
                : 'WIN';
    _emit(BgEvent('game',
        '$winner wins — $label! +${result.points} point${result.points == 1 ? '' : 's'}.'));
    onUpdate?.call();
  }

  bool get matchOver =>
      matchLength > 1 &&
      (matchScore[0] >= matchLength || matchScore[1] >= matchLength);

  String get matchWinnerName {
    if (matchScore[0] >= matchLength) return players[0].name;
    if (matchScore[1] >= matchLength) return players[1].name;
    return '';
  }

  void resetMatchScores() {
    matchScore[0] = 0;
    matchScore[1] = 0;
  }

  void _emit(BgEvent e) => onEvent?.call(e);

  // ------------------------------------------------------------ test hooks
  /// Synchronously advance bot/auto phases (no timers) for bot-vs-bot sims.
  /// Returns false when the game needs a human or is over.
  bool autoStepSync() {
    if (gameOver) return false;
    switch (phase) {
      case BgPhase.rollOff:
        rollOffWhite = 1 + rnd.nextInt(6);
        rollOffBlack = 1 + rnd.nextInt(6);
        if (rollOffWhite == rollOffBlack) return true;
        whiteTurn = rollOffWhite > rollOffBlack;
        dice = [rollOffWhite, rollOffBlack];
        remainingDice = List<int>.from(dice);
        _takeUndoSnapshot();
        _beginMovesPhaseSync();
        return true;
      case BgPhase.awaitingDecision:
        if (!current.isBot) return false;
        if (BgAi.shouldDouble(
            pos, whiteTurn, current.difficulty, cube, crawford)) {
          final take = BgAi.shouldTake(
              pos, !whiteTurn, other.difficulty, cube);
          if (take) {
            cube.value *= 2;
            cube.owner = whiteTurn ? 1 : 0;
          } else {
            _finishGame(
                whiteWon: whiteTurn,
                kind: 'double-decline',
                forcedPoints: cube.value);
            return false;
          }
        }
        final d1 = 1 + rnd.nextInt(6), d2 = 1 + rnd.nextInt(6);
        dice = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
        remainingDice = List<int>.from(dice);
        _beginMovesPhaseSync();
        return true;
      case BgPhase.botActing:
      case BgPhase.awaitingMoves:
        if (!current.isBot) return false;
        if (currentSeqs.isEmpty) {
          _endTurnSync();
          return true;
        }
        final seq = BgAi.chooseSequence(pos, whiteTurn, currentSeqs,
            List<int>.from(remainingDice), current.difficulty,
            isOpening: moveNumber < 2, rnd: rnd);
        for (final m in seq) {
          remainingDice.remove(m.die);
          BgRules.applyMove(pos, whiteTurn, m);
          moveNumber++;
          if ((whiteTurn ? pos.whiteOff : pos.blackOff) == 15) {
            _finishGame(whiteWon: whiteTurn, kind: 'bearoff');
            return false;
          }
        }
        _endTurnSync();
        return true;
      case BgPhase.doubleOffer:
        return false;
      case BgPhase.diceRolling:
      case BgPhase.animating:
        return true;
      case BgPhase.gameOver:
        return false;
    }
  }

  void _beginMovesPhaseSync() {
    currentSeqs = BgRules.legalSequences(pos, whiteTurn, remainingDice);
    phase = current.isBot ? BgPhase.botActing : BgPhase.awaitingMoves;
  }

  void _endTurnSync() {
    whiteTurn = !whiteTurn;
    dice = [];
    remainingDice = [];
    currentSeqs = [];
    botPlan = [];
    _takeUndoSnapshot();
    phase = BgPhase.awaitingDecision;
  }
}
