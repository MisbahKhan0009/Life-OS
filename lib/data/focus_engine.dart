import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'focus_models.dart';
import 'focus_store.dart';

enum FocusEventKind { started, paused, focusDone, breakDone, skipped, broken }

class FocusEvent {
  const FocusEvent(this.kind, {this.session, this.nextPhase});
  final FocusEventKind kind;

  /// The session that was just logged (for [FocusEventKind.focusDone]).
  final FocusSession? session;
  final FocusPhase? nextPhase;
}

/// The Focus timer. Time is measured from the wall clock, not counted in ticks,
/// so it stays right when the app sleeps in the background or is closed and
/// reopened (the state is saved on every change).
class FocusEngine extends ChangeNotifier with WidgetsBindingObserver {
  FocusEngine(this.store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _restore();
    store.addListener(notifyListeners);
  }

  final FocusStore store;
  final DateTime Function() _clock;
  final _events = StreamController<FocusEvent>.broadcast();
  Timer? _ticker;

  Stream<FocusEvent> get events => _events.stream;

  // ---------- state ----------

  FocusPhase _phase = FocusPhase.focus;
  int _round = 1;
  DateTime? _runningSince;
  int _elapsedBeforeMs = 0;
  int _extraSeconds = 0;
  DateTime? _phaseStartedAt;

  /// For Flowtime: the break length earned by the last focus block.
  int _flowBreakMinutes = 5;

  String? _noteId;
  String _intention = '';
  final List<String> _distractions = [];
  int _distractionCount = 0;
  bool _broken = false;

  FocusPhase get phase => _phase;
  int get round => _round;
  FocusMode get mode => store.mode;
  bool get running => _runningSince != null;
  bool get started => running || _elapsedBeforeMs > 0;
  String? get noteId => _noteId;
  String get intention => _intention;
  int get distractionCount => _distractionCount;
  List<String> get distractions => List.unmodifiable(_distractions);
  bool get broken => _broken;
  DateTime? get phaseStartedAt => _phaseStartedAt;

  /// Flowtime focus counts up with no end.
  bool get countsUp => mode == FocusMode.flow && _phase == FocusPhase.focus;

  bool get breakLocked => store.lockBreaks && _phase.isBreak;

  int get elapsedMs => _elapsedBeforeMs + (_runningSince == null ? 0 : _clock().difference(_runningSince!).inMilliseconds);

  int get elapsedSeconds => elapsedMs ~/ 1000;

  /// Length of the current phase in seconds (0 when counting up).
  int get targetSeconds {
    if (countsUp) return 0;
    final base = mode == FocusMode.flow ? _flowBreakMinutes : store.preset.minutesFor(_phase);
    return base * 60 + _extraSeconds;
  }

  int get remainingSeconds => countsUp ? 0 : math.max(0, targetSeconds - elapsedSeconds);

  /// Seconds to show on the dial: time left, or time worked in Flowtime.
  int get displaySeconds => countsUp ? elapsedSeconds : remainingSeconds;

  /// 0 to 1 through the phase. Flowtime fills once per hour.
  double get progress {
    if (countsUp) return (elapsedSeconds % 3600) / 3600;
    final t = targetSeconds;
    return t == 0 ? 0 : (elapsedSeconds / t).clamp(0.0, 1.0);
  }

  /// What comes after this phase.
  FocusPhase get nextPhase {
    if (_phase.isBreak) return FocusPhase.focus;
    if (mode == FocusMode.flow) return FocusPhase.shortBreak;
    return _round >= store.longEvery ? FocusPhase.longBreak : FocusPhase.shortBreak;
  }

  int nextPhaseMinutes() {
    final n = nextPhase;
    if (mode == FocusMode.flow) return n == FocusPhase.focus ? 0 : flowBreakMinutes(elapsedSeconds);
    return store.preset.minutesFor(n);
  }

  // ---------- lifecycle ----------

