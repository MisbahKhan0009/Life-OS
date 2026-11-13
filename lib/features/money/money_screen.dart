import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/widgets.dart';
import '../assistant/assistant_screen.dart';
import 'accounts_screen.dart';
import 'budget_screen.dart';
import 'goals.dart';
import 'money_kit.dart';
import 'spend_chart.dart';
import 'transactions_screen.dart';
import 'txn_list.dart';
import 'txn_sheet.dart';

/// Money hub home: Global deposit, Expense and Deposit, safe to spend,
/// the spending chart, accounts, goals and recent activity.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final now = DateTime.now();
    final recent = store.txns();
    final byCat = store.spentByCategory(now);
    final spent = store.spent(now);

    return ColoredBox(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(headerDate(now), style: AppText.label(11, color: p.muted)),
                      const SizedBox(height: 4),
                      Text('Money', style: AppText.sans(34, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.9)),
                    ]),
                  ),
                  AskButton(size: 40, background: p.accent, foreground: p.onAccent),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: hide ? MoneyIcons.eyeOff : MoneyIcons.eye,
                    label: hide ? 'Show balances' : 'Hide balances',
                    background: p.card,
                    foreground: p.ink,
                    onTap: () => store.hideBalances = !hide,
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(icon: MoneyIcons.accounts, label: 'Accounts', background: p.card, foreground: p.ink, onTap: () => _push(context, const AccountsScreen())),
                ]),
              ),
              const SizedBox(height: 16),
              _GlobalDepositCard(onTap: () => _push(context, const AccountsScreen())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: MoneyButton(label: 'Expense', icon: MoneyIcons.expense, height: 56, onTap: () => showTxnSheet(context, kind: TxnKind.expense)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MoneyButton(label: 'Deposit', icon: MoneyIcons.deposit, height: 56, filled: false, onTap: () => showTxnSheet(context, kind: TxnKind.deposit)),
                ),
              ]),
              const SizedBox(height: 10),
              _BudgetCard(onTap: () => _push(context, const BudgetScreen())),

              // Spending chart
              MoneySectionTitle('${monthShort(now)} spending', action: 'All activity', onAction: () => _push(context, const TransactionsScreen())),
              MoneyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('OUT THIS MONTH', style: AppText.label(10.5, color: p.muted)),
                        const SizedBox(height: 6),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(money(spent, hidden: hide), style: AppText.dot(28, color: p.ink))),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('IN', style: AppText.label(10.5, color: p.muted)),
                      const SizedBox(height: 6),
                      Text(money(store.deposited(now), hidden: hide), style: AppText.sans(15, weight: FontWeight.w700, color: p.deposit)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  PixelSpendChart(daily: store.dailySpent(now), dailyBudget: store.dailyBudget(now), today: now.day, hidden: hide),
                ]),
              ),

              if (byCat.isNotEmpty) ...[
                const MoneySectionTitle('Where it went'),
                MoneyCard(
                  child: Column(children: [
                    for (final (cat, amount) in byCat.take(5))
                      Pressable(
                        onTap: cat == null ? null : () => _push(context, TransactionsScreen(categoryId: cat.id)),
                        scale: 0.98,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(children: [
                            IconTile(icon: categoryIcon(cat?.icon ?? 'tag'), size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  Expanded(child: Text(cat?.name ?? 'Uncategorised', style: AppText.sans(14.5, weight: FontWeight.w600, color: p.ink))),
                                  Text(money(amount, hidden: hide), style: AppText.sans(14, weight: FontWeight.w600, color: p.ink)),
                                ]),
                                const SizedBox(height: 7),
                                MoneyBar(value: spent == 0 ? 0 : amount / spent, height: 5),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ],

              // Accounts
              MoneySectionTitle('Accounts', action: 'Manage', onAction: () => _push(context, const AccountsScreen())),
              SizedBox(
                height: 104,
                child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
                  for (final a in store.accounts)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: MoneyCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => _push(context, AccountScreen(accountId: a.id)),
                        child: SizedBox(
                          width: 132,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(accountIcon(a.kind), size: 16, color: p.muted),
                              const Spacer(),
                              if (a.inGlobal) Container(width: 6, height: 6, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
                            ]),
                            const Spacer(),
                            Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, color: p.muted)),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(money(store.balance(a.id), hidden: hide), style: AppText.sans(17, weight: FontWeight.w700, color: p.ink)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  Pressable(
                    onTap: () => showAccountEditor(context),
                    label: 'Add account',
                    child: Container(
                      width: 116,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: p.line, width: 1.5)),
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(AppIcons.add, size: 18, color: p.ink),
                        const Spacer(),
                        Text('Add account', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.sans(13.5, weight: FontWeight.w600, color: p.ink)),
                      ]),
                    ),
                  ),
                ]),
              ),

              // Goals
              const MoneySectionTitle('Goals'),
              const GoalStrip(),

              // Recent
              MoneySectionTitle('Recent', action: recent.isEmpty ? null : 'See all', onAction: () => _push(context, const TransactionsScreen())),
              if (recent.isEmpty)
                MoneyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Nothing logged yet', style: AppText.sans(15, weight: FontWeight.w600, color: p.ink)),
                    const SizedBox(height: 4),
                    Text('Tap Expense or Deposit to log your first one. Add your bank, bKash or savings under Accounts so the Global deposit adds them up.',
                        style: AppText.sans(13.5, color: p.muted, height: 1.4)),
                  ]),
                )
              else
                TxnGroupedList(txns: recent, limit: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalDepositCard extends StatelessWidget {
  const _GlobalDepositCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final hide = store.hideBalances;
    final count = store.globalAccountCount;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      label: 'Global deposit, ${money(store.globalDeposit, hidden: hide)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 196,
          child: GrainArt(
            base: MoneyColors.navy,
            spots: const [
              Spot(MoneyColors.airy, Alignment(1, -1), 1.0),
              Spot(MoneyColors.steel, Alignment(-1, 1), 1.0),
              Spot(Color(0x59F2EFE7), Alignment(0.4, 0.4), 0.5),
            ],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('GLOBAL DEPOSIT', style: AppText.label(11, color: MoneyColors.sky))),
                  Icon(AppIcons.forward, size: 16, color: MoneyColors.sky),
                ]),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money(store.globalDeposit, hidden: hide), style: AppText.dot(48, color: MoneyColors.ice)),
                ),
                const SizedBox(height: 6),
                Text('All savings combined', style: AppText.sans(13, color: MoneyColors.sky)),
                const Spacer(),
                Row(children: [
                  Expanded(child: Text('$count ${count == 1 ? 'ACCOUNT' : 'ACCOUNTS'} COUNTED', style: AppText.label(10.5, color: MoneyColors.airy))),
                  Text('NET ${moneyShort(store.netWorth, hidden: hide)}', style: AppText.label(10.5, color: MoneyColors.airy)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final budget = store.monthlyBudget;
    final now = DateTime.now();
    if (budget <= 0) {
      return MoneyCard(
        onTap: onTap,
        child: Row(children: [
          IconTile(icon: MoneyIcons.budget),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Set a monthly budget', style: AppText.sans(15, weight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 2),
              Text('See what is safe to spend each day', style: AppText.sans(13, color: p.muted)),
            ]),
          ),
          Icon(AppIcons.forward, size: 16, color: p.muted),
        ]),
      );
    }
    final spent = store.spent(now);
    final safe = store.safeToSpendToday() ?? 0;
    final over = spent > budget;
    return MoneyCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SAFE TO SPEND TODAY', style: AppText.label(10.5, color: p.muted)),
              const SizedBox(height: 6),
              Text(money(safe < 0 ? 0 : safe, hidden: hide), style: AppText.dot(28, color: safe < 0 ? p.expense : p.ink)),
            ]),
          ),
          Text(
            over ? 'OVER BY ${moneyShort(spent - budget, hidden: hide)}' : '${moneyShort(budget - spent, hidden: hide)} LEFT',
            style: AppText.label(10.5, color: over ? p.expense : p.muted),
          ),
        ]),
        const SizedBox(height: 12),
        MoneyBar(value: spent / budget, color: over ? p.expense : p.accent),
      ]),
    );
  }
}
