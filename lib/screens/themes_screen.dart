import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';
import 'pro_screen.dart';

/// Theme picker: 20 board themes + custom, 10 checker styles, 6 dice
/// styles, 3 point styles — all persisted, all in the Sultan material world.
class ThemesScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const ThemesScreen({super.key, required this.audio, required this.settings});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  SultanSettings get s => widget.settings;
  SultanThemeDef get t =>
      SultanThemes.byId(s.themeId, custom: s.customTheme);

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

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProScreen(audio: widget.audio, settings: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: t.accentLight, size: 26),
                      onPressed: () {
                        widget.audio.click();
                        Navigator.pop(context);
                      },
                    ),
                    Text('The Divan', style: Sultan.display(26, theme: t)),
                    const Spacer(),
                    if (!s.isPro)
                      GestureDetector(
                        onTap: _goPro,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: t.accent),
                            color: t.accent.withValues(alpha: 0.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock,
                                  size: 13, color: t.accentLight),
                              const SizedBox(width: 4),
                              Text('Go Pro',
                                  style: Sultan.label(12, theme: t)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  children: [
                    _section('BOARD THEMES'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.55,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: SultanThemes.all.length + 1,
                      itemBuilder: (_, i) {
                        if (i == SultanThemes.all.length) {
                          return _customCard();
                        }
                        final th = SultanThemes.all[i];
                        return _themeCard(th);
                      },
                    ),
                    const SizedBox(height: 18),
                    _section('CHECKER STYLES'),
                    const SizedBox(height: 8),
                    _styleRow(
                      count: CheckerStyles.count,
                      names: CheckerStyles.names,
                      selected: s.checkerStyle,
                      isPro: CheckerStyles.isPro,
                      swatch: (i) => _checkerSwatch(i),
                      onPick: (i) {
                        widget.audio.click();
                        s.setCheckerStyle(i);
                      },
                    ),
                    const SizedBox(height: 18),
                    _section('DICE STYLES'),
                    const SizedBox(height: 8),
                    _styleRow(
                      count: DiceStyles.count,
                      names: DiceStyles.names,
                      selected: s.diceStyle,
                      isPro: DiceStyles.isPro,
                      swatch: (i) => _diceSwatch(i),
                      onPick: (i) {
                        widget.audio.click();
                        s.setDiceStyle(i);
                      },
                    ),
                    const SizedBox(height: 18),
                    _section('POINT INLAY'),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (i) {
                        final sel = s.pointStyle == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              widget.audio.click();
                              s.setPointStyle(i);
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                  left: i == 0 ? 0 : 8),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(10),
                                color: sel
                                    ? t.accent
                                        .withValues(alpha: 0.9)
                                    : Colors.black
                                        .withValues(alpha: 0.35),
                                border: Border.all(
                                  color: sel
                                      ? t.accentLight
                                      : t.accent.withValues(
                                          alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                PointStyles.names[i],
                                textAlign: TextAlign.center,
                                style: Sultan.label(13, theme: t)
                                    .copyWith(
                                  color: sel
                                      ? t.woodDeep
                                      : t.ivory,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(title,
        style: Sultan.label(12, theme: t).copyWith(letterSpacing: 2.2));
  }

  Widget _themeCard(SultanThemeDef th) {
    final locked = !s.isPro && SultanThemes.isProTheme(th.id);
    final sel = s.themeId == th.id;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _goPro();
          return;
        }
        widget.audio.click();
        s.setTheme(th.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? t.accentLight : th.accent.withValues(alpha: 0.5),
            width: sel ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: th.woodDark,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _miniChecker(th.checkerWhite, th.accent),
                          const SizedBox(width: 8),
                          _miniChecker(th.checkerBlack, th.accent),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: th.woodMid,
                    alignment: Alignment.center,
                    child: Text(
                      th.name,
                      textAlign: TextAlign.center,
                      style: Sultan.label(11, theme: th),
                    ),
                  ),
                ),
              ],
            ),
            if (locked)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Icon(Icons.lock,
                      color: th.accentLight, size: 26),
                ),
              ),
            if (sel && !locked)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle,
                    color: th.accentLight, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customCard() {
    final sel = s.themeId == 'custom';
    return GestureDetector(
      onTap: () {
        if (!s.isPro) {
          _goPro();
          return;
        }
        widget.audio.click();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CustomThemeScreen(audio: widget.audio, settings: s),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? t.accentLight : t.accent.withValues(alpha: 0.5),
            width: sel ? 3 : 1.5,
          ),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.brush,
                color: s.isPro
                    ? t.accentLight
                    : t.ivory.withValues(alpha: 0.5),
                size: 28),
            const SizedBox(height: 6),
            Text('My Creation',
                style: Sultan.label(12, theme: t)),
            if (!s.isPro)
              Icon(Icons.lock,
                  size: 14,
                  color: t.accentLight.withValues(alpha: 0.9)),
          ],
        ),
      ),
    );
  }

  Widget _miniChecker(Color fill, Color ring) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  Widget _styleRow({
    required int count,
    required List<String> names,
    required int selected,
    required bool Function(int) isPro,
    required Widget Function(int) swatch,
    required ValueChanged<int> onPick,
  }) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final locked = !s.isPro && isPro(i);
          final sel = selected == i;
          return GestureDetector(
            onTap: () {
              if (locked) {
                _goPro();
                return;
              }
              onPick(i);
            },
            child: Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: sel
                    ? t.accent.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                  color: sel
                      ? t.accentLight
                      : t.accent.withValues(alpha: 0.4),
                  width: sel ? 2.5 : 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      swatch(i),
                      if (locked)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: Icon(Icons.lock,
                              size: 16, color: t.accentLight),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      names[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Sultan.label(10, theme: t),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _checkerSwatch(int i) {
    final white = i % 2 == 0;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: white ? t.checkerWhite : t.checkerBlack,
        border: Border.all(color: t.accent, width: 2),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: white ? t.accentDark : t.accentLight,
                width: 2),
          ),
        ),
      ),
    );
  }

  Widget _diceSwatch(int i) {
    final colors = DiceStyles.colors(t)[i];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: colors[0],
        border: Border.all(color: t.accent, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[1],
          ),
        ),
      ),
    );
  }
}

