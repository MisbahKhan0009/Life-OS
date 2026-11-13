import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'money_models.dart';

/// Offline store for the Money hub: accounts, categories, transactions, goals
/// and money settings. Kept in memory, written through to Hive on device.
///
/// Call after Hive has been initialised (NoteStore.open does that).
class MoneyStore extends ChangeNotifier {
  MoneyStore._(this._accounts, this._categories, this._txns, this._goals, this._settings);

  final Box _accounts;
  final Box _categories;
  final Box _txns;
  final Box _goals;
  final Box _settings;

  final Map<String, Account> _accountCache = {};
  final Map<String, Category> _categoryCache = {};
  final Map<String, Txn> _txnCache = {};
  final Map<String, Goal> _goalCache = {};

  static Future<MoneyStore> open() async {
    final s = MoneyStore._(
      await Hive.openBox('money_accounts'),
      await Hive.openBox('money_categories'),
      await Hive.openBox('money_txns'),
      await Hive.openBox('money_goals'),
      await Hive.openBox('money_settings'),
    );
    s._load();
    return s;
  }

  /// Store in test boxes. Hive must already be initialised with a temp path.
  @visibleForTesting
  static Future<MoneyStore> openForTest(String path, {String suffix = 'test'}) async {
    Hive.init(path);
    final s = MoneyStore._(
      await Hive.openBox('money_accounts_$suffix'),
      await Hive.openBox('money_categories_$suffix'),
      await Hive.openBox('money_txns_$suffix'),
      await Hive.openBox('money_goals_$suffix'),
      await Hive.openBox('money_settings_$suffix'),
    );
    s._load();
    return s;
  }

  void _load() {
    for (final v in _accounts.values) {
      if (v is Map) {
        final a = Account.fromMap(v);
        _accountCache[a.id] = a;
      }
    }
    for (final v in _categories.values) {
      if (v is Map) {
        final c = Category.fromMap(v);
        _categoryCache[c.id] = c;
      }
    }
    for (final v in _txns.values) {
      if (v is Map) {
        final t = Txn.fromMap(v);
        _txnCache[t.id] = t;
      }
    }
    for (final v in _goals.values) {
      if (v is Map) {
        final g = Goal.fromMap(v);
        _goalCache[g.id] = g;
      }
    }
    if (_settings.get('seeded') != true) {
      _seed();
      _settings.put('seeded', true);
    }
  }

  // ---------- settings ----------

  bool get hideBalances => _settings.get('hide') == true;
  set hideBalances(bool v) {
    _settings.put('hide', v);
    notifyListeners();
  }

  /// Overall monthly spending budget in paisa. 0 means none set.
  int get monthlyBudget => (_settings.get('budget') as num?)?.toInt() ?? 0;
  set monthlyBudget(int v) {
    _settings.put('budget', v < 0 ? 0 : v);
    notifyListeners();
  }

  /// The account new transactions start on.
  String? get defaultAccountId {
    final id = _settings.get('defaultAccount') as String?;
    if (id != null && _accountCache[id]?.archived == false) return id;
    final list = accounts;
    return list.isEmpty ? null : list.first.id;
  }

  set defaultAccountId(String? id) {
    _settings.put('defaultAccount', id);
    notifyListeners();
  }

  // ---------- accounts ----------

