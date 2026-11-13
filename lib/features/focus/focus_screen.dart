import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/widgets.dart';
import 'breathing.dart';
import 'focus_dial.dart';
import 'focus_kit.dart';
import 'focus_sheets.dart';
import 'focus_stats.dart';
import 'focus_view.dart';

/// Focus: a Pomodoro and Flowtime timer tied to what you are working on.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.active});

  /// True while the Focus tab is showing.
  final bool active;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  StreamSubscription<FocusEvent>? _sub;
  int _idea = DateTime.now().minute % breakIdeas.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= FocusEngineScope.read(context).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(FocusEvent e) {
    if (!mounted) return;
    switch (e.kind) {
      case FocusEventKind.focusDone:
        final s = e.session;
        if (s == null) return;
        setState(() => _idea = (_idea + 1) % breakIdeas.length);
        if (widget.active) {
          showCheckInSheet(context, s);
        } else {
          showToast(context, 'Focus done · ${focusDuration(s.seconds)}', actionLabel: 'Check in', onAction: () {
            shellTab.value = 2;
            showCheckInSheet(context, s);
          });
        }
      case FocusEventKind.breakDone:
        final engine = FocusEngineScope.read(context);
        showToast(context, engine.running ? 'Break over. Round ${engine.round} started.' : 'Break over. Ready for round ${engine.round}.');
      case FocusEventKind.broken:
        showToast(context, 'You left during focus. Strict mode marked this round as broken.');
      case FocusEventKind.started:
      case FocusEventKind.paused:
      case FocusEventKind.skipped:
        break;
    }
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final e = FocusEngineScope.of(context);
    final store = e.store;
    final onBreak = e.phase.isBreak;
    final accent = onBreak ? FocusColors.sage : FocusColors.ink;
    final pending = !e.running || onBreak ? store.pendingCheckIn : null;
    final sounds = store.soundMix.isNotEmpty;

    final headline = switch (e.phase) {
      FocusPhase.focus => e.mode == FocusMode.flow ? 'FLOW' : 'FOCUS · ROUND ${e.round} OF ${store.longEvery}',
      FocusPhase.shortBreak => 'SHORT BREAK',
      FocusPhase.longBreak => 'LONG BREAK',
    };

    return ColoredBox(
      color: FocusColors.ground,
      child: Stack(children: [
        Positioned.fill(
          child: GrainArt(
            base: FocusColors.ground,
            spots: [
              Spot(onBreak ? FocusColors.sage.withValues(alpha: 0.45) : (e.running ? const Color(0x40E5262E) : const Color(0x553A3A3C)), const Alignment(0, -0.2), 0.9),
            ],
            grain: 0.4,
          ),
        ),
        SafeArea(
          bottom: false,
          child: ContentWidth(
            max: 520,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              children: [
                // Header
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(headerDate(DateTime.now()), style: AppText.label(11, color: FocusColors.dim)),
                      const SizedBox(height: 4),
                      Text(headline, style: AppText.label(12.5, color: FocusColors.ink)),
                    ]),
                  ),
                  _HeaderButton(icon: sounds ? FocusIcons.sound : FocusIcons.soundOff, label: 'Sounds', lit: sounds, onTap: () => showSoundSheet(context)),
                  const SizedBox(width: 8),
                  _HeaderButton(icon: FocusIcons.stats, label: 'Stats', onTap: () => _push(const FocusStatsScreen())),
                  const SizedBox(width: 8),
                  _HeaderButton(icon: FocusIcons.settings, label: 'Focus settings', onTap: () => showFocusSettings(context)),
                ]),
                const SizedBox(height: 16),
                Center(child: _ModeSwitch(engine: e)),
                if (pending != null) ...[
                  const SizedBox(height: 14),
                  Pressable(
                    onTap: () => showCheckInSheet(context, pending),
                    scale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: FocusColors.line)),
                      child: Row(children: [
                        const Icon(FocusIcons.check, size: 18, color: FocusColors.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Check in on your ${focusDuration(pending.seconds)} session', style: AppText.sans(14.5, weight: FontWeight.w500, color: FocusColors.ink)),
                        ),
                        Icon(AppIcons.forward, size: 15, color: FocusColors.muted),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // Dial
                Center(
                  child: Pressable(
                    label: 'Fullscreen timer',
                    scale: 0.985,
                    onTap: () => _push(const FocusFullscreen()),
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(size: const Size(280, 280), painter: TickDial(progress: e.progress, color: accent)),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_clock(e.displaySeconds), style: AppText.dot(e.displaySeconds >= 3600 ? 50 : 66, color: FocusColors.ink)),
                          const SizedBox(height: 10),
                          Text(_subline(e), style: AppText.label(10.5, color: FocusColors.muted)),
                        ]),
                        const Positioned(bottom: 34, child: Icon(FocusIcons.expand, size: 14, color: FocusColors.dim)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Intention and linked note
                _IntentionPill(engine: e),
                const SizedBox(height: 10),

                if (!onBreak && e.started)
                  Row(children: [
                    if (!e.countsUp) ...[
                      Expanded(child: _ActionChip(icon: FocusIcons.plusFive, label: '+5 min', onTap: e.addFive)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _ActionChip(
                        icon: FocusIcons.distract,
                        label: e.distractionCount == 0 ? 'Distracted' : 'Distracted · ${e.distractionCount}',
                        onTap: () => showDistractionSheet(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _ActionChip(icon: FocusIcons.quickNote, label: 'Quick note', onTap: () => showQuickNoteSheet(context))),
                  ]),

                if (onBreak) _BreakCard(idea: breakIdeas[_idea], onBreathe: () => _push(const BreathingScreen()), onNext: () => setState(() => _idea = (_idea + 1) % breakIdeas.length)),
                const SizedBox(height: 12),

                // Controls card
                _ControlsCard(engine: e),
                const SizedBox(height: 12),
                _TodayStrip(onTap: () => _push(const FocusStatsScreen())),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  static String _clock(int secs) {
    final h = secs ~/ 3600;
    if (h > 0) return '$h:${twoDigits(secs % 3600 ~/ 60)}:${twoDigits(secs % 60)}';
    return '${twoDigits(secs ~/ 60)}:${twoDigits(secs % 60)}';
  }

  static String _subline(FocusEngine e) {
    if (e.phase.isBreak) return e.breakLocked ? 'BREAK IS PROTECTED' : 'THEN BACK TO FOCUS';
    if (e.countsUp) return e.elapsedSeconds < 60 ? 'COUNTING UP' : 'BREAK EARNED ${flowBreakMinutes(e.elapsedSeconds)} MIN';
    final next = e.nextPhase == FocusPhase.longBreak ? 'LONG BREAK' : 'BREAK';
    return 'THEN $next ${e.nextPhaseMinutes()} MIN';
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.label, required this.onTap, this.lit = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool lit;

  @override
  Widget build(BuildContext context) => RoundIconButton(
        icon: icon,
        label: label,
        background: lit ? FocusColors.ink : FocusColors.panelHigh,
        foreground: lit ? FocusColors.ground : FocusColors.ink,
        onTap: onTap,
      );
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.engine});
  final FocusEngine engine;

  @override
  Widget build(BuildContext context) {
    final locked = engine.started || engine.phase.isBreak;
    Widget seg(FocusMode m, String label) {
      final on = engine.mode == m;
      return Pressable(
        label: label,
        onTap: locked || on
            ? (locked && !on ? () => showToast(context, 'Finish or reset the timer to switch') : null)
            : () => engine.setMode(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? FocusColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(17)),
          child: Text(label, style: AppText.sans(13.5, weight: FontWeight.w600, color: on ? FocusColors.ground : FocusColors.muted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg(FocusMode.pomodoro, 'Pomodoro'), seg(FocusMode.flow, 'Flowtime')]),
    );
  }
}

class _IntentionPill extends StatelessWidget {
  const _IntentionPill({required this.engine});
  final FocusEngine engine;

  @override
  Widget build(BuildContext context) {
    final note = engine.noteId == null ? null : StoreScope.of(context).note(engine.noteId!);
    final has = engine.intention.isNotEmpty;
    return Pressable(
      onTap: () => showIntentionSheet(context),
      scale: 0.98,
      label: 'Set intention',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: FocusColors.line)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(has ? engine.intention : 'What are you working on?',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.sans(15.5, weight: has ? FontWeight.w600 : FontWeight.w400, color: has ? FocusColors.ink : FocusColors.muted)),
              if (note != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(FocusIcons.note, size: 13, color: FocusColors.muted),
                  const SizedBox(width: 5),
                  Expanded(child: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12.5, color: FocusColors.muted))),
                ]),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Icon(has || note != null ? FocusIcons.edit : AppIcons.add, size: 17, color: FocusColors.muted),
        ]),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: label,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(21)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: FocusColors.ink),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w500, color: FocusColors.ink))),
          ]),
        ),
      );
}

