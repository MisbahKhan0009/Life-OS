import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/data/models.dart';

void main() {
  test('note survives a round trip through its map', () {
    final note = Note(title: 'Weekly review', pinned: true, folderId: 'f1', blocks: [
      Block(type: BlockType.checklist, text: 'Pick three priorities', checked: true),
      Block(type: BlockType.image, imageId: 'img1', width: 0.5, text: 'Caption'),
    ]);
    final back = Note.fromMap(note.toMap());
    expect(back.id, note.id);
    expect(back.title, 'Weekly review');
    expect(back.pinned, isTrue);
    expect(back.folderId, 'f1');
    expect(back.blocks.length, 2);
    expect(back.blocks.first.checked, isTrue);
    expect(back.blocks.last.type, BlockType.image);
    expect(back.blocks.last.width, 0.5);
    expect(back.doneTasks, 1);
    expect(back.hasImage, isTrue);
  });

  test('display title falls back to the first line of text', () {
    final note = Note(blocks: [Block(text: 'Groceries\nmilk')]);
    expect(note.displayTitle, 'Groceries');
    expect(Note().displayTitle, 'Untitled');
  });

  test('unknown block types load as text', () {
    final b = Block.fromMap({'id': 'x', 'type': 'table', 'text': 'hi'});
    expect(b.type, BlockType.paragraph);
  });
}
