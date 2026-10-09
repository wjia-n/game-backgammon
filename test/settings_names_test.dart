import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon/engine/backgammon_engine.dart';
import 'package:backgammon/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// two names came back in arbitrary order and White/Black got swapped.
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the prefs round-trip plus the game-screen rebuild path, without
/// needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Sultan Bot'];
    final decoded = SultanSettings.decodePlayerNames(
      SultanSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: index 0 is always White, index 1 Black.
    expect(decoded[0], 'Wajiha');
    expect(decoded[1], 'Sultan Bot');
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      SultanSettings.decodePlayerNames(null),
      SultanSettings.defaultNames,
    );
    expect(
      SultanSettings.decodePlayerNames('definitely not json'),
      SultanSettings.defaultNames,
    );
    expect(
      SultanSettings.decodePlayerNames('["only one"]'),
      SultanSettings.defaultNames,
    );
    expect(
      SultanSettings.decodePlayerNames('["a","b","c"]'),
      SultanSettings.defaultNames,
    );
    expect(
      SultanSettings.decodePlayerNames('{"a":1}'),
      SultanSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded = SultanSettings.decodePlayerNames('["Wajiha","  "]');
    expect(decoded, ['Wajiha', 'Sultan Bot']);
    final decoded2 = SultanSettings.decodePlayerNames('["",42]');
    expect(decoded2, ['You', 'Sultan Bot']);
  });

  test('JSON key preserves order where a StringSet would not', () {
    // The JSON string is order-preserving by construction: decoding the
    // exact persisted string always yields the same slot order.
    const names = ['Zara', 'Bot Bob'];
    final raw = SultanSettings.encodePlayerNames(names);
    for (int i = 0; i < 5; i++) {
      expect(SultanSettings.decodePlayerNames(raw), names);
    }
  });

  test('game players rebuilt after "restart" show the persisted names', () {
    // Simulate: user renamed the White player, app restarted, game screen
    // rebuilt its players from the persisted value.
    const renamed = ['Wajiha', 'Sultan Bot'];
    final persisted = SultanSettings.decodePlayerNames(
      SultanSettings.encodePlayerNames(renamed),
    );
    final players = [
      BgPlayer(name: persisted[0], isBot: false),
      BgPlayer(name: persisted[1], isBot: true),
    ];
    expect(players[0].name, 'Wajiha'); // White keeps slot 0
    expect(players[1].name, 'Sultan Bot'); // Black keeps slot 1
    expect(players[0].isBot, isFalse);
    expect(players[1].isBot, isTrue);
  });
}
