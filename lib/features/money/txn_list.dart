import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../theme/tokens.dart';
import 'money_kit.dart';
import 'txn_sheet.dart';

String dayHeading(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  final base = '${weekdayShort(d).toUpperCase()} · ${d.day} ${monthShort(d).toUpperCase()}';
  return d.year == n.year ? base : '$base ${d.year}';
}

/// One transaction row. Tap to edit.
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.perspectiveAccountId});

  final Txn txn;

  /// When shown inside an account, transfers read as in or out of that account.
  final String? perspectiveAccountId;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final t = txn;
    final cat = store.category(t.categoryId);
    final from = store.account(t.accountId);
    final to = store.account(t.toAccountId);

    final (String title, String sub, IconData icon) = t.kind == TxnKind.transfer
        ? (
            t.note.isNotEmpty ? t.note : 'Transfer',
            '${from?.name ?? 'Account'} → ${to?.name ?? 'Account'}',
            MoneyIcons.transfer,
          )
        : (
            t.note.isNotEmpty ? t.note : (cat?.name ?? t.kind.label),
            [if (t.note.isNotEmpty && cat != null) cat.name, from?.name ?? 'Account'].join(' · '),
            cat == null ? txnIcon(t.kind) : categoryIcon(cat.icon),
          );

    int signed;
    if (t.kind == TxnKind.expense) {
      signed = -t.amount;
    } else if (t.kind == TxnKind.deposit) {
      signed = t.amount;
    } else if (perspectiveAccountId != null) {
      signed = t.toAccountId == perspectiveAccountId ? t.amount : -t.amount;
    } else {
      signed = 0;
    }
    final amountText = signed == 0 ? money(t.amount, hidden: store.hideBalances) : money(signed, sign: true, hidden: store.hideBalances);
    final amountColor = signed > 0 ? p.deposit : (signed < 0 && t.kind == TxnKind.expense ? p.ink : p.muted);

    return Semantics(
      label: '${t.kind.label}, $title, $amountText',
      child: MoneyCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: () => showTxnSheet(context, edit: t),
        child: Row(children: [
          IconTile(icon: icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12.5, color: p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(amountText, style: AppText.sans(15, weight: FontWeight.w700, color: amountColor)),
        ]),
      ),
    );
  }
}

/// Transactions grouped under day headings with each day's spending.
class TxnGroupedList extends StatelessWidget {
  const TxnGroupedList({super.key, required this.txns, this.perspectiveAccountId, this.limit});

  final List<Txn> txns;
  final String? perspectiveAccountId;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final store = MoneyScope.of(context);
    final list = limit == null ? txns : txns.take(limit!).toList();
    final children = <Widget>[];
    DateTime? current;
    for (var i = 0; i < list.length; i++) {
      final t = list[i];
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (current == null || day != current) {
        current = day;
        final dayOut = list
            .where((e) => e.kind == TxnKind.expense && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
            .fold(0, (s, e) => s + e.amount);
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 0 : 14, 4, 8),
          child: Row(children: [
            Expanded(child: Text(dayHeading(day), style: AppText.label(10.5, color: p.muted))),
            if (dayOut > 0) Text('−${moneyShort(dayOut, hidden: store.hideBalances)}', style: AppText.label(10.5, color: p.muted)),
          ]),
        ));
      }
      children.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: TxnTile(txn: t, perspectiveAccountId: perspectiveAccountId)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
