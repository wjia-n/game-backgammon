import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';

/// Settings: music/SFX toggles + volume sliders, player names, and stats.
class SettingsScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _rename(int index) async {
    final ctrl = TextEditingController(text: s.playerNames[index]);
    final focus = FocusNode();
    final original = s.playerNames[index];
    var committed = false;
    // Commit on focus loss (not just keyboard-done): persist the current
    // draft so the name is never lost, without closing the dialog.
    focus.addListener(() {
      if (!focus.hasFocus && !committed) {
        s.setPlayerName(index, ctrl.text);
      }
    });
    // Save on every keystroke so the rename is durable even if the dialog
    // is dismissed any other way.
    void persistDraft(String v) => s.setPlayerName(index, v);
    // Explicit commit: close the dialog with the final value.
    void commit(BuildContext ctx) {
      if (committed || !ctx.mounted) return;
      committed = true;
      widget.audio.click();
      Navigator.pop(ctx, ctrl.text);
    }

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.woodMid,
          title: Text('Player name',
              style: Sultan.label(16, theme: t)),
          content: TextField(
            controller: ctrl,
            focusNode: focus,
            autofocus: true,
            maxLength: 16,
            style: Sultan.body(16, theme: t),
            onChanged: persistDraft,
            onSubmitted: (_) => commit(ctx),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.accent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: t.accentLight, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                committed = true;
                Navigator.pop(ctx);
              },
              child: Text('Cancel',
                  style: Sultan.label(14, theme: t)
                      .copyWith(color: t.ivory)),
            ),
            TextButton(
              onPressed: () => commit(ctx),
              child: Text('Save', style: Sultan.label(14, theme: t)),
            ),
          ],
        ),
      );
      if (result != null) {
        await s.setPlayerName(index, result);
      } else {
        // Dismissed without committing (back button, tap outside, Cancel):
        // revert the keystroke saves so nothing half-typed sticks.
        await s.setPlayerName(index, original);
      }
    } finally {
      focus.dispose();
      ctrl.dispose();
    }
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
                    Text('Settings',
                        style: Sultan.display(26, theme: t)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  children: [
                    _row('Music', BrassToggle(
                      value: s.musicOn,
                      theme: t,
                      onChanged: (v) async {
                        await s.setMusic(v);
                        if (v) {
                          widget.audio.startMenuMusic();
                        } else {
                          widget.audio.stopMusic();
                        }
                      },
                    )),
                    _slider('Music volume', s.volume, (v) async {
                      await s.setVolume(v);
                    }),
                    const SizedBox(height: 8),
                    _row('Sound effects', BrassToggle(
                      value: s.sfxOn,
                      theme: t,
                      onChanged: (v) async {
                        await s.setSfx(v);
                        if (v) widget.audio.click();
                      },
                    )),
                    const SizedBox(height: 20),
                    Text('PLAYERS',
                        style: Sultan.label(12, theme: t)
                            .copyWith(letterSpacing: 2.2)),
                    const SizedBox(height: 8),
                    _nameRow(0, 'White'),
                    const SizedBox(height: 8),
                    _nameRow(1, 'Black'),
                    const SizedBox(height: 20),
                    Text('STATISTICS',
                        style: Sultan.label(12, theme: t)
                            .copyWith(letterSpacing: 2.2)),
                    const SizedBox(height: 8),
                    LeatherPlaque(
                      theme: t,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _stat('Won', '${s.wins}'),
                          _stat('Played', '${s.gamesPlayed}'),
                          _stat(
                              'Win %',
                              s.gamesPlayed == 0
                                  ? '—'
                                  : '${(100 * s.wins / s.gamesPlayed).round()}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text('Credits: WAJIHA',
                          style: Sultan.label(13, theme: t)),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Image.asset('assets/wajiha_logo.png',
                          width: 54, height: 54, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: Sultan.body(16, theme: t))),
          control,
        ],
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Sultan.body(14, theme: t)),
        Slider(
          value: value,
          min: 0,
          max: 1,
          activeColor: t.accent,
          inactiveColor: t.accent.withValues(alpha: 0.3),
          onChanged: (v) {
            widget.audio.configure(
                musicOn: s.musicOn, sfxOn: s.sfxOn, volume: v);
            onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _nameRow(int index, String side) {
    return GestureDetector(
      onTap: () => _rename(index),
      child: LeatherPlaque(
        theme: t,
        child: Row(
          children: [
            Text('$side  ', style: Sultan.label(14, theme: t)),
            Expanded(
              child: Text(s.playerNames[index],
                  style: Sultan.body(15, theme: t)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.edit,
                size: 15, color: t.accent.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: Sultan.display(24, theme: t)),
        Text(label, style: Sultan.label(11, theme: t)),
      ],
    );
  }
}
