import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_kit.dart';
import 'focus_sheets.dart';

/// Focus stats: totals, streaks, heatmap, best hours, quality and history.
class FocusStatsScreen extends StatelessWidget {
  const FocusStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FocusEngineScope.of(context).store;
    final notes = StoreScope.of(context);
    final now = DateTime.now();
    final avg = store.averageSeconds(now);
    final rate = store.completionRate(now);
    final rating = store.averageScore(now, energy: false);
    final ratingBefore = store.averageScore(now, energy: false, daysAgoStart: 60, daysAgoEnd: 30);
    final energy = store.averageScore(now, energy: true);
    final energyBefore = store.averageScore(now, energy: true, daysAgoStart: 60, daysAgoEnd: 30);
    final byNote = store.byNote(now);
    final history = store.sessions();

    return Scaffold(
      backgroundColor: FocusColors.ground,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            FocusPageHeader(
              title: 'Focus stats',
              trailing: RoundIconButton(
                icon: FocusIcons.copy,
                label: 'Copy all sessions as CSV',
                background: FocusColors.panelHigh,
                foreground: FocusColors.ink,
                onTap: history.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: store.toCsv(noteTitle: (id) => id == null ? '' : (notes.note(id)?.displayTitle ?? ''))));
                        if (context.mounted) showToast(context, 'Copied ${history.length} sessions as CSV');
                      },
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                Row(children: [
                  Expanded(child: _Big(label: 'TODAY', value: focusDuration(store.secondsOn(now)))),
                  const SizedBox(width: 8),
                  Expanded(child: _Big(label: 'THIS WEEK', value: focusDuration(store.weekSeconds(now)))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _Big(label: monthShort(now).toUpperCase(), value: focusDuration(store.monthSeconds(now)))),
                  const SizedBox(width: 8),
                  Expanded(child: _Big(label: '${now.year}', value: focusDuration(store.yearSeconds(now)))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _Big(label: 'STREAK', value: '${store.streak(now)}', unit: 'days')),
                  const SizedBox(width: 8),
                  Expanded(child: _Big(label: 'BEST STREAK', value: '${store.bestStreak}', unit: 'days')),
                ]),

                const _Title('Last 20 weeks'),
                _Panel(child: _Heatmap(daily: store.dailySeconds(now, 140), goalSeconds: store.dailyGoal * 60, today: now)),

                const _Title('Best hours · last 30 days'),
                _Panel(child: _Hours(hours: store.hourly(now))),

                const _Title('Quality · last 30 days'),
                _Panel(
                  child: Column(children: [
                    _Line(label: 'Average session', value: avg == 0 ? '-' : focusDuration(avg)),
                    _Line(label: 'Completed without breaking', value: rate == null ? '-' : '${(rate * 100).round()}%'),
                    _Line(label: 'Focus rating', value: _score(rating), trend: _trend(rating, ratingBefore)),
                    _Line(label: 'Energy', value: _score(energy), trend: _trend(energy, energyBefore), last: true),
                  ]),
                ),

