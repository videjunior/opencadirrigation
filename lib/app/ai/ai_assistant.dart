/// The AI assistant of a project tab: the conversation with the model the
/// user chose — Claude through the user's own Anthropic key or GPT through
/// the user's own OpenAI key, straight from this browser or desktop, no
/// server in between — the tools that let it read and change the project,
/// approvals, the plan and the to-do list, questions to the user, messages
/// typed while it works, checkpoints with rewind, the spending cap and the
/// token meter, the project's AI notes, and the undo of what it changed.
///
/// Nothing is sent before the user sends a message. Each key goes only to
/// its own provider's API; it stays in memory for the session unless the
/// user ticks "Remember the key on this device" (then it is kept in this
/// browser's storage), and it never enters the project, its autosave, share
/// links or exports.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/ai/agent_loop.dart';
import '../../core/ai/claude_api.dart';
import '../../core/ai/openai_api.dart';
import '../../core/ai/project_context.dart';
import '../../core/io/pdf_reader.dart';
import '../../core/model/entities.dart';
import '../../core/model/project.dart';
import '../i18n.dart';
import '../io/file_io.dart';
import '../io/prefs.dart';
import '../state/controller.dart';
import '../state/workspace.dart';
import 'agent_tools.dart';
import 'agent_tools_agent.dart';
import 'agent_tools_vision.dart';
import 'ai_prompt.dart';
import 'ai_transport.dart';
import 'ops_cad_view.dart' show AiTab, AiWorkspaceHost;
import 'view_snapshot.dart';

/// A file the user attached to the next message (a data sheet, a photo, a
/// picture of the view, a drawing to import).
class AiAttachment {
  AiAttachment(this.name, this.mime, this.bytes, {this.note = ''});
  final String name;
  final String mime;
  final Uint8List bytes;

  /// Text that goes with the file (the pixel ↔ world mapping of a picture
  /// of the view).
  final String note;

  /// Largest file the model reads, and largest file only imported.
  static const maxBytes = 20 * 1024 * 1024;
  static const maxImportBytes = 60 * 1024 * 1024;

  /// Media type of the drawing and GIS files that are imported, not read.
  static const importMime = 'application/x-import';
  static const importable = {'dxf', 'dwg', 'dgn', 'kml', 'kmz', 'shp', 'zip', 'geojson', 'gpx', 'xml', 'landxml', 'ifc', 'inp', 'las', 'tif', 'tiff'};

  bool get isImage => mime.startsWith('image/');
  bool get isPdf => mime == 'application/pdf';

  /// Not sent to the model: it learns the file is there and imports it with
  /// import_attachment.
  bool get importOnly => mime == importMime;
  int get limit => importOnly ? maxImportBytes : maxBytes;

  /// Send the text of the PDF read on this device instead of the file:
  /// far fewer tokens, but tables lose their figures and layout.
  bool asText = false;
  String? _text;
  bool _read = false;

  /// The text of the PDF (read once, on demand); null when it has none or
  /// cannot be read (scans, encryption).
  String? get pdfText {
    if (!_read) {
      _read = true;
      _text = isPdf ? pdfToText(bytes) : null;
    }
    return _text;
  }

  /// Media type from the file name; null when the file cannot be used.
  static String? mimeOf(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'txt' || 'csv' || 'tsv' || 'md' || 'json' => 'text/plain',
      _ => importable.contains(ext) ? importMime : null,
    };
  }

  /// What goes into the message.
  List<AiPart> parts() {
    if (importOnly) {
      return [
        AiTextPart(
          '<attachment name="$name" size="${(bytes.length / 1024).ceil()} KB">A drawing or GIS file for the project, not shown to you: import it with import_attachment {"name": "$name"} when the user wants it in the project.</attachment>',
        ),
      ];
    }
    if (isImage) return [AiImagePart(mime, base64Encode(bytes)), if (note.isNotEmpty) AiTextPart(note)];
    if (isPdf && asText && pdfText != null) return [AiTextPart('<attachment name="$name" content="text extracted from the PDF">\n$pdfText\n</attachment>')];
    if (isPdf) return [AiPdfPart(name, base64Encode(bytes))];
    return [AiTextPart('<attachment name="$name">\n${utf8.decode(bytes, allowMalformed: true)}\n</attachment>')];
  }
}

/// The text of a PDF, page by page, its runs ordered top to bottom and
/// left to right, one line per baseline (cells joined by tabs); at most
/// [maxPages] pages and [maxChars] characters. Null when nothing readable.
String? pdfToText(Uint8List bytes, {int maxPages = 40, int maxChars = 80000}) {
  try {
    final r = PdfReader.open(bytes);
    final out = StringBuffer();
    for (var i = 0; i < r.pageCount && i < maxPages && out.length < maxChars; i++) {
      final runs = [
        for (final t in r.readPage(i, vectors: false, images: false).texts)
          if (!t.hidden && t.text.trim().isNotEmpty) t,
      ]..sort((a, b) => a.origin.y != b.origin.y ? b.origin.y.compareTo(a.origin.y) : a.origin.x.compareTo(b.origin.x));
      if (runs.isEmpty) continue;
      out.writeln('--- page ${i + 1}');
      final line = <PdfTextItem>[];
      void flush() {
        line.sort((a, b) => a.origin.x.compareTo(b.origin.x));
        out.writeln(line.map((t) => t.text.trim()).join('\t'));
        line.clear();
      }

      for (final t in runs) {
        if (line.isNotEmpty && (line.first.origin.y - t.origin.y).abs() > 0.5 * (line.first.height > 0 ? line.first.height : 1)) flush();
        line.add(t);
      }
      if (line.isNotEmpty) flush();
    }
    final s = out.toString().trim();
    if (s.isEmpty) return null;
    return s.length <= maxChars ? s : '${s.substring(0, maxChars)}\n… (cut at $maxChars characters)';
  } catch (_) {
    return null;
  }
}

