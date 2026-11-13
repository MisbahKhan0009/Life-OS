import 'package:flutter/material.dart';

import '../data/store.dart';
import '../features/editor/editor_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/focus/focus_sheets.dart';
import '../features/folders/folders_screen.dart';
import '../features/home/home_screen.dart';
import '../data/money_models.dart';
import '../data/share_inbox.dart';
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

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int get _tab => shellTab.value;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _importShares());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _importShares();
  }

  /// Notes saved from the share menu while the app was in the background.
  void _importShares() {
    final inbox = shareInbox;
    if (inbox == null || !mounted) return;
    final n = inbox.importInto(StoreScope.read(context));
    if (n > 0) showToast(context, n == 1 ? 'Saved 1 note from share' : 'Saved $n notes from share');
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    WidgetsBinding.instance.removeObserver(this);
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
    // Sideways on Focus is StandBy, which fills the screen.
    final standby = focusTab && MediaQuery.of(context).orientation == Orientation.landscape;
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
          if (!standby)
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
                      addLabel: moneyTab ? 'Add transaction' : (focusTab ? 'Quick note' : 'New note'),
                      addIcon: focusTab ? AppIcons.edit : AppIcons.add,
                      onAdd: focusTab
                          ? () => showQuickNoteSheet(context)
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
  const _NavBar({required this.index, required this.onSelect, required this.money, this.onAdd, this.addLabel = 'New note', this.addIcon = AppIcons.add});

  final int index;
  final bool money;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;
  final String addLabel;
  final IconData addIcon;

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (w, a) => RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: w)),
                child: Icon(addIcon, key: ValueKey(addIcon), color: c.isDark ? Colors.white : activeFg, size: 24),
              ),
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
