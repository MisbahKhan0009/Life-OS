import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:http/http.dart' as http;

import 'focus_models.dart';
import 'focus_store.dart';
import 'format.dart';
import 'markdown.dart';
import 'models.dart';
import 'money_format.dart';
import 'money_models.dart';
import 'money_store.dart';
import 'store.dart';

/// One line in the chat.
class ChatMessage {
  ChatMessage({required this.role, required this.text, List<ToolNote>? tools, DateTime? at, this.error = false})
      : tools = tools ?? [],
        at = at ?? DateTime.now();

  /// 'user' or 'model'.
  final String role;
  String text;
  final List<ToolNote> tools;
  final DateTime at;
  final bool error;

  bool get isUser => role == 'user';

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        'tools': [for (final t in tools) t.toMap()],
        'at': at.millisecondsSinceEpoch,
        'error': error,
      };

  factory ChatMessage.fromMap(Map m) => ChatMessage(
        role: (m['role'] as String?) ?? 'model',
        text: (m['text'] as String?) ?? '',
        tools: [for (final t in (m['tools'] as List? ?? const [])) if (t is Map) ToolNote.fromMap(t)],
        at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0),
        error: (m['error'] as bool?) ?? false,
      );
}

/// What the assistant looked at or did, shown as a small chip under its answer.
class ToolNote {
  ToolNote(this.label, {this.noteId});
  final String label;

  /// Set when the chip should open a note.
  final String? noteId;

  Map<String, dynamic> toMap() => {'label': label, if (noteId != null) 'noteId': noteId};
  factory ToolNote.fromMap(Map m) => ToolNote((m['label'] as String?) ?? '', noteId: m['noteId'] as String?);
}

class AssistantException implements Exception {
  AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The personal assistant: chat history and settings on the device, answers from Gemini,
/// which looks things up in your notes, money and focus data through the tools below.
class Assistant extends ChangeNotifier {
  Assistant._(this._box, this.notes, this.money, this.focus);

  final Box _box;
  final NoteStore notes;
  final MoneyStore money;
  final FocusStore focus;

  final List<ChatMessage> messages = [];
  bool busy = false;

  /// What it is doing right now ("Searching notes…").
  String status = '';

  static Future<Assistant> open({required NoteStore notes, required MoneyStore money, required FocusStore focus, String box = 'assistant'}) async {
    final a = Assistant._(await Hive.openBox(box), notes, money, focus);
    for (final m in (a._box.get('messages') as List? ?? const [])) {
      if (m is Map) a.messages.add(ChatMessage.fromMap(m));
    }
    return a;
  }

  // ---------- settings ----------

  String get apiKey => (_box.get('apiKey') as String?) ?? '';
  set apiKey(String v) {
    _box.put('apiKey', v.trim());
    notifyListeners();
  }

  bool get hasKey => apiKey.isNotEmpty;

  String get model => (_box.get('model') as String?) ?? 'gemini-flash-latest';
  set model(String v) {
    _box.put('model', v.trim().isEmpty ? 'gemini-flash-latest' : v.trim());
    notifyListeners();
  }

  /// Lets the assistant create notes when you ask it to.
  bool get canWrite => (_box.get('canWrite') as bool?) ?? true;
  set canWrite(bool v) {
    _box.put('canWrite', v);
    notifyListeners();
  }

  void clear() {
    messages.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    final keep = messages.length > 200 ? messages.sublist(messages.length - 200) : messages;
    _box.put('messages', [for (final m in keep) m.toMap()]);
  }

  // ---------- chat ----------

  /// Sends [text] and waits for the reply (with any lookups in between).
  Future<void> send(String text, {http.Client? client}) async {
    final q = text.trim();
    if (q.isEmpty || busy) return;
    messages.add(ChatMessage(role: 'user', text: q));
    busy = true;
    status = 'Thinking';
    _persist();
    notifyListeners();

    final reply = ChatMessage(role: 'model', text: '');
    try {
      if (!hasKey) throw AssistantException('Add your Gemini API key in the assistant settings first.');
      reply.text = await _run(client ?? http.Client(), reply);
      if (reply.text.trim().isEmpty) reply.text = 'I could not come up with an answer. Try asking another way.';
      messages.add(reply);
    } catch (e) {
      messages.add(ChatMessage(role: 'model', text: e is AssistantException ? e.message : 'Something went wrong: $e', tools: reply.tools, error: true));
    } finally {
      busy = false;
      status = '';
      _persist();
      notifyListeners();
    }
  }

