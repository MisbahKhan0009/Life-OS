import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/widgets.dart';
import '../notes/note_widgets.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final folders = store.folders;
    final total = folders.fold<int>(0, (s, f) => s + store.countIn(f.id));
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${folders.length} ${folders.length == 1 ? 'FOLDER' : 'FOLDERS'} · $total NOTES', style: AppText.label(11, color: c.muted)),
                    const SizedBox(height: 8),
                    Text('Folders', style: AppText.display(46, color: c.ink, height: 1)),
                  ]),
                ),
                PillButton(label: 'New folder', icon: AppIcons.add, height: 40, onTap: () => showFolderEditor(context)),
              ],
            ),
            const SizedBox(height: 22),
            if (folders.isEmpty)
              Text('No folders yet. Create one to group related notes.', style: AppText.sans(15, color: c.muted))
            else
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 520 ? 3 : 2;
                const gap = 12.0;
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final f in folders) SizedBox(width: w, child: FolderCard(folder: f))],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final last = store.lastActivity(folder);
    final count = store.countIn(folder.id);
    final dark = !ArtPresets.isLight(folder.art);
    final bg = dark ? const Color(0xFF151515) : c.surface;
    final fg = dark ? const Color(0xFFF2F1EC) : c.ink;
    final sub = dark ? const Color(0xFF9C9B96) : c.muted;
    return Pressable(
      scale: 0.97,
      label: folder.name,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FolderScreen(folderId: folder.id))),
      onLongPress: () => showFolderEditor(context, folder: folder),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.l)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: SizedBox(height: 92, width: double.infinity, child: ArtPresets.art(folder.art)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: fg)),
                const SizedBox(height: 2),
                Text(folder.description.isEmpty ? ' ' : folder.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: sub)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(twoDigits(last.day), style: AppText.dot(22, color: fg)),
                    const SizedBox(width: 4),
                    Text(monthShort(last), style: AppText.sans(12, color: sub)),
                    const Spacer(),
                    Text('$count ${count == 1 ? 'note' : 'notes'}', style: AppText.sans(12, color: sub)),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a folder: name, description and cover art.
Future<void> showFolderEditor(BuildContext context, {Folder? folder}) {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: folder?.name ?? '');
  final desc = TextEditingController(text: folder?.description ?? '');
  var art = folder?.art ?? ArtPresets.names[store.folders.length % ArtPresets.names.length];
  var confirmDelete = false;
  return showAppSheet(context, builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setSheet) {
      final c = ctx.colors;
      InputDecoration deco(String hint) => InputDecoration(
            hintText: hint,
            hintStyle: AppText.sans(15, color: c.muted),
            filled: true,
            fillColor: c.ground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(folder == null ? 'New folder' : 'Edit folder', style: AppText.sans(19, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 14),
          TextField(controller: name, autofocus: folder == null, style: AppText.sans(15, color: c.ink), decoration: deco('Name')),
          const SizedBox(height: 8),
          TextField(controller: desc, style: AppText.sans(15, color: c.ink), decoration: deco('Description (optional)')),
          const SizedBox(height: 14),
          Text('COVER', style: AppText.label(10.5, color: c.muted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final a in ArtPresets.names)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pressable(
                    label: 'Cover $a',
                    onTap: () => setSheet(() => art = a),
                    child: Container(
                      width: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: art == a ? c.ink : Colors.transparent, width: 2),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(borderRadius: BorderRadius.circular(11), child: ArtPresets.art(a)),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          PillButton(
            label: folder == null ? 'Create folder' : 'Save',
            expand: true,
            onTap: () {
              if (folder == null) {
                store.createFolder(name.text, art: art, description: desc.text.trim());
              } else {
                folder.name = name.text.trim().isEmpty ? folder.name : name.text.trim();
                folder.description = desc.text.trim();
                folder.art = art;
                store.updateFolder(folder);
              }
              Navigator.pop(ctx);
            },
          ),
          if (folder != null) ...[
            const SizedBox(height: 8),
            PillButton(
              label: confirmDelete ? 'Tap again to delete folder' : 'Delete folder',
              style: confirmDelete ? PillStyle.action : PillStyle.quiet,
              expand: true,
              onTap: () {
                if (!confirmDelete) {
                  setSheet(() => confirmDelete = true);
                  return;
                }
                store.deleteFolder(folder);
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((r) => r.isFirst);
                showToast(context, 'Folder deleted. Its notes are kept.');
              },
            ),
          ],
        ],
      );
    });
  });
}

class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final folder = store.folder(folderId);
    if (folder == null) return Scaffold(backgroundColor: c.ground);
    final notes = store.notes(folderId: folderId);
    return Scaffold(
      backgroundColor: c.ground,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: ArtPresets.art(folder.art, grain: 0.5),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${notes.length} ${notes.length == 1 ? 'NOTE' : 'NOTES'}', style: AppText.label(11, color: c.muted)),
                  const SizedBox(height: 6),
                  Text(folder.name, style: AppText.display(38, color: c.ink)),
                  if (folder.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(folder.description, style: AppText.sans(15, color: c.muted)),
                  ],
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: notes.isEmpty
                    ? Text('No notes here yet.', style: AppText.sans(15, color: c.muted))
                    : Column(children: [for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 8), child: NoteRow(note: n))]),
              ),
            ),
          ),
        ]),
        Positioned(
          left: 16,
          right: 16,
          top: 0,
          child: SafeArea(
            child: Row(children: [
              Glass(radius: 20, child: RoundIconButton(icon: AppIcons.back, label: 'Back', background: Colors.transparent, onTap: () => Navigator.pop(context))),
              const Spacer(),
              Glass(
                radius: 20,
                child: RoundIconButton(icon: AppIcons.more, label: 'Edit folder', background: Colors.transparent, onTap: () => showFolderEditor(context, folder: folder)),
              ),
            ]),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 20),
            child: PillButton(label: 'New note', icon: AppIcons.add, height: 54, onTap: () => createAndOpenNote(context, folderId: folderId)),
          ),
        ),
      ]),
    );
  }
}
