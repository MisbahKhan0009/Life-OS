import 'package:flutter/material.dart';

import '../data/store.dart';
import '../features/editor/editor_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/folders/folders_screen.dart';
import '../features/home/home_screen.dart';
import '../data/money_models.dart';
import '../features/money/money_screen.dart';
import '../features/money/txn_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/widgets.dart';

/// Opens the editor for a note. New notes are discarded on close if left empty.
Future<void> openNote(BuildContext context, String noteId, {bool isNew = false}) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(noteId: noteId, isNew: isNew)));
}

Future<void> createAndOpenNote(BuildContext context, {String? folderId}) {
  final note = StoreScope.read(context).createNote(folderId: folderId);
  return openNote(context, note.id, isNew: true);
}

/// Keeps content readable on tablets and desktop.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.max = 640});

  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
    );
  }
}

/// The selected tab. Other screens can switch tabs by setting it (2 is Focus).
final shellTab = ValueNotifier<int>(0);

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int get _tab => shellTab.value;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  static const _tabs = [
    (AppIcons.notes, 'Notes'),
    (AppIcons.folder, 'Folders'),
    (AppIcons.focus, 'Focus'),
    (AppIcons.money, 'Money'),
  ];

  @override
  Widget build(BuildContext context) {
    final focusTab = _tab == 2;
    final moneyTab = _tab == 3;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _tab,
              children: [
                const HomeScreen(),
                const FoldersScreen(),
                Theme(data: AppTheme.build(AppColors.dark), child: FocusScreen(active: focusTab)),
                const MoneyScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 18),
              child: ContentWidth(
                max: 560,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Theme(
                    data: focusTab ? AppTheme.build(AppColors.dark) : Theme.of(context),
                    child: _NavBar(
                      index: _tab,
                      money: moneyTab,
                      onSelect: (i) => shellTab.value = i,
                      addLabel: moneyTab ? 'Add transaction' : 'New note',
                      onAdd: focusTab
                          ? null
                          : moneyTab
                              ? () => showTxnSheet(context, kind: TxnKind.expense)
                              : () => createAndOpenNote(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect, required this.money, this.onAdd, this.addLabel = 'New note'});

  final int index;
  final bool money;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeBg = money && !c.isDark ? MoneyColors.navy : c.ink;
    final activeFg = money && !c.isDark ? MoneyColors.ice : c.inverseInk;
    return Row(
      children: [
        Expanded(
          child: Glass(
            radius: 31,
            child: SizedBox(
              height: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _RootShellState._tabs.length; i++)
                      _NavItem(
                        icon: _RootShellState._tabs[i].$1,
                        label: _RootShellState._tabs[i].$2,
                        active: i == index,
                        activeBg: activeBg,
                        activeFg: activeFg,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 10),
          Pressable(
            onTap: onAdd,
            label: addLabel,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: c.isDark ? c.action : activeBg,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Icon(AppIcons.add, color: c.isDark ? Colors.white : activeFg, size: 24),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.activeBg, required this.activeFg, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final Color activeBg;
  final Color activeFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: active,
      child: Pressable(
        onTap: onTap,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: active ? 16 : 12),
          decoration: BoxDecoration(color: active ? activeBg : Colors.transparent, borderRadius: BorderRadius.circular(22)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: active ? activeFg : c.ink),
              if (active) ...[
                const SizedBox(width: 8),
                Text(label, style: AppText.sans(14, weight: FontWeight.w600, color: activeFg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
