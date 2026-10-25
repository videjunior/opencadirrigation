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
import 'package:flutter/services.dart';

import '../../../core/ai/agent_loop.dart';
import '../../../core/ai/project_context.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../ai/agent_tools_agent.dart';
import '../../ai/ai_assistant.dart';
import '../../io/file_io.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';

/// Light Markdown: headings, bullets, **bold** and `code`.
Widget aiRichText(String text, {double size = 12.5}) {
  final base = TextStyle(fontSize: size, height: 1.35);
  final spans = <InlineSpan>[];
  final inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  void line(String s, TextStyle style) {
    var i = 0;
    for (final m in inline.allMatches(s)) {
      if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start), style: style));
      spans.add(
        m.group(1) != null
            ? TextSpan(
                text: m.group(1),
                style: style.copyWith(fontWeight: FontWeight.bold),
              )
            : TextSpan(
                text: m.group(2),
                style: style.copyWith(fontFamily: 'monospace', color: Cad.codeText),
              ),
      );
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i), style: style));
  }

  final lines = text.split('\n');
  for (var k = 0; k < lines.length; k++) {
    final l = lines[k];
    final h = RegExp(r'^#{1,6}\s+').firstMatch(l);
    if (h != null) {
      line(l.substring(h.end), base.copyWith(fontWeight: FontWeight.bold, fontSize: size + 1));
    } else if (RegExp(r'^\s*[-*]\s+').hasMatch(l)) {
      line(l.replaceFirst(RegExp(r'^(\s*)[-*]\s+'), r'$1• '), base);
    } else {
      line(l, base);
    }
    if (k < lines.length - 1) spans.add(const TextSpan(text: '\n'));
  }
  return SelectableText.rich(TextSpan(children: spans), style: base);
}

String aiTokens(int n) => n < 1000 ? '$n' : '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';

String _usd(double v) => v.toStringAsFixed(v < 1 ? 3 : 2);

/// The meter line: tokens, pictures and the estimated cost.
String aiMeterText(ProjectController c, AiAssistant ai) => ai.usage.totalInput == 0
    ? '${ai.model.label} · ${c.t('ai.mode.${ai.permission.name}')}'
    : c.t('ai.meter', {'i': aiTokens(ai.usage.totalInput), 'o': aiTokens(ai.usage.output), 'c': _usd(ai.cost)}) + (ai.pictures > 0 ? ' · ${c.t('ai.pictures', {'n': '${ai.pictures}'})}' : '');

/// Files a message can carry (images, PDFs, text) and drawings to import.
const aiAttachAccept = '.pdf,.png,.jpg,.jpeg,.webp,.gif,.txt,.csv,.tsv,.json,.md,.dxf,.dwg,.dgn,.kml,.kmz,.shp,.zip,.geojson,.gpx,.xml,.landxml,.ifc,.inp,.las,.tif,.tiff';

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

class _AiChatViewState extends State<AiChatView> {
  final scroll = ScrollController();
  final focus = FocusNode();
  int _seen = 0;
  Timer? _clock;

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;
  TextEditingController get input => widget.input;

  @override
  void initState() {
    super.initState();
    ai.addListener(_follow);
    input.addListener(_typed);
    _follow();
  }

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
    ai.removeListener(_follow);
    input.removeListener(_typed);
    _clock?.cancel();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  void _typed() => setState(() {});

