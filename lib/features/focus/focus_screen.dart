import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/widgets.dart';

/// First build of Focus: a working Pomodoro timer in the Nothing-style design.
/// Linking sessions to notes, stats and sounds come in the Focus build.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.active});

  final bool active;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _presets = [15, 25, 50, 90];
  int _minutes = 25;
  int _total = 25 * 60;
  int _left = 25 * 60;
  bool _onBreak = false;
  int _round = 1;
  Timer? _timer;

  bool get _running => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer!.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    });
  }

  void _tick() {
    if (_left <= 1) {
      _timer?.cancel();
      _timer = null;
      final toBreak = !_onBreak;
      if (!toBreak) _round = _round % 4 + 1;
      final breakMin = _round == 4 ? 15 : 5;
      setState(() {
        _onBreak = toBreak;
        _total = (toBreak ? breakMin : _minutes) * 60;
        _left = _total;
      });
      if (mounted) showToast(context, toBreak ? 'Focus done. Take a $breakMin minute break.' : 'Break over. Ready for round $_round.');
      return;
    }
    setState(() => _left--);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _left = _total;
    });
  }

  void _setMinutes(int m) {
    if (_running) return;
    setState(() {
      _minutes = m;
      _onBreak = false;
      _total = m * 60;
      _left = _total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final elapsed = _total - _left;
    final progress = _total == 0 ? 0.0 : elapsed / _total;
    final label = _running ? 'PAUSE' : (elapsed > 0 ? 'RESUME' : 'START');
    return ColoredBox(
      color: const Color(0xFF070707),
      child: Stack(children: [
        Positioned.fill(
          child: GrainArt(
            base: const Color(0xFF070707),
            spots: [
              Spot(_onBreak ? c.sage.withValues(alpha: 0.5) : const Color(0x553A3A3C), const Alignment(0, 0.15), 0.9),
            ],
            grain: 0.4,
          ),
        ),
        SafeArea(
          bottom: false,
          child: ContentWidth(
            max: 520,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
              children: [
                Row(children: [
                  Expanded(child: Text(_onBreak ? 'BREAK' : 'FOCUS · ROUND $_round OF 4', style: AppText.label(12, color: const Color(0xFFB5B4AF)))),
                  Text(headerDate(DateTime.now()), style: AppText.label(11, color: const Color(0xFF6F6E6A))),
                ]),
                const SizedBox(height: 28),
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(size: const Size(280, 280), painter: _TickDial(progress: progress, color: _onBreak ? c.sage : const Color(0xFFEDEDEA))),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${twoDigits(_left ~/ 60)}:${twoDigits(_left % 60)}', style: AppText.dot(66, color: const Color(0xFFEDEDEA))),
                        const SizedBox(height: 10),
                        Text(_onBreak ? 'THEN BACK TO FOCUS' : 'THEN BREAK ${_round == 4 ? 15 : 5} MIN', style: AppText.label(11, color: const Color(0xFF8D8C88))),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFFECEBE7), borderRadius: BorderRadius.circular(Radii.xl)),
                  child: Column(children: [
                    Text('Session length', style: AppText.sans(13, color: const Color(0xFF6F6E6A))),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (final m in _presets)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Pressable(
                              label: '$m minutes',
                              onTap: _running ? null : () => _setMinutes(m),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _minutes == m ? const Color(0xFF151515) : const Color(0xFFDCDBD5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('$m', style: AppText.dot(22, color: _minutes == m ? const Color(0xFFF8F8F6) : const Color(0xFF151515))),
                              ),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      RoundIconButton(icon: AppIcons.restore, label: 'Reset', size: 52, background: const Color(0xFFDCDBD5), foreground: const Color(0xFF151515), onTap: _reset),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pressable(
                          label: label,
                          onTap: _toggle,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: _running ? const Color(0xFF151515) : c.action, borderRadius: BorderRadius.circular(28)),
                            child: Text(label, style: AppText.label(14, color: Colors.white, tracking: 0.2)),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Text('Linking sessions to notes, stats and sounds arrive in the Focus build.', textAlign: TextAlign.center, style: AppText.sans(12.5, color: const Color(0xFF6F6E6A))),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _TickDial extends CustomPainter {
  _TickDial({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const ticks = 60;
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final filled = (progress * ticks).round();
    for (var i = 0; i < ticks; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / ticks;
      final len = i % 5 == 0 ? 16.0 : 10.0;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * r;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (r - len);
      final paint = Paint()
        ..color = i < filled ? color : const Color(0xFF2E2E30)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickDial old) => old.progress != progress || old.color != color;
}
