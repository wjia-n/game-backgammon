import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';
import 'audio.dart';

/// Game-over / match screen: winner banner plaque, trophy medallion,
/// leather score plaque, Rematch / Main Menu brass plaques.
class GameOverScreen extends StatelessWidget {
  final String winnerName;
  final bool winnerIsWhite;
  final String kind; // Single game / Gammon / Backgammon / Double declined
  final int points;
  final int stake;
  final int whiteMatch;
  final int blackMatch;
  final int target;
  final bool matchWon;
  final int moveCount;
  final int hitCount;
  final VoidCallback onRematch;
  final VoidCallback onMenu;

  const GameOverScreen({
    super.key,
    required this.winnerName,
    required this.winnerIsWhite,
    required this.kind,
    required this.points,
    required this.stake,
    required this.whiteMatch,
    required this.blackMatch,
    required this.target,
    required this.matchWon,
    required this.moveCount,
    required this.hitCount,
    required this.onRematch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WoodBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TAVLA SULTANI',
                      style: BgTheme.caption.copyWith(letterSpacing: 4)),
                  const SizedBox(height: 8),
                  // winner banner plaque
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFD9B96A),
                          Color(0xFFB08D3E),
                          Color(0xFF8A6A2E)
                        ],
                      ),
                      border:
                          Border.all(color: BgTheme.engravedDark, width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 12,
                            offset: Offset(0, 6))
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          matchWon
                              ? 'MATCH WON'
                              : kind.toUpperCase(),
                          style: BgTheme.displayDark.copyWith(
                              fontSize: 14, letterSpacing: 3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$winnerName WINS!',
                          textAlign: TextAlign.center,
                          style: BgTheme.displayDark.copyWith(
                              fontSize: 30, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"The seal of victory is pressed in mother-of-pearl."',
                          textAlign: TextAlign.center,
                          style: BgTheme.bodyItalic.copyWith(
                              fontSize: 13,
                              color: BgTheme.engravedDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // trophy medallion
                  const Medallion(size: 84),
                  const SizedBox(height: 18),
                  // score plaque
                  LeatherPanel(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: BgTheme.brass, width: 1),
                            color: BgTheme.engravedDark
                                .withValues(alpha: 0.5),
                          ),
                          child: Text(
                            '$kind  ·  +$points ${points == 1 ? 'POINT' : 'POINTS'}',
                            style: BgTheme.display
                                .copyWith(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _scoreCell('White',
                                    whiteMatch, winnerIsWhite)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _scoreCell('Black',
                                    blackMatch, !winnerIsWhite)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('First to $target takes the match',
                            style: BgTheme.caption
                                .copyWith(fontSize: 10)),
                        const SizedBox(height: 8),
                        const EngravedDivider(),
                        const SizedBox(height: 8),
                        Text(
                          'Moves $moveCount   ·   Hits $hitCount   ·   Stake ×$stake',
                          style: BgTheme.body
                              .copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BrassButton(
                          label: matchWon ? 'NEW MATCH' : 'REMATCH',
                          sublabel: matchWon
                              ? 'Fresh tally'
                              : 'Next game',
                          fontSize: 18,
                          onTap: () {
                            BgAudio.instance.click();
                            onRematch();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrassButton(
                          label: 'MENU',
                          sublabel: 'Main menu',
                          fontSize: 18,
                          primary: false,
                          onTap: () {
                            BgAudio.instance.click();
                            onMenu();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreCell(String name, int score, bool isWinner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isWinner ? BgTheme.brassHi : BgTheme.brassDeep,
            width: isWinner ? 2 : 1),
        color:
            BgTheme.engravedDark.withValues(alpha: 0.45),
      ),
      child: Column(
        children: [
          Text(name.toUpperCase(), style: BgTheme.caption),
          const SizedBox(height: 4),
          Text('$score',
              style: BgTheme.numeral.copyWith(fontSize: 30)),
          Text(isWinner ? 'VICTOR' : 'YIELDED',
              style: BgTheme.caption.copyWith(
                  fontSize: 9,
                  color: isWinner
                      ? BgTheme.goldText
                      : BgTheme.brass)),
        ],
      ),
    );
  }
}
