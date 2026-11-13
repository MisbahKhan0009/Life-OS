import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Life OS "Orbit" mark: 24 dots round a centre dot, the first one red.
/// [lit] is how many dots after the red one are bright (16 in the logo).
/// [spin] rotates which dot is red, for a quiet "thinking" animation.
class OrbitMark extends StatelessWidget {
  const OrbitMark({super.key, this.size = 40, this.lit = 16, this.spin = 0, this.ink, this.dim, this.background});

  final double size;
  final int lit;
  final int spin;
  final Color? ink;
  final Color? dim;

  /// When set, the mark sits on a rounded tile of this colour (like the app icon).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      size: Size.square(size),
      painter: _OrbitPainter(
        lit: lit,
        spin: spin,
        ink: ink ?? const Color(0xFFEDEDEA),
        dim: dim ?? const Color(0xFF343436),
        scale: background == null ? 1.36 : 1.0,
      ),
    );
    if (background == null) return painter;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.225)),
      child: painter,
    );
  }
}

/// The mark with its dots chasing round, for loading and thinking states.
class OrbitSpinner extends StatefulWidget {
  const OrbitSpinner({super.key, this.size = 28, this.ink, this.dim});

  final double size;
  final Color? ink;
  final Color? dim;

  @override
  State<OrbitSpinner> createState() => _OrbitSpinnerState();
}

class _OrbitSpinnerState extends State<OrbitSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => OrbitMark(size: widget.size, spin: (_c.value * 24).floor(), lit: 9, ink: widget.ink, dim: widget.dim),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.lit, required this.spin, required this.ink, required this.dim, required this.scale});

  final int lit;
  final int spin;
  final Color ink;
  final Color dim;
  final double scale;

  static const _red = Color(0xFFE5262E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final r = s * 0.30 * scale;
    final p = Paint()..isAntiAlias = true;
    for (var i = 0; i < 24; i++) {
      final k = (i - spin) % 24; // position relative to the red dot
      final a = -math.pi / 2 + i * 2 * math.pi / 24;
      final rad = s * (k == 0 ? 0.039 : 0.0254) * scale;
      p.color = k == 0 ? _red : (k <= lit ? ink : dim);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, rad, p);
    }
    p.color = ink;
    canvas.drawCircle(c, s * 0.033 * scale, p);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.spin != spin || old.lit != lit || old.ink != ink || old.dim != dim;
}
