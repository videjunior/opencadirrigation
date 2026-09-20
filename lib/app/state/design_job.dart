/// Off-thread design job: the request/response messages exchanged between
/// the UI and a Web Worker (browser), an isolate (desktop) or the UI thread
/// itself (fallback), and the code that runs the job.
///
/// Messages are JSON-encodable maps with a `type`: `progress` (a
/// [DesignProgress]), `done` (a [DesignResponse]) or `error`.
library;

import '../../core/design/designer.dart';
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/model/project.dart';
import '../i18n.dart';

export '../../core/design/designer.dart' show DesignProgress, DesignStage;

/// What the worker needs: the project (without embedded images, which the
/// design never reads), the language for names in the results (with its
/// string table when the language is not compiled in, since the worker
/// cannot read assets) and the sizing switches.
class DesignRequest {
  DesignRequest({required this.project, required this.lang, this.strings, this.sizeZones = true, this.sizeMain = true});

  /// Builds the request for [project], leaving embedded images behind.
  factory DesignRequest.of(Project project, {required String lang, bool sizeZones = true, bool sizeMain = true}) {
    final j = project.toJson(includeEntities: false);
    j['entities'] = [for (final e in project.entities) if (!isDesignPassive(e)) e.toJson()];
    return DesignRequest(project: j, lang: lang, strings: languagePack(lang)?.strings, sizeZones: sizeZones, sizeMain: sizeMain);
  }

  final Map<String, dynamic> project;
  final String lang;

  /// Strings of [lang] when it comes from a language pack (null otherwise).
  final Map<String, String>? strings;
  final bool sizeZones;
  final bool sizeMain;

  Map<String, dynamic> toJson() => {
    'project': project,
    'lang': lang,
    if (strings != null) 'strings': strings,
    'sizeZones': sizeZones,
    'sizeMain': sizeMain,
  };

  static DesignRequest fromJson(Map<String, dynamic> j) => DesignRequest(
    project: j['project'] as Map<String, dynamic>,
    lang: j['lang'] as String? ?? 'en',
    strings: j['strings'] is Map ? {for (final e in (j['strings'] as Map).entries) '${e.key}': '${e.value}'} : null,
    sizeZones: j['sizeZones'] as bool? ?? true,
    sizeMain: j['sizeMain'] as bool? ?? true,
  );
}

/// Entities the design neither reads nor changes and that may carry large
/// payloads (embedded images): kept on the UI side.
bool isDesignPassive(Entity e) => e is ImageEntity;

/// What comes back: the results plus the project's entities after the run
/// (pipe sizes assigned, telescoped pipes split into pieces) and the id
/// counter the job reached.
class DesignResponse {
  DesignResponse({required this.results, required this.entities, required this.nextId});

  final DesignResults results;
  final List<Entity> entities;
  final int nextId;

  Map<String, dynamic> toJson() => {'results': results.toJson(), 'entities': entities.map((e) => e.toJson()).toList(), 'nextId': nextId};

  static DesignResponse fromJson(Map<String, dynamic> j) => DesignResponse(
    results: DesignResults.fromJson(j['results'] as Map<String, dynamic>),
    entities: ((j['entities'] as List?) ?? []).map((e) => Entity.fromJson(e as Map<String, dynamic>)).toList(),
    nextId: (j['nextId'] as num?)?.toInt() ?? 1,
  );
}

/// A design that failed inside the job (worker, isolate or thread).
class DesignJobException implements Exception {
  DesignJobException(this.message, [this.stack = '']);
  final String message;
  final String stack;

  @override
  String toString() => message;
}

Future<void> _noYield() => Future<void>.value();

/// Runs [request] and reports through [post]: `progress` messages, then one
/// `done` or `error` message. Never throws. [yieldControl] is awaited between
/// design steps (only needed when running on the UI thread).
Future<void> runDesignJob(Map<String, dynamic> request, void Function(Map<String, dynamic> message) post, {Future<void> Function()? yieldControl}) async {
  try {
    final req = DesignRequest.fromJson(request);
    final project = Project.fromJson(req.project);
    if (req.strings != null && !isLanguagePackInstalled(req.lang)) installLanguagePack(req.lang, LanguagePack(strings: req.strings!));
    final t = I18n(req.lang);
    final d = Designer(project, label: (k) => t(k));
    final r = await d.designAllAsync(
      sizeZones: req.sizeZones,
      sizeMain: req.sizeMain,
      onProgress: (p) => post({'type': 'progress', ...p.toJson()}),
      yieldControl: yieldControl ?? _noYield,
    );
    post({'type': 'done', ...DesignResponse(results: r, entities: project.entities, nextId: project.nextIdValue).toJson()});
  } catch (e, st) {
    post({'type': 'error', 'message': '$e', 'stack': '$st'});
  }
}

/// Puts the entities of a finished job into [project], keeping the passive
/// entities (images) that were not sent, at their former positions.
void applyDesignResponse(Project project, DesignResponse response) {
  final kept = <(int, Entity)>[for (var i = 0; i < project.entities.length; i++) if (isDesignPassive(project.entities[i])) (i, project.entities[i])];
  final merged = List<Entity>.of(response.entities);
  for (final (i, e) in kept) {
    merged.insert(i < merged.length ? i : merged.length, e);
  }
  project.entities
    ..clear()
    ..addAll(merged);
  project.ensureNextId(response.nextId);
}

/// Runs design jobs somewhere: a Web Worker, an isolate or the UI thread.
abstract class DesignRunner {
  /// Runs [request]; [onProgress] gets the progress messages, [onMode] is
  /// told where the job runs (`worker`, `isolate` or `thread`) before it
  /// starts, and [yieldControl] is awaited between steps when the job runs
  /// on the UI thread.
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl});

  /// Releases the worker, if any.
  void dispose() {}
}

/// Runs the job on the calling thread (yielding between steps so a UI can
/// repaint). The fallback when no worker is available.
class InThreadDesignRunner implements DesignRunner {
  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async {
    onMode?.call('thread');
    DesignResponse? response;
    Object? error;
    await runDesignJob(request.toJson(), (m) {
      switch (m['type']) {
        case 'progress':
          onProgress?.call(DesignProgress.fromJson(m));
        case 'done':
          response = DesignResponse.fromJson(m);
        case 'error':
          error = DesignJobException(m['message'] as String? ?? 'error', m['stack'] as String? ?? '');
      }
    }, yieldControl: yieldControl);
    if (error != null) throw error!;
    return response!;
  }

  @override
  void dispose() {}
}

/// Decodes one message from a worker or isolate and routes it.
void dispatchDesignMessage(Map<String, dynamic> m, {void Function(DesignProgress progress)? onProgress, required void Function(DesignResponse response) onDone, required void Function(DesignJobException error) onError}) {
  switch (m['type']) {
    case 'progress':
      onProgress?.call(DesignProgress.fromJson(m));
    case 'done':
      onDone(DesignResponse.fromJson(m));
    case 'error':
      onError(DesignJobException(m['message'] as String? ?? 'error', m['stack'] as String? ?? ''));
  }
}