                if (byNote.isNotEmpty) ...[
                  const _Title('By note · last 30 days'),
                  _Panel(
                    child: Column(children: [
                      for (final (id, secs) in byNote.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(
                                child: Text(notes.note(id)?.displayTitle ?? 'Deleted note',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(14.5, weight: FontWeight.w500, color: FocusColors.ink)),
                              ),
                              Text(focusDuration(secs), style: AppText.sans(14, weight: FontWeight.w600, color: FocusColors.ink)),
                            ]),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressTrack(value: secs / byNote.first.$2),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ],

                _Title('History', action: 'Add past session', onAction: () => showSessionEditor(context)),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('No sessions yet. Start a round and it shows up here.', style: AppText.sans(14, color: FocusColors.muted))),
                  )
                else
                  ..._historyRows(context, history.take(100).toList(), notes),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static String _score(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)} / 5';

  static int _trend(double? now, double? before) {
    if (now == null || before == null) return 0;
    if (now - before > 0.2) return 1;
    if (before - now > 0.2) return -1;
    return 0;
  }

  List<Widget> _historyRows(BuildContext context, List<FocusSession> list, NoteStore notes) {
    final out = <Widget>[];
    DateTime? day;
    for (final s in list) {
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      if (day != d) {
        day = d;
        final total = list.where((x) => x.start.year == d.year && x.start.month == d.month && x.start.day == d.day).fold(0, (a, x) => a + x.seconds);
        out.add(Padding(
          padding: EdgeInsets.fromLTRB(4, out.isEmpty ? 0 : 14, 4, 8),
          child: Row(children: [
            Expanded(child: Text(relativeDayHeading(d), style: AppText.label(10.5, color: FocusColors.muted))),
            Text(focusDuration(total), style: AppText.label(10.5, color: FocusColors.muted)),
          ]),
        ));
      }
      final note = s.noteId == null ? null : notes.note(s.noteId!);
      final title = s.intention.isNotEmpty ? s.intention : (note?.displayTitle ?? (s.mode == FocusMode.flow ? 'Flowtime' : '${s.presetName} round'));
      final tags = [
        '${focusClock(s.start)} to ${focusClock(s.end)}',
        if (note != null && s.intention.isNotEmpty) note.displayTitle,
        if (s.manual) 'added later',
        if (s.broken) 'broken',
        if (!s.completed && !s.manual) 'ended early',
        if (s.distractionCount > 0) '${s.distractionCount} distracted',
      ];
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Pressable(
          onTap: () => showSessionEditor(context, edit: s),
          scale: 0.98,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: FocusColors.line)),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: s.broken ? FocusColors.red : (s.counts || s.manual ? FocusColors.ink : FocusColors.dim),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: FocusColors.ink)),
                  const SizedBox(height: 2),
                  Text(tags.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12.5, color: FocusColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(focusDuration(s.seconds), style: AppText.sans(15, weight: FontWeight.w700, color: FocusColors.ink)),
                if (s.rating > 0) Text('${'●' * s.rating}${'○' * (5 - s.rating)}', style: AppText.sans(9, color: FocusColors.muted, letterSpacing: 1)),
              ]),
            ]),
          ),
        ),
      ));
    }
    return out;
  }
}

String relativeDayHeading(DateTime d) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  final base = '${weekdayShort(d).toUpperCase()} · ${d.day} ${monthShort(d).toUpperCase()}';
  return d.year == n.year ? base : '$base ${d.year}';
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.label(10.5, color: FocusColors.muted)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.dot(30, color: FocusColors.ink)))),
          if (unit != null) ...[
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit!, style: AppText.sans(13, color: FocusColors.muted))),
          ],
        ]),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: FocusColors.line)),
        child: child,
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: AppText.sans(13, weight: FontWeight.w600, color: FocusColors.muted))),
          if (action != null)
            Pressable(
              onTap: onAction,
              label: action,
              child: Text(action!, style: AppText.sans(13, weight: FontWeight.w600, color: FocusColors.ink)),
            ),
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.trend = 0, this.last = false});

  final String label;
  final String value;
  final int trend;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: FocusColors.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.sans(14.5, color: FocusColors.ink))),
          if (trend != 0) ...[
            Text(trend > 0 ? '↑' : '↓', style: AppText.sans(14, weight: FontWeight.w700, color: trend > 0 ? FocusColors.sage : FocusColors.red)),
            const SizedBox(width: 6),
          ],
          Text(value, style: AppText.sans(14.5, weight: FontWeight.w600, color: FocusColors.ink)),
        ]),
      );
}

/// Thin bar used for per-note time.
class LinearProgressTrack extends StatelessWidget {
  const LinearProgressTrack({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 5,
        child: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: FocusColors.line)),
          FractionallySizedBox(widthFactor: value.clamp(0.0, 1.0), child: const ColoredBox(color: FocusColors.ink)),
        ]),
      );
}

