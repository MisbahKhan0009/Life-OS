import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'focus_kit.dart';

/// Nothing-style tick dial: 60 marks that light up as time passes.
class TickDial extends CustomPainter {
  TickDial({required this.progress, required this.color, this.track = FocusColors.line});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const ticks = 60;
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final filled = (progress * ticks).round();
    final paint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < ticks; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / ticks;
      final len = i % 5 == 0 ? r * 0.11 : r * 0.07;
      final dir = Offset(math.cos(a), math.sin(a));
      paint.color = i < filled ? color : track;
      canvas.drawLine(center + dir * r, center + dir * (r - len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TickDial old) => old.progress != progress || old.color != color;
}

/// Ring of dots for the daily goal.
class DotRing extends CustomPainter {
  DotRing({required this.progress, required this.on, required this.off, this.dots = 40});

  final double progress;
  final Color on;
  final Color off;
  final int dots;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final lit = (progress.clamp(0.0, 1.0) * dots).round();
    final p = Paint();
    for (var i = 0; i < dots; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / dots;
      p.color = i < lit ? on : off;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 2.4, p);
    }
  }

  @override
  bool shouldRepaint(covariant DotRing old) => old.progress != progress || old.on != on;
}
