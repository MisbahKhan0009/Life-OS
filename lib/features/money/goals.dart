import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/money_format.dart';
import '../../data/money_models.dart';
import '../../data/money_store.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/widgets.dart';
import 'money_kit.dart';

/// Horizontal strip of goal cards plus a "new goal" tile.
class GoalStrip extends StatelessWidget {
  const GoalStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final goals = store.goals;
    return SizedBox(
      height: 150,
      child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
        for (final g in goals) Padding(padding: const EdgeInsets.only(right: 10), child: GoalCard(goal: g)),
        Pressable(
          onTap: () => showGoalEditor(context),
          label: 'New goal',
          child: Container(
            width: goals.isEmpty ? 220 : 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.l),
              border: Border.all(color: p.line, width: 1.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon: AppIcons.add, size: 34),
              const Spacer(),
              Text(goals.isEmpty ? 'Start a goal' : 'New goal', style: AppText.sans(15, weight: FontWeight.w600, color: p.ink)),
              if (goals.isEmpty) ...[
                const SizedBox(height: 2),
                Text('Emergency fund, laptop, a trip', style: AppText.sans(12.5, color: p.muted)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final hide = store.hideBalances;
    final light = ArtPresets.isLight(goal.art);
    final ink = light ? MoneyColors.navy : Colors.white;
    final soft = light ? MoneyColors.navy.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75);
    return Pressable(
      onTap: () => showGoalSheet(context, goal),
      label: goal.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.l),
        child: SizedBox(
          width: 190,
          child: Stack(fit: StackFit.expand, children: [
            ArtPresets.art(goal.art),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: ink))),
                  if (goal.reached) Icon(AppIcons.check, size: 16, color: ink),
                ]),
                const Spacer(),
                Text('${(goal.progress * 100).round()}%', style: AppText.dot(30, color: ink)),
                const SizedBox(height: 6),
                Text('${moneyShort(goal.saved, hidden: hide)} of ${moneyShort(goal.target, hidden: hide)}', style: AppText.sans(12.5, color: soft)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(children: [
                      Positioned.fill(child: ColoredBox(color: ink.withValues(alpha: 0.2))),
                      FractionallySizedBox(widthFactor: goal.progress, child: ColoredBox(color: ink)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Goal detail: add or take out money, edit, delete.
Future<void> showGoalSheet(BuildContext context, Goal goal) {
  return showMoneySheet<void>(context, scroll: true, builder: (ctx) => _GoalSheet(goalId: goal.id));
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.goalId});

  final String goalId;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _move(MoneyStore store, Goal g, int sign) {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      showToast(context, 'Enter an amount first');
      return;
    }
    store.contribute(g, v * sign);
    _amount.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = MoneyScope.of(context);
    final p = MoneyPalette.of(context);
    final g = store.goal(widget.goalId);
    if (g == null) return const SizedBox(height: 80);
    final hide = store.hideBalances;
    final monthly = g.monthlyNeeded();
    final d = g.deadline;
    final history = g.entries.reversed.take(6).toList();

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(g.name, style: AppText.sans(20, weight: FontWeight.w700, color: p.ink))),
        RoundIconButton(
          icon: AppIcons.more,
          label: 'Edit goal',
          size: 36,
          background: p.soft,
          foreground: p.ink,
          onTap: () async {
            final nav = Navigator.of(context);
            final deleted = await showGoalEditor(context, edit: g);
            if (deleted == true) nav.pop();
          },
        ),
      ]),
      const SizedBox(height: 14),
      Text(money(g.saved, hidden: hide), style: AppText.dot(40, color: p.ink)),
      const SizedBox(height: 4),
      Text('of ${money(g.target, hidden: hide)} · ${(g.progress * 100).round()}%', style: AppText.sans(13.5, color: p.muted)),
      const SizedBox(height: 12),
      MoneyBar(value: g.progress, height: 8, color: g.reached ? p.deposit : p.accent),
      const SizedBox(height: 10),
      if (g.reached)
        Text('Goal reached. Well done.', style: AppText.sans(13.5, weight: FontWeight.w600, color: p.deposit))
      else if (d != null)
        Text(
          monthly == null ? 'By ${d.day} ${monthShort(d)} ${d.year}' : 'Put aside ${money(monthly, hidden: hide)} a month to reach it by ${monthShort(d)} ${d.year}',
          style: AppText.sans(13.5, color: p.muted, height: 1.4),
        ),
      const FieldLabel('Amount'),
      MoneyField(controller: _amount, hint: '0', prefix: taka, keyboard: const TextInputType.numberWithOptions(decimal: true)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: MoneyButton(label: 'Add', icon: MoneyIcons.deposit, onTap: () => _move(store, g, 1))),
        const SizedBox(width: 8),
        Expanded(child: MoneyButton(label: 'Take out', icon: MoneyIcons.expense, filled: false, onTap: g.saved > 0 ? () => _move(store, g, -1) : null)),
      ]),
      if (history.isNotEmpty) ...[
        const FieldLabel('Recent'),
        for (final e in history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(children: [
              Expanded(child: Text('${e.date.day} ${monthShort(e.date)} ${e.date.year}', style: AppText.sans(14, color: p.muted))),
              Text(money(e.amount, sign: true, hidden: hide), style: AppText.sans(14, weight: FontWeight.w600, color: e.amount > 0 ? p.deposit : p.ink)),
            ]),
          ),
      ],
    ]);
  }
}

