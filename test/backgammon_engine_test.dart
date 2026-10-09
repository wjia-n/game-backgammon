import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon/engine/backgammon_engine.dart';

BgPosition _custom(Map<int, int> pts,
    {int whiteBar = 0,
    int blackBar = 0,
    int whiteOff = 0,
    int blackOff = 0}) {
  final p = BgPosition();
  pts.forEach((k, v) => p.points[k] = v);
  p.whiteBar = whiteBar;
  p.blackBar = blackBar;
  p.whiteOff = whiteOff;
  p.blackOff = blackOff;
  return p;
}

void main() {
  group('setup', () {
    test('standard starting position', () {
      final p = BgPosition.initial();
      expect(p.points[23], 2);
      expect(p.points[12], 5);
      expect(p.points[7], 3);
      expect(p.points[5], 5);
      expect(p.points[0], -2);
      expect(p.points[11], -5);
      expect(p.points[16], -3);
      expect(p.points[18], -5);
      expect(BgRules.invariantHolds(p), isTrue);
    });
  });

  group('move generation', () {
    test('doubles grant four moves', () {
      final p = BgPosition.initial();
      final seqs = BgRules.legalSequences(p, true, [4, 4, 4, 4]);
      expect(seqs, isNotEmpty);
      expect(seqs.first.length, 4);
      for (final s in seqs) {
        expect(s.length, 4);
      }
    });

    test('blot hit sends checker to the bar', () {
      // White blot on the 10-point (idx 9); black on idx 3 moves 6 to hit.
      final p = _custom({9: 1, 3: -1}, whiteOff: 14, blackOff: 14);
      final seqs = BgRules.legalSequences(p, false, [6, 2]);
      expect(seqs, isNotEmpty);
      final np = p.clone();
      final hit = BgRules.applyMove(np, false, seqs.first.first);
      expect(hit, isTrue);
      expect(np.whiteBar, 1);
      expect(BgRules.invariantHolds(np), isTrue);
    });

    test('bar re-entry blocked on both dice forfeits the turn', () {
      // White on the bar; black owns 19-point (idx 18) and 24-point (idx 23).
      final p = _custom({18: -2, 23: -2}, whiteBar: 1, whiteOff: 14, blackOff: 11);
      final seqs = BgRules.legalSequences(p, true, [6, 1]);
      expect(seqs, isEmpty);
    });

    test('bar re-entry targets the right points', () {
      final p = _custom({}, whiteBar: 1, whiteOff: 14, blackOff: 15);
      final seqs = BgRules.legalSequences(p, true, [6, 1]);
      // die 6 -> idx 18 (point 19); die 1 -> idx 23 (point 24)
      final tos = seqs.expand((s) => s.map((m) => m.to)).toSet();
      expect(tos, containsAll([18, 23]));
      expect(seqs.every((s) => s.first.from == -1), isTrue);
    });

    test('made point blocks landing', () {
      // Black owns the 5-point (idx 4); white on idx 10 rolling 6.
      final p = _custom({10: 1, 4: -2}, whiteOff: 14, blackOff: 13);
      final seqs = BgRules.legalSequences(p, true, [6, 3]);
      for (final s in seqs) {
        for (final m in s) {
          expect(m.to, isNot(4));
        }
      }
    });

    test('forced higher die when only one is playable', () {
      // White on idx 10; black blocks idx 4 (6 away) AND idx 1 with made
      // points, so only the 3 (10->7) is playable — and playing it does
      // not unlock the 6.
      final p = _custom({10: 1, 4: -2, 1: -2}, whiteOff: 14, blackOff: 11);
      final seqs = BgRules.legalSequences(p, true, [6, 3]);
      expect(seqs, isNotEmpty);
      expect(seqs.every((s) => s.length == 1 && s.first.die == 3), isTrue);
    });

    test('order matters: finds the legal order', () {
      // White: checker on idx 10, checker on idx 5; black owns idx 4.
      // 10->4 (6) illegal; 10->6 (4) then 6->0 (6) legal.
      final p = _custom({10: 1, 5: 1, 4: -2}, whiteOff: 13, blackOff: 13);
      final seqs = BgRules.legalSequences(p, true, [6, 4]);
      expect(seqs, isNotEmpty);
      expect(seqs.any((s) => s.length == 2), isTrue);
    });

    test('hit during combined move is legal mid-sequence', () {
      // White on idx 12; black blot on idx 6. Roll 6-4: 12->6 hits the blot.
      final p = _custom({12: 1, 6: -1}, whiteOff: 14, blackOff: 14);
      final seqs = BgRules.legalSequences(p, true, [6, 4]);
      expect(seqs, isNotEmpty);
      final np = p.clone();
      var hit = false;
      for (final m in seqs.first) {
        hit = BgRules.applyMove(np, true, m) || hit;
      }
      expect(hit, isTrue);
      expect(np.blackBar, 1);
    });
  });

  group('bear-off', () {
    test('basic bear-off', () {
      final p = _custom({5: 2, 1: 1}, whiteOff: 12, blackOff: 15);
      final seqs = BgRules.legalSequences(p, true, [6, 2]);
      final offs = seqs
          .expand((s) => s)
          .where((m) => m.to == 24)
          .toSet();
      // Distinct bear-off options: 6 off the 6-point, 2 off the 2-point.
      expect(offs.length, 2);
      expect(offs, containsAll([
        const BgMove(5, 24, 6),
        const BgMove(1, 24, 2),
      ]));
    });

    test('bear off from highest occupied point when die too big', () {
      // Roll 6, checkers on 4-point (idx 3) and 2-point (idx 1).
      final p = _custom({3: 1, 1: 1}, whiteOff: 13, blackOff: 15);
      final seqs = BgRules.legalSequences(p, true, [6, 2]);
      // The 6 must come off the highest occupied point (the 4-point)
      // whenever it is played first.
      final firstSixes =
          seqs.where((s) => s.first.die == 6).map((s) => s.first).toList();
      expect(firstSixes, isNotEmpty);
      expect(
          firstSixes.every((m) => m.from == 3 && m.to == 24), isTrue);
    });

    test('forced move from higher point instead of bearing off', () {
      // Roll 2, checker on the 5-point (idx 4): must move to the 3-point.
      final p = _custom({4: 1}, whiteOff: 14, blackOff: 15);
      final seqs = BgRules.legalSequences(p, true, [2, 5]);
      final twos =
          seqs.expand((s) => s).where((m) => m.die == 2).toList();
      expect(twos, isNotEmpty);
      expect(twos.every((m) => m.from == 4 && m.to == 2), isTrue);
    });

    test('bear-off blocked while a checker is outside home', () {
      final p = _custom({5: 5, 12: 1}, whiteOff: 9, blackOff: 15);
      expect(BgRules.allInHome(p, true), isFalse);
      // A single die can never bear off while the checker is out.
      final single = BgRules.legalSequences(p, true, [6]);
      expect(single.expand((s) => s).where((m) => m.to == 24), isEmpty);
      // With four 6s the stray checker can be brought home first (12->6->0),
      // but no sequence may OPEN with a bear-off.
      final seqs = BgRules.legalSequences(p, true, [6, 6, 6, 6]);
      expect(seqs, isNotEmpty);
      expect(seqs.every((s) => s.first.to != 24), isTrue);
    });
  });

  group('scoring', () {
    test('single game scoring', () {
      final p = _custom({12: -8}, whiteOff: 15, blackOff: 7);
      final r = BgRules.scoreGame(p, true, 1);
      expect(r.points, 1);
      expect(r.kind, 'single');
    });

    test('gammon scoring', () {
      final p = _custom({12: -15}, whiteOff: 15, blackOff: 0);
      final r = BgRules.scoreGame(p, true, 1);
      expect(r.points, 2);
      expect(r.kind, 'gammon');
    });

    test('backgammon scoring (loser on the bar)', () {
      final p = _custom({12: -14}, whiteOff: 15, blackOff: 0, blackBar: 1);
      final r = BgRules.scoreGame(p, true, 1);
      expect(r.points, 3);
      expect(r.kind, 'backgammon');
    });

    test('backgammon scoring (loser in winner home)', () {
      final p = _custom({2: -1, 12: -14}, whiteOff: 15, blackOff: 0);
      final r = BgRules.scoreGame(p, true, 1);
      expect(r.points, 3);
      expect(r.kind, 'backgammon');
    });

    test('cube multiplies the score', () {
      final p = _custom({12: -15}, whiteOff: 15, blackOff: 0);
      final r = BgRules.scoreGame(p, true, 4);
      expect(r.points, 8);
    });
  });

  group('doubling cube', () {
    test('double offer flow: accept', () {
      final g = BgGame(players: [
        BgPlayer(name: 'W', isBot: false),
        BgPlayer(name: 'B', isBot: false),
      ]);
      g.newGame();
      g.cancelPendingTimers();
      g.phase = BgPhase.awaitingDecision;
      g.whiteTurn = true;
      expect(g.canDoubleNow, isTrue);
      expect(g.offerDouble(), isTrue);
      expect(g.phase, BgPhase.doubleOffer);
      g.respondDouble(accept: true);
      expect(g.cube.value, 2);
      expect(g.cube.owner, 1); // black took it
      expect(g.phase, BgPhase.awaitingDecision);
      g.dispose();
    });

    test('double decline ends the game at current stake', () {
      final g = BgGame(players: [
        BgPlayer(name: 'W', isBot: false),
        BgPlayer(name: 'B', isBot: false),
      ]);
      g.newGame();
      g.cancelPendingTimers();
      g.phase = BgPhase.awaitingDecision;
      g.whiteTurn = true;
      g.offerDouble();
      g.respondDouble(accept: false);
      expect(g.gameOver, isTrue);
      expect(g.lastResult!.points, 1);
      expect(g.lastResult!.kind, 'double-decline');
      expect(g.matchScore[0], 1);
      expect(g.lastWinnerWhite, isTrue);
      g.dispose();
    });

    test('cannot double twice in a row without owning the cube', () {
      final g = BgGame(players: [
        BgPlayer(name: 'W', isBot: false),
        BgPlayer(name: 'B', isBot: false),
      ]);
      g.newGame();
      g.cancelPendingTimers();
      g.phase = BgPhase.awaitingDecision;
      g.whiteTurn = true;
      g.offerDouble();
      g.respondDouble(accept: true);
      // White no longer owns the cube -> cannot double again.
      expect(g.canDoubleNow, isFalse);
      g.dispose();
    });

    test('crawford game disables the cube', () {
      final g = BgGame(
        players: [
          BgPlayer(name: 'W', isBot: false),
          BgPlayer(name: 'B', isBot: false),
        ],
        matchLength: 5,
      );
      g.matchScore[0] = 4;
      g.newGame();
      g.cancelPendingTimers();
      expect(g.crawford, isTrue);
      g.phase = BgPhase.awaitingDecision;
      expect(g.canDoubleNow, isFalse);
      expect(g.cubeDead, isTrue);
      g.dispose();
    });

    test('easy bot never doubles', () {
      final p = BgPosition.initial();
      for (int i = 0; i < 50; i++) {
        expect(BgAi.shouldDouble(p, true, 0, BgCube(), false), isFalse);
      }
    });
  });

  group('AI', () {
    test('opening book: 3-1 makes the 5-point at medium+', () {
      final p = BgPosition.initial();
      final seqs = BgRules.legalSequences(p, true, [3, 1]);
      final pick = BgAi.chooseSequence(p, true, seqs, [3, 1], 1,
          isOpening: true, rnd: Random(42));
      final sig = pick
          .take(2)
          .map((m) => '${m.from + 1}>${m.to + 1}')
          .join(',');
      expect(sig, '8>5,6>5');
    });

    test('AI always returns a legal maximal sequence', () {
      final rnd = Random(7);
      for (int i = 0; i < 30; i++) {
        final g = BgGame(
          players: [
            BgPlayer(name: 'W', isBot: true, difficulty: i % 3),
            BgPlayer(name: 'B', isBot: true, difficulty: (i + 1) % 3),
          ],
          rnd: Random(i),
        );
        for (int k = 0; k < 12; k++) {
          final d1 = 1 + rnd.nextInt(6), d2 = 1 + rnd.nextInt(6);
          final dice = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
          final white = k % 2 == 0;
          final seqs = BgRules.legalSequences(g.pos, white, dice);
          if (seqs.isNotEmpty) {
            final pick = BgAi.chooseSequence(
                g.pos, white, seqs, dice, i % 3,
                rnd: rnd);
            expect(seqs.any((s) => _sameSeq(s, pick)), isTrue,
                reason: 'AI returned an illegal sequence');
            for (final m in pick) {
              BgRules.applyMove(g.pos, white, m);
            }
          }
          expect(BgRules.invariantHolds(g.pos), isTrue);
        }
        g.dispose();
      }
    });
  });

  group('no stuck states: bot-vs-bot simulation', () {
    test('20 full games terminate with valid state', () {
      for (int gi = 0; gi < 20; gi++) {
        final g = BgGame(
          players: [
            BgPlayer(name: 'W', isBot: true, difficulty: gi % 3),
            BgPlayer(name: 'B', isBot: true, difficulty: (gi + 1) % 3),
          ],
          matchLength: 1,
          rnd: Random(1000 + gi),
        );
        var steps = 0;
        while (!g.gameOver && steps < 20000) {
          final advanced = g.autoStepSync();
          if (!advanced && !g.gameOver) {
            fail('stuck state at phase ${g.phase} in game $gi');
          }
          expect(BgRules.invariantHolds(g.pos), isTrue,
              reason: 'invariant broken in game $gi');
          steps++;
        }
        expect(g.gameOver, isTrue,
            reason: 'game $gi did not terminate in 20000 steps');
        expect(g.lastResult, isNotNull);
        expect(g.lastResult!.points, greaterThan(0));
        g.dispose();
      }
    });

    test('match play with Crawford terminates', () {
      final g = BgGame(
        players: [
          BgPlayer(name: 'W', isBot: true, difficulty: 1),
          BgPlayer(name: 'B', isBot: true, difficulty: 2),
        ],
        matchLength: 5,
        rnd: Random(99),
      );
      var games = 0;
      while (!g.matchOver && games < 12) {
        g.newGame();
        g.cancelPendingTimers();
      g.cancelPendingTimers();
        var steps = 0;
        while (!g.gameOver && steps < 20000) {
          final advanced = g.autoStepSync();
          if (!advanced && !g.gameOver) {
            fail('stuck state at phase ${g.phase}');
          }
          steps++;
        }
        expect(g.gameOver, isTrue);
        games++;
      }
      expect(g.matchOver, isTrue);
      expect(g.matchWinnerName, isNotEmpty);
      g.dispose();
    });
  });
}

bool _sameSeq(List<BgMove> a, List<BgMove> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
