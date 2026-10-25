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

  Future<ToolOutput> run(Map<String, dynamic> input);

  /// The tool as every provider describes it (the order of a conversation's
  /// tools stays fixed: it is part of the cached prefix).
  AiToolSpec get spec => AiToolSpec(name, description, inputSchema);
}

/// A tool made of closures.
class FnTool extends AgentTool {
  FnTool({required this.name, required this.description, required this.inputSchema, this.effect = ToolEffect.read, this.effectFor, this.summary, this.confirm, required this.handler});
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
  final Future<ToolOutput> Function(Map<String, dynamic> input) handler;

  @override
  ToolEffect effectOf(Map<String, dynamic> input) => effectFor?.call(input) ?? effect;
  @override
  String describe(Map<String, dynamic> input) => summary?.call(input) ?? name;
  @override
  bool mustConfirm(Map<String, dynamic> input) => effectOf(input) == ToolEffect.export || (confirm?.call(input) ?? false);
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
  AgentTurn({required this.messages, required this.text, required this.usage, required this.cost, required this.steps, required this.stop, required this.calls, this.error, this.compactions = 0});

  /// Entries to append to the conversation, in the provider's format: the
  /// question and everything the model and the tools added, ending in a
  /// valid state (every tool call answered). Empty when nothing came back,
  /// so the question can be asked again.
  final List<Map<String, dynamic>> messages;
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
  const AgentStatus.thinking() : kind = 'thinking', tool = '', wait = Duration.zero;
  const AgentStatus.tool(this.tool) : kind = 'tool', wait = Duration.zero;
  const AgentStatus.approval(this.tool) : kind = 'approval', wait = Duration.zero;
  const AgentStatus.retry(this.wait) : kind = 'retry', tool = '';
  final String kind;
  final String tool;
  final Duration wait;
}

class AgentEvents {
  const AgentEvents({this.onText, this.onCall, this.onStatus, this.approve, this.onUsage, this.steer, this.afterRound, this.onCompacted});
  final void Function(String delta)? onText;

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

  /// The tools in a fixed order (part of the cached prefix of every request
  /// of a conversation).
  List<AiToolSpec> get specs => [for (final t in tools) t.spec];

  static AiToolResult _error(String id, String text) => AiToolResult(id, ToolOutput.error(text));

  /// Runs one user message [user] (in the provider's format, see
  /// [AiClient.userMessage]) after [history]: at most [maxSteps] requests
  /// to the model, and no new request once [costCap] US$ are spent.
  /// [permissionNow], when given, is asked at every call (the user may
  /// approve a plan or change the mode while the turn runs).
  Future<AgentTurn> run({
    required AiModel model,
    AiEffort effort = AiEffort.medium,
    required String system,
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> user,
    AgentPermission permission = AgentPermission.ask,
    AgentPermission Function()? permissionNow,
    int maxSteps = 30,
    double? costCap,
    int? taskBudget,
    int? compactAt,
    required AiCancel cancel,
    AgentEvents events = const AgentEvents(),
  }) async {
    final defs = specs;
    final byName = {for (final t in tools) t.name: t};
    final kept = <Map<String, dynamic>>[user];
    final calls = <AgentToolCall>[];
    final text = StringBuffer();
    var usage = AiUsage.zero;
    var cost = 0.0;
    var steps = 0;
    var compactions = 0;
    var answered = false;
    var warnedBudget = false;
    final stopped = Completer<Approval>();
    cancel.onCancel(() {
      if (!stopped.isCompleted) stopped.complete(Approval.stop);
    });

    AgentTurn end(AgentStop stop, [AiError? e]) =>
        AgentTurn(messages: answered ? kept : const [], text: text.toString(), usage: usage, cost: cost, steps: steps, stop: stop, calls: calls, error: e, compactions: compactions);

    while (true) {
      if (cancel.cancelled) return end(AgentStop.cancelled);
      if (costCap != null && steps > 0 && cost >= costCap) return end(AgentStop.budget);
      steps++;
      events.onStatus?.call(const AgentStatus.thinking());
      var fresh = true;
      final AiReply reply;
      try {
        reply = await api.send(
          AiRequest(model: model, system: system, history: [...history, ...kept], tools: defs, effort: effort, taskBudget: taskBudget, compactAt: compactAt),
          cancel: cancel,
          listener: AiStreamListener(
            onText: (s) {
              // a paragraph between what the model wrote before and after tools
              final d = fresh && text.isNotEmpty ? '\n\n$s' : s;
              fresh = false;
              text.write(d);
              events.onText?.call(d);
            },
          ),
          onRetry: (wait, _) => events.onStatus?.call(AgentStatus.retry(wait)),
        );
      } on AiError catch (e) {
        return end(e.kind == AiErrorKind.cancelled ? AgentStop.cancelled : AgentStop.error, e);
      }
      usage += reply.usage;
      cost += reply.usage.cost(AiModel.served(reply.model, model));
      events.onUsage?.call(usage, cost);
      // a declined answer is discarded, as is a tool call cut by the length limit
      if (reply.stop == AiStop.refusal) return end(AgentStop.error, AiError(AiErrorKind.refusal, category: reply.category, message: reply.explanation));
      final uses = reply.calls;
      if (reply.stop == AiStop.maxTokens && uses.isNotEmpty) return end(AgentStop.error, AiError(AiErrorKind.truncated));
      if (reply.items.isNotEmpty) {
        kept.addAll(reply.items);
        answered = true;
      }
      if (reply.compacted) {
        compactions++;
        events.onCompacted?.call();
      }
      if (uses.isEmpty || reply.stop != AiStop.tool) return end(reply.stop == AiStop.maxTokens ? AgentStop.maxTokens : AgentStop.done);

      final results = <AiToolResult>[];
      final round = <AgentToolCall>[];
      var lastChange = -1;
      var stop = false;
      final last = steps >= maxSteps;
      for (final u in uses) {
        final id = u.id;
        final name = u.name;
        final input = u.input;
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
        final problem = raw != null ? null : schemaProblem(tool.inputSchema, input);
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
          if (mode != AgentPermission.auto || tool.mustConfirm(input)) {
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
        events.onStatus?.call(AgentStatus.tool(name));
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
        if (cancel.cancelled) stop = true;
      }
      final going = !stop && !cancel.cancelled && !last;
      if (going && lastChange >= 0 && events.afterRound != null) {
        try {
          final extra = await events.afterRound!(round);
          if (extra != null) {
            final r = results[lastChange];
            results[lastChange] = AiToolResult(r.id, ToolOutput('${r.output.text}\n${extra.text}'.trim(), images: [...r.output.images, ...extra.images], isError: r.output.isError));
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
      kept.addAll(api.toolResults(results, user: [for (final p in steering) p is AiTextPart ? AiTextPart('$steeringPrefix${p.text}') : p], note: notes.isEmpty ? null : notes.join('\n')));
      if (stop || cancel.cancelled) return end(AgentStop.cancelled);
      if (last) return end(AgentStop.stepLimit);
    }
  }
}
