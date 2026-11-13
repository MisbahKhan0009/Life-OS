import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/share_inbox.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/logo.dart';
import '../../ui/widgets.dart';

const _channel = MethodChannel('life_os/share');

/// The "Save to Life OS" popup. Runs on its own over the app you shared from.
class ShareApp extends StatelessWidget {
  const ShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: AppTheme.build(AppColors.light),
      darkTheme: AppTheme.build(AppColors.dark),
      home: const ShareSheet(),
    );
  }
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, this.inbox, this.shared});

  /// For tests.
  final ShareInbox? inbox;
  final ({String text, String subject})? shared;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  final _note = TextEditingController();
  final _newFolder = TextEditingController();
  ShareInbox? _inbox;
  String _text = '';
  String _subject = '';
  List<({String id, String name, String art})> _folders = const [];
  String? _folderId;
  List<({String id, String title, String? folderId})> _notes = const [];

  /// The note to add to; null makes a new one.
  String? _noteId;
  final _newNote = TextEditingController();
  bool _creating = false;
  bool _saved = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _in.forward();
  }

  Future<void> _load() async {
    final inbox = widget.inbox ?? await ShareInbox.open();
    var text = widget.shared?.text ?? '';
    var subject = widget.shared?.subject ?? '';
    if (widget.shared == null) {
      try {
        final m = await _channel.invokeMapMethod<String, dynamic>('getShared');
        text = (m?['text'] as String?) ?? '';
        subject = (m?['subject'] as String?) ?? '';
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _inbox = inbox;
      _text = text;
      _subject = subject;
      _folders = inbox?.readFolders() ?? const [];
      _notes = inbox?.readNotes() ?? const [];
      // Start where the last share went, so saving more of the same is one tap.
      final last = inbox?.readLast();
      if (last != null && (last.folderId == null || _folders.any((f) => f.id == last.folderId))) {
        _folderId = last.folderId;
        if (last.noteId != null && _notes.any((n) => n.id == last.noteId && n.folderId == last.folderId)) _noteId = last.noteId;
      }
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _note.dispose();
    _newFolder.dispose();
    _newNote.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await _in.reverse();
    try {
      await _channel.invokeMethod('close');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }

  Future<void> _save() async {
    if (_saved) return;
    HapticFeedback.mediumImpact();
    final newName = _creating ? _newFolder.text.trim() : '';
    final noteId = newName.isEmpty ? _noteId : null;
    try {
      _inbox?.add(
        text: _text,
        subject: _subject,
        note: _note.text,
        folderId: newName.isEmpty ? _folderId : null,
        newFolder: newName.isEmpty ? null : newName,
        noteId: noteId,
        newNoteTitle: noteId == null ? _newNote.text.trim() : null,
      );
      if (newName.isEmpty) _inbox?.writeLast(folderId: _folderId, noteId: noteId);
    } catch (_) {}
    setState(() => _saved = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final url = firstUrl(_text);
    final media = MediaQuery.of(context);
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // Dim the app behind, tap to dismiss.
        Positioned.fill(
          child: FadeTransition(
            opacity: curve,
            child: GestureDetector(onTap: _close, child: const ColoredBox(color: Color(0x66000000))),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: curve,
            builder: (context, child) => FractionalTranslation(translation: Offset(0, 1 - curve.value), child: child),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + media.viewInsets.bottom + media.padding.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560, maxHeight: media.size.height * 0.85),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  child: ColoredBox(
                    color: c.surface,
                    child: Stack(children: [
                      Positioned.fill(child: IgnorePointer(child: GrainOverlay(opacity: c.isDark ? 0.05 : 0.07))),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(height: 14),
                          Row(children: [
                            const OrbitMark(size: 36, background: Color(0xFF0E0E0F)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Save to Life OS', style: AppText.sans(18, weight: FontWeight.w700, color: c.ink)),
                                Text('Becomes a note. You stay where you are.', style: AppText.sans(12.5, color: c.muted)),
                              ]),
                            ),
                            RoundIconButton(icon: AppIcons.close, label: 'Cancel', size: 36, background: c.chip, foreground: c.ink, onTap: _close),
                          ]),
                          const SizedBox(height: 16),
                          _Preview(text: _text, url: url, subject: _subject),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.line)),
                            child: TextField(
                              controller: _note,
                              minLines: 2,
                              maxLines: 5,
                              cursorColor: c.action,
                              textCapitalization: TextCapitalization.sentences,
                              style: AppText.sans(16, color: c.ink, height: 1.35),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: _noteId == null ? 'Add a note (optional)' : 'A line above the link (optional)',
                                hintStyle: AppText.sans(16, color: c.muted),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Text('FOLDER', style: AppText.label(10.5, color: c.muted)),
                            const SizedBox(width: 6),
                            Text('OPTIONAL', style: AppText.label(10.5, color: c.muted.withValues(alpha: 0.6))),
                          ]),
                          const SizedBox(height: 10),
                          _creating ? _newFolderField(c) : _folderChips(c),
                          const SizedBox(height: 16),
                          Row(children: [
                            Text('NOTE', style: AppText.label(10.5, color: c.muted)),
                            const SizedBox(width: 6),
                            Text(_noteId == null ? 'NEW' : 'ADD TO EXISTING', style: AppText.label(10.5, color: c.muted.withValues(alpha: 0.6))),
                          ]),
                          const SizedBox(height: 8),
                          _noteList(c),
                          const SizedBox(height: 18),
                          Pressable(
                            onTap: _save,
                            label: 'Save',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: _saved ? c.ink : c.action, borderRadius: BorderRadius.circular(27)),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
                                child: _saved
                                    ? Row(key: const ValueKey('done'), mainAxisSize: MainAxisSize.min, children: [
                                        Icon(AppIcons.check, size: 18, color: c.inverseInk),
                                        const SizedBox(width: 8),
                                        Text('Saved', style: AppText.sans(16, weight: FontWeight.w600, color: c.inverseInk)),
                                      ])
                                    : Text(_saveLabel(), key: const ValueKey('save'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(16, weight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _folderChips(AppColors c) {
    return SizedBox(
      height: 38,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        _Chip(label: 'No folder', selected: _folderId == null, onTap: () => setState(() {
              _folderId = null;
              _noteId = null;
            })),
        for (final f in _folders) ...[
          const SizedBox(width: 8),
          _Chip(label: f.name, art: f.art, selected: _folderId == f.id, onTap: () => setState(() {
                _folderId = f.id;
                _noteId = null;
              })),
        ],
        const SizedBox(width: 8),
        _Chip(
          label: 'New folder',
          icon: AppIcons.add,
          selected: false,
          onTap: () => setState(() {
            _creating = true;
            _folderId = null;
            _noteId = null;
          }),
        ),
      ]),
    );
  }

  String _saveLabel() {
    if (_noteId == null || _creating) return 'Save';
    final t = _notes.where((n) => n.id == _noteId).firstOrNull?.title ?? 'note';
    return 'Add to $t';
  }

  /// "New note" plus the notes in the chosen folder, newest first.
  Widget _noteList(AppColors c) {
    final inFolder = _creating ? const <({String id, String title, String? folderId})>[] : _notes.where((n) => n.folderId == _folderId).take(40).toList();
    Widget row({required bool selected, required VoidCallback onTap, required Widget child, IconData? icon}) => Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          scale: 0.98,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: selected ? c.ink : c.chip.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Radii.s),
            ),
            child: Row(children: [
              Icon(icon ?? (selected ? AppIcons.check : AppIcons.notes), size: 16, color: selected ? c.inverseInk : c.muted),
              const SizedBox(width: 10),
              Expanded(child: child),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row(
        selected: _noteId == null,
        icon: AppIcons.add,
        onTap: () => setState(() => _noteId = null),
        child: _noteId == null
            ? TextField(
                controller: _newNote,
                cursorColor: c.action,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.sans(15, weight: FontWeight.w500, color: c.inverseInk),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'New note · name it, or leave blank',
                  hintStyle: AppText.sans(15, color: c.inverseInk.withValues(alpha: 0.6)),
                ),
              )
            : Text('New note', style: AppText.sans(15, weight: FontWeight.w500, color: c.ink)),
      ),
      if (inFolder.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 196),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final n in inFolder)
                row(
                  selected: _noteId == n.id,
                  onTap: () => setState(() => _noteId = n.id),
                  child: Text(n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(15, weight: FontWeight.w500, color: _noteId == n.id ? c.inverseInk : c.ink)),
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _newFolderField(AppColors c) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(23), border: Border.all(color: c.ink, width: 1.2)),
          child: TextField(
            controller: _newFolder,
            autofocus: true,
            cursorColor: c.action,
            textCapitalization: TextCapitalization.words,
            style: AppText.sans(15.5, color: c.ink),
            decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Folder name', hintStyle: AppText.sans(15.5, color: c.muted)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      RoundIconButton(
        icon: AppIcons.close,
        label: 'Pick an existing folder',
        size: 46,
        background: c.chip,
        foreground: c.ink,
        onTap: () => setState(() {
          _creating = false;
          _newFolder.clear();
        }),
      ),
    ]);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.url, required this.subject});

  final String text;
  final String? url;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final host = url == null ? null : hostOf(url!);
    final rest = url == null ? text.trim() : text.replaceFirst(url!, '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.chip.withValues(alpha: c.isDark ? 0.6 : 0.7), borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(fit: StackFit.expand, children: [
              ArtPresets.art(host == null ? 'honey' : 'tide', grain: 0.5),
              Icon(host == null ? CupertinoIcons.text_quote : CupertinoIcons.link, size: 20, color: Colors.white),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              subject.isNotEmpty ? subject : (host ?? (text.isEmpty ? 'Nothing was shared' : 'Text')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(15, weight: FontWeight.w600, color: c.ink),
            ),
            const SizedBox(height: 2),
            if (rest.isNotEmpty)
              Text(rest, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.sans(13, color: c.muted, height: 1.3)),
            if (url != null)
              Text(url!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: c.muted.withValues(alpha: 0.8))),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon, this.art});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? art;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 38,
        padding: EdgeInsets.only(left: art != null ? 5 : 14, right: 14),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.chip,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (art != null) ...[
            ClipOval(child: SizedBox(width: 28, height: 28, child: ArtPresets.art(art!, grain: 0.4))),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[Icon(icon, size: 16, color: selected ? c.inverseInk : c.ink), const SizedBox(width: 6)],
          Text(label, style: AppText.sans(14, weight: FontWeight.w500, color: selected ? c.inverseInk : c.ink)),
        ]),
      ),
    );
  }
}