  /// Starts watching the app lifecycle (strict mode and catching up after sleep).
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    if (running) _startTicker();
    tick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (running && _phase == FocusPhase.focus && store.strict && !_broken) {
        _broken = true;
        _save();
        _events.add(const FocusEvent(FocusEventKind.broken));
      }
    } else if (state == AppLifecycleState.resumed) {
      tick();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    store.removeListener(notifyListeners);
    _events.close();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ---------- controls ----------

  void start() {
    if (running) return;
    final now = _clock();
    _runningSince = now;
    _phaseStartedAt ??= now;
    _startTicker();
    _changed();
    _events.add(FocusEvent(FocusEventKind.started, nextPhase: _phase));
  }

  void pause() {
    if (!running) return;
    _elapsedBeforeMs = elapsedMs;
    _runningSince = null;
    _stopTicker();
    _changed();
    _events.add(const FocusEvent(FocusEventKind.paused));
  }

  void toggle() => running ? pause() : start();

  /// Adds five minutes to a countdown.
  void addFive() {
    if (countsUp) return;
    _extraSeconds += 300;
    _changed();
  }

  /// Ends the current phase now. Focus time so far is kept as a session.
  void finishNow() {
    if (breakLocked) return;
    final at = _clock();
    if (_phase == FocusPhase.focus) {
      if (elapsedSeconds >= 60) {
        _completeFocus(at, early: !countsUp);
      } else {
        _resetPhase();
        _changed();
      }
    } else {
      _completeBreak(at, skipped: true);
    }
  }

  /// Skips to the next phase without logging (focus under a minute) or logs what was done.
  void skip() => finishNow();

  /// Throws away the current phase and goes back to the start of it.
  void reset() {
    _resetPhase();
    _changed();
  }

  /// Back to round 1 of focus.
  void restartCycle() {
    _phase = FocusPhase.focus;
    _round = 1;
    _resetPhase();
    _changed();
  }

  void setMode(FocusMode m) {
    if (started) return;
    store.mode = m;
    _phase = FocusPhase.focus;
    _round = 1;
    _resetPhase();
    _changed();
  }

  void setPreset(String id) {
    if (started) return;
    store.presetId = id;
    _changed();
  }

  void link({String? noteId, String? intention}) {
    _noteId = noteId;
    if (intention != null) _intention = intention.trim();
    _changed();
  }

  void unlinkNote() {
    _noteId = null;
    _changed();
  }

  void logDistraction([String? text]) {
    _distractionCount++;
    final t = text?.trim() ?? '';
    if (t.isNotEmpty) _distractions.add(t);
    _changed();
  }

  /// Called by the ticker and on resume. Completes any phases whose time is up,
  /// timing each completion at the exact moment it ended.
  void tick() {
    var guard = 0;
    while (running && !countsUp && targetSeconds > 0 && elapsedMs >= targetSeconds * 1000 && guard < 50) {
      guard++;
      final endedAt = _runningSince!.add(Duration(milliseconds: targetSeconds * 1000 - _elapsedBeforeMs));
      if (_phase == FocusPhase.focus) {
        _completeFocus(endedAt, early: false);
      } else {
        _completeBreak(endedAt, skipped: false);
      }
    }
    if (running) notifyListeners();
  }

  // ---------- phase changes ----------

  void _completeFocus(DateTime at, {required bool early}) {
    final runMs = _runningSince == null ? 0 : at.difference(_runningSince!).inMilliseconds;
    final worked = math.max(0, _elapsedBeforeMs + runMs) ~/ 1000;
    final session = FocusSession(
      start: _phaseStartedAt ?? at.subtract(Duration(seconds: worked)),
      end: at,
      seconds: worked,
      planned: countsUp ? 0 : targetSeconds,
      mode: mode,
      presetName: mode == FocusMode.flow ? 'Flowtime' : store.preset.name,
      noteId: _noteId,
      intention: _intention,
      distractions: List.of(_distractions),
      distractionCount: _distractionCount,
      completed: !early,
      broken: _broken,
    );
    store.saveSession(session);
    if (mode == FocusMode.flow) _flowBreakMinutes = flowBreakMinutes(worked);

    final next = nextPhase;
    final wasRunning = running;
    _phase = next;
    _distractions.clear();
    _distractionCount = 0;
    _broken = false;
    _beginPhase(at, autostart: wasRunning && store.autoBreaks);
    _changed();
    _events.add(FocusEvent(FocusEventKind.focusDone, session: session, nextPhase: next));
  }

  void _completeBreak(DateTime at, {required bool skipped}) {
    final wasLong = _phase == FocusPhase.longBreak;
    final wasRunning = running;
    _round = wasLong || mode == FocusMode.flow ? 1 : _round + 1;
    _phase = FocusPhase.focus;
    _beginPhase(at, autostart: wasRunning && !skipped && store.autoFocus);
    _changed();
    _events.add(FocusEvent(skipped ? FocusEventKind.skipped : FocusEventKind.breakDone, nextPhase: FocusPhase.focus));
  }

  void _beginPhase(DateTime at, {required bool autostart}) {
    _elapsedBeforeMs = 0;
    _extraSeconds = 0;
    if (autostart) {
      _runningSince = at;
      _phaseStartedAt = at;
      _startTicker();
    } else {
      _runningSince = null;
      _phaseStartedAt = null;
      _stopTicker();
    }
  }

  void _resetPhase() {
    _runningSince = null;
    _phaseStartedAt = null;
    _elapsedBeforeMs = 0;
    _extraSeconds = 0;
    _broken = false;
    if (_phase == FocusPhase.focus) {
      _distractions.clear();
      _distractionCount = 0;
    }
    _stopTicker();
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  // ---------- persistence ----------

  void _save() {
    store.engineState = {
      'phase': _phase.name,
      'round': _round,
      'runningSince': _runningSince?.millisecondsSinceEpoch,
      'elapsedBefore': _elapsedBeforeMs,
      'extra': _extraSeconds,
      'phaseStartedAt': _phaseStartedAt?.millisecondsSinceEpoch,
      'flowBreak': _flowBreakMinutes,
      'noteId': _noteId,
      'intention': _intention,
      'distractions': List.of(_distractions),
      'distractionCount': _distractionCount,
      'broken': _broken,
    };
  }

  void _restore() {
    final m = store.engineState;
    if (m == null) return;
    DateTime? t(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    _phase = FocusPhase.values.firstWhere((p) => p.name == m['phase'], orElse: () => FocusPhase.focus);
    _round = (m['round'] as num?)?.toInt() ?? 1;
    _runningSince = t(m['runningSince']);
    _elapsedBeforeMs = (m['elapsedBefore'] as num?)?.toInt() ?? 0;
    _extraSeconds = (m['extra'] as num?)?.toInt() ?? 0;
    _phaseStartedAt = t(m['phaseStartedAt']);
    _flowBreakMinutes = (m['flowBreak'] as num?)?.toInt() ?? 5;
    _noteId = m['noteId'] as String?;
    _intention = (m['intention'] as String?) ?? '';
    _distractions
      ..clear()
      ..addAll([for (final d in (m['distractions'] as List? ?? const [])) d.toString()]);
    _distractionCount = (m['distractionCount'] as num?)?.toInt() ?? 0;
    _broken = (m['broken'] as bool?) ?? false;
  }
}

/// Makes the focus store and engine available below the app root.
class FocusEngineScope extends InheritedNotifier<FocusEngine> {
  const FocusEngineScope({super.key, required FocusEngine engine, required super.child}) : super(notifier: engine);

  static FocusEngine of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FocusEngineScope>()!.notifier!;

  static FocusEngine read(BuildContext context) => context.getInheritedWidgetOfExactType<FocusEngineScope>()!.notifier!;
}
