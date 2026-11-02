/// The agent loop of the AI assistant: the model answers, asks for tools,
/// the program runs them on the open project and hands back the results,
/// until the model ends its turn, the step limit or the spending cap is
/// reached, or the user stops it.
///
/// Pure Dart and free of the app and of the provider: the tools are objects
/// the app provides, approvals are a callback, the model is any [AiClient]
/// (Anthropic or OpenAI), whose formats the loop never looks into. What the
/// model may change follows [AgentPermission]; a change the user skips, an
/// invalid input or a failing tool goes back to the model as an error
/// result, so it can adapt instead of the turn breaking. What the user types
/// while the model works goes to it with the next round of results.
library;

import 'dart:async';
import 'dart:convert';

import '../model/geometry.dart';
import 'llm.dart';
import 'llm_formats.dart' show steeringPrefix;

export 'llm.dart';

/// What a tool does: reads the project; changes it (an undo step); saves
/// a file; or asks another service over the network (a geocoder, a
/// catalogue site) without changing the project.
enum ToolEffect { read, write, export, network }

/// What the assistant may do without asking. [plan]: it explores with the
/// read tools and presents a plan; changes wait until the user approves it.
enum AgentPermission { readOnly, plan, ask, auto }

/// The user's answer to a change awaiting approval.
enum Approval { apply, skip, stop }

/// A tool input the tool cannot use; the message goes back to the model.
class ToolInputError implements Exception {
  ToolInputError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A tool the model may call.
abstract class AgentTool {
  String get name;
  String get description;
  Map<String, Object?> get inputSchema;
  ToolEffect get effect => ToolEffect.read;

  /// What one call does (a dispatcher tool takes the effect of what it
  /// runs); [effect] by default.
  ToolEffect effectOf(Map<String, dynamic> input) => effect;

  /// One line saying what the call will do, for the approval card and the
  /// transcript (in the user's language).
  String describe(Map<String, dynamic> input) => name;

  /// Calls confirmed even when changes apply automatically: exports and
  /// large deletions (requests to other services follow the mode: asked in
  /// "ask", free in "apply automatically").
  bool mustConfirm(Map<String, dynamic> input) => effectOf(input) == ToolEffect.export;

  /// The input the call runs with, fixed when the call is planned: what it
  /// would otherwise read from the user's screen as it runs (the selection)
  /// taken now, so the approval card shows exactly what runs, whatever the
  /// user clicks while the card waits. [input] by default.
  Map<String, dynamic> bind(Map<String, dynamic> input) => input;

  Future<ToolOutput> run(Map<String, dynamic> input);

  /// The tool as every provider describes it (the order of a conversation's
  /// tools stays fixed: it is part of the cached prefix).
  AiToolSpec get spec => AiToolSpec(name, description, inputSchema);
}

/// A tool made of closures.
class FnTool extends AgentTool {
  FnTool({required this.name, required this.description, required this.inputSchema, this.effect = ToolEffect.read, this.effectFor, this.summary, this.confirm, this.binder, required this.handler});
  @override
  final String name;
  @override
  final String description;
  @override
  final Map<String, Object?> inputSchema;
  @override
  final ToolEffect effect;

  /// [effectOf] of a call ([effect] when null).
  final ToolEffect Function(Map<String, dynamic> input)? effectFor;

  /// [describe] of a call (the tool name when null).
  final String Function(Map<String, dynamic> input)? summary;

  /// Calls to confirm even when changes apply automatically.
  final bool Function(Map<String, dynamic> input)? confirm;

  /// [bind] of a call (the input as it is when null).
  final Map<String, dynamic> Function(Map<String, dynamic> input)? binder;
  final Future<ToolOutput> Function(Map<String, dynamic> input) handler;

