import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon/engine.dart';

void _custom(BgEngine e, Map<int, int> pts, {bool white = true}) {
  e.points = List.filled(24, 0);
  pts.forEach((k, v) => e.points[k] = v);
  e.whiteBar = e.blackBar = e.whiteOff = e.blackOff = 0;
  e.whiteTurn = white;
  e.dice = [];
}

void main() {
  test('standard starting position', () {
    final e = BgEngine()..reset();
    expect(e.points[23], 2);
    expect(e.points[12], 5);
    expect(e.points[7], 3);
    expect(e.points[5], 5);
    expect(e.points[0], -2);
    expect(e.points[11], -5);
    expect(e.points[16], -3);
    expect(e.points[18], -5);
  });

  test('doubles grant four moves', () {
    final e = BgEngine()..reset();
    e.rollDice([4, 4]);
    expect(e.dice, [4, 4, 4, 4]);
    e.rollDice([2, 5]);
    expect(e.dice, [2, 5]);
  });

  test('basic move consumes one die', () {
    final e = BgEngine();
    _custom(e, {10: 2, 0: -2, 23: -2});
    e.rollDice([3, 5]);
    final ms = e.movesForDie(3);
    expect(ms.any((m) => m.from == 10 && m.to == 7), true);
    e.doMove(ms.firstWhere((m) => m.from == 10 && m.to == 7));
    expect(e.points[10], 1);
    expect(e.points[7], 1);
    expect(e.dice, [5]);
  });

  test('hitting a blot sends it to the bar', () {
    final e = BgEngine();
    _custom(e, {10: 2, 7: -1, 0: -2});
    e.rollDice([3, 5]);
    final ms = e.movesForDie(3);
    expect(ms.any((m) => m.from == 10 && m.to == 7), true);
    e.doMove(ms.firstWhere((m) => m.from == 10 && m.to == 7));
    expect(e.points[7], 1);
    expect(e.blackBar, 1);
  });

  test('a made point blocks the move', () {
    final e = BgEngine();
    _custom(e, {10: 2, 7: -2, 0: -2});
    e.rollDice([3, 5]);
    expect(e.movesForDie(3).where((m) => m.from == 10 && m.to == 7), isEmpty);
  });

  test('bar checkers must re-enter first', () {
    final e = BgEngine();
    _custom(e, {10: 2, 0: -2});
    e.whiteBar = 1;
    e.rollDice([4, 2]);
    // white re-enters on 24-4 = 20
    final ms = e.movesForDie(4);
    expect(ms.length, 1);
    expect(ms.first.from, -1);
    expect(ms.first.to, 20);
    e.doMove(ms.first);
    expect(e.whiteBar, 0);
    expect(e.points[20], 1);
  });

  test('blocked re-entry point', () {
    final e = BgEngine();
    _custom(e, {10: 2, 0: -2, 20: -2, 22: -2});
    e.whiteBar = 1;
    e.rollDice([4, 2]);
    expect(e.movesForDie(4), isEmpty);
    expect(e.hasAnyMove, false);
  });

  test('exact bear off', () {
    final e = BgEngine();
    _custom(e, {0: 3, 2: 2}); // all in home
    e.rollDice([1, 6]);
    final ms = e.movesForDie(1);
    expect(ms.any((m) => m.from == 0 && m.to == 24), true);
    e.doMove(ms.firstWhere((m) => m.from == 0 && m.to == 24));
    expect(e.whiteOff, 1);
  });

  test('larger die bears off when no higher checkers', () {
    final e = BgEngine();
    _custom(e, {3: 2}); // needs 4, nothing above
    e.rollDice([6, 2]);
    final ms = e.movesForDie(6);
    expect(ms.any((m) => m.from == 3 && m.to == 24), true);
  });

  test('larger die cannot skip higher checkers', () {
    final e = BgEngine();
    _custom(e, {3: 1, 5: 1}); // checker on 5 is higher
    e.rollDice([6, 2]);
    expect(e.movesForDie(6).where((m) => m.from == 3 && m.to == 24), isEmpty);
    // but the checker on 5 can bear off with the 6
    expect(e.movesForDie(6).any((m) => m.from == 5 && m.to == 24), true);
  });

  test('no bear off until all checkers are home', () {
    final e = BgEngine();
    _custom(e, {0: 2, 10: 1}); // one checker outside home
    e.rollDice([1, 2]);
    expect(e.movesForDie(1).where((m) => m.to == 24), isEmpty);
  });

  test('bearing off the last checker wins', () {
    final e = BgEngine();
    _custom(e, {0: 1});
    e.whiteOff = 14;
    e.rollDice([1, 2]);
    final w = e.doMove(e.movesForDie(1).firstWhere((m) => m.to == 24));
    expect(w, 0);
    expect(e.whiteOff, 15);
  });
}
