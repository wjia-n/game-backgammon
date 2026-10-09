import 'package:flutter/material.dart';
import 'backgammon_themes.dart';

/// Tavla Sultani — the Stitch-derived design system for Backgammon.
/// Ottoman luxury: deep walnut, aged brass, mother-of-pearl, tan leather.
/// No neon, no cyberpunk, no generic Material look.
///
/// All widgets accept an optional [SultanThemeDef]; they default to the
/// Sultan Walnut theme so existing call sites keep working.
class Sultan {
  static const shadow = Color(0xFF1A0F08);

  static TextStyle display(double size,
          {Color? color, SultanThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFD9B96A),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: shadow, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, SultanThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFEDE4D3),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, SultanThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFD9B96A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([SultanThemeDef? t]) {
    t ??= SultanThemes.byId('walnut');
    final light = t.id == 'ivorygold' ||
        t.id == 'sandalwood' ||
        t.id == 'honeymaple' ||
        t.id == 'porcelain' ||
        t.id == 'sahara';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.woodDark,
      colorScheme: ColorScheme(
        brightness: light ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.woodDeep,
        secondary: t.accentLight,
        onSecondary: t.woodDeep,
        surface: t.woodMid,
        onSurface: t.ivory,
        error: const Color(0xFFB03A2E),
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.woodMid),
    );
  }
}

/// Walnut wood-grain background with a warm vignette, theme-aware.
class WoodBackdrop extends StatelessWidget {
  final Widget child;
  final SultanThemeDef? theme;
  const WoodBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? SultanThemes.byId('walnut');
    return Container(
      decoration: BoxDecoration(color: t.woodDark),
      child: CustomPaint(
        painter: _WoodGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final SultanThemeDef t;
  _WoodGrainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.woodMid.withValues(alpha: 0.55),
        t.woodDark.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.5),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = vignette.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
    // Wood grain streaks.
    final grain = Paint()
      ..color = t.woodDeep.withValues(alpha: 0.16)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 14; i++) {
      final y = size.height * (i + 0.5) / 14;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(size.width * 0.3, y + 6 * ((i % 3) - 1), size.width * 0.7,
            y - 6 * ((i % 2)), size.width, y + 4);
      canvas.drawPath(path, grain);
    }
    // Candlelight glow from upper-left.
    final glow = RadialGradient(
      center: const Alignment(-0.7, -0.8),
      radius: 0.8,
      colors: [
        const Color(0xFFF5D9A0).withValues(alpha: 0.10),
        const Color(0xFFF5D9A0).withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = glow.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter old) => old.t.id != t.id;
}

/// A brass-and-leather plaque button — the physical control of the UI.
class BrassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final SultanThemeDef? theme;
  final double fontSize;
  final bool small;
  const BrassButton({
    super.key,
    required this.text,
    this.onTap,
    this.theme,
    this.fontSize = 17,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? SultanThemes.byId('walnut');
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 18 : 30,
            vertical: small ? 10 : 15,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.accentLight, t.accent, t.accentDark],
            ),
            border: Border.all(color: t.woodDeep, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.18),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Sultan.label(fontSize, theme: t)
                .copyWith(color: t.woodDeep, letterSpacing: 1.4),
          ),
        ),
      ),
    );
  }
}

/// A dark leather plaque for labels/scores.
class LeatherPlaque extends StatelessWidget {
  final Widget child;
  final SultanThemeDef? theme;
  final EdgeInsets padding;
  const LeatherPlaque({
    super.key,
    required this.child,
    this.theme,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? SultanThemes.byId('walnut');
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: t.woodDeep.withValues(alpha: 0.85),
        border: Border.all(color: t.accent.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Brass toggle switch.
class BrassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final SultanThemeDef? theme;
  const BrassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? SultanThemes.byId('walnut');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value
              ? t.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: t.accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [t.accentLight, t.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