  @override
  ToolEffect effectOf(Map<String, dynamic> input) => effectFor?.call(input) ?? effect;
  @override
  String describe(Map<String, dynamic> input) => summary?.call(input) ?? name;
  @override
  bool mustConfirm(Map<String, dynamic> input) => effectOf(input) == ToolEffect.export || (confirm?.call(input) ?? false);
  @override
  Map<String, dynamic> bind(Map<String, dynamic> input) => binder?.call(input) ?? input;
  @override
  Future<ToolOutput> run(Map<String, dynamic> input) => handler(input);
}

/// First problem of [value] against [schema] (types, enums, required and
/// unknown fields, recursively), or null when it fits.
String? schemaProblem(Map<String, Object?> schema, Object? value, [String path = 'input']) {
  final type = schema['type'];
  if (value == null) return null;
  final ok = switch (type) {
    'string' => value is String,
    'number' => value is num,
    'integer' => value is int || (value is num && value == value.roundToDouble()),
    'boolean' => value is bool,
    'array' => value is List,
    'object' => value is Map,
    _ => true,
  };
  if (!ok) return '"$path" must be of type $type.';
  final options = schema['enum'];
  if (options is List && !options.contains(value)) return '"$path" must be one of: ${options.join(', ')}.';
  if (value is List) {
    final items = schema['items'];
    if (items is Map<String, Object?>) {
      for (var i = 0; i < value.length; i++) {
        final p = schemaProblem(items, value[i], '$path[$i]');
        if (p != null) return p;
      }
    }
    final max = schema['maxItems'];
    if (max is int && value.length > max) return '"$path" has ${value.length} items; at most $max are allowed per call.';
    final min = schema['minItems'];
    if (min is int && value.length < min) return '"$path" has ${value.length} items; at least $min are needed.';
  }
  if (value is Map) {
    final props = schema['properties'];
    final known = props is Map ? props : const {};
    for (final r in (schema['required'] as List? ?? const [])) {
      if (value[r] == null) return 'Missing "$path.$r".';
    }
    if (schema['additionalProperties'] == false) {
      for (final k in value.keys) {
        if (!known.containsKey(k)) return 'Unknown field "$path.$k". Allowed: ${known.keys.join(', ')}.';
      }
    }
    for (final e in value.entries) {
      final p = known[e.key];
      if (p is Map<String, Object?>) {
        final problem = schemaProblem(p, e.value, '$path.${e.key}');
        if (problem != null) return problem;
      }
    }
  }
  return null;
}

/// Typed access to a tool input, with errors the model can act on.
class ToolArgs {
  ToolArgs(this.input);
  final Map<String, dynamic> input;

  bool has(String k) => input[k] != null;

  String? str(String k, {bool required = false}) {
    final v = input[k];
    if (v == null) {
      if (required) throw ToolInputError('Missing "$k".');
      return null;
    }
    if (v is! String) throw ToolInputError('"$k" must be a text.');
    final s = v.trim();
    if (required && s.isEmpty) throw ToolInputError('"$k" must not be empty.');
    return s;
  }

  double? number(String k, {double? min, double? max, bool required = false}) {
    final v = input[k];
    if (v == null) {
      if (required) throw ToolInputError('Missing "$k".');
      return null;
    }
    if (v is! num || !v.isFinite) throw ToolInputError('"$k" must be a number.');
    final d = v.toDouble();
    if ((min != null && d < min) || (max != null && d > max)) throw ToolInputError('"$k" = $d is outside ${min ?? '-∞'} … ${max ?? '∞'}.');
    return d;
  }

  int? integer(String k, {int? min, int? max, bool required = false}) {
    final d = number(k, min: min?.toDouble(), max: max?.toDouble(), required: required);
    if (d == null) return null;
    if (d != d.roundToDouble()) throw ToolInputError('"$k" must be a whole number.');
    return d.toInt();
  }

  bool? flag(String k) {
    final v = input[k];
    if (v == null) return null;
    if (v is! bool) throw ToolInputError('"$k" must be true or false.');
    return v;
  }

  List<String> strings(String k, {bool required = false}) {
    final v = input[k];
    if (v == null) {
      if (required) throw ToolInputError('Missing "$k".');
      return const [];
    }
    if (v is! List || v.any((x) => x is! String)) throw ToolInputError('"$k" must be a list of texts.');
    return [for (final x in v) (x as String).trim()];
  }

