import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/assistant.dart';
import '../../data/focus_engine.dart';
import '../../data/money_store.dart';
import '../../data/store.dart';
import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';
import '../../ui/logo.dart';
import '../../ui/widgets.dart';

Assistant? _assistant;
Future<Assistant>? _opening;

Future<Assistant> assistantFor(BuildContext context) {
  if (_assistant != null) return Future.value(_assistant);
  final notes = StoreScope.read(context);
  final money = MoneyScope.read(context);
  final focus = FocusEngineScope.read(context).store;
  return _opening ??= Assistant.open(notes: notes, money: money, focus: focus).then((a) => _assistant = a);
}

void openAssistant(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const AssistantScreen(),
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c), child: child),
      );
    },
  ));
}

/// Round "Ask" button for screen headers.
class AskButton extends StatelessWidget {
  const AskButton({super.key, this.background, this.foreground, this.size = 38});

  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RoundIconButton(
      icon: AppIcons.ask,
      label: 'Ask Life OS',
      size: size,
      background: background ?? c.ink,
      foreground: foreground ?? c.inverseInk,
      onTap: () => openAssistant(context),
    );
  }
}

/// Chat with your own data.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  Assistant? _a;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _seen = 0;

  static const _suggestions = [
    'How much did I spend on food this month?',
    'What is my Global deposit right now?',
    'Find my notes about the weekly review',
    'How was my focus this week?',
    'Which note have I focused on the most?',
    'Make a packing list note for a weekend trip',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final a = await assistantFor(context);
      if (!mounted) return;
      a.addListener(_changed);
      setState(() => _a = a);
      _toEnd(jump: true);
    });
  }

  @override
  void dispose() {
    _a?.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final a = _a!;
    if (a.messages.length != _seen) {
      if (a.messages.length > _seen && _seen > 0 && !a.messages.last.isUser) HapticFeedback.lightImpact();
      _seen = a.messages.length;
      _toEnd();
    }
    setState(() {});
  }

  void _toEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      jump ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    });
  }

  void _send([String? text]) {
    final a = _a;
    final t = (text ?? _input.text).trim();
    if (a == null || t.isEmpty || a.busy) return;
    if (!a.hasKey) {
      showAssistantSettings(context, a);
      return;
    }
    _input.clear();
    a.send(t);
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _a;
    final messages = a?.messages ?? const <ChatMessage>[];

    return Scaffold(
      backgroundColor: c.ground,
      body: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: GrainOverlay(opacity: c.isDark ? 0.04 : 0.06))),
        SafeArea(
          child: ContentWidth(
            max: 680,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(children: [
                  RoundIconButton(icon: AppIcons.back, label: 'Back', background: c.chip, foreground: c.ink, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  a != null && a.busy ? OrbitSpinner(size: 30, ink: c.ink, dim: c.line) : OrbitMark(size: 30, ink: c.ink, dim: c.line),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ask Life OS', style: AppText.sans(18, weight: FontWeight.w700, color: c.ink)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          a == null ? 'Opening' : (a.busy ? '${a.status}…' : 'Searches your notes, money and focus'),
                          key: ValueKey(a?.status ?? ''),
                          style: AppText.sans(12.5, color: c.muted),
                        ),
                      ),
                    ]),
                  ),
                  if (a != null)
                    RoundIconButton(icon: AppIcons.settings, label: 'Assistant settings', background: c.chip, foreground: c.ink, onTap: () => showAssistantSettings(context, a)),
                ]),
              ),
              Expanded(
                child: a == null
                    ? const SizedBox()
                    : messages.isEmpty
                        ? _Empty(hasKey: a.hasKey, suggestions: _suggestions, onPick: _send, onSetup: () => showAssistantSettings(context, a))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: messages.length + (a.busy ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == messages.length) return _Thinking(status: a.status);
                              return _Bubble(key: ValueKey(messages[i].at.microsecondsSinceEpoch), message: messages[i]);
                            },
                          ),
              ),
              _Composer(controller: _input, busy: a?.busy ?? false, onSend: _send),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasKey, required this.suggestions, required this.onPick, required this.onSetup});

  final bool hasKey;
  final List<String> suggestions;
  final ValueChanged<String> onPick;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 30, 20, 20), children: [
      Center(child: OrbitMark(size: 92, background: const Color(0xFF0E0E0F))),
      const SizedBox(height: 22),
      Text('Your own assistant', textAlign: TextAlign.center, style: AppText.display(29, color: c.ink)),
      const SizedBox(height: 8),
      Text(
        'Ask about anything in Life OS. It looks through your notes, money and focus sessions to answer, and can write notes for you.',
        textAlign: TextAlign.center,
        style: AppText.sans(14.5, color: c.muted, height: 1.45),
      ),
      const SizedBox(height: 24),
      if (!hasKey) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('One step first', style: AppText.sans(16, weight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 4),
            Text('Paste your Gemini API key. It stays on this phone.', style: AppText.sans(13.5, color: c.muted)),
            const SizedBox(height: 12),
            PillButton(label: 'Add API key', style: PillStyle.action, onTap: onSetup),
          ]),
        ),
        const SizedBox(height: 18),
      ],
      Text('TRY', style: AppText.label(10.5, color: c.muted)),
      const SizedBox(height: 10),
      for (final s in suggestions)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            onTap: () => onPick(s),
            scale: 0.98,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.line)),
              child: Row(children: [
                Expanded(child: Text(s, style: AppText.sans(14.5, color: c.ink))),
                Icon(CupertinoIcons.arrow_up_right, size: 15, color: c.muted),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = message;
    final child = m.isUser
        ? Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: SelectableText(m.text, style: AppText.sans(15.5, color: c.inverseInk, height: 1.4)),
              ),
            ),
          )
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: OrbitMark(size: 26, background: const Color(0xFF0E0E0F), lit: m.error ? 4 : 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (m.tools.isNotEmpty) ...[
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final t in m.tools) _ToolChip(note: t)]),
                  const SizedBox(height: 8),
                ],
                RichText(
                  text: TextSpan(children: renderMarkdown(m.text, c, error: m.error)),
                ),
                const SizedBox(height: 4),
                Pressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    showToast(context, 'Copied');
                  },
                  label: 'Copy answer',
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Icon(AppIcons.copy, size: 15, color: c.muted)),
                ),
              ]),
            ),
          ]);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (_, v, w) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: w)),
      child: Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.note});
  final ToolNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final opens = note.noteId != null && StoreScope.read(context).note(note.noteId!) != null;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 10, 5),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(opens ? AppIcons.notes : CupertinoIcons.search, size: 12, color: c.muted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(note.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, weight: FontWeight.w500, color: c.muted)),
        ),
      ]),
    );
    if (!opens) return chip;
    return Pressable(onTap: () => openNote(context, note.noteId!), label: note.label, child: chip);
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        const OrbitSpinner(size: 26),
        const SizedBox(width: 10),
        Text('$status…', style: AppText.sans(14, color: c.muted)),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.busy, required this.onSend});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Glass(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: c.action,
                style: AppText.sans(16, color: c.ink, height: 1.35),
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Ask anything about your life', hintStyle: AppText.sans(16, color: c.muted)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) {
              final ready = v.text.trim().isNotEmpty && !busy;
              return Pressable(
                onTap: ready ? onSend : null,
                label: 'Send',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: ready ? c.action : c.chip, shape: BoxShape.circle),
                  child: Icon(AppIcons.send, size: 20, color: ready ? Colors.white : c.muted),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

/// A light Markdown renderer for answers: **bold**, *italic*, `code`, headings and bullets.
List<InlineSpan> renderMarkdown(String text, AppColors c, {bool error = false}) {
  final base = AppText.sans(15.5, color: error ? c.action : c.ink, height: 1.5);
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var style = base;
    final t = line.trimLeft();
    if (t.startsWith('### ') || t.startsWith('## ') || t.startsWith('# ')) {
      line = t.replaceFirst(RegExp(r'^#+\s'), '');
      style = base.copyWith(fontWeight: FontWeight.w700, fontSize: 16.5);
    } else if (t.startsWith('- ') || t.startsWith('* ')) {
      spans.add(TextSpan(text: '  •  ', style: base.copyWith(color: c.muted)));
      line = t.substring(2);
    } else if (RegExp(r'^\d+\.\s').hasMatch(t)) {
      final m = RegExp(r'^(\d+)\.\s').firstMatch(t)!;
      spans.add(TextSpan(text: '  ${m.group(1)}.  ', style: base.copyWith(color: c.muted)));
      line = t.substring(m.end);
    }
    spans.addAll(_inline(line, style, c));
    if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
  }
  return spans;
}

