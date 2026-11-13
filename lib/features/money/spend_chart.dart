import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/money_format.dart';
import '../../theme/tokens.dart';
import 'money_kit.dart';

/// Day-by-day spending as dot-matrix columns, in the Nothing OS spirit.
/// Days over the daily budget light up in the expense colour.
class PixelSpendChart extends StatelessWidget {
  const PixelSpendChart({super.key, required this.daily, required this.dailyBudget, required this.today, this.hidden = false});

  /// Spending per day, index 0 is the 1st.
  final List<int> daily;

  /// Even daily share of the budget (0 when there is no budget).
  final int dailyBudget;

  /// Day of the month (1-based) to highlight, or 0 for a past month.
  final int today;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final peak = daily.fold(0, math.max);
    final peakDay = peak == 0 ? -1 : daily.indexOf(peak);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 112,
        child: CustomPaint(
          painter: _PixelPainter(
            daily: daily,
            dailyBudget: dailyBudget,
            today: today,
            on: p.accent,
            over: p.expense,
            off: p.soft,
            future: p.soft.withValues(alpha: 0.45),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text('1', style: AppText.label(10, color: p.muted)),
        const Spacer(),
        if (peakDay >= 0)
          Text('PEAK ${moneyShort(peak, hidden: hidden)} ON ${peakDay + 1}', style: AppText.label(10, color: p.muted)),
        const Spacer(),
        Text('${daily.length}', style: AppText.label(10, color: p.muted)),
      ]),
    ]);
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter({
    required this.daily,
    required this.dailyBudget,
    required this.today,
    required this.on,
    required this.over,
    required this.off,
    required this.future,
  });

  final List<int> daily;
  final int dailyBudget;
  final int today;
  final Color on;
  final Color over;
  final Color off;
  final Color future;

  static const rows = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = daily.length;
    if (cols == 0) return;
    final gap = size.width / cols * 0.22;
    final cell = math.min((size.width - gap * (cols - 1)) / cols, (size.height - gap * (rows - 1)) / rows);
    final colW = cell + gap;
    final left = (size.width - (cols * colW - gap)) / 2;
    final peak = math.max(daily.fold(0, math.max), dailyBudget);
    final r = Radius.circular(cell * 0.32);
    final paint = Paint();

    for (var i = 0; i < cols; i++) {
      final v = daily[i];
      final lit = peak == 0 || v == 0 ? 0 : math.max(1, (v / peak * rows).round());
      final isFuture = today > 0 && i + 1 > today;
      final isOver = dailyBudget > 0 && v > dailyBudget;
      for (var row = 0; row < rows; row++) {
        final x = left + i * colW;
        final y = size.height - (row + 1) * cell - row * gap;
        final idle = i + 1 == today ? on.withValues(alpha: 0.22) : (isFuture ? future : off);
        paint.color = row < lit ? (isOver ? over : on) : idle;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cell, cell), r), paint);
      }
    }

    // Daily budget guide.
    if (dailyBudget > 0 && peak > 0) {
      final level = (dailyBudget / peak * rows).clamp(0, rows.toDouble());
      final y = size.height - level * (cell + gap) + gap / 2;
      final dash = Paint()
        ..color = over.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
        x += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.daily != daily || old.dailyBudget != dailyBudget || old.today != today || old.on != on || old.off != off;
}
