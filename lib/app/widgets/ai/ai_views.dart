/// The views of the AI assistant, shared by the docked panel and the
/// dialog: the conversation (with the to-do list, the cards for approvals,
/// questions and plans, messages typed while the assistant works, rewind,
/// quick commands and attachments), the data sent (with a preview of
/// exactly what goes out, and to which company), and the settings (a key
/// per provider, the model by provider and tier with its list prices, the
/// modes, limits and spending cap, the instructions and the project's AI
/// notes).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/agent_loop.dart';
import '../../../core/ai/project_context.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../ai/agent_tools_agent.dart';
import '../../ai/ai_assistant.dart';
import '../../ai/ai_attention.dart';
import '../../io/file_drop.dart';
import '../../io/file_io.dart';
import '../../io/links.dart';
import '../../keys/hotkeys.dart' show OwnKeys;
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'ai_conversations.dart';
import 'ai_drop.dart';
import 'ai_markdown.dart';
import 'ai_marks_bar.dart';
import 'ai_steps.dart';
import 'ai_voice.dart';

/// The assistant's text, rendered from its Markdown (see ai_markdown.dart).
Widget aiRichText(String text, {double size = 12.5}) => AiMarkdown(text, size: size);

/// Asks before a conversation with content, or a running task, is wiped;
/// true when it may go.
Future<bool> aiConfirmNew(BuildContext context, ProjectController c, AiAssistant ai) async {
  if (!ai.busy && !ai.items.any((it) => it.kind != AiItemKind.notice)) return true;
  final t = c.t;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('ai.new')),
      content: Text(t(ai.busy ? 'ai.new.confirmBusy' : 'ai.new.confirm')),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('cancel'))),
        FilledButton(key: const Key('ai_new_ok'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t('ai.new'))),
      ],
    ),
  );
  return ok == true;
}

String aiTokens(int n) => n < 1000 ? '$n' : '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';

String _usd(double v) => v.toStringAsFixed(v < 1 ? 3 : 2);

/// The meter line: tokens, pictures and the estimated cost.
String aiMeterText(ProjectController c, AiAssistant ai) => ai.usage.totalInput == 0
    ? '${ai.model.label} · ${c.t('ai.mode.${ai.permission.name}')}'
    : c.t('ai.meter', {'i': aiTokens(ai.usage.totalInput), 'o': aiTokens(ai.usage.output), 'c': _usd(ai.cost)}) + (ai.pictures > 0 ? ' · ${c.t('ai.pictures', {'n': '${ai.pictures}'})}' : '');

/// Files a message can carry (images, PDFs, text) and drawings to import.
const aiAttachAccept = '.pdf,.png,.jpg,.jpeg,.webp,.gif,.txt,.csv,.tsv,.json,.md,.dxf,.dwg,.dgn,.kml,.kmz,.shp,.zip,.geojson,.gpx,.xml,.landxml,.inp,.las,.tif,.tiff';

// ---------------------------------------------------------------- conversation

class AiChatView extends StatefulWidget {
  const AiChatView({super.key, required this.c, required this.ai, required this.input, this.compact = false, this.onSettings});
  final ProjectController c;
  final AiAssistant ai;
  final TextEditingController input;
  final bool compact;