/// What the AI changed in one turn (by kind of item, and which settings).
class AiTurnChanges {
  AiTurnChanges({required this.added, required this.changed, required this.removed, required this.settings, required this.endIndex, required this.steps});
  final Map<String, int> added, changed, removed;
  final List<String> settings;

  /// History position after the turn and the undo steps it made.
  final int endIndex, steps;
  bool undone = false;
  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty && settings.isEmpty;
}

/// Where the conversation and the project stood before a message: the
/// rewind goes back there.
class AiCheckpoint {
  AiCheckpoint({required this.history, required this.items, required this.index, this.label, this.time});

  /// Entries of the conversation and items of the transcript before it.
  final int history, items;

  /// The project's history position then, and that state's fingerprint
  /// (the label and time of the step that led to it): the position moves
  /// when old steps are dropped, the fingerprint does not.
  final int index;
  final String? label;
  final DateTime? time;
}

enum AiItemKind { user, assistant, notice }

/// One entry of the conversation as the panel shows it.
class AiItem {
  AiItem.user(this.text, {this.attachments = const [], this.contextTokens, this.steered = false}) : kind = AiItemKind.user;
  AiItem.assistant() : kind = AiItemKind.assistant, text = '', attachments = const [], contextTokens = null, steered = false;
  AiItem.notice(this.text) : kind = AiItemKind.notice, attachments = const [], contextTokens = null, steered = false;
  final AiItemKind kind;
  String text;
  final List<String> attachments;

  /// Approximate size of the project data sent with the message.
  final int? contextTokens;

  /// Written while the assistant worked; it reached the model with the
  /// next round of tool results.
  final bool steered;

  /// Where things stood before this message (user messages).
  AiCheckpoint? checkpoint;
  final List<AgentToolCall> calls = [];
  bool running = false;
  String status = '';

  /// When the answer started (the elapsed time of long turns).
  DateTime? started;

  /// Translated reason the answer stopped early.
  String? error;

  /// The turn stopped at the step limit or the spending cap: it can go on.
  bool canContinue = false;
  bool stopped = false;
  AiUsage usage = AiUsage.zero;
  double cost = 0;

  /// Pictures sent in the turn (they count in the input tokens).
  int pictures = 0;
  String model = '';
  AiTurnChanges? changes;
}

/// A change awaiting the user's approval.
class AiApproval {
  AiApproval(this.call);
  final AgentToolCall call;
  final Completer<Approval> done = Completer<Approval>();
}

/// Questions of ask_user awaiting the answers.
class AiAsk {
  AiAsk(this.questions);
  final List<AiQuestion> questions;
  final Completer<List<String>?> done = Completer<List<String>?>();
}

/// A plan awaiting the user's decision.
class AiPlanReview {
  AiPlanReview(this.plan);
  final String plan;
  final Completer<PlanDecision?> done = Completer<PlanDecision?>();
}

/// Where a project's AI notes live: in the project file ([ProjectNotesStore],
/// the app's choice) or on this device by project id ([DeviceNotesStore]).
abstract class AiNotesStore {
  const AiNotesStore();
  String read(ProjectController c);
  void write(ProjectController c, String text);
}

class DeviceNotesStore extends AiNotesStore {
  const DeviceNotesStore();
  static String keyOf(ProjectController c) => 'ai.notes.${c.project.meta.uid}';
  @override
  String read(ProjectController c) => getPref(keyOf(c)) ?? '';
  @override
  void write(ProjectController c, String text) => text.trim().isEmpty ? removePref(keyOf(c)) : setPref(keyOf(c), text.trim());
}

/// The notes travel with the project file; writing them is one undo step.
class ProjectNotesStore extends AiNotesStore {
  const ProjectNotesStore();
  @override
  String read(ProjectController c) => c.project.aiNotes;
  @override
  void write(ProjectController c, String text) => c.mutate(() => c.project.aiNotes = text.trim(), invalidateResults: false, label: 'hist.aiNotes');
}

/// A quick command of the input box (`/design`, `/plan`…): a prompt
/// template ([prompt]) or something done here.
class AiCommand {
  const AiCommand(this.name, {this.prompt = false});
  final String name;
  final bool prompt;
  String get label => '/$name';
}

const aiCommands = [
  AiCommand('new'),
  AiCommand('design', prompt: true),
  AiCommand('check', prompt: true),
  AiCommand('report', prompt: true),
  AiCommand('quote', prompt: true),
  AiCommand('export', prompt: true),
  AiCommand('plan'),
  AiCommand('clear'),
  AiCommand('cost'),
];

/// A tool whose first change opens the turn's undo group.
class _Tracked extends AgentTool {
  _Tracked(this.inner, this.before);
  final AgentTool inner;
  final void Function() before;
  @override
  String get name => inner.name;
  @override
  String get description => inner.description;
  @override
  Map<String, Object?> get inputSchema => inner.inputSchema;
  @override
  ToolEffect get effect => inner.effect;
  @override
  ToolEffect effectOf(Map<String, dynamic> input) => inner.effectOf(input);
  @override
  String describe(Map<String, dynamic> input) => inner.describe(input);
  @override
  bool mustConfirm(Map<String, dynamic> input) => inner.mustConfirm(input);
  @override
  Future<ToolOutput> run(Map<String, dynamic> input) {
    if (inner.effectOf(input) == ToolEffect.write) before();
    return inner.run(input);
  }
}

class AiAssistant extends ChangeNotifier {
  AiAssistant(this.c);
  final ProjectController c;

  static final Expando<AiAssistant> _of = Expando<AiAssistant>('ai');

