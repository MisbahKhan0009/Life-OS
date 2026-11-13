import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'focus_models.dart';

/// Sessions, presets and Focus settings, kept in memory and written to Hive.
/// Call after Hive has been initialised (NoteStore.open does that).
class FocusStore extends ChangeNotifier {
  FocusStore._(this._sessions, this._presets, this._settings);

  final Box _sessions;
  final Box _presets;
  final Box _settings;

  final Map<String, FocusSession> _sessionCache = {};
  final Map<String, FocusPreset> _presetCache = {};

  static Future<FocusStore> open() async {
    final s = FocusStore._(await Hive.openBox('focus_sessions'), await Hive.openBox('focus_presets'), await Hive.openBox('focus_settings'));
    s._load();
    return s;
  }

  @visibleForTesting
  static Future<FocusStore> openForTest(String path, {String suffix = 'test'}) async {
    Hive.init(path);
    final s = FocusStore._(
      await Hive.openBox('focus_sessions_$suffix'),
      await Hive.openBox('focus_presets_$suffix'),
      await Hive.openBox('focus_settings_$suffix'),
    );
    s._load();
    return s;
  }

  void _load() {
    for (final v in _sessions.values) {
      if (v is Map) {
        final x = FocusSession.fromMap(v);
        _sessionCache[x.id] = x;
      }
    }
    for (final v in _presets.values) {
      if (v is Map) {
        final p = FocusPreset.fromMap(v);
        _presetCache[p.id] = p;
      }
    }
    if (_presetCache.isEmpty) {
      for (final p in FocusPreset.defaults()) {
        _presetCache[p.id] = p;
        _presets.put(p.id, p.toMap());
      }
    }
  }

  // ---------- settings ----------

  T _get<T>(String key, T fallback) {
    final v = _settings.get(key);
    return v is T ? v : fallback;
  }

  void _set(String key, Object? value) {
    _settings.put(key, value);
    notifyListeners();
  }

  String get presetId => _get<String>('preset', 'classic');
  set presetId(String v) => _set('preset', v);

  FocusMode get mode => _get<String>('mode', 'pomodoro') == 'flow' ? FocusMode.flow : FocusMode.pomodoro;
  set mode(FocusMode v) => _set('mode', v.name);

  bool get autoBreaks => _get<bool>('autoBreaks', true);
  set autoBreaks(bool v) => _set('autoBreaks', v);

  bool get autoFocus => _get<bool>('autoFocus', false);
  set autoFocus(bool v) => _set('autoFocus', v);

  /// A long break after this many focus rounds.
  int get longEvery => _get<int>('longEvery', 4);
  set longEvery(int v) => _set('longEvery', v.clamp(2, 8));

  /// Daily focus goal in minutes.
  int get dailyGoal => _get<int>('dailyGoal', 120);
  set dailyGoal(int v) => _set('dailyGoal', v.clamp(15, 720));

  /// Leaving the app during focus marks the session as broken.
  bool get strict => _get<bool>('strict', false);
  set strict(bool v) => _set('strict', v);

  /// Breaks can't be skipped and focus can't restart until they end.
  bool get lockBreaks => _get<bool>('lockBreaks', false);
  set lockBreaks(bool v) => _set('lockBreaks', v);

  bool get chime => _get<bool>('chime', true);
  set chime(bool v) => _set('chime', v);

  bool get vibrate => _get<bool>('vibrate', true);
  set vibrate(bool v) => _set('vibrate', v);

  bool get tick => _get<bool>('tick', false);
  set tick(bool v) => _set('tick', v);

  double get chimeVolume => _get<double>('chimeVolume', 0.8);
  set chimeVolume(double v) => _set('chimeVolume', v.clamp(0.0, 1.0));

  /// Ambient sound volumes by name, 0 is off.
  Map<String, double> get soundMix {
    final raw = _settings.get('mix');
    if (raw is! Map) return {};
    return {for (final e in raw.entries) e.key.toString(): (e.value as num).toDouble()};
  }

