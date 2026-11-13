import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_audio.dart';
import 'focus_kit.dart';

/// Set by main() on devices; null in tests.
FocusAudio? focusAudio;

// ---------- notes ----------

/// Adds blocks to the end of a note. Returns false if the note is gone.
bool appendToNote(NoteStore notes, String? noteId, List<Block> blocks) {
  final n = noteId == null ? null : notes.note(noteId);
  if (n == null || n.inTrash) return false;
  if (n.blocks.length == 1 && n.blocks.first.type == BlockType.paragraph && n.blocks.first.text.trim().isEmpty) {
    n.blocks.clear();
  }
  n.blocks.addAll(blocks);
  notes.touch(n);
  return true;
}

/// The "Later" note collects thoughts captured during focus (your inbox).
Note laterNote(NoteStore notes) {
  for (final n in notes.notes()) {
    if (n.title.trim().toLowerCase() == 'later') return n;
  }
  return notes.createNote(title: 'Later', blocks: [Block(text: 'Thoughts captured during focus. Deal with them after.')]);
}

/// Pick a note to link. Resolves to the note id, or '' to unlink, or null when dismissed.
Future<String?> pickNote(BuildContext context, {String? current}) {
  return showFocusSheet<String>(context, scroll: false, builder: (_) => _NotePicker(current: current));
}

class _NotePicker extends StatefulWidget {
  const _NotePicker({this.current});
  final String? current;

  @override
  State<_NotePicker> createState() => _NotePickerState();
}

class _NotePickerState extends State<_NotePicker> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = StoreScope.of(context).notes(query: _q.text);
    final h = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h * 0.75),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const FocusSheetTitle('Link a note', subtitle: 'Time you focus is logged on it, and quick notes land there.'),
        const SizedBox(height: 14),
        FocusField(controller: _q, hint: 'Search notes'),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            if (widget.current != null)
              _row(context, icon: AppIcons.close, title: 'Remove link', onTap: () => Navigator.of(context).pop('')),
            for (final n in notes.take(60))
              _row(
                context,
                icon: n.id == widget.current ? FocusIcons.check : FocusIcons.note,
                title: n.displayTitle,
                subtitle: relativeDay(n.updatedAt),
                onTap: () => Navigator.of(context).pop(n.id),
              ),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('No notes match', style: AppText.sans(14, color: FocusColors.muted))),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: FocusColors.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, color: FocusColors.ink))),
          if (subtitle != null) Text(subtitle, style: AppText.sans(12.5, color: FocusColors.dim)),
        ]),
      ),
    );
  }
}

// ---------- intention ----------

Future<void> showIntentionSheet(BuildContext context) {
  return showFocusSheet<void>(context, builder: (_) => const _IntentionSheet());
}

class _IntentionSheet extends StatefulWidget {
  const _IntentionSheet();

  @override
  State<_IntentionSheet> createState() => _IntentionSheetState();
}

class _IntentionSheetState extends State<_IntentionSheet> {
  late final _text = TextEditingController(text: FocusEngineScope.read(context).intention);
  late String? _noteId = FocusEngineScope.read(context).noteId;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    FocusEngineScope.read(context).link(noteId: _noteId, intention: _text.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final notes = StoreScope.of(context);
    final note = _noteId == null ? null : notes.note(_noteId!);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FocusSheetTitle('What are you working on?', subtitle: 'One clear intention. You mark it done when the session ends.'),
      const SizedBox(height: 14),
      FocusField(controller: _text, hint: 'Draft section 2', autofocus: true, onSubmitted: (_) => _save()),
      const FocusLabel('Linked note'),
      Pressable(
        onTap: () async {
          final id = await pickNote(context, current: _noteId);
          if (id == null || !mounted) return;
          setState(() => _noteId = id.isEmpty ? null : id);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(Radii.s)),
          child: Row(children: [
            Icon(note == null ? FocusIcons.link : FocusIcons.note, size: 18, color: FocusColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(note?.displayTitle ?? 'Pick a note (optional)',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, color: note == null ? FocusColors.muted : FocusColors.ink)),
            ),
            Icon(AppIcons.forward, size: 15, color: FocusColors.dim),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      FocusButton(label: 'Save', onTap: _save),
    ]);
  }
}

