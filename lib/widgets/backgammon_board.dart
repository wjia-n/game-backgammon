import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/backgammon_engine.dart';
import '../theme/backgammon_themes.dart';

/// Geometry of the backgammon board for a given size.
///
/// Top row (y small): indices 12..23 left -> right (Black marches left->right).
/// Bottom row (y large): indices 11..6, bar, 5..0 left -> right
/// (White marches right->left along the bottom).
class BoardLayout {
  final Size size;
  late final double frame;
  late final double barW;
  late final double pointW;
  late final double pointH;
  late final double checkerR;

  BoardLayout(this.size) {
    frame = (size.width * 0.045).clamp(10.0, 22.0);
    pointW = size.width * 0.068;
    barW = size.width - 2 * frame - 12 * pointW;
    pointH = size.height * 0.40;
    checkerR = pointW * 0.47;
  }

  double _colX(int c) =>
      frame + pointW * (c + 0.5) + (c >= 6 ? barW : 0);

  /// Column 0..11 for a point index.
  int _col(int idx) => idx >= 12 ? idx - 12 : 11 - idx;

  /// Base center of a point (where the first checker sits).
  Offset pointBase(int idx) {
    final x = _colX(_col(idx));
    final y = idx >= 12 ? frame + checkerR + 4 : size.height - frame - checkerR - 4;
    return Offset(x, y);
  }

  /// Center of the [stack]-th checker on [idx] (0 = base).
  Offset checkerAt(int idx, int stack) {
    final base = pointBase(idx);
    final dir = idx >= 12 ? 1.0 : -1.0;
    return Offset(base.dx, base.dy + dir * stack * checkerR * 1.66);
  }

  Offset barCenter(bool white, int stack) {
    final x = size.width / 2;
    final y = size.height / 2 + (white ? 1 : -1) * (14 + stack * checkerR * 1.5);
    return Offset(x, y);
  }

  /// Borne-off stacks live on the right edge strip.
  Offset offCenter(bool white, int stack) {
    final x = size.width - frame * 0.5;
    final baseY = white
        ? size.height - frame - checkerR - 4
        : frame + checkerR + 4;
    final dir = white ? -1.0 : 1.0;
    return Offset(x, baseY + dir * (stack % 8) * checkerR * 1.1);
  }

  /// Doubling-cube resting spot: center of the bar, or the owner's side.
  Offset cubeCenter(int owner) {
    // owner: -1 centered, 0 white, 1 black
    final x = size.width / 2;
    final y = owner == 0
        ? size.height - frame - 34
        : owner == 1
            ? frame + 34
            : size.height / 2;
    return Offset(x, y);
  }

  /// Hit-test a tap. Returns a point index 0..23, -2 = bar, -3 = off strip.
  int hitTest(Offset p) {
    if (p.dx > size.width - frame) return -3; // off strip
    if ((p.dx - size.width / 2).abs() < barW / 2 + 6 &&
        (p.dy - size.height / 2).abs() < size.height * 0.22) {
      return -2; // bar
    }
    final top = p.dy < size.height / 2;
    double x = p.dx - frame;
    if (x < 0) return -1;
    int c = (x / pointW).floor();
    // Account for the bar gap: x positions past the gap shift by barW.
    if (p.dx > size.width / 2 + barW / 2) {
      c = ((p.dx - frame - barW) / pointW).floor();
    } else if (p.dx > size.width / 2 - barW / 2) {
      return -1;
    }
    if (c < 0 || c > 11) return -1;
    return top ? 12 + c : 11 - c;
  }
}

// ---------------------------------------------------------------------------
// Checkers
// ---------------------------------------------------------------------------

