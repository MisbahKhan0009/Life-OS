import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'models.dart';

enum NoteFilter { all, pinned, checklists, images }

/// Offline-first store for notes, folders, images and settings.
/// Everything is kept in memory and written through to Hive boxes on device.
class NoteStore extends ChangeNotifier {
  NoteStore._(this._notes, this._folders, this._images, this._settings);

  final Box _notes;
  final Box _folders;
  final Box _images;
  final Box _settings;

  final Map<String, Note> _noteCache = {};
  final Map<String, Folder> _folderCache = {};

  static const trashDays = 30;

  static Future<NoteStore> open() async {
    await Hive.initFlutter('life_os');
    final store = NoteStore._(
      await Hive.openBox('notes'),
      await Hive.openBox('folders'),
      await Hive.openBox('images'),
      await Hive.openBox('settings'),
    );
    store._load();
    return store;
  }

  /// In-memory store for tests.
  @visibleForTesting
  static Future<NoteStore> openForTest(String path) async {
    Hive.init(path);
    final store = NoteStore._(
      await Hive.openBox('notes_test'),
      await Hive.openBox('folders_test'),
      await Hive.openBox('images_test'),
      await Hive.openBox('settings_test'),
    );
    store._load();
    return store;
  }

  void _load() {
    for (final v in _notes.values) {
      if (v is Map) {
        final n = Note.fromMap(v);
        _noteCache[n.id] = n;
      }
    }
    for (final v in _folders.values) {
      if (v is Map) {
        final f = Folder.fromMap(v);
        _folderCache[f.id] = f;
      }
    }
    _purgeOldTrash();
    if (_settings.get('seeded') != true) {
      _seed();
      _settings.put('seeded', true);
    }
  }

  // ---------- settings ----------

  /// Shared links waiting for their preview (title, description, image) to be fetched.
  /// Each is {noteId, url, autoTitle, tries}.
  List<Map<String, dynamic>> get pendingLinks {
    final raw = _settings.get('pendingLinks');
    if (raw is! List) return [];
    return [for (final m in raw) if (m is Map) m.cast<String, dynamic>()];
  }

  set pendingLinks(List<Map<String, dynamic>> v) => _settings.put('pendingLinks', v);

  bool get linksBackfilled => _settings.get('linksBackfilled') == true;
  set linksBackfilled(bool v) => _settings.put('linksBackfilled', v);

  ThemeMode get themeMode => switch (_settings.get('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  set themeMode(ThemeMode mode) {
    _settings.put('theme', mode.name);
    notifyListeners();
  }

  // ---------- queries ----------

  List<Note> get _active => _noteCache.values.where((n) => n.isActive).toList();

  Note? note(String id) => _noteCache[id];

  List<Note> notes({NoteFilter filter = NoteFilter.all, String query = '', String? folderId}) {
    final q = query.trim().toLowerCase();
    final list = _active.where((n) {
      if (folderId != null && n.folderId != folderId) return false;
      switch (filter) {
        case NoteFilter.all:
          break;
        case NoteFilter.pinned:
          if (!n.pinned) return false;
        case NoteFilter.checklists:
          if (!n.hasChecklist) return false;
        case NoteFilter.images:
          if (!n.hasImage) return false;
      }
      if (q.isEmpty) return true;
      return q.split(RegExp(r'\s+')).every(n.searchText.contains);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<Note> get pinned => notes(filter: NoteFilter.pinned);

  List<Note> get archived => _noteCache.values.where((n) => n.archived && !n.inTrash).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Note> get trash => _noteCache.values.where((n) => n.inTrash).toList()..sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));

  List<Folder> get folders => _folderCache.values.toList()..sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));

  Folder? folder(String? id) => id == null ? null : _folderCache[id];

  int countIn(String folderId) => _active.where((n) => n.folderId == folderId).length;

  int get activeCount => _active.length;

  DateTime lastActivity(Folder f) {
    var t = f.createdAt;
    for (final n in _active) {
      if (n.folderId == f.id && n.updatedAt.isAfter(t)) t = n.updatedAt;
    }
    return t;
  }

  // ---------- note edits ----------

  Note createNote({String? folderId, String title = '', List<Block>? blocks}) {
    final n = Note(folderId: folderId, title: title, blocks: blocks);
    _noteCache[n.id] = n;
    _write(n);
    notifyListeners();
    return n;
  }

  /// Call after mutating a note in place.
  void touch(Note n, {bool notify = true}) {
    n.updatedAt = DateTime.now();
    _write(n);
    if (notify) notifyListeners();
  }

  void togglePin(Note n) {
    n.pinned = !n.pinned;
    touch(n);
  }

  void toggleLock(Note n) {
    n.locked = !n.locked;
    touch(n);
  }