// ---------- quick note and distractions ----------

Future<void> showQuickNoteSheet(BuildContext context) {
  final ctrl = TextEditingController();
  return showFocusSheet<void>(context, builder: (ctx) {
    final engine = FocusEngineScope.read(ctx);
    final notes = StoreScope.read(ctx);
    final linked = engine.noteId == null ? null : notes.note(engine.noteId!);
    void save() {
      final t = ctrl.text.trim();
      if (t.isEmpty) return;
      final target = linked ?? laterNote(notes);
      appendToNote(notes, target.id, [Block(type: BlockType.bullet, text: t)]);
      Navigator.of(ctx).pop();
      showToast(context, 'Added to ${target.displayTitle}');
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FocusSheetTitle('Quick note', subtitle: linked == null ? 'Goes to your Later note. Link a note to send it there instead.' : 'Goes to ${linked.displayTitle}.'),
      const SizedBox(height: 14),
      FocusField(controller: ctrl, hint: 'Write it down and get back to it', autofocus: true, maxLines: 4),
      const SizedBox(height: 16),
      FocusButton(label: 'Add note', onTap: save),
    ]);
  });
}

Future<void> showDistractionSheet(BuildContext context) {
  final ctrl = TextEditingController();
  return showFocusSheet<void>(context, builder: (ctx) {
    final engine = FocusEngineScope.read(ctx);
    final notes = StoreScope.read(ctx);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FocusSheetTitle('Something pulled you away?', subtitle: 'Count it, park the thought, and keep going. Thoughts go to your Later note.'),
      const SizedBox(height: 14),
      FocusField(controller: ctrl, hint: 'Reply to Rafi, check the build… (optional)', autofocus: true),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: FocusButton(
            label: 'Just count it',
            quiet: true,
            onTap: () {
              engine.logDistraction();
              Navigator.of(ctx).pop();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FocusButton(
            label: 'Park thought',
            onTap: () {
              final t = ctrl.text.trim();
              engine.logDistraction(t);
              if (t.isNotEmpty) appendToNote(notes, laterNote(notes).id, [Block(type: BlockType.checklist, text: t)]);
              Navigator.of(ctx).pop();
              showToast(context, t.isEmpty ? 'Counted' : 'Parked in Later');
            },
          ),
        ),
      ]),
    ]);
  });
}

// ---------- check-in ----------

Future<void> showCheckInSheet(BuildContext context, FocusSession session) {
  return showFocusSheet<void>(context, builder: (_) => _CheckIn(sessionId: session.id));
}

class _CheckIn extends StatefulWidget {
  const _CheckIn({required this.sessionId});
  final String sessionId;

  @override
  State<_CheckIn> createState() => _CheckInState();
}

