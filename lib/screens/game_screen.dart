import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/backgammon_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';
import '../widgets/backgammon_board.dart';

/// The game screen: the board, one dice tray per side, narration banner,
/// doubling-cube flow, pause, undo, and game-over handling.
///
/// Bot turns are fully visible: the active side's tray highlights, its dice
/// roll with a live animation, and every move animates with narration.
/// Nothing is ever silently auto-played.
class GameScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late BgGame game;
  late AnimationController _moveAnim;
  String _narration = 'Welcome to the table.';
  int? _selectedFrom; // point idx, or -1 = bar
  BgMove? _lastAnimMove;
  bool _doubleDialogOpen = false;
  bool _overDialogOpen = false;
  Timer? _narrTimer;

  SultanSettings get s => widget.settings;
  SultanAudio get audio => widget.audio;
  SultanThemeDef get t =>
      SultanThemes.byId(s.themeId, custom: s.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    final botName = s.playerNames[1];
    game = BgGame(
      players: [
        BgPlayer(name: s.playerNames[0], isBot: false),
        BgPlayer(
            name: s.mode == 0 ? botName : s.playerNames[1],
            isBot: s.mode == 0,
            difficulty: s.difficulty),
      ],
      matchLength: s.matchLength,
    );
    game.onUpdate = _onUpdate;
    game.onEvent = _onEvent;
    audio.startGameMusic();
    game.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _narrTimer?.cancel();
    _moveAnim.dispose();
    game.dispose();
    audio.startMenuMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      game.setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      game.setPaused(false);
    }
  }

  void _onUpdate() {
    if (!mounted) return;
    // A new animated move started: run the flight animation + sound.
    if (game.animMove != null && game.animMove != _lastAnimMove) {
      _lastAnimMove = game.animMove;
      _moveAnim.forward(from: 0);
      if (game.animHit) {
        audio.capture();
      } else if (game.animMove!.to == 24) {
        audio.bearoff();
      } else {
        audio.move();
      }
    }
    if (game.animMove == null) _lastAnimMove = null;
    // Re-show the take/pass dialog if it was lost while the offer pends.
    if (game.phase == BgPhase.doubleOffer && !_doubleDialogOpen) {
      _maybeShowDoubleDialog();
    }
    setState(() {});
  }

  void _onEvent(BgEvent e) {
    if (!mounted) return;
    _narrTimer?.cancel();
    setState(() => _narration = e.message);
    _narrTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _narration == e.message) setState(() => _narration = '');
    });
    switch (e.kind) {
      case 'roll':
        if (e.message.contains('shakes the dice cup')) audio.dice();
        break;
      case 'nomove':
        audio.invalid();
        break;
      case 'double-offer':
        audio.doubleCube();
        _maybeShowDoubleDialog();
        break;
      case 'double-take':
        audio.click();
        break;
      case 'game':
        final humanWon = !game.players[game.lastWinnerWhite ? 0 : 1].isBot;
        if (humanWon) {
          audio.win();
        } else {
          audio.lose();
        }
        s.recordGame(humanWon: humanWon);
        Future.delayed(const Duration(milliseconds: 1400), _showGameOver);
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------- interactions
  void _onBoardTap(int hit) {
    if (game.phase != BgPhase.awaitingMoves || game.current.isBot) return;
    if (hit == -1) {
      setState(() => _selectedFrom = null);
      return;
    }
    final white = game.whiteTurn;
    if (_selectedFrom == null) {
      // Select own checker or bar.
      if (hit == -2) {
        if (BgRules.barCount(game.pos, white) > 0) {
          final dests = game.destinationsFor(-1);
          if (dests.isNotEmpty) {
            audio.click();
            setState(() => _selectedFrom = -1);
          } else {
            audio.invalid();
          }
        }
        return;
      }
      if (hit >= 0 && BgRules.ownCount(game.pos, white, hit) > 0) {
        final dests = game.destinationsFor(hit);
        if (dests.isNotEmpty) {
          audio.click();
          setState(() => _selectedFrom = hit);
        } else {
          audio.invalid();
        }
      }
      return;
    }
    // A selection exists: tap a destination to move, or re-select.
    final dests = game.destinationsFor(_selectedFrom!);
    int? dest;
    if (hit == -3 && dests.contains(24)) {
      dest = 24;
    } else if (hit >= 0 && dests.contains(hit)) {
      dest = hit;
    }
    if (dest != null) {
      final ok = game.humanPlay(_selectedFrom!, dest);
      if (!ok) audio.invalid();
      setState(() => _selectedFrom = null);
      return;
    }
    // Re-select.
    if (hit == -2 && BgRules.barCount(game.pos, white) > 0) {
      setState(() => _selectedFrom = -1);
      return;
    }
    if (hit >= 0 && BgRules.ownCount(game.pos, white, hit) > 0) {
      final d2 = game.destinationsFor(hit);
      if (d2.isNotEmpty) {
        audio.click();
        setState(() => _selectedFrom = hit);
        return;
      }
    }
    audio.invalid();
    setState(() => _selectedFrom = null);
  }

  List<int> _destinations() {
    if (_selectedFrom == null) return const [];
    return game.destinationsFor(_selectedFrom!);
  }

  // -------------------------------------------------------------- dialogs
  void _maybeShowDoubleDialog() {
    if (_doubleDialogOpen || !mounted) return;
    if (game.phase != BgPhase.doubleOffer) return;
    final responderIdx = game.whiteTurn ? 1 : 0;
    if (game.players[responderIdx].isBot) return; // bot answers via engine
    _doubleDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.woodMid,
        title: Text('The cube is doubled!',
            style: Sultan.display(22, theme: t)),
        content: Text(
          '${game.players[responderIdx].name}, take the cube at ${game.cube.value * 2} — or pass and lose ${game.cube.value} point${game.cube.value == 1 ? '' : 's'}.',
          style: Sultan.body(15, theme: t),
        ),
        actions: [
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.pop(ctx);
              _doubleDialogOpen = false;
              game.respondDouble(accept: false);
            },
            child: Text('Pass',
                style: Sultan.label(16, theme: t)
                    .copyWith(color: const Color(0xFFD98880))),
          ),
          BrassButton(
            text: 'TAKE',
            small: true,
            theme: t,
            onTap: () {
              audio.click();
              Navigator.pop(ctx);
              _doubleDialogOpen = false;
              game.respondDouble(accept: true);
            },
          ),
        ],
      ),
    ).then((_) => _doubleDialogOpen = false);
  }

  void _showGameOver() {
    if (_overDialogOpen || !mounted || !game.gameOver) return;
    _overDialogOpen = true;
    final r = game.lastResult!;
    final winnerWhite = game.lastWinnerWhite;
    final winnerName =
        winnerWhite ? game.players[0].name : game.players[1].name;
    final kindLabel = r.kind == 'backgammon'
        ? 'BACKGAMMON ×${game.cube.value}'
        : r.kind == 'gammon'
            ? 'GAMMON ×${game.cube.value}'
            : r.kind == 'double-decline'
                ? 'DOUBLE DECLINED'
                : 'GAME ×${game.cube.value}';
    final matchDone = game.matchOver;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.woodMid,
        title: Text('$winnerName wins!',
            textAlign: TextAlign.center,
            style: Sultan.display(26, theme: t)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(kindLabel, style: Sultan.label(15, theme: t)),
            const SizedBox(height: 10),
            LeatherPlaque(
              theme: t,
              child: Text(
                '${game.players[0].name}  ${game.matchScore[0]} — ${game.matchScore[1]}  ${game.players[1].name}',
                style: Sultan.body(16, theme: t),
              ),
            ),
            if (matchDone) ...[
              const SizedBox(height: 10),
              Text(
                '${game.matchWinnerName} takes the match!',
                style: Sultan.label(16, theme: t),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!matchDone)
            BrassButton(
              text: 'NEXT GAME',
              small: true,
              theme: t,
              onTap: () {
                audio.click();
                Navigator.pop(ctx);
                _overDialogOpen = false;
                setState(() {
                  _selectedFrom = null;
                  _narration = 'A new game begins.';
                });
                game.newGame();
              },
            ),
          if (matchDone)
            BrassButton(
              text: 'NEW MATCH',
              small: true,
              theme: t,
              onTap: () {
                audio.click();
                Navigator.pop(ctx);
                _overDialogOpen = false;
                game.resetMatchScores();
                setState(() {
                  _selectedFrom = null;
                  _narration = 'A new match begins.';
                });
                game.newGame();
              },
            ),
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.pop(ctx);
              _overDialogOpen = false;
              Navigator.pop(context);
            },
            child: Text('Menu',
                style:
                    Sultan.label(15, theme: t).copyWith(color: t.ivory)),
          ),
        ],
      ),
    ).then((_) => _overDialogOpen = false);
  }

  void _undo() {
    if (game.undoTurn()) {
      audio.click();
      setState(() => _selectedFrom = null);
    } else {
      audio.invalid();
    }
  }
  void _showPause() {
    audio.click();
    game.setPaused(true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.woodMid,
        title: Text('Paused', style: Sultan.display(24, theme: t)),
        content: Text(
          '${game.players[0].name} ${game.matchScore[0]} — ${game.matchScore[1]} ${game.players[1].name}',
          style: Sultan.body(15, theme: t),
        ),
        actions: [
          BrassButton(
            text: 'RESUME',
            small: true,
            theme: t,
            onTap: () {
              audio.click();
              Navigator.pop(ctx);
              game.setPaused(false);
            },
          ),
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.pop(ctx);
              game.setPaused(false);
              setState(() => _selectedFrom = null);
              game.newGame();
            },
            child: Text('Restart',
                style:
                    Sultan.label(15, theme: t).copyWith(color: t.ivory)),
          ),
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Quit',
                style: Sultan.label(15, theme: t)
                    .copyWith(color: const Color(0xFFD98880))),
          ),
        ],
      ),
    ).then((_) {
      if (mounted && !game.gameOver) game.setPaused(false);
    });
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final white = game.players[0];
    final black = game.players[1];
    final activeWhite = game.whiteTurn;
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                theme: t,
                whiteName: white.name,
                blackName: black.name,
                scoreW: game.matchScore[0],
                scoreB: game.matchScore[1],
                matchLength: game.matchLength,
                crawford: game.crawford,
                onPause: _showPause,
              ),
              // Black's tray (top).
              _SideTray(
                theme: t,
                name: black.name,
                isBot: black.isBot,
                active: !activeWhite && !game.gameOver,
                white: false,
                dice: game.dice,
                rollOffValue: game.rollOffBlack,
                phase: game.phase,
                pip: BgRules.pipCount(game.pos, false),
                off: game.pos.blackOff,
                diceStyle: s.diceStyle,
                canRoll: false,
                canDouble: false,
                canUndo: false,
                onRoll: () {},
                onDouble: () {},
                onUndo: () {},
              ),
              // Board.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: AnimatedBuilder(
                    animation: _moveAnim,
                    builder: (_, _) => BackgammonBoard(
                      pos: game.pos,
                      cube: game.cube,
                      crawford: game.crawford,
                      theme: t,
                      checkerStyle: s.checkerStyle,
                      pointStyle: s.pointStyle,
                      selectedFrom: _selectedFrom,
                      destinations: _destinations(),
                      animMove: game.animMove,
                      animHit: game.animHit,
                      animT: _moveAnim.value,
                      whiteTurn: game.whiteTurn,
                      onTap: _onBoardTap,
                    ),
                  ),
                ),
              ),
              // Narration banner.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _narration.isEmpty
                      ? const SizedBox(height: 20, key: ValueKey('e'))
                      : LeatherPlaque(
                          key: ValueKey(_narration),
                          theme: t,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          child: Text(
                            _narration,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Sultan.body(13, theme: t).copyWith(
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                ),
              ),
              // White's tray (bottom).
              _SideTray(
                theme: t,
                name: white.name,
                isBot: white.isBot,
                active: activeWhite && !game.gameOver,
                white: true,
                dice: game.dice,
                rollOffValue: game.rollOffWhite,
                phase: game.phase,
                pip: BgRules.pipCount(game.pos, true),
                off: game.pos.whiteOff,
                diceStyle: s.diceStyle,
                canRoll: game.phase == BgPhase.awaitingDecision &&
                    !white.isBot &&
                    !game.gameOver,
                canDouble: game.canDoubleNow && !white.isBot,
                canUndo: (game.phase == BgPhase.awaitingMoves ||
                        game.phase == BgPhase.awaitingDecision) &&
                    !white.isBot &&
                    !game.gameOver,
                onRoll: () {
                  audio.click();
                  game.requestRoll();
                },
                onDouble: () {
                  if (game.offerDouble()) {
                    // dialog/sound handled via the double-offer event
                  } else {
                    audio.invalid();
                  }
                },
                onUndo: _undo,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: match score + pause
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final SultanThemeDef theme;
  final String whiteName, blackName;
  final int scoreW, scoreB, matchLength;
  final bool crawford;
  final VoidCallback onPause;
  const _Header({
    required this.theme,
    required this.whiteName,
    required this.blackName,
    required this.scoreW,
    required this.scoreB,
    required this.matchLength,
    required this.crawford,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.pause_circle_outline,
                color: theme.accentLight, size: 28),
            onPressed: onPause,
          ),
          Expanded(
            child: LeatherPlaque(
              theme: theme,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(whiteName,
                        overflow: TextOverflow.ellipsis,
                        style: Sultan.label(13, theme: theme)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$scoreW – $scoreB',
                      style: Sultan.display(20, theme: theme),
                    ),
                  ),
                  Flexible(
                    child: Text(blackName,
                        overflow: TextOverflow.ellipsis,
                        style: Sultan.label(13, theme: theme)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                matchLength == 1 ? 'Single' : 'To $matchLength',
                style: Sultan.label(11, theme: theme),
              ),
              if (crawford)
                Text('Crawford',
                    style: Sultan.label(10, theme: theme).copyWith(
                        color: theme.ivory.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-side tray: name, dice cup, roll/double controls, pip + borne-off counts
// ---------------------------------------------------------------------------

class _SideTray extends StatelessWidget {
  final SultanThemeDef theme;
  final String name;
  final bool isBot;
  final bool active;
  final bool white;
  final List<int> dice;
  final int rollOffValue;
  final BgPhase phase;
  final int pip;
  final int off;
  final int diceStyle;
  final bool canRoll;
  final bool canDouble;
  final bool canUndo;
  final VoidCallback onRoll;
  final VoidCallback onDouble;
  final VoidCallback onUndo;

  const _SideTray({
    required this.theme,
    required this.name,
    required this.isBot,
    required this.active,
    required this.white,
    required this.dice,
    required this.rollOffValue,
    required this.phase,
    required this.pip,
    required this.off,
    required this.diceStyle,
    required this.canRoll,
    required this.canDouble,
    required this.canUndo,
    required this.onRoll,
    required this.onDouble,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final rolling = active &&
        (phase == BgPhase.diceRolling || phase == BgPhase.rollOff);
    final colors = DiceStyles.colors(theme)[diceStyle];
    List<int> shown;
    if (phase == BgPhase.rollOff) {
      shown = rollOffValue > 0 ? [rollOffValue] : const [];
    } else if (dice.isEmpty) {
      shown = const [];
    } else {
      shown = dice.length > 2 ? dice.sublist(0, 2) : dice;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: active
              ? theme.accentLight
              : theme.accent.withValues(alpha: 0.35),
          width: active ? 2.5 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Name + bot badge.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: white
                            ? theme.checkerWhite
                            : theme.checkerBlack,
                        border:
                            Border.all(color: theme.accent, width: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: Sultan.label(14, theme: theme).copyWith(
                            color: active
                                ? theme.accentLight
                                : theme.ivory.withValues(alpha: 0.8),
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isBot
                      ? (active ? 'thinking…' : 'bot')
                      : (active ? 'your move' : ''),
                  style: Sultan.body(11, theme: theme).copyWith(
                      color: theme.ivory.withValues(alpha: 0.55),
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          // Dice cup.
          _DiceCup(
            values: shown,
            rolling: rolling,
            face: colors[0],
            pip: colors[1],
            doubles: dice.length == 4,
          ),
          const SizedBox(width: 10),
          // Pip + off counts.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('pip $pip', style: Sultan.label(11, theme: theme)),
              Text('off $off/15',
                  style: Sultan.body(11, theme: theme).copyWith(
                      color: theme.ivory.withValues(alpha: 0.7))),
            ],
          ),
          // Controls (human active side only).
          if (canRoll || canDouble) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canRoll)
                  _TrayButton(
                      label: 'ROLL', theme: theme, onTap: onRoll),
                if (canRoll && canDouble) const SizedBox(height: 6),
                if (canDouble)
                  _TrayButton(
                      label: 'DOUBLE', theme: theme, onTap: onDouble),
              ],
            ),
          ],
          // Undo (human, mid-turn).
          if (canUndo) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.undo,
                  color: theme.accentLight, size: 22),
              tooltip: 'Take back the turn',
              onPressed: onUndo,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrayButton extends StatelessWidget {
  final String label;
  final SultanThemeDef theme;
  final VoidCallback onTap;
  const _TrayButton({
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [theme.accentLight, theme.accent, theme.accentDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: theme.woodDeep, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 3),
              blurRadius: 5,
            ),
          ],
        ),
        child: Text(label,
            style: Sultan.label(14, theme: theme)
                .copyWith(color: theme.woodDeep)),
      ),
    );
  }
}

/// A side's dice cup: two dice with a live rolling animation.
class _DiceCup extends StatefulWidget {
  final List<int> values;
  final bool rolling;
  final bool doubles;
  final Color face;
  final Color pip;
  const _DiceCup({
    required this.values,
    required this.rolling,
    required this.doubles,
    required this.face,
    required this.pip,
  });

  @override
  State<_DiceCup> createState() => _DiceCupState();
}

class _DiceCupState extends State<_DiceCup> {
  final _rnd = Random();
  Timer? _t;
  List<int> _faces = [1, 1];

  @override
  void initState() {
    super.initState();
    _faces = widget.values.isEmpty ? [1, 1] : List.of(widget.values);
    _syncRolling();
  }

  @override
  void didUpdateWidget(covariant _DiceCup old) {
    super.didUpdateWidget(old);
    if (widget.rolling != old.rolling) _syncRolling();
    if (!widget.rolling && widget.values.isNotEmpty) {
      _faces = List.of(widget.values);
    }
  }

  void _syncRolling() {
    _t?.cancel();
    if (widget.rolling) {
      _t = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (!mounted) return;
        setState(() {
          _faces = [1 + _rnd.nextInt(6), 1 + _rnd.nextInt(6)];
        });
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.rolling
        ? _faces
        : (widget.values.isEmpty ? [0, 0] : _faces);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(
            color: widget.face.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            show[i] == 0
                ? SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.casino_outlined,
                        color:
                            widget.face.withValues(alpha: 0.3),
                        size: 28),
                  )
                : DiceFace(
                    value: show[i],
                    size: 34,
                    face: widget.face,
                    pip: widget.pip,
                  ),
          ],
          if (widget.doubles && !widget.rolling)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('×2',
                  style: TextStyle(
                      color: widget.pip,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
        ],
      ),
    );
  }
}
