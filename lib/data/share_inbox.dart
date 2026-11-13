import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
  void add({required String text, String subject = '', String note = '', String? folderId, String? newFolder}) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final data = jsonEncode({
      'text': text,
      'subject': subject,
      'note': note,
      'folderId': folderId,
      'newFolder': newFolder,
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
        final shared = sharedNote(
          text: (m['text'] as String?) ?? '',
          subject: (m['subject'] as String?) ?? '',
          note: (m['note'] as String?) ?? '',
        );
        store.createNote(folderId: folderId, title: shared.title, blocks: shared.blocks);
        n++;
      } catch (_) {
        // A broken file is skipped and removed so it doesn't block the rest.
      }
      try {
        f.deleteSync();
      } catch (_) {}
    }
    return n;
  }
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