class _CheckInState extends State<_CheckIn> {
  late final FocusSession? _s = FocusEngineScope.read(context).store.session(widget.sessionId);
  late bool? _done = _s?.intentionDone ?? (_s?.intention.isNotEmpty == true ? true : null);
  late int _rating = _s?.rating ?? 0;
  late int _energy = _s?.energy ?? 0;
  late final _note = TextEditingController(text: _s?.reflection ?? '');
  late bool _log = _s?.noteId != null;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final s = _s;
    if (s == null) return Navigator.of(context).pop();
    final store = FocusEngineScope.read(context).store;
    s
      ..intentionDone = s.intention.isEmpty ? null : _done
      ..rating = _rating
      ..energy = _energy
      ..reflection = _note.text.trim()
      ..checkedIn = true;
    store.saveSession(s);
    if (_log && s.noteId != null) {
      final parts = <String>[
        '${focusDuration(s.seconds)} focus, ${focusClock(s.start)}',
        if (s.intention.isNotEmpty) '${s.intention} ${s.intentionDone == true ? '✓' : '(not yet)'}',
        if (s.rating > 0) 'focus ${s.rating}/5',
        if (s.reflection.isNotEmpty) s.reflection,
      ];
      appendToNote(StoreScope.read(context), s.noteId, [Block(type: BlockType.quote, text: parts.join(' · '))]);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox(height: 60);
    final note = s.noteId == null ? null : StoreScope.of(context).note(s.noteId!);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${focusDuration(s.seconds)} OF FOCUS', style: AppText.label(11, color: FocusColors.muted)),
      const SizedBox(height: 6),
      Text(s.completed ? 'Round done. How did it go?' : 'Ended early. How did it go?', style: AppText.sans(20, weight: FontWeight.w700, color: FocusColors.ink)),
      if (s.broken) ...[
        const SizedBox(height: 6),
        Text('You left the app during this one, so strict mode counts it as broken.', style: AppText.sans(13, color: FocusColors.red)),
      ],
      if (s.intention.isNotEmpty) ...[
        const FocusLabel('Intention'),
        Text(s.intention, style: AppText.sans(16, weight: FontWeight.w500, color: FocusColors.ink)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FocusButton(label: 'Done', icon: FocusIcons.check, height: 44, quiet: _done != true, onTap: () => setState(() => _done = true))),
          const SizedBox(width: 8),
          Expanded(child: FocusButton(label: 'Not yet', height: 44, quiet: _done != false, onTap: () => setState(() => _done = false))),
        ]),
      ],
      const FocusLabel('Focus'),
      ScoreDots(value: _rating, onChanged: (v) => setState(() => _rating = v), low: 'SCATTERED', high: 'DEEP'),
      const FocusLabel('Energy'),
      ScoreDots(value: _energy, onChanged: (v) => setState(() => _energy = v), low: 'DRAINED', high: 'FRESH'),
      const FocusLabel('Note (optional)'),
      FocusField(controller: _note, hint: 'What helped, what got in the way', maxLines: 3),
      if (note != null) FocusToggle(title: 'Add a summary to ${note.displayTitle}', value: _log, onChanged: (v) => setState(() => _log = v)),
      if (s.distractionCount > 0) ...[
        const SizedBox(height: 8),
        Text('${s.distractionCount} ${s.distractionCount == 1 ? 'distraction' : 'distractions'} logged', style: AppText.sans(13, color: FocusColors.muted)),
      ],
      const SizedBox(height: 18),
      FocusButton(label: 'Save check-in', onTap: _save),
      const SizedBox(height: 8),
      FocusButton(
        label: 'Skip',
        quiet: true,
        onTap: () {
          s.checkedIn = true;
          FocusEngineScope.read(context).store.saveSession(s);
          Navigator.of(context).pop();
        },
      ),
    ]);
  }
}

// ---------- presets ----------

