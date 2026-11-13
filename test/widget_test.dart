import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/data/focus_engine.dart';
import 'package:life_os/data/focus_store.dart';
import 'package:life_os/data/models.dart';
import 'package:life_os/data/money_store.dart';
import 'package:life_os/data/store.dart';
import 'package:life_os/shell/root_shell.dart';
import 'package:life_os/ui/widgets.dart';

void main() {
  late NoteStore store;
  late MoneyStore money;
  late FocusEngine focus;
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('life_os_test');
    store = await NoteStore.openForTest(dir.path);
    money = await MoneyStore.openForTest(dir.path, suffix: 'widget');
    focus = FocusEngine(await FocusStore.openForTest(dir.path, suffix: 'widget'));
  });

  setUp(() => shellTab.value = 0);

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('first run seeds a welcome note and two folders', () {
    expect(store.folders.length, 2);
    expect(store.pinned.single.title, 'Welcome to Life OS');
  });

  test('search finds notes by any word in their blocks', () {
    expect(store.notes(query: 'priorities').single.title, 'Weekly review');
    expect(store.notes(query: 'nothing-matches-this'), isEmpty);
  });

  test('trash and restore', () {
    final n = store.createNote(title: 'Temp', blocks: [Block(text: 'x')]);
    store.moveToTrash(n);
    expect(store.notes().any((e) => e.id == n.id), isFalse);
    expect(store.trash.any((e) => e.id == n.id), isTrue);
    store.restore(n);
    expect(store.notes().any((e) => e.id == n.id), isTrue);
  });

  testWidgets('home shows the notes title and pinned note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(LifeOsApp(store: store, money: money, focus: focus));
    await tester.pump();
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Welcome to Life OS'), findsOneWidget);
  });

  testWidgets('money tab shows the Global deposit and opens the add sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(LifeOsApp(store: store, money: money, focus: focus));
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.money));
    await tester.pumpAndSettle();
    expect(find.text('GLOBAL DEPOSIT'), findsOneWidget);
    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);
    for (final k in ['1', '2', '5']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    expect(find.text('Save expense'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(money.spent(DateTime.now()), 12500);
  });

  testWidgets('focus tab starts and pauses the timer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(LifeOsApp(store: store, money: money, focus: focus));
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.focus));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    await tester.tap(find.text('START'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(focus.running, isTrue);
    expect(find.text('PAUSE'), findsOneWidget);
    await tester.tap(find.text('PAUSE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(focus.running, isFalse);
    expect(find.text('RESUME'), findsOneWidget);
    focus.reset();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
