import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/data/assistant.dart';
import 'package:life_os/data/focus_store.dart';
import 'package:life_os/data/models.dart';
import 'package:life_os/data/money_models.dart';
import 'package:life_os/data/money_store.dart';
import 'package:life_os/data/share_inbox.dart';
import 'package:life_os/data/store.dart';
import 'package:life_os/features/share/share_app.dart';
import 'package:life_os/theme/app_theme.dart';
import 'package:life_os/theme/tokens.dart';

void main() {
  late Directory dir;
  late NoteStore notes;
  late MoneyStore money;
  late FocusStore focus;
  late Assistant assistant;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('life_os_v2');
    notes = await NoteStore.openForTest(dir.path);
    money = await MoneyStore.openForTest(dir.path, suffix: 'v2');
    focus = await FocusStore.openForTest(dir.path, suffix: 'v2');
    assistant = await Assistant.open(notes: notes, money: money, focus: focus, box: 'assistant_v2');
  });

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  group('share inbox', () {
    test('a shared link becomes a titled note', () {
      final n = sharedNote(text: 'https://www.facebook.com/share/p/abc123/', note: '');
      expect(n.title, 'Link from facebook.com');
      expect(n.blocks.single.text, 'https://www.facebook.com/share/p/abc123/');
      final m = sharedNote(text: 'Look at this https://m.facebook.com/x', note: 'Recipe for Friday\nwith rice');
      expect(m.title, 'Recipe for Friday');
      expect(m.blocks.length, 2);
      expect(hostOf('https://m.facebook.com/x'), 'facebook.com');
    });

    test('shares are imported once, into a new folder when asked', () {
      final inbox = ShareInbox.at(Directory('${dir.path}/inbox'));
      inbox.writeFolders(notes.folders);
      expect(inbox.readFolders().length, notes.folders.length);
      inbox.add(text: 'https://example.com/a', note: 'Read later', newFolder: 'Reading');
      inbox.add(text: 'https://example.com/b', folderId: notes.folders.first.id);
      final before = notes.notes().length;
      expect(inbox.importInto(notes), 2);
      expect(notes.notes().length, before + 2);
      expect(notes.folders.any((f) => f.name == 'Reading'), isTrue);
      expect(inbox.importInto(notes), 0);
    });
  });

  group('assistant tools', () {
    test('note search ranks title matches first', () {
      notes.createNote(title: 'Flight to Sylhet', blocks: [Block(text: 'Biman BG 601, seat 14A')]);
      final log = <ToolNote>[];
      final r = assistant.runTool('search_notes', {'query': 'sylhet flight'}, log) as Map;
      expect((r['notes'] as List).first['title'], 'Flight to Sylhet');
      expect(log.single.label, contains('sylhet'));
      final id = (r['notes'] as List).first['id'] as String;
      final read = assistant.runTool('read_note', {'id': id}, log) as Map;
      expect(read['markdown'], contains('14A'));
    });

    test('money and focus summaries', () {
      final food = money.categories(CategoryKind.expense).firstWhere((c) => c.name == 'Food');
      money.addTxn(kind: TxnKind.expense, amount: 125000, accountId: money.accounts.first.id, categoryId: food.id, note: 'Kacchi');
      final log = <ToolNote>[];
      final m = assistant.runTool('money_overview', {}, log) as Map;
      expect(m['spent'], '৳1,250');
      final t = assistant.runTool('list_transactions', {'category': 'food'}, log) as Map;
      expect(t['count'], 1);
      expect(t['total_spent'], '৳1,250');
      final f = assistant.runTool('focus_overview', {}, log) as Map;
      expect(f['streak_days'], 0);
    });

    test('create note turns text into blocks', () {
      final log = <ToolNote>[];
      final r = assistant.runTool('create_note', {'title': 'Packing', 'text': '- Charger\n[] Passport\nRemember tickets'}, log) as Map;
      final n = notes.note(r['id'] as String)!;
      expect(n.blocks.map((b) => b.type), [BlockType.bullet, BlockType.checklist, BlockType.paragraph]);
      expect(log.single.noteId, n.id);
    });

    test('function calling loop: looks up, then answers', () async {
      assistant.apiKey = 'test-key';
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(req.headers['X-goog-api-key'] ?? req.headers['x-goog-api-key'], 'test-key');
        final body = jsonDecode(req.body) as Map;
        if (calls == 1) {
          return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {
                          'functionCall': {'name': 'search_notes', 'args': {'query': 'sylhet'}}
                        }
                      ]
                    }
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json'});
        }
        final last = (body['contents'] as List).last as Map;
        expect(((last['parts'] as List).first as Map).containsKey('functionResponse'), isTrue);
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [
                      {'text': 'Your **Flight to Sylhet** note says seat 14A.'}
                    ]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      await assistant.send('Where is my seat to Sylhet?', client: client);
      expect(calls, 2);
      expect(assistant.messages.last.text, contains('14A'));
      expect(assistant.messages.last.tools.single.label, contains('sylhet'));
    });

    test('missing key gives a clear message', () async {
      assistant.apiKey = '';
      await assistant.send('hello');
      expect(assistant.messages.last.error, isTrue);
      expect(assistant.messages.last.text, contains('API key'));
    });
  });

  testWidgets('share popup saves into the inbox', (tester) async {
    final inbox = ShareInbox.at(Directory('${dir.path}/popup'));
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColors.light),
      home: ShareSheet(inbox: inbox, shared: (text: 'https://www.facebook.com/reel/42', subject: '')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Save to Life OS'), findsOneWidget);
    expect(find.text('facebook.com'), findsOneWidget);
    await tester.tap(find.text('New folder'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).last, 'Reels');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    final files = inbox.dir.listSync().where((f) => f.path.endsWith('.share')).toList();
    expect(files.length, 1);
    expect(File(files.single.path).readAsStringSync(), contains('Reels'));
  });
}
