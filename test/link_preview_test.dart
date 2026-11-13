import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/data/link_preview.dart';
import 'package:life_os/data/models.dart';
import 'package:life_os/data/share_inbox.dart';
import 'package:life_os/data/store.dart';

const _fbHtml = '''<html><head>
<meta property="og:title" content="1.2K reactions · 87 comments | Dhaka Food Lovers" />
<meta property="og:description" content="Best kacchi in Old Dhaka? We tried 7 places so you don&#039;t have to." />
<meta property="og:image" content="https://scontent.example/cover.jpg" />
<meta property="og:site_name" content="Facebook" />
<title>Facebook</title></head><body></body></html>''';

const _articleHtml = '''<html><head><title>Ignored</title>
<meta content="How to Build a Second Brain &amp; Actually Use It" property="og:title">
<meta name="description" content="A practical guide.">
</head></html>''';

void main() {
  test('parses Open Graph tags in either attribute order and unescapes them', () {
    final a = parsePreview(_articleHtml);
    expect(a.title, 'How to Build a Second Brain & Actually Use It');
    expect(a.description, 'A practical guide.');
    final f = parsePreview(_fbHtml);
    expect(f.description, contains("don't"));
    expect(f.image, 'https://scontent.example/cover.jpg');
  });

  test('Facebook count-only titles fall back to the post text', () {
    final t = titleFrom(parsePreview(_fbHtml), 'https://www.facebook.com/share/p/x');
    expect(t, startsWith('Best kacchi in Old Dhaka?'));
    expect(titleFrom(const LinkPreview(title: 'Log in or sign up to view'), 'u'), isNull);
    expect(titleFrom(const LinkPreview(title: 'Lofi Girl - YouTube'), 'u'), 'Lofi Girl');
  });

  test('shared notes get the real title, description and image in the background', () async {
    final dir = await Directory.systemTemp.createTemp('life_os_links');
    final store = await NoteStore.openForTest(dir.path);
    final inbox = ShareInbox.at(Directory('${dir.path}/inbox'));
    inbox.add(text: 'https://www.facebook.com/share/p/abc/');
    inbox.add(text: 'https://example.com/post', note: 'My own title');
    expect(inbox.importInto(store), 2);
    expect(store.pendingLinks.length, 2);

    final png = Uint8List.fromList(List.filled(5000, 7));
    final client = MockClient((req) async {
      if (req.url.host == 'scontent.example') return http.Response.bytes(png, 200, headers: {'content-type': 'image/jpeg'});
      if (req.url.host.contains('facebook')) {
        expect(req.headers['User-Agent'], contains('facebookexternalhit'));
        return http.Response(_fbHtml, 200, headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return http.Response(_articleHtml, 200, headers: {'content-type': 'text/html'});
    });
    final enricher = LinkEnricher(store, client: () => client);
    expect(await enricher.run(), 2);
    expect(store.pendingLinks, isEmpty);

    final fb = store.notes().firstWhere((n) => n.blocks.any((b) => b.text.contains('facebook.com/share')));
    expect(fb.title, startsWith('Best kacchi'));
    expect(fb.blocks.first.type, BlockType.image);
    // You named this one yourself, so the title stays; the description is still added.
    final own = store.notes().firstWhere((n) => n.title == 'My own title');
    expect(own.blocks.any((b) => b.text == 'A practical guide.'), isTrue);
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('no internet: the link stays queued for later', () async {
    final dir = await Directory.systemTemp.createTemp('life_os_links2');
    final store = await NoteStore.openForTest(dir.path);
    final n = store.createNote(title: 'Link from example.com', blocks: [Block(text: 'https://example.com/a')]);
    LinkEnricher.enqueue(store, n.id, 'https://example.com/a', n.title);
    final client = MockClient((req) async => throw const SocketException('offline'));
    expect(await LinkEnricher(store, client: () => client).run(), 0);
    expect(store.pendingLinks.single['tries'], 1);
    expect(store.note(n.id)!.title, 'Link from example.com');
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
}
