import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BackgammonApp());

class BackgammonApp extends StatelessWidget {
  const BackgammonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Backgammon',
      tagline: 'Roll the dice, race home, and send rivals flying to the bar! 🎲',
      emoji: '🎯',
      slug: 'backgammon',
      howToPlay:
          '• Tap Roll, then tap one of your checkers and a glowing point to move.\n• Land on a lone enemy checker to HIT it to the bar! 💥\n• Checkers on the bar must re-enter before anything else moves.\n• Get all 15 checkers into your home board, then bear them off. First home wins! 🏁',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => BackgammonScreen(players: players, callbacks: cb),
    );
  }
}