/// Draws one physical checker disc in the given style.
void drawChecker(
  Canvas canvas,
  Offset c,
  double r,
  Color base,
  int style,
  SultanThemeDef theme,
) {
  // Contact shadow.
  canvas.drawOval(
    Rect.fromCenter(center: c + Offset(0, r * 0.16), width: r * 1.9, height: r * 1.7),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );
  final dark = _shade(base, 0.55);
  final light = _shade(base, 1.28);

  void disc(Color fill) {
    canvas.drawCircle(c, r, Paint()..color = dark);
    canvas.drawCircle(c, r * 0.92, Paint()..color = fill);
    // Bevel highlight (candlelight from upper-left).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      3.4,
      2.2,
      false,
      Paint()
        ..color = light.withValues(alpha: 0.75)
        ..strokeWidth = r * 0.10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  switch (style) {
    case 1: // Pearl Ring
      disc(base);
      canvas.drawCircle(
          c,
          r * 0.52,
          Paint()
            ..color = const Color(0xFFF6EFDD)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.16);
      break;
    case 2: // Brass Rim
      disc(base);
      canvas.drawCircle(
          c,
          r * 0.80,
          Paint()
            ..color = theme.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14);
      break;
    case 3: // Engraved Star
      disc(base);
      final star = Paint()
        ..color = dark.withValues(alpha: 0.9)
        ..strokeWidth = r * 0.07
        ..style = PaintingStyle.stroke;
      for (int k = 0; k < 4; k++) {
        final a = k * 3.14159 / 4;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * r * 0.52,
          c - Offset(cos(a), sin(a)) * r * 0.52,
          star,
        );
      }
      break;
    case 4: // Domed Jewel
      final grad = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [light, base, dark],
      );
      canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..shader = grad.createShader(Rect.fromCircle(center: c, radius: r)));
      canvas.drawCircle(c, r * 0.20, Paint()..color = light.withValues(alpha: 0.9));
      break;
    case 5: // Hex Token
      final hex = Path();
      for (int k = 0; k < 6; k++) {
        final a = k * 3.14159 / 3 + 0.52;
        final p = c + Offset(cos(a), sin(a)) * r * 0.92;
        if (k == 0) {
          hex.moveTo(p.dx, p.dy);
        } else {
          hex.lineTo(p.dx, p.dy);
        }
      }
      hex.close();
      canvas.drawPath(hex, Paint()..color = dark);
      final hex2 = Path();
      for (int k = 0; k < 6; k++) {
        final a = k * 3.14159 / 3 + 0.52;
        final p = c + Offset(cos(a), sin(a)) * r * 0.78;
        if (k == 0) {
          hex2.moveTo(p.dx, p.dy);
        } else {
          hex2.lineTo(p.dx, p.dy);
        }
      }
      hex2.close();
      canvas.drawPath(hex2, Paint()..color = base);
      break;
    case 6: // Minted Coin
      disc(base);
      for (int k = 0; k < 24; k++) {
        final a = k * 3.14159 / 12;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * r * 0.86,
          c + Offset(cos(a), sin(a)) * r * 0.94,
          Paint()
            ..color = dark
            ..strokeWidth = r * 0.05,
        );
      }
      canvas.drawCircle(
          c,
          r * 0.55,
          Paint()
            ..color = dark.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06);
      break;
    case 7: // Rose Carve
      disc(base);
      final rose = Paint()
        ..color = dark.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06;
      canvas.drawCircle(c, r * 0.50, rose);
      canvas.drawCircle(c, r * 0.30, rose);
      canvas.drawCircle(c, r * 0.12, Paint()..color = dark.withValues(alpha: 0.8));
      break;
    case 8: // Onyx Dome
      final grad = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.0,
        colors: [_shade(base, 1.5), base, _shade(base, 0.4)],
      );
      canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..shader = grad.createShader(Rect.fromCircle(center: c, radius: r)));
      canvas.drawCircle(
          c,
          r * 0.66,
          Paint()
            ..color = theme.accentLight.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08);
      break;
    case 9: // Mother Pearl
      final grad = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.1,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFF1E8D2),
          Color(0xFFD9C9A8),
        ],
      );
      canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..shader = grad.createShader(Rect.fromCircle(center: c, radius: r)));
      canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08);
      break;
    case 0:
    default: // Sultan Disc
      disc(base);
      canvas.drawCircle(
          c,
          r * 0.60,
          Paint()
            ..color = dark.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07);
  }
}