  /// A point `[x, y]` in metres.
  static Pt pointOf(Object? v, String what) {
    if (v is List && v.length >= 2 && v[0] is num && v[1] is num && (v[0] as num).isFinite && (v[1] as num).isFinite) return Pt((v[0] as num).toDouble(), (v[1] as num).toDouble());
    throw ToolInputError('$what must be a point [x, y] in metres.');
  }

  Pt? point(String k, {bool required = false}) {
    final v = input[k];
    if (v == null) {
      if (required) throw ToolInputError('Missing "$k".');
      return null;
    }
    return pointOf(v, '"$k"');
  }

  /// A list of points `[[x, y], …]`.
  static List<Pt> pointsOf(Object? v, String what, {int min = 1, int max = 5000}) {
    if (v is! List) throw ToolInputError('$what must be a list of points [[x, y], …] in metres.');
    if (v.length < min || v.length > max) throw ToolInputError('$what needs $min to $max points (got ${v.length}).');
    return [for (var i = 0; i < v.length; i++) pointOf(v[i], '$what[$i]')];
  }

  List<Pt>? points(String k, {int min = 1, int max = 5000, bool required = false}) {
    final v = input[k];
    if (v == null) {
      if (required) throw ToolInputError('Missing "$k".');
      return null;
    }
    return pointsOf(v, '"$k"', min: min, max: max);
  }
}

enum ToolCallState { waiting, running, done, failed, skipped, refused }

/// One tool call of a turn, as the transcript shows it.
class AgentToolCall {
  AgentToolCall({required this.id, required this.name, required this.input, required this.summary, required this.effect});
  final String id;
  final String name;
  final Map<String, dynamic> input;

  /// What the call does, in the user's language.
  final String summary;
  final ToolEffect effect;
  ToolCallState state = ToolCallState.running;

  /// The first line of the result (or of the error).
  String result = '';
  bool get isChange => effect != ToolEffect.read;
}

enum AgentStop { done, maxTokens, stepLimit, budget, cancelled, error }

/// What a turn produced.
class AgentTurn {
  AgentTurn({
    required this.messages,
    required this.text,
    required this.usage,
    required this.cost,
    required this.steps,
    required this.stop,
    required this.calls,
    this.error,
    this.compactions = 0,
    this.history,
    this.models = const [],
    this.prefixDrops = 0,
    this.effortDeclined = false,
    this.lightened = false,
  });

  /// The models that answered, in order, each once (a server-side fallback
  /// may answer for the model asked for, and then go on for a while).
  final List<String> models;

  /// Thinking blocks the API dropped because the conversation before them
  /// had changed ([AiReply.prefixDrops]): it should not happen, and costs
  /// the cache of the conversation from there on.
  final int prefixDrops;

  /// The API turned down the effort message given with the question: the
  /// turn ran with that effort as the request's own instead.
  final bool effortDeclined;

  /// A round of results was too large or had a picture the API refused:
  /// it went again without its pictures.
  final bool lightened;

  /// Entries to append to the conversation, in the provider's format: the
  /// question and everything the model and the tools added, ending in a
  /// valid state (every tool call answered). When the API refused a request,
  /// what that request added is left out — except a round of tools that ran
  /// (they may have changed the project, so the conversation must say so),
  /// kept without its pictures. Empty when nothing came back and nothing
  /// ran, so the question can be asked again.
  final List<Map<String, dynamic>> messages;

  /// The conversation before the turn as the client rewrote it so that the
  /// API would take it (thinking blocks it no longer accepted taken out,
  /// once); null when unchanged. It has the entries the history had, in
  /// the same places: the caller replaces its copy with it, then appends
  /// [messages].
  final List<Map<String, dynamic>>? history;
  final String text;
  final AiUsage usage;

  /// US$ at list prices (an estimate).
  final double cost;
  final int steps;
  final AgentStop stop;
  final List<AgentToolCall> calls;
  final AiError? error;