  /// Keeps the newest text in view while it streams in; puts a rewound
  /// message back in the box; ticks the clock of long answers.
  void _follow() {
    final back = ai.rewound;
    if (back != null) {
      ai.rewound = null;
      input.text = back;
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

  void _send() {
    final q = input.text;
    if (q.trim().isEmpty && (ai.busy || ai.attachments.isEmpty)) return;
    input.clear();
    ai.send(q);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> _attach() async {
    final f = await openBinaryFile(accept: aiAttachAccept);
    if (f == null) return;
    final mime = AiAttachment.mimeOf(f.$1);
    final a = mime == null ? null : AiAttachment(f.$1, mime, f.$2);
    if (a == null || f.$2.length > a.limit) {
      c.notify(c.t('ai.attach.bad'));
      return;
    }
    ai.addAttachment(a);
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
  Widget build(BuildContext context) {
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (k, q) in _starters().indexed)
                              ActionChip(
                                key: Key('ai_starter_$k'),
                                label: Text(q, style: const TextStyle(fontSize: 11.5)),
                                onPressed: () => setState(() => input.text = q),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(t('ai.cmd.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
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
        ),
        if (ai.pending != null) _approval(ai.pending!),
        if (ai.question != null) _QuestionCard(key: ValueKey(ai.question), c: c, ai: ai, ask: ai.question!),
        if (ai.planReview != null) _PlanCard(key: ValueKey(ai.planReview), c: c, ai: ai, review: ai.planReview!),
        if (ai.queued.isNotEmpty) _queued(),
        if (ai.attachments.isNotEmpty) _attachments(),
        if (ai.commandsFor(input.text).isNotEmpty) _commands(),
        _inputBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            t('ai.footer', {'m': m.label, 'p': m.provider.company, 'h': m.provider.host}),
            style: TextStyle(fontSize: 10, color: Cad.fg38),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

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
              '${a.name} (${(a.bytes.length / 1024).ceil()} KB)${a.isPdf ? ' · ${c.t(a.asText ? 'ai.attach.asText' : 'ai.attach.asPdf')}' : (a.importOnly ? ' · ${c.t('ai.attach.import')}' : '')}',
              style: const TextStyle(fontSize: 11),
            ),
            tooltip: a.isPdf ? c.t(a.asText ? 'ai.attach.asPdf' : 'ai.attach.asText') : null,
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

  Widget _inputBar() {
    final t = c.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(key: const Key('ai_attach'), tooltip: t('ai.attach'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.attach_file, size: 19), onPressed: ai.busy ? null : _attach),
          IconButton(
            key: const Key('ai_attach_view'),
            tooltip: t('ai.attach.view'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
            onPressed: ai.busy ? null : _attachView,
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
              child: TextField(
                key: const Key('ai_input'),
                controller: input,
                focusNode: focus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(hintText: t(ai.busy ? 'ai.hint.busy' : 'ai.hint'), isDense: true),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(left: widget.compact ? 24 : 64, bottom: 6, top: 2),
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
                padding: const EdgeInsets.only(right: 4),
                child: SelectableText(it.text, style: const TextStyle(fontSize: 12.5)),
              ),
            for (final a in it.attachments) Text('📎 $a', style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            if (it.contextTokens != null) Text(t('ai.sentData', {'n': '${it.contextTokens}'}), style: TextStyle(fontSize: 10, color: Cad.fg38)),
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
      margin: EdgeInsets.only(right: widget.compact ? 8 : 40, bottom: 10, top: 2),
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
                  Flexible(
                    child: Text(
                      secs >= 10 ? '${it.status} · ${t('ai.elapsed', {'s': '$secs'})}' : it.status,
                      key: const Key('ai_status'),
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
              child: Text(
                it.error!,
                key: const Key('ai_error'),
                style: TextStyle(fontSize: 12, color: Cad.unconnected),
              ),
            ),
          if (it.canContinue && !ai.busy && identical(it, ai.items.lastWhere((x) => x.kind == AiItemKind.assistant)))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(key: const Key('ai_continue'), onPressed: ai.continueTask, icon: const Icon(Icons.play_arrow, size: 16), label: Text(t('ai.continue'))),
            ),
          if (it.changes != null && !it.changes!.isEmpty) _changes(it.changes!),
          if (!it.running && (it.text.isNotEmpty || it.usage.totalInput > 0))
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                if (it.usage.totalInput > 0)
                  Text(
                    t('ai.usage', {'i': aiTokens(it.usage.totalInput), 'o': aiTokens(it.usage.output), 'c': _usd(it.cost)}) +
                        (it.pictures > 0 ? ' · ${t('ai.pictures', {'n': '${it.pictures}'})}' : ''),
                    style: TextStyle(fontSize: 10, color: Cad.fg38),
                  ),
                if (it.text.isNotEmpty) ...[
                  IconButton(
                    key: const Key('ai_copy'),
                    tooltip: t('ai.copy'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 15),
                    onPressed: () => Clipboard.setData(ClipboardData(text: it.text)),
                  ),
                  IconButton(
                    key: const Key('ai_insert_text'),
                    tooltip: t('ai.insert'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.text_fields, size: 16),
                    onPressed: () => _insertText(it.text),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _callRow(AgentToolCall call) {
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
            child: Text(
              call.state == ToolCallState.failed ? '${call.summary} — ${call.result}' : call.summary,
              style: TextStyle(fontSize: 11, color: call.state == ToolCallState.failed ? Cad.unconnected : Cad.fg60),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          Align(
            alignment: Alignment.centerRight,
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
                        child: SelectableText(details.length > 6000 ? '${details.substring(0, 6000)}…' : details, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
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
                  FilledButton(key: const Key('ai_apply'), onPressed: () => ai.answer(Approval.apply), child: Text(t('ai.ask.apply'))),
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
  const _QuestionCard({super.key, required this.c, required this.ai, required this.ask});
  final ProjectController c;
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
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
                    FilledButton(key: const Key('ai_question_send'), onPressed: () => widget.ai.answerQuestions(_answers()), child: Text(t('ai.questions.send'))),
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
  const _PlanCard({super.key, required this.c, required this.ai, required this.review});
  final ProjectController c;
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
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
    child: SelectableText(
      text,
      key: key,
      style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Cad.fg70),
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

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;

  @override
  void dispose() {
    for (final k in keys.values) {
      k.dispose();
    }
    instructions.dispose();
    notes.dispose();
    super.dispose();
  }

  void _saveKey(AiProvider p) {
    final k = keys[p]!.text.trim();
    if (k.isEmpty) return;
    ai.saveKey(k, provider: p, remember: remember[p]!);
    keys[p]!.clear();
    show.remove(p);
    // with a key, the model goes to that company if the chosen one cannot run
    if (!ai.hasKey && ai.model.provider != p) ai.model = AiModel.all.firstWhere((m) => m.provider == p);
    setState(() {});
    widget.onSaved?.call();
    if (!k.startsWith(p.keyPrefix)) c.notify(c.t('ai.key.odd', {'p': p.company, 'x': p.keyPrefix}));
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
          onChanged: (v) => setState(() => remember[p] = v ?? false),
        ),
      ],
    );
  }

  String _tier(AiTier x) => c.t('ai.tier.${x.name}');

  /// The model picker: grouped by company, each with its tier and price.
  Widget _modelPicker() {
    final t = c.t;
    final m = ai.model;
    return DropdownButton<AiModel>(
      key: const Key('ai_model'),
      isExpanded: true,
      value: m,
      items: [
        for (final p in AiProvider.values) ...[
          DropdownMenuItem<AiModel>(
            enabled: false,
            child: Text(
              p.company.toUpperCase(),
              style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.bold, color: Cad.fg54),
            ),
          ),
          for (final x in AiModel.all.where((x) => x.provider == p && x.listed))
            DropdownMenuItem<AiModel>(
              value: x,
              child: Text(
                '${x.label} · ${_tier(x.tier)}${x.earlier ? ' · ${t('ai.model.earlier')}' : ''} · US\$ ${x.priceText}${identical(x, AiModel.standard) ? ' · ${t('ai.model.default')}' : ''}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ],
      onChanged: (x) {
        if (x != null) setState(() => ai.model = x);
      },
    );
  }

  String _modelHint(AiModel m) {
    final t = c.t;
    String usd(double v) => v.toStringAsFixed(v < 0.1 ? 3 : 2);
    return [
      t('ai.model.price', {'t': _tier(m.tier), 'i': usd(m.input), 'o': usd(m.output), 'r': usd(m.cacheRead), 'w': usd(m.cacheWrite)}),
      if (m.longAbove > 0) t('ai.model.long', {'n': '${m.longAbove ~/ 1000}', 'a': '${m.longInput}'.replaceFirst('.0', ''), 'b': '${m.longOutput}'.replaceFirst('.0', '')}),
      if (m.longTurns) t('ai.model.longTurns'),
      if (m.needsRetention) t('ai.model.retention'),
      if (m.earlier) t('ai.model.earlierHint'),
      t('ai.model.to', {'p': m.provider.company, 'h': m.provider.host}),
      if (ai.switchStartsAnew(m)) t('ai.model.newConv'),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final m = ai.model;
    final other = AiProvider.values.where((p) => p != m.provider);
    return ScrollBody(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(t('ai.model')),
            _modelPicker(),
            Text(
              _modelHint(m),
              key: const Key('ai_model_hint'),
              style: TextStyle(fontSize: 10.5, color: Cad.fg54),
            ),
            Text(t('ai.model.switch'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
            // the key of the chosen model's company first
            _keySection(m.provider),
            for (final p in other) _keySection(p),
            Text(t('ai.key.privacy'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
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
            Text(t('ai.limits.hint'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
            SwitchListTile(
              key: const Key('ai_compact'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: ai.compaction,
              onChanged: (v) => setState(() => ai.compaction = v),
              title: Text(t('ai.compact'), style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(t('ai.compact.hint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
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
              onChanged: (v) => ai.notes = v,
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
                OutlinedButton.icon(
                  key: const Key('ai_clear'),
                  onPressed: ai.items.isEmpty ? null : () => setState(ai.clear),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(t('ai.clear')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t('ai.privacy', {'p': m.provider.company, 'h': m.provider.host, 'm': m.label}), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            const SizedBox(height: 4),
            Text(t('ai.vis.privacy'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
          ],
        ),
      ),
    );
  }
}
