import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../notes/note_widgets.dart';
import '../assistant/assistant_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  NoteFilter _filter = NoteFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final query = _search.text;
    final browsing = query.trim().isEmpty && _filter == NoteFilter.all;
    final pinned = browsing ? store.pinned : const <Note>[];
    final list = store.notes(filter: _filter, query: query).where((n) => !browsing || !n.pinned).toList();

    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            Row(children: [
              Expanded(child: Text(headerDate(DateTime.now()), style: AppText.label(11, color: c.muted))),
              const AskButton(),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: AppIcons.settings,
                label: 'Settings, archive and trash',
                size: 38,
                background: c.sage,
                foreground: c.inverseInk,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Notes', style: AppText.display(46, color: c.ink, height: 1)),
            const SizedBox(height: 14),
            _SearchField(controller: _search, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in NoteFilter.values) ...[
                  AppChip(
                    label: switch (f) {
                      NoteFilter.all => 'All',
                      NoteFilter.pinned => 'Pinned',
                      NoteFilter.checklists => 'Checklists',
                      NoteFilter.images => 'Images',
                    },
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 22),
            if (pinned.isNotEmpty) ...[
              SectionLabel('Pinned', trailing: Text(twoDigits(pinned.length), style: AppText.dot(15, color: c.ink))),
              PinnedStack(notes: pinned),
              const SizedBox(height: 22),
            ],
            if (list.isNotEmpty) ...[
              SectionLabel(browsing ? 'Recent' : '${list.length} ${list.length == 1 ? 'note' : 'notes'}'),
              for (final n in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: NoteRow(note: n)),
            ] else if (pinned.isEmpty)
              _Empty(searching: !browsing),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(23)),
      child: Row(children: [
        Icon(AppIcons.search, size: 18, color: c.muted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: AppText.sans(15, color: c.ink),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Search notes',
              hintStyle: AppText.sans(15, color: c.muted),
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          RoundIconButton(
            icon: AppIcons.close,
            label: 'Clear search',
            size: 28,
            background: c.chip,
            onTap: () {
              controller.clear();
              onChanged('');
            },
          ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l)),
      child: Column(children: [
        Text(searching ? '00' : '0', style: AppText.dot(44, color: c.muted)),
        const SizedBox(height: 10),
        Text(searching ? 'No notes match.' : 'No notes yet.', style: AppText.sans(16, weight: FontWeight.w600, color: c.ink)),
        const SizedBox(height: 4),
        Text(searching ? 'Try fewer words or another filter.' : 'Tap + to write your first note.',
            textAlign: TextAlign.center, style: AppText.sans(14, color: c.muted)),
        if (!searching) ...[
          const SizedBox(height: 16),
          PillButton(label: 'New note', icon: AppIcons.add, onTap: () => createAndOpenNote(context)),
        ],
      ]),
    );
  }
}
