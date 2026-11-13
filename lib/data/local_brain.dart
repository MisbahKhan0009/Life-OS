import 'focus_models.dart';
import 'focus_store.dart';
import 'format.dart';
import 'models.dart';
import 'money_format.dart';
import 'money_models.dart';
import 'money_store.dart';
import 'store.dart';

/// An answer worked out on the phone, with no AI model and no internet.
class LocalAnswer {
  LocalAnswer(this.text, {List<Map<String, dynamic>>? cards, this.google, this.understood = true, List<String>? looked})
      : cards = cards ?? [],
        looked = looked ?? [];

  /// Markdown-light text.
  final String text;

  /// Things to show under the text: {type: note|txn|stat, ...}.
  final List<Map<String, dynamic>> cards;

  /// When set, offer a Google search for this.
  final String? google;

  /// False when the question wasn't about anything in the app.
  final bool understood;

  /// What it looked at, shown as small chips.
  final List<String> looked;
}

/// A date range with a name ("this month").
class Period {
  Period(this.from, this.to, this.label);
  final DateTime from;
  final DateTime to;
  final String label;

  bool contains(DateTime d) => !d.isBefore(from) && d.isBefore(to);
}

const _months = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];

/// Finds a time range in a question. Null when none is mentioned.
Period? parsePeriod(String q, DateTime now) {
  final t = q.toLowerCase();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
  final monday = day(-(today.weekday - 1));

  final nDays = RegExp(r'\b(?:last|past)\s+(\d{1,3})\s+days?\b').firstMatch(t);
  if (nDays != null) {
    final n = int.parse(nDays.group(1)!);
    return Period(day(-n + 1), day(1), 'the last $n days');
  }
  if (RegExp(r'\btoday\b|\btonight\b').hasMatch(t)) return Period(today, day(1), 'today');
  if (RegExp(r'\byesterday\b').hasMatch(t)) return Period(day(-1), today, 'yesterday');
  if (RegExp(r'\blast week\b').hasMatch(t)) return Period(DateTime(monday.year, monday.month, monday.day - 7), monday, 'last week');
  if (RegExp(r'\b(this|current) week\b|\bweek\b').hasMatch(t)) return Period(monday, DateTime(monday.year, monday.month, monday.day + 7), 'this week');
  if (RegExp(r'\blast month\b').hasMatch(t)) {
    final m = DateTime(now.year, now.month - 1);
    return Period(m, DateTime(now.year, now.month), 'last month (${_monthName(m)})');
  }
  if (RegExp(r'\blast year\b').hasMatch(t)) return Period(DateTime(now.year - 1), DateTime(now.year), '${now.year - 1}');
  if (RegExp(r'\b(this|current) year\b|\byear\b').hasMatch(t)) return Period(DateTime(now.year), DateTime(now.year + 1), 'this year');
  for (var i = 0; i < 12; i++) {
    final name = _months[i];
    final m = RegExp('\\b(${name.substring(0, 3)}|$name)\\b(?:\\s+(\\d{4}))?').firstMatch(t);
    if (m != null && !(name == 'may' && !RegExp(r'\bin may\b|\bmay \d{4}\b|\bof may\b').hasMatch(t))) {
      var year = int.tryParse(m.group(2) ?? '') ?? now.year;
      if (m.group(2) == null && i + 1 > now.month) year -= 1; // "in December" in November means last year
      return Period(DateTime(year, i + 1), DateTime(year, i + 2), '${_cap(name)}${year == now.year ? '' : ' $year'}');
    }
  }
  if (RegExp(r'\b(this|current) month\b|\bmonth\b').hasMatch(t)) return Period(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'this month');
  return null;
}

String _monthName(DateTime d) => _cap(_months[d.month - 1]);
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _stop = {
  'a', 'an', 'the', 'i', 'me', 'my', 'mine', 'we', 'our', 'you', 'your', 'is', 'are', 'was', 'were', 'be', 'been', 'am', 'do', 'did',
  'does', 'have', 'has', 'had', 'what', 'whats', "what's", 'which', 'who', 'where', 'when', 'how', 'why', 'much', 'many', 'any', 'some',
  'all', 'of', 'on', 'in', 'at', 'to', 'for', 'from', 'about', 'with', 'and', 'or', 'it', 'this', 'that', 'these', 'those', 'there', 'can',
  'could', 'would', 'should', 'will', 'please', 'tell', 'show', 'give', 'find', 'search', 'look', 'up', 'get', 'list', 'note', 'notes',
  'wrote', 'write', 'written', 'so', 'far', 'last', 'past', 'month', 'week', 'year', 'today', 'yesterday', 'days', 'day', 'time', 'most',
  'least', 'than', 'more', 'less', 'by', 'into', 'out', 'anything', 'something', 'thing', 'things', 'again', 'just', 'now', 'right',
  'current', 'total',
};

