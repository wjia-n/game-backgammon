import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'theme.dart';
import 'widgets.dart';
import 'audio.dart';
import 'settings.dart';
import 'game_over_screen.dart';
import 'screens/settings_screen.dart';

enum _Phase { rolloff, play }

/// Snapshot entry for undo (engine state before a single move).
class _GameScreen extends StatefulWidget {
  final bool vsBot;
  const _GameScreen({super.key, required this.vsBot});

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class BackgammonGameScreen extends _GameScreen {
  const BackgammonGameScreen({super.key, required super.vsBot});
}

class _GameScreenState extends State<BackgammonGameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _rand = Random();
  final eng = BgEngine();

  _Phase phase = _Phase.rolloff;
  bool rolled = false;
  int selFrom = -2; // -2 none, -1 bar, else point index
  List<BgMove> selMoves = [];
  bool over = false;
  int lastTo = -1;

  // Doubling cube: 64 = centered/unowned. Owner: -1 center, 0 white, 1 black.
  int cubeValue = 64;
  int cubeOwner = -1;

  // Opening roll-off dice
  int roWhite = 0, roBlack = 0;
  String rolloffMsg = '';

  // Undo history (snapshots before each move of the current turn)
  final List<BgSnapshot> _undoStack = [];

  // Move animation overlay
  _MoveAnim? _anim;
  late AnimationController _animCtl;

  // Dice rattle
  bool _diceShaking = false;
  late AnimationController _shakeCtl;

  bool _paused = false;
  int _botToken = 0;
  String message = '';