List<InlineSpan> _inline(String s, TextStyle style, AppColors c) {
  final out = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])');
  var last = 0;
  for (final m in re.allMatches(s)) {
    if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start), style: style));
    if (m.group(1) != null) {
      out.add(TextSpan(text: m.group(1), style: style.copyWith(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null) {
      out.add(TextSpan(text: m.group(2), style: style.copyWith(fontFamily: 'GeistMono', fontSize: (style.fontSize ?? 15) - 1.5, backgroundColor: c.chip)));
    } else {
      out.add(TextSpan(text: m.group(3), style: style.copyWith(fontStyle: FontStyle.italic)));
    }
    last = m.end;
  }
  if (last < s.length) out.add(TextSpan(text: s.substring(last), style: style));
  return out;
}

/// API key, model and permissions.
Future<void> showAssistantSettings(BuildContext context, Assistant a) {
  final key = TextEditingController(text: a.apiKey);
  final model = TextEditingController(text: a.model);
  var obscure = true;
  return showAppSheet<void>(context, builder: (ctx) {
    final c = ctx.colors;
    return StatefulBuilder(builder: (ctx, set) {
      void save() {
        a.apiKey = key.text;
        a.model = model.text;
        Navigator.of(ctx).pop();
        showToast(context, a.hasKey ? 'Assistant ready' : 'API key removed');
      }

      Widget field(TextEditingController ctrl, String hint, {bool secret = false}) => Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(Radii.s), border: Border.all(color: c.line)),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: secret && obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  cursorColor: c.action,
                  style: AppText.sans(15, color: c.ink),
                  decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: hint, hintStyle: AppText.sans(15, color: c.muted)),
                ),
              ),
              if (secret)
                Pressable(
                  onTap: () => set(() => obscure = !obscure),
                  label: obscure ? 'Show key' : 'Hide key',
                  child: Icon(obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18, color: c.muted),
                ),
            ]),
          );

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Assistant', style: AppText.sans(20, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 4),
          Text(
            'Answers come from Google Gemini. When you ask something, the parts of your notes, money and focus data it looks up are sent to Google to write the answer. Your key is kept only on this phone.',
            style: AppText.sans(13, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text('GEMINI API KEY', style: AppText.label(10.5, color: c.muted)),
          const SizedBox(height: 8),
          field(key, 'Paste your key', secret: true),
          const SizedBox(height: 6),
          Text('Get one free at aistudio.google.com', style: AppText.sans(12.5, color: c.muted)),
          const SizedBox(height: 14),
          Text('MODEL', style: AppText.label(10.5, color: c.muted)),
          const SizedBox(height: 8),
          field(model, 'gemini-flash-latest'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Let it create notes when you ask', style: AppText.sans(15, color: c.ink))),
            CupertinoSwitch(value: a.canWrite, activeTrackColor: c.action, onChanged: (v) => set(() => a.canWrite = v)),
          ]),
          const SizedBox(height: 16),
          PillButton(label: 'Save', style: PillStyle.primary, onTap: save),
          const SizedBox(height: 8),
          PillButton(
            label: 'Clear conversation',
            style: PillStyle.quiet,
            onTap: a.messages.isEmpty
                ? null
                : () {
                    a.clear();
                    Navigator.of(ctx).pop();
                  },
          ),
        ]),
      );
    });
  });
}