  /// The assistant of project tab [c] (its conversation survives closing
  /// the panel).
  static AiAssistant of(ProjectController c) => _of[c] ??= AiAssistant(c);

  /// Replaced by tests: the HTTP exchange, the waits between retries, the
  /// pictures and the browser flag.
  static AiTransport? debugTransport;
  static Future<void> Function(Duration d)? debugSleep;
  static ViewSnapshots? debugSnapshots;
  static bool? debugBrowser;

  /// The docked panel is open (one for the app; it shows the active tab's
  /// assistant).
  static final panelOpen = ValueNotifier<bool>(false);
  static void togglePanel() => panelOpen.value = !panelOpen.value;

  /// The app's tabs, set where the app builds its workspace (tabs and the
  /// clipboard for the tools; null: one project only).
  static Workspace? workspace;

  /// The app shows the docked panel ([panelOpen]) beside the drawing: the
  /// assistant opens there (a bottom sheet on phones) instead of a dialog.
  static bool dockable = false;

  /// Where the AI notes of projects are kept.
  static AiNotesStore notesStore = const ProjectNotesStore();

  bool get _browser => debugBrowser ?? platformIsBrowser;

  // ---------------------------------------------------------------- keys

  /// Preference of the Anthropic key (the first one the app had).
  static const keyPref = 'ai.key';
  static String keyPrefOf(AiProvider p) => p == AiProvider.anthropic ? keyPref : 'ai.key.${p.name}';

  /// Keys of this session that the user did not ask to remember: in memory
  /// only, so no script on the page (the site's visit statistics run on the
  /// same origin) can find them in the browser storage.
  static final Map<AiProvider, String> _sessionKeys = {};

  /// Forgets the keys of this session (tests start without them).
  static void clearSessionKey() => _sessionKeys.clear();

  String? keyOf(AiProvider p) {
    final k = (_sessionKeys[p] ?? getPref(keyPrefOf(p)))?.trim();
    return k == null || k.isEmpty ? null : k;
  }

  bool hasKeyFor(AiProvider p) => keyOf(p) != null;

  /// The key of [p] is kept in the browser storage ("remember").
  bool remembers(AiProvider p) => !_sessionKeys.containsKey(p) && (getPref(keyPrefOf(p)) ?? '').trim().isNotEmpty;

  /// The key of [p] shortened for display ("sk-ant-…a1b2").
  String masked(AiProvider p) {
    final k = keyOf(p) ?? '';
    return k.length <= 12 ? '••••' : '${k.substring(0, 7)}…${k.substring(k.length - 4)}';
  }

  /// Keeps [key] for [provider] for this session, or in the browser
  /// storage with [remember] (the user's explicit choice).
  void saveKey(String key, {AiProvider provider = AiProvider.anthropic, bool remember = false}) {
    final k = key.trim();
    if (k.isEmpty) return forgetKey(provider);
    if (remember) {
      setPref(keyPrefOf(provider), k);
      _sessionKeys.remove(provider);
    } else {
      removePref(keyPrefOf(provider));
      _sessionKeys[provider] = k;
    }
    notifyListeners();
  }

  void forgetKey([AiProvider provider = AiProvider.anthropic]) {
    removePref(keyPrefOf(provider));
    _sessionKeys.remove(provider);
    notifyListeners();
  }

  /// The key, presence and display of the chosen model's provider.
  String? get apiKey => keyOf(model.provider);
  bool get hasKey => hasKeyFor(model.provider);
  bool get remembersKey => remembers(model.provider);
  String get maskedKey => masked(model.provider);

  // ---------------------------------------------------------------- settings

  AiModel get model => AiModel.byId(getPref('ai.model'));

  /// Another company, or another OpenAI model, starts a new conversation
  /// (the earlier one is not sent to it); Claude models can take over a
  /// conversation of another Claude model.
  set model(AiModel m) {
    final from = _convModel;
    setPref('ai.model', m.id);
    if (from != null && items.isNotEmpty && needsNewConversation(from, m)) {
      clear();
      items.add(AiItem.notice(t('ai.newConv', {'m': m.label, 'p': m.provider.company})));
    }
    notifyListeners();
  }

  static bool needsNewConversation(AiModel from, AiModel to) => from.provider != to.provider || (to.provider == AiProvider.openai && from.id != to.id);

  /// Switching from the conversation's model to [m] would start anew.
  bool switchStartsAnew(AiModel m) => _convModel != null && items.isNotEmpty && needsNewConversation(_convModel!, m);

  AiEffort get effort => AiEffort.values.where((e) => e.name == getPref('ai.effort')).firstOrNull ?? AiEffort.medium;
  set effort(AiEffort e) {
    setPref('ai.effort', e.name);
    notifyListeners();
  }

  AgentPermission get permission => AgentPermission.values.where((e) => e.name == getPref('ai.mode')).firstOrNull ?? AgentPermission.ask;
  set permission(AgentPermission p) {
    setPref('ai.mode', p.name);
    notifyListeners();
  }

  static const stepChoices = [10, 20, 30, 50, 100, 150, 200];

  /// Requests to the model per task at most.
  int get maxSteps => (int.tryParse(getPref('ai.steps') ?? '') ?? 50).clamp(5, 200);
  set maxSteps(int n) {
    setPref('ai.steps', '${n.clamp(5, 200)}');
    notifyListeners();
  }