Color _shade(Color c, double f) {
  int r = (c.r * 255.0 * f).clamp(0, 255).round();
  int g = (c.g * 255.0 * f).clamp(0, 255).round();
  int b = (c.b * 255.0 * f).clamp(0, 255).round();
  return Color.fromARGB(255, r, g, b);
}

// ---------------------------------------------------------------------------
// Dice
// ---------------------------------------------------------------------------

class DiceFace extends StatelessWidget {
  final int value; // 1..6
  final double size;
  final Color face;
  final Color pip;
  const DiceFace({
    super.key,
    required this.value,
    required this.size,
    required this.face,
    required this.pip,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DicePainter(value, face, pip),
    );
  }
}

class _DicePainter extends CustomPainter {
  final int value;
  final Color face, pip;
  _DicePainter(this.value, this.face, this.pip);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 2), width: size.width * 0.96, height: size.width * 0.9),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(rect, Paint()..color = _shade(face, 0.6));
    canvas.drawRRect(
      rect.deflate(1.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shade(face, 1.18), face, _shade(face, 0.85)],
        ).createShader(rect.outerRect),
    );
    const pos = {
      1: [[0.0, 0.0]],
      2: [
        [-0.24, -0.24],
        [0.24, 0.24]
      ],
      3: [
        [-0.26, -0.26],
        [0.0, 0.0],
        [0.26, 0.26]
      ],
      4: [
        [-0.24, -0.24],
        [0.24, -0.24],
        [-0.24, 0.24],
        [0.24, 0.24]
      ],
      5: [
        [-0.26, -0.26],
        [0.26, -0.26],
        [0.0, 0.0],
        [-0.26, 0.26],
        [0.26, 0.26]
      ],
      6: [
        [-0.26, -0.26],
        [0.26, -0.26],
        [-0.26, 0.0],
        [0.26, 0.0],
        [-0.26, 0.26],
        [0.26, 0.26]
      ],
    };
    final pr = size.width * 0.085;
    for (final xy in pos[value] ?? const []) {
      final pc = Offset(c.dx + xy[0] * size.width, c.dy + xy[1] * size.height);
      canvas.drawCircle(pc + const Offset(0, 1), pr, Paint()..color = Colors.black.withValues(alpha: 0.4));
      canvas.drawCircle(pc, pr, Paint()..color = pip);
      canvas.drawCircle(
          pc + Offset(-pr * 0.3, -pr * 0.3), pr * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter old) =>
      old.value != value || old.face != face || old.pip != pip;
}

// ---------------------------------------------------------------------------
// Board
// ---------------------------------------------------------------------------

/// The backgammon board: felt bed, 24 inlaid points, bar, off strips,
/// doubling cube, checkers, selection highlights and move animation.
class BackgammonBoard extends StatelessWidget {
  final BgPosition pos;
  final BgCube cube;
  final bool crawford;
  final SultanThemeDef theme;
  final int checkerStyle;
  final int pointStyle;
  final int? selectedFrom; // point idx, or -1 = bar
  final List<int> destinations; // point idx, or 24 = bear off
  final BgMove? animMove;
  final bool animHit;
  final double animT; // 0..1
  final bool whiteTurn;
  final void Function(int hit)? onTap; // hit-test code