  void setSound(String name, double volume) {
    final mix = soundMix;
    if (volume <= 0) {
      mix.remove(name);
    } else {
      mix[name] = volume.clamp(0.0, 1.0);
    }
    _set('mix', mix);
  }

  void clearSounds() => _set('mix', <String, double>{});

  /// Ambient sounds pause when the timer pauses or a break starts.
  bool get soundsFollowTimer => _get<bool>('soundsFollow', true);
  set soundsFollowTimer(bool v) => _set('soundsFollow', v);

  /// Focus music links (Spotify, YouTube, YouTube Music) as maps {id, name, url}.
  List<Map<String, String>> get musicSources {
    final raw = _settings.get('music');
    if (raw is! List) return const [];
    return [
      for (final m in raw)
        if (m is Map) {for (final e in m.entries) e.key.toString(): e.value.toString()}
    ];
  }

  set musicSources(List<Map<String, String>> v) => _set('music', v);

  bool get musicSeeded => _get<bool>('musicSeeded', false);
  set musicSeeded(bool v) => _settings.put('musicSeeded', v);

  /// The source the Focus music card plays.
  String? get musicId => _settings.get('musicId') as String?;
  set musicId(String? v) => _set('musicId', v);

  /// Play when focus starts, pause on pause and breaks.
  bool get musicFollows => _get<bool>('musicFollows', true);
  set musicFollows(bool v) => _set('musicFollows', v);

  /// Saved engine state so a running timer survives the app closing.
  Map? get engineState => _settings.get('engine') as Map?;
  set engineState(Map? v) => v == null ? _settings.delete('engine') : _settings.put('engine', v);

  // ---------- presets ----------

  List<FocusPreset> get presets {
    final list = _presetCache.values.toList();
    list.sort((a, b) {
      if (a.builtin != b.builtin) return a.builtin ? -1 : 1;
      return a.focus.compareTo(b.focus);
    });
    return list;
  }

  FocusPreset get preset => _presetCache[presetId] ?? presets.first;

  FocusPreset? presetById(String id) => _presetCache[id];

  FocusPreset savePreset(FocusPreset p) {
    _presetCache[p.id] = p;
    _presets.put(p.id, p.toMap());
    notifyListeners();
    return p;
  }

  void deletePreset(FocusPreset p) {
    if (p.builtin) return;
    _presetCache.remove(p.id);
    _presets.delete(p.id);
    if (presetId == p.id) _settings.put('preset', 'classic');
    notifyListeners();
  }

  // ---------- sessions ----------

  FocusSession? session(String id) => _sessionCache[id];

