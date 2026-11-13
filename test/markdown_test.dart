import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/data/markdown.dart';
import 'package:life_os/data/models.dart';

void main() {
  group('detectShortcut', () {
    test('headings', () {
      expect(detectShortcut('# Title')!.type, BlockType.heading1);
      expect(detectShortcut('## Sub')!.type, BlockType.heading2);
      expect(detectShortcut('### Small')!.rest, 'Small');
    });

    test('lists and checklists', () {
      expect(detectShortcut('- item')!.type, BlockType.bullet);
      expect(detectShortcut('1. first')!.type, BlockType.numbered);
      expect(detectShortcut('[] task')!.type, BlockType.checklist);
      expect(detectShortcut('[ ] task')!.rest, 'task');
      final done = detectShortcut('[x] done')!;
      expect(done.type, BlockType.checklist);
      expect(done.checked, isTrue);
      expect(done.rest, 'done');
    });

    test('quote, code and divider', () {
      expect(detectShortcut('> said')!.type, BlockType.quote);
      expect(detectShortcut('```')!.type, BlockType.code);
      expect(detectShortcut('---')!.type, BlockType.divider);
    });

    test('plain text is left alone', () {
      expect(detectShortcut('Hello'), isNull);
      expect(detectShortcut('#hashtag'), isNull);
      expect(detectShortcut('-'), isNull);
    });
  });

  test('noteToMarkdown writes portable Markdown', () {
    final note = Note(title: 'Trip', blocks: [
      Block(text: 'Plan'),
      Block(type: BlockType.checklist, text: 'Tickets', checked: true),
      Block(type: BlockType.checklist, text: 'Hotel'),
      Block(type: BlockType.numbered, text: 'One'),
      Block(type: BlockType.numbered, text: 'Two'),
      Block(type: BlockType.divider),
    ]);
    final md = noteToMarkdown(note);
    expect(md, contains('# Trip'));
    expect(md, contains('- [x] Tickets'));
    expect(md, contains('- [ ] Hotel'));
    expect(md, contains('1. One'));
    expect(md, contains('2. Two'));
    expect(md, contains('---'));
  });
}
