import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/focus_engine.dart';
import '../../data/format.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_kit.dart';

/// Ideas for a break, shown one at a time.
const breakIdeas = [
  ('Stand up and stretch', 'Reach up, then fold forward. Roll your shoulders.'),
  ('Drink some water', 'A full glass. Your focus runs on it.'),
  ('Look far away', 'Find something 6 metres away and look at it for 20 seconds.'),
  ('Walk for a minute', 'Away from the screen. Get the blood moving.'),
  ('Breathe', 'A minute of slow breathing calms the mind before the next round.'),
  ('Rest your eyes', 'Close them and let your face relax.'),
];

enum _Pattern { box, relax }

/// Guided breathing for breaks: an expanding dot circle with a count.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  _Pattern _pattern = _Pattern.box;
  int _lastStep = -1;

  // Seconds for in, hold, out, hold.
  List<int> get _steps => _pattern == _Pattern.box ? const [4, 4, 4, 4] : const [4, 7, 8, 0];

  void _setPattern(_Pattern p) {
    setState(() => _pattern = p);
    final total = _steps.fold(0, (a, b) => a + b);
    _c
      ..duration = Duration(seconds: total)
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = FocusEngineScope.of(context);
    return Scaffold(
      backgroundColor: FocusColors.ground,
      body: SafeArea(
        child: Column(children: [
          FocusPageHeader(
            title: 'Breathe',
            trailing: engine.phase.index > 0
                ? Text('BREAK ${twoDigits(engine.remainingSeconds ~/ 60)}:${twoDigits(engine.remainingSeconds % 60)}',
                    style: AppText.label(11, color: FocusColors.muted))
                : null,
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip('Box 4·4·4·4', _pattern == _Pattern.box, () => _setPattern(_Pattern.box)),
            const SizedBox(width: 8),
            _chip('Relax 4·7·8', _pattern == _Pattern.relax, () => _setPattern(_Pattern.relax)),
          ]),
          Expanded(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final steps = _steps;
                final total = steps.fold(0, (a, b) => a + b);
                final t = _c.value * total;
                var acc = 0.0;
                var step = 0;
                for (var i = 0; i < steps.length; i++) {
                  if (t < acc + steps[i]) {
                    step = i;
                    break;
                  }
                  acc += steps[i];
                }
                final within = steps[step] == 0 ? 1.0 : (t - acc) / steps[step];
                final size = switch (step) {
                  0 => 0.35 + 0.65 * Curves.easeInOut.transform(within),
                  1 => 1.0,
                  2 => 1.0 - 0.65 * Curves.easeInOut.transform(within),
                  _ => 0.35,
                };
                if (step != _lastStep) {
                  _lastStep = step;
                  HapticFeedback.selectionClick();
                }
                final label = const ['Breathe in', 'Hold', 'Breathe out', 'Hold'][step];
                final count = math.max(1, steps[step] - (t - acc).floor());
                return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CustomPaint(painter: _DotsPainter(size)),
                  ),
                  const SizedBox(height: 28),
                  Text(label, style: AppText.sans(24, weight: FontWeight.w600, color: FocusColors.ink)),
                  const SizedBox(height: 8),
                  Text('$count', style: AppText.dot(40, color: FocusColors.muted)),
                ]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: FocusButton(label: 'Done', quiet: true, onTap: () => Navigator.of(context).maybePop()),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Pressable(
        onTap: onTap,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? FocusColors.ink : FocusColors.panelHigh, borderRadius: BorderRadius.circular(17)),
          child: Text(label, style: AppText.sans(13.5, weight: FontWeight.w500, color: on ? FocusColors.ground : FocusColors.ink)),
        ),
      );
}

/// Rings of dots that grow with the breath (dot-matrix look).
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.scale);
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    final p = Paint();
    for (var ring = 1; ring <= 7; ring++) {
      final r = maxR * scale * ring / 7;
      final n = 6 + ring * 6;
      final lit = ring / 7 <= scale + 0.02;
      p.color = lit ? FocusColors.ink.withValues(alpha: 0.35 + 0.65 * ring / 7) : FocusColors.line;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n + ring * 0.3;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 2.2 + ring * 0.25, p);
      }
    }
    p.color = FocusColors.ink;
    canvas.drawCircle(c, 4, p);
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.scale != scale;
}