  /// Newest first.
  List<FocusSession> sessions({DateTime? from, DateTime? to, String? noteId}) {
    final list = _sessionCache.values.where((s) {
      if (from != null && s.start.isBefore(from)) return false;
      if (to != null && !s.start.isBefore(to)) return false;
      if (noteId != null && s.noteId != noteId) return false;
      return true;
    }).toList();
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  void saveSession(FocusSession s) {
    _sessionCache[s.id] = s;
    _sessions.put(s.id, s.toMap());
    notifyListeners();
  }

  void deleteSession(FocusSession s) {
    _sessionCache.remove(s.id);
    _sessions.delete(s.id);
    notifyListeners();
  }

  /// Latest session still waiting for its check-in (from the last 12 hours).
  FocusSession? get pendingCheckIn {
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    for (final s in sessions(from: cutoff)) {
      if (!s.checkedIn && !s.manual) return s;
    }
    return null;
  }

  // ---------- stats ----------

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  int secondsBetween(DateTime from, DateTime to) => sessions(from: from, to: to).fold(0, (a, s) => a + s.seconds);

  int secondsOn(DateTime day) {
    final d = _day(day);
    return secondsBetween(d, DateTime(d.year, d.month, d.day + 1));
  }

  int roundsOn(DateTime day) {
    final d = _day(day);
    return sessions(from: d, to: DateTime(d.year, d.month, d.day + 1)).where((s) => s.counts).length;
  }

  /// Monday-start week containing [now].
  int weekSeconds(DateTime now) {
    final d = _day(now);
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return secondsBetween(start, DateTime(start.year, start.month, start.day + 7));
  }

  int monthSeconds(DateTime now) => secondsBetween(DateTime(now.year, now.month), DateTime(now.year, now.month + 1));

  int yearSeconds(DateTime now) => secondsBetween(DateTime(now.year), DateTime(now.year + 1));

  Set<DateTime> get _activeDays => {for (final s in _sessionCache.values) if (s.seconds >= 60) _day(s.start)};

  /// Days in a row with focus time, ending today (or yesterday if today is still empty).
  int streak(DateTime now) {
    final days = _activeDays;
    var d = _day(now);
    if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int get bestStreak {
    final days = _activeDays.toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
      best = math.max(best, run);
      prev = d;
    }
    return best;
  }

  /// Focus seconds per day for the [days] days ending today, oldest first.
  List<int> dailySeconds(DateTime now, int days) {
    final today = _day(now);
    final out = List<int>.filled(days, 0);
    final from = DateTime(today.year, today.month, today.day - days + 1);
    for (final s in sessions(from: from)) {
      final i = _day(s.start).difference(from).inDays;
      if (i >= 0 && i < days) out[i] += s.seconds;
    }
    return out;
  }

  /// Focus seconds by hour of day over the last [days] days.
  List<int> hourly(DateTime now, {int days = 30}) {
    final out = List<int>.filled(24, 0);
    for (final s in sessions(from: now.subtract(Duration(days: days)))) {
      out[s.start.hour] += s.seconds;
    }
    return out;
  }

  /// Average session length in seconds over the last [days] days.
  int averageSeconds(DateTime now, {int days = 30}) {
    final list = sessions(from: now.subtract(Duration(days: days)));
    if (list.isEmpty) return 0;
    return list.fold(0, (a, s) => a + s.seconds) ~/ list.length;
  }

  /// Share of non-manual sessions that ran to the end without breaking.
  double? completionRate(DateTime now, {int days = 30}) {
    final list = sessions(from: now.subtract(Duration(days: days))).where((s) => !s.manual).toList();
    if (list.isEmpty) return null;
    return list.where((s) => s.counts).length / list.length;
  }

  /// Average rating or energy (1 to 5) between [daysAgoStart] and [daysAgoEnd] days back.
  double? averageScore(DateTime now, {required bool energy, int daysAgoStart = 30, int daysAgoEnd = 0}) {
    final list = sessions(from: now.subtract(Duration(days: daysAgoStart)), to: now.subtract(Duration(days: daysAgoEnd)))
        .map((s) => energy ? s.energy : s.rating)
        .where((v) => v > 0)
        .toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  /// Linked notes by focus time over the last [days] days, biggest first.
  List<(String, int)> byNote(DateTime now, {int days = 30}) {
    final totals = <String, int>{};
    for (final s in sessions(from: now.subtract(Duration(days: days)))) {
      final id = s.noteId;
      if (id != null) totals[id] = (totals[id] ?? 0) + s.seconds;
    }
    final list = [for (final e in totals.entries) (e.key, e.value)];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  int secondsOnNote(String noteId) => sessions(noteId: noteId).fold(0, (a, s) => a + s.seconds);

  /// All sessions as CSV, oldest first.
  String toCsv({String Function(String? noteId)? noteTitle}) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer('start,end,minutes,mode,preset,note,intention,intention_done,completed,broken,distractions,rating,energy,reflection,manual\n');
    for (final s in sessions().reversed) {
      b.writeln([
        s.start.toIso8601String(),
        s.end.toIso8601String(),
        (s.seconds / 60).toStringAsFixed(1),
        s.mode.name,
        q(s.presetName),
        q(noteTitle?.call(s.noteId) ?? ''),
        q(s.intention),
        s.intentionDone == null ? '' : (s.intentionDone! ? 'yes' : 'no'),
        s.completed ? 'yes' : 'no',
        s.broken ? 'yes' : 'no',
        s.distractionCount,
        s.rating == 0 ? '' : s.rating,
        s.energy == 0 ? '' : s.energy,
        q(s.reflection),
        s.manual ? 'yes' : 'no',
      ].join(','));
    }
    return b.toString();
  }
}