  Future<String> _run(http.Client client, ChatMessage reply) async {
    // Earlier turns go in as plain text; the newest question is last.
    final history = messages.where((m) => !m.error).toList();
    final recent = history.length > 16 ? history.sublist(history.length - 16) : history;
    final contents = <Map<String, dynamic>>[
      for (final m in recent)
        {
          'role': m.isUser ? 'user' : 'model',
          'parts': [
            {'text': m.text}
          ],
        },
    ];

    for (var step = 0; step < 8; step++) {
      final res = await _call(client, contents);
      final cand = (res['candidates'] as List?)?.firstOrNull as Map?;
      final content = cand?['content'] as Map?;
      final parts = (content?['parts'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
      if (parts.isEmpty) {
        final reason = cand?['finishReason'] ?? (res['promptFeedback'] as Map?)?['blockReason'];
        throw AssistantException(reason == null ? 'Gemini sent back an empty answer.' : 'Gemini stopped ($reason).');
      }
      final calls = [for (final p in parts) if (p['functionCall'] is Map) p['functionCall'] as Map];
      if (calls.isEmpty) {
        return parts.where((p) => p['thought'] != true).map((p) => p['text'] as String? ?? '').join().trim();
      }
      // Send the model's turn back exactly as it came (it can carry thought signatures).
      contents.add({'role': 'model', 'parts': parts});
      final responses = <Map<String, dynamic>>[];
      for (final call in calls) {
        final name = call['name'] as String? ?? '';
        final args = (call['args'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        status = _statusFor(name);
        notifyListeners();
        Object result;
        try {
          result = runTool(name, args, reply.tools);
        } catch (e) {
          result = {'error': '$e'};
        }
        responses.add({
          'functionResponse': {
            'name': name,
            'response': result is Map ? result : {'result': result},
          },
        });
      }
      contents.add({'role': 'user', 'parts': responses});
      status = 'Writing';
      notifyListeners();
    }
    throw AssistantException('That took too many steps. Try a narrower question.');
  }

  Future<Map<String, dynamic>> _call(http.Client client, List<Map<String, dynamic>> contents) async {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _system()}
        ]
      },
      'contents': contents,
      'tools': [
        {'functionDeclarations': toolDeclarations(canWrite: canWrite)}
      ],
      'generationConfig': {'temperature': 0.4},
    });
    final http.Response r;
    try {
      r = await client
          .post(uri, headers: {'Content-Type': 'application/json', 'X-goog-api-key': apiKey}, body: body)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw AssistantException('Gemini took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw AssistantException('Could not reach Gemini. Check your internet connection.');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AssistantException('Gemini sent something unexpected (HTTP ${r.statusCode}).');
    }
    if (r.statusCode != 200) {
      final msg = (json['error'] as Map?)?['message'] ?? 'HTTP ${r.statusCode}';
      if (r.statusCode == 400 || r.statusCode == 401 || r.statusCode == 403) {
        throw AssistantException('Gemini refused the request: $msg\nCheck the API key and model in the assistant settings.');
      }
      if (r.statusCode == 429) throw AssistantException('Gemini says you have hit your limit for now. Try again in a minute.');
      throw AssistantException('Gemini error: $msg');
    }
    return json;
  }

  String _system() {
    final now = DateTime.now();
    return '''
You are the personal assistant inside Life OS, the user's own app for notes, money and focus (Pomodoro).
You help them find things and understand their own data. Today is ${weekdayShort(now)} ${now.day} ${monthShort(now)} ${now.year}, ${twoDigits(now.hour)}:${twoDigits(now.minute)}.

Rules:
- Look things up with the tools before answering anything about their notes, money or focus. Never invent notes, numbers or sessions. If a search finds nothing, say so.
- Search with a few short keyword variations if the first search finds nothing.
- Money is in Bangladeshi taka. Write amounts like ৳1,250 with lakh grouping (৳1,25,000).
- Refer to notes by their title. Quote short bits when it helps.
- Keep answers short and warm: a sentence or two, or a few bullets. Use **bold** sparingly. Do not use em dashes.
- Only create notes when the user asks you to.''';
  }

  static String _statusFor(String tool) => switch (tool) {
        'search_notes' => 'Searching notes',
        'read_note' => 'Reading a note',
        'list_folders' => 'Looking at folders',
        'create_note' => 'Creating a note',
        'money_overview' => 'Checking money',
        'list_transactions' => 'Looking through transactions',
        'list_goals' => 'Checking goals',
        'focus_overview' => 'Checking focus',
        'list_focus_sessions' => 'Looking through sessions',
        _ => 'Looking',
      };

  // ---------- tools ----------