  void moveToFolder(Note n, String? folderId) {
    n.folderId = folderId;
    touch(n);
  }

  void archive(Note n, bool value) {
    n.archived = value;
    if (value) n.pinned = false;
    touch(n);
  }

  void moveToTrash(Note n) {
    n.trashedAt = DateTime.now();
    n.pinned = false;
    _write(n);
    notifyListeners();
  }

  void restore(Note n) {
    n.trashedAt = null;
    n.archived = false;
    touch(n);
  }

  void deleteForever(Note n) {
    for (final b in n.blocks) {
      if (b.imageId != null) _images.delete(b.imageId);
    }
    _noteCache.remove(n.id);
    _notes.delete(n.id);
    notifyListeners();
  }

  void emptyTrash() {
    for (final n in trash) {
      deleteForever(n);
    }
  }

  /// Drops an empty, untouched note when the editor closes.
  void discardIfEmpty(Note n) {
    final empty = n.title.trim().isEmpty && n.blocks.every((b) => b.type.isText && b.text.trim().isEmpty);
    if (empty) {
      _noteCache.remove(n.id);
      _notes.delete(n.id);
      notifyListeners();
    }
  }

  void _write(Note n) => _notes.put(n.id, n.toMap());

  void _purgeOldTrash() {
    final cutoff = DateTime.now().subtract(const Duration(days: trashDays));
    for (final n in _noteCache.values.where((n) => n.inTrash && n.trashedAt!.isBefore(cutoff)).toList()) {
      _noteCache.remove(n.id);
      _notes.delete(n.id);
    }
  }

  // ---------- folders ----------

  Folder createFolder(String name, {String art = 'tide', String description = ''}) {
    final f = Folder(name: name.trim().isEmpty ? 'New folder' : name.trim(), art: art, description: description);
    _folderCache[f.id] = f;
    _folders.put(f.id, f.toMap());
    notifyListeners();
    return f;
  }

  void updateFolder(Folder f) {
    _folders.put(f.id, f.toMap());
    notifyListeners();
  }

  /// Deletes the folder; its notes stay and move to "No folder".
  void deleteFolder(Folder f) {
    for (final n in _noteCache.values.where((n) => n.folderId == f.id)) {
      n.folderId = null;
      _write(n);
    }
    _folderCache.remove(f.id);
    _folders.delete(f.id);
    notifyListeners();
  }

  // ---------- images ----------

  String saveImage(Uint8List bytes) {
    final id = newId();
    _images.put(id, bytes);
    return id;
  }

  Uint8List? image(String? id) {
    if (id == null) return null;
    final v = _images.get(id);
    if (v is Uint8List) return v;
    if (v is List) return Uint8List.fromList(v.cast<int>());
    return null;
  }

  // ---------- first run ----------

  void _seed() {
    final work = createFolder('Daily memo', art: 'ember', description: 'Notes and journaling');
    createFolder('Research', art: 'moss', description: 'Papers and surveys');
    final welcome = createNote(title: 'Welcome to Life OS', blocks: [
      Block(text: 'Everything here is a block. Type at the start of a line to change it:'),
      Block(type: BlockType.bullet, text: '# for a heading, ## and ### for smaller ones'),
      Block(type: BlockType.bullet, text: '- for a bulleted list, 1. for a numbered list'),
      Block(type: BlockType.bullet, text: '[] for a checklist, > for a quote, ``` for code, --- for a divider'),
      Block(type: BlockType.bullet, text: '/ on an empty line opens the block menu'),
      Block(type: BlockType.heading2, text: 'Try it'),
      Block(type: BlockType.checklist, text: 'Pin this note from the ··· menu', checked: false),
      Block(type: BlockType.checklist, text: 'Add an image with the photo button', checked: false),
      Block(type: BlockType.checklist, text: 'Move a note into a folder', checked: false),
      Block(type: BlockType.quote, text: 'Notes are stored on this device and work offline.'),
    ]);
    welcome.pinned = true;
    _write(welcome);
    createNote(folderId: work.id, title: 'Weekly review', blocks: [
      Block(text: 'What moved this week, what stalled, and the three things for next week.'),
      Block(type: BlockType.checklist, text: 'Look back at last week', checked: true),
      Block(type: BlockType.checklist, text: 'Pick three priorities'),
      Block(type: BlockType.checklist, text: 'Block focus time'),
    ]);
  }
}

/// Makes the store available below the app root and rebuilds dependants on change.
class StoreScope extends InheritedNotifier<NoteStore> {
  const StoreScope({super.key, required NoteStore store, required super.child}) : super(notifier: store);

  static NoteStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Reads the store without subscribing to changes.
  static NoteStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