  const BackgammonBoard({
    super.key,
    required this.pos,
    required this.cube,
    required this.crawford,
    required this.theme,
    required this.checkerStyle,
    required this.pointStyle,
    this.selectedFrom,
    this.destinations = const [],
    this.animMove,
    this.animHit = false,
    this.animT = 0,
    required this.whiteTurn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final layout = BoardLayout(
            Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final hit = layout.hitTest(d.localPosition);
            onTap?.call(hit);
          },
          child: CustomPaint(
            painter: _BoardPainter(
              pos: pos,
              cube: cube,
              crawford: crawford,
              theme: theme,
              checkerStyle: checkerStyle,
              pointStyle: pointStyle,
              selectedFrom: selectedFrom,
              destinations: destinations,
              animMove: animMove,
              animHit: animHit,
              animT: animT,
              whiteTurn: whiteTurn,
              layout: layout,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BgPosition pos;
  final BgCube cube;
  final bool crawford;
  final SultanThemeDef theme;
  final int checkerStyle;
  final int pointStyle;
  final int? selectedFrom;
  final List<int> destinations;
  final BgMove? animMove;
  final bool animHit;
  final double animT;
  final bool whiteTurn;
  final BoardLayout layout;

  _BoardPainter({
    required this.pos,
    required this.cube,
    required this.crawford,
    required this.theme,
    required this.checkerStyle,
    required this.pointStyle,
    required this.selectedFrom,
    required this.destinations,
    required this.animMove,
    required this.animHit,
    required this.animT,
    required this.whiteTurn,
    required this.layout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    // Frame.
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(14),
    );
    canvas.drawRRect(
        frameRect, Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawRRect(
      frameRect.deflate(3),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.woodMid, t.woodDark, t.woodMid],
        ).createShader(frameRect.outerRect),
    );
    // Brass corner brackets.
    final br = Paint()..color = t.accent;
    for (final dx in [10.0, size.width - 10.0]) {
      for (final dy in [10.0, size.height - 10.0]) {
        canvas.drawCircle(Offset(dx, dy), 4, br);
      }
    }
    // Felt bed.
    final bed = Rect.fromLTWH(layout.frame, layout.frame,
        size.width - 2 * layout.frame, size.height - 2 * layout.frame);
    canvas.drawRect(bed, Paint()..color = t.felt);
    // Subtle felt texture.
    final feltShade = Paint()..color = Colors.black.withValues(alpha: 0.12);
    for (int i = 0; i < 40; i++) {
      final y = bed.top + (bed.height * (i * 37 % 40) / 40);
      canvas.drawLine(Offset(bed.left, y), Offset(bed.right, y), feltShade);
    }

    // Points.
    for (int idx = 0; idx < 24; idx++) {
      _drawPoint(canvas, idx);
    }
    // Bar.
    final barRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: layout.barW,
      height: size.height - 2 * layout.frame,
    );
    canvas.drawRect(
        barRect,
        Paint()
          ..shader = LinearGradient(
            colors: [t.woodMid, t.woodDark],
          ).createShader(barRect));
    canvas.drawRect(
        barRect, Paint()..color = Colors.black.withValues(alpha: 0.25));
    // Bar separators.
    canvas.drawLine(
      Offset(barRect.left, size.height / 2),
      Offset(barRect.right, size.height / 2),
      Paint()
        ..color = t.accent.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // Off strips (right edge).
    _drawOffStrip(canvas, true);
    _drawOffStrip(canvas, false);

    // Checkers on points.
    for (int idx = 0; idx < 24; idx++) {
      _drawStack(canvas, idx);
    }
    // Bar checkers.
    _drawBarStack(canvas, true);
    _drawBarStack(canvas, false);

    // Selection + destinations.
    _drawSelection(canvas);

    // Move animation (flying checker).
    _drawAnim(canvas);

    // Doubling cube.
    _drawCube(canvas);
  }

  void _drawPoint(Canvas canvas, int idx) {
    final t = theme;
    final top = idx >= 12;
    final c = (idx >= 12 ? idx - 12 : 11 - idx);
    final x0 = layout.frame + layout.pointW * c + (c >= 6 ? layout.barW : 0);
    final yBase = top ? layout.frame : layout.size.height - layout.frame;
    final dir = top ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(x0, yBase)
      ..lineTo(x0 + layout.pointW, yBase)
      ..lineTo(x0 + layout.pointW / 2, yBase + dir * layout.pointH)
      ..close();
    final alt = (idx % 2 == 0);
    var fill = alt ? t.pointLight : t.pointDark;
    if (pointStyle == 2) {
      fill = alt
          ? const Color(0xFFF1E8D2)
          : const Color(0xFFD9C9A8);
    }
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    if (pointStyle == 1) {
      // Brass inlay border.
      final inset = Path()
        ..moveTo(x0 + 3, yBase)
        ..lineTo(x0 + layout.pointW - 3, yBase)
        ..lineTo(x0 + layout.pointW / 2, yBase + dir * (layout.pointH - 6))
        ..close();
      canvas.drawPath(
          inset,
          Paint()
            ..color = t.accent.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  void _drawStack(Canvas canvas, int idx) {
    final n = pos.points[idx];
    if (n == 0) return;
    final white = n > 0;
    final count = n.abs();
    final shown = count > 5 ? 5 : count;
    for (int s = 0; s < shown; s++) {
      // Skip the checker that is currently flying.
      if (animMove != null && animMove!.from == idx && s == shown - 1) {
        continue;
      }
      final ctr = layout.checkerAt(idx, s);
      drawChecker(canvas, ctr, layout.checkerR,
          white ? theme.checkerWhite : theme.checkerBlack, checkerStyle, theme);
    }
    if (count > 5) {
      final ctr = layout.checkerAt(idx, 4);
      _countBadge(canvas, ctr, count);
    }
  }

  void _drawBarStack(Canvas canvas, bool white) {
    final n = white ? pos.whiteBar : pos.blackBar;
    for (int s = 0; s < n; s++) {
      // The checker currently flying in from the bar is drawn by _drawAnim.
      if (animMove != null &&
          animMove!.from == -1 &&
          s == n - 1 &&
          ((white && whiteTurn) || (!white && !whiteTurn))) {
        continue;
      }
      drawChecker(
          canvas,
          layout.barCenter(white, s),
          layout.checkerR,
          white ? theme.checkerWhite : theme.checkerBlack,
          checkerStyle,
          theme);
    }
  }

  void _drawOffStrip(Canvas canvas, bool white) {
    final t = theme;
    final n = white ? pos.whiteOff : pos.blackOff;
    final shown = n > 8 ? 8 : n;
    for (int s = 0; s < shown; s++) {
      drawChecker(
          canvas,
          layout.offCenter(white, s),
          layout.checkerR * 0.8,
          white ? t.checkerWhite : t.checkerBlack,
          checkerStyle,
          t);
    }
    if (n > 8) {
      _countBadge(canvas, layout.offCenter(white, 7), n);
    }
  }

  void _countBadge(Canvas canvas, Offset c, int n) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 30, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.75));
    canvas.drawRRect(
        rect,
        Paint()
          ..color = theme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final tp = TextPainter(
      text: TextSpan(
          text: '$n',
          style: TextStyle(
              color: theme.accentLight,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawSelection(Canvas canvas) {
    final t = theme;
    // Selected checker glow.
    if (selectedFrom != null) {
      Offset c;
      if (selectedFrom == -1) {
        final n = whiteTurn ? pos.whiteBar : pos.blackBar;
        c = layout.barCenter(whiteTurn, n > 0 ? n - 1 : 0);
      } else {
        final n = pos.points[selectedFrom!].abs();
        c = layout.checkerAt(selectedFrom!, n > 5 ? 4 : n - 1);
      }
      canvas.drawCircle(
          c,
          layout.checkerR * 1.25,
          Paint()
            ..color = t.accentLight.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    // Destination glows.
    for (final d in destinations) {
      if (d == 24) {
        final c = layout.offCenter(whiteTurn, 0);
        canvas.drawCircle(
            c,
            layout.checkerR * 1.3,
            Paint()
              ..color = t.accentLight.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        continue;
      }
      final base = layout.pointBase(d);
      final top = d >= 12;
      final tipY = base.dy + (top ? 1 : -1) * layout.pointH * 0.55;
      canvas.drawCircle(
          Offset(base.dx, tipY),
          layout.checkerR * 0.9,
          Paint()..color = t.accentLight.withValues(alpha: 0.55));
      canvas.drawCircle(
          Offset(base.dx, tipY),
          layout.checkerR * 0.9,
          Paint()
            ..color = t.accentLight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  void _drawAnim(Canvas canvas) {
    final m = animMove;
    if (m == null) return;
    final t = animT.clamp(0.0, 1.0);
    final e = t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;
    Offset from;
    if (m.from == -1) {
      final n = whiteTurn ? pos.whiteBar : pos.blackBar;
      from = layout.barCenter(whiteTurn, n > 0 ? n - 1 : 0);
    } else {
      final n = pos.points[m.from].abs();
      from = layout.checkerAt(m.from, (n > 5 ? 5 : n) - 1);
    }
    Offset to;
    if (m.to == 24) {
      final n = whiteTurn ? pos.whiteOff : pos.blackOff;
      to = layout.offCenter(whiteTurn, n > 8 ? 7 : n);
    } else {
      to = layout.pointBase(m.to);
    }
    // Arc the flight.
    final mid = Offset((from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2 - 46 * (1 - (2 * t - 1).abs()));
    final p = Offset(
      from.dx + (to.dx - from.dx) * e,
      from.dy + (mid.dy - from.dy) * (e < 0.5 ? e * 2 : 1) +
          (to.dy - mid.dy) * (e < 0.5 ? 0 : (e - 0.5) * 2),
    );
    final white = whiteTurn;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(p.dx, to.dy + (from.dy < to.dy ? 10 : -10)),
          width: layout.checkerR * 1.6,
          height: layout.checkerR * 0.7),
      Paint()..color = Colors.black.withValues(alpha: 0.25 * (1 - t)),
    );
    drawChecker(canvas, p, layout.checkerR,
        white ? theme.checkerWhite : theme.checkerBlack, checkerStyle, theme);
    // Hit victim flies to the bar.
    if (animHit && m.to != 24) {
      final victimFrom = layout.pointBase(m.to);
      final victimTo = layout.barCenter(!white, 0);
      final vp = Offset(
        victimFrom.dx + (victimTo.dx - victimFrom.dx) * e,
        victimFrom.dy + (victimTo.dy - victimFrom.dy) * e -
            40 * (1 - (2 * t - 1).abs()),
      );
      drawChecker(canvas, vp, layout.checkerR,
          white ? theme.checkerBlack : theme.checkerWhite, checkerStyle, theme);
    }
  }

  void _drawCube(Canvas canvas) {
    final t = theme;
    final ctr = layout.cubeCenter(cube.owner);
    final s = layout.checkerR * 1.5;
    final dimmed = crawford;
    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: ctr + Offset(0, s * 0.7), width: s * 1.7, height: s * 0.9),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    // Leather cube body (rounded square).
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: ctr, width: s * 1.5, height: s * 1.5),
      Radius.circular(s * 0.25),
    );
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _shade(const Color(0xFFA9713F), 1.15),
          const Color(0xFFA9713F),
          _shade(const Color(0xFFA9713F), 0.7),
        ],
      ).createShader(rect.outerRect);
    canvas.drawRRect(rect, body);
    if (dimmed) {
      canvas.drawRRect(
          rect, Paint()..color = Colors.black.withValues(alpha: 0.45));
    }
    // Stitched edge.
    canvas.drawRRect(
        rect.deflate(4),
        Paint()
          ..color = t.accentLight.withValues(alpha: dimmed ? 0.25 : 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Numeral.
    final tp = TextPainter(
      text: TextSpan(
        text: '${cube.value}',
        style: TextStyle(
          color: dimmed
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF2E1E12),
          fontSize: s * 0.62,
          fontWeight: FontWeight.bold,
          fontFamily: 'EBGaramond',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, ctr - Offset(tp.width / 2, tp.height / 2));
    if (dimmed) {
      final tp2 = TextPainter(
        text: const TextSpan(
          text: '✕',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, ctr + Offset(s * 0.55, -s * 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
