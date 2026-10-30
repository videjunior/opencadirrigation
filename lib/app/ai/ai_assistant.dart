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
///
/// The conversation of a project is kept in this browser after each turn
/// (lib/app/io/ai_store.dart: this device's storage, never uploaded), so
/// that a reload, or the project opened again later, brings it back and the
/// model goes on with all of it: the transcript, the history exactly as the
/// API took it, the mappings of the pictures, small attached files. What is
/// kept is project data and pictures, like the project's own autosave in
/// the same storage; an API key is never in it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/ai/agent_loop.dart';
import '../../core/ai/claude_api.dart';
import '../../core/ai/image_prep.dart';
import '../../core/ai/openai_api.dart';
import '../../core/ai/project_context.dart';
import '../../core/io/pdf_reader.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/units.dart';
import '../i18n.dart';
import '../io/ai_store.dart';
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
  static const importable = {'dxf', 'dwg', 'dgn', 'kml', 'kmz', 'shp', 'zip', 'geojson', 'gpx', 'xml', 'landxml', 'inp', 'las', 'tif', 'tiff'};

  bool get isImage => mime.startsWith('image/');

  /// Where the photo was taken, for the model (see
  /// [AiAssistant.photoPlaceNote]); '' when unknown.
  String place = '';

  ModelImage? _modelImage;
  bool _prepared = false;

  /// The picture as the models take it (the real type read from the bytes,
  /// upright, within the size limits); prepared once, when it is attached,
  /// since a large photo takes a moment to decode. Null: not a picture.
  ModelImage? get modelImage {
    if (!_prepared) {
      _prepared = true;
      _modelImage = prepareModelImage(bytes);
    }
    return _modelImage;
  }
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
    if (isImage) {
      final p = modelImage;
      if (p == null) return [AiTextPart('<attachment name="$name">This file could not be read as a picture.</attachment>')];
      return [AiImagePart(p.mediaType, base64Encode(p.bytes)), if (note.isNotEmpty) AiTextPart(note), if (place.isNotEmpty) AiTextPart(place)];
    }
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
  AiCheckpoint({required this.history, required this.items, required this.index, this.label, this.time, this.restored = false});

  /// Entries of the conversation and items of the transcript before it.
  final int history, items;

  /// The project's history position then, and that state's fingerprint
  /// (the label and time of the step that led to it): the position moves
  /// when old steps are dropped, the fingerprint does not.
  final int index;
  final String? label;
  final DateTime? time;

  /// Brought back with a conversation kept in the browser: the undo history
  /// it pointed into was the one of another page, or of the project before
  /// it was opened again (opening a project starts its history anew), so a
  /// rewind takes back the conversation only.
  final bool restored;
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

  /// A line of this page only (the notice of a conversation brought back):
  /// not kept with the conversation.
  bool transient = false;

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

  /// What the answer can do again after an error or a stop: send the same
  /// message (nothing of it reached the model's history) or go on.
  AiRetry? retry;

  /// The fix is in the settings (no key, a key refused, a model the key
  /// cannot use): the answer offers to open them.
  bool toSettings = false;
  AiUsage usage = AiUsage.zero;
  double cost = 0;

  /// Pictures sent in the turn (they count in the input tokens).
  int pictures = 0;
  String model = '';
  AiTurnChanges? changes;
}

/// How a failed or stopped answer goes on: [text] is the message that
/// started it; [kept] says whether part of the task reached the model's
/// history (then it continues, otherwise the message is sent again).
class AiRetry {
  const AiRetry(this.text, {required this.kept});
  final String text;
  final bool kept;
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
  AiCommand('review', prompt: true),
  AiCommand('report', prompt: true),
  AiCommand('quote', prompt: true),
  AiCommand('export', prompt: true),
  AiCommand('plan'),
  AiCommand('clear'),
  AiCommand('cost'),
];