/// Custom theme creator: tune every material color of the set.
class CustomThemeScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  SultanSettings get s => widget.settings;

  static const _keys = [
    ('woodDark', 'Table wood'),
    ('woodMid', 'Board frame'),
    ('woodDeep', 'Vignette'),
    ('accent', 'Brass'),
    ('accentLight', 'Brass highlight'),
    ('felt', 'Felt bed'),
    ('pointLight', 'Light points'),
    ('pointDark', 'Dark points'),
    ('checkerWhite', 'White checkers'),
    ('checkerBlack', 'Black checkers'),
    ('ivory', 'Text ivory'),
  ];

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

  @override
  Widget build(BuildContext context) {
    final t = SultanThemes.byId('custom', custom: s.customTheme);
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: t.accentLight, size: 26),
                      onPressed: () {
                        widget.audio.click();
                        Navigator.pop(context);
                      },
                    ),
                    Text('My Creation',
                        style: Sultan.display(24, theme: t)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        widget.audio.click();
                        s.resetCustomColors();
                      },
                      child: Text('Reset',
                          style: Sultan.label(13, theme: t)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  children: [
                    for (final k in _keys)
                      _colorRow(t, k.$1, k.$2),
                    const SizedBox(height: 16),
                    BrassButton(
                      text: 'USE THIS THEME',
                      theme: t,
                      onTap: () {
                        widget.audio.click();
                        s.setTheme('custom');
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRow(SultanThemeDef t, String key, String label) {
    final argb = s.customColors[key] ?? 0xFF000000;
    final c = Color(argb);    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Sultan.body(14, theme: t))),
          _channel(t, 'R', (c.r * 255).round(), (v) => _set(key, argb, v, 16)),
          _channel(t, 'G', (c.g * 255).round(), (v) => _set(key, argb, v, 8)),
          _channel(t, 'B', (c.b * 255).round(), (v) => _set(key, argb, v, 0)),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: t.accent, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  void _set(String key, int argb, int v, int shift) {
    final mask = ~(0xFF << shift);
    s.setCustomColor(key, (argb & mask) | ((v & 0xFF) << shift));
  }

  Widget _channel(SultanThemeDef t, String label, int value,
      ValueChanged<int> onChanged) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Text('$label $value', style: Sultan.label(10, theme: t)),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: t.accent,
            onChanged: (v) {
              widget.audio.click();
              onChanged(v.round());
            },
          ),
        ],
      ),
    );
  }
}
