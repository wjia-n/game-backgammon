import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Backgammon: 24 points, dice (doubles = 4 moves), bearing off,
/// hitting blots to the bar, re-entry. No doubling cube — pure race!
class BgMove {
  final int from; // 0-23, or -1 = from bar
  final int to; // 0-23, or 24 = bear off
  final int die;
  const BgMove(this.from, this.to, this.die);
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

  bool get _white => whiteTurn;
  int get _bar => _white ? whiteBar : blackBar;
  int _cnt(int i) => _white ? points[i] : -points[i]; // own checkers
  int _foe(int i) => _white ? -points[i] : points[i]; // enemy checkers

  bool _allInHome() {
    if (_bar > 0) return false;
    for (int i = 0; i < 24; i++) {
      if (_cnt(i) == 0) continue;
      if (_white && i > 5) return false;
      if (!_white && i < 18) return false;
    }
    return true;
  }

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

// ---------- UI ----------
class BackgammonScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const BackgammonScreen({super.key, required this.players, required this.callbacks});

  @override
  State<BackgammonScreen> createState() => _BackgammonScreenState();
}

class _BackgammonScreenState extends State<BackgammonScreen> {
  final _rand = Random();
  final eng = BgEngine();
  bool rolled = false;
  int selFrom = -2; // -2 none, -1 bar, else point
  List<BgMove> selMoves = [];
  bool over = false;
  int lastTo = -1;