class _BreakCard extends StatelessWidget {
  const _BreakCard({required this.idea, required this.onBreathe, required this.onNext});

  final (String, String) idea;
  final VoidCallback onBreathe;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: FocusColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('BREAK IDEA', style: AppText.label(10.5, color: FocusColors.sage))),
          Pressable(onTap: onNext, label: 'Another idea', child: Text('Another', style: AppText.sans(13, weight: FontWeight.w600, color: FocusColors.muted))),
        ]),
        const SizedBox(height: 8),
        Text(idea.$1, style: AppText.sans(17, weight: FontWeight.w600, color: FocusColors.ink)),
        const SizedBox(height: 4),
        Text(idea.$2, style: AppText.sans(13.5, color: FocusColors.muted, height: 1.4)),
        const SizedBox(height: 12),
        FocusButton(label: 'Breathe with me', icon: FocusIcons.breathe, quiet: true, height: 44, onTap: onBreathe),
      ]),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({required this.engine});
  final FocusEngine engine;

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final store = e.store;
    final showPresets = !e.started && e.phase == FocusPhase.focus && e.mode == FocusMode.pomodoro;
    final label = e.running ? 'PAUSE' : (e.started ? 'RESUME' : (e.phase.isBreak ? 'START BREAK' : 'START'));
    final skipLabel = e.phase.isBreak ? 'Skip break' : (e.countsUp ? 'Finish and take a break' : 'Finish now');
    final canSkip = e.phase.isBreak ? !e.breakLocked : e.started;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FocusColors.card, borderRadius: BorderRadius.circular(Radii.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showPresets) ...[
          Row(children: [
            Expanded(child: Text('Session length', style: AppText.sans(13, color: FocusColors.cardMuted))),
            Pressable(
              onTap: () => showPresetSheet(context),
              label: 'Presets',
              child: Text('Presets', style: AppText.sans(13, weight: FontWeight.w600, color: FocusColors.cardInk)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in store.presets)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Pressable(
                    label: '${p.name}, ${p.focus} minutes',
                    onTap: () => e.setPreset(p.id),
                    onLongPress: () => showPresetSheet(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 74,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: store.preset.id == p.id ? FocusColors.cardInk : FocusColors.cardSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${p.focus}', style: AppText.dot(22, color: store.preset.id == p.id ? FocusColors.card : FocusColors.cardInk)),
                        const SizedBox(height: 3),
                        Text(p.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(8.5, color: store.preset.id == p.id ? FocusColors.cardSoft : FocusColors.cardMuted)),
                      ]),
                    ),
                  ),
                ),
              Pressable(
                label: 'New preset',
                onTap: () => showPresetEditor(context),
                child: Container(
                  width: 58,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: FocusColors.cardSoft, width: 1.5)),
                  child: const Icon(AppIcons.add, size: 20, color: FocusColors.cardInk),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        Row(children: [
          RoundIconButton(
            icon: AppIcons.restore,
            label: e.started ? 'Reset this ${e.phase.isBreak ? 'break' : 'round'}' : 'Back to round 1',
            size: 52,
            background: FocusColors.cardSoft,
            foreground: FocusColors.cardInk,
            onTap: e.started ? e.reset : (e.round > 1 || e.phase.isBreak ? e.restartCycle : null),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              label: label,
              onTap: e.toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: e.running ? FocusColors.cardInk : FocusColors.red, borderRadius: BorderRadius.circular(28)),
                child: Text(label, style: AppText.label(14, color: Colors.white, tracking: 0.2)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          RoundIconButton(
            icon: e.countsUp ? FocusIcons.stop : FocusIcons.skip,
            label: skipLabel,
            size: 52,
            background: FocusColors.cardSoft,
            foreground: canSkip ? FocusColors.cardInk : FocusColors.cardMuted.withValues(alpha: 0.5),
            onTap: canSkip ? e.finishNow : null,
          ),
        ]),
      ]),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = FocusEngineScope.of(context).store;
    final now = DateTime.now();
    final mins = store.secondsOn(now) ~/ 60;
    final goal = store.dailyGoal;
    final rounds = store.roundsOn(now);
    final streak = store.streak(now);
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      label: 'Today: $mins of $goal minutes',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: FocusColors.line)),
        child: Row(children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(56, 56), painter: DotRing(progress: goal == 0 ? 0 : mins / goal, on: FocusColors.red, off: FocusColors.line, dots: 24)),
              Text('${math.min(999, (goal == 0 ? 0 : mins * 100 ~/ goal))}%', style: AppText.label(9.5, color: FocusColors.ink, tracking: 0.05)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TODAY', style: AppText.label(10.5, color: FocusColors.muted)),
              const SizedBox(height: 4),
              Text('${focusDuration(mins * 60)} of ${focusDuration(goal * 60)}', style: AppText.sans(16, weight: FontWeight.w600, color: FocusColors.ink)),
              const SizedBox(height: 2),
              Text('$rounds ${rounds == 1 ? 'round' : 'rounds'}', style: AppText.sans(12.5, color: FocusColors.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Icon(FocusIcons.flame, size: 16, color: streak > 0 ? FocusColors.red : FocusColors.dim),
              const SizedBox(width: 4),
              Text('$streak', style: AppText.dot(24, color: FocusColors.ink)),
            ]),
            Text('DAY STREAK', style: AppText.label(9.5, color: FocusColors.muted)),
          ]),
        ]),
      ),
    );
  }
}
