import 'models.dart';

/// Converts a note to portable Markdown. Images become references by id.
String noteToMarkdown(Note note) {
  final out = StringBuffer();
  if (note.title.trim().isNotEmpty) out.writeln('# ${note.title.trim()}\n');
  var number = 0;
  for (final b in note.blocks) {
    if (b.type != BlockType.numbered) number = 0;
    final t = b.text;
    switch (b.type) {
      case BlockType.paragraph:
        out.writeln(t);
        out.writeln();
      case BlockType.heading1:
        out.writeln('## $t\n');
      case BlockType.heading2:
        out.writeln('### $t\n');
      case BlockType.heading3:
        out.writeln('#### $t\n');
      case BlockType.bullet:
        out.writeln('- $t');
      case BlockType.numbered:
        number++;
        out.writeln('$number. $t');
      case BlockType.checklist:
        out.writeln('- [${b.checked ? 'x' : ' '}] $t');
      case BlockType.quote:
        out.writeln('> ${t.replaceAll('\n', '\n> ')}\n');
      case BlockType.code:
        out.writeln('```\n$t\n```\n');
      case BlockType.divider:
        out.writeln('---\n');
      case BlockType.image:
        out.writeln('![${t.isEmpty ? 'image' : t}](images/${b.imageId}.png)\n');
    }
  }
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// The result of typing a Markdown shortcut at the start of a text block.
class Shortcut {
  const Shortcut(this.type, this.rest, {this.checked = false});
  final BlockType type;
  final String rest;
  final bool checked;
}

/// Turns "# ", "- ", "[] ", "> ", "```" and "---" typed at the start of a
/// paragraph into the matching block, the way Notion and Typora do.
Shortcut? detectShortcut(String text) {
  const rules = <String, BlockType>{
    '### ': BlockType.heading3,
    '## ': BlockType.heading2,
    '# ': BlockType.heading1,
    '- [ ] ': BlockType.checklist,
    '[ ] ': BlockType.checklist,
    '[] ': BlockType.checklist,
    '- ': BlockType.bullet,
    '* ': BlockType.bullet,
    '1. ': BlockType.numbered,
    '> ': BlockType.quote,
  };
  if (text.startsWith('- [x] ') || text.startsWith('[x] ')) {
    return Shortcut(BlockType.checklist, text.substring(text.indexOf(']') + 2), checked: true);
  }
  for (final e in rules.entries) {
    if (text.startsWith(e.key)) return Shortcut(e.value, text.substring(e.key.length));
  }
  if (text == '```') return const Shortcut(BlockType.code, '');
  if (text == '---') return const Shortcut(BlockType.divider, '');
  return null;
}

/// Inline Markdown is kept as typed; this strips the markers for previews.
String plainPreview(String text) => text.replaceAll(RegExp(r'[*_`~]'), '');