Future<void> showPresetSheet(BuildContext context) {
  return showFocusSheet<void>(context, builder: (ctx) {
    final engine = FocusEngineScope.of(ctx);
    final store = engine.store;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FocusSheetTitle('Presets', subtitle: 'Focus, short break and long break, in minutes.'),
      const SizedBox(height: 10),
      for (final p in store.presets)
        Pressable(
          onTap: () {
            engine.setPreset(p.id);
            Navigator.of(ctx).pop();
          },
          onLongPress: p.builtin ? null : () => showPresetEditor(ctx, edit: p),
          scale: 0.98,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: p.id == store.preset.id ? FocusColors.panelHigh : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.s),
              border: Border.all(color: FocusColors.line),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: AppText.sans(15.5, weight: FontWeight.w600, color: FocusColors.ink)),
                  const SizedBox(height: 2),
                  Text('${p.focus} focus · ${p.shortBreak} break · ${p.longBreak} long', style: AppText.sans(12.5, color: FocusColors.muted)),
                ]),
              ),
              if (!p.builtin)
                RoundIconButton(icon: FocusIcons.edit, label: 'Edit ${p.name}', size: 34, background: FocusColors.panelHigh, foreground: FocusColors.ink, onTap: () => showPresetEditor(ctx, edit: p)),
              if (p.id == store.preset.id) const Padding(padding: EdgeInsets.only(left: 8, right: 4), child: Icon(FocusIcons.check, size: 18, color: FocusColors.ink)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      FocusButton(label: 'New preset', icon: AppIcons.add, quiet: true, onTap: () => showPresetEditor(ctx)),
    ]);
  });
}

Future<void> showPresetEditor(BuildContext context, {FocusPreset? edit}) {
  return showFocusSheet<void>(context, builder: (_) => _PresetEditor(edit: edit));
}

class _PresetEditor extends StatefulWidget {
  const _PresetEditor({this.edit});
  final FocusPreset? edit;

  @override
  State<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends State<_PresetEditor> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late int _focus = widget.edit?.focus ?? 40;
  late int _short = widget.edit?.shortBreak ?? 8;
  late int _long = widget.edit?.longBreak ?? 20;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = FocusEngineScope.read(context);
    final e = widget.edit;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FocusSheetTitle(e == null ? 'New preset' : 'Edit preset'),
      const SizedBox(height: 14),
      FocusField(controller: _name, hint: 'Name, like Study or Writing', autofocus: e == null),
      const SizedBox(height: 8),
      FocusStepper(title: 'Focus', value: _focus, step: 5, min: 5, max: 180, unit: 'm', onChanged: (v) => setState(() => _focus = v)),
      FocusStepper(title: 'Short break', value: _short, min: 1, max: 60, unit: 'm', onChanged: (v) => setState(() => _short = v)),
      FocusStepper(title: 'Long break', value: _long, step: 5, min: 5, max: 90, unit: 'm', onChanged: (v) => setState(() => _long = v)),
      const SizedBox(height: 16),
      FocusButton(
        label: e == null ? 'Create and use' : 'Save',
        onTap: () {
          final name = _name.text.trim().isEmpty ? '$_focus / $_short' : _name.text.trim();
          if (e == null) {
            final p = engine.store.savePreset(FocusPreset(name: name, focus: _focus, shortBreak: _short, longBreak: _long));
            engine.setPreset(p.id);
          } else {
            e
              ..name = name
              ..focus = _focus
              ..shortBreak = _short
              ..longBreak = _long;
            engine.store.savePreset(e);
          }
          Navigator.of(context).pop();
        },
      ),
      if (e != null) ...[
        const SizedBox(height: 8),
        FocusButton(
          label: 'Delete preset',
          quiet: true,
          onTap: engine.started && engine.store.preset.id == e.id
              ? null
              : () {
                  engine.store.deletePreset(e);
                  Navigator.of(context).pop();
                },
        ),
      ],
    ]);
  }
}

// ---------- settings ----------