/// Create or edit a goal. Resolves true when the goal was deleted.
Future<bool?> showGoalEditor(BuildContext context, {Goal? edit}) {
  return showMoneySheet<bool>(context, scroll: true, builder: (_) => _GoalEditor(edit: edit));
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({this.edit});

  final Goal? edit;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _target = TextEditingController(text: widget.edit == null ? '' : amountToExpr(widget.edit!.target));
  late DateTime? _deadline = widget.edit?.deadline;
  late String _art = widget.edit?.art ?? 'navy';

  static const _arts = ['navy', 'tide', 'moss', 'ember', 'honey', 'bloom'];

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final p = MoneyPalette.of(context);
    final now = DateTime.now();
    var picked = _deadline ?? DateTime(now.year, now.month + 6, 1);
    final ok = await showMoneySheet<bool>(context, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Target date', style: AppText.sans(18, weight: FontWeight.w700, color: p.ink)),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: AppText.sans(20, color: p.ink))),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.monthYear,
              initialDateTime: picked.isBefore(now) ? now : picked,
              minimumDate: DateTime(now.year, now.month),
              maximumYear: now.year + 40,
              onDateTimeChanged: (d) => picked = d,
            ),
          ),
        ),
        const SizedBox(height: 8),
        MoneyButton(label: 'Done', onTap: () => Navigator.of(ctx).pop(true)),
      ]);
    });
    if (ok == true && mounted) setState(() => _deadline = DateTime(picked.year, picked.month, 1));
  }

  void _save() {
    final store = MoneyScope.read(context);
    final target = parseAmount(_target.text);
    if (target == null || target <= 0) {
      showToast(context, 'Enter a target amount');
      return;
    }
    final e = widget.edit;
    if (e == null) {
      store.createGoal(name: _name.text, target: target, deadline: _deadline, art: _art);
    } else {
      e
        ..name = _name.text.trim().isEmpty ? e.name : _name.text.trim()
        ..target = target
        ..deadline = _deadline
        ..art = _art;
      store.updateGoal(e);
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _delete() async {
    final e = widget.edit!;
    final ok = await confirmMoney(context, title: 'Delete ${e.name}?', message: 'The goal and its history are removed. Your accounts are not touched.', confirm: 'Delete');
    if (!ok || !mounted) return;
    MoneyScope.read(context).deleteGoal(e);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final editing = widget.edit != null;
    final d = _deadline;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(editing ? 'Edit goal' : 'New goal', style: AppText.sans(20, weight: FontWeight.w700, color: p.ink)),
      const FieldLabel('Name'),
      MoneyField(controller: _name, hint: 'Emergency fund', autofocus: !editing),
      const FieldLabel('Target'),
      MoneyField(controller: _target, hint: '0', prefix: taka, keyboard: const TextInputType.numberWithOptions(decimal: true)),
      const FieldLabel('Target date (optional)'),
      Row(children: [
        Expanded(
          child: MoneyChip(
            label: d == null ? 'No date' : '${monthShort(d)} ${d.year}',
            icon: MoneyIcons.calendar,
            selected: d != null,
            onTap: _pickDeadline,
          ),
        ),
        if (d != null) ...[
          const SizedBox(width: 8),
          MoneyChip(label: 'Clear', selected: false, onTap: () => setState(() => _deadline = null)),
        ],
      ]),
      const FieldLabel('Cover'),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final a in _arts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () => setState(() => _art = a),
                label: a,
                child: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: a == _art ? p.ink : Colors.transparent, width: 2)),
                  child: ClipOval(child: ArtPresets.art(a, grain: 0.4)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      MoneyButton(label: editing ? 'Save' : 'Create goal', onTap: _save),
      if (editing) ...[
        const SizedBox(height: 8),
        MoneyButton(label: 'Delete goal', filled: false, onTap: _delete),
      ],
    ]);
  }
}
