import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import 'money_kit.dart';
import 'transactions_screen.dart';

/// Monthly budget, safe to spend and per-category limits.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final now = DateTime.now();
    final budget = store.monthlyBudget;
    final spent = store.spent(now);
    final safe = store.safeToSpendToday();
    final daysLeft = DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;
    final cats = store.categories(CategoryKind.expense);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            const MoneyPageHeader(title: 'Budget'),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                MoneyCard(
                  onTap: () => editBudget(context),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${monthShort(now).toUpperCase()} BUDGET', style: AppText.label(10.5, color: p.muted))),
                      Text(budget > 0 ? 'EDIT' : 'SET', style: AppText.label(10.5, color: p.ink)),
                    ]),
                    const SizedBox(height: 10),
                    Text(budget > 0 ? money(budget, hidden: hide) : 'No budget yet', style: budget > 0 ? AppText.dot(34, color: p.ink) : AppText.sans(22, weight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 12),
                    if (budget > 0) ...[
                      MoneyBar(value: spent / budget, color: spent > budget ? p.expense : p.accent, height: 8),
                      const SizedBox(height: 10),
                      Text(
                        spent > budget
                            ? 'Over by ${money(spent - budget, hidden: hide)} · ${money(spent, hidden: hide)} spent'
                            : '${money(budget - spent, hidden: hide)} left · ${money(spent, hidden: hide)} spent',
                        style: AppText.sans(13.5, color: p.muted),
                      ),
                    ] else
                      Text('Set a monthly limit to see what is safe to spend each day.', style: AppText.sans(13.5, color: p.muted, height: 1.4)),
                  ]),
                ),
                if (safe != null) ...[
                  const SizedBox(height: 8),
                  MoneyCard(
                    color: p.cardAlt,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('SAFE TO SPEND TODAY', style: AppText.label(10.5, color: p.muted)),
                          const SizedBox(height: 8),
                          Text(money(safe < 0 ? 0 : safe, hidden: hide), style: AppText.dot(28, color: safe < 0 ? p.expense : p.ink)),
                        ]),
                      ),
                      Text('$daysLeft ${daysLeft == 1 ? 'DAY' : 'DAYS'} LEFT', style: AppText.label(10.5, color: p.muted)),
                    ]),
                  ),
                ],
                const MoneySectionTitle('Category limits'),
                for (final c in cats) _CategoryLimitRow(category: c),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryLimitRow extends StatelessWidget {
  const _CategoryLimitRow({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final spent = store.spentIn(category.id, DateTime.now());
    final limit = category.limit;
    final over = limit > 0 && spent > limit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MoneyCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        onTap: () => editCategoryLimit(context, category),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconTile(icon: categoryIcon(category.icon), size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(category.name, style: AppText.sans(15, weight: FontWeight.w600, color: p.ink))),
            Text(
              limit > 0 ? '${moneyShort(spent, hidden: hide)} / ${moneyShort(limit, hidden: hide)}' : (spent > 0 ? moneyShort(spent, hidden: hide) : 'No limit'),
              style: AppText.sans(13.5, weight: FontWeight.w600, color: over ? p.expense : p.muted),
            ),
          ]),
          if (limit > 0) ...[
            const SizedBox(height: 10),
            MoneyBar(value: spent / limit, color: over ? p.expense : p.accent),
          ],
        ]),
      ),
    );
  }
}

/// Sheet to set the overall monthly budget.
Future<void> editBudget(BuildContext context) async {
  final store = MoneyScope.read(context);
  final value = await _amountSheet(
    context,
    title: 'Monthly budget',
    hint: 'How much you plan to spend in a month',
    initial: store.monthlyBudget,
    clearLabel: store.monthlyBudget > 0 ? 'Remove budget' : null,
  );
  if (value != null) store.monthlyBudget = value;
}

/// Sheet to set one category's monthly limit, with a shortcut to its transactions.
Future<void> editCategoryLimit(BuildContext context, Category c) async {
  final store = MoneyScope.read(context);
  final value = await _amountSheet(
    context,
    title: '${c.name} limit',
    hint: 'Monthly limit for ${c.name.toLowerCase()}',
    initial: c.limit,
    clearLabel: c.limit > 0 ? 'Remove limit' : null,
    extraLabel: 'See ${c.name} transactions',
    onExtra: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionsScreen(categoryId: c.id))),
  );
  if (value != null) {
    c.limit = value;
    store.updateCategory(c);
  }
}

/// Returns the entered amount in paisa, 0 when cleared, or null when dismissed.
Future<int?> _amountSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required int initial,
  String? clearLabel,
  String? extraLabel,
  VoidCallback? onExtra,
}) {
  final ctrl = TextEditingController(text: initial > 0 ? amountToExpr(initial) : '');
  return showMoneySheet<int>(context, builder: (ctx) {
    final p = MoneyPalette.of(ctx);
    void submit() {
      final v = parseAmount(ctrl.text);
      Navigator.of(ctx).pop(v == null || v < 0 ? 0 : v);
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: AppText.sans(20, weight: FontWeight.w700, color: p.ink)),
      const SizedBox(height: 4),
      Text(hint, style: AppText.sans(13.5, color: p.muted)),
      const SizedBox(height: 14),
      MoneyField(
        controller: ctrl,
        hint: '0',
        prefix: taka,
        autofocus: true,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => submit(),
      ),
      const SizedBox(height: 16),
      MoneyButton(label: 'Save', onTap: submit),
      if (clearLabel != null) ...[
        const SizedBox(height: 8),
        MoneyButton(label: clearLabel, filled: false, onTap: () => Navigator.of(ctx).pop(0)),
      ],
      if (extraLabel != null) ...[
        const SizedBox(height: 8),
        MoneyButton(
          label: extraLabel,
          filled: false,
          onTap: () {
            Navigator.of(ctx).pop();
            onExtra?.call();
          },
        ),
      ],
    ]);
  });
}