/// Words that carry meaning in a question.
List<String> keywords(String q) => q
    .toLowerCase()
    .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.length > 1 && !_stop.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
    .toList();

/// Notes ranked by how many words they contain (title matches count more).
List<Note> rankNotes(NoteStore notes, List<String> words, {String? folderId, int limit = 8}) {
  final all = notes.notes(folderId: folderId);
  if (words.isEmpty) return all.take(limit).toList();
  final scored = <(Note, int)>[];
  for (final x in all) {
    final title = x.displayTitle.toLowerCase();
    final text = x.searchText;
    var score = 0;
    var hits = 0;
    for (final w in words) {
      final inTitle = title.contains(w);
      final inText = text.contains(w);
      if (inTitle) score += 3;
      if (inText) score += 1;
      if (inTitle || inText) hits++;
    }
    if (score > 0 && hits * 2 >= words.length) scored.add((x, score + hits * 2));
  }
  scored.sort((p, q) => q.$2 != p.$2 ? q.$2.compareTo(p.$2) : q.$1.updatedAt.compareTo(p.$1.updatedAt));
  return [for (final e in scored.take(limit)) e.$1];
}

const _categoryWords = {
  'food': ['food', 'eat', 'eating', 'ate', 'restaurant', 'lunch', 'dinner', 'breakfast', 'snack', 'snacks', 'khabar', 'coffee', 'tea'],
  'groceries': ['grocery', 'groceries', 'bazar', 'bazaar', 'market', 'vegetables'],
  'transport': ['transport', 'uber', 'pathao', 'rickshaw', 'bus', 'cng', 'fuel', 'taxi', 'travel', 'ride', 'rides', 'metro', 'train'],
  'rent': ['rent', 'house rent'],
  'bills': ['bill', 'bills', 'electricity', 'gas', 'water', 'utility', 'utilities'],
  'mobile & internet': ['mobile', 'internet', 'recharge', 'data', 'wifi', 'phone bill'],
  'shopping': ['shopping', 'shop', 'clothes', 'bought', 'buy'],
  'health': ['health', 'medicine', 'doctor', 'pharmacy', 'medical', 'hospital'],
  'education': ['education', 'course', 'courses', 'books', 'tuition', 'school', 'university', 'class'],
  'family': ['family', 'parents', 'mother', 'father'],
  'fun': ['fun', 'movie', 'movies', 'entertainment', 'games', 'netflix', 'outing'],
  'gifts & charity': ['gift', 'gifts', 'charity', 'donation', 'zakat', 'sadaqah'],
};

