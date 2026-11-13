import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'share_inbox.dart' show firstUrl, hostOf;
import 'store.dart';

/// What a page says about itself (the same data apps use for link previews).
class LinkPreview {
  const LinkPreview({this.title = '', this.description = '', this.image = '', this.site = ''});
  final String title;
  final String description;
  final String image;
  final String site;

  bool get isEmpty => title.isEmpty && description.isEmpty;
}

const _browserUa =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Mobile Safari/537.36';

/// Facebook and Instagram give their public preview data to their own link crawler.
const _crawlerUa = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

bool _socialHost(String host) =>
    host.contains('facebook.com') || host.contains('fb.watch') || host.contains('fb.com') || host.contains('instagram.com') || host.contains('threads.net');

/// Titles that say nothing about the post itself.
bool isGenericTitle(String t) {
  final s = t.trim().toLowerCase();
  if (s.isEmpty) return true;
  const generic = {
    'facebook', 'instagram', 'log in or sign up to view', 'log into facebook', 'facebook - log in or sign up', 'log in', 'login',
    'sign up', 'error', 'page not found', 'youtube', 'threads', 'x', 'twitter', 'watch', 'video', 'just a moment...', 'access denied',
  };
  if (generic.contains(s)) return true;
  return s.startsWith('log in') || s.startsWith('sign in') || s.contains('log into facebook') || s == 'reels' || s.startsWith('facebook |');
}

/// Reads Open Graph and Twitter card tags (and <title>) from a page.
LinkPreview parsePreview(String html) {
  final head = html.length > 400000 ? html.substring(0, 400000) : html;
  String meta(List<String> keys) {
    for (final k in keys) {
      final esc = RegExp.escape(k);
      final a = RegExp('<meta[^>]+(?:property|name)\\s*=\\s*["\']$esc["\'][^>]*content\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(head) ??
          RegExp('<meta[^>]+(?:property|name)\\s*=\\s*["\']$esc["\'][^>]*content\\s*=\\s*\'([^\']*)\'', caseSensitive: false).firstMatch(head) ??
          RegExp('<meta[^>]+content\\s*=\\s*"([^"]*)"[^>]*(?:property|name)\\s*=\\s*["\']$esc["\']', caseSensitive: false).firstMatch(head);
      final v = a?.group(1)?.trim() ?? '';
      if (v.isNotEmpty) return unescapeHtml(v);
    }
    return '';
  }

  var title = meta(['og:title', 'twitter:title']);
  if (title.isEmpty) {
    final t = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(head)?.group(1) ?? '';
    title = unescapeHtml(t.replaceAll(RegExp(r'\s+'), ' ').trim());
  }
  return LinkPreview(
    title: title,
    description: meta(['og:description', 'twitter:description', 'description']),
    image: meta(['og:image', 'og:image:url', 'og:image:secure_url', 'twitter:image', 'twitter:image:src']),
    site: meta(['og:site_name']),
  );
}

String unescapeHtml(String s) {
  const named = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'ndash': '-', 'mdash': '-', 'hellip': '…', 'rsquo': '’', 'lsquo': '‘', 'ldquo': '“', 'rdquo': '”'};
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final g = m.group(1)!;
    try {
      if (g.startsWith('#x') || g.startsWith('#X')) return String.fromCharCode(int.parse(g.substring(2), radix: 16));
      if (g.startsWith('#')) return String.fromCharCode(int.parse(g.substring(1)));
    } catch (_) {
      return m.group(0)!;
    }
    return named[g.toLowerCase()] ?? m.group(0)!;
  });
}