  /// Times the server summarised the earlier conversation during the turn.
  final int compactions;
}

/// What the loop is doing, for the status line.
class AgentStatus {
  const AgentStatus.thinking() : kind = 'thinking', tool = '', wait = Duration.zero, note = '', reason = null;

  /// Running [tool]; [note]: what the model wrote on its progress before
  /// the calls of this step, if anything.
  const AgentStatus.tool(this.tool, {this.note = ''}) : kind = 'tool', wait = Duration.zero, reason = null;
  const AgentStatus.approval(this.tool) : kind = 'approval', wait = Duration.zero, note = '', reason = null;

  /// Trying again in [wait] after [reason].
  const AgentStatus.retry(this.wait, {this.reason}) : kind = 'retry', tool = '', note = '';

  /// A note the model writes on its progress between tool calls ([note],
  /// one line), as it arrives.
  const AgentStatus.update(this.note) : kind = 'update', tool = '', wait = Duration.zero, reason = null;
  final String kind;
  final String tool;
  final Duration wait;
  final String note;
  final AiErrorKind? reason;
}

class AgentEvents {
  const AgentEvents({this.onText, this.onCall, this.onStatus, this.approve, this.onUsage, this.steer, this.afterRound, this.onCompacted, this.onProgress, this.onModel});
  final void Function(String delta)? onText;

  /// The turn so far, as entries a conversation could end with (every tool
  /// call answered: those still to run as not run), after each change and
  /// each round: kept, it brings the conversation back as far as it went
  /// should the page close in the middle of the turn. [changed]: a change
  /// ran since the last call.
  final void Function(List<Map<String, dynamic>> messages, {required bool changed})? onProgress;

  /// The model that served an answer, when it is not the one asked for (a
  /// server-side fallback).
  final void Function(String model)? onModel;

  /// A call was added or changed state.
  final void Function(AgentToolCall call)? onCall;
  final void Function(AgentStatus status)? onStatus;

  /// Asked for every change that needs the user's approval; a missing
  /// callback skips them.
  final Future<Approval> Function(AgentToolCall call)? approve;
  final void Function(AiUsage usage, double cost)? onUsage;

  /// What the user wrote while the model worked, taken (and emptied) after
  /// each round of tools; it goes to the model with the results.
  final List<AiPart> Function()? steer;

  /// After a round of tools in which something changed: more for the model
  /// (e.g. a picture of the drawing now), added to the result of the last
  /// change of the round.
  final Future<ToolOutput?> Function(List<AgentToolCall> round)? afterRound;

  /// The server summarised the earlier conversation.
  final void Function()? onCompacted;
}

class AgentLoop {
  AgentLoop({required this.api, required this.tools, this.maxResultChars = 16000});
  final AiClient api;
  final List<AgentTool> tools;
  final int maxResultChars;

  /// Least output limit of a request under a spending cap (see [run]): an
  /// answer this long still fits a round of tool calls.
  static const minCappedOutput = 16000;

  /// What a picture or a PDF left out of a round of results says to the
  /// model.
  static const leftOut = '[A picture was left out: the request was too large, or the API refused it. Take a smaller one (view_snapshot with a smaller size or region) if you need it.]';

  /// The tools in a fixed order (part of the cached prefix of every request
  /// of a conversation).
  List<AiToolSpec> get specs => [for (final t in tools) t.spec];

  static AiToolResult _error(String id, String text) => AiToolResult(id, ToolOutput.error(text));

