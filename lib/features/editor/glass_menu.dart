import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';

enum GlassAction { pin, lock, copy, find, focus, move, image, archive, delete }

/// The Liquid Glass context menu from the mood board: a row of quick icons,
/// then labelled actions with their icon on the right.
Future<GlassAction?> showGlassMenu(BuildContext context, {required Note note, String focusLabel = 'Focus on this'}) {
  return showGeneralDialog<GlassAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _GlassMenu(note: note, focusLabel: focusLabel),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), alignment: Alignment.topRight, child: child),
      );
    },
  );
}

class _GlassMenu extends StatelessWidget {
  const _GlassMenu({required this.note, required this.focusLabel});

  final Note note;
  final String focusLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void pick(GlassAction a) => Navigator.of(context).pop(a);
    Widget quick(IconData icon, String label, GlassAction a) => Expanded(
          child: Pressable(
            label: label,
            onTap: () => pick(a),
            child: SizedBox(height: 46, child: Icon(icon, size: 21, color: c.ink)),
          ),
        );
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 58, right: 12),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 252,
              child: Glass(
                radius: 26,
                blur: 28,
                padding: const EdgeInsets.all(8),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    quick(AppIcons.copy, 'Copy as Markdown', GlassAction.copy),
                    quick(note.pinned ? AppIcons.pinFill : AppIcons.pin, note.pinned ? 'Unpin' : 'Pin', GlassAction.pin),
                    quick(note.locked ? AppIcons.unlock : AppIcons.lock, note.locked ? 'Unlock' : 'Lock', GlassAction.lock),
                  ]),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, color: c.ink.withValues(alpha: 0.1))),
                  MenuRow(label: 'Find in note', icon: AppIcons.search, onTap: () => pick(GlassAction.find)),
                  MenuRow(label: focusLabel, icon: AppIcons.focus, onTap: () => pick(GlassAction.focus)),
                  MenuRow(label: 'Move to folder', icon: AppIcons.folder, onTap: () => pick(GlassAction.move)),
                  if (!note.locked) MenuRow(label: 'Insert image', icon: AppIcons.image, onTap: () => pick(GlassAction.image)),
                  MenuRow(label: note.archived ? 'Unarchive' : 'Archive', icon: AppIcons.archive, onTap: () => pick(GlassAction.archive)),
                  MenuRow(label: 'Move to trash', icon: AppIcons.trash, destructive: true, onTap: () => pick(GlassAction.delete)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