  /// Opens the settings (the key is missing).
  final VoidCallback? onSettings;

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> implements AiPasteTarget {
  final scroll = ScrollController();
  final focus = FocusNode();

  /// The main button of the card waiting for the user (Apply, Send the
  /// answers, Approve): it takes the focus when the card appears, unless the
  /// user is typing in the box.
  final cardFocus = FocusNode();
  Object? _card;
  int _seen = 0;
  Timer? _clock;

  /// Scrolled up, away from the newest text (shows the way back down).
  bool _away = false;

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;
  TextEditingController get input => widget.input;

  @override
  void initState() {
    super.initState();
    ai.addListener(_follow);
    input.addListener(_typed);
    scroll.addListener(_onScroll);
    AiFileDrop.instance.addBox(this);
    _follow();
  }

  /// Files pasted while the box has the cursor are attached (a screenshot,
  /// files copied in the file manager).
  @override
  bool get focused => focus.hasFocus;

  @override
  Future<void> take(List<DroppedFile> files) => aiAttachFiles(AiFileDrop.instance.noticesFor(c), ai, files);

  void _onScroll() {
    final away = scroll.hasClients && scroll.position.maxScrollExtent - scroll.position.pixels > 300;
    if (away != _away) setState(() => _away = away);
  }

  /// Puts the cursor in the box (after the frame, when the box exists):
  /// Enter then sends instead of reaching the drawing's shortcuts.
  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) focus.requestFocus();
  });

  @override
  void didUpdateWidget(AiChatView old) {
    super.didUpdateWidget(old);
    if (!identical(old.ai, ai)) {
      old.ai.removeListener(_follow);
      ai.addListener(_follow);
    }
    if (!identical(old.input, input)) {
      old.input.removeListener(_typed);
      input.addListener(_typed);
    }
  }

  @override
  void dispose() {
    AiFileDrop.instance.removeBox(this);
    ai.removeListener(_follow);
    input.removeListener(_typed);
    _clock?.cancel();
    scroll.removeListener(_onScroll);
    scroll.dispose();
    focus.dispose();
    cardFocus.dispose();
    super.dispose();
  }

  void _typed() => setState(() {});

  /// Keeps the newest text in view while it streams in; puts a rewound
  /// message back in the box; ticks the clock of long answers.
  void _follow() {
    final back = ai.rewound;
    var focusNow = false;
    if (back != null) {
      ai.rewound = null;
      // a request from elsewhere (Ask the AI, the start-up question, a rewind) never discards a draft
      final draft = input.text.trim();
      input.text = draft.isEmpty || draft == back.trim() ? back : '$draft\n\n$back';
      input.selection = TextSelection.collapsed(offset: input.text.length);
      focusNow = true;
    }
    if (ai.focusInput) {
      ai.focusInput = false;
      focusNow = true;
    }
    if (focusNow) _focusSoon();
    // a card that waits for the user: said aloud, and its main button focused
    final card = ai.pending ?? ai.question ?? ai.planReview;
    if (card == null) {
      _card = null;
    } else if (!identical(card, _card)) {
      _card = card;
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce(card));
    }
    if (ai.busy && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        if (!ai.busy) {
          _clock?.cancel();
          _clock = null;
        }
      });
    }
    final n = ai.items.length + ai.items.fold<int>(0, (s, i) => s + i.text.length + i.calls.length);
    if (n == _seen || !scroll.hasClients) return;
    _seen = n;
    final pos = scroll.position;
    if (pos.maxScrollExtent - pos.pixels < 160) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    }
  }

  /// Says what the card [card] waits for (screen readers) and puts the focus
  /// on its main button — not while the user types in the box, whose text
  /// would then go to the card.
  void _announce(Object card) {
    if (!mounted || !identical(card, _card)) return;
    final t = c.t;
    final text = switch (card) {
      AiApproval p => t('ai.announce.approval', {'x': p.call.summary}),
      AiAsk _ => t('ai.announce.questions'),
      _ => t('ai.announce.plan'),
    };
    SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context));
    if (!(focus.hasFocus && input.text.trim().isNotEmpty)) cardFocus.requestFocus();
  }

  /// Keys on a card: a character typed there goes to the box (the user
  /// meant to write), with the focus; Enter, Space (they press the focused
  /// button) and Escape are the card's.
  KeyEventResult _cardKey(FocusNode _, KeyEvent e) {
    final ch = e.character;
    if (e is! KeyDownEvent || ch == null || ch.isEmpty || ch.codeUnitAt(0) <= 0x20 || ch.codeUnitAt(0) == 0x7f) return KeyEventResult.ignored;
    final sel = input.selection;
    final at = sel.isValid ? sel.end : input.text.length;
    input.value = TextEditingValue(
      text: input.text.replaceRange(at, at, ch),
      selection: TextSelection.collapsed(offset: at + ch.length),
    );
    focus.requestFocus();
    return KeyEventResult.handled;
  }

  /// [child] as a card that waits for the user: announced (a live region,
  /// for the screen readers that ignore announcements), its keys its own
  /// (the app's shortcuts leave them alone), Escape running [onEscape].
  Widget _cardShell(Widget child, {VoidCallback? onEscape}) => OwnKeys(
    child: Semantics(
      liveRegion: true,
      container: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _cardKey,
        child: onEscape == null ? child : CallbackShortcuts(bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape}, child: child),
      ),
    ),
  );

  /// Enter in the box: sends, unless an input method is still composing.
  void _enter() {
    if (input.value.composing.isValid) return;
    _send();
  }

  void _useStarter(String q) {
    setState(() {
      input.text = q;
      input.selection = TextSelection.collapsed(offset: q.length);
    });
    _focusSoon();
  }

  void _send() {
    final q = input.text;
    if (q.trim().isEmpty && (ai.busy || ai.attachments.isEmpty)) return;
    input.clear();
    _focusSoon();
    ai.send(q);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  /// The paperclip; drops and pastes go through the same checks
  /// ([aiAttachFiles]).
  Future<void> _attach() async {
    final f = await openBinaryFile(accept: aiAttachAccept);
    if (f != null) await aiAttachFiles(AiFileDrop.instance.noticesFor(c), ai, [DroppedFile.bytes(f.$1, f.$2)]);
  }

  Future<void> _attachView() async {
    if (!await ai.attachView()) c.notify(c.t('ai.attach.viewFailed'));
  }

  void _insertText(String text) {
    final b = c.project.bounds;
    final at = c.camera.size.isEmpty ? (b.isEmpty ? Pt.zero : b.center) : c.camera.center;
    final h = c.camera.size.isEmpty ? 1.0 : (14 / c.camera.scale).clamp(0.2, 50).toDouble();
    c.addEntity(TextEntity(id: c.project.newId(), position: at, text: text.trim(), height: h));
    c.notify(c.t('ai.inserted'));
  }

  Future<void> _rewind(AiItem it) async {
    final project = ai.rewindsProject(it);
    if (project == null) return;
    final t = c.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ai.rewind')),
        content: Text(t(project ? 'ai.rewind.confirm' : 'ai.rewind.confirmChat')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('cancel'))),
          FilledButton(key: const Key('ai_rewind_ok'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t('ai.rewind'))),
        ],
      ),
    );
    if (ok == true) ai.rewind(it);
  }

  List<String> _starters() {
    final t = c.t;
    // a new, empty project: start a design, find the site, trace the fields
    if (c.project.entities.isEmpty) {
      return [t('ai.start.prompt'), t('ai.q.site'), t('ai.q.trace'), if (ai.attachments.isNotEmpty) t('ai.q.datasheet')];
    }
    final failing = c.results?.zones.values.where((z) => !z.withinWindow).firstOrNull;
    return [
      if (failing != null) t('ai.q.zoneWindow', {'z': failing.zoneName}) else t('ai.q.windowAny'),
      t('ai.q.pumping'),
      t('ai.q.summary'),
      t('ai.q.fix'),
      t('ai.q.design'),
      t('ai.q.trace'),
      t('ai.q.memorial'),
      if (ai.attachments.isNotEmpty) t('ai.q.datasheet'),
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(context, box.maxHeight.isFinite ? box.maxHeight * 0.5 : 420));

  Widget _build(BuildContext context, double cardMax) {
    final t = c.t;
    final items = ai.items;
    final m = ai.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ai.hasKey)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Cad.cardHigh, borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                Icon(Icons.key_outlined, size: 16, color: Cad.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(t('ai.needKey', {'p': m.provider.company}), style: const TextStyle(fontSize: 12))),
                if (widget.onSettings != null) TextButton(key: const Key('ai_go_settings'), onPressed: widget.onSettings, child: Text(t('ai.view.settings'))),
              ],
            ),
          ),
        // the conversation is kept by another tab of this browser
        if (ai.otherTab) _banner(Icons.tab_unselected, t('ai.otherTab'), const Key('ai_other_tab')),
        // the project's notes came from elsewhere: read as information, until the user takes them as theirs
        if (ai.historyLength == 0 && !ai.notesTrusted)
          _banner(Icons.policy_outlined, t('ai.notes.foreign'), const Key('ai_notes_foreign'), [
            TextButton(key: const Key('ai_notes_trust'), onPressed: ai.trustNotes, child: Text(t('ai.notes.trust'))),
            if (widget.onSettings != null) TextButton(key: const Key('ai_notes_review'), onPressed: widget.onSettings, child: Text(t('ai.notes.review'))),
          ]),
        if (ai.todos.isNotEmpty) _todos(),
        Expanded(
          child: items.isEmpty
              ? ScrollBody(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('ai.intro'), style: TextStyle(fontSize: 12.5, color: Cad.fg70)),
                        const SizedBox(height: 10),
                        Text(t('ai.starters'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                        const SizedBox(height: 4),
                        // a review of what is drawn: read-only whatever the mode (/review)
                        if (c.project.entities.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, right: 8),
                            child: Material(
                              key: const Key('ai_review'),
                              color: Cad.card,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: ai.busy ? null : () => ai.send('/review'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Icon(Icons.fact_check_outlined, size: 15, color: Cad.accentIcon),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(t('ai.review'), style: const TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final (k, q) in _starters().indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, right: 8),
                            child: Material(
                              key: Key('ai_starter_$k'),
                              color: Cad.card,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _useStarter(q),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Icon(Icons.lightbulb_outline, size: 15, color: Cad.accentIcon),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(q, style: const TextStyle(fontSize: 12, height: 1.3))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(t('ai.cmd.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      key: const Key('ai_list'),
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: items.length,
                      itemBuilder: (context, i) => switch (items[i].kind) {
                        AiItemKind.user => _userBubble(items[i], i),
                        AiItemKind.assistant => _answer(items[i]),
                        AiItemKind.notice => _notice(items[i]),
                      },
                    ),
                    if (_away)
                      PositionedDirectional(
                        end: 10,
                        bottom: 8,
                        child: IconButton.filledTonal(
                          key: const Key('ai_to_bottom'),
                          tooltip: t('ai.toBottom'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: () => scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                        ),
                      ),
                  ],
                ),
        ),
        if (ai.pending != null) _cardShell(_approval(ai.pending!), onEscape: () => ai.answer(Approval.skip)),
        if (ai.question != null)
          _cardShell(
            _QuestionCard(key: ValueKey(ai.question), c: c, ai: ai, ask: ai.question!, maxHeight: cardMax, mainFocus: cardFocus),
            onEscape: () => ai.answerQuestions([for (final _ in ai.question!.questions) '']),
          ),
        if (ai.planReview != null) _cardShell(_PlanCard(key: ValueKey(ai.planReview), c: c, ai: ai, review: ai.planReview!, maxHeight: cardMax, mainFocus: cardFocus)),
        if (ai.queued.isNotEmpty) _queued(),
        if (ai.attachments.isNotEmpty) _attachments(),
        if (ai.commandsFor(input.text).isNotEmpty) _commands(),
        // points and lines the user marks on the drawing for the assistant
        AiMarksBar(c: c, input: input),
        _inputBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            t('ai.footer', {'m': m.label, 'p': m.provider.company, 'h': m.provider.host}),
            style: TextStyle(fontSize: 10, color: Cad.fg54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _banner(IconData icon, String text, Key key, [List<Widget> actions = const []]) => Container(
    key: key,
    margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
    padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
    decoration: BoxDecoration(color: Cad.cardHigh, borderRadius: BorderRadius.circular(4)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Cad.warning),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5))),
          ],
        ),
        if (actions.isNotEmpty) Wrap(alignment: WrapAlignment.end, spacing: 4, children: actions),
      ],
    ),
  );

  Widget _todos() {
    final t = c.t;
    final done = ai.todos.where((x) => x.status == TodoStatus.done).length;
    return Container(
      key: const Key('ai_todos'),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Cad.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cad.divider),
      ),
      constraints: const BoxConstraints(maxHeight: 132),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('ai.todos', {'d': '$done', 'n': '${ai.todos.length}'}),
              style: TextStyle(fontSize: 10.5, color: Cad.fg54, fontWeight: FontWeight.w600),
            ),
            for (final x in ai.todos)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (x.status) {
                        TodoStatus.done => Icons.check_box,
                        TodoStatus.inProgress => Icons.indeterminate_check_box_outlined,
                        TodoStatus.pending => Icons.check_box_outline_blank,
                      },
                      size: 13,
                      color: switch (x.status) {
                        TodoStatus.done => Cad.ok,
                        TodoStatus.inProgress => Cad.accentText,
                        TodoStatus.pending => Cad.fg38,
                      },
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        x.content,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: x.status == TodoStatus.done ? Cad.fg38 : Cad.fg87,
                          fontWeight: x.status == TodoStatus.inProgress ? FontWeight.w600 : FontWeight.normal,
                          decoration: x.status == TodoStatus.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _queued() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(c.t('ai.queued'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final (k, q) in ai.queued.indexed)
              InputChip(
                key: Key('ai_queued_$k'),
                avatar: const Icon(Icons.schedule_send_outlined, size: 14),
                label: Text(q.length > 60 ? '${q.substring(0, 59)}…' : q, style: const TextStyle(fontSize: 11)),
                onDeleted: () => ai.unqueue(k),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _attachments() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final a in ai.attachments)
          InputChip(
            avatar: Icon(
              a.importOnly ? Icons.layers_outlined : (a.isImage ? Icons.image_outlined : (a.isPdf ? (a.asText ? Icons.notes : Icons.picture_as_pdf_outlined) : Icons.description_outlined)),
              size: 15,
            ),
            label: Text(
              '${a.name} (${(a.bytes.length / 1024).ceil()} KB · ${c.t('ai.attach.tokens', {'n': AiAssistant.aiTokensText(a.approxTokens)})})${a.isPdf ? ' · ${c.t(a.asText || a.pdfTooLarge ? 'ai.attach.asText' : 'ai.attach.asPdf')}' : (a.importOnly ? ' · ${c.t('ai.attach.import')}' : '')}',
              style: TextStyle(fontSize: 11, color: a.paged ? Cad.warning : null),
            ),
            // a long file: read in parts by the assistant, as needed
            tooltip: a.paged ? c.t('ai.attach.large', {'n': AiAssistant.aiTokensText(a.approxTokens)}) : (a.isPdf ? c.t(a.asText ? 'ai.attach.asPdf' : 'ai.attach.asText') : null),
            // a PDF goes whole, or as the text read on this device
            onPressed: a.isPdf ? () => setState(() => a.asText = !a.asText && a.pdfText != null) : null,
            onDeleted: () => ai.removeAttachment(a),
          ),
      ],
    ),
  );

  Widget _commands() {
    final t = c.t;
    final list = ai.commandsFor(input.text);
    return Container(
      key: const Key('ai_cmd_menu'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        color: Cad.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cad.divider),
      ),
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final x in list)
            InkWell(
              key: Key('ai_cmd_${x.name}'),
              onTap: () {
                input.text = '${x.label} ';
                input.selection = TextSelection.collapsed(offset: input.text.length);
                focus.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(x.label, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    ),
                    Expanded(
                      child: Text(t('ai.cmd.${x.name}'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The box on a line of its own, as wide as the panel, and its buttons on
  /// the line below: the attachments and the voice on one side, Send (or
  /// Queue and Stop) on the other. Beside the buttons, in a 400 px panel,
  /// the box had less than half the width.
  Widget _inputBar() {
    final t = c.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.enter): _enter, const SingleActivator(LogicalKeyboardKey.numpadEnter): _enter},
            child: TextField(
              key: const Key('ai_input'),
              controller: input,
              focusNode: focus,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: t(ai.busy ? 'ai.hint.busy' : 'ai.hint'), isDense: true),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            key: const Key('ai_input_buttons'),
            children: [
              IconButton(
                key: const Key('ai_attach'),
                tooltip: t('ai.attach'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.attach_file, size: 19),
                onPressed: ai.busy ? null : _attach,
              ),
              IconButton(
                key: const Key('ai_attach_view'),
                tooltip: t('ai.attach.view'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                onPressed: ai.busy ? null : _attachView,
              ),
              // speaking instead of typing (hidden where the browser has no dictation)
              AiVoiceButton(c: c, input: input, focus: focus),
              const Spacer(),
              if (ai.busy) ...[
                IconButton(key: const Key('ai_queue'), tooltip: t('ai.queue'), onPressed: _send, icon: const Icon(Icons.schedule_send_outlined, size: 18)),
                OutlinedButton.icon(
                  key: const Key('ai_stop'),
                  style: OutlinedButton.styleFrom(foregroundColor: Cad.unconnected),
                  onPressed: ai.stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 17),
                  label: Text(t('ai.stop')),
                ),
              ] else
                FilledButton.icon(key: const Key('ai_send'), onPressed: _send, icon: const Icon(Icons.send, size: 16), label: Text(t('ai.send'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notice(AiItem it) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    child: Text(
      it.text,
      key: const Key('ai_notice'),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Cad.fg54, fontStyle: FontStyle.italic),
    ),
  );

  Widget _userBubble(AiItem it, int index) {
    final t = c.t;
    final canRewind = it.checkpoint != null && !ai.busy;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: EdgeInsetsDirectional.only(start: widget.compact ? 24 : 64, bottom: 6, top: 2),
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
        decoration: BoxDecoration(
          color: it.steered ? Cad.panel : Cad.bubble,
          borderRadius: BorderRadius.circular(6),
          border: it.steered ? Border.all(color: Cad.divider) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (it.steered) Text(t('ai.steered'), style: TextStyle(fontSize: 10, color: Cad.fg54)),
            if (it.text.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: SelectableText(it.text, style: const TextStyle(fontSize: 12.5)),
              ),
            for (final a in it.attachments) Text('📎 $a', style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            if (it.contextTokens != null) Text(t('ai.sentData', {'n': '${it.contextTokens}'}), style: TextStyle(fontSize: 10, color: Cad.fg54)),
            if (canRewind)
              SizedBox(
                height: 22,
                child: TextButton.icon(
                  key: Key('ai_rewind_$index'),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
                  onPressed: () => _rewind(it),
                  icon: const Icon(Icons.history, size: 13),
                  label: Text(t('ai.rewind'), style: const TextStyle(fontSize: 10.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _answer(AiItem it) {
    final t = c.t;
    final secs = it.running && it.started != null ? DateTime.now().difference(it.started!).inSeconds : 0;
    return Container(
      margin: EdgeInsetsDirectional.only(end: widget.compact ? 8 : 40, bottom: 10, top: 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: Cad.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Cad.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final call in it.calls) _callRow(call),
          if (it.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: aiRichText(it.text)),
          if (it.running)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  // the status is announced when it changes; the clock that ticks every second is not
                  // (nodes of their own: merged, the clock would be in the live region's text)
                  Flexible(
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      child: Text(
                        it.status,
                        key: const Key('ai_status'),
                        style: TextStyle(fontSize: 11.5, color: Cad.fg60),
                      ),
                    ),
                  ),
                  if (secs >= 10)
                    Semantics(
                      container: true,
                      label: t('ai.status.elapsed', {'s': '$secs'}),
                      excludeSemantics: true,
                      child: Text(
                        ' · ${t('ai.elapsed', {'s': '$secs'})}',
                        key: const Key('ai_elapsed'),
                        style: TextStyle(fontSize: 11.5, color: Cad.fg60),
                      ),
                    ),
                ],
              ),
            ),
          if (it.stopped)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t('ai.stopped'), style: TextStyle(fontSize: 11.5, color: Cad.warning)),
            ),
          if (it.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  it.error!,
                  key: const Key('ai_error'),
                  style: TextStyle(fontSize: 12, color: Cad.unconnected),
                ),
              ),
            ),
          if (it.canContinue && !ai.busy && identical(it, ai.items.lastWhere((x) => x.kind == AiItemKind.assistant)))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(key: const Key('ai_continue'), onPressed: ai.continueTask, icon: const Icon(Icons.play_arrow, size: 16), label: Text(t('ai.continue'))),
            ),
          // after an error or a stop: try again (or go on), and open the settings when the fix is there
          if (it.retry != null && !it.canContinue && !ai.busy && identical(it, ai.items.lastWhere((x) => x.kind == AiItemKind.assistant)))
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('ai_retry'),
                  onPressed: () => ai.resume(it),
                  icon: Icon(it.retry!.kept ? Icons.play_arrow : Icons.refresh, size: 16),
                  label: Text(t(it.retry!.kept ? 'ai.continue' : 'ai.retry')),
                ),
                if (it.toSettings && widget.onSettings != null)
                  TextButton.icon(key: const Key('ai_err_settings'), onPressed: widget.onSettings, icon: const Icon(Icons.settings_outlined, size: 16), label: Text(t('ai.view.settings'))),
              ],
            ),
          if (it.changes != null && !it.changes!.isEmpty) _changes(it.changes!),
          if (it.servedBy != null) _servedBy(it.servedBy!),
          if (!it.running && (it.text.isNotEmpty || it.usage.totalInput > 0))
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                if (it.usage.totalInput > 0)
                  Text(
                    t('ai.usage', {'i': aiTokens(it.usage.totalInput), 'o': aiTokens(it.usage.output), 'c': _usd(it.cost)}) +
                        (it.pictures > 0 ? ' · ${t('ai.pictures', {'n': '${it.pictures}'})}' : ''),
                    style: TextStyle(fontSize: 10, color: Cad.fg54),
                  ),
                if (it.text.isNotEmpty) ...[
                  IconButton(
                    key: const Key('ai_copy'),
                    tooltip: t('ai.copy'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 15),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: it.text));
                      c.notify(t('ai.copied'));
                    },
                  ),
                  IconButton(
                    key: const Key('ai_insert_text'),
                    tooltip: t('ai.insert'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.text_fields, size: 16),
                    onPressed: () => _insertText(aiPlainText(it.text)),
                  ),
                ],
              ],
            ),
          // the costs and the cache by step
          if (!it.running && it.steps.isNotEmpty) AiStepCosts(key: ObjectKey(it), c: c, item: it),
        ],
      ),
    );
  }

  Widget _callRow(AgentToolCall call) {
    final failed = call.state == ToolCallState.failed;
    final (icon, color) = switch (call.state) {
      ToolCallState.running => (Icons.more_horiz, Cad.fg54),
      ToolCallState.waiting => (Icons.pan_tool_outlined, Cad.warning),
      ToolCallState.done => (call.isChange ? Icons.edit_outlined : Icons.visibility_outlined, Cad.ok),
      ToolCallState.failed => (Icons.error_outline, Cad.unconnected),
      ToolCallState.skipped => (Icons.block, Cad.fg38),
      ToolCallState.refused => (Icons.lock_outline, Cad.fg38),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Tooltip(
              message: failed ? call.result : '',
              child: Text(
                failed ? '${call.summary} — ${c.t('ai.call.failed')}' : call.summary,
                style: TextStyle(fontSize: 11, color: failed ? Cad.unconnected : Cad.fg60),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The model a fallback answered with, and its price.
  Widget _servedBy(String id) {
    final m = AiModel.all.where((x) => x.label == id || x.id == id).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        c.t('ai.servedBy', {'m': m?.label ?? id, 'p': m?.priceText ?? '?'}),
        key: const Key('ai_served_by'),
        style: TextStyle(fontSize: 10.5, color: Cad.warning),
      ),
    );
  }

  Widget _changes(AiTurnChanges ch) {
    final t = c.t;
    String list(Map<String, int> m) => [for (final e in m.entries) '${e.value} × ${e.key}'].join(', ');
    return Container(
      key: const Key('ai_changes'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Cad.tintInfo, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('ai.chg.title'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (ch.added.isNotEmpty) Text('+ ${list(ch.added)}', style: TextStyle(fontSize: 11, color: Cad.ok)),
          if (ch.changed.isNotEmpty) Text('~ ${list(ch.changed)}', style: TextStyle(fontSize: 11, color: Cad.accentText)),
          if (ch.removed.isNotEmpty) Text('− ${list(ch.removed)}', style: TextStyle(fontSize: 11, color: Cad.warning)),
          if (ch.settings.isNotEmpty) Text('${t('ai.chg.settings')}: ${ch.settings.join(', ')}', style: TextStyle(fontSize: 11, color: Cad.fg70)),
          if (ch.interleaved)
            Text(
              t('ai.chg.mixed'),
              key: const Key('ai_changes_mixed'),
              style: TextStyle(fontSize: 10.5, color: Cad.fg54),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ch.undone
                ? Text(t('ai.chg.undone'), style: TextStyle(fontSize: 11, color: Cad.fg54))
                : TextButton.icon(
                    key: const Key('ai_undo_turn'),
                    onPressed: ai.canUndo(ch) ? () => ai.undoTurn(ch) : null,
                    icon: const Icon(Icons.undo, size: 15),
                    label: Text(t('ai.chg.undo'), style: const TextStyle(fontSize: 11.5)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _approval(AiApproval p) {
    final t = c.t;
    final details = const JsonEncoder.withIndent('  ').convert(p.call.input);
    // a Material, not a coloured box: the expansion tile paints its ink on it
    return Padding(
      key: const Key('ai_approval'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Material(
        color: Cad.tintWarning,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Cad.warning.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(switch (p.call.effect) {
                  ToolEffect.export => 'ai.ask.export',
                  ToolEffect.network => 'ai.ask.network',
                  _ => 'ai.ask.change',
                }),
                style: TextStyle(fontSize: 11, color: Cad.warning),
              ),
              const SizedBox(height: 2),
              Text(
                p.call.summary,
                key: const Key('ai_approval_text'),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(t('ai.ask.details'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(details.length > 6000 ? '${details.substring(0, 6000)}…' : details, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: [
                  TextButton(key: const Key('ai_stop_all'), onPressed: () => ai.answer(Approval.stop), child: Text(t('ai.stop'))),
                  OutlinedButton(key: const Key('ai_skip'), onPressed: () => ai.answer(Approval.skip), child: Text(t('ai.ask.skip'))),
                  // in "ask": this change and the plain ones after it, without more cards
                  if (ai.taskPermission == AgentPermission.ask)
                    Tooltip(
                      message: t('ai.ask.applyRestHint'),
                      child: OutlinedButton(key: const Key('ai_apply_rest'), onPressed: ai.applyRest, child: Text(t('ai.ask.applyRest'))),
                    ),
                  Tooltip(
                    message: t('ai.ask.keys'),
                    child: FilledButton(key: const Key('ai_apply'), focusNode: cardFocus, onPressed: () => ai.answer(Approval.apply), child: Text(t('ai.ask.apply'))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The questions of ask_user: options to tap, a free answer, Send or Skip.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({super.key, required this.c, required this.ai, required this.ask, this.maxHeight = 420, this.mainFocus});
  final ProjectController c;

  /// The focus of Send (the card's main button).
  final FocusNode? mainFocus;

  /// Height the card may take (half of the conversation area).
  final double maxHeight;
  final AiAssistant ai;
  final AiAsk ask;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final picked = [for (final _ in widget.ask.questions) <int>{}];
  late final free = [for (final _ in widget.ask.questions) TextEditingController()];

  @override
  void dispose() {
    for (final f in free) {
      f.dispose();
    }
    super.dispose();
  }

  List<String> _answers() => [
    for (var k = 0; k < widget.ask.questions.length; k++)
      [for (final o in picked[k].toList()..sort()) widget.ask.questions[k].options[o].label, if (free[k].text.trim().isNotEmpty) free[k].text.trim()].join('; '),
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    final qs = widget.ask.questions;
    return Padding(
      key: const Key('ai_question'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Material(
        color: Cad.tintInfo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Cad.divider),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('ai.questions'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                for (final (k, q) in qs.indexed) ...[
                  const SizedBox(height: 6),
                  if (q.header.isNotEmpty)
                    Text(
                      q.header.toUpperCase(),
                      style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: Cad.fg54, fontWeight: FontWeight.bold),
                    ),
                  Text(q.question, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final (o, opt) in q.options.indexed)
                        Tooltip(
                          message: opt.description,
                          child: FilterChip(
                            key: Key('ai_question_opt_${k}_$o'),
                            label: Text(opt.label, style: const TextStyle(fontSize: 11.5)),
                            selected: picked[k].contains(o),
                            onSelected: (on) => setState(() {
                              if (!q.multi) picked[k].clear();
                              on ? picked[k].add(o) : picked[k].remove(o);
                            }),
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    key: Key('ai_question_text_$k'),
                    controller: free[k],
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(isDense: true, hintText: t('ai.questions.other')),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  children: [
                    TextButton(key: const Key('ai_question_skip'), onPressed: () => widget.ai.answerQuestions([for (final _ in qs) '']), child: Text(t('ai.questions.skip'))),
                    FilledButton(key: const Key('ai_question_send'), focusNode: widget.mainFocus, onPressed: () => widget.ai.answerQuestions(_answers()), child: Text(t('ai.questions.send'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plan of plan mode: approve it (and how changes then apply), or ask
/// for changes.
class _PlanCard extends StatefulWidget {
  const _PlanCard({super.key, required this.c, required this.ai, required this.review, this.maxHeight = 420, this.mainFocus});
  final ProjectController c;

  /// The focus of Approve (changes then wait for approval one by one: the
  /// safe choice for a key pressed by habit).
  final FocusNode? mainFocus;

  /// Height the card may take (half of the conversation area).
  final double maxHeight;
  final AiAssistant ai;
  final AiPlanReview review;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  final feedback = TextEditingController();

  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    return Padding(
      key: const Key('ai_plan'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Material(
        color: Cad.tintInfo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Cad.accent.withValues(alpha: 0.6)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('ai.plan.title'), style: TextStyle(fontSize: 11, color: Cad.accentText)),
                const SizedBox(height: 4),
                aiRichText(widget.review.plan, size: 12),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('ai_plan_feedback'),
                  controller: feedback,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(isDense: true, hintText: t('ai.plan.feedback')),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    TextButton(key: const Key('ai_plan_revise'), onPressed: () => widget.ai.decidePlan(PlanDecision.revise(feedback.text)), child: Text(t('ai.plan.revise'))),
                    OutlinedButton(
                      key: const Key('ai_plan_approve_ask'),
                      focusNode: widget.mainFocus,
                      onPressed: () => widget.ai.decidePlan(const PlanDecision.approved(AgentPermission.ask)),
                      child: Text(t('ai.plan.approveAsk')),
                    ),
                    FilledButton(
                      key: const Key('ai_plan_approve_auto'),
                      onPressed: () => widget.ai.decidePlan(const PlanDecision.approved(AgentPermission.auto)),
                      child: Text(t('ai.plan.approveAuto')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- data sent

class AiDataView extends StatelessWidget {
  const AiDataView({super.key, required this.c, required this.ai, required this.input});
  final ProjectController c;
  final AiAssistant ai;
  final TextEditingController input;

  Widget _box(String text, Key key) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Cad.background,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Cad.divider),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SelectableText(
        text,
        key: key,
        style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Cad.fg70),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final m = ai.model;
    final ctx = ai.previewContext();
    final next = ai.composeText(input.text.trim().isEmpty ? t('ai.preview.question') : input.text, ctx);
    return ScrollBody(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('ai.privacy', {'p': m.provider.company, 'h': m.provider.host, 'm': m.label}),
              key: const Key('ai_privacy'),
              style: TextStyle(fontSize: 12, color: Cad.fg70),
            ),
            const SizedBox(height: 4),
            Text(t('ai.vis.privacy'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  CheckboxListTile(
                    key: const Key('ai_attach_ctx'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: ai.attachContext,
                    onChanged: (v) {
                      ai.attachContext = v ?? false;
                      ai.refresh();
                    },
                    title: Text(t('ai.data.attach'), style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(t('ai.data.attachHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  ),
                  for (final p in ContextPart.values)
                    CheckboxListTile(
                      key: Key('ai_part_${p.name}'),
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 24),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: ai.parts.contains(p),
                      onChanged: ai.attachContext ? (v) => ai.setPart(p, v ?? false) : null,
                      title: Text(t('ai.part.${p.name}', {'n': '${c.selection.length}'}), style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ctx.isEmpty ? t('ai.data.none') : t('ai.data.size', {'n': '${ctx.approxTokens}'}),
              key: const Key('ai_data_size'),
              style: TextStyle(fontSize: 11.5, color: Cad.fg60),
            ),
            SectionTitle(t('ai.preview.title')),
            Text(
              t('ai.preview.hint', {'n': '${ai.historyLength}', 'm': m.label, 'p': m.provider.company, 'k': '${ai.toolbox.tools.length}', 'o': '${ai.toolbox.operations.length}'}),
              style: TextStyle(fontSize: 11, color: Cad.fg54),
            ),
            const SizedBox(height: 6),
            _box(next, const Key('ai_preview_text')),
            for (final a in ai.attachments)
              Text('📎 ${a.name} (${a.importOnly ? t('ai.attach.import') : a.mime}, ${(a.bytes.length / 1024).ceil()} KB)', style: TextStyle(fontSize: 11, color: Cad.fg60)),
            SectionTitle(t('ai.preview.system')),
            _box(ai.systemPrompt, const Key('ai_preview_system')),
            SectionTitle(t('ai.preview.tools')),
            Text(
              [for (final x in ai.toolbox.tools) x.name].join(', '),
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Cad.fg60),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- settings

class AiSettingsView extends StatefulWidget {
  const AiSettingsView({super.key, required this.c, required this.ai, this.onSaved});
  final ProjectController c;
  final AiAssistant ai;

  /// A key was saved (the host goes back to the conversation).
  final VoidCallback? onSaved;

  @override
  State<AiSettingsView> createState() => _AiSettingsViewState();
}

class _AiSettingsViewState extends State<AiSettingsView> {
  final keys = {for (final p in AiProvider.values) p: TextEditingController()};
  final show = <AiProvider>{};
  late final remember = {for (final p in AiProvider.values) p: widget.ai.remembers(p)};
  late final instructions = TextEditingController(text: widget.ai.instructions);
  late final notes = TextEditingController(text: widget.ai.notes);

  /// The project's AI notes are saved after a pause in typing (each save is
  /// an undo step of the project), and when the view closes.
  Timer? _notesTimer;

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;

  @override
  void dispose() {
    if (_notesTimer?.isActive ?? false) _saveNotes();
    _notesTimer?.cancel();
    for (final k in keys.values) {
      k.dispose();
    }
    instructions.dispose();
    notes.dispose();
    super.dispose();
  }

  void _saveNotes() {
    _notesTimer?.cancel();
    if (notes.text != ai.notes) ai.notes = notes.text;
  }

  /// The model a key of [p] starts with: the one last chosen of its
  /// company, else the app's default for it, otherwise that company's
  /// intermediate tier (never the dearest by chance).
  AiModel _defaultFor(AiProvider p) =>
      ai.lastModelOf(p) ??
      (AiModel.standard.provider == p
          ? AiModel.standard
          : AiModel.all.where((m) => m.provider == p && m.tier == AiTier.intermediate && m.listed && !m.earlier).firstOrNull ?? AiModel.all.firstWhere((m) => m.provider == p));

  void _saveKey(AiProvider p) {
    final k = keys[p]!.text.trim();
    if (k.isEmpty) return;
    // a key of another company in this field (told by how its keys start)
    final starts = AiProvider.ofKey(k);
    final other = starts != null && starts != p && !(p.keyPrefix.isNotEmpty && k.startsWith(p.keyPrefix) && p.keyPrefix.length >= starts.keyPrefix.length) ? starts : null;
    if (other != null) {
      c.notify(c.t('ai.key.wrongCompany', {'p': other.company}));
      return;
    }
    ai.saveKey(k, provider: p, remember: remember[p]!);
    keys[p]!.clear();
    show.remove(p);
    // with a key, the model goes to that company if the chosen one cannot run
    if (!ai.hasKey && ai.model.provider != p) {
      ai.model = _defaultFor(p);
      c.notify(c.t('ai.key.modelSet', {'m': ai.model.label}));
    }
    setState(() {});
    widget.onSaved?.call();
    if (p.keyPrefix.isNotEmpty && !k.startsWith(p.keyPrefix)) c.notify(c.t('ai.key.odd', {'p': p.company, 'x': p.keyPrefix}));
  }

  /// The companies, one chip each (a tick on those with a key): choosing one
  /// chooses its model (the one last used of it).
  Widget _providerPicker() {
    final t = c.t;
    final now = ai.model.provider;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        for (final p in AiProvider.values)
          ChoiceChip(
            key: Key('ai_provider_${p.name}'),
            label: Text(p.company, style: const TextStyle(fontSize: 12)),
            tooltip: ai.hasKeyFor(p) ? t('ai.provider.hasKey', {'p': '${p.company} (${p.family})'}) : (p.family == p.company ? p.company : '${p.company} (${p.family})'),
            avatar: ai.hasKeyFor(p) ? Icon(Icons.key, size: 14, color: Cad.ok) : null,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: p == now,
            onSelected: (_) {
              if (p != ai.model.provider) setState(() => ai.model = _defaultFor(p));
            },
          ),
      ],
    );
  }

  Widget _keySection(AiProvider p) {
    final t = c.t;
    final n = p.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(t('ai.key.title', {'p': p.company})),
        Text(t('ai.key.explain.$n'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
        TextButton.icon(onPressed: () => openExternalLink(p.keysUrl), icon: const Icon(Icons.open_in_new, size: 14), label: Text(t('ai.key.get', {'p': p.company}))),
        if (ai.hasKeyFor(p))
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Cad.ok),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t(ai.remembers(p) ? 'ai.key.saved' : 'ai.key.session', {'k': ai.masked(p)}), key: Key('ai_key_saved_$n'), style: const TextStyle(fontSize: 12)),
              ),
              TextButton(key: Key('ai_key_forget_$n'), onPressed: () => setState(() => ai.forgetKey(p)), child: Text(t('ai.key.forget'))),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('ai_key_field_$n'),
                controller: keys[p],
                obscureText: !show.contains(p),
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: t(ai.hasKeyFor(p) ? 'ai.key.replace' : 'ai.key.field'),
                  hintText: '${p.keyPrefix}…',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: t(show.contains(p) ? 'ai.key.hide' : 'ai.key.show'),
                    icon: Icon(show.contains(p) ? Icons.visibility_off : Icons.visibility, size: 16),
                    onPressed: () => setState(() => show.contains(p) ? show.remove(p) : show.add(p)),
                  ),
                ),
                onSubmitted: (_) => _saveKey(p),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(key: Key('ai_key_save_$n'), onPressed: () => _saveKey(p), child: Text(t('ai.key.save'))),
          ],
        ),
        CheckboxListTile(
          key: Key('ai_key_remember_$n'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(t('ai.key.remember'), style: const TextStyle(fontSize: 12)),
          value: remember[p],
          // a key already saved moves at once (into this device's storage, or out of it)
          onChanged: (v) => setState(() {
            remember[p] = v ?? false;
            final k = ai.keyOf(p);
            if (k != null) ai.saveKey(k, provider: p, remember: remember[p]!);
          }),
        ),
      ],
    );
  }

  String _tier(AiTier x) => c.t('ai.tier.${x.name}');

  /// The connection test of [m]: the button, and the result of the last
  /// test of this page.
  Widget _testRow(AiModel m) {
    final t = c.t;
    final p = AiAssistant.probes[m.id];
    final running = AiAssistant.probing.contains(m.id);
    final key = ai.hasKeyFor(m.provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('ai_test'),
            onPressed: !key || running
                ? null
                : () async {
                    await ai.testConnection(m);
                    if (mounted) setState(() {});
                  },
            icon: running ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_check, size: 16),
            label: Text(t('ai.test', {'m': m.label}), style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (!key)
          Text(t('ai.test.needKey', {'p': m.provider.company}), style: TextStyle(fontSize: 10.5, color: Cad.fg54))
        else if (p != null)
          Text(
            ai.probeText(p),
            key: const Key('ai_test_result'),
            style: TextStyle(fontSize: 11, color: p.ok ? Cad.ok : Cad.unconnected),
          )
        else
          Text(t('ai.test.hint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
      ],
    );
  }

  /// The system notifications of the call back: allowed, asked or refused
  /// by the browser (nothing where it has none).
  Widget _notifyRow() {
    final t = c.t;
    final p = AiAttention.permission;
    if (p == 'unsupported') return const SizedBox.shrink();
    if (p == 'granted') {
      return SwitchListTile(
        key: const Key('ai_notify'),
        dense: true,
        contentPadding: const EdgeInsetsDirectional.only(start: 16),
        value: AiAttention.notify,
        onChanged: (v) => setState(() => AiAttention.notify = v),
        title: Text(t('ai.attn.notify'), style: const TextStyle(fontSize: 12)),
      );
    }
    if (p == 'denied') {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, bottom: 4),
        child: Text(
          t('ai.attn.denied'),
          key: const Key('ai_notify_denied'),
          style: TextStyle(fontSize: 11, color: Cad.fg54),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const Key('ai_notify_allow'),
        onPressed: () async {
          await AiAttention.allowNotifications();
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.notifications_active_outlined, size: 16),
        label: Text(t('ai.attn.allow'), style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// The name of [x] in the picker (the company is chosen above it).
  static String _name(AiModel x) => x.label.replaceFirst(' (${x.provider.company})', '');

  /// The model picker: the models of the chosen company, each with its
  /// tier and price.
  Widget _modelPicker() {
    final t = c.t;
    final m = ai.model;
    final offered = AiModel.offered(m.provider);
    return DropdownButton<AiModel>(
      key: const Key('ai_model'),
      isExpanded: true,
      value: m,
      items: [
        // the chosen one first when it is no longer offered (a conversation's own model)
        for (final x in [if (!offered.contains(m)) m, ...offered])
          DropdownMenuItem<AiModel>(
            value: x,
            child: Text(
              [
                _name(x),
                _tier(x.tier),
                if (x.earlier) t('ai.model.earlier'),
                if (x.priced && (x.input > 0 || x.output > 0)) 'US\$ ${x.priceText}',
                if (x.freeTier) t('ai.model.freeTier'),
                if (identical(x, AiModel.standard)) t('ai.model.default'),
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (x) {
        if (x != null) setState(() => ai.model = x);
      },
    );
  }

  String _modelHint(AiModel m) {
    final t = c.t;
    String usd(double v) => v.toStringAsFixed(v > 0 && v < 0.1 ? 3 : 2);
    final f = m.priceFactor;
    final ends = m.introEnds;
    return [
      if (!m.priced) t('ai.model.router') else t('ai.model.price', {'t': _tier(m.tier), 'i': usd(m.input * f), 'o': usd(m.output * f), 'r': usd(m.cacheRead * f), 'w': usd(m.cacheWrite * f)}),
      if (ends != null) t('ai.model.intro', {'d': ends.toIso8601String().substring(0, 10), 'i': usd(m.input), 'o': usd(m.output)}),
      if (m.freeTier) t('ai.model.freeHint'),
      if (!m.vision) t('ai.model.noVision'),
      if (m.longAbove > 0) t('ai.model.long', {'n': '${m.longAbove ~/ 1000}', 'a': '${m.longInput}'.replaceFirst('.0', ''), 'b': '${m.longOutput}'.replaceFirst('.0', '')}),
      if (m.longTurns) t('ai.model.longTurns'),
      if (m.needsRetention) t('ai.model.retention'),
      if (m.earlier) t('ai.model.earlierHint'),
      t('ai.model.to', {'p': m.provider.company, 'h': m.provider.host}),
      if (m.provider == AiProvider.openrouter) t('ai.model.via'),
      if (ai.switchStartsAnew(m)) t('ai.model.newConv'),
      ?ai.switchCostText(m),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final m = ai.model;
    // the keys of the other companies stay in reach while they are saved (to replace or forget them)
    final other = AiProvider.values.where((p) => p != m.provider && ai.hasKeyFor(p));
    final noKey = !AiProvider.values.any(ai.hasKeyFor);
    return ScrollBody(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // without any key, the settings say first that one is enough
            if (noKey) Text(t('ai.key.oneEnough'), key: const Key('ai_key_one'), style: const TextStyle(fontSize: 12.5)),
            SectionTitle(t('ai.provider')),
            _providerPicker(),
            // without any key, the key of the chosen company comes before its models
            if (noKey) _keySection(m.provider),
            SectionTitle(t('ai.model')),
            _modelPicker(),
            Text(
              _modelHint(m),
              key: const Key('ai_model_hint'),
              style: TextStyle(fontSize: 10.5, color: Cad.fg54),
            ),
            Text(t('ai.model.switch'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            // 1.6.0 IA: a connection test of the model chosen (one small request)
            _testRow(m),
            // the key of the chosen model's company first
            if (!noKey) ...[_keySection(m.provider), for (final p in other) _keySection(p)],
            Text(t('ai.key.privacy'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            SectionTitle(t('ai.effort')),
            DropdownButton<AiEffort>(
              key: const Key('ai_effort'),
              isExpanded: true,
              value: ai.effort,
              items: [
                for (final e in AiEffort.values)
                  DropdownMenuItem(
                    value: e,
                    child: Text(t('ai.effort.${e.name}'), style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (e) => setState(() => ai.effort = e ?? ai.effort),
            ),
            if (m.perMessageEffort)
              Text(
                t('ai.effort.hint'),
                key: const Key('ai_effort_hint'),
                style: TextStyle(fontSize: 10.5, color: Cad.fg54),
              ),
            // 1.6.0 IA: the effort follows the stage of the task (Claude, through effort messages)
            if (m.perMessageEffort && m.provider == AiProvider.anthropic)
              SwitchListTile(
                key: const Key('ai_stage_effort'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ai.stageEffort,
                onChanged: (v) => setState(() => ai.stageEffort = v),
                title: Text(t('ai.stageEffort'), style: const TextStyle(fontSize: 12.5)),
                subtitle: Text(t('ai.stageEffort.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
              ),
            SectionTitle(t('ai.mode')),
            RadioGroup<AgentPermission>(
              groupValue: ai.permission,
              onChanged: (v) => setState(() => ai.permission = v ?? ai.permission),
              child: Column(
                children: [
                  for (final p in AgentPermission.values)
                    RadioListTile<AgentPermission>(
                      key: Key('ai_mode_${p.name}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: p,
                      title: Text(t('ai.mode.${p.name}'), style: const TextStyle(fontSize: 12.5)),
                      subtitle: Text(t('ai.mode.${p.name}.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                    ),
                ],
              ),
            ),
            SectionTitle(t('ai.limits')),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${t('ai.steps')}: ', style: const TextStyle(fontSize: 12)),
                    DropdownButton<int>(
                      key: const Key('ai_steps'),
                      value: AiAssistant.stepChoices.contains(ai.maxSteps) ? ai.maxSteps : 50,
                      items: [
                        for (final n in AiAssistant.stepChoices)
                          DropdownMenuItem(
                            value: n,
                            child: Text('$n', style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                      onChanged: (n) => setState(() => ai.maxSteps = n ?? 50),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${t('ai.cap')}: ', style: const TextStyle(fontSize: 12)),
                    DropdownButton<double>(
                      key: const Key('ai_cap'),
                      value: AiAssistant.capChoices.contains(ai.costCap) ? ai.costCap : 2.0,
                      items: [
                        for (final v in AiAssistant.capChoices)
                          DropdownMenuItem(
                            value: v,
                            child: Text(v == 0 ? t('ai.cap.none') : 'US\$ ${v.toStringAsFixed(v < 1 ? 2 : 0)}', style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                      onChanged: (v) => setState(() => ai.costCap = v ?? 2.0),
                    ),
                  ],
                ),
              ],
            ),
            Text(t('ai.limits.hint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            SwitchListTile(
              key: const Key('ai_compact'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: ai.compaction,
              onChanged: (v) => setState(() => ai.compaction = v),
              title: Text(t('ai.compact'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.compact.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
            if (m.provider == AiProvider.anthropic)
              SwitchListTile(
                key: const Key('ai_keep_warm'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ai.keepWarm,
                onChanged: (v) => setState(() => ai.keepWarm = v),
                title: Text(t('ai.keepWarm'), style: const TextStyle(fontSize: 12.5)),
                subtitle: Text(t('ai.keepWarm.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
              ),
            SwitchListTile(
              key: const Key('ai_show_changes'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: ai.showChanges,
              onChanged: (v) => setState(() => ai.showChanges = v),
              title: Text(t('ai.showChanges'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.showChanges.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
            SwitchListTile(
              key: const Key('ai_ask_start'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: AiAssistant.askAtStart,
              onChanged: (v) => setState(() => AiAssistant.askAtStart = v),
              title: Text(t('ai.askStart'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.askStart.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
            // 1.6.0 IA: a task that waits or ends while the app is in the background
            SwitchListTile(
              key: const Key('ai_attention'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: AiAttention.enabled,
              onChanged: (v) => setState(() => AiAttention.enabled = v),
              title: Text(t('ai.attn.setting'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.attn.setting.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
            if (AiAttention.enabled) _notifyRow(),
            // conversations kept in this browser (IndexedDB), by project
            SwitchListTile(
              key: const Key('ai_keep'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: AiAssistant.keepConversations,
              onChanged: (v) => setState(() => AiAssistant.keepConversations = v),
              title: Text(t('ai.keep'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.keep.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('ai_keep_delete'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t('ai.keep.delete')),
                      content: Text(t('ai.keep.deleteConfirm')),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('cancel'))),
                        FilledButton(key: const Key('ai_keep_delete_ok'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t('ai.keep.delete'))),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await AiAssistant.deleteSavedConversations();
                  c.notify(t('ai.keep.deleted'));
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(t('ai.keep.delete'), style: const TextStyle(fontSize: 12)),
              ),
            ),
            SectionTitle(t('ai.instructions')),
            Text(t('ai.instructions.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            TextField(
              key: const Key('ai_instructions'),
              controller: instructions,
              minLines: 2,
              maxLines: 6,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(isDense: true, hintText: t('ai.instructions.example')),
              onChanged: (v) => ai.instructions = v,
            ),
            SectionTitle(t('ai.notes')),
            Text(t('ai.notes.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            TextField(
              key: const Key('ai_notes'),
              controller: notes,
              minLines: 2,
              maxLines: 8,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) {
                _notesTimer?.cancel();
                _notesTimer = Timer(const Duration(milliseconds: 1200), _saveNotes);
              },
              onEditingComplete: _saveNotes,
              onTapOutside: (_) => _saveNotes(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  key: const Key('ai_transcript'),
                  onPressed: ai.items.isEmpty ? null : ai.saveTranscript,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(t('ai.transcript.save')),
                ),
                // 1.6.0 IA: the project's conversations, and a conversation to or from a file
                OutlinedButton.icon(key: const Key('ai_conv_list'), onPressed: () => showAiConversations(context, c, ai), icon: const Icon(Icons.history, size: 16), label: Text(t('ai.conv.title'))),
                OutlinedButton.icon(
                  key: const Key('ai_conv_export_file'),
                  onPressed: ai.busy || !ai.items.any((it) => it.kind != AiItemKind.notice) ? null : () => aiExportConversation(c, ai),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(t('ai.conv.export')),
                ),
                OutlinedButton.icon(
                  key: const Key('ai_conv_import_file'),
                  onPressed: ai.busy
                      ? null
                      : () async {
                          await aiImportConversation(c, ai);
                          if (mounted) setState(() {});
                        },
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: Text(t('ai.conv.import')),
                ),
                OutlinedButton.icon(
                  key: const Key('ai_clear'),
                  onPressed: ai.items.isEmpty
                      ? null
                      : () async {
                          if (await aiConfirmNew(context, c, ai) && mounted) setState(ai.clear);
                        },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(t('ai.clear')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t('ai.privacy', {'p': m.provider.company, 'h': m.provider.host, 'm': m.label}), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            const SizedBox(height: 4),
            Text(t('ai.vis.privacy'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
          ],
        ),
      ),
    );
  }
}