Future<void> showFocusSettings(BuildContext context) {
  return showFocusSheet<void>(context, builder: (ctx) {
    final store = FocusEngineScope.of(ctx).store;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FocusSheetTitle('Focus settings'),
      const FocusLabel('Flow'),
      FocusToggle(title: 'Start breaks on their own', value: store.autoBreaks, onChanged: (v) => store.autoBreaks = v),
      FocusToggle(title: 'Start the next round on its own', value: store.autoFocus, onChanged: (v) => store.autoFocus = v),
      FocusStepper(title: 'Long break every', value: store.longEvery, min: 2, max: 8, unit: ' rd', onChanged: (v) => store.longEvery = v),
      FocusStepper(title: 'Daily goal', value: store.dailyGoal, step: 15, min: 15, max: 720, unit: 'm', onChanged: (v) => store.dailyGoal = v),
      const FocusLabel('Discipline'),
      FocusToggle(
        title: 'Strict mode',
        subtitle: 'Leaving the app during focus marks the session as broken.',
        value: store.strict,
        onChanged: (v) => store.strict = v,
      ),
      FocusToggle(
        title: 'Protect breaks',
        subtitle: 'Breaks can\'t be skipped. Rest is part of the work.',
        value: store.lockBreaks,
        onChanged: (v) => store.lockBreaks = v,
      ),
      const FocusLabel('Sound and touch'),
      FocusToggle(title: 'Chime when a phase ends', value: store.chime, onChanged: (v) => store.chime = v),
      if (store.chime)
        Row(children: [
          const Icon(CupertinoIcons.speaker_1, size: 16, color: FocusColors.muted),
          Expanded(
            child: CupertinoSlider(
              value: store.chimeVolume,
              activeColor: FocusColors.ink,
              onChanged: (v) => store.chimeVolume = v,
              onChangeEnd: (_) => focusAudio?.chime(),
            ),
          ),
          const Icon(CupertinoIcons.speaker_3, size: 16, color: FocusColors.muted),
        ]),
      FocusToggle(title: 'Vibrate when a phase ends', value: store.vibrate, onChanged: (v) => store.vibrate = v),
      FocusToggle(title: 'Ticking during focus', value: store.tick, onChanged: (v) => store.tick = v),
      const SizedBox(height: 8),
    ]);
  });
}

// ---------- sounds ----------

Future<void> showSoundSheet(BuildContext context) {
  return showFocusSheet<void>(context, builder: (ctx) {
    final store = FocusEngineScope.of(ctx).store;
    final mix = store.soundMix;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: FocusSheetTitle('Sounds', subtitle: 'Mix any of them. Made on your phone, works offline.')),
        if (mix.isNotEmpty)
          Pressable(
            onTap: store.clearSounds,
            label: 'Turn all off',
            child: Padding(padding: const EdgeInsets.all(8), child: Text('All off', style: AppText.sans(14, weight: FontWeight.w600, color: FocusColors.ink))),
          ),
      ]),
      const SizedBox(height: 10),
      for (final s in AmbientSound.all)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
          decoration: BoxDecoration(
            color: mix.containsKey(s.id) ? FocusColors.panelHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.s),
            border: Border.all(color: FocusColors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.label, style: AppText.sans(15, weight: FontWeight.w600, color: FocusColors.ink)),
                  Text(s.blurb, style: AppText.sans(12.5, color: FocusColors.muted)),
                ]),
              ),
              CupertinoSwitch(
                value: mix.containsKey(s.id),
                activeTrackColor: FocusColors.red,
                onChanged: (v) => store.setSound(s.id, v ? 0.6 : 0),
              ),
            ]),
            if (mix.containsKey(s.id))
              CupertinoSlider(value: mix[s.id]!, min: 0.05, activeColor: FocusColors.ink, onChanged: (v) => store.setSound(s.id, v)),
          ]),
        ),
      FocusToggle(
        title: 'Only while focusing',
        subtitle: 'Sounds pause with the timer and during breaks.',
        value: store.soundsFollowTimer,
        onChanged: (v) => store.soundsFollowTimer = v,
      ),
    ]);
  });
}

// ---------- sessions ----------

/// Edit a logged session, or add one done away from the app (when [edit] is null).
Future<void> showSessionEditor(BuildContext context, {FocusSession? edit}) {
  return showFocusSheet<void>(context, builder: (_) => _SessionEditor(edit: edit));
}

