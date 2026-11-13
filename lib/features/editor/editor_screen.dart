import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../data/markdown.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../../shell/root_shell.dart';
import '../notes/note_widgets.dart';
import 'glass_menu.dart';

/// Every text block's controller starts with this invisible sentinel, so a
/// backspace at the very start of a block can be detected on every platform
/// (soft keyboards send no key event for it).
const zw = '​';

class _BlockCtl {
  _BlockCtl(this.block)
      : text = TextEditingController(text: zw + block.text),
        node = FocusNode();

  final Block block;
  final TextEditingController text;
  final FocusNode node;

  void dispose() {
    text.dispose();
    node.dispose();
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.noteId, this.isNew = false});

  final String noteId;
  final bool isNew;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final NoteStore _store;
  late final Note _note;
  late final TextEditingController _title;
  final _titleNode = FocusNode();
  final List<_BlockCtl> _ctls = [];
  Timer? _saveTimer;
  bool _dirty = false;
  bool _finding = false;
  final _find = TextEditingController();
  _BlockCtl? _focused;

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    _note = _store.note(widget.noteId) ?? _store.createNote();
    _title = TextEditingController(text: _note.title);
    for (final b in _note.blocks) {
      _ctls.add(_makeCtl(b));
    }
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _titleNode.requestFocus());
    }
  }

  _BlockCtl _makeCtl(Block b) {
    final c = _BlockCtl(b);
    c.text.addListener(() => _guardSentinel(c));
    c.node.addListener(() {
      if (c.node.hasFocus) {
        _focused = c;
        if (mounted) setState(() {});
      } else if (_focused == c) {
        // Keep the reference so toolbar actions still know where to act.
        if (mounted) setState(() {});
      }
    });
    return c;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final store = _store;
    final note = _note;
    final dirty = _dirty;
    final isNew = widget.isNew;
    scheduleMicrotask(() {
      if (dirty) {
        store.touch(note);
      } else {
        store.touch(note, notify: false);
      }
      if (isNew) store.discardIfEmpty(note);
    });
    for (final c in _ctls) {
      c.dispose();
    }
    _title.dispose();
    _titleNode.dispose();
    _find.dispose();
    super.dispose();
  }

  // ---------- saving ----------

  void _changed({bool rebuild = false}) {
    _dirty = true;
    _note.blocks = _ctls.map((c) => c.block).toList();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => _store.touch(_note, notify: false));
    if (rebuild && mounted) setState(() {});
  }

  // ---------- text editing ----------

  void _guardSentinel(_BlockCtl c) {
    final v = c.text.value;
    if (v.text.startsWith(zw) && v.selection.isValid && v.selection.isCollapsed && v.selection.baseOffset == 0) {
      c.text.selection = const TextSelection.collapsed(offset: 1);
    }
  }

  void _setText(_BlockCtl c, String content, {int? cursor}) {
    c.block.text = content;
    final offset = (cursor ?? content.length) + 1;
    c.text.value = TextEditingValue(text: zw + content, selection: TextSelection.collapsed(offset: offset.clamp(1, content.length + 1)));
  }

  void _focus(_BlockCtl c, {int? at}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.node.requestFocus();
      final len = c.text.text.length;
      c.text.selection = TextSelection.collapsed(offset: ((at ?? (len - 1)) + 1).clamp(1, len));
    });
  }

  void _onBlockChanged(_BlockCtl c, String value) {
    final i = _ctls.indexOf(c);
    if (i < 0) return;

    // Backspace at the very start of the block.
    if (!value.startsWith(zw)) {
      _backspaceAtStart(c, i, value);
      return;
    }
    var content = value.substring(1).replaceAll(zw, '');
    final b = c.block;

    // Enter splits the block, except inside code where new lines belong.
    if (content.contains('\n') && b.type != BlockType.code) {
      final cut = content.indexOf('\n');
      final before = content.substring(0, cut);
      final after = content.substring(cut + 1);
      if (b.type.isList && before.isEmpty && after.isEmpty) {
        b.type = BlockType.paragraph;
        _setText(c, '');
        _changed(rebuild: true);
        return;
      }
      _setText(c, before);
      final nextType = b.type.isList ? b.type : BlockType.paragraph;
      final next = _makeCtl(Block(type: nextType, text: after));
      _ctls.insert(i + 1, next);
      _changed(rebuild: true);
      _focus(next, at: 0);
      return;
    }

    if (b.type == BlockType.paragraph) {
      if (content == '/') {
        _setText(c, '');
        _changed();
        _showBlockMenu(c, replace: true);
        return;
      }
      final s = detectShortcut(content);
      if (s != null) {
        b.type = s.type;
        b.checked = s.checked;
        if (s.type == BlockType.divider) {
          _setText(c, '');
          final next = _makeCtl(Block());
          _ctls.insert(i + 1, next);
          _changed(rebuild: true);
          _focus(next, at: 0);
          return;
        }
        _setText(c, s.rest);
        _changed(rebuild: true);
        return;
      }
    }

    b.text = content;
    _changed(rebuild: _finding);
  }

  void _backspaceAtStart(_BlockCtl c, int i, String value) {
    final content = value.replaceAll(zw, '');
    final b = c.block;
    if (b.type != BlockType.paragraph) {
      // First backspace turns a list item, heading or quote back into text.
      b.type = BlockType.paragraph;
      _setText(c, content, cursor: 0);
      _changed(rebuild: true);
      return;
    }
    if (i == 0) {
      _setText(c, content, cursor: 0);
      return;
    }
    final prev = _ctls[i - 1];
    if (!prev.block.type.isText) {
      // Remove the divider or image above instead of merging into it.
      _ctls.removeAt(i - 1);
      prev.dispose();
      _setText(c, content, cursor: 0);
      _changed(rebuild: true);
      return;
    }
    final join = prev.block.text.length;
    _ctls.removeAt(i);
    _setText(prev, prev.block.text + content, cursor: join);
    _changed(rebuild: true);
    _focus(prev, at: join);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  // ---------- block operations ----------

  _BlockCtl get _target => _focused != null && _ctls.contains(_focused) ? _focused! : _ctls.last;

  void _turnInto(_BlockCtl c, BlockType type) {
    if (type == BlockType.image) {
      _insertImage(after: c);
      return;
    }
    final i = _ctls.indexOf(c);
    if (type == BlockType.divider) {
      final d = _makeCtl(Block(type: BlockType.divider));
      _ctls.insert(i + 1, d);
      final next = _makeCtl(Block());
      _ctls.insert(i + 2, next);
      _changed(rebuild: true);
      _focus(next, at: 0);
      return;
    }
    c.block.type = c.block.type == type && type != BlockType.paragraph ? BlockType.paragraph : type;
    _changed(rebuild: true);
    _focus(c);
  }

  void _toggleChecked(_BlockCtl c) {
    c.block.checked = !c.block.checked;
    _changed(rebuild: true);
  }

  void _removeBlock(_BlockCtl c) {
    final i = _ctls.indexOf(c);
    if (i < 0) return;
    _ctls.removeAt(i);
    if (_ctls.isEmpty) _ctls.add(_makeCtl(Block()));
    if (_focused == c) _focused = null;
    _changed(rebuild: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  Future<void> _insertImage({_BlockCtl? after}) async {
    final anchor = after ?? _target;
    Uint8List? bytes;
    try {
      // Large photos are scaled down on the device before they are stored.
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
      bytes = await picked?.readAsBytes();
    } catch (_) {
      if (mounted) showToast(context, "Couldn't open your photos. Check the app's permission and try again.");
      return;
    }
    if (bytes == null || !mounted) return;
    final id = _store.saveImage(bytes);
    var i = _ctls.indexOf(anchor);
    if (i < 0) i = _ctls.length - 1;
    // An empty text block is replaced by the image instead of left behind.
    final replace = anchor.block.type == BlockType.paragraph && anchor.block.text.isEmpty;
    final img = _makeCtl(Block(type: BlockType.image, imageId: id));
    if (replace) {
      _ctls[i] = img;
      WidgetsBinding.instance.addPostFrameCallback((_) => anchor.dispose());
    } else {
      _ctls.insert(++i, img);
    }
    final next = _makeCtl(Block());
    _ctls.insert(_ctls.indexOf(img) + 1, next);
    _changed(rebuild: true);
    _focus(next, at: 0);
  }

  Future<void> _showBlockMenu(_BlockCtl c, {bool replace = false}) async {
    final type = await showAppSheet<BlockType>(context, builder: (ctx) {
      final cc = ctx.colors;
      const items = [
        (BlockType.paragraph, AppIcons.text, 'Plain text'),
        (BlockType.heading1, AppIcons.text, 'Large heading'),
        (BlockType.heading2, AppIcons.text, 'Medium heading'),
        (BlockType.heading3, AppIcons.text, 'Small heading'),
        (BlockType.checklist, AppIcons.checklist, 'Track tasks'),
        (BlockType.bullet, AppIcons.bullet, 'Simple list'),
        (BlockType.numbered, AppIcons.numbered, 'Ordered list'),
        (BlockType.quote, AppIcons.quote, 'Highlight a line'),
        (BlockType.code, AppIcons.code, 'Monospace block'),
        (BlockType.image, AppIcons.image, 'From your photos'),
        (BlockType.divider, AppIcons.divider, 'Separate sections'),
      ];
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(replace ? 'Turn into' : 'Change block', style: AppText.sans(17, weight: FontWeight.w700, color: cc.ink)),
          ),
          for (final it in items)
            Pressable(
              scale: 0.98,
              label: it.$1.label,
              onTap: () => Navigator.pop(ctx, it.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.block.type == it.$1 ? cc.ink.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: cc.ground, borderRadius: BorderRadius.circular(10)),
                    child: Icon(it.$2, size: 18, color: cc.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.$1.label, style: AppText.sans(15, weight: FontWeight.w600, color: cc.ink)),
                      Text(it.$3, style: AppText.sans(12, color: cc.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      );
    });
    if (type == null || !mounted) {
      _focus(c);
      return;
    }
    _turnInto(c, type);
  }

  // ---------- menu actions ----------

  Future<void> _openMenu() async {
    FocusScope.of(context).unfocus();
    final focused = FocusEngineScope.read(context).store.secondsOnNote(_note.id);
    final action = await showGlassMenu(context, note: _note, focusLabel: focused >= 60 ? 'Focus on this · ${focusDuration(focused)}' : 'Focus on this');
    if (action == null || !mounted) return;
    switch (action) {
      case GlassAction.pin:
        _store.togglePin(_note);
        showToast(context, _note.pinned ? 'Pinned' : 'Unpinned');
      case GlassAction.lock:
        _store.toggleLock(_note);
        setState(() {});
        showToast(context, _note.locked ? 'Locked. Unlock from ··· to edit.' : 'Unlocked');
      case GlassAction.copy:
        await Clipboard.setData(ClipboardData(text: noteToMarkdown(_note)));
        if (mounted) showToast(context, 'Copied as Markdown');
      case GlassAction.find:
        setState(() => _finding = true);
      case GlassAction.focus:
        FocusEngineScope.read(context).link(noteId: _note.id);
        Navigator.pop(context);
        shellTab.value = 2;
      case GlassAction.move:
        await showMoveSheet(context, _note);
        if (mounted) setState(() {});
      case GlassAction.image:
        await _insertImage();
      case GlassAction.archive:
        _store.archive(_note, !_note.archived);
        if (mounted) Navigator.pop(context);
      case GlassAction.delete:
        _store.moveToTrash(_note);
        if (mounted) Navigator.pop(context);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locked = _note.locked;
    final query = _finding ? _find.text.trim().toLowerCase() : '';
    final matches = query.isEmpty ? 0 : _ctls.where((b) => b.block.text.toLowerCase().contains(query)).length;
    final editing = !locked && (_focused?.node.hasFocus ?? false);
    final folder = _store.folder(_note.folderId);

    var number = 0;
    final rows = <Widget>[];
    for (final ctl in _ctls) {
      number = ctl.block.type == BlockType.numbered ? number + 1 : 0;
      final hit = query.isNotEmpty && ctl.block.text.toLowerCase().contains(query);
      rows.add(Padding(
        key: ValueKey(ctl.block.id),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: _BlockView(
          ctl: ctl,
          number: number,
          locked: locked,
          highlight: hit,
          store: _store,
          onChanged: (v) => _onBlockChanged(ctl, v),
          onToggle: () => _toggleChecked(ctl),
          onRemove: () => _removeBlock(ctl),
          onImageWidth: (w) {
            ctl.block.width = w;
            _changed(rebuild: true);
          },
          onCaption: (v) {
            ctl.block.text = v;
            _changed();
          },
        ),
      ));
    }

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _finding
                ? _FindBar(
                    controller: _find,
                    matches: matches,
                    onChanged: () => setState(() {}),
                    onClose: () => setState(() {
                      _finding = false;
                      _find.clear();
                    }),
                  )
                : Row(children: [
                    RoundIconButton(icon: AppIcons.back, label: 'Back', background: c.ground, onTap: () => Navigator.maybePop(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(folder?.name ?? 'Notes', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w500, color: c.muted)),
                    ),
                    if (_note.pinned) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(AppIcons.pinFill, size: 16, color: c.muted)),
                    if (locked) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(AppIcons.lock, size: 16, color: c.muted)),
                    RoundIconButton(icon: AppIcons.more, label: 'Note actions', background: c.ground, onTap: _openMenu),
                  ]),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!locked && _ctls.isNotEmpty && !(_focused?.node.hasFocus ?? false)) _focus(_ctls.last);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 160),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _title,
                          focusNode: _titleNode,
                          readOnly: locked,
                          style: AppText.display(36, color: c.ink, height: 1.1),
                          decoration: InputDecoration.collapsed(hintText: 'Title', hintStyle: AppText.display(36, color: c.muted.withValues(alpha: 0.5), height: 1.1)),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          onChanged: (v) {
                            _note.title = v.replaceAll('\n', ' ');
                            _changed();
                          },
                          onSubmitted: (_) => _focus(_ctls.first, at: 0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Edited ${relativeDay(_note.updatedAt)}${_note.hasChecklist ? ' · ${_note.doneTasks}/${_note.doneTasks + _note.openTasks} done' : ''}',
                          style: AppText.label(10.5, color: c.muted),
                        ),
                        if (locked) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: c.ground, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Icon(AppIcons.lock, size: 16, color: c.muted),
                              const SizedBox(width: 8),
                              Expanded(child: Text('This note is locked. Unlock it from the ··· menu to edit.', style: AppText.sans(13, color: c.muted))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ...rows,
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (editing)
            _Toolbar(
              onTurnInto: () => _showBlockMenu(_target),
              onChecklist: () => _turnInto(_target, BlockType.checklist),
              onBullet: () => _turnInto(_target, BlockType.bullet),
              onImage: () => _insertImage(),
              onDone: () => FocusScope.of(context).unfocus(),
            ),
        ]),
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.ctl,
    required this.number,
    required this.locked,
    required this.highlight,
    required this.store,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onImageWidth,
    required this.onCaption,
  });

  final _BlockCtl ctl;
  final int number;
  final bool locked;
  final bool highlight;
  final NoteStore store;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<double> onImageWidth;
  final ValueChanged<String> onCaption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = ctl.block;
    if (b.type == BlockType.divider) {
      return Pressable(
        label: 'Divider. Long press to remove.',
        onLongPress: locked ? null : onRemove,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 1, color: c.line)),
      );
    }
    if (b.type == BlockType.image) {
      return _ImageBlock(block: b, store: store, locked: locked, onRemove: onRemove, onWidth: onImageWidth, onCaption: onCaption);
    }

    final style = switch (b.type) {
      BlockType.heading1 => AppText.display(30, color: c.ink, height: 1.25),
      BlockType.heading2 => AppText.sans(20, weight: FontWeight.w700, color: c.ink, height: 1.3),
      BlockType.heading3 => AppText.sans(17, weight: FontWeight.w600, color: c.ink, height: 1.35),
      BlockType.code => AppText.label(13.5, color: c.ink, tracking: 0).copyWith(height: 1.5),
      BlockType.checklist when b.checked =>
        AppText.sans(16, color: c.muted, height: 1.5).copyWith(decoration: TextDecoration.lineThrough, decorationColor: c.muted),
      BlockType.quote => AppText.sans(16, color: c.ink, height: 1.5, weight: FontWeight.w500),
      _ => AppText.sans(16, color: c.ink, height: 1.5),
    };
    final hint = switch (b.type) {
      BlockType.heading1 || BlockType.heading2 || BlockType.heading3 => 'Heading',
      BlockType.bullet || BlockType.numbered => 'List item',
      BlockType.checklist => 'To do',
      BlockType.quote => 'Quote',
      BlockType.code => 'Code',
      _ => ctl.node.hasFocus ? 'Type / for blocks' : '',
    };

    final field = TextField(
      controller: ctl.text,
      focusNode: ctl.node,
      readOnly: locked,
      onChanged: onChanged,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: style,
      cursorColor: c.ink,
      decoration: InputDecoration.collapsed(hintText: hint, hintStyle: style.copyWith(color: c.muted.withValues(alpha: 0.55), decoration: TextDecoration.none)),
    );

    Widget? lead;
    switch (b.type) {
      case BlockType.bullet:
        lead = Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle)),
        );
      case BlockType.numbered:
        lead = Text('$number.', style: AppText.sans(16, color: c.muted, height: 1.5));
      case BlockType.checklist:
        lead = Pressable(
          label: b.checked ? 'Mark not done' : 'Mark done',
          onTap: locked ? null : onToggle,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: b.checked ? c.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: b.checked ? c.ink : c.muted, width: 1.6),
              ),
              child: b.checked ? Icon(AppIcons.check, size: 13, color: c.inverseInk) : null,
            ),
          ),
        );
      default:
        lead = null;
    }

    Widget body = lead == null
        ? field
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 26, child: Align(alignment: Alignment.topLeft, child: lead)),
            Expanded(child: field),
          ]);

    if (b.type == BlockType.quote) {
      body = Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.sage, width: 3))),
        child: body,
      );
    } else if (b.type == BlockType.code) {
      body = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.ground, borderRadius: BorderRadius.circular(12)),
        child: body,
      );
    }
    if (b.type == BlockType.heading1 || b.type == BlockType.heading2) {
      body = Padding(padding: const EdgeInsets.only(top: 10), child: body);
    }
    if (highlight) {
      body = Container(
        decoration: BoxDecoration(color: c.sage.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: body,
      );
    }
    return body;
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.block, required this.store, required this.locked, required this.onRemove, required this.onWidth, required this.onCaption});

  final Block block;
  final NoteStore store;
  final bool locked;
  final VoidCallback onRemove;
  final ValueChanged<double> onWidth;
  final ValueChanged<String> onCaption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bytes = store.image(block.imageId);
    return LayoutBuilder(builder: (context, box) {
      final full = box.maxWidth;
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: full * block.width.clamp(0.3, 1.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              Pressable(
                scale: 0.99,
                label: 'Image. Tap to view, long press for options.',
                onTap: bytes == null ? null : () => _openViewer(context, bytes),
                onLongPress: locked ? null : () => _options(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.m),
                  child: bytes == null
                      ? Container(height: 140, color: c.ground, alignment: Alignment.center, child: Text('Image not found', style: AppText.sans(13, color: c.muted)))
                      : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
              if (!locked)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => onWidth((block.width + d.delta.dx / full).clamp(0.3, 1.0)),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: Semantics(
                        label: 'Drag to resize image',
                        child: Glass(
                          radius: 14,
                          blur: 12,
                          child: SizedBox(width: 28, height: 28, child: Icon(Icons.open_in_full_rounded, size: 14, color: c.ink)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            _Caption(initial: block.text, readOnly: locked, onChanged: onCaption),
          ]),
        ),
      );
    });
  }

  Future<void> _options(BuildContext context) {
    return showAppSheet(context, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MenuRow(label: 'Full width', icon: AppIcons.image, selected: block.width >= 0.99, onTap: () {
          Navigator.pop(ctx);
          onWidth(1);
        }),
        MenuRow(label: 'Half width', icon: AppIcons.image, selected: (block.width - 0.5).abs() < 0.05, onTap: () {
          Navigator.pop(ctx);
          onWidth(0.5);
        }),
        MenuRow(label: 'Remove image', icon: AppIcons.trash, destructive: true, onTap: () {
          Navigator.pop(ctx);
          onRemove();
        }),
      ]);
    });
  }

  void _openViewer(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, __) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(bytes)))),
          Positioned(
            right: 16,
            top: 0,
            child: SafeArea(
              child: RoundIconButton(icon: AppIcons.close, label: 'Close', background: Colors.white24, foreground: Colors.white, onTap: () => Navigator.pop(ctx)),
            ),
          ),
        ]),
      ),
      transitionsBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ));
  }
}

