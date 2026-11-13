import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/data/money_format.dart';
import 'package:life_os/data/money_models.dart';
import 'package:life_os/data/money_store.dart';

void main() {
  group('formatting', () {
    test('lakh grouping', () {
      expect(groupLakh(0), '0');
      expect(groupLakh(999), '999');
      expect(groupLakh(1000), '1,000');
      expect(groupLakh(100000), '1,00,000');
      expect(groupLakh(1234567), '12,34,567');
      expect(groupLakh(123456789), '12,34,56,789');
      expect(groupLakh(-1234567), '-12,34,567');
    });

    test('money shows paisa only when there are some', () {
      expect(money(125000), '৳1,250');
      expect(money(125050), '৳1,250.50');
      expect(money(-5000), '-৳50');
      expect(money(5000, sign: true), '+৳50');
      expect(money(5000, hidden: true), '৳••••');
    });

    test('short money', () {
      expect(moneyShort(95000), '৳950');
      expect(moneyShort(1250000), '৳12.5K');
      expect(moneyShort(34000000), '৳3.4L');
      expect(moneyShort(1200000000), '৳1.2Cr');
    });

    test('parse typed amounts', () {
      expect(parseAmount('1,250.5'), 125050);
      expect(parseAmount('৳300'), 30000);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  group('keypad calculator', () {
    test('evaluates with × and ÷ first', () {
      expect(evalAmount('120+45×2'), 21000);
      expect(evalAmount('100−20÷4'), 9500);
      expect(evalAmount('1250.5'), 125050);
      expect(evalAmount('300+'), 30000);
      expect(evalAmount(''), isNull);
      expect(evalAmount('5÷0'), isNull);
    });

    test('key presses build a clean expression', () {
      var e = '';
      for (final k in ['0', '0', '5', '.', '2', '5', '9', '+', '×', '3']) {
        e = keypadPress(e, k);
      }
      expect(e, '5.25×3');
      expect(keypadPress('', '+'), '');
      expect(keypadPress('12', '⌫'), '1');
      expect(keypadPress('12', 'C'), '');
      expect(keypadPress('', '.'), '0.');
      expect(hasOperator('5.25×3'), isTrue);
      expect(hasOperator('525'), isFalse);
    });

    test('round trip and pretty print', () {
      expect(amountToExpr(125050), '1250.5');
      expect(amountToExpr(125000), '1250');
      expect(prettyExpr('125000+300'), '1,25,000 + 300');
    });
  });

  group('store', () {
    late MoneyStore store;
    late Directory dir;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('life_os_money');
      store = await MoneyStore.openForTest(dir.path);
    });

    tearDownAll(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('first run has a Cash account and default categories', () {
      expect(store.accounts.single.name, 'Cash');
      expect(store.categories(CategoryKind.expense).any((c) => c.name == 'Food'), isTrue);
      expect(store.categories(CategoryKind.income).any((c) => c.name == 'Salary'), isTrue);
      expect(store.defaultAccountId, store.accounts.single.id);
    });

    test('balances, transfers and the Global deposit', () {
      final cash = store.accounts.single;
      final bank = store.createAccount(name: 'City Bank', kind: AccountKind.bank, opening: 5000000);
      final card = store.createAccount(name: 'Visa', kind: AccountKind.card);
      final dps = store.createAccount(name: 'DPS', kind: AccountKind.dps, opening: 12000000);
      expect(card.inGlobal, isFalse);

      final food = store.categories(CategoryKind.expense).firstWhere((c) => c.name == 'Food');
      final salary = store.categories(CategoryKind.income).firstWhere((c) => c.name == 'Salary');

      store.addTxn(kind: TxnKind.deposit, amount: 8000000, accountId: bank.id, categoryId: salary.id);
      store.addTxn(kind: TxnKind.transfer, amount: 1000000, accountId: bank.id, toAccountId: cash.id);
      store.addTxn(kind: TxnKind.expense, amount: 45000, accountId: cash.id, categoryId: food.id, note: 'Lunch');
      store.addTxn(kind: TxnKind.expense, amount: 200000, accountId: card.id, categoryId: food.id);

      expect(store.balance(cash.id), 1000000 - 45000);
      expect(store.balance(bank.id), 5000000 + 8000000 - 1000000);
      expect(store.balance(card.id), -200000);
      expect(store.globalDeposit, (1000000 - 45000) + 12000000 + 12000000);
      expect(store.netWorth, store.globalDeposit - 200000);
      expect(dps.inGlobal, isTrue);

      final now = DateTime.now();
      expect(store.spent(now), 245000);
      expect(store.deposited(now), 8000000);
      expect(store.txns(query: 'lunch').single.amount, 45000);
      expect(store.spentByCategory(now).first.$2, 245000);
      expect(store.dailySpent(now)[now.day - 1], 245000);
    });

    test('accounts with history are archived instead of removed', () {
      final empty = store.createAccount(name: 'Spare', kind: AccountKind.wallet);
      store.removeAccount(empty);
      expect(store.account(empty.id), isNull);

      final cash = store.accounts.firstWhere((a) => a.name == 'Cash');
      store.removeAccount(cash);
      expect(store.account(cash.id)!.archived, isTrue);
      expect(store.accounts.any((a) => a.id == cash.id), isFalse);
      store.restoreAccount(cash);
      expect(store.accounts.any((a) => a.id == cash.id), isTrue);
    });

    test('safe to spend spreads the leftover budget over the days left', () {
      store.monthlyBudget = 0;
      expect(store.safeToSpendToday(), isNull);
      store.monthlyBudget = 3000000;
      final now = DateTime.now();
      final days = store.dailySpent(now).length;
      final spentToday = store.dailySpent(now)[now.day - 1];
      final before = store.dailySpent(now).take(now.day - 1).fold(0, (s, v) => s + v);
      final expected = ((3000000 - before) / (days - now.day + 1)).floor() - spentToday;
      expect(store.safeToSpendToday(now: now), expected);
    });

    test('goals track contributions and never go below zero', () {
      final g = store.createGoal(name: 'Laptop', target: 15000000, deadline: DateTime(DateTime.now().year + 1, 1, 1));
      store.contribute(g, 5000000);
      expect(g.saved, 5000000);
      expect(g.progress, closeTo(1 / 3, 0.001));
      store.contribute(g, -9000000);
      expect(g.saved, 0);
      expect(g.monthlyNeeded(), isNotNull);
      store.contribute(g, 15000000);
      expect(g.reached, isTrue);
      expect(g.monthlyNeeded(), isNull);
    });

    test('delete and undo a transaction', () {
      final t = store.txns().first;
      store.deleteTxn(t);
      expect(store.txn(t.id), isNull);
      store.restoreTxn(t);
      expect(store.txn(t.id), isNotNull);
    });
  });
}