/// A clean note title from a preview: drops "| Facebook" style endings and falls back to the
/// post text when the title is generic.
String? titleFrom(LinkPreview p, String url) {
  var t = p.title;
  for (final end in [' | Facebook', ' | Instagram', ' - YouTube', ' | LinkedIn', ' / X', ' on X', ' | TikTok', ' - Facebook', ' | Threads']) {
    if (t.endsWith(end)) t = t.substring(0, t.length - end.length).trim();
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Facebook often titles posts "123 reactions · 4 comments | Name". Use the post text instead.
  final countsOnly = RegExp(r'^[\d.,KkMm]+\s+(reactions?|views?|likes?|comments?)', caseSensitive: false).hasMatch(t);
  if (isGenericTitle(t) || countsOnly) {
    final d = p.description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (d.isEmpty || isGenericTitle(d)) return null;
    t = d;
  }
  if (t.length > 80) {
    final cut = t.substring(0, 80);
    final space = cut.lastIndexOf(' ');
    t = '${(space > 40 ? cut.substring(0, space) : cut).trim()}…';
  }
  return t.isEmpty ? null : t;
}

/// Downloads a page's preview. Null when it can't be reached or says nothing useful.
Future<LinkPreview?> fetchPreview(String url, {http.Client? client}) async {
  final c = client ?? http.Client();
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
  final social = _socialHost(uri.host);
  LinkPreview? best;
  for (final ua in social ? [_crawlerUa, _browserUa] : [_browserUa, _crawlerUa]) {
    try {
      final r = await c.get(uri, headers: {'User-Agent': ua, 'Accept': 'text/html,application/xhtml+xml', 'Accept-Language': 'en,bn;q=0.8'}).timeout(const Duration(seconds: 10));
      if (r.statusCode >= 400) continue;
      final type = r.headers['content-type'] ?? '';
      if (type.isNotEmpty && !type.contains('html')) continue;
      final bytes = r.bodyBytes.length > 600000 ? r.bodyBytes.sublist(0, 600000) : r.bodyBytes;
      final p = parsePreview(utf8.decode(bytes, allowMalformed: true));
      if (titleFrom(p, url) != null) return p;
      best ??= p.isEmpty ? null : p;
    } catch (_) {}
  }
  if (client == null) c.close();
  return best;
}

/// Set by main() on devices.
LinkEnricher? linkEnricher;

/// Fills in shared notes in the background: a real title, the description and a preview image.
/// Runs when the app starts and comes back to the front; retries later if there's no internet.
class LinkEnricher {
  LinkEnricher(this.store, {http.Client Function()? client}) : _client = client ?? http.Client.new;

  final NoteStore store;
  final http.Client Function() _client;
  bool _running = false;

  /// Queues a note made from a shared link. [autoTitle] is the placeholder title it got.
  static void enqueue(NoteStore store, String noteId, String url, String autoTitle) {
    store.pendingLinks = [
      ...store.pendingLinks.where((m) => m['noteId'] != noteId),
      {'noteId': noteId, 'url': url, 'autoTitle': autoTitle, 'tries': 0},
    ];
  }

  /// Notes saved before this feature existed still have "Link from …" titles. Queue them once.
  void backfill() {
    if (store.linksBackfilled) return;
    for (final n in store.notes()) {
      if (!n.title.startsWith('Link from ')) continue;
      final url = firstUrl(n.blocks.map((b) => b.text).join('\n'));
      if (url != null) enqueue(store, n.id, url, n.title);
    }
    store.linksBackfilled = true;
  }

  Future<int> run() async {
    if (_running || kIsWeb) return 0;
    _running = true;
    var done = 0;
    final client = _client();
    try {
      for (final job in store.pendingLinks) {
        final noteId = job['noteId'] as String;
        final url = job['url'] as String;
        final note = store.note(noteId);
        if (note == null || note.inTrash) {
          _drop(noteId);
          continue;
        }
        final p = await fetchPreview(url, client: client);
        if (p == null) {
          final tries = ((job['tries'] as num?)?.toInt() ?? 0) + 1;
          if (tries >= 5) {
            _drop(noteId);
          } else {
            store.pendingLinks = [for (final m in store.pendingLinks) m['noteId'] == noteId ? {...m, 'tries': tries} : m];
          }
          continue;
        }
        await _apply(note, p, url, job['autoTitle'] as String? ?? '', client);
        _drop(noteId);
        done++;
      }
    } finally {
      client.close();
      _running = false;
    }
    return done;
  }

  void _drop(String noteId) => store.pendingLinks = [for (final m in store.pendingLinks) if (m['noteId'] != noteId) m];

  Future<void> _apply(Note note, LinkPreview p, String url, String autoTitle, http.Client client) async {
    var changed = false;
    // Only replace the title if you haven't renamed the note yourself.
    final title = titleFrom(p, url);
    if (title != null && (note.title == autoTitle || note.title.trim().isEmpty)) {
      note.title = title;
      changed = true;
    }
    final desc = p.description.replaceAll(RegExp(r'\s+'), ' ').trim();
    final text = note.searchText;
    if (desc.isNotEmpty && !isGenericTitle(desc) && desc.toLowerCase() != (title ?? '').toLowerCase().replaceAll('…', '') && !text.contains(desc.toLowerCase())) {
      final at = note.blocks.indexWhere((b) => b.text.contains(url));
      note.blocks.insert(at < 0 ? note.blocks.length : at, Block(type: BlockType.quote, text: desc.length > 400 ? '${desc.substring(0, 400)}…' : desc));
      changed = true;
    }
    if (p.image.isNotEmpty && !note.blocks.any((b) => b.type == BlockType.image)) {
      final bytes = await _image(p.image, url, client);
      if (bytes != null) {
        final id = store.saveImage(bytes);
        note.blocks.insert(0, Block(type: BlockType.image, imageId: id, text: p.site.isNotEmpty ? p.site : hostOf(url)));
        changed = true;
      }
    }
    if (changed) store.touch(note);
  }

  Future<Uint8List?> _image(String src, String page, http.Client client) async {
    try {
      final uri = Uri.parse(page).resolve(unescapeHtml(src));
      final r = await client.get(uri, headers: {'User-Agent': _browserUa}).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      if (!(r.headers['content-type'] ?? 'image/').startsWith('image/')) return null;
      if (r.bodyBytes.length < 2000 || r.bodyBytes.length > 3 * 1024 * 1024) return null;
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
