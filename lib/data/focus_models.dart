import 'models.dart' show newId;

enum FocusMode { pomodoro, flow }

enum FocusPhase { focus, shortBreak, longBreak }

extension FocusPhaseX on FocusPhase {
  bool get isBreak => this != FocusPhase.focus;

  String get label => switch (this) {
        FocusPhase.focus => 'Focus',
        FocusPhase.shortBreak => 'Short break',
        FocusPhase.longBreak => 'Long break',
      };
}

/// Lengths for a Pomodoro cycle, in minutes.
class FocusPreset {
  FocusPreset({String? id, required this.name, required this.focus, required this.shortBreak, required this.longBreak, this.builtin = false})
      : id = id ?? newId();

  final String id;
  String name;
  int focus;
  int shortBreak;
  int longBreak;
  final bool builtin;

  int minutesFor(FocusPhase p) => switch (p) {
        FocusPhase.focus => focus,
        FocusPhase.shortBreak => shortBreak,
        FocusPhase.longBreak => longBreak,
      };

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'focus': focus, 'short': shortBreak, 'long': longBreak, 'builtin': builtin};

  factory FocusPreset.fromMap(Map m) => FocusPreset(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Preset',
        focus: (m['focus'] as num?)?.toInt() ?? 25,
        shortBreak: (m['short'] as num?)?.toInt() ?? 5,
        longBreak: (m['long'] as num?)?.toInt() ?? 15,
        builtin: (m['builtin'] as bool?) ?? false,
      );

  static List<FocusPreset> defaults() => [
        FocusPreset(id: 'classic', name: 'Classic', focus: 25, shortBreak: 5, longBreak: 15, builtin: true),
        FocusPreset(id: 'long', name: 'Long', focus: 50, shortBreak: 10, longBreak: 20, builtin: true),
        FocusPreset(id: 'deep', name: 'Deep work', focus: 90, shortBreak: 20, longBreak: 30, builtin: true),
      ];
}

/// One logged block of focus time.
class FocusSession {
  FocusSession({
    String? id,
    required this.start,
    required this.end,
    required this.seconds,
    this.planned = 0,
    this.mode = FocusMode.pomodoro,
    this.presetName = '',
    this.noteId,
    this.intention = '',
    this.intentionDone,
    List<String>? distractions,
    this.distractionCount = 0,
    this.completed = true,
    this.broken = false,
    this.rating = 0,
    this.energy = 0,
    this.reflection = '',
    this.manual = false,
    this.checkedIn = false,
  })  : id = id ?? newId(),
        distractions = distractions ?? [];

  final String id;
  DateTime start;
  DateTime end;

  /// Focused time actually spent (pauses excluded).
  int seconds;

  /// Planned length in seconds; 0 for Flowtime.
  int planned;
  FocusMode mode;
  String presetName;
  String? noteId;
  String intention;
  bool? intentionDone;
  final List<String> distractions;
  int distractionCount;

  /// Ran to the end rather than ended early.
  bool completed;

  /// Strict mode: you left the app during the session.
  bool broken;

  /// 1 to 5, 0 when not rated.
  int rating;
  int energy;
  String reflection;
  bool manual;
  bool checkedIn;

  int get minutes => (seconds / 60).round();

  /// Counts as a full round for completion rate and the daily round count.
  bool get counts => completed && !broken;

  Map<String, dynamic> toMap() => {
        'id': id,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'seconds': seconds,
        'planned': planned,
        'mode': mode.name,
        'preset': presetName,
        if (noteId != null) 'noteId': noteId,
        'intention': intention,
        if (intentionDone != null) 'intentionDone': intentionDone,
        'distractions': distractions,
        'distractionCount': distractionCount,
        'completed': completed,
        'broken': broken,
        'rating': rating,
        'energy': energy,
        'reflection': reflection,
        'manual': manual,
        'checkedIn': checkedIn,
      };

  factory FocusSession.fromMap(Map m) {
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return FocusSession(
      id: m['id'] as String,
      start: DateTime.fromMillisecondsSinceEpoch(i('start')),
      end: DateTime.fromMillisecondsSinceEpoch(i('end')),
      seconds: i('seconds'),
      planned: i('planned'),
      mode: m['mode'] == 'flow' ? FocusMode.flow : FocusMode.pomodoro,
      presetName: (m['preset'] as String?) ?? '',
      noteId: m['noteId'] as String?,
      intention: (m['intention'] as String?) ?? '',
      intentionDone: m['intentionDone'] as bool?,
      distractions: [for (final d in (m['distractions'] as List? ?? const [])) d.toString()],
      distractionCount: i('distractionCount'),
      completed: (m['completed'] as bool?) ?? true,
      broken: (m['broken'] as bool?) ?? false,
      rating: i('rating'),
      energy: i('energy'),
      reflection: (m['reflection'] as String?) ?? '',
      manual: (m['manual'] as bool?) ?? false,
      checkedIn: (m['checkedIn'] as bool?) ?? false,
    );
  }
}

/// Seconds as "1h 05m", "25m" or "40s".
String focusDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r.toString().padLeft(2, '0')}m';
}

/// Flowtime break suggestion: a fifth of the time worked, 1 to 30 minutes.
int flowBreakMinutes(int workedSeconds) => (workedSeconds / 60 / 5).round().clamp(1, 30);