  static const capChoices = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 0.0];

  /// US$ a task may spend at list prices before it stops (0: no cap).
  double get costCap => (double.tryParse(getPref('ai.cap') ?? '') ?? 2.0).clamp(0, 1000).toDouble();
  set costCap(double v) {
    setPref('ai.cap', '$v');
    notifyListeners();
  }

  /// Older turns are summarised on the server when the conversation grows
  /// long (and old pictures leave it).
  bool get compaction => getPref('ai.compact') != 'off';
  set compaction(bool on) {
    setPref('ai.compact', on ? 'on' : 'off');
    notifyListeners();
  }

  /// A picture of the drawing goes to the model after its changes (costs
  /// tokens; off by default).
  bool get showChanges => getPref('ai.showChanges') == 'on';
  set showChanges(bool on) {
    setPref('ai.showChanges', on ? 'on' : 'off');
    notifyListeners();
  }

  /// The user's standing instructions ("always PVC PN 80"), read at the
  /// start of each conversation.
  String get instructions => getPref('ai.instructions') ?? '';
  set instructions(String s) {
    s.trim().isEmpty ? removePref('ai.instructions') : setPref('ai.instructions', s.trim());
    notifyListeners();
  }

  /// The project's AI notes (requirements, decisions).
  String get notes => notesStore.read(c);
  set notes(String s) {
    notesStore.write(c, s);
    notifyListeners();
  }

  /// Parts of the project data attached to a message.
  Set<ContextPart> get parts {
    final s = getPref('ai.parts');
    if (s == null) return {...ContextPart.values};
    return {for (final n in s.split(',')) ...ContextPart.values.where((p) => p.name == n)};
  }

  void setPart(ContextPart p, bool on) {
    final now = parts;
    on ? now.add(p) : now.remove(p);
    setPref(
      'ai.parts',
      [
        for (final x in ContextPart.values)
          if (now.contains(x)) x.name,
      ].join(','),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- conversation

  final List<AiItem> items = [];
  final List<Map<String, dynamic>> _history = [];
  String? _system;
  AiModel? _convModel;
  AgentToolbox? _toolbox;
  late final _Host _host = _Host(this);
  final List<AiAttachment> attachments = [];

  /// Files attached in this conversation (import_attachment reads them).
  final Map<String, Uint8List> _files = {};

  /// Attach the project data to the next message (on at the start of a
  /// conversation; the model reads more through its tools).
  bool attachContext = true;

  bool get busy => _cancel != null;
  AiCancel? _cancel;
  AiApproval? pending;
  AiAsk? question;
  AiPlanReview? planReview;

  /// The model's to-do list for the task.
  List<AiTodo> todos = const [];

  /// Messages typed while the assistant works, handed to it with the next
  /// round of tool results (or sent next when the turn ends).
  final List<String> queued = [];

  /// The text of a message the user rewound to (the panel puts it back in
  /// the input box).
  String? rewound;

  /// Tokens and cost (US$, list prices) of the conversation so far.
  AiUsage usage = AiUsage.zero;
  double cost = 0;
  int pictures = 0;

  int get historyLength => _history.length;

  /// The model of the conversation (set by its first message).
  AiModel? get conversationModel => _convModel;

  /// The system prompt of the conversation (fixed from its first message:
  /// a change would invalidate the model's earlier reasoning).
  String get systemPrompt => _system ?? aiSystemPrompt(c, instructions: instructions);

  AgentToolbox get toolbox => _toolbox ??= AgentToolbox(c, snapshots: debugSnapshots ?? const CanvasSnapshots(), host: _host);

  /// The project data the next message would carry.
  ProjectContext previewContext() {
    if (!attachContext || parts.isEmpty || (c.project.entities.isEmpty && c.project.meta.name.isEmpty)) return ProjectContext.empty;
    try {
      return buildProjectContext(toolbox.source(), parts: parts);
    } catch (_) {
      // no data rather than no conversation: the model reads it with its tools
      return ProjectContext.empty;
    }
  }

  /// The text of the next message as it will be sent: the project data, the
  /// project's notes at the start of a conversation, then the question.
  String composeText(String question, ProjectContext ctx) {
    final n = _history.isEmpty ? notes.trim() : '';
    return [if (!ctx.isEmpty) '<project_data>\n${ctx.text}\n</project_data>', if (n.isNotEmpty) '<project_notes>\n$n\n</project_notes>', question.trim()].join('\n\n');
  }

  void addAttachment(AiAttachment a) {
    attachments.add(a);
    notifyListeners();
  }

  void removeAttachment(AiAttachment a) {
    attachments.remove(a);
    notifyListeners();
  }

  /// Attaches a picture of what the user sees, with its mapping, so the
  /// user can point at things ("the mainline along this road"); false when
  /// no picture can be made.
  Future<bool> attachView() async {
    final v = await captureUserView(c, snapshots: debugSnapshots);
    if (v == null) return false;
    addAttachment(AiAttachment(v.name, 'image/png', v.png, note: v.mapping));
    return true;
  }

  /// Starts a new conversation (the meter restarts too).
  void clear() {
    stop();
    items.clear();
    _history.clear();
    _system = null;
    _convModel = null;
    _toolbox = null;
    attachments.clear();
    _files.clear();
    queued.clear();
    todos = const [];
    attachContext = true;
    usage = AiUsage.zero;
    cost = 0;
    pictures = 0;
    notifyListeners();
  }

  /// Stops the running turn: the request in flight, a pending approval,
  /// question or plan, and any further step (a tool already running
  /// finishes first).
  void stop() {
    final p = pending, q = question, r = planReview;
    pending = null;
    question = null;
    planReview = null;
    if (p != null && !p.done.isCompleted) p.done.complete(Approval.stop);
    if (q != null && !q.done.isCompleted) q.done.complete(null);
    if (r != null && !r.done.isCompleted) r.done.complete(null);
    _cancel?.cancel();
    notifyListeners();
  }

  void answer(Approval a) {
    final p = pending;
    pending = null;
    if (p != null && !p.done.isCompleted) p.done.complete(a);
    notifyListeners();
  }

  /// The user's answers to the pending questions (empty texts: skipped).
  void answerQuestions(List<String> answers) {
    final q = question;
    question = null;
    if (q != null && !q.done.isCompleted) q.done.complete(answers);
    notifyListeners();
  }

  /// The user's decision on the pending plan; an approval also sets the
  /// mode the changes run in.
  void decidePlan(PlanDecision d) {
    final r = planReview;
    planReview = null;
    if (d.approved) permission = d.mode!;
    if (r != null && !r.done.isCompleted) r.done.complete(d);
    notifyListeners();
  }

  /// Adds a message typed while the assistant works.
  void queue(String text) {
    final s = text.trim();
    if (s.isEmpty) return;
    queued.add(s);
    notifyListeners();
  }

  void unqueue(int i) {
    if (i < 0 || i >= queued.length) return;
    queued.removeAt(i);
    notifyListeners();
  }

  /// Tells the panel something changed (the tools' host).
  void refresh() => notifyListeners();

  Timer? _tick;
  void _soon() {
    _tick ??= Timer(const Duration(milliseconds: 60), () {
      _tick = null;
      notifyListeners();
    });
  }

  // the undo group and the change summary of a turn
  SettingsEdit? _edit;
  Map<String, (String, String)>? _before;
  Map<String, String>? _beforeSettings;
  int _startIndex = 0;

  static String _sig(Entity e) {
    final j = e.toJson()..remove('data');
    return jsonEncode(j);
  }

  Map<String, String> _settingsSig() {
    final p = c.project;
    return {
      t('ai.chg.params'): jsonEncode(p.params.toJson()),
      t('ai.chg.catalog'): jsonEncode(p.catalog.toJson()),
      t('ai.chg.flows'): jsonEncode([for (final f in p.systemFlows) f.toJson()]),
      t('ai.chg.layers'): jsonEncode([for (final l in p.layers) l.toJson()]),
      t('ai.chg.details'): jsonEncode(p.meta.toJson()..remove('modified')),
      t('ai.chg.quote'): jsonEncode(p.proposal.toJson()),
      t('ai.chg.labels'): jsonEncode([for (final r in p.labelRules) r.toJson()]),
    };
  }

  I18n get t => c.t;

  /// Called before the first change of a turn.
  void _openTurn() {
    if (_edit != null) return;
    _before = {for (final e in c.project.entities) e.id: (_sig(e), toolbox.kindOf(e))};
    _beforeSettings = _settingsSig();
    _startIndex = c.historyIndex;
    _edit = c.beginSettingsEdit('hist.ai');
  }

  AiTurnChanges? _closeTurn() {
    final edit = _edit;
    _edit = null;
    if (edit == null) return null;
    final kept = c.results;
    final committed = c.commitSettingsEdit(edit);
    // the results the AI computed after its last change still hold
    if (committed && kept != null && c.results == null) {
      c.results = kept;
      c.refresh();
    }
    final before = _before ?? const {};
    final now = {for (final e in c.project.entities) e.id: (_sig(e), toolbox.kindOf(e))};
    final added = <String, int>{}, changed = <String, int>{}, removed = <String, int>{};
    void add(Map<String, int> m, String k) => m[k] = (m[k] ?? 0) + 1;
    for (final e in now.entries) {
      final old = before[e.key];
      if (old == null) {
        add(added, e.value.$2);
      } else if (old.$1 != e.value.$1) {
        add(changed, e.value.$2);
      }
    }
    for (final e in before.entries) {
      if (!now.containsKey(e.key)) add(removed, e.value.$2);
    }
    final s0 = _beforeSettings ?? const {}, s1 = _settingsSig();
    final settings = [
      for (final k in s1.keys)
        if (s0[k] != s1[k]) k,
    ];
    final end = c.historyIndex;
    return AiTurnChanges(added: added, changed: changed, removed: removed, settings: settings, endIndex: end, steps: committed ? 1 : end - _startIndex);
  }

  /// Whether [ch] can still be undone (nothing happened in the project
  /// since).
  bool canUndo(AiTurnChanges ch) => !ch.undone && !busy && ch.steps > 0 && c.historyIndex == ch.endIndex;

  /// Undoes what the AI changed in that turn.
  void undoTurn(AiTurnChanges ch) {
    if (!canUndo(ch)) return;
    for (var k = 0; k < ch.steps; k++) {
      c.undo();
    }
    ch.undone = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- checkpoints

  AiCheckpoint _checkpoint() {
    final k = c.historyIndex;
    final es = c.historyEntries;
    return AiCheckpoint(history: _history.length, items: items.length, index: k, label: k > 0 && k < es.length ? es[k].label : null, time: k > 0 && k < es.length ? es[k - 1].time : null);
  }

  /// The history position of the state [cp] recorded, or null when the
  /// project's history no longer reaches it.
  int? _target(AiCheckpoint cp) {
    final all = c.historyEntries;
    final es = all.where((e) => !e.future).toList();
    if (cp.index == 0) {
      // the opening state stays at 0 while no old step was dropped
      return all.length - 1 < ProjectController.maxUndo ? 0 : null;
    }
    for (var j = 1; j < es.length; j++) {
      if (es[j].label == cp.label && es[j - 1].time == cp.time) return j;
    }
    return null;
  }

  /// What rewinding to [it] does: null when it cannot be done now;
  /// otherwise whether the project goes back too (false: only the
  /// conversation).
  bool? rewindsProject(AiItem it) {
    final cp = it.checkpoint;
    if (cp == null || busy) return null;
    return _target(cp) != null;
  }

  /// Takes the conversation and the project back to before message [it]
  /// (through the undo history; redo brings the project forward again).
  /// The message goes back to the input box ([rewound]).
  void rewind(AiItem it) {
    final cp = it.checkpoint;
    if (cp == null) return;
    stop();
    final target = _target(cp);
    if (target != null && target != c.historyIndex) c.jumpToHistory(target);
    if (cp.history < _history.length) _history.removeRange(cp.history, _history.length);
    if (cp.items < items.length) items.removeRange(cp.items, items.length);
    if (_history.isEmpty) {
      _system = null;
      _convModel = null;
      _toolbox = null;
      attachContext = true;
    }
    todos = const [];
    queued.clear();
    rewound = it.text;
    items.add(AiItem.notice(t(target == null ? 'ai.rewound.chat' : 'ai.rewound')));
    notifyListeners();
  }

  // ---------------------------------------------------------------- texts

  String _errorText(AiError e, AiModel m) {
    final args = {'p': m.provider.company, 'h': m.provider.host, 'm': m.label};
    return switch (e.kind) {
      AiErrorKind.noKey => t('ai.err.noKey', args),
      AiErrorKind.auth => t('ai.err.auth', args),
      AiErrorKind.permission => t('ai.err.permission', args),
      AiErrorKind.billing => t('ai.err.billing', args),
      AiErrorKind.notFound => t(m.needsRetention ? 'ai.err.retention' : 'ai.err.model', args),
      AiErrorKind.retention => t('ai.err.retention', args),
      AiErrorKind.invalidRequest => t('ai.err.invalid', {'m': e.message}),
      AiErrorKind.tooLarge => t('ai.err.tooLarge'),
      AiErrorKind.rateLimit => t('ai.err.rateLimit', args),
      AiErrorKind.overloaded => t('ai.err.overloaded', args),
      AiErrorKind.server => t('ai.err.server', args),
      AiErrorKind.network => t(m.provider == AiProvider.openai && _browser ? 'ai.err.networkKey' : 'ai.err.network', args),
      AiErrorKind.timeout => t('ai.err.timeout', args),
      AiErrorKind.interrupted => t('ai.err.interrupted'),
      AiErrorKind.cancelled => t('ai.stopped'),
      AiErrorKind.refusal => e.message.isEmpty ? t('ai.err.refusal', args) : '${t('ai.err.refusal', args)} (${e.message})',
      AiErrorKind.truncated => t('ai.err.truncated'),
      AiErrorKind.http => t('ai.err.http', {'s': '${e.status ?? '?'}', 'm': e.message, 'p': m.provider.company}),
    };
  }

  String _statusText(AgentStatus s, AiModel m) => switch (s.kind) {
    'tool' => t('ai.st.tool', {'n': s.tool}),
    'approval' => t('ai.st.approval'),
    'retry' => t('ai.st.retry', {'s': '${(s.wait.inMilliseconds / 1000).ceil()}'}),
    _ => t('ai.st.thinking', {'m': m.label}),
  };

  /// The cost summary of the conversation.
  String costText() => t('ai.cmd.costText', {'i': '${usage.totalInput}', 'o': '${usage.output}', 'r': '${usage.cacheRead}', 'n': '$pictures', 'c': cost.toStringAsFixed(cost < 1 ? 3 : 2)});

  // ---------------------------------------------------------------- quick commands

  /// The commands whose name starts with what follows the slash in [text].
  List<AiCommand> commandsFor(String text) {
    if (!text.startsWith('/') || text.contains(' ') || text.contains('\n')) return const [];
    final k = text.substring(1).toLowerCase();
    return [
      for (final x in aiCommands)
        if (x.name.startsWith(k)) x,
    ];
  }

  /// [q] after its quick command: the prompt to send, or null when the
  /// command was done here.
  String? _command(String q) {
    final m = RegExp(r'^/(\S+)\s*([\s\S]*)$').firstMatch(q);
    if (m == null) return q;
    final name = m.group(1)!.toLowerCase();
    final rest = m.group(2)!.trim();
    final cmd = aiCommands.where((x) => x.name == name).firstOrNull;
    if (cmd == null) {
      items.add(AiItem.notice(t('ai.cmd.unknown', {'c': '/$name', 'l': aiCommands.map((x) => x.label).join(' ')})));
      notifyListeners();
      return null;
    }
    switch (cmd.name) {
      case 'new' || 'clear':
        clear();
        return null;
      case 'cost':
        items.add(AiItem.notice(costText()));
        notifyListeners();
        return null;
      case 'plan':
        permission = AgentPermission.plan;
        if (rest.isEmpty) {
          items.add(AiItem.notice(t('ai.cmd.planOn')));
          notifyListeners();
          return null;
        }
        return rest;
    }
    final prompt = t('ai.cmd.${cmd.name}.prompt', {'x': rest});
    return rest.isEmpty || prompt.contains(rest) ? prompt : '$prompt\n$rest';
  }

  // ---------------------------------------------------------------- the turn

  AiClient _client(AiProvider p, String key) => switch (p) {
    AiProvider.anthropic => AnthropicClient(apiKey: key, transport: debugTransport ?? platformTransport, browser: _browser, sleep: debugSleep),
    AiProvider.openai => OpenAiClient(apiKey: key, transport: debugTransport ?? platformTransport, sleep: debugSleep),
  };

  /// Tools that may change the project (their first change opens the
  /// turn's undo group): the dispatchers run changes too.
  static const _dispatchers = {'run_operation', 'run_command', 'set_setting'};

  /// Sends [question] (with the project data and attachments chosen) and
  /// runs the task to its end. While a task runs, a message is queued for
  /// the model's next step instead.
  Future<void> send(String text) async {
    var q = text.trim();
    if (busy) {
      queue(q);
      return;
    }
    if (q.startsWith('/')) {
      final r = _command(q);
      if (r == null) return;
      q = r;
    }
    if (q.isEmpty && attachments.isEmpty) return;
    rewound = null;
    final m = model;
    final key = keyOf(m.provider);
    final ctx = previewContext();
    final files = [...attachments];
    final userItem = AiItem.user(q, attachments: [for (final a in files) a.name], contextTokens: ctx.isEmpty ? null : ctx.approxTokens)..checkpoint = _checkpoint();
    var answer = AiItem.assistant()..model = m.label;
    items
      ..add(userItem)
      ..add(answer);
    if (key == null) {
      answer.error = t('ai.err.noKey', {'p': m.provider.company});
      notifyListeners();
      return;
    }
    if (_history.isEmpty) {
      _system = null;
      _convModel = m;
    }
    _convModel ??= m;
    _system ??= aiSystemPrompt(c, instructions: instructions);
    final client = _client(m.provider, key);
    final message = client.userMessage([for (final a in files) ...a.parts(), AiTextPart(composeText(q.isEmpty ? t('ai.q.attachment') : q, ctx))]);
    for (final a in files) {
      _files[a.name] = a.bytes;
    }
    attachments.clear();
    final cancel = AiCancel();
    _cancel = cancel;
    answer
      ..running = true
      ..started = DateTime.now()
      ..status = t('ai.st.thinking', {'m': m.label})
      ..pictures = files.where((a) => a.isImage).length;
    notifyListeners();
    final box = toolbox;
    final loop = AgentLoop(api: client, tools: [for (final tool in box.tools) tool.effect == ToolEffect.read && !_dispatchers.contains(tool.name) ? tool : _Tracked(tool, _openTurn)]);
    final usage0 = usage, cost0 = cost;
    final cap = costCap;
    AgentTurn? turn;
    try {
      turn = await loop.run(
        model: m,
        effort: effort,
        system: _system!,
        history: _history,
        user: message,
        permission: permission,
        permissionNow: () => permission,
        maxSteps: maxSteps,
        costCap: cap > 0 ? cap : null,
        taskBudget: cap > 0 && m.taskBudget ? (cap / m.output * 1e6).round() : null,
        compactAt: compaction ? (m.provider == AiProvider.anthropic ? 150000 : 200000) : null,
        cancel: cancel,
        events: AgentEvents(
          onText: (s) {
            answer.text += answer.text.isEmpty ? s.trimLeft() : s;
            _soon();
          },
          onCall: (call) {
            if (!answer.calls.contains(call)) answer.calls.add(call);
            _soon();
          },
          onStatus: (s) {
            answer.status = _statusText(s, m);
            _soon();
          },
          approve: (call) {
            final p = AiApproval(call);
            pending = p;
            notifyListeners();
            return p.done.future;
          },
          onUsage: (u, x) {
            answer
              ..usage = u
              ..cost = x;
            usage = usage0 + u;
            cost = cost0 + x;
            _soon();
          },
          steer: () {
            if (queued.isEmpty) return const [];
            final texts = [...queued];
            queued.clear();
            // the messages show where the model received them
            answer.running = false;
            for (final s in texts) {
              items.add(AiItem.user(s, steered: true));
            }
            final next = AiItem.assistant()
              ..model = m.label
              ..running = true
              ..started = answer.started
              ..status = answer.status;
            items.add(next);
            answer = next;
            notifyListeners();
            return [for (final s in texts) AiTextPart(s)];
          },
          afterRound: (round) async {
            if (!showChanges) return null;
            final img = await feedbackPicture(box);
            if (img == null) return null;
            answer.pictures++;
            return ToolOutput('The drawing after these changes (picture attached). ${lastFeedbackMapping(box) ?? ''}'.trim(), images: [img]);
          },
          onCompacted: () {
            items.insert(items.indexOf(answer), AiItem.notice(t('ai.compacted')));
            _soon();
          },
        ),
      );
    } catch (e) {
      answer.error = t('ai.err.unexpected', {'e': '${e.runtimeType}'});
    } finally {
      _cancel = null;
      pending = null;
      question = null;
      planReview = null;
      answer.changes = _closeTurn();
      answer
        ..running = false
        ..status = '';
      for (final it in items) {
        if (it.kind == AiItemKind.assistant) it.running = false;
      }
    }
    if (turn != null) {
      _history.addAll(turn.messages);
      if (turn.messages.isNotEmpty && !ctx.isEmpty) attachContext = false;
      answer.pictures += _picturesIn(turn);
      pictures += answer.pictures;
      switch (turn.stop) {
        case AgentStop.cancelled:
          answer.stopped = true;
        case AgentStop.stepLimit:
          answer
            ..error = t('ai.err.steps', {'n': '$maxSteps'})
            ..canContinue = true;
        case AgentStop.budget:
          answer
            ..error = t('ai.err.budget', {'c': cap.toStringAsFixed(2)})
            ..canContinue = true;
        case AgentStop.maxTokens:
          answer.error = t('ai.err.length');
        case AgentStop.error:
          answer.error = turn.error == null ? t('ai.err.server', {'p': m.provider.company}) : _errorText(turn.error!, m);
        case AgentStop.done:
          break;
      }
      // nothing kept: the question can be sent again with its attachments
      if (turn.messages.isEmpty && files.isNotEmpty && attachments.isEmpty) attachments.addAll(files);
    }
    _tick?.cancel();
    _tick = null;
    notifyListeners();
    // what the user wrote after the last step is the next message
    if (queued.isNotEmpty && turn != null && turn.stop != AgentStop.cancelled) {
      final next = queued.join('\n\n');
      queued.clear();
      scheduleMicrotask(() => send(next));
    }
  }

  static int _picturesIn(AgentTurn turn) {
    var n = 0;
    for (final call in turn.calls) {
      if (call.state == ToolCallState.done && (call.name == 'view_snapshot' || call.name == 'preview_geometry' || call.name == 'terrain_picture')) n++;
    }
    return n;
  }

  /// Goes on with a task that stopped at the step limit or the cap.
  Future<void> continueTask() => send(t('ai.continue.prompt'));

  // ---------------------------------------------------------------- transcript

  /// The conversation as Markdown.
  String transcript() {
    final b = StringBuffer('# ${t('ai.transcript.title', {'p': c.project.meta.name.isEmpty ? t('ai.transcript.untitled') : c.project.meta.name})}\n\n');
    final m = _convModel ?? model;
    b
      ..writeln('${t('ai.transcript.model')}: ${m.label} (${m.provider.company}) · ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}')
      ..writeln();
    for (final it in items) {
      switch (it.kind) {
        case AiItemKind.user:
          b
            ..writeln('## ${t(it.steered ? 'ai.transcript.youMeanwhile' : 'ai.transcript.you')}')
            ..writeln()
            ..writeln(it.text);
          for (final a in it.attachments) {
            b.writeln('- 📎 $a');
          }
        case AiItemKind.assistant:
          b
            ..writeln('## ${t('ai.transcript.assistant', {'m': it.model})}')
            ..writeln();
          for (final call in it.calls) {
            b.writeln('- `${call.name}` ${call.summary}${call.state == ToolCallState.done ? '' : ' (${call.state.name}${call.result.isEmpty ? '' : ': ${call.result}'})'}');
          }
          if (it.calls.isNotEmpty) b.writeln();
          if (it.text.isNotEmpty) b.writeln(it.text);
          if (it.error != null) b.writeln('\n> ${it.error}');
          final ch = it.changes;
          if (ch != null && !ch.isEmpty) {
            String list(Map<String, int> m) => [for (final e in m.entries) '${e.value} × ${e.key}'].join(', ');
            b.writeln('\n**${t('ai.chg.title')}**${ch.undone ? ' (${t('ai.chg.undone')})' : ''}');
            if (ch.added.isNotEmpty) b.writeln('- + ${list(ch.added)}');
            if (ch.changed.isNotEmpty) b.writeln('- ~ ${list(ch.changed)}');
            if (ch.removed.isNotEmpty) b.writeln('- − ${list(ch.removed)}');
            if (ch.settings.isNotEmpty) b.writeln('- ${t('ai.chg.settings')}: ${ch.settings.join(', ')}');
          }
        case AiItemKind.notice:
          b.writeln('> ${it.text}');
      }
      b.writeln();
    }
    b.writeln('---\n${costText()}');
    return b.toString();
  }

  Future<void> saveTranscript() {
    final name = (c.project.meta.name.isEmpty ? 'project' : c.project.meta.name).replaceAll(RegExp(r'[^\w\- ]+'), '_').trim();
    return saveTextFile('$name - AI.md', transcript(), mime: 'text/markdown');
  }

  @override
  void dispose() {
    stop();
    _tick?.cancel();
    super.dispose();
  }
}

/// What the tools reach of the assistant and of the app around it.
class _Host implements AgentHost, AiWorkspaceHost {
  _Host(this.ai);
  final AiAssistant ai;
  ProjectController get c => ai.c;
  Workspace? get ws => AiAssistant.workspace;

  @override
  AgentPermission get permission => ai.permission;

  @override
  bool get stopped => ai._cancel?.cancelled ?? false;

  @override
  void setTodos(List<AiTodo> items) {
    ai.todos = List.unmodifiable(items);
    ai._soon();
  }

  @override
  Future<List<String>?> ask(List<AiQuestion> questions) {
    final q = AiAsk(questions);
    ai.question = q;
    ai.refresh();
    return q.done.future;
  }

  @override
  Future<PlanDecision?> reviewPlan(String plan) {
    final r = AiPlanReview(plan);
    ai.planReview = r;
    ai.refresh();
    return r.done.future;
  }

  @override
  String get notes => ai.notes;

  @override
  void setNotes(String text) => ai.notes = text;

  @override
  String get instructions => ai.instructions;

  @override
  Map<String, Uint8List> get files => Map.unmodifiable(ai._files);

  @override
  bool openTab(Project p) {
    final w = ws;
    if (w == null) return false;
    w.addTab().openProject(p, dirty: true);
    return true;
  }

  @override
  List<AiTab> get tabs {
    final w = ws;
    if (w == null) return const [];
    return [for (var i = 0; i < w.tabs.length; i++) AiTab(name: w.tabs[i].project.meta.name, dirty: w.tabs[i].dirty, active: i == w.active, own: identical(w.tabs[i], c))];
  }

  @override
  bool selectTab(int index) {
    final w = ws;
    if (w == null || index < 0 || index >= w.tabs.length) return false;
    w.select(index);
    return true;
  }

  @override
  bool closeTab(int index) {
    final w = ws;
    if (w == null || index < 0 || index >= w.tabs.length || identical(w.tabs[index], c)) return false;
    w.tabs[index].autosaveNow();
    w.closeTab(index);
    return true;
  }

  @override
  bool newTab() {
    final w = ws;
    if (w == null) return false;
    w.addTab();
    return true;
  }

  @override
  Future<int> copySelection({bool cut = false}) async {
    if (c.selection.isEmpty) return 0;
    final p = ClipboardPayload.fromSelection(c);
    ws?.clipboard = p;
    try {
      await Clipboard.setData(ClipboardData(text: p.encode()));
    } catch (_) {}
    if (cut) c.deleteSelected();
    return p.count;
  }

  @override
  Future<int> paste() async {
    ClipboardPayload? p;
    try {
      p = ClipboardPayload.tryParse((await Clipboard.getData(Clipboard.kTextPlain))?.text);
    } catch (_) {}
    p ??= ws?.clipboard;
    return p == null ? 0 : p.pasteInto(c).length;
  }
}
