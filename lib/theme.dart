import 'package:flutter/material.dart';

/// Ottoman luxury theme — "Tavla Sultani": mother-of-pearl inlay, aged brass,
/// stitched tan leather, deep walnut wood, warm candlelight. No neon, no glow.
class BgTheme {
  BgTheme._();

  // ---- Palette (from Stitch DESIGN.md) ----
  static const walnut = Color(0xFF3B2417);
  static const walnutDeep = Color(0xFF241409);
  static const rosewood = Color(0xFF5A3220);
  static const rosewoodDeep = Color(0xFF3E2114);
  static const brass = Color(0xFFB08D3E);
  static const brassDeep = Color(0xFF7A5F28);
  static const brassHi = Color(0xFFD9B96A);
  static const pearl = Color(0xFFEDE4D3);
  static const pearlShadow = Color(0xFFD8C9AE);
  static const leather = Color(0xFFA9713F);
  static const darkLeather = Color(0xFF5C3A22);
  static const engravedDark = Color(0xFF2E1E12);
  static const goldText = Color(0xFFE3C878);
  static const candle = Color(0xFFF5D9A0);
  static const vignette = Color(0xFF1A0F08);

  // Ebony board variant
  static const ebony = Color(0xFF171310);
  static const ebonyDeep = Color(0xFF0D0A08);

  static const displayFamily = 'EBGaramond';
  static const bodyFamily = 'EBGaramond';

  static TextStyle get display => const TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        color: goldText,
        letterSpacing: 3.0,
      );

  static TextStyle get displayDark => const TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        color: engravedDark,
        letterSpacing: 2.0,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: bodyFamily,
        color: pearl,
        fontSize: 15,
        height: 1.35,
      );

  static TextStyle get bodyItalic => body.copyWith(fontStyle: FontStyle.italic);

  static TextStyle get caption => const TextStyle(
        fontFamily: bodyFamily,
        color: brassHi,
        fontSize: 12,
        letterSpacing: 1.5,
      );

  static TextStyle get numeral => const TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        color: goldText,
        fontFeatures: [FontFeature.tabularFigures()],
      );

  // ---- Board palettes (Walnut / Ebony) ----
  static BoardPalette boardPalette(int theme) =>
      theme == 1 ? BoardPalette.ebony() : BoardPalette.walnut();
}

class BoardPalette {
  final Color frame;
  final Color frameDeep;
  final Color field;
  final Color pointLight;
  final Color pointDark;
  final Color bar;
  final Color inlay;

  const BoardPalette({
    required this.frame,
    required this.frameDeep,
    required this.field,
    required this.pointLight,
    required this.pointDark,
    required this.bar,
    required this.inlay,
  });

  factory BoardPalette.walnut() => const BoardPalette(
        frame: BgTheme.walnut,
        frameDeep: BgTheme.walnutDeep,
        field: Color(0xFF4A2E1B),
        pointLight: BgTheme.pearl,
        pointDark: BgTheme.rosewood,
        bar: BgTheme.darkLeather,
        inlay: BgTheme.brass,
      );

  factory BoardPalette.ebony() => const BoardPalette(
        frame: BgTheme.ebony,
        frameDeep: BgTheme.ebonyDeep,
        field: Color(0xFF1E1813),
        pointLight: BgTheme.pearl,
        pointDark: Color(0xFF2E2620),
        bar: Color(0xFF241C15),
        inlay: BgTheme.brass,
      );
}
