import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/data/focus_engine.dart';
import 'package:life_os/data/focus_models.dart';
import 'package:life_os/data/focus_store.dart';

void main() {
  late FocusStore store;
  late Directory dir;
  var now = DateTime(2026, 11, 13, 9, 0);
  DateTime clock() => now;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('life_os_focus');
    store = await FocusStore.openForTest(dir.path);
  });

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('defaults: three built-in presets, classic selected', () {
    expect(store.presets.map((p) => p.name), ['Classic', 'Long', 'Deep work']);
    expect(store.preset.focus, 25);
    expect(store.longEvery, 4);
  });

  test('a full Pomodoro round logs a session and starts the break on time', () {
    now = DateTime(2026, 11, 13, 9, 0);
    store.autoBreaks = true;
    store.autoFocus = false;
    final e = FocusEngine(store, clock: clock);
    e.link(intention: 'Draft section 2');
    e.start();
    now = now.add(const Duration(minutes: 10));
    e.tick();
    expect(e.remainingSeconds, 15 * 60);
    e.logDistraction('Check email');

    // App slept past the end: the session ends at exactly 25 minutes and the break has been running since.
    now = now.add(const Duration(minutes: 17));
    e.tick();
    final s = store.sessions().first;
    expect(s.seconds, 25 * 60);
    expect(s.end, DateTime(2026, 11, 13, 9, 25));
    expect(s.intention, 'Draft section 2');
    expect(s.distractions, ['Check email']);
    expect(s.completed, isTrue);
    expect(e.phase, FocusPhase.shortBreak);
    expect(e.running, isTrue);
    expect(e.remainingSeconds, 3 * 60);

    // Break ends; next focus waits for a tap.
    now = now.add(const Duration(minutes: 5));
    e.tick();
    expect(e.phase, FocusPhase.focus);
    expect(e.round, 2);
    expect(e.running, isFalse);
    e.dispose();
  });

  test('pause keeps time, +5 extends, ending early keeps the time', () {
    now = DateTime(2026, 11, 13, 14, 0);
    final e = FocusEngine(store, clock: clock);
    e.restartCycle();
    e.start();
    now = now.add(const Duration(minutes: 5));
    e.pause();
    now = now.add(const Duration(minutes: 30));
    expect(e.elapsedSeconds, 5 * 60);
    e.addFive();
    expect(e.remainingSeconds, 25 * 60);
    e.start();
    now = now.add(const Duration(minutes: 3));
    e.finishNow();
    final s = store.sessions().first;
    expect(s.seconds, 8 * 60);
    expect(s.completed, isFalse);
    expect(e.phase, FocusPhase.shortBreak);
    e.dispose();
  });

  test('long break after the set number of rounds', () {
    now = DateTime(2026, 11, 13, 16, 0);
    store.longEvery = 2;
    store.autoBreaks = true;
    store.autoFocus = true;
    final e = FocusEngine(store, clock: clock);
    e.restartCycle();
    e.start();
    now = now.add(const Duration(minutes: 25 + 5 + 25 + 1));
    e.tick();
    expect(e.phase, FocusPhase.longBreak);
    expect(e.round, 2);
    now = now.add(const Duration(minutes: 15));
    e.tick();
    expect(e.phase, FocusPhase.focus);
    expect(e.round, 1);
    e.pause();
    store.longEvery = 4;
    e.dispose();
  });

  test('Flowtime counts up and suggests a fifth as break', () {
    now = DateTime(2026, 11, 13, 19, 0);
    store.autoBreaks = false;
    final e = FocusEngine(store, clock: clock);
    e.restartCycle();
    e.setMode(FocusMode.flow);
    e.start();
    now = now.add(const Duration(minutes: 50));
    e.tick();
    expect(e.countsUp, isTrue);
    expect(e.displaySeconds, 50 * 60);
    expect(e.nextPhaseMinutes(), 10);
    e.finishNow();
    expect(e.phase, FocusPhase.shortBreak);
    expect(e.targetSeconds, 10 * 60);
    expect(store.sessions().first.mode, FocusMode.flow);
    e.setMode(FocusMode.pomodoro);
    e.dispose();
  });

  test('state survives a restart', () {
    now = DateTime(2026, 11, 13, 21, 0);
    final e = FocusEngine(store, clock: clock);
    e.restartCycle();
    e.link(intention: 'Read');
    e.start();
    now = now.add(const Duration(minutes: 7));
    e.dispose();
    final again = FocusEngine(store, clock: clock);
    expect(again.running, isTrue);
    expect(again.elapsedSeconds, 7 * 60);
    expect(again.intention, 'Read');
    again.reset();
    again.dispose();
  });

  test('stats: totals, streak, rate and CSV', () {
    final day = DateTime(2026, 11, 13);
    expect(store.secondsOn(day), greaterThan(0));
    expect(store.roundsOn(day), greaterThanOrEqualTo(1));
    expect(store.streak(DateTime(2026, 11, 13, 23)), 1);
    store.saveSession(FocusSession(
      start: DateTime(2026, 11, 12, 10),
      end: DateTime(2026, 11, 12, 10, 25),
      seconds: 1500,
      manual: true,
    ));
    expect(store.streak(DateTime(2026, 11, 13, 23)), 2);
    expect(store.bestStreak, 2);
    expect(store.dailySeconds(DateTime(2026, 11, 13, 23), 7).length, 7);
    expect(store.completionRate(DateTime(2026, 11, 13, 23)), isNotNull);
    expect(store.toCsv().split('\n').first, startsWith('start,end,minutes'));
    expect(focusDuration(3900), '1h 05m');
    expect(flowBreakMinutes(50 * 60), 10);
  });
}
