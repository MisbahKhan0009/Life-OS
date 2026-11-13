import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_dial.dart';
import 'focus_kit.dart';
import 'standby.dart';

/// Distraction-free fullscreen timer. Turn the phone sideways for a big clock.
class FocusFullscreen extends StatefulWidget {
  const FocusFullscreen({super.key});

  @override
  State<FocusFullscreen> createState() => _FocusFullscreenState();
}

class _FocusFullscreenState extends State<FocusFullscreen> {
  bool _controls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  void _poke() {
    setState(() => _controls = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final e = FocusEngineScope.of(context);
    final secs = e.displaySeconds;
    final h = secs ~/ 3600;
    final time = h > 0 ? '$h:${twoDigits(secs % 3600 ~/ 60)}:${twoDigits(secs % 60)}' : '${twoDigits(secs ~/ 60)}:${twoDigits(secs % 60)}';
    final label = e.phase == FocusPhase.focus ? (e.countsUp ? 'FLOW' : 'FOCUS · ROUND ${e.round}') : e.phase.label.toUpperCase();
    final color = e.phase.isBreak ? FocusColors.sage : FocusColors.ink;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _poke,
        child: SafeArea(
          child: OrientationBuilder(builder: (context, orientation) {
            final landscape = orientation == Orientation.landscape;
            if (landscape) return StandByView(onExit: () => Navigator.of(context).maybePop());
            final clock = landscape
                ? FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(time, style: AppText.dot(200, color: color))),
                  )
                : SizedBox(
                    width: 320,
                    height: 320,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(size: const Size(320, 320), painter: TickDial(progress: e.progress, color: color)),
                      Text(time, style: AppText.dot(h > 0 ? 54 : 74, color: FocusColors.ink)),
                    ]),
                  );
            return Stack(children: [
              Positioned.fill(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: AppText.label(13, color: FocusColors.muted)),
                  SizedBox(height: landscape ? 4 : 28),
                  if (landscape) Expanded(child: Center(child: clock)) else clock,
                  if (e.intention.isNotEmpty) ...[
                    SizedBox(height: landscape ? 4 : 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(e.intention, textAlign: TextAlign.center, maxLines: 2, style: AppText.sans(17, color: FocusColors.muted)),
                    ),
                  ],
                  if (landscape) const SizedBox(height: 12),
                ]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _controls ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_controls,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      RoundIconButton(
                        icon: FocusIcons.collapse,
                        label: 'Exit fullscreen',
                        size: 52,
                        background: FocusColors.panelHigh,
                        foreground: FocusColors.ink,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Pressable(
                        label: e.running ? 'Pause' : 'Start',
                        onTap: () {
                          e.toggle();
                          _poke();
                        },
                        child: Container(
                          height: 52,
                          width: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: e.running ? FocusColors.panelHigh : FocusColors.red, borderRadius: BorderRadius.circular(26)),
                          child: Text(e.running ? 'PAUSE' : 'START', style: AppText.label(14, color: Colors.white, tracking: 0.2)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}
