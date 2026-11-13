import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'money_kit.dart';
import 'txn_list.dart';

/// Every transaction, month by month, with filters and search.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.categoryId});

  /// Opens already narrowed to one category.
  final String? categoryId;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxnKind? _kind;
  late String? _categoryId = widget.categoryId;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _shift(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final list = store.txns(month: _month, kind: _kind, categoryId: _categoryId, query: _query.text);
    final out = list.where((t) => t.kind == TxnKind.expense).fold(0, (s, t) => s + t.amount);
    final inn = list.where((t) => t.kind == TxnKind.deposit).fold(0, (s, t) => s + t.amount);
    final cat = store.category(_categoryId);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            const MoneyPageHeader(title: 'Transactions'),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
                Row(children: [
                  RoundIconButton(icon: AppIcons.back, label: 'Previous month', size: 36, background: p.card, foreground: p.ink, onTap: () => _shift(-1)),
                  Expanded(
                    child: Center(
                      child: Text('${monthShort(_month).toUpperCase()} ${_month.year}', style: AppText.label(13, color: p.ink, tracking: 0.2)),
                    ),
                  ),
                  RoundIconButton(
                    icon: AppIcons.forward,
                    label: 'Next month',
                    size: 36,
                    background: p.card,
                    foreground: isCurrent ? p.muted.withValues(alpha: 0.4) : p.ink,
                    onTap: isCurrent ? null : () => _shift(1),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Stat(label: 'OUT', value: money(out, hidden: hide), color: p.ink)),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: 'IN', value: money(inn, hidden: hide), color: p.deposit)),
                ]),
                const SizedBox(height: 12),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Icon(AppIcons.search, size: 18, color: p.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        cursorColor: p.ink,
                        style: AppText.sans(15, color: p.ink),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search notes, categories, accounts',
                          hintStyle: AppText.sans(15, color: p.muted),
                        ),
                      ),
                    ),
                    if (_query.text.isNotEmpty)
                      Pressable(
                        onTap: () => setState(_query.clear),
                        label: 'Clear search',
                        child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: p.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    MoneyChip(label: 'All', selected: _kind == null, onTap: () => setState(() => _kind = null)),
                    for (final k in TxnKind.values) ...[
                      const SizedBox(width: 8),
                      MoneyChip(label: k.label, icon: txnIcon(k), selected: _kind == k, onTap: () => setState(() => _kind = _kind == k ? null : k)),
                    ],
                    if (cat != null) ...[
                      const SizedBox(width: 8),
                      MoneyChip(label: '${cat.name}  ✕', icon: categoryIcon(cat.icon), selected: true, onTap: () => setState(() => _categoryId = null)),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Nothing here for this month', style: AppText.sans(14, color: p.muted))),
                  )
                else
                  TxnGroupedList(txns: list),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return MoneyCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.label(10.5, color: p.muted)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.sans(18, weight: FontWeight.w700, color: color))),
      ]),
    );
  }
}
