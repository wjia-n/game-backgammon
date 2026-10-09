import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Warm walnut-table backdrop: radial candlelight vignette + subtle wood grain.
class WoodBackdrop extends StatelessWidget {
  final Widget child;
  const WoodBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.45),
          radius: 1.3,
          colors: [Color(0xFF33200F), BgTheme.walnut, BgTheme.vignette],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GrainPainter(),
        child: child,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 0; i < 26; i++) {
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.black.withValues(alpha: 0.05 + rng.nextDouble() * 0.05);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 40) {
        path.lineTo(x, y + sin(x / 90 + i) * 6 + rng.nextDouble() * 3);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A beveled brass plaque button with corner rivets — the primary control.
class BrassButton extends StatefulWidget {
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final bool primary;
  final double fontSize;
  final IconData? icon;

  const BrassButton({
    super.key,
    required this.label,
    this.sublabel,
    this.onTap,
    this.primary = true,
    this.fontSize = 20,
    this.icon,
  });

  @override
  State<BrassButton> createState() => _BrassButtonState();
}

class _BrassButtonState extends State<BrassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: widget.primary
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD9B96A), Color(0xFFB08D3E), Color(0xFF8A6A2E)],
                      stops: [0.0, 0.55, 1.0],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4A2E1B), Color(0xFF33200F)],
                    ),
              border: Border.all(
                color: widget.primary ? BgTheme.engravedDark : BgTheme.brassDeep,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: _down ? 4 : 10,
                  offset: Offset(0, _down ? 2 : 5),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: widget.primary ? 0.22 : 0.06),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: widget.primary ? BgTheme.engravedDark : BgTheme.goldText,
                          size: widget.fontSize + 4),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: (widget.primary ? BgTheme.displayDark : BgTheme.display).copyWith(
                              fontSize: widget.fontSize,
                              letterSpacing: 2.0,
                            ),
                          ),
                          if (widget.sublabel != null)
                            Text(
                              widget.sublabel!,
                              textAlign: TextAlign.center,
                              style: BgTheme.bodyItalic.copyWith(
                                fontSize: 12,
                                color: widget.primary ? BgTheme.engravedDark : BgTheme.brassHi,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // corner rivets
                for (final pos in const [
                  Alignment.topLeft,
                  Alignment.topRight,
                  Alignment.bottomLeft,
                  Alignment.bottomRight,
                ])
                  Align(
                    alignment: pos,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFF5D9A0), Color(0xFF7A5F28)],
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark leather panel with brass-thread stitched border.
class LeatherPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const LeatherPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B4426), BgTheme.darkLeather, Color(0xFF40260F)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: CustomPaint(
        painter: _StitchPainter(),
        child: child,
      ),
    );
  }
}

class _StitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BgTheme.brassHi.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const r = 10.0;
    final rect = RRect.fromLTRBR(6, 6, size.width - 6, size.height - 6, const Radius.circular(r));
    const dash = 6.0, gap = 4.0;
    final path = Path()..addRRect(rect);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final seg = m.extractPath(d, (d + dash).clamp(0, m.length));
        canvas.drawPath(seg, paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Arabesque 8-point star medallion in mother-of-pearl + brass.
class Medallion extends StatelessWidget {
  final double size;
  const Medallion({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MedallionPainter()),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final pearl = Paint()..color = BgTheme.pearl.withValues(alpha: 0.9);
    final brass = Paint()
      ..color = BgTheme.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // two rotated squares = 8-point star
    for (int k = 0; k < 2; k++) {
      final path = Path();
      for (int i = 0; i <= 4; i++) {
        final a = pi / 4 * i + pi / 4 * k + pi / 8;
        final p = Offset(c.dx + r * 0.82 * cos(a), c.dy + r * 0.82 * sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, pearl);
      canvas.drawPath(path, brass);
    }
    // inner rosette
    canvas.drawCircle(c, r * 0.3, Paint()..color = BgTheme.rosewood);
    canvas.drawCircle(c, r * 0.3, brass);
    canvas.drawCircle(c, r * 0.12, pearl);
    canvas.drawCircle(c, r * 0.94, brass);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A physical backgammon checker disc with bevel, sheen and contact shadow.
class CheckerDisc extends StatelessWidget {
  final bool white;
  final double diameter;
  final bool selected;

  const CheckerDisc({super.key, required this.white, required this.diameter, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final d = diameter;
    return Container(
      width: d,
      height: d + 5,
      alignment: Alignment.topCenter,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // contact shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: d * 0.9,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                radius: 1.1,
                colors: white
                    ? const [Color(0xFFFDF6E8), BgTheme.pearl, BgTheme.pearlShadow, Color(0xFFB8A37E)]
                    : const [Color(0xFF6E4023), BgTheme.rosewood, Color(0xFF2E1A0E), Color(0xFF1A0E06)],
                stops: const [0.0, 0.45, 0.8, 1.0],
              ),
              border: Border.all(
                color: selected ? BgTheme.brassHi : (white ? const Color(0xFFB8A37E) : Colors.black54),
                width: selected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: d * 0.62,
                height: d * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (white ? const Color(0xFFB8A37E) : BgTheme.brassDeep).withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                child: Center(child: Medallion(size: d * 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ivory die with engraved pips.
class DieFace extends StatelessWidget {
  final int value;
  final double size;
  const DieFace({super.key, required this.value, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.35),
          radius: 1.2,
          colors: [Color(0xFFFDF8EC), BgTheme.pearl, BgTheme.pearlShadow],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: const Color(0xFFB8A37E), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 3)),
        ],
      ),
      child: CustomPaint(painter: _PipPainter(value)),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int value;
  _PipPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF241708);
    final r = size.width * 0.075;
    final v = value.clamp(1, 6);
    void dot(double x, double y) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, paint);
    }

    switch (v) {
      case 1:
        dot(0.5, 0.5);
      case 2:
        dot(0.28, 0.28);
        dot(0.72, 0.72);
      case 3:
        dot(0.26, 0.26);
        dot(0.5, 0.5);
        dot(0.74, 0.74);
      case 4:
        dot(0.3, 0.3);
        dot(0.7, 0.3);
        dot(0.3, 0.7);
        dot(0.7, 0.7);
      case 5:
        dot(0.28, 0.28);
        dot(0.72, 0.28);
        dot(0.5, 0.5);
        dot(0.28, 0.72);
        dot(0.72, 0.72);
      case 6:
        dot(0.3, 0.24);
        dot(0.7, 0.24);
        dot(0.3, 0.5);
        dot(0.7, 0.5);
        dot(0.3, 0.76);
        dot(0.7, 0.76);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) => old.value != value;
}

/// Brass toggle switch for settings.
class BrassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const BrassToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? BgTheme.brassDeep : const Color(0xFF241708),
          border: Border.all(color: BgTheme.brass, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.3),
              colors: [Color(0xFFF5D9A0), BgTheme.brass, BgTheme.brassDeep],
            ),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// Thin engraved divider with a center diamond.
class EngravedDivider extends StatelessWidget {
  const EngravedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BgTheme.brassDeep, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: BgTheme.brass,
                border: Border.all(color: BgTheme.brassHi, width: 1),
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(color: BgTheme.brassDeep, thickness: 1)),
      ],
    );
  }
}
