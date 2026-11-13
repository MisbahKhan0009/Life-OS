import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'money_kit.dart';
import 'txn_list.dart';

/// All accounts, the Global deposit breakdown and net worth.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final hide = store.hideBalances;
    final accounts = store.accounts;
    final counted = accounts.where((a) => a.inGlobal).toList();
    final others = accounts.where((a) => !a.inGlobal).toList();
    final archived = store.archivedAccounts;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            MoneyPageHeader(
              title: 'Accounts',
              trailing: RoundIconButton(icon: AppIcons.add, label: 'Add account', background: p.accent, foreground: p.onAccent, onTap: () => showAccountEditor(context)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                MoneyCard(
                  color: p.cardAlt,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('GLOBAL DEPOSIT', style: AppText.label(10.5, color: p.muted)),
                        const SizedBox(height: 8),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(money(store.globalDeposit, hidden: hide), style: AppText.dot(32, color: p.ink))),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('NET WORTH', style: AppText.label(10.5, color: p.muted)),
                      const SizedBox(height: 8),
                      Text(money(store.netWorth, hidden: hide), style: AppText.sans(16, weight: FontWeight.w700, color: p.ink)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('The Global deposit adds up every account marked to count in it. Credit cards stay out unless you include them.',
                      style: AppText.sans(12.5, color: p.muted, height: 1.4)),
                ),
                if (counted.isNotEmpty) ...[
                  const MoneySectionTitle('In Global deposit'),
                  for (final a in counted) AccountRow(account: a),
                ],
                if (others.isNotEmpty) ...[
                  const MoneySectionTitle('Not counted'),
                  for (final a in others) AccountRow(account: a),
                ],
                if (archived.isNotEmpty) ...[
                  const MoneySectionTitle('Archived'),
                  for (final a in archived)
                    MoneyCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        IconTile(icon: accountIcon(a.kind), size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(a.name, style: AppText.sans(15, color: p.muted))),
                        Pressable(
                          onTap: () => store.restoreAccount(a),
                          label: 'Restore',
                          child: Text('Restore', style: AppText.sans(14, weight: FontWeight.w600, color: p.ink)),
                        ),
                      ]),
                    ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class AccountRow extends StatelessWidget {
  const AccountRow({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final bal = store.balance(account.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MoneyCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen(accountId: account.id))),
        child: Row(children: [
          IconTile(icon: accountIcon(account.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account.name, style: AppText.sans(15.5, weight: FontWeight.w600, color: p.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(account.kind.label, style: AppText.sans(12.5, color: p.muted)),
            ]),
          ),
          Text(money(bal, hidden: store.hideBalances), style: AppText.sans(15.5, weight: FontWeight.w700, color: bal < 0 ? p.expense : p.ink)),
        ]),
      ),
    );
  }
}

/// One account: balance, its transactions and edit.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final a = store.account(accountId);
    if (a == null) {
      return Scaffold(backgroundColor: p.bg, body: const SafeArea(child: MoneyPageHeader(title: 'Account')));
    }
    final txns = store.txns(accountId: a.id);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            MoneyPageHeader(
              title: a.name,
              trailing: RoundIconButton(icon: AppIcons.more, label: 'Edit account', background: p.card, foreground: p.ink, onTap: () => showAccountEditor(context, edit: a)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                MoneyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconTile(icon: accountIcon(a.kind), size: 34),
                      const SizedBox(width: 10),
                      Expanded(child: Text(a.kind.label.toUpperCase(), style: AppText.label(10.5, color: p.muted))),
                      if (a.inGlobal) Text('IN GLOBAL DEPOSIT', style: AppText.label(10, color: p.muted)),
                    ]),
                    const SizedBox(height: 16),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(money(store.balance(a.id), hidden: store.hideBalances), style: AppText.dot(40, color: p.ink))),
                    const SizedBox(height: 6),
                    Text('Started at ${money(a.opening, hidden: store.hideBalances)}', style: AppText.sans(13, color: p.muted)),
                  ]),
                ),
                const MoneySectionTitle('Activity'),
                if (txns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nothing logged here yet', style: AppText.sans(14, color: p.muted))),
                  )
                else
                  TxnGroupedList(txns: txns, perspectiveAccountId: a.id),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Create or edit an account. Returns the account when saved.
Future<Account?> showAccountEditor(BuildContext context, {Account? edit}) {
  return showMoneySheet<Account>(context, scroll: true, builder: (_) => _AccountEditor(edit: edit));
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.edit});

  final Account? edit;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _opening = TextEditingController(text: widget.edit == null || widget.edit!.opening == 0 ? '' : amountToExpr(widget.edit!.opening));
  late AccountKind _kind = widget.edit?.kind ?? AccountKind.bank;
  late bool _inGlobal = widget.edit?.inGlobal ?? AccountKind.bank.countsByDefault;
  bool _touchedGlobal = false;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final store = MoneyScope.read(context);
    final opening = parseAmount(_opening.text) ?? 0;
    final e = widget.edit;
    if (e == null) {
      final a = store.createAccount(name: _name.text, kind: _kind, opening: opening, inGlobal: _inGlobal);
      Navigator.of(context).pop(a);
    } else {
      e
        ..name = _name.text.trim().isEmpty ? e.name : _name.text.trim()
        ..kind = _kind
        ..opening = opening
        ..inGlobal = _inGlobal;
      store.updateAccount(e);
      Navigator.of(context).pop(e);
    }
  }

  Future<void> _remove() async {
    final store = MoneyScope.read(context);
    final e = widget.edit!;
    final history = store.hasTxns(e.id);
    final ok = await confirmMoney(
      context,
      title: history ? 'Archive ${e.name}?' : 'Delete ${e.name}?',
      message: history
          ? 'It has transactions, so it will be archived: hidden from lists and the Global deposit, with its history kept. You can restore it from Accounts.'
          : 'It has no transactions, so it will be removed.',
      confirm: history ? 'Archive' : 'Delete',
    );
    if (!ok || !mounted) return;
    store.removeAccount(e);
    final nav = Navigator.of(context);
    nav.pop();
    nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final editing = widget.edit != null;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(editing ? 'Edit account' : 'New account', style: AppText.sans(20, weight: FontWeight.w700, color: p.ink)),
      const FieldLabel('Name'),
      MoneyField(controller: _name, hint: 'City Bank, bKash, Wallet…', autofocus: !editing),
      const FieldLabel('Type'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in AccountKind.values)
          MoneyChip(
            label: k.label,
            icon: accountIcon(k),
            selected: k == _kind,
            onTap: () => setState(() {
              _kind = k;
              if (!_touchedGlobal && !editing) _inGlobal = k.countsByDefault;
            }),
          ),
      ]),
      FieldLabel(editing ? 'Opening balance' : 'Current balance'),
      MoneyField(controller: _opening, hint: '0', prefix: taka, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.s)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Count in Global deposit', style: AppText.sans(15, weight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 2),
              Text('Adds this balance to your total savings', style: AppText.sans(12.5, color: p.muted)),
            ]),
          ),
          CupertinoSwitch(
            value: _inGlobal,
            activeTrackColor: p.accent,
            onChanged: (v) => setState(() {
              _inGlobal = v;
              _touchedGlobal = true;
            }),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      MoneyButton(label: editing ? 'Save' : 'Add account', onTap: _save),
      if (editing) ...[
        const SizedBox(height: 8),
        MoneyButton(label: 'Archive or delete', filled: false, onTap: _remove),
      ],
    ]);
  }
}
