import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../audio.dart';
import '../settings.dart';

/// Settings as an open leather folio: brass toggles, brass sliders on
/// rosewood tracks with mother-of-pearl ticks, board-theme segmented plate.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final audio = BgAudio.instance;
    final s = BgSettings.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WoodBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        audio.click();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFD9B96A),
                              Color(0xFFB08D3E),
                              Color(0xFF8A6A2E)
                            ],
                          ),
                          border: Border.all(
                              color: BgTheme.engravedDark, width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: BgTheme.engravedDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('SETTINGS',
                          textAlign: TextAlign.center,
                          style: BgTheme.display.copyWith(fontSize: 19)),
                    ),
                    const SizedBox(width: 52),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: LeatherPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFD9B96A),
                                Color(0xFFB08D3E),
                                Color(0xFF8A6A2E)
                              ],
                            ),
                            border: Border.all(
                                color: BgTheme.engravedDark, width: 1.5),
                          ),
                          child: Text('AYARLAR · SETTINGS',
                              textAlign: TextAlign.center,
                              style: BgTheme.displayDark
                                  .copyWith(fontSize: 18)),
                        ),
                        const SizedBox(height: 18),
                        _toggleRow(
                          'Music',
                          'Oud & percussion in the salon',
                          audio.musicOn,
                          (v) {
                            audio.setMusic(v);
                            if (v) {
                              audio.playMusic('audio/music_menu.wav');
                            }
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        _toggleRow(
                          'Sound Effects',
                          'Dice rattle & wooden checkers',
                          audio.sfxOn,
                          (v) {
                            audio.setSfx(v);
                            if (v) audio.click();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 18),
                        const EngravedDivider(),
                        const SizedBox(height: 14),
                        _sliderRow(
                          'Music Volume',
                          audio.musicVolume,
                          (v) {
                            audio.setMusicVolume(v);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 14),
                        _sliderRow(
                          'SFX Volume',
                          audio.sfxVolume,
                          (v) {
                            audio.setSfxVolume(v);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 18),
                        const EngravedDivider(),
                        const SizedBox(height: 14),
                        Text('BOT STRENGTH',
                            style: BgTheme.caption),
                        const SizedBox(height: 8),
                        _segmented(
                          BgSettings.difficulties,
                          s.difficulty,
                          (i) {
                            s.setDifficulty(i);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('BOARD WOOD',
                            style: BgTheme.caption),
                        const SizedBox(height: 8),
                        _segmented(
                          BgSettings.themes,
                          s.boardTheme,
                          (i) {
                            s.setBoardTheme(i);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('MATCH LENGTH',
                            style: BgTheme.caption),
                        const SizedBox(height: 8),
                        _segmented(
                          BgSettings.matchLengths
                              .map((e) => 'First to $e')
                              .toList(),
                          BgSettings.matchLengths
                              .indexOf(s.matchLength),
                          (i) {
                            s.setMatchLength(
                                BgSettings.matchLengths[i]);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            '"Patience hides in the walnut board\'s embrace."',
                            textAlign: TextAlign.center,
                            style: BgTheme.bodyItalic.copyWith(
                                fontSize: 13,
                                color: BgTheme.brassHi),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: BrassButton(
                    label: 'BACK',
                    fontSize: 18,
                    onTap: () {
                      audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
      String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: BgTheme.engravedDark.withValues(alpha: 0.45),
        border: Border.all(color: BgTheme.brassDeep, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        BgTheme.display.copyWith(fontSize: 16)),
                Text(sub,
                    style: BgTheme.bodyItalic.copyWith(
                        fontSize: 12, color: BgTheme.brassHi)),
              ],
            ),
          ),
          BrassToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _sliderRow(
      String title, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: BgTheme.display.copyWith(fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD9B96A), Color(0xFFB08D3E)],
                ),
                border:
                    Border.all(color: BgTheme.engravedDark, width: 1),
              ),
              child: Text('${(value * 10).round()} / 10',
                  style: BgTheme.displayDark.copyWith(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            // mother-of-pearl ticks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                10,
                (i) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i / 10 <= value
                        ? BgTheme.pearl
                        : BgTheme.pearl.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 10,
                activeTrackColor: BgTheme.brassDeep,
                inactiveTrackColor:
                    const Color(0xFF241708).withValues(alpha: 0.0),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 15),
                thumbColor: BgTheme.brassHi,
                overlayColor:
                    BgTheme.brassHi.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segmented(
      List<String> options, int selected, ValueChanged<int> onTap) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: BgTheme.engravedDark.withValues(alpha: 0.5),
        border: Border.all(color: BgTheme.brassDeep, width: 1),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  BgAudio.instance.click();
                  onTap(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: i == selected
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFD9B96A),
                              Color(0xFFB08D3E)
                            ],
                          )
                        : null,
                    border: Border.all(
                        color: i == selected
                            ? BgTheme.engravedDark
                            : Colors.transparent,
                        width: 1),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: (i == selected
                            ? BgTheme.displayDark
                            : BgTheme.display)
                        .copyWith(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
