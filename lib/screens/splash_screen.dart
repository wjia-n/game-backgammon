import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';
import 'menu_screen.dart';

/// Launch splash: WAJIHA company splash, then the game splash
/// (logo + name + animated loading line + "Credits: WAJIHA").
class SplashScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the company splash shows, then menu music.
    widget.audio.prewarm();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _companyDone = true);
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SultanThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B08),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _companyDone
            ? _GameSplash(theme: theme, loader: _loader)
            : _CompanySplash(theme: theme),
      ),
    );
  }
}

/// Company splash: the official WAJIHA logo, untouched.
class _CompanySplash extends StatelessWidget {
  final SultanThemeDef theme;
  const _CompanySplash({required this.theme});

  @override
  Widget build(BuildContext context) {
    return WoodBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (_, v, _) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + 0.15 * v,
                  child: Image.asset(
                    'assets/wajiha_logo.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('WAJIHA', style: Sultan.display(34, theme: theme)),
          ],
        ),
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final SultanThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return WoodBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/backgammon_logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 22),
            Text('Backgammon', style: Sultan.display(48, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'THE SULTAN EDITION',
              style: Sultan.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1
                          ? 'Setting the pieces…'
                          : 'Ready!',
                      style: Sultan.body(13,
                          theme: theme,
                          color: theme.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Sultan.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