  int moveCount = 0;
  int hitCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _shakeCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    eng.reset();
    BgAudio.instance.playMusic('audio/music_game.wav');
    BgAudio.instance.start();
    Future.delayed(const Duration(milliseconds: 800), _rollOffStep);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animCtl.dispose();
    _shakeCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _paused = true;
      BgAudio.instance.stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      _paused = false;
      if (!over) {
        BgAudio.instance.playMusic('audio/music_game.wav');
        _maybeBot();
      }
    }
  }

  // ---------- helpers ----------
  bool get _botTurn => widget.vsBot && !eng.whiteTurn;
  bool get _humanTurn =>
      !over && phase == _Phase.play && rolled && !_botTurn && !_paused;
  int get _curIdx => eng.whiteTurn ? 0 : 1;
  int get _target => BgSettings.instance.matchLength;
  bool get _cubeLive => BgSettings.instance.whiteMatch < _target - 1 &&
      BgSettings.instance.blackMatch < _target - 1;
  int get _stake => cubeValue == 64 ? 1 : cubeValue;

  String _name(int idx) {
    if (!widget.vsBot) return idx == 0 ? 'White' : 'Black';
    return idx == 0 ? 'You' : 'Bot';
  }

  // ---------- opening roll-off (RULES §3) ----------
  void _rollOffStep() {
    if (!mounted || over || _paused) return;
    if (phase != _Phase.rolloff) return;
    final a = _rand.nextInt(6) + 1;
    final b = _rand.nextInt(6) + 1;
    setState(() {
      roWhite = a;
      roBlack = b;
    });
    BgAudio.instance.dice();
    if (a == b) {
      setState(() => rolloffMsg = 'Tied at $a — rolling again…');
      Future.delayed(const Duration(milliseconds: 1100), _rollOffStep);
      return;
    }
    final whiteFirst = a > b;
    setState(() {
      rolloffMsg =
          '${whiteFirst ? _name(0) : _name(1)} rolls ${whiteFirst ? a : b} and moves first!';
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted || over) return;
      setState(() {
        eng.whiteTurn = whiteFirst;
        eng.rollDice([a, b]);
        rolled = true;
        phase = _Phase.play;
        message = '${_name(_curIdx)} to move';
      });
      _maybeBot();
    });
  }

  // ---------- turn flow ----------
  void _roll() {
    if (over || rolled || _botTurn || phase != _Phase.play || _paused) return;
    BgAudio.instance.dice();
    setState(() => _diceShaking = true);
    _shakeCtl.forward(from: 0);
    final d1 = _rand.nextInt(6) + 1, d2 = _rand.nextInt(6) + 1;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || over) return;
      setState(() {
        eng.rollDice([d1, d2]);
        rolled = true;
        _diceShaking = false;
        _undoStack.clear();
        selFrom = -2;
        selMoves = [];
        message = eng.hasAnyMove ? 'Choose a checker' : 'No legal moves';
      });
      if (!eng.hasAnyMove) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted || over || !_humanTurn) return;
          _endTurn();
        });
      }
    });
  }

  void _tapPoint(int i) {
    if (!_humanTurn) return;
    final white = eng.whiteTurn;
    if (selFrom != -2) {
      final mv = _deduped().where((m) => m.to == i).toList();
      if (mv.isNotEmpty) {
        _applyMove(mv.first);
        return;
      }
    }
    final own = white ? eng.points[i] : -eng.points[i];
    if (own > 0 && eng.barCount(white) == 0) {
      final moves = eng.dice
          .expand((d) => eng.movesForDie(d))
          .where((m) => m.from == i)
          .toList();
      if (moves.isEmpty) {
        BgAudio.instance.invalid();
        setState(() => message = 'That checker cannot move');
        return;
      }
      setState(() {
        selFrom = i;
        selMoves = moves;
        message = 'Choose a destination';
      });
      BgAudio.instance.click();
    } else {
      setState(() {
        selFrom = -2;
        selMoves = [];
      });
    }
  }

  void _tapBar() {
    if (!_humanTurn) return;
    final white = eng.whiteTurn;
    if (eng.barCount(white) == 0) return;
    if (selFrom == -1) {
      setState(() {
        selFrom = -2;
        selMoves = [];
      });
      return;
    }
    final moves = eng.dice
        .expand((d) => eng.movesForDie(d))
        .where((m) => m.from == -1)
        .toList();
    setState(() {
      selFrom = -1;
      selMoves = moves;
      message = moves.isEmpty ? 'No re-entry — dice forfeited' : 'Choose a re-entry point';
    });
    BgAudio.instance.click();
  }

  void _tapOffTray() {
    if (!_humanTurn || selFrom == -2) return;
    final mv = selMoves.where((m) => m.to == 24).toList();
    if (mv.isNotEmpty) {
      _applyMove(mv.first);
    } else {
      BgAudio.instance.invalid();
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
    final moverIdx = _curIdx;
    final wasHit = m.to != 24 && eng.foeCount(m.to) == 1;
    final wasOff = m.to == 24;
    final white = eng.whiteTurn;
    _undoStack.add(eng.snapshot());
    final fromC = _checkerCenter(m.from, white);
    setState(() {
      final w = eng.doMove(m);
      lastTo = m.to;
      selFrom = -2;
      selMoves = [];
      moveCount++;
      if (wasHit) hitCount++;
      if (w >= 0) over = true;
    });
    if (wasHit) {
      BgAudio.instance.hit();
    } else if (wasOff) {
      BgAudio.instance.bearOff();
    } else {
      BgAudio.instance.slide();
    }
    // weighty slide animation overlay
    if (fromC != null && m.to != 24) {
      final toC = _pointLandingCenter(m.to, white);
      if (toC != null) {
        _anim = _MoveAnim(from: fromC, to: toC, white: white);
        _animCtl.forward(from: 0);
      }
    }
    if (over) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _finishGame(moverIdx, declined: false);
      });
      return;
    }
    if (eng.dice.isEmpty || !eng.hasAnyMove) {
      setState(() => message = eng.dice.isEmpty ? '' : 'No further moves');
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || over) return;
        _endTurn();
      });
    } else if (!_botTurn) {
      setState(() => message = '${eng.dice.length} move${eng.dice.length > 1 ? 's' : ''} left');
      _maybeBotMoves();
    } else {
      _maybeBotMoves();
    }
  }

  void _undo() {
    if (!_humanTurn || _undoStack.isEmpty) return;
    BgAudio.instance.click();
    setState(() {
      eng.restore(_undoStack.removeLast());
      selFrom = -2;
      selMoves = [];
      lastTo = -1;
      moveCount = (moveCount - 1).clamp(0, 1 << 30);
      message = 'Move taken back';
    });
  }

  void _endTurn() {
    if (over) return;
    _botToken++;
    setState(() {
      eng.whiteTurn = !eng.whiteTurn;
      eng.dice = [];
      rolled = false;
      selFrom = -2;
      selMoves = [];
      lastTo = -1;
      _undoStack.clear();
      message = '${_name(_curIdx)} to move';
    });
    _maybeBot();
  }

  // ---------- doubling cube (RULES §7) ----------
  void _offerDouble() {
    if (over || rolled || _botTurn || phase != _Phase.play || _paused) return;
    if (!_cubeLive) return;
    if (!(cubeOwner == -1 || cubeOwner == _curIdx)) return;
    final newValue = _stake * 2;
    BgAudio.instance.doubleTurn();
    if (widget.vsBot) {
      // Bot responds.
      final botPip = eng.pipCount(false);
      final youPip = eng.pipCount(true);
      final ahead = youPip - botPip; // positive = you ahead
      final diff = BgSettings.instance.difficulty;
      final accept = diff == 0 ? ahead > 0 : ahead > -20;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || over) return;
        if (accept) {
          setState(() {
            cubeValue = newValue;
            cubeOwner = 1;
            message = 'Bot takes the double — stake ×$newValue';
          });
          BgAudio.instance.doubleTurn();
        } else {
          _finishGame(0, declined: true);
        }
      });
      setState(() => message = 'Double offered to the Bot…');
    } else {
      _askDoubleHuman(newValue);
    }
  }

  void _askDoubleHuman(int newValue, {VoidCallback? onTake}) {
    final foe = _name(1 - _curIdx);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: LeatherPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DOUBLE OFFERED', style: BgTheme.display.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text('$foe, the stake goes to ×$newValue. Take or pass?',
                  style: BgTheme.body, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrassButton(
                    label: 'Take',
                    fontSize: 16,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        cubeValue = newValue;
                        cubeOwner = 1 - _curIdx;
                        message = '$foe takes — stake ×$newValue';
                      });
                      BgAudio.instance.doubleTurn();
                      onTake?.call();
                    },
                  ),
                  const SizedBox(width: 12),
                  BrassButton(
                    label: 'Pass',
                    fontSize: 16,
                    primary: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _finishGame(_curIdx, declined: true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- bot ----------
  void _maybeBot() {
    if (over || !_botTurn || phase != _Phase.play || _paused) return;
    final token = ++_botToken;
    setState(() => message = 'Bot is thinking…');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || over || _paused || token != _botToken) return;
      _botMaybeDouble(token);
    });
  }

  void _botMaybeDouble(int token) {
    // Medium+: double with a clear pip lead (RULES §11). Easy never doubles.
    final diff = BgSettings.instance.difficulty;
    final canDouble = _cubeLive && (cubeOwner == -1 || cubeOwner == 1);
    if (diff >= 1 && canDouble) {
      final lead = eng.pipCount(true) - eng.pipCount(false);
      if (lead >= 15) {
        final newValue = _stake * 2;
        BgAudio.instance.doubleTurn();
        setState(() => message = 'Bot offers to double to ×$newValue…');
        _askDoubleHuman(newValue, onTake: () {
          if (!mounted || over || token != _botToken) return;
          _botRoll(token);
        });
        return;
      }
    }
    _botRoll(token);
  }

  void _botRoll(int token) {
    if (!mounted || over || _paused || token != _botToken) return;
    BgAudio.instance.dice();
    setState(() => _diceShaking = true);
    _shakeCtl.forward(from: 0);
    final d1 = _rand.nextInt(6) + 1, d2 = _rand.nextInt(6) + 1;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || over || _paused || token != _botToken) return;
      setState(() {
        eng.rollDice([d1, d2]);
        rolled = true;
        _diceShaking = false;
        _undoStack.clear();
      });
      if (!eng.hasAnyMove) {
        setState(() => message = 'Bot has no moves');
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (!mounted || over || token != _botToken) return;
          _endTurn();
        });
      } else {
        _maybeBotMoves();
      }
    });
  }

  void _maybeBotMoves() {
    if (over || !_botTurn || !rolled || _paused) return;
    final token = _botToken;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || over || !_botTurn || _paused || token != _botToken) return;
      final options = <BgMove>[];
      for (final d in eng.dice.toSet()) {
        options.addAll(eng.movesForDie(d));
      }
      if (options.isEmpty) {
        _endTurn();
        return;
      }
      _applyMove(_pickBotMove(options));
      if (!over && rolled && eng.hasAnyMove && _botTurn) _maybeBotMoves();
    });
  }

  BgMove _pickBotMove(List<BgMove> options) {
    final diff = BgSettings.instance.difficulty;
    if (diff == 0 && _rand.nextDouble() < 0.4) {
      return options[_rand.nextInt(options.length)]; // Easy: random 40%
    }
    BgMove best = options.first;
    int bestScore = -1 << 30;
    for (final m in options) {
      int s = diff == 2 ? 0 : _rand.nextInt(12) - 6; // Hard: no noise
      if (m.from == -1) s += 8;
      if (m.to == 24) {
        s += 22;
      } else {
        if (eng.foeCount(m.to) == 1) s += 30; // hit the blot
        final own = eng.ownCount(m.to);
        if (own == 1) s += 12; // make a point
        if (own == 0) s -= 8; // leaves a blot
      }
      final fromCnt =
          m.from == -1 ? 1 : eng.ownCount(m.from);
      if (fromCnt > 2) s += 4; // unstack
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best;
  }

  // ---------- scoring & game over ----------
  Future<void> _finishGame(int winnerIdx, {required bool declined}) async {
    _botToken++;
    final winnerIsWhite = winnerIdx == 0;
    int base, points;
    String kind;
    if (declined) {
      base = 1;
      kind = 'Double declined';
      points = _stake; // current (undoubled) stake, single game
    } else {
      final loserIsWhite = !winnerIsWhite;
      final loserOff = eng.offCount(loserIsWhite);
      final loserBar = eng.barCount(loserIsWhite);
      int inWinnerHome = 0;
      for (int i = 0; i < 24; i++) {
        final c = loserIsWhite ? eng.points[i] : -eng.points[i];
        if (c <= 0) continue;
        final inHome = winnerIsWhite ? i < 6 : i >= 18;
        if (inHome) inWinnerHome += c;
      }
      if (loserOff > 0) {
        base = 1;
        kind = 'Single game';
      } else if (loserBar > 0 || inWinnerHome > 0) {
        base = 3;
        kind = 'Backgammon';
      } else {
        base = 2;
        kind = 'Gammon';
      }
      points = base * _stake;
    }
    final matchWon = await BgSettings.instance.recordGame(winnerIsWhite, points);
    if (winnerIsWhite) {
      BgAudio.instance.win();
    } else {
      BgAudio.instance.lose();
    }
    if (!mounted) return;
    BgAudio.instance.playMusic('audio/music_menu.wav');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameOverScreen(
          winnerName: _name(winnerIdx),
          winnerIsWhite: winnerIsWhite,
          kind: kind,
          points: points,
          stake: _stake,
          whiteMatch: BgSettings.instance.whiteMatch,
          blackMatch: BgSettings.instance.blackMatch,
          target: _target,
          matchWon: matchWon,
          moveCount: moveCount,
          hitCount: hitCount,
          onRematch: () {
            Navigator.of(context).pop();
            _newGame();
          },
          onMenu: () {
            Navigator.of(context).pop(); // game-over screen
            Navigator.of(context).pop(); // game screen -> main menu
          },
        ),
      ),
    );
    if (matchWon) await BgSettings.instance.resetMatch();
    if (mounted) BgAudio.instance.playMusic('audio/music_game.wav');
  }

  void _newGame() {
    _botToken++;
    setState(() {
      eng.reset();
      cubeValue = 64;
      cubeOwner = -1;
      phase = _Phase.rolloff;
      rolled = false;
      selFrom = -2;
      selMoves = [];
      over = false;
      lastTo = -1;
      roWhite = 0;
      roBlack = 0;
      rolloffMsg = '';
      _undoStack.clear();
      _anim = null;
      moveCount = 0;
      hitCount = 0;
      message = '';
    });
    BgAudio.instance.start();
    Future.delayed(const Duration(milliseconds: 800), _rollOffStep);
  }

  void _restart() {
    BgAudio.instance.click();
    _newGame();
  }

  // ---------- pause ----------
  void _showPause() {
    if (over) return;
    _paused = true;
    BgAudio.instance.click();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: LeatherPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: BgTheme.display.copyWith(fontSize: 24)),
              const SizedBox(height: 6),
              const EngravedDivider(),
              const SizedBox(height: 14),
              SizedBox(
                width: 220,
                child: BrassButton(
                    label: 'Resume',
                    fontSize: 17,
                    onTap: () => Navigator.of(ctx).pop()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: BrassButton(
                    label: 'Restart',
                    fontSize: 17,
                    primary: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _restart();
                    }),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: BrassButton(
                    label: 'Settings',
                    fontSize: 17,
                    primary: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const SettingsScreen()))
                          .then((_) {
                        if (mounted) setState(() {});
                      });
                    }),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: BrassButton(
                    label: 'Main Menu',
                    fontSize: 17,
                    primary: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    }),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (!over && mounted) {
        setState(() => _paused = false);
        _maybeBot();
      }
    });
  }

  // ---------- geometry (set during layout) ----------
  _BoardGeom? _geom;

  /// Center of the topmost checker on a point/bar (for move animation).
  Offset? _checkerCenter(int from, bool white) {
    final g = _geom;
    if (g == null) return null;
    if (from == -1) return g.barStackCenter(eng.barCount(white));
    final n = white ? eng.points[from] : -eng.points[from];
    if (n <= 0) return null;
    return g.stackTop(from, 1);
  }

  Offset? _pointLandingCenter(int to, bool white) {
    final g = _geom;
    if (g == null) return null;
    return g.landingCenter(to);
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final pal = BgTheme.boardPalette(BgSettings.instance.boardTheme);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WoodBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              _scorePlaque(),
              const SizedBox(height: 6),
              Expanded(child: _boardArea(pal)),
              const SizedBox(height: 6),
              _diceStrip(),
              const SizedBox(height: 6),
              _controls(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _iconPlaque(Icons.pause, _showPause),
          const SizedBox(width: 10),
          Expanded(
            child: Text('TAVLA SULTANI',
                textAlign: TextAlign.center,
                style: BgTheme.display.copyWith(fontSize: 17)),
          ),
          const SizedBox(width: 10),
          _iconPlaque(Icons.settings, () {
            BgAudio.instance.click();
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                .then((_) {
              if (mounted) setState(() {});
            });
          }),
        ],
      ),
    );
  }

  Widget _iconPlaque(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9B96A), Color(0xFFB08D3E), Color(0xFF8A6A2E)],
          ),
          border: Border.all(color: BgTheme.engravedDark, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Icon(icon, color: BgTheme.engravedDark, size: 22),
      ),
    );
  }

  Widget _scorePlaque() {
    final s = BgSettings.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF241708).withValues(alpha: 0.85),
          border: Border.all(color: BgTheme.brassDeep, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _pipBox(_name(0), eng.pipCount(true), true,
                  eng.whiteTurn && phase == _Phase.play),
            ),
            Column(
              children: [
                Text('${s.whiteMatch} – ${s.blackMatch}',
                    style: BgTheme.numeral.copyWith(fontSize: 20)),
                Text('FIRST TO ${s.matchLength}',
                    style: BgTheme.caption.copyWith(fontSize: 9)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BgTheme.brass, width: 1),
                    color: BgTheme.darkLeather,
                  ),
                  child: Text('STAKE ×$_stake',
                      style: BgTheme.caption.copyWith(fontSize: 10)),
                ),
              ],
            ),
            Expanded(
              child: _pipBox(_name(1), eng.pipCount(false), false,
                  !eng.whiteTurn && phase == _Phase.play),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipBox(String name, int pip, bool white, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active ? BgTheme.brassHi : Colors.transparent, width: 1.5),
        color: active
            ? BgTheme.brassDeep.withValues(alpha: 0.35)
            : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            white ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (white) ...[
            _miniDisc(true),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  white ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: BgTheme.caption.copyWith(fontSize: 10)),
                Text('$pip',
                    style: BgTheme.numeral.copyWith(fontSize: 16)),
              ],
            ),
          ),
          if (!white) ...[
            const SizedBox(width: 6),
            _miniDisc(false),
          ],
        ],
      ),
    );
  }

  Widget _miniDisc(bool white) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: white
              ? const [Color(0xFFFDF6E8), BgTheme.pearlShadow]
              : const [Color(0xFF6E4023), Color(0xFF1A0E06)],
        ),
        border: Border.all(color: Colors.black45, width: 1),
      ),
    );
  }

  // ---------- board ----------
  Widget _boardArea(BoardPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final g = _BoardGeom(
            w: constraints.maxWidth,
            h: constraints.maxHeight,
          );
          _geom = g;
          return Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _SurfacePainter(
                  pal: pal,
                  g: g,
                  selected: selFrom >= 0 ? {selFrom} : {},
                  barSelected: selFrom == -1,
                  lastTo: lastTo,
                ),
              ),
              // point hit areas
              for (int i = 0; i < 24; i++)
                Positioned.fromRect(
                  rect: g.pointRect(i),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _tapPoint(i),
                    child: const SizedBox.expand(),
                  ),
                ),
              // bar hit area
              Positioned.fromRect(
                rect: g.barRect(),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _tapBar,
                  child: const SizedBox.expand(),
                ),
              ),
              // checkers
              for (int i = 0; i < 24; i++) _pointStack(g, i),
              _barStack(g),
              // destination markers
              for (final m in _deduped()) _destMarker(g, m),
              // move animation overlay
              if (_anim != null)
                AnimatedBuilder(
                  animation: _animCtl,
                  builder: (_, _) {
                    final t = Curves.easeOutCubic.transform(_animCtl.value);
                    final pos = Offset.lerp(_anim!.from, _anim!.to, t)!;
                    final lift = sin(t * pi) * 26;
                    return Positioned(
                      left: pos.dx - g.disc / 2,
                      top: pos.dy - g.disc / 2 - lift,
                      child: IgnorePointer(
                        child: CheckerDisc(
                            white: _anim!.white, diameter: g.disc),
                      ),
                    );
                  },
                ),
              // opening roll-off overlay
              if (phase == _Phase.rolloff) _rolloffOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _pointStack(_BoardGeom g, int i) {
    final n = eng.points[i];
    if (n == 0) return const SizedBox.shrink();
    final white = n > 0;
    final count = n.abs();
    final show = count.clamp(1, 5);
    final topDown = i >= 12;
    final kids = <Widget>[];
    for (int k = 0; k < show; k++) {
      final c = g.stackCenter(i, k);
      kids.add(Positioned(
        left: c.dx - g.disc / 2,
        top: c.dy - g.disc / 2,
        child: IgnorePointer(
          child: CheckerDisc(
            white: white,
            diameter: g.disc,
            selected: selFrom == i && k == 0,
          ),
        ),
      ));
    }
    if (count > 5) {
      final c = g.stackCenter(i, 4);
      kids.add(Positioned(
        left: c.dx - 16,
        top: (topDown ? c.dy + g.disc / 2 - 4 : c.dy - g.disc / 2 - 18),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: BgTheme.engravedDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BgTheme.brass, width: 1),
            ),
            child: Text('×$count',
                style: BgTheme.numeral.copyWith(fontSize: 11)),
          ),
        ),
      ));
    }
    return Stack(children: kids);
  }

  Widget _barStack(_BoardGeom g) {
    final white = eng.whiteTurn;
    final n = eng.barCount(white);
    if (n == 0) return const SizedBox.shrink();
    final show = n.clamp(1, 3);
    final kids = <Widget>[];
    for (int k = 0; k < show; k++) {
      final c = g.barStackCenter(k);
      kids.add(Positioned(
        left: c.dx - g.disc / 2,
        top: c.dy - g.disc / 2,
        child: IgnorePointer(
          child: CheckerDisc(
              white: white,
              diameter: g.disc,
              selected: selFrom == -1 && k == 0),
        ),
      ));
    }
    if (n > 3) {
      final c = g.barStackCenter(2);
      kids.add(Positioned(
        left: c.dx - 14,
        top: c.dy + g.disc / 2 - 2,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: BgTheme.engravedDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BgTheme.brass, width: 1),
            ),
            child: Text('×$n',
                style: BgTheme.numeral.copyWith(fontSize: 11)),
          ),
        ),
      ));
    }
    return Stack(children: kids);
  }

  Widget _destMarker(_BoardGeom g, BgMove m) {
    if (m.to == 24) return const SizedBox.shrink();
    final c = g.landingCenter(m.to);
    return Positioned(
      left: c.dx - 11,
      top: c.dy - 11,
      child: IgnorePointer(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BgTheme.pearl.withValues(alpha: 0.85),
            border: Border.all(color: BgTheme.brassHi, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4)
            ],
          ),
          child: const Center(
            child: Icon(Icons.arrow_downward,
                size: 13, color: BgTheme.engravedDark),
          ),
        ),
      ),
    );
  }

  Widget _rolloffOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.55),
        ),
        child: Center(
          child: LeatherPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('OPENING ROLL',
                    style: BgTheme.display.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        Text(_name(0).toUpperCase(),
                            style: BgTheme.caption),
                        const SizedBox(height: 6),
                        roWhite > 0
                            ? DieFace(value: roWhite, size: 52)
                            : const SizedBox(width: 52, height: 52),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(_name(1).toUpperCase(),
                            style: BgTheme.caption),
                        const SizedBox(height: 6),
                        roBlack > 0
                            ? DieFace(value: roBlack, size: 52)
                            : const SizedBox(width: 52, height: 52),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: Text(rolloffMsg,
                      textAlign: TextAlign.center,
                      style: BgTheme.bodyItalic.copyWith(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- dice + message strip ----------
  Widget _diceStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF241708).withValues(alpha: 0.85),
          border: Border.all(color: BgTheme.brassDeep, width: 1.5),
        ),
        child: Row(
          children: [
            _offTray(true),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (phase == _Phase.play)
                        for (final d in eng.dice)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: _diceShaking
                                ? AnimatedBuilder(
                                    animation: _shakeCtl,
                                    builder: (_, _) {
                                      final j = sin(_shakeCtl.value *
                                              pi *
                                              6);
                                      return Transform.translate(
                                        offset: Offset(j * 6, -j.abs() * 8),
                                        child: Transform.rotate(
                                          angle: j * 0.5,
                                          child: DieFace(
                                              value: _rand.nextInt(6) + 1,
                                              size: 40),
                                        ),
                                      );
                                    },
                                  )
                                : DieFace(value: d, size: 40),
                          ),
                      if (phase == _Phase.play &&
                          eng.dice.isEmpty &&
                          rolled)
                        Text('—',
                            style: BgTheme.caption.copyWith(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.isEmpty
                        ? (phase == _Phase.rolloff
                            ? 'Rolling for first move…'
                            : '')
                        : message,
                    textAlign: TextAlign.center,
                    style: BgTheme.bodyItalic.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            _offTray(false),
          ],
        ),
      ),
    );
  }

  Widget _offTray(bool white) {
    final n = eng.offCount(white);
    final canBear = _humanTurn &&
        selFrom != -2 &&
        selMoves.any((m) => m.to == 24) &&
        ((white && eng.whiteTurn) || (!white && !eng.whiteTurn));
    return GestureDetector(
      onTap: canBear ? _tapOffTray : null,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: canBear ? BgTheme.brassHi : BgTheme.brassDeep,
              width: canBear ? 2 : 1),
          color: BgTheme.darkLeather,
        ),
        child: Column(
          children: [
            Text(white ? 'WHITE' : 'BLACK',
                style: BgTheme.caption.copyWith(fontSize: 8)),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.center,
              children: [
                _miniDisc(white),
                if (n > 0)
                  Text('$n',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
              ],
            ),
            const SizedBox(height: 2),
            Text('OFF', style: BgTheme.caption.copyWith(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // ---------- controls ----------
  Widget _controls() {
    final canDouble = phase == _Phase.play &&
        !over &&
        !rolled &&
        !_botTurn &&
        !_paused &&
        _cubeLive &&
        (cubeOwner == -1 || cubeOwner == _curIdx);
    final canRoll =
        phase == _Phase.play && !over && !rolled && !_botTurn && !_paused;
    final canUndo = _humanTurn && _undoStack.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: BrassButton(
              label: '×${_stake * 2}',
              sublabel: _cubeLive ? 'Double' : 'No cube',
              fontSize: 18,
              primary: false,
              onTap: canDouble ? _offerDouble : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BrassButton(
              label: 'ROLL DICE',
              sublabel: _botTurn ? 'Bot\u2019s turn' : 'Your move',
              fontSize: 20,
              icon: Icons.casino,
              onTap: canRoll ? _roll : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BrassButton(
              label: 'UNDO',
              sublabel: 'Last move',
              fontSize: 16,
              primary: false,
              onTap: canUndo ? _undo : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- move animation ----------
class _MoveAnim {
  final Offset from;
  final Offset to;
  final bool white;
  _MoveAnim({required this.from, required this.to, required this.white});
}

// ---------- board geometry ----------
class _BoardGeom {
  final double w, h;
  late final double frame = 10;
  late final double pw; // point width
  late final double barW;
  late final double barX;
  late final double fx, fy, fw, fh; // inner rect
  late final double disc;
  late final double pointLen;

  _BoardGeom({required this.w, required this.h}) {
    fx = frame;
    fy = frame;
    fw = w - frame * 2;
    fh = h - frame * 2;
    barW = fw * 0.11;
    barX = fx + fw / 2 - barW / 2;
    pw = (fw - barW) / 12;
    disc = pw * 0.94;
    pointLen = (fh / 2) * 0.8;
  }

  double _colX(int i) {
    // returns left x of the point column
    if (i >= 12) {
      // top row: 12..17 left, 18..23 right
      final right = i >= 18;
      final col = right ? i - 18 : i - 12;
      return fx + (right ? 6 * pw + barW : 0) + col * pw;
    } else {
      // bottom row: 11..6 left, 5..0 right
      final right = i <= 5;
      final col = right ? 5 - i : 11 - i;
      return fx + (right ? 6 * pw + barW : 0) + col * pw;
    }
  }

  Rect pointRect(int i) {
    final x = _colX(i);
    if (i >= 12) {
      return Rect.fromLTWH(x, fy, pw, fh / 2);
    }
    return Rect.fromLTWH(x, fy + fh / 2, pw, fh / 2);
  }

  Rect barRect() => Rect.fromLTWH(barX, fy, barW, fh);

  Offset stackCenter(int i, int k) {
    final cx = _colX(i) + pw / 2;
    final step = disc * 0.68;
    if (i >= 12) {
      return Offset(cx, fy + disc / 2 + 4 + k * step);
    }
    return Offset(cx, fy + fh - disc / 2 - 4 - k * step);
  }

  /// Topmost checker center of a stack of [n] (for animation start).
  Offset stackTop(int i, int n) => stackCenter(i, 0);

  Offset barStackCenter(int k) {
    final cx = barX + barW / 2;
    final cy = fy + fh / 2 + (k - 1) * disc * 0.55;
    return Offset(cx, cy);
  }

  /// Where a checker visually lands on a point.
  Offset landingCenter(int i) {
    final cx = _colX(i) + pw / 2;
    if (i >= 12) {
      return Offset(cx, fy + pointLen - disc / 2);
    }
    return Offset(cx, fy + fh - pointLen + disc / 2);
  }

  List<Offset> triangle(int i) {
    final x = _colX(i);
    final cx = x + pw / 2;
    if (i >= 12) {
      return [Offset(x + 2, fy), Offset(x + pw - 2, fy), Offset(cx, fy + pointLen)];
    }
    return [
      Offset(x + 2, fy + fh),
      Offset(x + pw - 2, fy + fh),
      Offset(cx, fy + fh - pointLen)
    ];
  }
}

// ---------- board surface painter ----------
class _SurfacePainter extends CustomPainter {
  final BoardPalette pal;
  final _BoardGeom g;
  final Set<int> selected;
  final bool barSelected;
  final int lastTo;

  _SurfacePainter({
    required this.pal,
    required this.g,
    required this.selected,
    required this.barSelected,
    required this.lastTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // frame
    final frameR = RRect.fromLTRBR(
        0, 0, size.width, size.height, const Radius.circular(14));
    canvas.drawRRect(
        frameR, Paint()..color = pal.frameDeep);
    canvas.drawRRect(
        RRect.fromLTRBR(3, 3, size.width - 3, size.height - 3,
            const Radius.circular(12)),
        Paint()..color = pal.frame);
    // mother-of-pearl inlay line
    canvas.drawRRect(
        RRect.fromLTRBR(9, 9, size.width - 9, size.height - 9,
            const Radius.circular(10)),
        Paint()
          ..color = pal.inlay.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    // field halves
    final halfH = g.fh / 2;
    canvas.drawRect(
        Rect.fromLTWH(g.fx, g.fy, g.fw, halfH), Paint()..color = pal.field);
    canvas.drawRect(
        Rect.fromLTWH(g.fx, g.fy + halfH, g.fw, halfH),
        Paint()..color = pal.field);
    // wood sheen on field
    canvas.drawRect(
        Rect.fromLTWH(g.fx, g.fy, g.fw, halfH),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(g.fx, g.fy, g.fw, halfH)));

    // points
    for (int i = 0; i < 24; i++) {
      final tri = g.triangle(i);
      final path = Path()
        ..moveTo(tri[0].dx, tri[0].dy)
        ..lineTo(tri[1].dx, tri[1].dy)
        ..lineTo(tri[2].dx, tri[2].dy)
        ..close();
      // alternate: even columns light pearl, odd dark rosewood
      final light = (i % 2 == 0) == (i >= 12);
      final base = light ? pal.pointLight : pal.pointDark;
      canvas.drawPath(path, Paint()..color = base);
      // bevel edge
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      if (selected.contains(i) || lastTo == i) {
        canvas.drawPath(
            path,
            Paint()
              ..color = BgTheme.brassHi.withValues(
                  alpha: selected.contains(i) ? 0.55 : 0.3));
      }
    }

    // bar
    final barR = RRect.fromLTRBR(g.barX, g.fy, g.barX + g.barW,
        g.fy + g.fh, const Radius.circular(6));
    canvas.drawRRect(barR, Paint()..color = pal.bar);
    canvas.drawRRect(
        barR,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (barSelected) {
      canvas.drawRRect(
          barR,
          Paint()
            ..color = BgTheme.brassHi.withValues(alpha: 0.5));
    }
    // bar medallion
    final mc = Offset(g.barX + g.barW / 2, g.fy + g.fh / 2);
    _drawStar(canvas, mc, g.barW * 0.42);

    // frame corner brackets
    final bp = Paint()
      ..color = BgTheme.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const cl = 22.0;
    for (final corner in [
      [0.0, 0.0, 1.0, 1.0],
      [size.width, 0.0, -1.0, 1.0],
      [0.0, size.height, 1.0, -1.0],
      [size.width, size.height, -1.0, -1.0],
    ]) {
      final x = corner[0], y = corner[1];
      final dx = corner[2], dy = corner[3];
      canvas.drawPath(
          Path()
            ..moveTo(x + dx * cl, y)
            ..lineTo(x, y)
            ..lineTo(x, y + dy * cl),
          bp);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r) {
    final pearl = Paint()..color = BgTheme.pearl.withValues(alpha: 0.85);
    final brass = Paint()
      ..color = BgTheme.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int k = 0; k < 2; k++) {
      final path = Path();
      for (int i = 0; i <= 4; i++) {
        final a = pi / 4 * i + pi / 4 * k + pi / 8;
        final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, pearl);
      canvas.drawPath(path, brass);
    }
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter old) => true;
}
