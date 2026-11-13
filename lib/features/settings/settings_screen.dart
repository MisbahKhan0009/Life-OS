import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../notes/note_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(children: [RoundIconButton(icon: AppIcons.back, label: 'Back', onTap: () => Navigator.pop(context))]),
              const SizedBox(height: 16),
              Text('Settings', style: AppText.sans(34, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.9)),
              const SizedBox(height: 22),
              const SectionLabel('Appearance'),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  for (final m in ThemeMode.values)
                    Expanded(
                      child: Pressable(
                        label: '${m.name} theme',
                        onTap: () => store.themeMode = m,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 52,
                          decoration: BoxDecoration(color: store.themeMode == m ? c.ink : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(
                              switch (m) { ThemeMode.light => AppIcons.sun, ThemeMode.dark => AppIcons.moon, ThemeMode.system => AppIcons.settings },
                              size: 18,
                              color: store.themeMode == m ? c.inverseInk : c.ink,
                            ),
                            const SizedBox(height: 2),
                            Text(switch (m) { ThemeMode.light => 'Light', ThemeMode.dark => 'Dark', ThemeMode.system => 'System' },
                                style: AppText.sans(12, weight: FontWeight.w600, color: store.themeMode == m ? c.inverseInk : c.ink)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Library'),
              _NavRow(
                icon: AppIcons.archive,
                label: 'Archive',
                count: store.archived.length,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BinScreen(trash: false))),
              ),
              const SizedBox(height: 8),
              _NavRow(
                icon: AppIcons.trash,
                label: 'Trash',
                count: store.trash.length,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BinScreen(trash: true))),
              ),
              const SizedBox(height: 22),
              const SectionLabel('About'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(twoDigits(store.activeCount), style: AppText.dot(30, color: c.ink)),
                    const SizedBox(width: 8),
                    Text('notes on this device', style: AppText.sans(14, color: c.muted)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Life OS 0.1. Notes are stored offline on this device. Focus and Money arrive in the next builds.', style: AppText.sans(13, color: c.muted, height: 1.4)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.98,
      label: label,
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m)),
        child: Row(children: [
          Icon(icon, size: 20, color: c.ink),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.sans(15, weight: FontWeight.w600, color: c.ink))),
          Text(twoDigits(count), style: AppText.dot(16, color: c.muted)),
          const SizedBox(width: 8),
          Icon(AppIcons.forward, size: 16, color: c.muted),
        ]),
      ),
    );
  }
}

/// Archive or Trash. Trash keeps notes for 30 days.
class BinScreen extends StatefulWidget {
  const BinScreen({super.key, required this.trash});

  final bool trash;

  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  bool _confirmEmpty = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final list = widget.trash ? store.trash : store.archived;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(children: [
                RoundIconButton(icon: AppIcons.back, label: 'Back', onTap: () => Navigator.pop(context)),
                const Spacer(),
                if (widget.trash && list.isNotEmpty)
                  PillButton(
                    label: _confirmEmpty ? 'Tap again to delete all' : 'Empty trash',
                    style: _confirmEmpty ? PillStyle.action : PillStyle.secondary,
                    height: 40,
                    onTap: () {
                      if (!_confirmEmpty) {
                        setState(() => _confirmEmpty = true);
                        return;
                      }
                      store.emptyTrash();
                      setState(() => _confirmEmpty = false);
                      showToast(context, 'Trash emptied');
                    },
                  ),
              ]),
              const SizedBox(height: 16),
              Text(widget.trash ? 'Trash' : 'Archive', style: AppText.sans(34, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.9)),
              const SizedBox(height: 6),
              Text(
                widget.trash ? 'Notes here are deleted for good after ${NoteStore.trashDays} days.' : 'Archived notes are hidden from Notes and search.',
                style: AppText.sans(14, color: c.muted),
              ),
              const SizedBox(height: 18),
              if (list.isEmpty)
                Text(widget.trash ? 'Trash is empty.' : 'Nothing archived.', style: AppText.sans(15, color: c.muted))
              else
                for (final n in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.trash ? _TrashRow(note: n) : NoteRow(note: n)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.read(context);
    final left = NoteStore.trashDays - DateTime.now().difference(note.trashedAt!).inDays;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 2),
            Text('Deleted ${relativeDay(note.trashedAt!)} · ${left.clamp(0, NoteStore.trashDays)} days left', style: AppText.sans(12, color: c.muted)),
          ]),
        ),
        RoundIconButton(icon: AppIcons.restore, label: 'Restore', size: 38, background: c.ground, onTap: () {
          store.restore(note);
          showToast(context, 'Restored');
        }),
        const SizedBox(width: 6),
        RoundIconButton(icon: AppIcons.trash, label: 'Delete forever', size: 38, background: c.ground, foreground: c.action, onTap: () {
          store.deleteForever(note);
          showToast(context, 'Deleted forever');
        }),
      ]),
    );
  }
}
