import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/data/models.dart';
import 'package:life_os/data/store.dart';

void main() {
  late NoteStore store;
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('life_os_test');
    store = await NoteStore.openForTest(dir.path);
  });

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
    await tester.pumpWidget(LifeOsApp(store: store));
    await tester.pump();
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Welcome to Life OS'), findsOneWidget);
  });
}