  static List<Map<String, dynamic>> toolDeclarations({bool canWrite = true}) {
    Map<String, dynamic> obj(Map<String, dynamic> props, [List<String> req = const []]) =>
        {'type': 'object', 'properties': props, if (req.isNotEmpty) 'required': req};
    Map<String, dynamic> str(String d) => {'type': 'string', 'description': d};
    Map<String, dynamic> int_(String d) => {'type': 'integer', 'description': d};
    return [
      {
        'name': 'search_notes',
        'description': 'Search the user\'s notes by keywords (title and text). Empty query lists the most recent notes.',
        'parameters': obj({'query': str('Keywords, e.g. "weekly review" or "flight"'), 'folder': str('Optional folder name to search in'), 'limit': int_('Max results, default 8')}),
      },
      {
        'name': 'read_note',
        'description': 'Read the full text of one note by its id (from search_notes).',
        'parameters': obj({'id': str('Note id')}, ['id']),
      },
      {
        'name': 'list_folders',
        'description': 'List folders with how many notes each has.',
        'parameters': obj({}),
      },
      if (canWrite)
        {
          'name': 'create_note',
          'description': 'Create a new note. Only when the user asks for it.',
          'parameters': obj({
            'title': str('Note title'),
            'text': str('Note body. Lines starting with "- " become bullets, "[] " checklist items.'),
            'folder': str('Optional existing folder name'),
          }, ['title', 'text']),
        },
      {
        'name': 'money_overview',
        'description': 'Money summary: Global deposit (all savings combined), net worth, account balances, a month\'s spending and deposits, budget, safe to spend today, top spending categories.',
        'parameters': obj({'month': str('YYYY-MM, default this month')}),
      },
      {
        'name': 'list_transactions',
        'description': 'List money transactions, newest first.',
        'parameters': obj({
          'month': str('YYYY-MM, default this month. Use "all" for every month.'),
          'kind': str('expense, deposit or transfer'),
          'category': str('Category name, e.g. Food'),
          'query': str('Words in the note, category or account'),
          'limit': int_('Max results, default 30'),
        }),
      },
      {
        'name': 'list_goals',
        'description': 'Savings goals with target, saved so far, deadline and monthly amount needed.',
        'parameters': obj({}),
      },
      {
        'name': 'focus_overview',
        'description': 'Focus (Pomodoro) summary: today, week, month, year totals, streaks, daily goal, average session, completion rate, ratings and top notes worked on.',
        'parameters': obj({'days': int_('Window for averages, default 30')}),
      },
      {
        'name': 'list_focus_sessions',
        'description': 'List focus sessions, newest first, with intention, linked note, minutes and ratings.',
        'parameters': obj({'days': int_('How many days back, default 7'), 'limit': int_('Max results, default 30')}),
      },
    ];
  }

