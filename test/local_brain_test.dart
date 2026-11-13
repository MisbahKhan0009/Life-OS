import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/data/focus_models.dart';
import 'package:life_os/data/focus_store.dart';
import 'package:life_os/data/local_brain.dart';
import 'package:life_os/data/models.dart';
import 'package:life_os/data/money_models.dart';
import 'package:life_os/data/money_store.dart';
import 'package:life_os/data/store.dart';
import 'package:life_os/features/focus/focus_music.dart';

void main() {
  late Directory dir;
  late NoteStore notes;
  late MoneyStore money;
  late FocusStore focus;
  late LocalBrain brain;
  final now = DateTime(2026, 11, 13, 15, 0);

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('life_os_brain');
    notes = await NoteStore.openForTest(dir.path);
    money = await MoneyStore.openForTest(dir.path, suffix: 'brain');
    focus = await FocusStore.openForTest(dir.path, suffix: 'brain');
    brain = LocalBrain(notes, money, focus, clock: () => now);

    notes.createNote(title: 'Flight to Sylhet', blocks: [Block(text: 'Biman BG 601, seat 14A')]);
    final cash = money.accounts.first;
    final bkash = money.createAccount(name: 'bKash', kind: AccountKind.wallet, opening: 500000);
    final food = money.categories(CategoryKind.expense).firstWhere((c) => c.name == 'Food');
    final transport = money.categories(CategoryKind.expense).firstWhere((c) => c.name == 'Transport');
    money.addTxn(kind: TxnKind.expense, amount: 45000, accountId: cash.id, categoryId: food.id, note: 'Kacchi', date: DateTime(2026, 11, 12, 13));
    money.addTxn(kind: TxnKind.expense, amount: 30000, accountId: cash.id, categoryId: transport.id, note: 'Pathao', date: DateTime(2026, 11, 13, 9));
    money.addTxn(kind: TxnKind.expense, amount: 900000, accountId: bkash.id, categoryId: food.id, note: 'Wedding gift dinner', date: DateTime(2026, 10, 20));
    focus.saveSession(FocusSession(start: DateTime(2026, 11, 13, 10), end: DateTime(2026, 11, 13, 10, 25), seconds: 1500));
    focus.saveSession(FocusSession(start: DateTime(2026, 11, 11, 10), end: DateTime(2026, 11, 11, 10, 50), seconds: 3000));
  });

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('periods', () {
    expect(parsePeriod('this month', now)!.from, DateTime(2026, 11));
    expect(parsePeriod('last month', now)!.from, DateTime(2026, 10));
    expect(parsePeriod('in october', now)!.from, DateTime(2026, 10));
    expect(parsePeriod('december', now)!.from, DateTime(2025, 12));
    expect(parsePeriod('this week', now)!.from, DateTime(2026, 11, 9));
    expect(parsePeriod('past 3 days', now)!.from, DateTime(2026, 11, 11));
    expect(parsePeriod('may I have', now), isNull);
  });

  test('spending by category, by period and by note words', () {
    var a = brain.answer('How much did I spend on food this month?');
    expect(a.text, contains('৳450'));
    expect(a.cards.single['label'], 'Kacchi');
    a = brain.answer('how much did i spend on lunch last month');
    expect(a.text, contains('৳9,000'));
    a = brain.answer('what did I spend on pathao');
    expect(a.text, contains('৳300'));
    a = brain.answer('spent this month');
    expect(a.text, contains('৳750'));
    expect(a.text, contains('Where it went'));
    a = brain.answer('biggest expense last month');
    expect(a.text, contains('Wedding gift dinner'));
  });

  test('balances and accounts', () {
    var a = brain.answer("what's my global deposit");
    expect(a.text, contains('Global deposit'));
    a = brain.answer('how much is in bkash');
    expect(a.text, contains('bKash'));
    expect(a.text, contains('-৳4,000'));
  });

  test('focus questions', () {
    var a = brain.answer('how was my focus this week');
    expect(a.text, contains('1h 15m'));
    a = brain.answer('focus today');
    expect(a.text, contains('25m'));
    a = brain.answer('what is my streak');
    expect(a.text, contains('1-day'));
  });

  test('notes: search, create, and the Google fallback', () {
    var a = brain.answer('where is my seat to sylhet');
    expect(a.cards.first['title'], 'Flight to Sylhet');
    expect(a.understood, isTrue);
    a = brain.answer('Make a note: weekend trip, charger, passport, tickets');
    final n = notes.notes().firstWhere((x) => x.title == 'Weekend trip');
    expect(n.blocks.length, 3);
    expect(n.blocks.first.type, BlockType.checklist);
    a = brain.answer('who won the world cup in 2022');
    expect(a.understood, isFalse);
    expect(a.google, isNotNull);
  });

  test('music links are recognised', () {
    expect(musicKindOf('https://open.spotify.com/playlist/37i9dQZF1DWZeKCadgRdKQ?si=x'), MusicKind.spotify);
    expect(musicKindOf('https://music.youtube.com/playlist?list=RD'), MusicKind.ytmusic);
    expect(musicKindOf('https://youtu.be/jfKfPfyJRdk'), MusicKind.youtube);
    expect(musicKindOf('https://soundcloud.com/x'), MusicKind.link);
  });
}
