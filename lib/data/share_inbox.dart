import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'link_preview.dart';
import 'models.dart';
import 'store.dart';

/// Set by main() on devices. Null on the web and in tests.
ShareInbox? shareInbox;

/// Hand-off between the share popup and the app.
///
/// The popup runs in its own Flutter engine (see ShareActivity), so it never opens the Hive
/// boxes the app is using. It reads a small folder list the app keeps up to date, and drops
/// each saved share as a JSON file. The app turns those files into notes when it starts or
/// comes back to the front.
class ShareInbox {
  ShareInbox._(this.dir);

  final Directory dir;

  static Future<ShareInbox?> open() async {
    if (kIsWeb) return null;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/share_inbox');
      if (!d.existsSync()) d.createSync(recursive: true);
      return ShareInbox._(d);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static ShareInbox at(Directory d) {
    if (!d.existsSync()) d.createSync(recursive: true);
    return ShareInbox._(d);
  }

  File get _folders => File('${dir.path}/folders.json');

  String _lastFolders = '';

  /// Called by the app whenever folders change.
  void writeFolders(List<Folder> folders) {
    final json = jsonEncode([for (final f in folders) {'id': f.id, 'name': f.name, 'art': f.art}]);
    if (json == _lastFolders) return;
    _lastFolders = json;
    try {
      final tmp = File('${_folders.path}.tmp')..writeAsStringSync(json, flush: true);
      tmp.renameSync(_folders.path);
    } catch (_) {}
  }

  File get _notes => File('${dir.path}/notes.json');
  File get _last => File('${dir.path}/last.json');
  String _lastNotes = '';

  /// Called by the app whenever notes or folders change: what the popup can file into.
  void writeSnapshot(NoteStore store) {
    writeFolders(store.folders);
    final list = store.notes().where((n) => !n.locked).take(400).toList();
    final json = jsonEncode([
      for (final n in list) {'id': n.id, 'title': n.displayTitle, 'folderId': n.folderId, 'updated': n.updatedAt.millisecondsSinceEpoch},
    ]);
    if (json == _lastNotes) return;
    _lastNotes = json;
    try {
      final tmp = File('${_notes.path}.tmp')..writeAsStringSync(json, flush: true);
      tmp.renameSync(_notes.path);
    } catch (_) {}
  }

  /// Notes the popup can add to, newest first.
  List<({String id, String title, String? folderId})> readNotes() {
    try {
      final list = (jsonDecode(_notes.readAsStringSync()) as List).whereType<Map>().toList()
        ..sort((a, b) => ((b['updated'] as num?) ?? 0).compareTo((a['updated'] as num?) ?? 0));
      return [for (final m in list) (id: m['id'] as String, title: (m['title'] as String?) ?? 'Untitled', folderId: m['folderId'] as String?)];
    } catch (_) {
      return const [];
    }
  }

  /// Where you filed the last share, so the popup can start there.
  ({String? folderId, String? noteId}) readLast() {
    try {
      final m = jsonDecode(_last.readAsStringSync()) as Map;
      return (folderId: m['folderId'] as String?, noteId: m['noteId'] as String?);
    } catch (_) {
      return (folderId: null, noteId: null);
    }
  }

  void writeLast({String? folderId, String? noteId}) {
    try {
      _last.writeAsStringSync(jsonEncode({'folderId': folderId, 'noteId': noteId}));
    } catch (_) {}
  }

  /// Folders as the popup sees them.
  List<({String id, String name, String art})> readFolders() {
    try {
      final list = jsonDecode(_folders.readAsStringSync()) as List;
      return [
        for (final m in list.whereType<Map>()) (id: m['id'] as String, name: (m['name'] as String?) ?? 'Folder', art: (m['art'] as String?) ?? 'tide'),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Saved by the popup. [newFolder] creates a folder with that name when imported.
  /// [noteId] adds the share to the end of that note instead of making a new one;
  /// [newNoteTitle] names the new note.
  void add({
    required String text,
    String subject = '',
    String note = '',
    String? folderId,
    String? newFolder,
    String? noteId,
    String? newNoteTitle,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final data = jsonEncode({
      'text': text,
      'subject': subject,
      'note': note,
      'folderId': folderId,
      'newFolder': newFolder,
      'noteId': noteId,
      'newNoteTitle': newNoteTitle,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    final tmp = File('${dir.path}/$stamp.part')..writeAsStringSync(data, flush: true);
    tmp.renameSync('${dir.path}/$stamp.share');
  }

  /// Turns waiting shares into notes. Returns how many were added.
  int importInto(NoteStore store) {
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.share')).toList()..sort((a, b) => a.path.compareTo(b.path));
    var n = 0;
    for (final f in files) {
      try {
        final m = jsonDecode(f.readAsStringSync()) as Map;
        String? folderId = m['folderId'] as String?;
        final newFolder = (m['newFolder'] as String?)?.trim() ?? '';
        if (newFolder.isNotEmpty) {
          final existing = store.folders.where((x) => x.name.toLowerCase() == newFolder.toLowerCase());
          folderId = existing.isNotEmpty ? existing.first.id : store.createFolder(newFolder).id;
        }
        if (folderId != null && store.folder(folderId) == null) folderId = null;
        final text = (m['text'] as String?) ?? '';
        final yours = ((m['note'] as String?) ?? '').trim();
        final url = firstUrl(text);

        // Add to an existing note: your note on one line, the link on the next.
        final target = store.note((m['noteId'] as String?) ?? '');
        if (target != null && !target.inTrash) {
          final linkBlock = Block(text: text.trim());
          appendShare(store, target, yours: yours, shared: linkBlock);
          if (url != null && yours.isEmpty) LinkEnricher.enqueueLine(store, target.id, url, linkBlock.id);
          n++;
          continue;
        }

        final named = ((m['newNoteTitle'] as String?) ?? '').trim();
        final shared = sharedNote(
          text: (m['text'] as String?) ?? '',
          subject: (m['subject'] as String?) ?? '',
          note: (m['note'] as String?) ?? '',
        );
        if (named.isNotEmpty) {
          // A named collection note ("Baby videos"): same layout as adding to one later.
          final note = store.createNote(folderId: folderId, title: named, blocks: []);
          final linkBlock = Block(text: text.trim());
          appendShare(store, note, yours: yours, shared: linkBlock);
          if (url != null && yours.isEmpty) LinkEnricher.enqueueLine(store, note.id, url, linkBlock.id);
          n++;
          continue;
        }
        final note = store.createNote(folderId: folderId, title: shared.title, blocks: shared.blocks);
        if (url != null) {
          // Fetch the page's own title, description and image in the background.
          LinkEnricher.enqueue(store, note.id, url, shared.title.startsWith('Link from ') ? shared.title : '\u0000');
        }
        n++;
      } catch (_) {
        // A broken file is skipped and removed so it doesn't block the rest.
      } finally {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    return n;
  }
}

/// Adds a share to the end of [note]: your note (if any) on one line, the link on the next.
void appendShare(NoteStore store, Note note, {required String yours, required Block shared}) {
  final blocks = note.blocks;
  while (blocks.isNotEmpty && blocks.last.type.isText && blocks.last.text.trim().isEmpty) {
    blocks.removeLast();
  }
  if (yours.isNotEmpty) blocks.add(Block(text: yours));
  blocks.add(shared);
  store.touch(note);
}

final _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// First link in shared text, if any.
String? firstUrl(String text) => _url.firstMatch(text)?.group(0);

/// "facebook.com" from a link.
String hostOf(String url) {
  final h = Uri.tryParse(url)?.host ?? '';
  return h.startsWith('www.') ? h.substring(4) : (h.startsWith('m.') ? h.substring(2) : h);
}

/// Builds the note for a share: your note first, then what was shared.
({String title, List<Block> blocks}) sharedNote({required String text, String subject = '', String note = ''}) {
  final url = firstUrl(text);
  final yours = note.trim();
  final shared = text.trim();
  final firstLine = yours.split('\n').first.trim();
  String title;
  if (subject.trim().isNotEmpty) {
    title = subject.trim();
  } else if (firstLine.isNotEmpty && firstLine.length <= 60) {
    title = firstLine;
  } else if (url != null) {
    title = 'Link from ${hostOf(url)}';
  } else {
    final t = shared.split('\n').first;
    title = t.length > 60 ? '${t.substring(0, 57)}…' : t;
  }
  final blocks = <Block>[
    if (yours.isNotEmpty && yours != title) Block(text: yours),
    if (shared.isNotEmpty) Block(type: url != null && shared == url ? BlockType.paragraph : BlockType.quote, text: shared),
  ];
  if (blocks.isEmpty) blocks.add(Block(text: ''));
  return (title: title, blocks: blocks);
}