class _Caption extends StatefulWidget {
  const _Caption({required this.initial, required this.readOnly, required this.onChanged});

  final String initial;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: _ctl,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      style: AppText.sans(12.5, color: c.muted),
      decoration: InputDecoration.collapsed(hintText: widget.readOnly ? '' : 'Add a caption', hintStyle: AppText.sans(12.5, color: c.muted.withValues(alpha: 0.5))),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onTurnInto, required this.onChecklist, required this.onBullet, required this.onImage, required this.onDone});

  final VoidCallback onTurnInto;
  final VoidCallback onChecklist;
  final VoidCallback onBullet;
  final VoidCallback onImage;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The toolbar is always dark ink, like the design, in both themes.
    final fg = c.isDark ? c.ink : c.inverseInk;
    final bg = c.isDark ? c.raised : c.ink;
    Widget btn(String label, Widget child, VoidCallback onTap) => Pressable(
          label: label,
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              btn('Turn into', Text('Aa', style: AppText.sans(16, weight: FontWeight.w700, color: fg)), onTurnInto),
              btn('Checklist', Icon(AppIcons.checklist, size: 20, color: fg), onChecklist),
              btn('Bulleted list', Icon(AppIcons.bullet, size: 20, color: fg), onBullet),
              btn('Insert image', Icon(AppIcons.image, size: 20, color: fg), onImage),
              btn('Block menu', Text('/', style: AppText.label(18, color: fg, tracking: 0)), onTurnInto),
              const Spacer(),
              Pressable(
                label: 'Done',
                onTap: onDone,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(20)),
                  child: Text('Done', style: AppText.sans(14, weight: FontWeight.w600, color: bg)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FindBar extends StatelessWidget {
  const _FindBar({required this.controller, required this.matches, required this.onChanged, required this.onClose});

  final TextEditingController controller;
  final int matches;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(color: c.ground, borderRadius: BorderRadius.circular(23)),
      child: Row(children: [
        Icon(AppIcons.search, size: 18, color: c.muted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => onChanged(),
            style: AppText.sans(15, color: c.ink),
            decoration: InputDecoration.collapsed(hintText: 'Find in note', hintStyle: AppText.sans(15, color: c.muted)),
          ),
        ),
        if (controller.text.trim().isNotEmpty) Text('$matches', style: AppText.dot(16, color: c.ink)),
        const SizedBox(width: 6),
        RoundIconButton(icon: AppIcons.close, label: 'Close find', size: 38, background: c.surface, onTap: onClose),
      ]),
    );
  }
}