  /// Runs one tool. [log] collects chips for the answer.
  @visibleForTesting
  Object runTool(String name, Map<String, dynamic> a, List<ToolNote> log) {
    int n(String k, int d) => (a[k] as num?)?.toInt() ?? d;
    String s(String k) => (a[k] as String?)?.trim() ?? '';
    switch (name) {
      case 'search_notes':
        final q = s('query');
        final folderName = s('folder').toLowerCase();
        final folder = folderName.isEmpty ? null : notes.folders.where((f) => f.name.toLowerCase().contains(folderName)).firstOrNull;
        final found = searchNotes(q, folderId: folder?.id, limit: n('limit', 8).clamp(1, 20));
        log.add(ToolNote(q.isEmpty ? 'Recent notes' : 'Searched notes · $q'));
        return {
          'count': found.length,
          'notes': [
            for (final x in found)
              {
                'id': x.id,
                'title': x.displayTitle,
                'folder': notes.folder(x.folderId)?.name,
                'updated': '${x.updatedAt.year}-${twoDigits(x.updatedAt.month)}-${twoDigits(x.updatedAt.day)}',
                'pinned': x.pinned,
                'snippet': _clip(x.preview, 220),
              }
          ],
        };
      case 'read_note':
        final note = notes.note(s('id'));
        if (note == null || note.inTrash) return {'error': 'No note with that id'};
        log.add(ToolNote('Read · ${note.displayTitle}', noteId: note.id));
        return {
          'id': note.id,
          'title': note.displayTitle,
          'folder': notes.folder(note.folderId)?.name,
          'created': note.createdAt.toIso8601String(),
          'updated': note.updatedAt.toIso8601String(),
          'markdown': note.locked ? '(This note is locked. Ask the user to unlock it.)' : _clip(noteToMarkdown(note), 8000),
        };
      case 'list_folders':
        log.add(ToolNote('Folders'));
        return {
          'folders': [for (final f in notes.folders) {'name': f.name, 'notes': notes.countIn(f.id), 'description': f.description}],
          'notes_without_folder': notes.notes().where((x) => x.folderId == null).length,
        };
      case 'create_note':
        if (!canWrite) return {'error': 'Creating notes is turned off in the assistant settings'};
        final folderName = s('folder').toLowerCase();
        final folder = folderName.isEmpty ? null : notes.folders.where((f) => f.name.toLowerCase() == folderName).firstOrNull;
        final note = notes.createNote(title: s('title'), folderId: folder?.id, blocks: textToBlocks(s('text')));
        log.add(ToolNote('Created · ${note.displayTitle}', noteId: note.id));
        return {'created': true, 'id': note.id, 'title': note.displayTitle, 'folder': folder?.name};
      case 'money_overview':
        final m = _month(s('month')) ?? DateTime(DateTime.now().year, DateTime.now().month);
        log.add(ToolNote('Money · ${monthShort(m)} ${m.year}'));
        final budget = money.monthlyBudget;
        final isNow = m.year == DateTime.now().year && m.month == DateTime.now().month;
        return {
          'month': '${m.year}-${twoDigits(m.month)}',
          'global_deposit': moneyText(money.globalDeposit),
          'net_worth': moneyText(money.netWorth),
          'accounts': [
            for (final x in money.accounts) {'name': x.name, 'type': x.kind.label, 'balance': moneyText(money.balance(x.id)), 'in_global_deposit': x.inGlobal}
          ],
          'spent': moneyText(money.spent(m)),
          'deposited': moneyText(money.deposited(m)),
          'monthly_budget': budget > 0 ? moneyText(budget) : 'not set',
          if (isNow && money.safeToSpendToday() != null) 'safe_to_spend_today': moneyText(money.safeToSpendToday()!),
          'top_categories': [
            for (final (c, amt) in money.spentByCategory(m).take(8))
              {'category': c?.name ?? 'Uncategorised', 'spent': moneyText(amt), if ((c?.limit ?? 0) > 0) 'limit': moneyText(c!.limit)}
          ],
        };
      case 'list_transactions':
        final monthArg = s('month');
        final m = monthArg == 'all' ? null : (_month(monthArg) ?? DateTime(DateTime.now().year, DateTime.now().month));
        final kind = TxnKind.values.where((k) => k.name == s('kind').toLowerCase()).firstOrNull;
        final catName = s('category').toLowerCase();
        final cat = catName.isEmpty
            ? null
            : [...money.categories(CategoryKind.expense), ...money.categories(CategoryKind.income)].where((c) => c.name.toLowerCase().contains(catName)).firstOrNull;
        final list = money.txns(month: m, kind: kind, categoryId: cat?.id, query: s('query'));
        final limit = n('limit', 30).clamp(1, 100);
        log.add(ToolNote('Transactions${cat != null ? ' · ${cat.name}' : ''}${m != null ? ' · ${monthShort(m)}' : ''}'));
        return {
          'count': list.length,
          'total_spent': moneyText(list.where((x) => x.kind == TxnKind.expense).fold(0, (t, x) => t + x.amount)),
          'total_deposited': moneyText(list.where((x) => x.kind == TxnKind.deposit).fold(0, (t, x) => t + x.amount)),
          'transactions': [
            for (final t in list.take(limit))
              {
                'date': '${t.date.year}-${twoDigits(t.date.month)}-${twoDigits(t.date.day)}',
                'kind': t.kind.name,
                'amount': moneyText(t.amount),
                'category': money.category(t.categoryId)?.name,
                'account': money.account(t.accountId)?.name,
                if (t.toAccountId != null) 'to_account': money.account(t.toAccountId)?.name,
                if (t.note.isNotEmpty) 'note': t.note,
              }
          ],
        };
      case 'list_goals':
        log.add(ToolNote('Goals'));
        return {
          'goals': [
            for (final g in money.goals)
              {
                'name': g.name,
                'target': moneyText(g.target),
                'saved': moneyText(g.saved),
                'progress_percent': (g.progress * 100).round(),
                if (g.deadline != null) 'deadline': '${g.deadline!.year}-${twoDigits(g.deadline!.month)}',
                if (g.monthlyNeeded() != null) 'monthly_needed': moneyText(g.monthlyNeeded()!),
              }
          ],
        };
      case 'focus_overview':
        final now = DateTime.now();
        final days = n('days', 30).clamp(1, 365);
        log.add(ToolNote('Focus stats'));
        final rate = focus.completionRate(now, days: days);
        return {
          'today': focusDuration(focus.secondsOn(now)),
          'rounds_today': focus.roundsOn(now),
          'daily_goal': focusDuration(focus.dailyGoal * 60),
          'this_week': focusDuration(focus.weekSeconds(now)),
          'this_month': focusDuration(focus.monthSeconds(now)),
          'this_year': focusDuration(focus.yearSeconds(now)),
          'streak_days': focus.streak(now),
          'best_streak_days': focus.bestStreak,
          'average_session': focusDuration(focus.averageSeconds(now, days: days)),
          if (rate != null) 'completion_rate_percent': (rate * 100).round(),
          if (focus.averageScore(now, energy: false, daysAgoStart: days) != null) 'average_focus_rating': focus.averageScore(now, energy: false, daysAgoStart: days)!.toStringAsFixed(1),
          if (focus.averageScore(now, energy: true, daysAgoStart: days) != null) 'average_energy': focus.averageScore(now, energy: true, daysAgoStart: days)!.toStringAsFixed(1),
          'top_notes': [
            for (final (id, secs) in focus.byNote(now, days: days).take(5)) {'note': notes.note(id)?.displayTitle ?? 'deleted note', 'time': focusDuration(secs)}
          ],
        };
      case 'list_focus_sessions':
        final days = n('days', 7).clamp(1, 365);
        final list = focus.sessions(from: DateTime.now().subtract(Duration(days: days)));
        log.add(ToolNote('Focus sessions · $days days'));
        return {
          'count': list.length,
          'sessions': [
            for (final x in list.take(n('limit', 30).clamp(1, 100)))
              {
                'start': x.start.toIso8601String(),
                'minutes': x.minutes,
                'mode': x.mode.name,
                if (x.intention.isNotEmpty) 'intention': x.intention,
                if (x.intentionDone != null) 'intention_done': x.intentionDone,
                if (x.noteId != null) 'note': notes.note(x.noteId!)?.displayTitle,
                'completed': x.counts,
                if (x.rating > 0) 'focus_rating': x.rating,
                if (x.energy > 0) 'energy': x.energy,
                if (x.reflection.isNotEmpty) 'reflection': x.reflection,
                if (x.distractionCount > 0) 'distractions': x.distractionCount,
              }
          ],
        };
    }
    return {'error': 'Unknown tool $name'};
  }