class _SessionEditor extends StatefulWidget {
  const _SessionEditor({this.edit});
  final FocusSession? edit;

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late DateTime _start = widget.edit?.start ?? DateTime.now().subtract(const Duration(minutes: 30));
  late int _minutes = widget.edit == null ? 25 : (widget.edit!.seconds / 60).round().clamp(1, 600);
  late String? _noteId = widget.edit?.noteId;
  late final _intention = TextEditingController(text: widget.edit?.intention ?? '');
  late int _rating = widget.edit?.rating ?? 0;

  @override
  void dispose() {
    _intention.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    var picked = _start;
    final now = DateTime.now();
    final ok = await showFocusSheet<bool>(context, scroll: false, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const FocusSheetTitle('Started at'),
        SizedBox(
          height: 210,
          child: CupertinoTheme(
            data: CupertinoThemeData(brightness: Brightness.dark, textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: AppText.sans(19, color: FocusColors.ink))),
            child: CupertinoDatePicker(
              initialDateTime: _start.isAfter(now) ? now : _start,
              maximumDate: now,
              minimumYear: 2020,
              onDateTimeChanged: (d) => picked = d,
            ),
          ),
        ),
        FocusButton(label: 'Done', onTap: () => Navigator.of(ctx).pop(true)),
      ]);
    });
    if (ok == true && mounted) setState(() => _start = picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = FocusEngineScope.read(context).store;
    final notes = StoreScope.of(context);
    final note = _noteId == null ? null : notes.note(_noteId!);
    final e = widget.edit;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FocusSheetTitle(e == null ? 'Add a past session' : 'Edit session', subtitle: e == null ? 'For focus time done away from the app.' : null),
      const FocusLabel('Started'),
      Pressable(
        onTap: _pickStart,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(Radii.s)),
          child: Text('${weekdayShort(_start)} ${_start.day} ${monthShort(_start)} · ${focusClock(_start)}', style: AppText.sans(15.5, color: FocusColors.ink)),
        ),
      ),
      FocusStepper(title: 'Minutes', value: _minutes, step: 5, min: 5, max: 600, onChanged: (v) => setState(() => _minutes = v)),
      const FocusLabel('Intention', top: 8),
      FocusField(controller: _intention, hint: 'What you worked on'),
      const FocusLabel('Linked note'),
      Pressable(
        onTap: () async {
          final id = await pickNote(context, current: _noteId);
          if (id == null || !mounted) return;
          setState(() => _noteId = id.isEmpty ? null : id);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(Radii.s)),
          child: Text(note?.displayTitle ?? 'None', style: AppText.sans(15.5, color: note == null ? FocusColors.muted : FocusColors.ink)),
        ),
      ),
      const FocusLabel('Focus'),
      ScoreDots(value: _rating, onChanged: (v) => setState(() => _rating = v), low: 'SCATTERED', high: 'DEEP'),
      const SizedBox(height: 18),
      FocusButton(
        label: e == null ? 'Add session' : 'Save',
        onTap: () {
          final end = _start.add(Duration(minutes: _minutes));
          if (e == null) {
            store.saveSession(FocusSession(
              start: _start,
              end: end,
              seconds: _minutes * 60,
              planned: _minutes * 60,
              presetName: 'Manual',
              noteId: _noteId,
              intention: _intention.text.trim(),
              rating: _rating,
              manual: true,
              checkedIn: true,
            ));
          } else {
            e
              ..start = _start
              ..end = end
              ..seconds = _minutes * 60
              ..noteId = _noteId
              ..intention = _intention.text.trim()
              ..rating = _rating;
            store.saveSession(e);
          }
          Navigator.of(context).pop();
        },
      ),
      if (e != null) ...[
        const SizedBox(height: 8),
        FocusButton(
          label: 'Delete session',
          quiet: true,
          onTap: () {
            store.deleteSession(e);
            showToast(context, 'Session deleted', actionLabel: 'Undo', onAction: () => store.saveSession(e));
            Navigator.of(context).pop();
          },
        ),
      ],
    ]);
  }
}
