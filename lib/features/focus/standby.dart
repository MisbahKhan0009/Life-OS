import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_dial.dart';
import 'focus_kit.dart';

/// Landscape timer in the spirit of iPhone StandBy: a big dial on the left,
/// glanceable widgets on the right. Night mode turns everything a dim red.
class StandByView extends StatefulWidget {
  const StandByView({super.key, this.onExit});

  /// Shown as a close button when set.
  final VoidCallback? onExit;

  @override
  State<StandByView> createState() => _StandByViewState();
}

class _StandByViewState extends State<StandByView> {
  bool _night = false;

  @override
  Widget build(BuildContext context) {
    final e = FocusEngineScope.of(context);
    final store = e.store;
    final ink = _night ? const Color(0xFFB3141B) : FocusColors.ink;
    final muted = _night ? const Color(0xFF6A0E12) : FocusColors.muted;
    final track = _night ? const Color(0xFF2A0608) : FocusColors.line;
    final panel = _night ? const Color(0xFF120304) : FocusColors.panel;
    final accent = _night ? ink : (e.phase.isBreak ? FocusColors.sage : FocusColors.red);
    final secs = e.displaySeconds;
    final h = secs ~/ 3600;
    final time = h > 0 ? '$h:${twoDigits(secs % 3600 ~/ 60)}:${twoDigits(secs % 60)}' : '${twoDigits(secs ~/ 60)}:${twoDigits(secs % 60)}';
    final phase = e.phase == FocusPhase.focus ? (e.countsUp ? 'FLOW' : 'FOCUS · ${e.round}/${store.longEvery}') : e.phase.label.toUpperCase();
    final now = DateTime.now();
    final mins = store.secondsOn(now) ~/ 60;
    final goal = store.dailyGoal;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            // Dial
            Expanded(
              flex: 11,
              child: LayoutBuilder(builder: (context, box) {
                final d = (box.biggest.shortestSide).clamp(120.0, 520.0);
                return Center(
                  child: Pressable(
                    label: e.running ? 'Pause' : 'Start',
                    scale: 0.98,
                    onTap: e.toggle,
                    child: SizedBox(
                      width: d,
                      height: d,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(size: Size.square(d), painter: TickDial(progress: e.progress, color: accent, track: track)),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(phase, style: AppText.label(d * 0.045, color: muted)),
                          SizedBox(height: d * 0.03),
                          FittedBox(child: Text(time, style: AppText.dot(d * (h > 0 ? 0.17 : 0.23), color: ink))),
                          SizedBox(height: d * 0.03),
                          Text(e.running ? 'TAP TO PAUSE' : 'TAP TO START', style: AppText.label(d * 0.036, color: muted)),
                        ]),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 18),
            // Widgets
            Expanded(
              flex: 9,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(headerDate(now), style: AppText.label(11, color: muted))),
                  _Small(icon: CupertinoIcons.moon_fill, label: _night ? 'Night mode off' : 'Night mode', on: _night, ink: ink, panel: panel, onTap: () => setState(() => _night = !_night)),
                  if (widget.onExit != null) ...[
                    const SizedBox(width: 8),
                    _Small(icon: AppIcons.close, label: 'Exit StandBy', ink: ink, panel: panel, onTap: widget.onExit!),
                  ],
                ]),
                const SizedBox(height: 10),
                Expanded(
                  child: _Tile(
                    panel: panel,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('NOW', style: AppText.label(10.5, color: muted)),
                      const SizedBox(height: 6),
                      Text(
                        e.intention.isNotEmpty ? e.intention : (e.phase.isBreak ? 'Rest. Look away from the screen.' : 'No intention set'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(19, weight: FontWeight.w600, color: ink, height: 1.2),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: _Tile(
                        panel: panel,
                        child: LayoutBuilder(builder: (context, box) => Row(children: [
                          if (box.maxWidth > 120) ...[
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CustomPaint(painter: DotRing(progress: goal == 0 ? 0 : mins / goal, on: accent, off: track, dots: 22)),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('TODAY', style: AppText.label(10, color: muted)),
                              FittedBox(child: Text(focusDuration(mins * 60), style: AppText.dot(22, color: ink))),
                            ]),
                          ),
                        ])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Tile(
                        panel: panel,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('STREAK', style: AppText.label(10, color: muted)),
                          Text('${store.streak(now)}', style: AppText.dot(26, color: ink)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  if (!e.countsUp && !e.phase.isBreak) ...[
                    _Small(icon: FocusIcons.plusFive, label: 'Add 5 minutes', ink: ink, panel: panel, onTap: e.addFive),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Pressable(
                      label: e.running ? 'Pause' : 'Start',
                      onTap: e.toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: e.running ? panel : accent, borderRadius: BorderRadius.circular(23), border: Border.all(color: track)),
                        child: Text(e.running ? 'PAUSE' : (e.started ? 'RESUME' : 'START'),
                            style: AppText.label(13, color: e.running ? ink : (_night ? Colors.black : Colors.white), tracking: 0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Small(
                    icon: FocusIcons.skip,
                    label: 'Finish or skip',
                    ink: (e.phase.isBreak ? !e.breakLocked : e.started) ? ink : muted,
                    panel: panel,
                    onTap: (e.phase.isBreak ? !e.breakLocked : e.started) ? e.finishNow : null,
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.panel, required this.child});
  final Color panel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(24)),
        child: child,
      );
}

class _Small extends StatelessWidget {
  const _Small({required this.icon, required this.label, required this.ink, required this.panel, required this.onTap, this.on = false});

  final IconData icon;
  final String label;
  final Color ink;
  final Color panel;
  final VoidCallback? onTap;
  final bool on;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: label,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: on ? ink : panel, shape: BoxShape.circle),
          child: Icon(icon, size: 19, color: on ? Colors.black : ink),
        ),
      );
}

/// StandBy as its own screen: turns the phone sideways, hides the system bars,
/// and puts everything back when you leave.
class StandByScreen extends StatefulWidget {
  const StandByScreen({super.key});

  @override
  State<StandByScreen> createState() => _StandByScreenState();
}

class _StandByScreenState extends State<StandByScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: StandByView(onExit: () => Navigator.of(context).maybePop()));
  }
}