  @override
  void initState() {
    super.initState();
    eng.reset();
    widget.callbacks.setActivePlayer(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  bool get _botTurn => widget.players[eng.whiteTurn ? 0 : 1].isBot;

  void _roll() {
    final d1 = _rand.nextInt(6) + 1, d2 = _rand.nextInt(6) + 1;
    setState(() {
      eng.rollDice([d1, d2]);
      rolled = true;
      selFrom = -2;
      selMoves = [];
    });
    Sfx.click();
    if (!eng.hasAnyMove) {
      // no moves possible — pass the turn
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || over) return;
        _endTurn(auto: true);
      });
    } else {
      _maybeBotMoves();
    }
  }

  void _tapPoint(int i) {
    if (over || !rolled || _botTurn) return;
    final white = eng.whiteTurn;
    if (selFrom != -2) {
      final mv = _deduped().where((m) => m.to == i).toList();
      if (mv.isNotEmpty) {
        _applyMove(mv.first);
        return;
      }
    }
    final own = white ? eng.points[i] : -eng.points[i];
    if (own > 0 && !(eng._bar > 0)) {
      setState(() {
        selFrom = i;
        selMoves = eng.dice.expand((d) => eng.movesForDie(d)).where((m) => m.from == i).toList();
      });
      Sfx.click();
    } else {
      setState(() {
        selFrom = -2;
        selMoves = [];
      });
    }
  }

  void _tapBar() {
    if (over || !rolled || _botTurn) return;
    if (eng._bar > 0) {
      if (selFrom == -1) {
        setState(() {
          selFrom = -2;
          selMoves = [];
        });
      } else {
        setState(() {
          selFrom = -1;
          selMoves =
              eng.dice.expand((d) => eng.movesForDie(d)).where((m) => m.from == -1).toList();
        });
        Sfx.click();
      }
    }
  }

  List<BgMove> _deduped() {
    final seen = <String>{};
    final out = <BgMove>[];
    for (final m in selMoves) {
      final k = '${m.from}-${m.to}';
      if (seen.add(k)) out.add(m);
    }
    return out;
  }

  void _applyMove(BgMove m) {
    final moverIdx = eng.whiteTurn ? 0 : 1;
    final wasHit = m.to != 24 && eng._foe(m.to) == 1;
    final wasOff = m.to == 24;
    setState(() {
      final w = eng.doMove(m);
      lastTo = m.to;
      selFrom = -2;
      selMoves = [];
      if (w >= 0) over = true;
    });
    if (wasHit) {
      Sfx.win();
    } else if (wasOff) {
      Sfx.click();
    } else {
      Sfx.move();
    }
    if (over) {
      final w = widget.players[moverIdx];
      w.score += 1;
      widget.callbacks.refreshHud();
      Sfx.win();
      widget.callbacks.finish(
          winner: w, headline: '${w.name} races home first! 🏁', subline: 'Backgammon royalty! 👑');
      return;
    }
    if (eng.dice.isEmpty || !eng.hasAnyMove) {
      _endTurn();
    } else {
      setState(() {});
    }
  }

  void _endTurn({bool auto = false}) {
    if (over) return;
    setState(() {
      eng.whiteTurn = !eng.whiteTurn;
      eng.dice = [];
      rolled = false;
      selFrom = -2;
      selMoves = [];
    });
    if (auto) Sfx.lose();
    widget.callbacks.setActivePlayer(eng.whiteTurn ? 0 : 1);
    _maybeBot();
  }

  // ---------- bot ----------
  void _maybeBot() {
    if (over || !_botTurn) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || over) return;
      _roll();
    });
  }

  void _maybeBotMoves() {
    if (over || !_botTurn || !rolled) return;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || over || !_botTurn) return;
      final options = <BgMove>[];
      for (final d in eng.dice.toSet()) {
        options.addAll(eng.movesForDie(d));
      }
      if (options.isEmpty) {
        _endTurn(auto: true);
        return;
      }
      BgMove pick;
      if (_rand.nextDouble() < 0.2) {
        pick = options[_rand.nextInt(options.length)];
      } else {
        pick = _bestBotMove(options);
      }
      _applyMove(pick);
      if (!over && rolled && eng.hasAnyMove) _maybeBotMoves();
    });
  }

  BgMove _bestBotMove(List<BgMove> options) {
    final white = eng.whiteTurn;
    BgMove best = options.first;
    int bestScore = -1 << 30;
    for (final m in options) {
      int s = _rand.nextInt(12) - 6;
      if (m.from == -1) s += 8; // get off the bar!
      if (m.to == 24) {
        s += 22; // bear off 🎉
      } else {
        if (eng._foe(m.to) == 1) s += 30; // HIT the blot! 💥
        final own = white ? eng.points[m.to] : -eng.points[m.to];
        if (own == 1) s += 12; // make a point
        if (own == 0) s -= 8; // leaves a blot... risky
      }
      final fromCnt = m.from == -1 ? 1 : (white ? eng.points[m.from] : -eng.points[m.from]);
      if (fromCnt > 2) s += 4; // unstack
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final cur = widget.players[eng.whiteTurn ? 0 : 1];
    final barCount = eng._bar;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
                player: cur,
                action: !rolled
                    ? ', roll those dice! 🎲'
                    : (cur.isBot ? ' is plotting… 🤖' : ', make your moves! 👆')),
          const SizedBox(height: 6),
          _offTray(widget.players[0], eng.whiteOff, t, true),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: t.radius,
                boxShadow: [
                  BoxShadow(
                      color: t.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Expanded(child: _pointRow([12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], true, t)),
                  _middleStrip(t, barCount),
                  Expanded(child: _pointRow([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0], false, t)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _offTray(widget.players[1], eng.blackOff, t, false),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _offTray(Player p, int off, GameTheme t, bool top) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${p.emoji} home: ', style: TextStyle(color: t.muted, fontSize: 12)),
        ...List.generate(
            off.clamp(0, 15),
            (_) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.color))),
        if (off == 0) Text('—', style: TextStyle(color: t.muted, fontSize: 12)),
        if (!top) const SizedBox(width: 8),
      ],
    );
  }

  Widget _pointRow(List<int> idx, bool topDown, GameTheme t) {
    return Row(
      children: [
        for (int k = 0; k < 12; k++) ...[
          Expanded(child: _point(idx[k], topDown, t, k % 2 == 0)),
          if (k == 5)
            Container(width: 8, color: t.primary.withValues(alpha: 0.25)),
        ],
      ],
    );
  }

  Widget _point(int i, bool topDown, GameTheme t, bool alt) {
    final dests = _deduped().map((m) => m.to).toSet();
    final isDest = dests.contains(i);
    final isSel = selFrom == i;
    final n = eng.points[i];
    return GestureDetector(
      onTap: () => _tapPoint(i),
      child: Container(
        decoration: BoxDecoration(
          color: isSel
              ? t.accent.withValues(alpha: 0.5)
              : isDest
                  ? t.secondary.withValues(alpha: 0.35)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _TriPainter(
                  color: (alt ? t.primary : t.secondary).withValues(alpha: 0.4),
                  down: topDown,
                  highlight: lastTo == i),
            ),
            _checkerStack(n, topDown, t),
          ],
        ),
      ),
    );
  }

  Widget _checkerStack(int n, bool topDown, GameTheme t) {
    if (n == 0) return const SizedBox.expand();
    final white = n > 0;
    final count = n.abs();
    final p = white ? widget.players[0] : widget.players[1];
    final show = count.clamp(1, 5);
    return LayoutBuilder(
      builder: (_, constraints) {
        final d = (constraints.maxWidth).clamp(18.0, 30.0);
        final kids = <Widget>[];
        for (int k = 0; k < show; k++) {
          kids.add(Positioned(
            top: topDown ? k * d * 0.62 : null,
            bottom: topDown ? null : k * d * 0.62,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.color,
                  border: Border.all(color: Colors.white70, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                ),
              ),
            ),
          ));
        }
        if (count > 5) {
          kids.add(Positioned(
            top: topDown ? 5 * d * 0.62 : null,
            bottom: topDown ? null : 5 * d * 0.62,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: t.background, borderRadius: BorderRadius.circular(8)),
                child: Text('×$count',
                    style: TextStyle(fontSize: 10, color: t.text, fontWeight: FontWeight.bold)),
              ),
            ),
          ));
        }
        return Stack(children: kids);
      },
    );
  }

  Widget _middleStrip(GameTheme t, int barCount) {
    final white = eng.whiteTurn;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.symmetric(
            horizontal: BorderSide(color: t.primary.withValues(alpha: 0.25))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // bar
          GestureDetector(
            onTap: _tapBar,
            child: Container(
              width: 64,
              height: 52,
              decoration: BoxDecoration(
                color: selFrom == -1
                    ? t.accent.withValues(alpha: 0.5)
                    : t.background,
                borderRadius: t.radius,
                border: Border.all(color: t.primary.withValues(alpha: 0.4)),
              ),
              child: barCount > 0
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.players[white ? 0 : 1].color,
                              border: Border.all(color: Colors.white70, width: 1.5)),
                        ),
                        Text('$barCount',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ],
                    )
                  : Center(
                      child: Text('BAR',
                          style: TextStyle(
                              fontSize: 10,
                              color: t.muted,
                              fontWeight: FontWeight.bold))),
            ),
          ),
          // dice
          Row(
            children: eng.dice
                .map((d) => Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                          color: t.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.primary.withValues(alpha: 0.5), width: 2)),
                      alignment: Alignment.center,
                      child: Text(_dieFace(d),
                          style: TextStyle(fontSize: 22, color: t.text)),
                    ))
                .toList(),
          ),
          // roll / done (humans only — bots roll themselves 🤖)
          if (!over && !_botTurn)
            !rolled
              ? WajihaButton(
                  label: 'Roll 🎲', emoji: '🎲', primary: true, onTap: _roll)
              : WajihaButton(
                  label: eng.dice.isEmpty || !eng.hasAnyMove ? 'Done ✓' : 'Done',
                  emoji: '✓',
                  primary: false,
                  onTap: () => _endTurn()),
          if (!over && _botTurn)
            Text('🤖', style: const TextStyle(fontSize: 26)),
        ],
      ),
    );
  }

  String _dieFace(int d) => ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'][d - 1];
}

class _TriPainter extends CustomPainter {
  final Color color;
  final bool down;
  final bool highlight;
  _TriPainter({required this.color, required this.down, this.highlight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = highlight ? const Color(0xFFFFC531).withValues(alpha: 0.6) : color;
    final path = Path();
    if (down) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height * 0.92);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2, size.height * 0.08);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TriPainter old) =>
      old.color != color || old.down != down || old.highlight != highlight;
}
