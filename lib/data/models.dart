import 'dart:math';

/// Short unique ids without a dependency.
String newId() {
  final r = Random();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final s = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$t$s';
}

enum BlockType { paragraph, heading1, heading2, heading3, bullet, numbered, checklist, quote, code, divider, image }

extension BlockTypeX on BlockType {
  bool get isText => this != BlockType.divider && this != BlockType.image;
  bool get isList => this == BlockType.bullet || this == BlockType.numbered || this == BlockType.checklist;

  String get label => switch (this) {
        BlockType.paragraph => 'Text',
        BlockType.heading1 => 'Heading 1',
        BlockType.heading2 => 'Heading 2',
        BlockType.heading3 => 'Heading 3',
        BlockType.bullet => 'Bulleted list',
        BlockType.numbered => 'Numbered list',
        BlockType.checklist => 'Checklist',
        BlockType.quote => 'Quote',
        BlockType.code => 'Code',
        BlockType.divider => 'Divider',
        BlockType.image => 'Image',
      };
}

/// One block of a note. Images keep their bytes in a separate store under [imageId].
class Block {
  Block({
    String? id,
    this.type = BlockType.paragraph,
    this.text = '',
    this.checked = false,
    this.imageId,
    this.width = 1.0,
  }) : id = id ?? newId();

  final String id;
  BlockType type;
  String text;
  bool checked;
  String? imageId;

  /// Image width as a share of the column, 0.3 to 1.0.
  double width;

  Block copy() => Block(type: type, text: text, checked: checked, imageId: imageId, width: width);

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'text': text,
        'checked': checked,
        if (imageId != null) 'imageId': imageId,
        'width': width,
      };

  factory Block.fromMap(Map<dynamic, dynamic> m) => Block(
        id: m['id'] as String?,
        type: BlockType.values.firstWhere((t) => t.name == m['type'], orElse: () => BlockType.paragraph),
        text: (m['text'] as String?) ?? '',
        checked: (m['checked'] as bool?) ?? false,
        imageId: m['imageId'] as String?,
        width: ((m['width'] as num?) ?? 1.0).toDouble(),
      );
}

class Note {
  Note({
    String? id,
    this.title = '',
    List<Block>? blocks,
    this.folderId,
    this.pinned = false,
    this.locked = false,
    this.archived = false,
    this.trashedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newId(),
        blocks = blocks ?? [Block()],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  List<Block> blocks;
  String? folderId;
  bool pinned;
  bool locked;
  bool archived;
  DateTime? trashedAt;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get inTrash => trashedAt != null;
  bool get isActive => !inTrash && !archived;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    for (final b in blocks) {
      if (b.type.isText && b.text.trim().isNotEmpty) return b.text.trim().split('\n').first;
    }
    return 'Untitled';
  }

  Iterable<Block> get checklist => blocks.where((b) => b.type == BlockType.checklist);
  bool get hasChecklist => checklist.isNotEmpty;
  bool get hasImage => blocks.any((b) => b.type == BlockType.image);
  int get openTasks => checklist.where((b) => !b.checked).length;
  int get doneTasks => checklist.where((b) => b.checked).length;

  /// First readable line that is not the title, for previews.
  String get preview {
    for (final b in blocks) {
      if (b.type.isText && b.type != BlockType.checklist && b.text.trim().isNotEmpty && b.text.trim() != title.trim()) {
        return b.text.trim();
      }
    }
    return '';
  }

  /// Everything searchable in one lowercase string.
  String get searchText => ([title, ...blocks.where((b) => b.type.isText || b.type == BlockType.image).map((b) => b.text)]).join('\n').toLowerCase();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toMap()).toList(),
        'folderId': folderId,
        'pinned': pinned,
        'locked': locked,
        'archived': archived,
        'trashedAt': trashedAt?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<dynamic, dynamic> m) {
    DateTime? d(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    final raw = (m['blocks'] as List?) ?? const [];
    final blocks = raw.whereType<Map>().map((b) => Block.fromMap(b)).toList();
    return Note(
      id: m['id'] as String?,
      title: (m['title'] as String?) ?? '',
      blocks: blocks.isEmpty ? [Block()] : blocks,
      folderId: m['folderId'] as String?,
      pinned: (m['pinned'] as bool?) ?? false,
      locked: (m['locked'] as bool?) ?? false,
      archived: (m['archived'] as bool?) ?? false,
      trashedAt: d(m['trashedAt']),
      createdAt: d(m['createdAt']),
      updatedAt: d(m['updatedAt']),
    );
  }
}

class Folder {
  Folder({String? id, required this.name, this.description = '', this.art = 'tide', DateTime? createdAt})
      : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  String description;
  String art;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'art': art,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Folder.fromMap(Map<dynamic, dynamic> m) => Folder(
        id: m['id'] as String?,
        name: (m['name'] as String?) ?? 'Folder',
        description: (m['description'] as String?) ?? '',
        art: (m['art'] as String?) ?? 'tide',
        createdAt: m['createdAt'] is int ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int) : null,
      );
}