  /// Runs one user message [user] (in the provider's format, see
  /// [AiClient.userMessage]) after [history]: at most [maxSteps] requests
  /// to the model, and no new request once [costCap] US$ are spent; each
  /// request may write no more than what is left of the cap buys (at least
  /// [minCappedOutput] tokens). [extra] entries follow the message (an
  /// effort message, [AiClient.effortMessage]). [permissionNow], when
  /// given, is asked at every call (the user may approve a plan or change
  /// the mode while the turn runs).
  Future<AgentTurn> run({
    required AiModel model,
    AiEffort effort = AiEffort.medium,
    required String system,
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> user,
    List<Map<String, dynamic>> extra = const [],
    AgentPermission permission = AgentPermission.ask,
    AgentPermission Function()? permissionNow,
    int maxSteps = 30,
    double? costCap,
    int? taskBudget,
    int? compactAt,
    bool longCache = false,
    required AiCancel cancel,
    AgentEvents events = const AgentEvents(),
  }) async {
    final defs = specs;
    final byName = {for (final t in tools) t.name: t};
    // the conversation before the turn, rewritten at most by a client's
    // recovery (AgentTurn.history)
    var past = history;
    var rewrote = false;
    final kept = <Map<String, dynamic>>[user, ...extra];
    var requestEffort = effort;
    var effortDeclined = false;
    // entries of [kept] in the input of the last request the API accepted:
    // a request it refuses takes back what came after them
    var accepted = 0;
    // the calls of the last answer kept, until their results go in, and
    // the results made so far
    var open = const <AiToolCall>[];
    var results = <AiToolResult>[];
    // the last round of results put in [kept]: where, and what it was made
    // of (to send it again without its pictures)
    var roundAt = -1;
    var roundResults = <AiToolResult>[];
    var roundUser = <AiPart>[];
    String? roundNote;
    var lightened = false;
    final calls = <AgentToolCall>[];
    final text = StringBuffer();
    var usage = AiUsage.zero;
    var cost = 0.0;
    var steps = 0;
    var compactions = 0;
    var prefixDrops = 0;
    final models = <String>[];
    var warnedBudget = false;
    final stopped = Completer<Approval>();
    cancel.onCancel(() {
      if (!stopped.isCompleted) stopped.complete(Approval.stop);
    });

    // the calls of [open] without a result yet, answered as not run
    List<AiToolResult> closing(String why) {
      final done = {for (final r in results) r.id};
      return [
        ...results,
        for (final u in open)
          if (!done.contains(u.id)) _error(u.id, why),
      ];
    }

    void progress({required bool changed}) {
      final f = events.onProgress;
      if (f == null) return;
      try {
        f([...kept, if (open.isNotEmpty) ...api.toolResults(closing('Not run: the request ended early. Call it again if it is still needed.'))], changed: changed);
      } catch (_) {
        // keeping a copy is no reason to stop
      }
    }

    void spend(AiUsage u, AiModel at) {
      if (u.isZero) return;
      usage += u;
      cost += u.cost(at);
      events.onUsage?.call(usage, cost);
    }

    AgentTurn end(AgentStop stop, [AiError? e]) {
      if (open.isNotEmpty) {
        // a round the turn did not finish: every call still gets an answer,
        // so the conversation stays one the API takes
        final why = switch (stop) {
          AgentStop.cancelled => 'Not run: the user stopped the assistant.',
          AgentStop.done => 'Not run: your answer ended before this call could run. Call it again if it is still needed.',
          _ => 'Not run: the request ended early${e == null ? '' : ' (${e.kind.name})'}. Call it again if it is still needed.',
        };
        kept.addAll(api.toolResults(closing(why)));
        open = const [];
      }
      // only the question (and its effort message) left: nothing came back
      final asked = effortDeclined ? 1 : 1 + extra.length;
      return AgentTurn(
        messages: kept.length > asked ? kept : const [],
        text: text.toString(),
        usage: usage,
        cost: cost,
        steps: steps,
        stop: stop,
        calls: calls,
        error: e,
        compactions: compactions,
        history: rewrote ? past : null,
        models: models,
        prefixDrops: prefixDrops,
        effortDeclined: effortDeclined,
        lightened: lightened,
      );
    }

    // the last round of results without its pictures (and without the
    // pictures of what the user wrote with it); false when it had none
    bool lighten() {
      if (roundAt < 0 || roundAt >= kept.length) return false;
      final pictures = roundResults.any((r) => r.output.images.isNotEmpty) || roundUser.any((p) => p is AiImagePart || p is AiPdfPart);
      if (!pictures) return false;
      final light = [for (final r in roundResults) r.output.images.isEmpty ? r : AiToolResult(r.id, ToolOutput('${r.output.text}\n$leftOut'.trim(), isError: r.output.isError))];
      final user = [for (final p in roundUser) p is AiImagePart || p is AiPdfPart ? const AiTextPart(leftOut) : p];
      kept
        ..removeRange(roundAt, kept.length)
        ..addAll(api.toolResults(light, user: user, note: roundNote));
      roundResults = light;
      roundUser = user;
      return true;
    }

    try {
      while (true) {
        if (cancel.cancelled) return end(AgentStop.cancelled);
        if (costCap != null && steps > 0 && cost >= costCap) return end(AgentStop.budget);
        steps++;
        events.onStatus?.call(const AgentStatus.thinking());
        var fresh = true;
        var note = '';
        // under a cap, an answer may write only what is left of it buys
        int? maxTokens;
        if (costCap != null) {
          final left = costCap - cost;
          final price = model.output * (model.longAbove > 0 ? model.longOutput : 1);
          final room = left <= 0 ? 0 : (left / price * 1e6).floor();
          if (room < model.maxOutput) maxTokens = room < minCappedOutput ? minCappedOutput : room;
        }
        final AiReply reply;
        try {
          reply = await api.send(
            AiRequest(
              model: model,
              system: system,
              history: [...past, ...kept],
              tools: defs,
              effort: requestEffort,
              taskBudget: taskBudget,
              compactAt: compactAt,
              maxTokens: maxTokens,
              longCache: longCache,
            ),
            cancel: cancel,
            listener: AiStreamListener(
              onText: (s) {
                // a paragraph between what the model wrote before and after tools
                final d = fresh && text.isNotEmpty ? '\n\n$s' : s;
                fresh = false;
                text.write(d);
                events.onText?.call(d);
              },
              onThinking: (s) {
                final n = _oneLine(s);
                if (n.isEmpty || n == note) return;
                note = n;
                events.onStatus?.call(AgentStatus.update(n));
              },
            ),
            onRetry: (wait, _, e) => events.onStatus?.call(AgentStatus.retry(wait, reason: e.kind)),
          );
        } on AiError catch (e) {
          // attempts that broke off were billed all the same
          spend(e.usage, model);
          if (e.refusedContent && accepted == 0 && extra.isNotEmpty && !effortDeclined && (e.message.contains('effort') || e.message.contains('output_config'))) {
            // the effort message was turned down: the effort goes as the request's own
            requestEffort = effortAfter(extra, requestEffort);
            kept.removeRange(1, kept.length);
            effortDeclined = true;
            continue;
          }
          if (e.refusedContent && kept.length > accepted) {
            if (accepted == 0) {
              // nothing ran: the question can be asked again
              kept.removeRange(accepted, kept.length);
              open = const [];
              results = [];
            } else if (!lightened && lighten()) {
              // a round of results too large, or with a picture the API refused: again without the pictures
              lightened = true;
              continue;
            } else {
              // the tools of the last round ran (the project may have changed): the round stays, lightened
              lighten();
              open = const [];
              results = [];
            }
          }
          return end(e.kind == AiErrorKind.cancelled ? AgentStop.cancelled : AgentStop.error, e);
        }
        accepted = kept.length;
        final rewritten = reply.history;
        if (rewritten != null && rewritten.length == past.length + kept.length) {
          final n = past.length;
          kept.setAll(0, rewritten.sublist(n));
          past = rewritten.sublist(0, n);
          rewrote = true;
        }
        usage += reply.usage;
        cost += reply.cost(model);
        events.onUsage?.call(usage, cost);
        prefixDrops += reply.prefixDrops;
        if (reply.model.isNotEmpty && !models.contains(reply.model)) {
          models.add(reply.model);
          if (!identical(AiModel.served(reply.model, model), model)) events.onModel?.call(reply.model);
        }
        // a declined answer is discarded, as is a tool call cut by the length limit
        if (reply.stop == AiStop.refusal) {
          return end(AgentStop.error, AiError(AiErrorKind.refusal, category: reply.category, message: reply.explanation, recommendedModel: reply.recommendedModel));
        }
        final uses = reply.calls;
        // the output limit the cap set ended the answer: the task stops at the cap
        final capped = maxTokens != null && reply.stop == AiStop.maxTokens;
        if (uses.isNotEmpty && reply.stop == AiStop.maxTokens) return capped ? end(AgentStop.budget) : end(AgentStop.error, AiError(AiErrorKind.truncated));
        if (uses.isNotEmpty && reply.stop == AiStop.contextWindow) return end(AgentStop.error, AiError(AiErrorKind.contextWindow));
        if (reply.items.isNotEmpty) {
          kept.addAll(reply.items);
          open = uses;
          results = [];
        }
        if (reply.compacted) {
          compactions++;
          events.onCompacted?.call();
        }
        // the context window is full: what the model wrote stays, the conversation cannot go on
        if (reply.stop == AiStop.contextWindow) return end(AgentStop.error, AiError(AiErrorKind.contextWindow));
        // the server paused a long turn of its own: the same conversation again, no new message
        if (reply.stop == AiStop.pause && uses.isEmpty) continue;
        if (uses.isEmpty || (reply.stop != AiStop.tool && reply.stop != AiStop.pause)) {
          return end(reply.stop == AiStop.maxTokens ? (capped ? AgentStop.budget : AgentStop.maxTokens) : AgentStop.done);
        }

        final round = <AgentToolCall>[];
        var lastChange = -1;
        var stop = false;
        var changed = false;
        final last = steps >= maxSteps;
        for (final u in uses) {
          final id = u.id;
          final name = u.name;
          if (stop || cancel.cancelled) {
            results.add(_error(id, 'Not run: the user stopped the assistant.'));
            continue;
          }
          if (last) {
            results.add(_error(id, 'Not run: the step limit of this request was reached. Tell the user what is left; they can ask you to continue.'));
            continue;
          }
          final tool = byName[name];
          if (tool == null) {
            results.add(_error(id, 'Unknown tool "$name".'));
            continue;
          }
          final raw = u.invalidRaw;
          final problem = raw != null ? null : schemaProblem(tool.inputSchema, u.input);
          // what the call reads of the screen (the selection) is fixed now: the card shows what runs
          var input = u.input;
          if (problem == null && raw == null) {
            try {
              input = tool.bind(u.input);
            } catch (_) {
              input = u.input;
            }
          }
          String summary;
          try {
            summary = problem == null && raw == null ? tool.describe(input) : name;
          } catch (_) {
            summary = name;
          }
          var effect = ToolEffect.read;
          try {
            effect = problem == null && raw == null ? tool.effectOf(input) : tool.effect;
          } catch (_) {
            effect = tool.effect;
          }
          final call = AgentToolCall(id: id, name: name, input: input, summary: summary, effect: effect);
          calls.add(call);
          round.add(call);
          void finish(ToolCallState s, String r) {
            call.state = s;
            call.result = r.split('\n').first;
            events.onCall?.call(call);
          }

          if (raw != null) {
            finish(ToolCallState.failed, 'INVALID_JSON');
            results.add(_error(id, jsonEncode({'INVALID_JSON': raw})));
            continue;
          }
          if (problem != null) {
            finish(ToolCallState.failed, problem);
            results.add(_error(id, problem));
            continue;
          }
          if (effect != ToolEffect.read) {
            final mode = permissionNow?.call() ?? permission;
            // a request to another service changes nothing: allowed in every
            // mode, with the user's approval unless changes apply automatically
            final lookup = effect == ToolEffect.network;
            if (mode == AgentPermission.readOnly && !lookup) {
              finish(ToolCallState.refused, 'read-only');
              results.add(
                _error(id, 'Refused: the user set the assistant to read-only, so it may not change the project or export files. Describe the change instead; the user can make it or allow changes.'),
              );
              continue;
            }
            if (mode == AgentPermission.plan && !lookup) {
              finish(ToolCallState.refused, 'plan');
              results.add(_error(id, 'Refused: plan mode. Explore with the read tools, then present your plan with present_plan; changes are allowed once the user approves it.'));
              continue;
            }
            var confirm = true;
            try {
              confirm = tool.mustConfirm(input);
            } catch (_) {
              // a call whose confirmation cannot be told is confirmed
            }
            if (mode != AgentPermission.auto || confirm) {
              call.state = ToolCallState.waiting;
              events.onCall?.call(call);
              events.onStatus?.call(AgentStatus.approval(name));
              final approve = events.approve;
              final a = approve == null ? Approval.skip : await Future.any([approve(call), stopped.future]);
              if (a == Approval.stop || cancel.cancelled) {
                stop = true;
                finish(ToolCallState.skipped, 'stopped');
                results.add(_error(id, 'Not run: the user stopped the assistant.'));
                continue;
              }
              if (a == Approval.skip) {
                finish(ToolCallState.skipped, 'skipped');
                results.add(_error(id, 'The user declined this change. Do not repeat it unless they ask; go on with the rest or explain the alternatives.'));
                continue;
              }
            }
          }
          call.state = ToolCallState.running;
          events.onCall?.call(call);
          events.onStatus?.call(AgentStatus.tool(name, note: note));
          try {
            final out = await tool.run(input);
            finish(out.isError ? ToolCallState.failed : ToolCallState.done, out.text);
            if (effect == ToolEffect.write && !out.isError) lastChange = results.length;
            results.add(AiToolResult(id, out.clip(maxResultChars)));
          } on ToolInputError catch (e) {
            finish(ToolCallState.failed, e.message);
            results.add(_error(id, e.message));
          } catch (e) {
            finish(ToolCallState.failed, '$e');
            results.add(_error(id, 'The tool failed: $e'));
          }
          if (effect != ToolEffect.read && call.state != ToolCallState.failed) {
            // kept as far as it went: should the page close now, the change is in the conversation
            changed = true;
            progress(changed: true);
          }
          if (cancel.cancelled) stop = true;
        }
        final going = !stop && !cancel.cancelled && !last;
        if (going && lastChange >= 0 && events.afterRound != null) {
          try {
            final picture = await events.afterRound!(round);
            if (picture != null) {
              final r = results[lastChange];
              results[lastChange] = AiToolResult(r.id, ToolOutput('${r.output.text}\n${picture.text}'.trim(), images: [...r.output.images, ...picture.images], isError: r.output.isError));
            }
          } catch (_) {
            // a picture that cannot be made is no reason to stop
          }
        }
        final notes = <String>[
          if (going && steps == maxSteps - 1) 'Step limit: the next answer is the last step of this request. Do not call more tools; tell the user what you did and what is left.',
          if (going && costCap != null && !warnedBudget && cost >= 0.8 * costCap)
            'Spending cap: about ${(100 * cost / costCap).round()} % of the cap for this task (US\$ ${costCap.toStringAsFixed(2)}) is spent. Finish the step you are on, then stop and tell the user what is done and what is left; they can raise the cap or ask you to continue.',
        ];
        if (notes.length > 1 || notes.any((n) => n.startsWith('Spending'))) warnedBudget = true;
        final steering = going ? (events.steer?.call() ?? const <AiPart>[]) : const <AiPart>[];
        roundAt = kept.length;
        roundResults = results;
        roundUser = [for (final p in steering) p is AiTextPart ? AiTextPart('$steeringPrefix${p.text}') : p];
        roundNote = notes.isEmpty ? null : notes.join('\n');
        kept.addAll(api.toolResults(roundResults, user: roundUser, note: roundNote));
        open = const [];
        results = [];
        progress(changed: changed);
        if (stop || cancel.cancelled) return end(AgentStop.cancelled);
        if (last) return end(AgentStop.stepLimit);
      }
    } catch (e) {
      // a failure of this program (a malformed answer, a callback that
      // threw) ends the turn as an error and keeps what is valid of it
      return end(AgentStop.error, AiError(AiErrorKind.unexpected, message: '${e.runtimeType}'));
    }
  }

  /// [s] on one line, at most 300 characters.
  static String _oneLine(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 300 ? t : '${t.substring(0, 299)}…';
  }
}