  /// Notes ranked by how many search words they contain (title matches count more).
  List<Note> searchNotes(String query, {String? folderId, int limit = 8}) {
    final all = notes.notes(folderId: folderId);
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty) return all.take(limit).toList();
    final scored = <(Note, int)>[];
    for (final x in all) {
      final title = x.displayTitle.toLowerCase();
      final text = x.searchText;
      var score = 0;
      for (final w in words) {
        if (title.contains(w)) score += 3;
        if (text.contains(w)) score += 1;
      }
      if (score > 0) scored.add((x, score));
    }
    scored.sort((p, q) => q.$2 != p.$2 ? q.$2.compareTo(p.$2) : q.$1.updatedAt.compareTo(p.$1.updatedAt));
    return [for (final e in scored.take(limit)) e.$1];
  }

  static DateTime? _month(String v) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(v.trim());
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static String _clip(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';
}

/// Taka text for tool results.
String moneyText(int paisa) => money(paisa);

/// Plain text to note blocks: "- " bullets, "[] " or "[x] " checklist, "# " headings.
List<Block> textToBlocks(String text) {
  final out = <Block>[];
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    final t = line.trimLeft();
    if (t.startsWith('- ') || t.startsWith('* ')) {
      out.add(Block(type: BlockType.bullet, text: t.substring(2)));
    } else if (t.startsWith('[] ') || t.startsWith('[ ] ')) {
      out.add(Block(type: BlockType.checklist, text: t.substring(t.indexOf(']') + 2)));
    } else if (t.toLowerCase().startsWith('[x] ')) {
      out.add(Block(type: BlockType.checklist, text: t.substring(4), checked: true));
    } else if (t.startsWith('### ')) {
      out.add(Block(type: BlockType.heading3, text: t.substring(4)));
    } else if (t.startsWith('## ')) {
      out.add(Block(type: BlockType.heading2, text: t.substring(3)));
    } else if (t.startsWith('# ')) {
      out.add(Block(type: BlockType.heading1, text: t.substring(2)));
    } else {
      out.add(Block(text: t));
    }
  }
  if (out.isEmpty) out.add(Block(text: ''));
  return out;
}
