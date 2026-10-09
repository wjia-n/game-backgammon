import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';
import 'audio.dart';
import 'settings.dart';
import 'game_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BgAudio.instance.init();
  await BgSettings.instance.init();
  runApp(const BackgammonApp());
}

class BackgammonApp extends StatelessWidget {
  const BackgammonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backgammon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: BgTheme.vignette,
        fontFamily: BgTheme.bodyFamily,
      ),
      home: const MainMenu(),
    );
  }
}

/// Heirloom main menu: engraved title plaque, mother-of-pearl medallion with
/// physical checkers, brass plaque buttons.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BgAudio.instance.playMusic('audio/music_menu.wav');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      BgAudio.instance.stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      BgAudio.instance.playMusic('audio/music_menu.wav');
    }
  }

  void _play(bool vsBot) {
    BgAudio.instance.click();
    BgAudio.instance.playMusic('audio/music_game.wav');
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => BackgammonGameScreen(vsBot: vsBot)))
        .then((_) {
      BgAudio.instance.playMusic('audio/music_menu.wav');
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = BgSettings.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WoodBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✦  TAVLA SULTANI  ✦',
                      style: BgTheme.caption
                          .copyWith(letterSpacing: 4, fontSize: 13)),
                  const SizedBox(height: 10),
                  // hero: medallion + physical checkers
                  SizedBox(
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Medallion(size: 170),
                        const Positioned(
                            left: 8,
                            top: 30,
                            child: CheckerDisc(
                                white: true, diameter: 56)),
                        const Positioned(
                            left: 22,
                            top: 96,
                            child:
                                CheckerDisc(white: true, diameter: 56)),
                        const Positioned(
                            right: 8,
                            top: 44,
                            child: CheckerDisc(
                                white: false, diameter: 56)),
                        const Positioned(
                            right: 24,
                            top: 108,
                            child: CheckerDisc(
                                white: false, diameter: 56)),
                      ],
                    ),
                  ),
                  Text('BACKGAMMON',
                      textAlign: TextAlign.center,
                      style: BgTheme.display.copyWith(
                          fontSize: 40, letterSpacing: 4)),
                  const SizedBox(height: 4),
                  Text('DERSAADET · EST. 1884',
                      style: BgTheme.caption
                          .copyWith(letterSpacing: 3)),
                  const SizedBox(height: 6),
                  const EngravedDivider(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: BrassButton(
                      label: 'Play vs Bot',
                      sublabel: 'Test your craft against the machine',
                      icon: Icons.smart_toy,
                      onTap: () => _play(true),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: BrassButton(
                      label: '2 Players',
                      sublabel: 'Share the board, pass and play',
                      icon: Icons.people,
                      onTap: () => _play(false),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: BrassButton(
                      label: 'Settings',
                      sublabel: 'Music, sound, board & match',
                      icon: Icons.settings,
                      primary: false,
                      onTap: () {
                        BgAudio.instance.click();
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) =>
                                    const SettingsScreen()))
                            .then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'MATCH  ·  WHITE ${s.whiteMatch} — BLACK ${s.blackMatch}  ·  FIRST TO ${s.matchLength}',
                    textAlign: TextAlign.center,
                    style: BgTheme.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      BgAudio.instance.click();
                      s.resetMatch();
                      setState(() {});
                    },
                    child: Text('Reset match tally',
                        style: BgTheme.bodyItalic.copyWith(
                            fontSize: 12,
                            color: BgTheme.brass)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
