import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'accounts_screen.dart';
import 'money_kit.dart';

/// Opens the add (or edit) sheet for an expense, deposit or transfer.
Future<void> showTxnSheet(BuildContext context, {TxnKind kind = TxnKind.expense, Txn? edit}) async {
  final store = MoneyScope.read(context);
  if (store.accounts.isEmpty) {
    showToast(context, 'Add an account first');
    await showAccountEditor(context);
    if (!context.mounted || store.accounts.isEmpty) return;
  }
  final result = await showMoneySheet<_SheetResult>(context, builder: (_) => _TxnSheet(kind: edit?.kind ?? kind, edit: edit));
  if (!context.mounted || result == null) return;
  switch (result) {
    case _Saved(:final txn, :final isNew):
      showToast(
        context,
        '${txn.kind.label} ${isNew ? 'saved' : 'updated'} · ${money(txn.amount)}',
        actionLabel: isNew ? 'Undo' : null,
        onAction: isNew ? () => store.deleteTxn(txn) : null,
      );
    case _Deleted(:final txn):
      showToast(context, '${txn.kind.label} deleted', actionLabel: 'Undo', onAction: () => store.restoreTxn(txn));
  }
}

sealed class _SheetResult {}

class _Saved extends _SheetResult {
  _Saved(this.txn, this.isNew);
  final Txn txn;
  final bool isNew;
}

class _Deleted extends _SheetResult {
  _Deleted(this.txn);
  final Txn txn;
}

class _TxnSheet extends StatefulWidget {
  const _TxnSheet({required this.kind, this.edit});

  final TxnKind kind;
  final Txn? edit;

  @override
  State<_TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<_TxnSheet> {
  late TxnKind _kind = widget.kind;
  late String _expr = widget.edit == null ? '' : amountToExpr(widget.edit!.amount);
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  late DateTime _date = widget.edit?.date ?? DateTime.now();
  late final TextEditingController _note = TextEditingController(text: widget.edit?.note ?? '');

  @override
  void initState() {
    super.initState();
    final store = MoneyScope.read(context);
    final e = widget.edit;
    _accountId = e?.accountId ?? store.defaultAccountId;
    _toAccountId = e?.toAccountId;
    _categoryId = e?.categoryId;
    if (_toAccountId == null && _kind == TxnKind.transfer) _pickDefaultTo(store);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pickDefaultTo(MoneyStore store) {
    final others = store.accounts.where((a) => a.id != _accountId).toList();
    _toAccountId = others.isEmpty ? null : others.first.id;
  }

  int? get _amount => evalAmount(_expr);

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() => _expr = keypadPress(_expr, key));
  }

  void _setKind(TxnKind k, MoneyStore store) {
    if (k == _kind) return;
    setState(() {
      _kind = k;
      final cat = store.category(_categoryId);
      final want = k == TxnKind.deposit ? CategoryKind.income : CategoryKind.expense;
      if (cat != null && cat.kind != want) _categoryId = null;
      if (k == TxnKind.transfer && (_toAccountId == null || _toAccountId == _accountId)) _pickDefaultTo(store);
    });
  }

  String? _problem(MoneyStore store) {
    final a = _amount;
    if (a == null || a <= 0) return 'Enter an amount';
    if (store.account(_accountId) == null) return 'Pick an account';
    if (_kind == TxnKind.transfer) {
      if (_toAccountId == null) return 'Pick where it goes';
      if (_toAccountId == _accountId) return 'Pick two different accounts';
    }
    return null;
  }

  void _save(MoneyStore store) {
    final amount = _amount!;
    final e = widget.edit;
    if (e == null) {
      final t = store.addTxn(
        kind: _kind,
        amount: amount,
        accountId: _accountId!,
        toAccountId: _toAccountId,
        categoryId: _categoryId,
        note: _note.text,
        date: _date,
      );
      if (_kind != TxnKind.transfer) store.defaultAccountId = _accountId;
      Navigator.of(context).pop(_Saved(t, true));
    } else {
      e
        ..kind = _kind
        ..amount = amount
        ..accountId = _accountId!
        ..toAccountId = _toAccountId
        ..categoryId = _categoryId
        ..note = _note.text.trim()
        ..date = _date;
      store.updateTxn(e);
      Navigator.of(context).pop(_Saved(e, false));
    }
  }