/// GitHub-style calendar of focus time, drawn as dots. Columns are weeks (Monday first).
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.daily, required this.goalSeconds, required this.today});

  final List<int> daily;
  final int goalSeconds;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(aspectRatio: 20 / 7, child: CustomPaint(painter: _HeatPainter(daily, goalSeconds, today.weekday))),
      const SizedBox(height: 10),
      Row(children: [
        Text('LESS', style: AppText.label(9.5, color: FocusColors.dim)),
        const SizedBox(width: 6),
        for (final a in const [0.0, 0.25, 0.5, 0.75, 1.0])
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: _heatColor(a), shape: BoxShape.circle)),
          ),
        Text('GOAL', style: AppText.label(9.5, color: FocusColors.dim)),
        const Spacer(),
        Text('${daily.where((d) => d >= 60).length} ACTIVE DAYS', style: AppText.label(9.5, color: FocusColors.muted)),
      ]),
    ]);
  }
}

Color _heatColor(double level) {
  if (level <= 0) return FocusColors.line;
  if (level >= 1) return FocusColors.red;
  return Color.lerp(const Color(0xFF55544F), FocusColors.ink, level)!;
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.daily, this.goal, this.todayWeekday);

  final List<int> daily;
  final int goal;
  final int todayWeekday;

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 20, rows = 7;
    final cell = math.min(size.width / cols, size.height / rows);
    final r = cell * 0.32;
    final p = Paint();
    // The last column ends on today's weekday; days after today are blank.
    final totalCells = cols * rows;
    final blanks = rows - todayWeekday; // after today in the final week
    final startOffset = totalCells - blanks - daily.length;
    for (var i = 0; i < daily.length; i++) {
      final idx = startOffset + i;
      if (idx < 0) continue;
      final col = idx ~/ rows;
      final row = idx % rows;
      final level = daily[i] < 60 ? 0.0 : (goal <= 0 ? 0.5 : daily[i] / goal);
      p.color = _heatColor(level >= 1 ? 1 : (level <= 0 ? 0 : 0.2 + level * 0.8));
      canvas.drawCircle(Offset(col * cell + cell / 2, row * cell + cell / 2), r, p);
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.daily != daily || old.goal != goal;
}

/// Focus by hour of day as dot columns.
class _Hours extends StatelessWidget {
  const _Hours({required this.hours});
  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final peak = hours.fold(0, math.max);
    final best = peak == 0 ? -1 : hours.indexOf(peak);
    String h(int i) => i == 0 ? '12a' : (i < 12 ? '${i}a' : (i == 12 ? '12p' : '${i - 12}p'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 90, child: CustomPaint(painter: _HoursPainter(hours, best))),
      const SizedBox(height: 8),
      Row(children: [
        Text('12A', style: AppText.label(9.5, color: FocusColors.dim)),
        const Spacer(),
        Text(best < 0 ? 'NO DATA YET' : 'BEST AROUND ${h(best).toUpperCase()}', style: AppText.label(9.5, color: FocusColors.muted)),
        const Spacer(),
        Text('11P', style: AppText.label(9.5, color: FocusColors.dim)),
      ]),
    ]);
  }
}

class _HoursPainter extends CustomPainter {
  _HoursPainter(this.hours, this.best);
  final List<int> hours;
  final int best;

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 9;
    final colW = size.width / 24;
    final cell = math.min(colW * 0.7, size.height / rows * 0.75);
    final gapY = size.height / rows;
    final peak = hours.fold(0, math.max);
    final p = Paint();
    for (var i = 0; i < 24; i++) {
      final lit = peak == 0 || hours[i] == 0 ? 0 : math.max(1, (hours[i] / peak * rows).round());
      for (var r = 0; r < rows; r++) {
        p.color = r < lit ? (i == best ? FocusColors.red : FocusColors.ink) : FocusColors.line;
        final cx = i * colW + colW / 2;
        final cy = size.height - r * gapY - gapY / 2;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: cell, height: cell), Radius.circular(cell * 0.3)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HoursPainter old) => old.hours != hours || old.best != best;
}
