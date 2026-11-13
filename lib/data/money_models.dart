import 'models.dart' show newId;

/// Amounts are stored as whole paisa (1 taka = 100 paisa) so sums never drift.

enum AccountKind { cash, bank, wallet, savings, dps, fdr, card, investment }

extension AccountKindX on AccountKind {
  String get label => switch (this) {
        AccountKind.cash => 'Cash',
        AccountKind.bank => 'Bank account',
        AccountKind.wallet => 'Mobile wallet',
        AccountKind.savings => 'Savings',
        AccountKind.dps => 'DPS',
        AccountKind.fdr => 'FDR',
        AccountKind.card => 'Credit card',
        AccountKind.investment => 'Investment',
      };

  /// Credit cards hold debt, so they stay out of the Global deposit by default.
  bool get countsByDefault => this != AccountKind.card;
}

class Account {
  Account({
    String? id,
    required this.name,
    this.kind = AccountKind.cash,
    this.opening = 0,
    bool? inGlobal,
    this.archived = false,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        inGlobal = inGlobal ?? kind.countsByDefault,
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  AccountKind kind;

  /// Balance before the first transaction logged here, in paisa.
  int opening;

  /// Counted in the Global deposit (all savings combined).
  bool inGlobal;
  bool archived;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'opening': opening,
        'inGlobal': inGlobal,
        'archived': archived,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Account.fromMap(Map m) => Account(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Account',
        kind: AccountKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => AccountKind.cash),
        opening: (m['opening'] as num?)?.toInt() ?? 0,
        inGlobal: m['inGlobal'] as bool?,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num?)?.toInt() ?? 0),
      );
}

enum CategoryKind { expense, income }

class Category {
  Category({String? id, required this.name, required this.kind, this.icon = 'tag', this.limit = 0, this.archived = false})
      : id = id ?? newId();

  final String id;
  String name;
  CategoryKind kind;

  /// Icon key, resolved to an icon in the Money UI.
  String icon;

  /// Monthly limit in paisa. 0 means no limit.
  int limit;
  bool archived;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'kind': kind.name, 'icon': icon, 'limit': limit, 'archived': archived};

  factory Category.fromMap(Map m) => Category(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Category',
        kind: m['kind'] == 'income' ? CategoryKind.income : CategoryKind.expense,
        icon: (m['icon'] as String?) ?? 'tag',
        limit: (m['limit'] as num?)?.toInt() ?? 0,
        archived: (m['archived'] as bool?) ?? false,
      );
}

/// Money only moves three ways: out (expense), in (deposit) or between your own accounts.
enum TxnKind { expense, deposit, transfer }

extension TxnKindX on TxnKind {
  String get label => switch (this) {
        TxnKind.expense => 'Expense',
        TxnKind.deposit => 'Deposit',
        TxnKind.transfer => 'Transfer',
      };
}

class Txn {
  Txn({
    String? id,
    required this.kind,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note = '',
    DateTime? date,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  TxnKind kind;

  /// Always positive, in paisa. [kind] decides the direction.
  int amount;
  String accountId;

  /// Destination for transfers.
  String? toAccountId;
  String? categoryId;
  String note;
  DateTime date;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'amount': amount,
        'accountId': accountId,
        if (toAccountId != null) 'toAccountId': toAccountId,
        if (categoryId != null) 'categoryId': categoryId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map m) => Txn(
        id: m['id'] as String,
        kind: TxnKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => TxnKind.expense),
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        accountId: (m['accountId'] as String?) ?? '',
        toAccountId: m['toAccountId'] as String?,
        categoryId: m['categoryId'] as String?,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num?)?.toInt() ?? 0),
      );
}

/// One step towards (or back from) a goal.
class GoalEntry {
  GoalEntry({required this.amount, DateTime? date}) : date = date ?? DateTime.now();

  /// Positive adds to the goal, negative takes money back out.
  final int amount;
  final DateTime date;

  Map<String, dynamic> toMap() => {'amount': amount, 'date': date.millisecondsSinceEpoch};

  factory GoalEntry.fromMap(Map m) =>
      GoalEntry(amount: (m['amount'] as num?)?.toInt() ?? 0, date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0));
}

class Goal {
  Goal({String? id, required this.name, required this.target, this.deadline, this.art = 'navy', List<GoalEntry>? entries, DateTime? createdAt})
      : id = id ?? newId(),
        entries = entries ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;

  /// Target in paisa.
  int target;
  DateTime? deadline;
  String art;
  final List<GoalEntry> entries;
  final DateTime createdAt;

  int get saved => entries.fold(0, (s, e) => s + e.amount);
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  bool get reached => target > 0 && saved >= target;

  /// What to put aside each month to reach the target by the deadline.
  int? monthlyNeeded({DateTime? now}) {
    final d = deadline;
    if (d == null || reached) return null;
    final n = now ?? DateTime.now();
    final months = (d.year - n.year) * 12 + d.month - n.month;
    final left = target - saved;
    if (months <= 0) return left;
    return (left / months).ceil();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target': target,
        if (deadline != null) 'deadline': deadline!.millisecondsSinceEpoch,
        'art': art,
        'entries': entries.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map m) => Goal(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Goal',
        target: (m['target'] as num?)?.toInt() ?? 0,
        deadline: m['deadline'] == null ? null : DateTime.fromMillisecondsSinceEpoch((m['deadline'] as num).toInt()),
        art: (m['art'] as String?) ?? 'navy',
        entries: [for (final e in (m['entries'] as List? ?? const [])) if (e is Map) GoalEntry.fromMap(e)],
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num?)?.toInt() ?? 0),
      );
}
