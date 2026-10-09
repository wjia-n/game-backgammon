import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'pro_screen.dart';
import 'themes_screen.dart';

/// Main menu: Ottoman-luxury title plaque, mode selection, renameable
/// player slots, match length, and links to Themes / Settings / Pro.
class MenuScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  SultanSettings get s => widget.settings;
  SultanThemeDef get t => SultanThemes.byId(s.themeId, custom: s.customTheme);

  @override
  void initState() {
    super.initState();
    s.addListener(_refresh);
  }

  @override
  void dispose() {
    s.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _startGame() {
    widget.audio.gameStart();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(audio: widget.audio, settings: s),
      ),
    );
  }

  Future<void> _renamePlayer(int index) async {
    final ctrl = TextEditingController(text: s.playerNames[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.woodMid,
        title: Text(
          index == 0 ? 'Name the White player' : 'Name the Black player',
          style: Sultan.label(16, theme: t),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          style: Sultan.body(16, theme: t),
          decoration: InputDecoration(
            counterText: '',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: t.accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: t.accentLight, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: Sultan.label(14, theme: t).copyWith(color: t.ivory)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Save', style: Sultan.label(14, theme: t)),
          ),
        ],
      ),
    );
    if (result != null) {
      widget.audio.click();
      await s.setPlayerName(index, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // Title plaque.
                LeatherPlaque(
                  theme: t,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Text('BACKGAMMON',
                          textAlign: TextAlign.center,
                          style: Sultan.display(40, theme: t)),
                      const SizedBox(height: 4),
                      Text('THE SULTAN EDITION',
                          style: Sultan.label(13, theme: t)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Closed board case hero: the logo medallion.
                Center(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.accent, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/backgammon_logo.png',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 22),
                // Mode: vs Bot / 2 Players.
                _SectionTitle('MODE', t),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ModeCard(
                        title: 'Vs Bot',
                        subtitle: 'Challenge the Sultan',
                        selected: s.mode == 0,
                        theme: t,
                        onTap: () {
                          widget.audio.click();
                          s.setMode(0);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        title: '2 Players',
                        subtitle: 'Pass & play',
                        selected: s.mode == 1,
                        theme: t,
                        onTap: () {
                          widget.audio.click();
                          s.setMode(1);
                        },
                      ),
                    ),
                  ],
                ),
                if (s.mode == 0) ...[
                  const SizedBox(height: 12),
                  _SectionTitle('BOT SKILL', t),
                  const SizedBox(height: 8),
                  _DifficultyRow(
                    difficulty: s.difficulty,
                    isPro: s.isPro,
                    theme: t,
                    onPick: (d) {
                      widget.audio.click();
                      s.setDifficulty(d);
                    },
                    onProTap: () => _openPro(),
                  ),
                ],
                const SizedBox(height: 14),
                _SectionTitle('PLAYERS', t),
                const SizedBox(height: 8),
                _NameRow(
                  label: 'White',
                  swatch: t.checkerWhite,
                  name: s.playerNames[0],
                  theme: t,
                  onTap: () => _renamePlayer(0),
                ),
                const SizedBox(height: 8),
                _NameRow(
                  label: s.mode == 0 ? 'Black (Bot)' : 'Black',
                  swatch: t.checkerBlack,
                  name: s.playerNames[1],
                  theme: t,
                  onTap: () => _renamePlayer(1),
                ),
                const SizedBox(height: 14),
                _SectionTitle('MATCH', t),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 5, 7, 11].map((m) {
                    final sel = s.matchLength == m;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        s.setMatchLength(m);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: sel
                              ? t.accent.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.35),
                          border: Border.all(
                            color: sel ? t.accentLight : t.accent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          m == 1 ? 'Single' : 'To $m',
                          style: Sultan.label(14, theme: t).copyWith(
                            color: sel ? t.woodDeep : t.ivory,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                BrassButton(
                  text: 'PLAY',
                  theme: t,
                  fontSize: 22,
                  onTap: _startGame,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _IconLink(
                      icon: Icons.palette,
                      label: 'Themes',
                      theme: t,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ThemesScreen(
                              audio: widget.audio, settings: s),
                        ),
                      ),
                    ),
                    _IconLink(
                      icon: Icons.settings,
                      label: 'Settings',
                      theme: t,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                              audio: widget.audio, settings: s),
                        ),
                      ),
                    ),
                    _IconLink(
                      icon: Icons.workspace_premium,
                      label: s.isPro ? 'Pro ✓' : 'Go Pro',
                      theme: t,
                      onTap: _openPro,
                    ),
                    _IconLink(
                      icon: Icons.help_outline,
                      label: 'How to play',
                      theme: t,
                      onTap: () => _showHowTo(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'W ${s.wins}   ·   Games ${s.gamesPlayed}',
                    style: Sultan.body(13, theme: t)
                        .copyWith(color: t.ivory.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(audio: widget.audio, settings: s),
      ),
    );
  }

  void _showHowTo() {
    widget.audio.click();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.woodMid,
        title: Text('How to play', style: Sultan.display(22, theme: t)),
        content: SingleChildScrollView(
          child: Text(
            'Race all 15 checkers around the board and bear them off before your rival.\n\n'
            '• Tap the dice cup (or ROLL) to roll.\n'
            '• Tap a highlighted checker, then a glowing point, to move.\n'
            '• You must play both dice when you can — the higher die first if only one fits.\n'
            '• Landing on a lone enemy checker HITS it to the bar.\n'
            '• Checkers on the bar must re-enter before anything else moves.\n'
            '• Once all 15 are home, bear them off. First to clear all 15 wins!\n'
            '• The doubling cube raises the stakes — double before you roll if you dare.',
            style: Sultan.body(14, theme: t),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Play!', style: Sultan.label(15, theme: t)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final SultanThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Sultan.label(12, theme: theme)
            .copyWith(letterSpacing: 2.2));
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final SultanThemeDef theme;
  final VoidCallback onTap;
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? theme.accent.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? theme.accentLight : theme.accent.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(title,
                style: Sultan.label(16, theme: theme).copyWith(
                  color: selected ? theme.accentLight : theme.ivory,
                )),
            const SizedBox(height: 2),
            Text(subtitle,
                style: Sultan.body(12, theme: theme).copyWith(
                  color: theme.ivory.withValues(alpha: 0.65),
                )),
          ],
        ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final int difficulty;
  final bool isPro;
  final SultanThemeDef theme;
  final ValueChanged<int> onPick;
  final VoidCallback onProTap;
  const _DifficultyRow({
    required this.difficulty,
    required this.isPro,
    required this.theme,
    required this.onPick,
    required this.onProTap,
  });

  @override
  Widget build(BuildContext context) {
    const names = ['Easy', 'Medium', 'Hard'];
    return Row(
      children: List.generate(3, (i) {
        final locked = i == 2 && !isPro;
        final sel = difficulty == i && !locked;
        return Expanded(
          child: GestureDetector(
            onTap: () => locked ? onProTap() : onPick(i),
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: sel
                    ? theme.accent.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                  color: sel
                      ? theme.accentLight
                      : theme.accent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(names[i],
                      style: Sultan.label(13, theme: theme).copyWith(
                        color: sel ? theme.woodDeep : theme.ivory,
                      )),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.lock,
                        size: 13,
                        color: theme.accentLight
                            .withValues(alpha: 0.9)),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _NameRow extends StatelessWidget {
  final String label;
  final Color swatch;
  final String name;
  final SultanThemeDef theme;
  final VoidCallback onTap;
  const _NameRow({
    required this.label,
    required this.swatch,
    required this.name,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LeatherPlaque(
        theme: theme,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: swatch,
                border: Border.all(color: theme.accent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: Sultan.label(14, theme: theme)),
            const Spacer(),
            Text(name,
                style: Sultan.body(15, theme: theme)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Icon(Icons.edit,
                size: 15, color: theme.accent.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}

class _IconLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final SultanThemeDef theme;
  final VoidCallback onTap;
  const _IconLink({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.accentLight, theme.accent, theme.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: theme.woodDeep, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, color: theme.woodDeep, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: Sultan.label(11, theme: theme)),
        ],
      ),
    );
  }
}
