import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/format.dart';
import '../../data/markdown.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';

String noteMeta(NoteStore store, Note n) {
  final parts = <String>[relativeDay(n.updatedAt)];
  final f = store.folder(n.folderId);
  if (f != null) parts.add(f.name);
  if (n.hasChecklist) {
    parts.add(n.openTasks == 0 ? 'All done' : '${n.openTasks} left');
  } else if (n.hasImage) {
    parts.add('Images');
  }
  return parts.join(' · ');
}

class _TypeTile extends StatelessWidget {
  const _TypeTile(this.note);
  final Note note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, bg) = note.hasChecklist
        ? (AppIcons.checklist, c.mist)
        : note.hasImage
            ? (AppIcons.image, c.isDark ? MoneyColors.deepNavy : MoneyColors.paleBlue)
            : (AppIcons.notes, c.isDark ? const Color(0xFF332C23) : const Color(0xFFE8DCCB));
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 19, color: c.ink),
    );
  }
}

/// A note in a list, styled after the mood board's list rows.
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.note, this.highlight = ''});

  final Note note;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    return Pressable(
      scale: 0.98,
      label: note.displayTitle,
      onTap: () => openNote(context, note.id),
      onLongPress: () => showNoteActions(context, note),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m)),
        child: Row(
          children: [
            _TypeTile(note),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (note.pinned) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(AppIcons.pinFill, size: 12, color: c.muted)),
                    if (note.locked) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(AppIcons.lock, size: 12, color: c.muted)),
                    Flexible(
                      child: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: c.ink)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(noteMeta(store, note), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: c.muted)),
                ],
              ),
            ),
            RoundIconButton(
              icon: AppIcons.moreVertical,
              label: 'More options for ${note.displayTitle}',
              size: 36,
              background: Colors.transparent,
              foreground: c.muted,
              onTap: () => showNoteActions(context, note),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned notes as an overlapping stack: two coloured tabs behind one card.
class PinnedStack extends StatelessWidget {
  const PinnedStack({super.key, required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = notes.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final front = shown.first;
    final behind = shown.skip(1).toList().reversed.toList();
    const tab = 44.0;
    final backColors = [c.isDark ? const Color(0xFF4F5E51) : c.sage, c.stone];
    final height = 150 + tab * behind.length;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < behind.length; i++)
            Positioned(
              left: 14.0 - i * 7,
              right: 14.0 - i * 7,
              top: tab * i,
              height: 120,
              child: Pressable(
                scale: 0.98,
                label: behind[i].displayTitle,
                onTap: () => openNote(context, behind[i].id),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  alignment: Alignment.topLeft,
                  decoration: BoxDecoration(
                    color: backColors[i % 2],
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(behind[i].displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(14, weight: FontWeight.w600, color: i % 2 == 0 && !c.isDark ? c.inverseInk : c.ink)),
                    ),
                    Text(relativeDay(behind[i].updatedAt).toUpperCase(), style: AppText.label(10.5, color: i % 2 == 0 && !c.isDark ? c.inverseInk.withValues(alpha: 0.8) : c.muted)),
                  ]),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: tab * behind.length,
            height: 150,
            child: Pressable(
              scale: 0.98,
              label: front.displayTitle,
              onTap: () => openNote(context, front.id),
              onLongPress: () => showNoteActions(context, front),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.l),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(front.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(18, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.2)),
                      ),
                      Icon(AppIcons.pinFill, size: 15, color: c.ink),
                    ]),
                    const SizedBox(height: 8),
                    Text(plainPreview(front.preview), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.sans(14, color: c.muted, height: 1.4)),
                    const Spacer(),
                    if (front.hasChecklist)
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: front.doneTasks / (front.doneTasks + front.openTasks),
                              minHeight: 4,
                              backgroundColor: c.chip,
                              color: c.isDark ? c.action : c.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${front.doneTasks}/${front.doneTasks + front.openTasks}', style: AppText.dot(14, color: c.ink)),
                      ])
                    else
                      Text(relativeDay(front.updatedAt).toUpperCase(), style: AppText.label(10.5, color: c.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Long-press / ··· actions for a note.
Future<void> showNoteActions(BuildContext context, Note note) {
  final store = StoreScope.read(context);
  return showAppSheet(context, builder: (ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(17, weight: FontWeight.w700, color: ctx.colors.ink)),
        ),
        MenuRow(
          label: note.pinned ? 'Unpin' : 'Pin to top',
          icon: note.pinned ? AppIcons.pinFill : AppIcons.pin,
          onTap: () {
            Navigator.pop(ctx);
            store.togglePin(note);
          },
        ),
        MenuRow(
          label: 'Move to folder',
          icon: AppIcons.folder,
          onTap: () {
            Navigator.pop(ctx);
            showMoveSheet(context, note);
          },
        ),
        MenuRow(
          label: 'Copy as Markdown',
          icon: AppIcons.copy,
          onTap: () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: noteToMarkdown(note)));
            showToast(context, 'Copied as Markdown');
          },
        ),
        MenuRow(
          label: note.archived ? 'Unarchive' : 'Archive',
          icon: AppIcons.archive,
          onTap: () {
            Navigator.pop(ctx);
            store.archive(note, !note.archived);
            showToast(context, note.archived ? 'Archived' : 'Moved back to notes');
          },
        ),
        MenuRow(
          label: 'Move to trash',
          icon: AppIcons.trash,
          destructive: true,
          onTap: () {
            Navigator.pop(ctx);
            store.moveToTrash(note);
            showToast(context, 'Moved to trash', actionLabel: 'Undo', onAction: () => store.restore(note));
          },
        ),
      ],
    );
  });
}

/// Folder picker for moving a note.
Future<void> showMoveSheet(BuildContext context, Note note) {
  final store = StoreScope.read(context);
  return showAppSheet(context, builder: (ctx) {
    final c = ctx.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text('Move to folder', style: AppText.sans(17, weight: FontWeight.w700, color: c.ink)),
        ),
        MenuRow(
          label: 'No folder',
          icon: note.folderId == null ? AppIcons.check : AppIcons.notes,
          selected: note.folderId == null,
          onTap: () {
            Navigator.pop(ctx);
            store.moveToFolder(note, null);
          },
        ),
        for (final f in store.folders)
          MenuRow(
            label: f.name,
            icon: note.folderId == f.id ? AppIcons.check : AppIcons.folder,
            selected: note.folderId == f.id,
            onTap: () {
              Navigator.pop(ctx);
              store.moveToFolder(note, f.id);
              showToast(context, 'Moved to ${f.name}');
            },
          ),
      ],
    );
  });
}