/// Answers questions about your own notes, money and focus without any AI.
class LocalBrain {
  LocalBrain(this.notes, this.money, this.focus, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final NoteStore notes;
  final MoneyStore money;
  final FocusStore focus;
  final DateTime Function() _clock;

  LocalAnswer answer(String question) {
    final q = question.trim();
    final t = q.toLowerCase();
    final now = _clock();
    if (t.isEmpty) return LocalAnswer('Ask me something.', understood: false);

    if (RegExp(r'^(hi|hello|hey|salam|assalamu|good (morning|evening|afternoon))\b').hasMatch(t)) {
      return LocalAnswer('Hi! Ask me about your notes, money or focus. For anything else I can search Google for you.');
    }
    if (RegExp(r'what can you do|help me use|^help$|how do you work').hasMatch(t)) return _help();

    final create = RegExp(r'^(?:please\s+)?(?:make|create|add|new|write|start|save)\s+(?:me\s+)?(?:a\s+)?(?:new\s+|quick\s+)?note\b[\s:,\-]*(?:about|called|titled|named|for|on|that says|saying)?\s*(.*)$', caseSensitive: false, dotAll: true)
            .firstMatch(q) ??
        RegExp(r'^(?:note that|remember that|remember to|jot down|note down)\s+(.*)$', caseSensitive: false, dotAll: true).firstMatch(q);
    if (create != null) return _createNote(create.group(1) ?? '');

    final period = parsePeriod(t, now);

    if (RegExp(r'\bstreak\b').hasMatch(t) && !RegExp(r'\b(spend|spent|money)\b').hasMatch(t)) return _focus(t, period, now, streakOnly: true);
    if (RegExp(r'\b(focus|focused|pomodoro|pomodoros|sessions?|rounds?|studied|study|concentrat)').hasMatch(t)) return _focus(t, period, now);

    if (RegExp(r'\bgoals?\b|\bsaving for\b').hasMatch(t)) return _goals();
    if (RegExp(r'\bbudget\b|safe to spend|can i (still )?spend|left to spend|how much (is )?left').hasMatch(t)) return _budget(now);
    if (RegExp(r'global deposit|net worth|total sav|my savings|how much money (do )?i have|\bbalances?\b|\bin (my )?(bank|cash|wallet|bkash|nagad|rocket)\b|accounts?\b').hasMatch(t)) {
      return _balances(t);
    }
    if (RegExp(r'\b(biggest|largest|highest|most expensive|top) (expense|spend|purchase|transaction)s?').hasMatch(t)) return _biggest(period, now);
    if (RegExp(r'\b(deposit|deposited|income|earn|earned|salary|received|got paid|came in)\b').hasMatch(t)) return _money(t, period, now, TxnKind.deposit);
    if (RegExp(r'\b(spend|spent|spending|expense|expenses|cost|costs|paid|pay for|bought|purchases?|transactions?)\b').hasMatch(t)) {
      return _money(t, period, now, RegExp(r'\btransactions?\b').hasMatch(t) ? null : TxnKind.expense);
    }

    if (RegExp(r'\bfolders?\b').hasMatch(t) && keywords(t).where((w) => w != 'folders' && w != 'folder').isEmpty) return _folders();

    return _searchNotes(q);
  }

  // ---------- notes ----------

  LocalAnswer _searchNotes(String q) {
    var words = keywords(q);
    String? folderId;
    for (final f in notes.folders) {
      if (q.toLowerCase().contains('in ${f.name.toLowerCase()}') || q.toLowerCase().contains('${f.name.toLowerCase()} folder')) {
        folderId = f.id;
        words = words.where((w) => !f.name.toLowerCase().split(' ').contains(w) && w != 'folder').toList();
      }
    }
    if (words.isEmpty && folderId == null) {
      return LocalAnswer('I could not tell what to look for. Try something like "find my notes about the trip".', understood: false, google: q);
    }
    final found = rankNotes(notes, words, folderId: folderId, limit: 6);
    final looked = ['Searched notes · ${words.join(' ')}'];
    if (found.isEmpty) {
      return LocalAnswer(
        'Nothing in your notes mentions **${words.join(' ')}**. Want me to search Google for it?',
        understood: false,
        google: q,
        looked: looked,
      );
    }
    final best = found.first;
    final text = found.length == 1
        ? 'Found it: **${best.displayTitle}**.'
        : 'Found **${found.length} notes**. The best match is **${best.displayTitle}**.';
    return LocalAnswer(text, cards: [for (final n in found) _noteCard(n, words)], looked: looked);
  }

  Map<String, dynamic> _noteCard(Note n, List<String> words) {
    // Show the line that mentions a search word, if there is one.
    var snippet = n.preview;
    for (final b in n.blocks) {
      final low = b.text.toLowerCase();
      if (words.any(low.contains)) {
        snippet = b.text;
        break;
      }
    }
    return {
      'type': 'note',
      'id': n.id,
      'title': n.displayTitle,
      'snippet': snippet.length > 140 ? '${snippet.substring(0, 140)}…' : snippet,
      'meta': [notes.folder(n.folderId)?.name, relativeDay(n.updatedAt)].whereType<String>().join(' · '),
    };
  }

  LocalAnswer _createNote(String body) {
    var content = body.trim();
    if (content.isEmpty) return LocalAnswer('What should the note say? Try "make a note: call the bank tomorrow".');
    String title;
    String rest;
    final colon = content.indexOf(':');
    if (colon > 0 && colon < 60) {
      title = content.substring(0, colon).trim();
      rest = content.substring(colon + 1).trim();
    } else if (content.contains(',')) {
      // "weekend trip, charger, passport" -> title "Weekend trip" with a checklist.
      final comma = content.indexOf(',');
      title = content.substring(0, comma).trim();
      rest = content.substring(comma + 1).trim();
    } else {
      title = content.length <= 60 ? content : '${content.substring(0, 57)}…';
      rest = content.length <= 60 ? '' : content;
    }
    title = _cap(title);
    final blocks = <Block>[];
    if (rest.isNotEmpty) {
      final items = rest.split(RegExp(r',|\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (items.length > 1 || content.contains(',')) {
        for (final i in items) {
          blocks.add(Block(type: BlockType.checklist, text: _cap(i)));
        }
      } else {
        blocks.add(Block(text: rest));
      }
    }
    final n = notes.createNote(title: title, blocks: blocks.isEmpty ? null : blocks);
    return LocalAnswer('Done. I made a note called **${n.displayTitle}**.', cards: [_noteCard(n, const [])], looked: ['Created a note']);
  }

  LocalAnswer _folders() {
    final fs = notes.folders;
    if (fs.isEmpty) return LocalAnswer('You have no folders yet.');
    return LocalAnswer(
      'You have **${fs.length} folders**:\n${[for (final f in fs) '- ${f.name}: ${notes.countIn(f.id)} notes'].join('\n')}',
      looked: ['Folders'],
    );
  }

  // ---------- money ----------

  Category? _category(String t, CategoryKind kind) {
    final cats = money.categories(kind);
    for (final c in cats) {
      if (RegExp('\\b${RegExp.escape(c.name.toLowerCase())}\\b').hasMatch(t)) return c;
    }
    for (final e in _categoryWords.entries) {
      if (e.value.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(t))) {
        final c = cats.where((c) => c.name.toLowerCase() == e.key).firstOrNull;
        if (c != null) return c;
      }
    }
    return null;
  }

  List<Txn> _inPeriod(Period p, {TxnKind? kind, String? categoryId}) =>
      money.txns(kind: kind, categoryId: categoryId).where((x) => p.contains(x.date)).toList();

  LocalAnswer _money(String t, Period? period, DateTime now, TxnKind? kind) {
    final p = period ?? Period(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'this month');
    final cat = _category(t, kind == TxnKind.deposit ? CategoryKind.income : CategoryKind.expense);
    var list = _inPeriod(p, kind: kind, categoryId: cat?.id);
    String? about = cat?.name;

    // No category matched: look for the words in transaction notes ("kacchi", "Daraz").
    if (cat == null) {
      final words = keywords(t).where((w) => !const {'spend', 'spent', 'spending', 'expense', 'expenses', 'cost', 'costs', 'paid', 'pay', 'bought', 'purchase', 'purchases', 'transactions', 'transaction', 'money', 'taka', 'deposit', 'deposited', 'income', 'earn', 'earned', 'received', 'salary'}.contains(w)).toList();
      if (words.isNotEmpty) {
        final byNote = list.where((x) => words.any((w) => x.note.toLowerCase().contains(w) || (money.account(x.accountId)?.name.toLowerCase().contains(w) ?? false))).toList();
        if (byNote.isNotEmpty) {
          list = byNote;
          about = words.join(' ');
        }
      }
    }

    final looked = ['${kind == TxnKind.deposit ? 'Deposits' : (kind == null ? 'Transactions' : 'Expenses')} · ${p.label}${about != null ? ' · $about' : ''}'];
    final hide = money.hideBalances;
    final total = list.where((x) => x.kind != TxnKind.transfer).fold(0, (s, x) => s + x.amount);
    final verb = kind == TxnKind.deposit ? 'deposited' : 'spent';
    if (list.isEmpty) {
      return LocalAnswer(
        'Nothing ${kind == TxnKind.deposit ? 'deposited' : 'logged'}${about != null ? ' for **$about**' : ''} ${p.label}.',
        looked: looked,
      );
    }
    final buf = StringBuffer(
        kind == null ? '**${list.length} transactions** ${p.label}.' : 'You $verb **${fmtMoney(total, hide)}**${about != null ? ' on **$about**' : ''} ${p.label}, across ${list.length} ${list.length == 1 ? 'entry' : 'entries'}.');
    if (kind == TxnKind.expense && cat == null && about == null) {
      final byCat = <String, int>{};
      for (final x in list) {
        final name = money.category(x.categoryId)?.name ?? 'Uncategorised';
        byCat[name] = (byCat[name] ?? 0) + x.amount;
      }
      final top = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      buf.write('\n\nWhere it went:');
      for (final e in top.take(4)) {
        buf.write('\n- ${e.key}: ${fmtMoney(e.value, hide)}');
      }
    }
    if (kind == TxnKind.expense && cat != null && cat.limit > 0 && p.label == 'this month') {
      final left = cat.limit - total;
      buf.write(left >= 0 ? '\n\n${fmtMoney(left, hide)} left of your ${cat.name} limit.' : '\n\nThat is ${fmtMoney(-left, hide)} over your ${cat.name} limit.');
    }
    return LocalAnswer(buf.toString(), cards: [for (final x in list.take(6)) _txnCard(x)], looked: looked);
  }

  LocalAnswer _biggest(Period? period, DateTime now) {
    final p = period ?? Period(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'this month');
    final list = _inPeriod(p, kind: TxnKind.expense)..sort((a, b) => b.amount.compareTo(a.amount));
    if (list.isEmpty) return LocalAnswer('No expenses ${p.label}.', looked: ['Expenses · ${p.label}']);
    final top = list.first;
    final what = top.note.isNotEmpty ? top.note : (money.category(top.categoryId)?.name ?? 'an expense');
    return LocalAnswer(
      'Your biggest expense ${p.label} was **${fmtMoney(top.amount, money.hideBalances)}** for **$what** on ${top.date.day} ${monthShort(top.date)}.',
      cards: [for (final x in list.take(5)) _txnCard(x)],
      looked: ['Expenses · ${p.label}'],
    );
  }

  LocalAnswer _balances(String t) {
    final hide = money.hideBalances;
    for (final a in money.accounts) {
      if (t.contains(a.name.toLowerCase())) {
        return LocalAnswer('**${a.name}** has **${fmtMoney(money.balance(a.id), hide)}**.', looked: ['Accounts']);
      }
    }
    final cards = [
      {'type': 'stat', 'label': 'Global deposit', 'value': fmtMoney(money.globalDeposit, hide)},
      {'type': 'stat', 'label': 'Net worth', 'value': fmtMoney(money.netWorth, hide)},
      for (final a in money.accounts) {'type': 'stat', 'label': a.name, 'value': fmtMoney(money.balance(a.id), hide)},
    ];
    return LocalAnswer(
      'Your **Global deposit** (all savings combined) is **${fmtMoney(money.globalDeposit, hide)}** across ${money.globalAccountCount} ${money.globalAccountCount == 1 ? 'account' : 'accounts'}. Net worth is ${fmtMoney(money.netWorth, hide)}.',
      cards: cards,
      looked: ['Accounts'],
    );
  }

  LocalAnswer _budget(DateTime now) {
    final hide = money.hideBalances;
    final budget = money.monthlyBudget;
    if (budget <= 0) return LocalAnswer('You have not set a monthly budget yet. Set one on the Money tab and I can tell you what is safe to spend each day.', looked: ['Budget']);
    final spent = money.spent(now);
    final safe = money.safeToSpendToday() ?? 0;
    final days = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final text = spent > budget
        ? 'You are **${fmtMoney(spent - budget, hide)} over** this month\'s budget of ${fmtMoney(budget, hide)}.'
        : 'You can spend **${fmtMoney(safe < 0 ? 0 : safe, hide)}** today and stay on budget. ${fmtMoney(budget - spent, hide)} is left for the next $days ${days == 1 ? 'day' : 'days'}.';
    return LocalAnswer(text, cards: [
      {'type': 'stat', 'label': 'Budget', 'value': fmtMoney(budget, hide)},
      {'type': 'stat', 'label': 'Spent', 'value': fmtMoney(spent, hide)},
      {'type': 'stat', 'label': 'Safe today', 'value': fmtMoney(safe < 0 ? 0 : safe, hide)},
    ], looked: ['Budget']);
  }

  LocalAnswer _goals() {
    final gs = money.goals;
    final hide = money.hideBalances;
    if (gs.isEmpty) return LocalAnswer('You have no savings goals yet. Add one on the Money tab.', looked: ['Goals']);
    final open = gs.where((g) => !g.reached).toList()..sort((a, b) => b.progress.compareTo(a.progress));
    final lines = [
      for (final g in gs)
        '- **${g.name}**: ${fmtMoney(g.saved, hide)} of ${fmtMoney(g.target, hide)} (${(g.progress * 100).round()}%)${g.monthlyNeeded() != null ? ', ${fmtMoney(g.monthlyNeeded()!, hide)} a month to hit the date' : ''}${g.reached ? ', reached' : ''}',
    ];
    final lead = open.isEmpty ? 'Every goal is reached. Nice.' : '**${open.first.name}** is closest, at ${(open.first.progress * 100).round()}%.';
    return LocalAnswer('$lead\n\n${lines.join('\n')}', looked: ['Goals']);
  }

  Map<String, dynamic> _txnCard(Txn x) {
    final cat = money.category(x.categoryId);
    final label = x.kind == TxnKind.transfer
        ? '${money.account(x.accountId)?.name ?? 'Account'} → ${money.account(x.toAccountId)?.name ?? 'Account'}'
        : (x.note.isNotEmpty ? x.note : (cat?.name ?? x.kind.label));
    return {
      'type': 'txn',
      'label': label,
      'meta': '${x.date.day} ${monthShort(x.date)} · ${cat?.name ?? x.kind.label} · ${money.account(x.accountId)?.name ?? ''}',
      'amount': x.kind == TxnKind.expense ? '−${fmtMoney(x.amount, money.hideBalances)}' : (x.kind == TxnKind.deposit ? '+${fmtMoney(x.amount, money.hideBalances)}' : fmtMoney(x.amount, money.hideBalances)),
      'kind': x.kind.name,
    };
  }

  // ---------- focus ----------

  LocalAnswer _focus(String t, Period? period, DateTime now, {bool streakOnly = false}) {
    final streak = focus.streak(now);
    if (streakOnly) {
      return LocalAnswer(
        streak == 0 ? 'No streak right now. One focus round today starts a new one.' : 'You are on a **$streak-day** focus streak. Your best is ${focus.bestStreak} days.',
        looked: ['Focus streak'],
      );
    }
    final p = period ?? Period(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1), 'today');
    final list = focus.sessions(from: p.from, to: p.to);
    final secs = list.fold(0, (s, x) => s + x.seconds);
    final rounds = list.where((x) => x.counts).length;
    final looked = ['Focus · ${p.label}'];
    if (list.isEmpty) {
      return LocalAnswer('No focus sessions ${p.label}.${streak > 0 ? ' Your streak is $streak days.' : ''}', looked: looked);
    }
    final rated = list.where((x) => x.rating > 0).toList();
    final avgRating = rated.isEmpty ? null : rated.fold(0, (s, x) => s + x.rating) / rated.length;
    final byNote = <String, int>{};
    for (final x in list) {
      if (x.noteId != null) byNote[x.noteId!] = (byNote[x.noteId!] ?? 0) + x.seconds;
    }
    final topNote = byNote.entries.isEmpty ? null : (byNote.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    final buf = StringBuffer('You focused **${focusDuration(secs)}** ${p.label} over ${list.length} ${list.length == 1 ? 'session' : 'sessions'} ($rounds full ${rounds == 1 ? 'round' : 'rounds'}).');
    if (p.label == 'today') {
      final goal = focus.dailyGoal;
      buf.write(secs >= goal * 60 ? ' Daily goal reached.' : ' ${focusDuration(goal * 60 - secs)} to your daily goal.');
    }
    if (topNote != null) buf.write('\n\nMost time went to **${notes.note(topNote.key)?.displayTitle ?? 'a deleted note'}** (${focusDuration(topNote.value)}).');
    if (avgRating != null) buf.write('\nAverage focus rating ${avgRating.toStringAsFixed(1)} / 5.');
    if (streak > 0) buf.write('\nStreak: $streak days.');
    return LocalAnswer(buf.toString(), cards: [
      {'type': 'stat', 'label': 'Focused', 'value': focusDuration(secs)},
      {'type': 'stat', 'label': 'Rounds', 'value': '$rounds'},
      {'type': 'stat', 'label': 'Streak', 'value': '$streak d'},
    ], looked: looked);
  }

  // ---------- help ----------

  LocalAnswer _help() => LocalAnswer('''
I work right on your phone, no internet needed. Try:
- "How much did I spend on food this month?"
- "What's my Global deposit?" or "How much is in bKash?"
- "Can I still spend today?"
- "Biggest expense last month"
- "How was my focus this week?"
- "Find my notes about the trip"
- "Make a note: groceries, eggs, rice, milk"

For anything outside the app I'll send you to Google, which shows its own AI summary. Switch to Gemini at the top for open-ended chat.''');
}

String fmtMoney(int paisa, bool hidden) => money(paisa, hidden: hidden);