  Future<void> _pickDate() async {
    final p = MoneyPalette.of(context);
    var picked = _date;
    final now = DateTime.now();
    final ok = await showMoneySheet<bool>(context, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Date', style: AppText.sans(18, weight: FontWeight.w700, color: p.ink)),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: AppText.sans(20, color: p.ink))),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _date.isAfter(now) ? now : _date,
              maximumDate: DateTime(now.year, now.month, now.day, 23, 59),
              minimumYear: 2000,
              onDateTimeChanged: (d) => picked = d,
            ),
          ),
        ),
        const SizedBox(height: 8),
        MoneyButton(label: 'Done', onTap: () => Navigator.of(ctx).pop(true)),
      ]);
    });
    if (ok == true && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  String _dateLabel() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(_date.year, _date.month, _date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${monthShort(d)}${d.year == n.year ? '' : ' ${d.year}'}';
  }

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final tone = switch (_kind) {
      TxnKind.expense => p.expense,
      TxnKind.deposit => p.deposit,
      TxnKind.transfer => p.ink,
    };
    final amount = _amount;
    final problem = _problem(store);
    final cats = _kind == TxnKind.transfer ? const <Category>[] : store.categories(_kind == TxnKind.deposit ? CategoryKind.income : CategoryKind.expense);
    final accounts = store.accounts;
    final height = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.9),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _KindSwitch(value: _kind, onChanged: (k) => _setKind(k, store))),
          if (widget.edit != null) ...[
            const SizedBox(width: 10),
            RoundIconButton(
              icon: AppIcons.trash,
              label: 'Delete',
              background: p.soft,
              foreground: p.expense,
              onTap: () async {
                final e = widget.edit!;
                final ok = await confirmMoney(context, title: 'Delete this ${e.kind.label.toLowerCase()}?', message: 'Balances update straight away.', confirm: 'Delete');
                if (!ok || !mounted) return;
                store.deleteTxn(e);
                if (context.mounted) Navigator.of(context).pop(_Deleted(e));
              },
            ),
          ],
        ]),
        Flexible(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 18),
              // Amount
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _expr.isEmpty ? '${taka}0' : (hasOperator(_expr) ? '$taka${prettyExpr(_expr)}' : money(amount ?? 0)),
                    style: AppText.dot(hasOperator(_expr) ? 38 : 54, color: _expr.isEmpty ? p.muted.withValues(alpha: 0.5) : tone),
                  ),
                ),
              ),
              SizedBox(
                height: 22,
                child: Center(
                  child: hasOperator(_expr) && amount != null
                      ? Text('= ${money(amount)}', style: AppText.label(12, color: p.muted))
                      : Text(_kind == TxnKind.transfer ? 'BETWEEN YOUR ACCOUNTS' : (_kind == TxnKind.expense ? 'MONEY OUT' : 'MONEY IN'),
                          style: AppText.label(10.5, color: p.muted)),
                ),
              ),
              if (_kind != TxnKind.transfer) ...[
                const FieldLabel('Category'),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: MoneyChip(
                          label: c.name,
                          icon: categoryIcon(c.icon),
                          selected: c.id == _categoryId,
                          onTap: () => setState(() => _categoryId = c.id == _categoryId ? null : c.id),
                        ),
                      ),
                  ]),
                ),
              ],
              FieldLabel(_kind == TxnKind.transfer ? 'From' : (_kind == TxnKind.expense ? 'Paid from' : 'Into')),
              _AccountPicker(accounts: accounts, selected: _accountId, onPick: (id) => setState(() {
                    _accountId = id;
                    if (_kind == TxnKind.transfer && _toAccountId == id) _pickDefaultTo(store);
                  })),
              if (_kind == TxnKind.transfer) ...[
                const FieldLabel('To'),
                _AccountPicker(accounts: accounts.where((a) => a.id != _accountId).toList(), selected: _toAccountId, onPick: (id) => setState(() => _toAccountId = id)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: MoneyField(controller: _note, hint: 'Note (optional)')),
                const SizedBox(width: 8),
                Pressable(
                  onTap: _pickDate,
                  label: 'Date',
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.s)),
                    child: Row(children: [
                      Icon(MoneyIcons.calendar, size: 17, color: p.ink),
                      const SizedBox(width: 6),
                      Text(_dateLabel(), style: AppText.sans(14.5, weight: FontWeight.w500, color: p.ink)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        _Keypad(onKey: _press),
        const SizedBox(height: 12),
        MoneyButton(
          label: problem ?? (widget.edit == null ? 'Save ${_kind.label.toLowerCase()}' : 'Save changes'),
          onTap: problem == null ? () => _save(store) : null,
        ),
      ]),
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.value, required this.onChanged});

  final TxnKind value;
  final ValueChanged<TxnKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(21)),
      child: Row(children: [
        for (final k in TxnKind.values)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(k),
              label: k.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(color: k == value ? p.accent : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(txnIcon(k), size: 14, color: k == value ? p.onAccent : p.ink),
                  const SizedBox(width: 5),
                  Text(k.label, style: AppText.sans(13.5, weight: FontWeight.w600, color: k == value ? p.onAccent : p.ink)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({required this.accounts, required this.selected, required this.onPick});

  final List<Account> accounts;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    if (accounts.isEmpty) {
      return MoneyChip(label: 'Add another account', icon: AppIcons.add, selected: false, onTap: () => showAccountEditor(context));
    }
    return SizedBox(
      height: 36,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MoneyChip(
              label: store.hideBalances ? a.name : '${a.name} · ${moneyShort(store.balance(a.id))}',
              icon: accountIcon(a.kind),
              selected: a.id == selected,
              onTap: () => onPick(a.id),
            ),
          ),
      ]),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['.', '0', '⌫', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Column(children: [
      for (final row in _rows)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            for (var i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Pressable(
                  onTap: () => onKey(row[i]),
                  onLongPress: row[i] == '⌫' ? () => onKey('C') : null,
                  label: row[i] == '⌫' ? 'Delete' : row[i],
                  scale: 0.94,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(color: calcOps.contains(row[i]) ? p.cardAlt : p.soft, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: row[i] == '⌫'
                        ? Icon(CupertinoIcons.delete_left, size: 20, color: p.ink)
                        : Text(row[i], style: calcOps.contains(row[i]) ? AppText.sans(22, weight: FontWeight.w500, color: p.muted) : AppText.dot(24, color: p.ink)),
                  ),
                ),
              ),
            ],
          ]),
        ),
    ]);
  }
}