/// A conversation kept in the browser, read back.
typedef _Kept = ({
  List<AiItem> items,
  List<Map<String, dynamic>> history,
  String? system,
  AiModel? model,
  List<AiTodo> todos,
  AiUsage usage,
  double cost,
  int pictures,
  bool context,
  String? marks,
  int dropped,
  List<String> filesLeft,
  Map<String, Uint8List> files,
  List<AiAttachment> pending,
  Object? vision,
  Object? views,
});

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
  AiAssistant(this.c) : _uid = c.project.meta.uid {
    _live.add(this);
    // the conversation kept for the project comes back, and follows it
    _claimed = !_shared;
    c.addListener(_onProject);
    _load();
  }
  final ProjectController c;

  static final Set<AiAssistant> _live = {};

  /// The assistants of the open tabs (created on first use).
  static Iterable<AiAssistant> get live => _live;

  /// The assistant of [c] if it has one already.
  static AiAssistant? peek(ProjectController c) => _of[c];

  /// Bumped when an assistant starts or ends a task or starts or stops
  /// waiting for the user: the shell keeps the panel on the assistant that
  /// works and badges its buttons.
  static final activity = ValueNotifier<int>(0);
  static void _mark() => activity.value++;

  /// The task waits for the user (an approval, questions or a plan).
  bool get waiting => pending != null || question != null || planReview != null;

  /// Stops the assistants whose tabs were closed.
  static void stopRemoved(Iterable<ProjectController> tabs) {
    for (final a in [..._live]) {
      if (!tabs.contains(a.c) && (a.busy || a.waiting)) a.stop();
    }
  }

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

  /// The model of the next message: the one chosen in the settings, unless
  /// it cannot read this conversation (it was chosen in another tab, or
  /// before the page was reloaded): then the conversation's own model goes
  /// on with it, and the panel says so. Choosing another company's model
  /// here starts a new conversation instead (the setter).
  AiModel get model {
    final chosen = AiModel.byId(getPref('ai.model'));
    final own = _convModel;
    return own != null && _history.isNotEmpty && needsNewConversation(own, chosen) ? own : chosen;
  }

  /// Another company, or another OpenAI model, starts a new conversation
  /// (the earlier one is not sent to it); Claude models can take over a
  /// conversation of another Claude model.
  set model(AiModel m) {
    final from = _convModel;
    setPref('ai.model', m.id);
    if (from != null && items.isNotEmpty && needsNewConversation(from, m)) {
      clear();
      items.add(AiItem.notice(t('ai.newConv', {'m': m.label, 'p': m.provider.company})));
    } else if (_history.isEmpty && !busy) {
      // the tools describe the pictures the model reads: built anew for it
      _toolbox = null;
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
  bool get showChanges => getPref('ai.showChanges') != 'off';
  set showChanges(bool on) {
    setPref('ai.showChanges', on ? 'on' : 'off');
    notifyListeners();
  }

  /// The app asks at start-up whether the user wants to design with the
  /// assistant (on by default; the question itself and the settings turn it
  /// off). One choice for the whole app, not per tab.
  static bool get askAtStart => getPref('ai.askAtStart') != 'off';
  static set askAtStart(bool on) => setPref('ai.askAtStart', on ? 'on' : 'off');

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

  /// The panel should put the cursor in its box (it was opened to type).
  bool focusInput = false;

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

  AgentToolbox get toolbox => _toolbox ??= AgentToolbox(c, snapshots: debugSnapshots ?? const CanvasSnapshots(), host: _host, pictures: PictureLimits.of(_convModel ?? model));

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
  /// project's notes at the start of a conversation, the user's marks on the
  /// drawing when they changed since the last message, then the question.
  String composeText(String question, ProjectContext ctx) {
    final n = _history.isEmpty ? notes.trim() : '';
    final marks = _marksText();
    return [if (!ctx.isEmpty) '<project_data>\n${ctx.text}\n</project_data>', if (n.isNotEmpty) '<project_notes>\n$n\n</project_notes>', ?marks, question.trim()].join('\n\n');
  }

  /// Version of the marks the last message carried (-1: none sent; -2: the
  /// model may know other marks than the tab's — a conversation brought
  /// back, whose versions counted in another page, or rewound — so the
  /// next message says what they are now).
  int _marksSent = -1;

  /// What the model last heard of the marks (null: nothing; '': none), kept
  /// with the conversation: brought back, it tells whether they changed.
  String? _marksSaid;

  /// The user's marks for the message, when they changed since the last
  /// one (null: nothing to say).
  String? _marksText() {
    final m = c.aiMarks;
    if (_marksSent != -2 && (m.version == _marksSent || (m.isEmpty && _marksSent < 0))) return null;
    if (m.isEmpty) return '<user_marks>The user removed the marks from the drawing.</user_marks>';
    return '<user_marks>\nMarks the user placed on the drawing for you, labelled there and in your pictures (orange), coordinates in metres:\n${m.describe()}\n</user_marks>';
  }

  void addAttachment(AiAttachment a) {
    if (a.isImage) {
      a.modelImage;
      a.place = photoPlaceNote(a);
    }
    attachments.add(a);
    notifyListeners();
  }

  /// Where the photo [a] was taken, for the model: from its GPS tags, or
  /// the device's position while its GPS is on; with the nearest item and
  /// how to keep it on the drawing ('' when nothing is known).
  String photoPlaceNote(AiAttachment a) {
    final place = photoPlace(a.bytes);
    final g = c.project.meta.georef;
    String near(Pt q) {
      Entity? best;
      var bd = double.infinity;
      for (final e in c.project.entities) {
        if (!e.isHydraulic && e is! AreaEntity && e is! CommentEntity) continue;
        final d = e.distanceTo(q);
        if (d < bd) {
          bd = d;
          best = e;
        }
      }
      return best == null || bd > 500 ? '' : '; the nearest item is ${best.id} (${best.type.name}${best.name.isEmpty ? '' : ' "${best.name}"'}) ${fmt(bd, 1)} m away';
    }

    final keep = 'To keep it on the drawing: add_photo_comment {"name": "${a.name}", "text": "what the photo shows"} pins a comment with the photo there.';
    if (place != null) {
      final facing = place.direction == null ? '' : ', facing ${fmt(place.direction!, 0)}° from north';
      final when = place.taken == null ? '' : ', taken ${place.taken!.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}';
      if (g == null) {
        return '<photo_place name="${a.name}">The photo\'s GPS puts it at latitude ${place.lat.toStringAsFixed(6)}, longitude ${place.lon.toStringAsFixed(6)}$facing$when. The project has no georeference: set_site at these coordinates would put the project there.</photo_place>';
      }
      final (x, y) = g.fromLatLon(place.lat, place.lon);
      final q = Pt(x, y);
      return '<photo_place name="${a.name}">Taken at [${fmt(x, 2)}, ${fmt(y, 2)}] m in the project (latitude ${place.lat.toStringAsFixed(6)}, longitude ${place.lon.toStringAsFixed(6)}, from the photo\'s GPS: a phone is usually within 5–10 m)$facing$when${near(q)}. $keep</photo_place>';
    }
    final fix = c.gpsFix, here = c.gpsPoint;
    if (fix != null && here != null && DateTime.now().difference(fix.time).inMinutes < 10) {
      return '<photo_place name="${a.name}">The photo carries no position; the device\'s GPS was at [${fmt(here.x, 2)}, ${fmt(here.y, 2)}] m (±${fmt(fix.accuracyM, 0)} m) when it was attached: if it was taken here, add_photo_comment {"name": "${a.name}", "at": [${fmt(here.x, 2)}, ${fmt(here.y, 2)}], "text": "…"} pins it there.</photo_place>';
    }
    return '';
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
    addAttachment(AiAttachment(v.name, v.mime, v.bytes, note: v.mapping));
    return true;
  }

  /// Starts a new conversation (the meter restarts too); the one kept in
  /// this browser for the project goes.
  void clear() {
    _reset();
    attachments.clear();
    if (_claimed) conversations.delete(_uid);
    notifyListeners();
    _mark();
  }

  /// Empties the conversation in memory (the copy kept in the browser
  /// stays): what [clear] does, and what another project in the tab does.
  void _reset() {
    stop();
    items.clear();
    _history.clear();
    _system = null;
    _convModel = null;
    _toolbox = null;
    _files.clear();
    _filesLeft.clear();
    queued.clear();
    todos = const [];
    attachContext = true;
    usage = AiUsage.zero;
    cost = 0;
    pictures = 0;
    // a new conversation hears of the marks again
    _marksSent = -1;
    _marksSaid = null;
    _dropped = 0;
    // a save or a load of the earlier conversation still on its way is ignored
    _gen++;
    _loading++;
    _rev = _savedRev = 0;
    _saveScheduled = false;
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
    // what the user wrote for the next step goes back to the box
    if (queued.isNotEmpty) {
      rewound = [if ((rewound ?? '').trim().isNotEmpty) rewound!, ...queued].join('\n\n');
      queued.clear();
    }
    notifyListeners();
    _mark();
  }

  void answer(Approval a) {
    final p = pending;
    pending = null;
    if (p != null && !p.done.isCompleted) p.done.complete(a);
    notifyListeners();
    _mark();
  }

  /// The user's answers to the pending questions (empty texts: skipped).
  void answerQuestions(List<String> answers) {
    final q = question;
    question = null;
    if (q != null && !q.done.isCompleted) q.done.complete(answers);
    notifyListeners();
    _mark();
  }

  /// The user's decision on the pending plan; an approval also sets the
  /// mode the rest of this task runs in (the mode chosen in the settings
  /// stays for the next tasks).
  void decidePlan(PlanDecision d) {
    final r = planReview;
    planReview = null;
    if (d.approved) _taskMode = d.mode;
    if (r != null && !r.done.isCompleted) r.done.complete(d);
    notifyListeners();
    _mark();
  }

  /// The mode of the running task when it differs from the settings (a
  /// plan approved to run automatically, or /plan before a task).
  AgentPermission? _taskMode;

  /// The mode the running task works in.
  AgentPermission get taskPermission => _taskMode ?? permission;

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
    _saveSoon();
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
    if (cp.restored) return null;
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
      _marksSent = -1;
      _marksSaid = null;
    } else if ((_marksSaid ?? '').isNotEmpty) {
      // the marks may have reached the model after that point: they go again
      _marksSent = -2;
    }
    todos = const [];
    queued.clear();
    rewound = it.text;
    items.add(AiItem.notice(t(target == null ? 'ai.rewound.chat' : 'ai.rewound')));
    notifyListeners();
    _saveSoon();
  }

  // ---------------------------------------------------------------- texts

  String _errorText(AiError e, AiModel m) {
    final args = {'p': m.provider.company, 'h': m.provider.host, 'm': m.label, 'u': m.provider.billingUrl};
    // a wait the provider asked for, in s, min or h
    String wait(Duration d) {
      final s = (d.inMilliseconds / 1000).ceil();
      if (s < 90) return '$s s';
      final min = (s / 60).ceil();
      if (min < 90) return '$min min';
      return min % 60 == 0 ? '${min ~/ 60} h' : '${min ~/ 60} h ${min % 60} min';
    }

    String mb(int bytes) => '${(bytes / 1e6).ceil()}';
    String refusal() {
      final c = e.category ?? '';
      final name = switch (c) {
        '' || 'reasoning_extraction' => null,
        'cyber' => t('ai.err.cat.cyber'),
        'bio' || 'bio_policy' => t('ai.err.cat.bio'),
        'frontier_llm' => t('ai.err.cat.frontier'),
        'content_filter' || 'image_content_policy_violation' => t('ai.err.cat.filter'),
        _ => t('ai.err.cat.policy'),
      };
      final r = e.recommendedModel ?? '';
      final other = AiModel.served(r, m);
      return [
        name == null ? t('ai.err.refusal', args) : t('ai.err.refusalCat', {...args, 'c': name}),
        if (e.message.isNotEmpty) '(${e.message})',
        t(c == 'reasoning_extraction' ? 'ai.err.refusalReasoning' : 'ai.err.refusalHint'),
        if (r.isNotEmpty) t('ai.err.refusalBusy', {'r': identical(other, m) && r != m.id ? r : other.label}),
      ].join(' ');
    }

    final text = switch (e.kind) {
      AiErrorKind.noKey => t('ai.err.noKey', args),
      AiErrorKind.auth => t('ai.err.auth', args),
      AiErrorKind.permission => t('ai.err.permission', args),
      AiErrorKind.billing => t('ai.err.billing', args),
      AiErrorKind.credit => t('ai.err.credit', args),
      AiErrorKind.spendLimit => [t('ai.err.spendLimit', args), if (e.message.isNotEmpty) '(${e.message})'].join(' '),
      AiErrorKind.notFound => t(m.needsRetention ? 'ai.err.retention' : 'ai.err.model', args),
      AiErrorKind.retention => t('ai.err.retention', args),
      AiErrorKind.invalidRequest => t('ai.err.invalid', {'m': e.message}),
      AiErrorKind.tooLarge => e.size == null ? t('ai.err.tooLarge') : t('ai.err.tooLargeConv', {'s': mb(e.size!), 'l': mb(e.limit ?? AiHttpClient.maxRequestBytes)}),
      AiErrorKind.contextWindow => t('ai.err.context', args),
      AiErrorKind.rateLimit => e.retryAfter == null ? t('ai.err.rateLimit', args) : t('ai.err.rateLimitWait', {...args, 'w': wait(e.retryAfter!)}),
      AiErrorKind.overloaded => t('ai.err.overloaded', args),
      AiErrorKind.server => t('ai.err.server', args),
      AiErrorKind.network => t(m.provider == AiProvider.openai && _browser ? 'ai.err.networkKey' : 'ai.err.network', args),
      AiErrorKind.timeout => t('ai.err.timeout', args),
      AiErrorKind.interrupted => t('ai.err.interrupted'),
      AiErrorKind.cancelled => t('ai.stopped'),
      AiErrorKind.refusal => refusal(),
      AiErrorKind.truncated => t('ai.err.truncated'),
      AiErrorKind.http => t('ai.err.http', {'s': '${e.status ?? '?'}', 'm': e.message, 'p': m.provider.company}),
      AiErrorKind.unexpected => t('ai.err.unexpected', {'e': e.message.isEmpty ? '?' : e.message}),
    };
    // the id the provider's support asks for, where it may have to look
    const withId = {AiErrorKind.invalidRequest, AiErrorKind.server, AiErrorKind.overloaded, AiErrorKind.timeout, AiErrorKind.interrupted, AiErrorKind.http, AiErrorKind.permission, AiErrorKind.unexpected};
    final id = e.requestId ?? '';
    return id.isNotEmpty && withId.contains(e.kind) ? '$text ${t('ai.err.requestId', {'r': id})}' : text;
  }

  String _statusText(AgentStatus s, AiModel m) => switch (s.kind) {
    // the model's own note on what it does, when it wrote one
    'tool' => s.note.isEmpty ? t('ai.st.tool', {'n': s.tool}) : t('ai.status.note', {'m': m.label, 'x': s.note}),
    'update' => t('ai.status.note', {'m': m.label, 'x': s.note}),
    'approval' => t('ai.st.approval'),
    'retry' => t(const {AiErrorKind.network, AiErrorKind.timeout, AiErrorKind.interrupted}.contains(s.reason) ? 'ai.status.retryNet' : 'ai.st.retry', {'s': '${(s.wait.inMilliseconds / 1000).ceil()}'}),
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
        if (rest.isEmpty) {
          permission = AgentPermission.plan;
          items.add(AiItem.notice(t('ai.cmd.planOn')));
          notifyListeners();
          return null;
        }
        // a plan first for this task; the mode in the settings stays
        _taskMode = AgentPermission.plan;
        return rest;
      case 'review':
        // a review reads and looks: nothing changes, whatever the mode
        _taskMode = AgentPermission.readOnly;
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
      // commands act now (the cost) or wait for the task to end; text goes
      // to the model's next step
      if (q.startsWith('/')) {
        final name = RegExp(r'^/(\S+)').firstMatch(q)?.group(1)?.toLowerCase();
        items.add(AiItem.notice(name == 'cost' ? costText() : t('ai.cmd.busy', {'c': '/${name ?? ''}'})));
        notifyListeners();
        return;
      }
      queue(q);
      return;
    }
    _taskMode = null;
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
      answer
        ..error = t('ai.err.noKey', {'p': m.provider.company})
        ..retry = AiRetry(q, kept: false)
        ..toSettings = true;
      notifyListeners();
      _saveSoon();
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
    _marksSent = c.aiMarks.version;
    _marksSaid = c.aiMarks.isEmpty ? '' : c.aiMarks.describe();
    for (final a in files) {
      _files[a.name] = a.bytes;
      _filesLeft.remove(a.name);
    }
    attachments.clear();
    final cancel = AiCancel();
    _cancel = cancel;
    _mark();
    answer
      ..running = true
      ..started = DateTime.now()
      ..status = t('ai.st.thinking', {'m': m.label})
      ..pictures = files.where((a) => a.isImage).length;
    notifyListeners();
    // kept with the question in it before the request goes: should the page
    // close during the turn, the question comes back with Try again
    _sending = files;
    _rev++;
    _saveNow(turnStart: true);
    final box = toolbox..pictures = PictureLimits.of(m);
    void beforeWrite() {
      _openTurn();
      box.changes.beforeWrite();
    }

    final loop = AgentLoop(api: client, tools: [for (final tool in box.tools) tool.effect == ToolEffect.read && !_dispatchers.contains(tool.name) ? tool : _Tracked(tool, beforeWrite)]);
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
        permission: taskPermission,
        permissionNow: () => taskPermission,
        maxSteps: maxSteps,
        costCap: cap > 0 ? cap : null,
        // No task budget in the chat: a token countdown shown to the model made
        // it stop early and tell the user the conversation had reached its
        // limit (Anthropic advises against task budgets in interactive
        // sessions). The app's own spending cap and step limit end a task,
        // with Continue.
        taskBudget: null,
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
            _mark();
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
            try {
              if (!showChanges) return null;
              // a picture that takes too long (tiles that do not come) is
              // no reason to hold the task
              final img = await feedbackPicture(box).timeout(const Duration(seconds: 30), onTimeout: () => null);
              if (img == null) return null;
              answer.pictures++;
              return ToolOutput('The drawing after these changes (picture attached). ${lastFeedbackMapping(box) ?? ''}'.trim(), images: [img]);
            } finally {
              box.changes.endRound();
            }
          },
          onCompacted: () {
            items.insert(items.indexOf(answer), AiItem.notice(t('ai.compacted')));
            _soon();
          },
        ),
      );
    } catch (e) {
      answer
        ..error = t('ai.err.unexpected', {'e': '${e.runtimeType}'})
        ..retry = AiRetry(q, kept: false);
      // nothing kept: the question can be sent again with its attachments
      if (files.isNotEmpty && attachments.isEmpty) attachments.addAll(files);
    } finally {
      _cancel = null;
      _taskMode = null;
      pending = null;
      question = null;
      planReview = null;
      box.changes.endTask();
      _mark();
      answer.changes = _closeTurn();
      answer
        ..running = false
        ..status = '';
      for (final it in items) {
        if (it.kind == AiItemKind.assistant) it.running = false;
      }
    }
    if (turn != null) {
      // a recovery may have stripped thinking blocks from the earlier
      // history (same length: the checkpoints stay valid)
      if (turn.history != null) {
        _history
          ..clear()
          ..addAll(turn.history!);
      }
      _history.addAll(turn.messages);
      if (turn.messages.isNotEmpty && !ctx.isEmpty) attachContext = false;
      answer.pictures += _picturesIn(turn);
      pictures += answer.pictures;
      final kept = turn.messages.isNotEmpty;
      switch (turn.stop) {
        case AgentStop.cancelled:
          answer
            ..stopped = true
            ..retry = AiRetry(q, kept: kept);
        case AgentStop.stepLimit:
          answer
            ..error = t('ai.err.steps', {'n': '$maxSteps'})
            ..canContinue = true;
        case AgentStop.budget:
          answer
            ..error = t('ai.err.budget', {'c': cap.toStringAsFixed(2)})
            ..canContinue = true;
        case AgentStop.maxTokens:
          answer
            ..error = t('ai.err.length')
            ..retry = AiRetry(q, kept: kept);
        case AgentStop.error:
          answer
            ..error = turn.error == null ? t('ai.err.server', {'p': m.provider.company}) : _errorText(turn.error!, m)
            ..retry = AiRetry(q, kept: kept)
            ..toSettings = const {AiErrorKind.noKey, AiErrorKind.auth, AiErrorKind.permission, AiErrorKind.notFound, AiErrorKind.retention}.contains(turn.error?.kind);
        case AgentStop.done:
          break;
      }
      // nothing kept: the question can be sent again with its attachments
      if (turn.messages.isEmpty && files.isNotEmpty && attachments.isEmpty) attachments.addAll(files);
    }
    _tick?.cancel();
    _tick = null;
    _sending = null;
    // the project was replaced during the turn (a new one, by the AI or the
    // user): the conversation went on in it and moves with it
    if (c.project.meta.uid != _uid) {
      if (_claimed) conversations.delete(_uid);
      _uid = c.project.meta.uid;
      _claimed = !_shared;
    }
    notifyListeners();
    // what the user wrote after the last step is the next message
    if (queued.isNotEmpty && turn != null && turn.stop != AgentStop.cancelled) {
      final next = queued.join('\n\n');
      queued.clear();
      scheduleMicrotask(() => send(next));
    }
    // after that next message started, whose turn then keeps it
    _saveSoon();
  }

  static int _picturesIn(AgentTurn turn) {
    var n = 0;
    for (final call in turn.calls) {
      if (call.state == ToolCallState.done && const {'view_snapshot', 'preview_geometry', 'terrain_picture', 'trace_region'}.contains(call.name)) n++;
    }
    return n;
  }

  /// Goes on with a task that stopped at the step limit or the cap.
  Future<void> continueTask() => send(t('ai.continue.prompt'));

  /// Tries a failed or stopped answer again: the task goes on from what
  /// reached the model, or, when nothing did, the same message (with its
  /// attachments, which came back to the box) is sent again in its place.
  Future<void> resume(AiItem answer) async {
    final r = answer.retry;
    if (r == null || busy) return;
    answer.retry = null;
    if (r.kept) return continueTask();
    // the question of a turn the page closed on, brought back: its files go again
    for (final a in _retryFiles[answer] ?? const <AiAttachment>[]) {
      if (!attachments.any((x) => x.name == a.name)) attachments.add(a);
    }
    final i = items.indexOf(answer);
    if (i > 0 && items[i - 1].kind == AiItemKind.user && !items[i - 1].steered) {
      items.removeRange(i - 1, i + 1);
    } else {
      items.remove(answer);
    }
    await send(r.text);
  }

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

  // ---------------------------------------------------------------- kept in this browser

  /// Where conversations are kept between visits, by project uid: this
  /// site's IndexedDB in the browser, memory elsewhere (tests may replace
  /// it). A conversation kept is project data and pictures — the messages,
  /// the tool results, the mappings of the pictures, small attached files —
  /// like the project's own autosave in the same storage of this browser;
  /// the API keys are never in it (one typed into a text is taken out).
  static ConversationStore conversations = platformConversationStore();

  /// Characters of JSON a conversation kept may take (a larger one is kept
  /// without its pictures, see [_reduced]), and bytes of the files attached
  /// in it that are kept with it (the latest first; the others are named).
  static int keptChars = ConversationStore.maxChars;
  static int keptFileBytes = 10 * 1024 * 1024;

  /// Conversations are kept in this browser (on by default): a reload, or
  /// the project opened again later, brings its conversation back. One
  /// choice for the app; off, nothing is kept and what was kept is deleted.
  static bool get keepConversations => getPref('ai.keepChats') != 'off';

  /// The pref naming the project, never changed, whose conversation is
  /// kept: nothing else brings that one back (no autosave, no file), so the
  /// next fresh start gives its uid to the new empty project
  /// ([resumePristine]).
  static const pristinePref = 'ai.pristineUid';

  /// No change made to the project of [c] since it was created empty.
  static bool _pristine(ProjectController c) => !c.dirty && c.historyIndex == 0 && c.project.entities.isEmpty && c.project.meta.georef == null;

  /// At a fresh start (nothing recovered, opened or linked): the new empty
  /// project takes the uid of the never-changed one whose conversation is
  /// kept, so a reload brings that conversation back too (a project with
  /// changes comes back with the recovery, and its conversation with it).
  /// Not when a project kept in this browser has that uid.
  static void resumePristine(ProjectController c) {
    final uid = getPref(pristinePref);
    if (uid == null || uid.isEmpty || uid == c.project.meta.uid || !keepConversations || !_pristine(c)) return;
    if (c.store.load(uid) != null || c.store.versions(uid).isNotEmpty) return;
    c.project.meta.uid = uid;
    c.refresh();
  }

  static set keepConversations(bool on) {
    setPref('ai.keepChats', on ? 'on' : 'off');
    if (!on) {
      _forgetKept();
      return;
    }
    // the conversations on screen are kept from now on
    for (final a in _inTabs) {
      a._saveSoon();
    }
  }

  /// Deletes every conversation kept in this browser: those on screen stay,
  /// and one that goes on is kept again.
  static Future<void> deleteSavedConversations() => _forgetKept();

  static Future<void> _forgetKept() {
    for (final a in _live) {
      // a save on its way no longer counts
      a._gen++;
      a._savedRev = -1;
      a._saveScheduled = false;
    }
    return conversations.clear();
  }

  /// The assistants of the tabs open now (every one without a workspace).
  static Iterable<AiAssistant> get _inTabs {
    final w = workspace;
    return w == null ? _live : _live.where((a) => w.tabs.contains(a.c));
  }

  /// The project the conversation belongs to: it is kept under its uid.
  String _uid;

  /// This assistant keeps the conversation of [_uid]; false while another
  /// open tab's assistant keeps it (the project is open twice).
  bool _claimed = false;
  bool get _shared => _inTabs.any((a) => !identical(a, this) && a._claimed && a._uid == _uid);

  /// Changes to the conversation (each bumps [_rev]) and the last one kept.
  /// A save still on its way for an earlier conversation of the tab ([_gen]:
  /// another project, a new conversation), and a load ([_loading]), are
  /// ignored when they arrive.
  int _rev = 0, _savedRev = 0, _gen = 0, _loading = 0;
  bool _saveScheduled = false;
  bool _disposed = false;

  /// Pictures left out of the copy kept (it was too large), and the names
  /// of attached files not kept with it.
  int _dropped = 0;
  final Set<String> _filesLeft = {};

  /// The attachments of the message whose turn runs, kept with it: Try
  /// again sends them should the page close during the turn.
  List<AiAttachment>? _sending;

  /// What Try again sends with the question of a turn the page closed on.
  final Expando<List<AiAttachment>> _retryFiles = Expando('ai.retry');

  /// The JSON of each entry of a history (append-only: each is encoded
  /// once), and the base64 of each file kept, by identity.
  static final Expando<String> _jsonOf = Expando('ai.json');
  static final Expando<String> _base64Of = Expando('ai.base64');

  /// The conversation holds answers that leaving the page would lose: it is
  /// not kept in this browser as it is now (keeping off, a turn running, a
  /// save not done or refused). The page asks before it closes then.
  bool get unsavedConversation => items.any((it) => it.kind == AiItemKind.assistant && it.text.isNotEmpty) && (busy || !keepConversations || _savedRev != _rev);

  /// The tab's project was replaced (a file opened in it, File → New, the
  /// autosave recovered at start-up): the conversation follows the project.
  /// The one on screen is kept under the earlier project, and the one kept
  /// for this project comes back. During a turn the conversation goes on in
  /// the new project and moves to it when the turn ends ([send]); with
  /// keeping off it stays with the tab, as nothing would bring it back.
  void _onProject() {
    final uid = c.project.meta.uid;
    if (uid == _uid || busy) return;
    final swap = keepConversations && (items.isNotEmpty || _history.isNotEmpty);
    if (swap) {
      if (_rev != _savedRev) _saveNow();
      _reset();
    }
    _uid = uid;
    _claimed = !_shared;
    _load();
    if (swap) {
      notifyListeners();
      _mark();
    }
  }

  /// Brings back the conversation kept for the project, if there is one, as
  /// soon as it arrives; a conversation started meanwhile stays as it is.
  void _load() {
    final token = ++_loading;
    if (!keepConversations || !_claimed) return;
    final uid = _uid;
    conversations.load(uid).then((s) {
      if (s == null || token != _loading || uid != _uid || _disposed || busy || items.isNotEmpty || _history.isNotEmpty) return;
      if (!_restore(s)) return;
      notifyListeners();
      _mark();
    }, onError: (Object _) {});
  }

  /// Keeps the conversation once the changes in hand are made (one save for
  /// several in a row), unless a turn runs: its end keeps it.
  void _saveSoon() {
    _rev++;
    if (_saveScheduled) return;
    _saveScheduled = true;
    final gen = _gen;
    scheduleMicrotask(() {
      if (gen != _gen) return;
      _saveScheduled = false;
      _saveNow();
    });
  }

  /// Names the project of [uid] in [pristinePref] while its conversation is
  /// [kept] and the project unchanged; drops the name once it is not.
  void _notePristine(String uid, {required bool kept}) {
    final named = getPref(pristinePref) == uid;
    if (kept && uid == c.project.meta.uid && _pristine(c)) {
      if (!named) setPref(pristinePref, uid);
    } else if (named) {
      removePref(pristinePref);
    }
  }

  /// Writes the conversation to [conversations]: encoded now, written in
  /// the background. [turnStart]: the copy taken as a turn starts, with the
  /// question in it, before the request goes (never while it streams).
  void _saveNow({bool turnStart = false}) {
    if (!keepConversations || (busy && !turnStart) || _disposed) return;
    if (!_claimed) {
      _claimed = !_shared;
      if (!_claimed) return;
    }
    final uid = _uid, rev = _rev, gen = _gen;
    void done(bool ok) {
      if (ok && gen == _gen && rev > _savedRev) _savedRev = rev;
    }

    // nothing to bring back (rewound to the first message): nothing kept
    if (!items.any((it) => it.kind != AiItemKind.notice)) {
      _notePristine(uid, kept: false);
      conversations.delete(uid).then((_) => done(true), onError: (Object _) {});
      return;
    }
    String? json;
    try {
      json = _encode();
    } catch (_) {
      json = null;
    }
    _notePristine(uid, kept: json != null);
    // too large even without its pictures: not kept (leaving the page asks first)
    if (json == null) return;
    conversations.save(uid, json).then(done, onError: (Object _) {});
  }

  /// The conversation as it is kept (format 1): the history exactly as the
  /// API took it, entry by entry; only one larger than [keptChars] is kept
  /// as a copy without its thinking blocks and pictures ([_reduced]). Null
  /// when even that is too large.
  String? _encode() {
    // a key typed into a message or the instructions is not kept
    final keys = [
      for (final p in AiProvider.values)
        if (keyOf(p) case final k? when k.length >= 8) k,
    ];
    String clean(String s) {
      for (final k in keys) {
        if (s.contains(k)) s = s.replaceAll(k, '[key]');
      }
      return s;
    }

    var history = [for (final m in _history) _jsonOf[m] ??= clean(jsonEncode(m))];
    // the files attached, the latest first, up to keptFileBytes in all
    final kept = <String>{};
    var bytes = 0;
    for (final name in _files.keys.toList().reversed) {
      final n = _files[name]!.length;
      if (bytes + n > keptFileBytes) continue;
      bytes += n;
      kept.add(name);
    }
    final left = {..._filesLeft, ..._files.keys.where((n) => !kept.contains(n))};
    final files = StringBuffer();
    for (final name in _files.keys.where(kept.contains)) {
      final b = _files[name]!;
      if (files.isNotEmpty) files.write(',');
      files
        ..write(jsonEncode(name))
        ..write(':"')
        ..write(_base64Of[b] ??= base64Encode(b))
        ..write('"');
    }
    var dropped = _dropped;
    var meta = clean(jsonEncode(_meta(dropped, left)));
    int size(Iterable<String> h) => h.fold(meta.length + files.length + 64, (s, x) => s + x.length + 1);
    if (size(history) > keptChars) {
      // room for the history, and for the count of pictures left out in the meta
      final r = _reduced(clean, keptChars - size(const []) - 64);
      if (r == null) return null;
      history = r.$1;
      dropped += r.$2;
      meta = clean(jsonEncode(_meta(dropped, left)));
    }
    return (StringBuffer('{"v":1,"meta":')
          ..write(meta)
          ..write(',"history":[')
          ..writeAll(history, ',')
          ..write('],"files":{')
          ..write(files)
          ..write('}}'))
        .toString();
  }

  /// Everything of the conversation but its history and files.
  Map<String, Object?> _meta(int dropped, Set<String> filesLeft) {
    // the notices of this page are not kept: the checkpoints count the items without them
    final before = List<int>.filled(items.length + 1, 0);
    for (var i = 0; i < items.length; i++) {
      before[i + 1] = before[i] + (items[i].transient ? 1 : 0);
    }
    int at(int i) => i - before[i.clamp(0, items.length)];
    final sending = _sending;
    return {
      'uid': _uid,
      'name': c.project.meta.name,
      'provider': _convModel?.provider.name,
      'model': _convModel?.id,
      'system': _system,
      'items': [
        for (final it in items)
          if (!it.transient) _itemJson(it, at),
      ],
      'todos': [
        for (final x in todos) {'c': x.content, 's': x.status.name},
      ],
      'usage': _usageJson(usage),
      'cost': cost,
      'pictures': pictures,
      'context': attachContext,
      'marks': _marksSaid,
      if (dropped > 0) 'dropped': dropped,
      if (filesLeft.isNotEmpty) 'filesLeft': [...filesLeft],
      if (busy && sending != null)
        'pending': [
          for (final a in sending) {'name': a.name, 'mime': a.mime, if (a.note.isNotEmpty) 'note': a.note, if (a.place.isNotEmpty) 'place': a.place, if (a.asText) 'text': true},
        ],
      // the mappings of the pictures, for image_to_world on the earlier ones
      if (_toolbox != null) 'vision': VisionSession.of(_toolbox!).toJson(),
      'views': VisionSession.of(c).toJson(),
    };
  }

  /// An entry of the transcript as it is kept: what the panel shows. Tool
  /// calls keep their summary, state and first line of result (not their
  /// input); approvals, questions and plans waiting are not kept (a turn is
  /// kept as it starts and when it ends).
  static Map<String, Object?> _itemJson(AiItem it, int Function(int) at) {
    final cp = it.checkpoint, ch = it.changes, r = it.retry;
    return {
      'k': it.kind.name,
      'text': it.text,
      if (it.attachments.isNotEmpty) 'att': it.attachments,
      if (it.contextTokens != null) 'ctx': it.contextTokens,
      if (it.steered) 'steered': true,
      if (cp != null) 'cp': [cp.history, at(cp.items)],
      if (it.calls.isNotEmpty)
        'calls': [
          for (final x in it.calls) {'id': x.id, 'name': x.name, 'sum': x.summary, 'eff': x.effect.name, 'st': x.state.name, if (x.result.isNotEmpty) 'res': x.result},
        ],
      if (it.running) 'running': true,
      'error': ?it.error,
      if (it.canContinue) 'cont': true,
      if (it.stopped) 'stopped': true,
      if (r != null) 'retry': {'text': r.text, 'kept': r.kept},
      if (it.toSettings) 'settings': true,
      if (it.usage.totalInput + it.usage.output > 0) 'usage': _usageJson(it.usage),
      if (it.cost != 0) 'cost': it.cost,
      if (it.pictures != 0) 'pics': it.pictures,
      if (it.model.isNotEmpty) 'model': it.model,
      if (ch != null) 'chg': {'add': ch.added, 'chg': ch.changed, 'rem': ch.removed, 'set': ch.settings, if (ch.undone) 'undone': true},
    };
  }

  static AiItem _itemOf(Map j) {
    final text = '${j['text'] ?? ''}';
    final it = switch (AiItemKind.values.byName(j['k'] as String)) {
      AiItemKind.user => AiItem.user(text, attachments: [for (final a in (j['att'] as List?) ?? const []) '$a'], contextTokens: (j['ctx'] as num?)?.toInt(), steered: j['steered'] == true),
      AiItemKind.assistant => AiItem.assistant()..text = text,
      AiItemKind.notice => AiItem.notice(text),
    };
    final cp = j['cp'];
    if (cp is List && cp.length == 2) it.checkpoint = AiCheckpoint(history: (cp[0] as num).toInt(), items: (cp[1] as num).toInt(), index: -1, restored: true);
    for (final x in (j['calls'] as List?) ?? const []) {
      final m = x as Map;
      final state = ToolCallState.values.byName(m['st'] as String);
      it.calls.add(
        AgentToolCall(id: '${m['id']}', name: '${m['name']}', input: const {}, summary: '${m['sum'] ?? m['name']}', effect: ToolEffect.values.byName(m['eff'] as String))
          // a call the page closed on did not finish
          ..state = state == ToolCallState.running || state == ToolCallState.waiting ? ToolCallState.skipped : state
          ..result = '${m['res'] ?? ''}',
      );
    }
    final r = j['retry'], ch = j['chg'];
    it
      ..running = j['running'] == true
      ..error = j['error'] as String?
      ..canContinue = j['cont'] == true
      ..stopped = j['stopped'] == true
      ..retry = r is Map ? AiRetry('${r['text'] ?? ''}', kept: r['kept'] == true) : null
      ..toSettings = j['settings'] == true
      ..usage = _usageOf(j['usage'])
      ..cost = (j['cost'] as num?)?.toDouble() ?? 0
      ..pictures = (j['pics'] as num?)?.toInt() ?? 0
      ..model = '${j['model'] ?? ''}';
    // the undo steps it made were of the page that made them (or of the
    // project before it was opened again): shown, no longer undoable
    if (ch is Map) {
      it.changes = AiTurnChanges(
        added: _counts(ch['add']),
        changed: _counts(ch['chg']),
        removed: _counts(ch['rem']),
        settings: [for (final s in (ch['set'] as List?) ?? const []) '$s'],
        endIndex: -1,
        steps: 0,
      )..undone = ch['undone'] == true;
    }
    return it;
  }

  static Map<String, int> _usageJson(AiUsage u) => {'i': u.input, 'o': u.output, 'w': u.cacheWrite, 'r': u.cacheRead};

  static AiUsage _usageOf(Object? j) {
    int n(String k) => j is Map && j[k] is num ? (j[k] as num).toInt() : 0;
    return AiUsage(input: n('i'), output: n('o'), cacheWrite: n('w'), cacheRead: n('r'));
  }

  static Map<String, int> _counts(Object? j) => {
    if (j is Map)
      for (final e in j.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
  };

  /// The conversation kept in [json], read whole; null when it cannot be.
  _Kept? _read(String json) {
    try {
      final j = jsonDecode(json);
      if (j is! Map || j['v'] != 1 || j['meta'] is! Map || j['history'] is! List) return null;
      final meta = j['meta'] as Map;
      AiModel? model;
      final id = meta['model'];
      if (id is String) {
        final provider = AiProvider.values.byName(meta['provider'] as String);
        // a model this version no longer offers: another of its company, whose API reads the history
        model = AiModel.all.where((m) => m.id == id).firstOrNull ?? AiModel.all.firstWhere((m) => m.provider == provider && m.listed);
      }
      final history = [for (final m in j['history'] as List) m as Map<String, dynamic>];
      if (history.isNotEmpty && model == null) return null;
      final files = <String, Uint8List>{
        if (j['files'] case final Map f)
          for (final e in f.entries) '${e.key}': base64Decode(e.value as String),
      };
      return (
        items: [for (final x in meta['items'] as List) _itemOf(x as Map)],
        history: history,
        system: meta['system'] as String?,
        model: model,
        todos: [for (final x in (meta['todos'] as List?) ?? const []) AiTodo('${(x as Map)['c']}', TodoStatus.values.byName(x['s'] as String))],
        usage: _usageOf(meta['usage']),
        cost: (meta['cost'] as num?)?.toDouble() ?? 0,
        pictures: (meta['pictures'] as num?)?.toInt() ?? 0,
        context: meta['context'] != false,
        marks: meta['marks'] as String?,
        dropped: (meta['dropped'] as num?)?.toInt() ?? 0,
        filesLeft: [for (final n in (meta['filesLeft'] as List?) ?? const []) '$n'],
        files: files,
        pending: [
          for (final x in (meta['pending'] as List?) ?? const [])
            if (files[(x as Map)['name']] case final bytes?)
              AiAttachment('${x['name']}', '${x['mime']}', bytes, note: '${x['note'] ?? ''}')
                ..place = '${x['place'] ?? ''}'
                ..asText = x['text'] == true,
        ],
        vision: meta['vision'],
        views: meta['views'],
      );
    } catch (_) {
      return null;
    }
  }

  /// Puts back the conversation kept in [s]; false, and nothing changed,
  /// when it cannot be read. It ends with a notice of when it was saved;
  /// an answer the page closed on shows as stopped, with Try again.
  bool _restore(StoredConversation s) {
    final k = _read(s.json);
    if (k == null) return false;
    items
      ..clear()
      ..addAll(k.items);
    _history
      ..clear()
      ..addAll(k.history);
    _system = k.system;
    _convModel = k.model;
    _toolbox = null;
    todos = List.unmodifiable(k.todos);
    usage = k.usage;
    cost = k.cost;
    pictures = k.pictures;
    attachContext = k.context;
    _files
      ..clear()
      ..addAll(k.files);
    _filesLeft
      ..clear()
      ..addAll(k.filesLeft);
    _dropped = k.dropped;
    // marks unchanged since the model heard of them need not go again;
    // otherwise the next message says what they are now
    final marks = c.aiMarks;
    _marksSaid = k.marks;
    _marksSent = k.marks == null ? -1 : (k.marks == (marks.isEmpty ? '' : marks.describe()) ? marks.version : -2);
    if (k.vision != null) VisionSession.of(toolbox).restore(k.vision);
    VisionSession.of(c).restore(k.views);
    var interrupted = false;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (!it.running) continue;
      it.running = false;
      if (it.kind != AiItemKind.assistant) continue;
      // nothing of that turn reached the history kept: the question goes again
      interrupted = true;
      it.stopped = true;
      final q = items.take(i).lastWhere((x) => x.kind == AiItemKind.user && !x.steered, orElse: () => AiItem.user('')).text;
      it.retry ??= AiRetry(q, kept: false);
      if (k.pending.isNotEmpty) _retryFiles[it] = k.pending;
    }
    items.add(
      AiItem.notice(
        [
          t('ai.restored', {'d': _when(s.saved)}),
          if (_dropped > 0) t('ai.restored.reduced'),
          if (_filesLeft.isNotEmpty) t('ai.restored.files', {'f': _filesLeft.join(', ')}),
          if (interrupted) t('ai.restored.interrupted'),
        ].join(' '),
      )..transient = true,
    );
    // as it is kept
    _savedRev = ++_rev;
    return true;
  }

  /// [d] as 2026-10-30 14:05.
  static String _when(DateTime d) {
    String two(int v) => '$v'.padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// A copy of the history within [budget] characters of JSON (its entries
  /// encoded) and the pictures it left out, or null. Any change to earlier
  /// entries makes the thinking blocks after them invalid (a signature
  /// covers the conversation before its block, and the Claude models that
  /// keep their thinking refuse a history that changed), so every thinking
  /// block leaves the copy first: a history without them is one the API
  /// takes, as in the recovery of claude_api.dart. Then the pictures and
  /// PDFs, the oldest first — those of the tool results before the user's
  /// own — give way to a note for the model until the copy fits.
  (List<String>, int)? _reduced(String Function(String) clean, int budget) {
    final anthropic = (_convModel ?? model).provider == AiProvider.anthropic;
    final h = anthropic ? _withoutThinking(_history) : [..._history];
    final out = [for (final m in h) _jsonOf[m] ??= clean(jsonEncode(m))];
    var size = out.fold(0, (s, x) => s + x.length + 1);
    var dropped = 0;
    for (final user in const [false, true]) {
      for (var i = 0; i < h.length && size > budget; i++) {
        final (m, n) = _withoutPictures(h[i], anthropic: anthropic, user: user);
        if (n == 0) continue;
        final s = clean(jsonEncode(m));
        size += s.length - out[i].length;
        out[i] = s;
        h[i] = m;
        dropped += n;
      }
    }
    return size > budget ? null : (out, dropped);
  }

  static bool _isThinking(Object? b) => b is Map && (b['type'] == 'thinking' || b['type'] == 'redacted_thinking');

  /// [h] without its thinking blocks ([stripThinking]); an answer that was
  /// nothing but thinking, which it leaves as it was, says "…" instead.
  static List<Map<String, dynamic>> _withoutThinking(List<Map<String, dynamic>> h) => [
    for (final m in stripThinking(h))
      if (m['role'] == 'assistant' && m['content'] is List && (m['content'] as List).isNotEmpty && (m['content'] as List).every(_isThinking))
        {
          ...m,
          'content': [
            {'type': 'text', 'text': '…'},
          ],
        }
      else
        m,
  ];

  /// What stands, for the model, for a picture or a PDF left out.
  static const _leftOut =
      '[A picture or a PDF was here. It was left out when this conversation was kept in the browser, as the conversation was too large to keep whole: take a new picture, or ask the user for the file, if you need it again.]';

  /// [m] with its pictures and PDFs ([user]: those the user attached, else
  /// those of tool results) replaced by [_leftOut], and how many.
  static (Map<String, dynamic>, int) _withoutPictures(Map<String, dynamic> m, {required bool anthropic, required bool user}) {
    var n = 0;
    List<Object?> swap(List blocks, Set<String> types, String textType) {
      final out = <Object?>[];
      for (final b in blocks) {
        if (b is Map && types.contains(b['type'])) {
          n++;
          out.add({'type': textType, 'text': _leftOut});
        } else {
          out.add(b);
        }
      }
      return out;
    }

    if (anthropic) {
      final c = m['content'];
      if (m['role'] != 'user' || c is! List) return (m, 0);
      final out = user
          ? swap(c, const {'image', 'document'}, 'text')
          : [
              for (final b in c)
                if (b is Map && b['type'] == 'tool_result' && b['content'] is List)
                  {
                    ...b,
                    'content': swap(b['content'] as List, const {'image'}, 'text'),
                  }
                else
                  b,
            ];
      return n == 0 ? (m, 0) : ({...m, 'content': out}, n);
    }
    // OpenAI: the tools' pictures in function outputs, the user's in user messages
    if (!user && m['type'] == 'function_call_output' && m['output'] is List) {
      final out = swap(m['output'] as List, const {'input_image'}, 'input_text');
      return n == 0 ? (m, 0) : ({...m, 'output': out}, n);
    }
    if (user && m['type'] == 'message' && m['role'] == 'user' && m['content'] is List) {
      final out = swap(m['content'] as List, const {'input_image', 'input_file'}, 'input_text');
      return n == 0 ? (m, 0) : ({...m, 'content': out}, n);
    }
    return (m, 0);
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _tick?.cancel();
    c.removeListener(_onProject);
    _live.remove(this);
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
  AgentPermission get permission => ai.taskPermission;

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
    AiAssistant._mark();
    return q.done.future;
  }

  @override
  Future<PlanDecision?> reviewPlan(String plan) {
    final r = AiPlanReview(plan);
    ai.planReview = r;
    ai.refresh();
    AiAssistant._mark();
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
    // in the background: the user keeps watching the task, which goes on in this tab
    w.addTab(select: false).openProject(p, dirty: true);
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
    w.addTab(select: false);
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