  List<Account> get accounts {
    final list = _accountCache.values.where((a) => !a.archived).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<Account> get archivedAccounts => _accountCache.values.where((a) => a.archived).toList();

  Account? account(String? id) => id == null ? null : _accountCache[id];

  Account createAccount({required String name, AccountKind kind = AccountKind.cash, int opening = 0, bool? inGlobal}) {
    final a = Account(name: name.trim().isEmpty ? kind.label : name.trim(), kind: kind, opening: opening, inGlobal: inGlobal);
    _accountCache[a.id] = a;
    _accounts.put(a.id, a.toMap());
    notifyListeners();
    return a;
  }

  void updateAccount(Account a) {
    _accountCache[a.id] = a;
    _accounts.put(a.id, a.toMap());
    notifyListeners();
  }

  bool hasTxns(String accountId) => _txnCache.values.any((t) => t.accountId == accountId || t.toAccountId == accountId);

  /// Accounts with history are archived (their past stays in reports); empty ones are removed.
  void removeAccount(Account a) {
    if (hasTxns(a.id)) {
      a.archived = true;
      _accounts.put(a.id, a.toMap());
    } else {
      _accountCache.remove(a.id);
      _accounts.delete(a.id);
    }
    notifyListeners();
  }

  void restoreAccount(Account a) {
    a.archived = false;
    updateAccount(a);
  }

  /// Opening balance plus everything that moved in and out.
  int balance(String accountId) {
    final a = _accountCache[accountId];
    var b = a?.opening ?? 0;
    for (final t in _txnCache.values) {
      switch (t.kind) {
        case TxnKind.expense:
          if (t.accountId == accountId) b -= t.amount;
        case TxnKind.deposit:
          if (t.accountId == accountId) b += t.amount;
        case TxnKind.transfer:
          if (t.accountId == accountId) b -= t.amount;
          if (t.toAccountId == accountId) b += t.amount;
      }
    }
    return b;
  }

  /// All your savings combined: every active account marked "count in Global deposit".
  int get globalDeposit => accounts.where((a) => a.inGlobal).fold(0, (s, a) => s + balance(a.id));

  int get globalAccountCount => accounts.where((a) => a.inGlobal).length;

  /// Everything you own minus card debt, across active accounts.
  int get netWorth => accounts.fold(0, (s, a) => s + balance(a.id));

  // ---------- categories ----------

  List<Category> categories(CategoryKind kind) => _categoryCache.values.where((c) => c.kind == kind && !c.archived).toList();

  Category? category(String? id) => id == null ? null : _categoryCache[id];

  Category createCategory({required String name, required CategoryKind kind, String icon = 'tag'}) {
    final c = Category(name: name.trim().isEmpty ? 'New category' : name.trim(), kind: kind, icon: icon);
    _categoryCache[c.id] = c;
    _categories.put(c.id, c.toMap());
    notifyListeners();
    return c;
  }

  void updateCategory(Category c) {
    _categoryCache[c.id] = c;
    _categories.put(c.id, c.toMap());
    notifyListeners();
  }

  /// Categories in use are hidden (history keeps its label); unused ones are removed.
  void removeCategory(Category c) {
    if (_txnCache.values.any((t) => t.categoryId == c.id)) {
      c.archived = true;
      _categories.put(c.id, c.toMap());
    } else {
      _categoryCache.remove(c.id);
      _categories.delete(c.id);
    }
    notifyListeners();
  }

  // ---------- transactions ----------

  Txn? txn(String id) => _txnCache[id];

  /// Newest first, optionally narrowed by month, kind, account, category or a search.
  List<Txn> txns({DateTime? month, TxnKind? kind, String? accountId, String? categoryId, String query = ''}) {
    final q = query.trim().toLowerCase();
    final list = _txnCache.values.where((t) {
      if (month != null && (t.date.year != month.year || t.date.month != month.month)) return false;
      if (kind != null && t.kind != kind) return false;
      if (accountId != null && t.accountId != accountId && t.toAccountId != accountId) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (q.isNotEmpty) {
        final hay = '${t.note} ${category(t.categoryId)?.name ?? ''} ${account(t.accountId)?.name ?? ''} ${account(t.toAccountId)?.name ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Txn addTxn({
    required TxnKind kind,
    required int amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    String note = '',
    DateTime? date,
  }) {
    final t = Txn(
      kind: kind,
      amount: amount.abs(),
      accountId: accountId,
      toAccountId: kind == TxnKind.transfer ? toAccountId : null,
      categoryId: kind == TxnKind.transfer ? null : categoryId,
      note: note.trim(),
      date: date,
    );
    _txnCache[t.id] = t;
    _txns.put(t.id, t.toMap());
    notifyListeners();
    return t;
  }

  void updateTxn(Txn t) {
    if (t.kind == TxnKind.transfer) {
      t.categoryId = null;
    } else {
      t.toAccountId = null;
    }
    _txnCache[t.id] = t;
    _txns.put(t.id, t.toMap());
    notifyListeners();
  }

  void deleteTxn(Txn t) {
    _txnCache.remove(t.id);
    _txns.delete(t.id);
    notifyListeners();
  }

  /// Puts a deleted transaction back (for undo).
  void restoreTxn(Txn t) {
    _txnCache[t.id] = t;
    _txns.put(t.id, t.toMap());
    notifyListeners();
  }

  // ---------- month figures ----------

  int spent(DateTime month) => txns(month: month, kind: TxnKind.expense).fold(0, (s, t) => s + t.amount);

  int deposited(DateTime month) => txns(month: month, kind: TxnKind.deposit).fold(0, (s, t) => s + t.amount);

  /// Spending per day of the month, index 0 is the 1st.
  List<int> dailySpent(DateTime month) {
    final days = daysInMonth(month);
    final out = List<int>.filled(days, 0);
    for (final t in txns(month: month, kind: TxnKind.expense)) {
      out[t.date.day - 1] += t.amount;
    }
    return out;
  }

  /// Expense categories by amount spent this month, biggest first.
  List<(Category?, int)> spentByCategory(DateTime month) {
    final totals = <String?, int>{};
    for (final t in txns(month: month, kind: TxnKind.expense)) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }
    final list = [for (final e in totals.entries) (category(e.key), e.value)];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  int spentIn(String categoryId, DateTime month) =>
      txns(month: month, kind: TxnKind.expense, categoryId: categoryId).fold(0, (s, t) => s + t.amount);

  /// What you can still spend today and stay inside the monthly budget.
  /// Leftover budget is spread evenly over the days left, today included.
  /// Null when no budget is set.
  int? safeToSpendToday({DateTime? now}) {
    final budget = monthlyBudget;
    if (budget <= 0) return null;
    final n = now ?? DateTime.now();
    final daily = dailySpent(n);
    final today = daily[n.day - 1];
    final before = daily.take(n.day - 1).fold(0, (s, v) => s + v);
    final daysLeft = daily.length - n.day + 1;
    final allowance = ((budget - before) / daysLeft).floor();
    return allowance - today;
  }

  /// Even daily share of the monthly budget, for the chart's guide line.
  int dailyBudget(DateTime month) {
    final budget = monthlyBudget;
    if (budget <= 0) return 0;
    return budget ~/ daysInMonth(month);
  }

  // ---------- goals ----------

  List<Goal> get goals {
    final list = _goalCache.values.toList();
    list.sort((a, b) {
      if (a.reached != b.reached) return a.reached ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  Goal? goal(String id) => _goalCache[id];

  Goal createGoal({required String name, required int target, DateTime? deadline, String art = 'navy'}) {
    final g = Goal(name: name.trim().isEmpty ? 'New goal' : name.trim(), target: target, deadline: deadline, art: art);
    _goalCache[g.id] = g;
    _goals.put(g.id, g.toMap());
    notifyListeners();
    return g;
  }

  void updateGoal(Goal g) {
    _goalCache[g.id] = g;
    _goals.put(g.id, g.toMap());
    notifyListeners();
  }

  /// Positive amount adds to the goal, negative takes it back out (never below zero).
  void contribute(Goal g, int amount) {
    var a = amount;
    if (a < 0 && -a > g.saved) a = -g.saved;
    if (a == 0) return;
    g.entries.add(GoalEntry(amount: a));
    updateGoal(g);
  }

  void deleteGoal(Goal g) {
    _goalCache.remove(g.id);
    _goals.delete(g.id);
    notifyListeners();
  }

  // ---------- first run ----------

  void _seed() {
    final cash = Account(name: 'Cash', kind: AccountKind.cash);
    _accountCache[cash.id] = cash;
    _accounts.put(cash.id, cash.toMap());
    _settings.put('defaultAccount', cash.id);

    const expense = [
      ('Food', 'food'),
      ('Groceries', 'cart'),
      ('Transport', 'car'),
      ('Rent', 'house'),
      ('Bills', 'bolt'),
      ('Mobile & internet', 'phone'),
      ('Shopping', 'bag'),
      ('Health', 'heart'),
      ('Education', 'book'),
      ('Family', 'people'),
      ('Fun', 'film'),
      ('Gifts & charity', 'gift'),
      ('Other', 'tag'),
    ];
    const income = [
      ('Salary', 'briefcase'),
      ('Business', 'chart'),
      ('Freelance', 'laptop'),
      ('Gift', 'gift'),
      ('Profit & interest', 'percent'),
      ('Other income', 'tag'),
    ];
    for (final (name, icon) in expense) {
      final c = Category(name: name, kind: CategoryKind.expense, icon: icon);
      _categoryCache[c.id] = c;
      _categories.put(c.id, c.toMap());
    }
    for (final (name, icon) in income) {
      final c = Category(name: name, kind: CategoryKind.income, icon: icon);
      _categoryCache[c.id] = c;
      _categories.put(c.id, c.toMap());
    }
  }
}

/// Number of days in the month of [d].
int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Makes the money store available below the app root.
class MoneyScope extends InheritedNotifier<MoneyStore> {
  const MoneyScope({super.key, required MoneyStore store, required super.child}) : super(notifier: store);

  static MoneyStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MoneyScope>()!.notifier!;

  static MoneyStore read(BuildContext context) => context.getInheritedWidgetOfExactType<MoneyScope>()!.notifier!;
}
