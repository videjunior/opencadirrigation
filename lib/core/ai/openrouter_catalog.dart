/// OpenRouter's list of models (`GET https://openrouter.ai/api/v1/models`,
/// public, no key) as the assistant offers it: each model that the
/// assistant can call through OpenRouter's Responses API becomes an
/// [AiModel] of [AiProvider.openrouter] with its list prices, and the
/// models the user picks are kept in the app's preferences and registered
/// again at start ([AiModel.register]).
///
/// What the list gives (openrouter.ai/docs/api/api-reference/models, read
/// on 2026-11-10): prices as strings in US$ per token (`prompt`,
/// `completion`, `input_cache_read`, `input_cache_write`; −1 for the
/// routers, which bill the model they pick), conditional `overrides` (a
/// long prompt priced higher above `min_prompt_tokens`; time windows),
/// `context_length`, the top provider's `max_completion_tokens`, input and
/// output modalities, `supported_parameters` (`tools`, `reasoning`…), the
/// reasoning efforts taken, and the API paths that serve the model
/// (`endpoints`).
///
/// Pure Dart: the download goes through a fetcher the app injects (the
/// same shape as its other JSON downloads), and the saved list through
/// `getPref`/`setPref`-style callbacks.
library;

import 'dart:async';
import 'dart:convert';

import 'llm.dart';

export 'llm.dart';

/// GET [url] with [headers], the body as text; throws when it cannot (the
/// app's fetcher turns an HTTP status into an [OpenRouterCatalogError]).
typedef CatalogFetch = Future<String> Function(Uri url, Map<String, String> headers);

/// Why the list could not be had.
enum CatalogFailure { network, timeout, status, format }

class OpenRouterCatalogError implements Exception {
  const OpenRouterCatalogError(this.failure, {this.status, this.message = ''});
  final CatalogFailure failure;

  /// The HTTP status of a [CatalogFailure.status].
  final int? status;
  final String message;

  @override
  String toString() => switch (failure) {
    CatalogFailure.network => 'OpenRouter could not be reached${message.isEmpty ? '' : ' ($message)'}',
    CatalogFailure.timeout => 'OpenRouter did not answer in time',
    CatalogFailure.status => 'OpenRouter answered ${status ?? '?'}${message.isEmpty ? '' : ' ($message)'}',
    CatalogFailure.format => 'OpenRouter sent a list this app cannot read${message.isEmpty ? '' : ' ($message)'}',
  };
}

/// One model of the list as the browser shows it.
class OpenRouterEntry {
  const OpenRouterEntry({required this.model, required this.name, required this.maker, this.context = 0, this.files = false, this.reasoning = false, this.created = 0});

  /// The model as the assistant uses it.
  final AiModel model;

  /// Its name without the maker ("Claude Opus 5.5"), and the maker
  /// ("Anthropic").
  final String name, maker;

  /// Context window in tokens (0: not given).
  final int context;

  /// Reads PDFs itself (`file` among its input modalities); for the others
  /// OpenRouter parses them.
  final bool files;

  /// Reasons before answering (takes `reasoning`).
  final bool reasoning;

  /// When OpenRouter listed it (seconds since 1970; 0: not given).
  final int created;

  String get id => model.id;
  bool get free => model.freeTier;

  /// A router: OpenRouter picks the model and bills its price.
  bool get router => !model.priced;

  /// US$ per million tokens of a typical step of the assistant, for
  /// sorting: three input tokens for each output token (the conversation
  /// is read again at every step); routers last.
  double get sortPrice => router ? double.infinity : (3 * model.input + model.output) / 4;
}

/// The list and where it came from.
class OpenRouterListing {
  const OpenRouterListing(this.entries, {this.copyOf, this.error});
  final List<OpenRouterEntry> entries;

  /// The download failed and this is the copy kept on that day.
  final DateTime? copyOf;

  /// Why the download failed (with a kept copy shown instead).
  final Object? error;
}

abstract final class OpenRouterCatalog {
  static final modelsUrl = Uri.parse('https://openrouter.ai/api/v1/models');

  /// The API path the assistant calls ([OpenRouterClient]).
  static const responsesPath = '/api/v1/responses';

  /// The key of the user's list in the app's preferences.
  static const prefKey = 'ai.openrouter.models';

  /// Most output tokens one answer is given, whatever the model allows (the
  /// app's largest anywhere; OpenRouter also holds the cost of
  /// `max_output_tokens` against a small balance while a request runs).
  static const maxOutputCap = 128000;

  /// Output tokens of a model whose list gives none.
  static const defaultOutput = 32000;

  /// The tier is a price band of the output price (US$ per million tokens),
  /// not a judgement of quality: from [topFrom] up top, from
  /// [intermediateFrom] up intermediate, below fast; free models are fast
  /// and routers intermediate. On the companies' own models of the app's
  /// table this gives their tier for all but Grok 4.7 (6, top there) and
  /// GPT-6.1 Terra (5, fast there).
  static const topFrom = 15.0, intermediateFrom = 4.0;

  static AiTier tierOf(double outputPerMillion, {bool router = false}) {
    if (router) return AiTier.intermediate;
    if (outputPerMillion >= topFrom) return AiTier.top;
    if (outputPerMillion >= intermediateFrom) return AiTier.intermediate;
    return AiTier.fast;
  }

  /// US$ per million tokens of a price in US$ per token (a string or a
  /// number), to a millionth of a dollar; null when missing or not a number.
  static double? perMillion(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
    if (d == null || !d.isFinite) return null;
    return (d * 1e12).round() / 1e6;
  }

  static List<String> _strings(Object? o) => [
    if (o is List)
      for (final x in o)
        if (x is String) x,
  ];

  static int _int(Object? o) => o is num ? o.toInt() : int.tryParse('${o ?? ''}') ?? 0;

  /// The model of one row of the list, or null when the assistant cannot
  /// use it here: not served by the Responses API, no text out, an alias
  /// (`~maker/family-latest`, a second row of a model listed on its own),
  /// or no price.
  static OpenRouterEntry? entryOf(Map<dynamic, dynamic> m) {
    final id = m['id'];
    if (id is! String || id.isEmpty || m['alias_target'] != null) return null;
    // the field is in every row; a row without it is taken as served
    if (m['endpoints'] is List && !_strings(m['endpoints']).contains(responsesPath)) return null;
    final arch = m['architecture'] is Map ? m['architecture'] as Map : const {};
    if (arch['output_modalities'] is List && !_strings(arch['output_modalities']).contains('text')) return null;
    final inputs = _strings(arch['input_modalities']);
    final p = m['pricing'] is Map ? m['pricing'] as Map : const {};
    final prompt = perMillion(p['prompt']), completion = perMillion(p['completion']);
    if (prompt == null || completion == null) return null;
    final router = prompt < 0 || completion < 0;
    final input = router ? 0.0 : prompt, output = router ? 0.0 : completion;
    final free = !router && input == 0 && output == 0;
    // a longer prompt billed higher: the first override that depends on
    // the prompt's length alone (the time-window ones are left out)
    var longAbove = 0;
    var longInput = 1.0, longOutput = 1.0;
    final overrides = p['overrides'];
    if (!router && overrides is List) {
      for (final o in overrides.whereType<Map>()) {
        final above = o['min_prompt_tokens'];
        if (above is! num || o.keys.any((k) => '$k'.startsWith('utc'))) continue;
        final op = perMillion(o['prompt']), oc = perMillion(o['completion']);
        longAbove = above.round();
        longInput = op != null && input > 0 ? op / input : 1;
        longOutput = oc != null && output > 0 ? oc / output : 1;
        break;
      }
    }
    final top = m['top_provider'] is Map ? m['top_provider'] as Map : const {};
    final context = _int(m['context_length']) > 0 ? _int(m['context_length']) : _int(top['context_length']);
    // what the top provider allows, at most [maxOutputCap] and half the
    // context (the conversation needs the rest)
    var maxOutput = _int(top['max_completion_tokens']);
    if (maxOutput <= 0) maxOutput = defaultOutput;
    if (maxOutput > maxOutputCap) maxOutput = maxOutputCap;
    if (context > 0 && maxOutput > context ~/ 2) maxOutput = context ~/ 2;
    final params = _strings(m['supported_parameters']);
    final r = m['reasoning'];
    final reasoning = r is Map || params.contains('reasoning');
    // the efforts it takes: those listed (null: any), none when it exposes
    // no effort setting
    final List<AiEffort> efforts;
    if (r is Map && r.containsKey('supported_efforts')) {
      final listed = r['supported_efforts'];
      efforts = listed == null
          ? AiEffort.values
          : [
              for (final e in AiEffort.values)
                if (_strings(listed).contains(e.name)) e,
            ];
    } else {
      efforts = const [];
    }
    final fullName = '${m['name'] ?? id}'.trim();
    final colon = fullName.indexOf(': ');
    final name = colon > 0 ? fullName.substring(colon + 2) : fullName;
    final author = id.contains('/') ? id.substring(0, id.indexOf('/')) : id;
    final maker = colon > 0 ? fullName.substring(0, colon) : (author == 'openrouter' ? 'OpenRouter' : author);
    final model = AiModel(
      AiProvider.openrouter,
      id,
      '$name (OpenRouter)',
      tierOf(output, router: router),
      input: input,
      output: output,
      cacheRead: perMillion(p['input_cache_read']) ?? input,
      cacheWrite: perMillion(p['input_cache_write']) ?? input,
      longAbove: longAbove,
      longInput: longInput,
      longOutput: longOutput,
      maxOutput: maxOutput,
      compaction: false,
      efforts: efforts,
      freeTier: free,
      vision: inputs.contains('image'),
      tools: params.contains('tools'),
      priced: !router,
    );
    return OpenRouterEntry(model: model, name: name, maker: maker, context: context, files: inputs.contains('file'), reasoning: reasoning, created: _int(m['created']));
  }

  /// The models of the list's JSON [text] that the assistant can use (the
  /// others left out, see [entryOf]); remembers which read PDFs themselves.
  static List<OpenRouterEntry> parse(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      throw const OpenRouterCatalogError(CatalogFailure.format, message: 'not JSON');
    }
    final data = j is Map ? j['data'] : null;
    if (data is! List) throw const OpenRouterCatalogError(CatalogFailure.format, message: 'no list of models');
    final out = <OpenRouterEntry>[];
    for (final row in data.whereType<Map>()) {
      final e = entryOf(row);
      if (e == null) continue;
      out.add(e);
      _files[e.id] = e.files;
    }
    return out;
  }

  /// The list's JSON, downloaded with [fetch] within [timeout].
  static Future<String> download(CatalogFetch fetch, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      // a plain GET: no header that would need a CORS preflight
      return await fetch(modelsUrl, const {}).timeout(timeout);
    } on TimeoutException {
      throw const OpenRouterCatalogError(CatalogFailure.timeout);
    } on OpenRouterCatalogError {
      rethrow;
    } catch (e) {
      throw OpenRouterCatalogError(CatalogFailure.network, message: '$e');
    }
  }

  /// The list, downloaded now and handed to [keep] (the app's data cache),
  /// or, when the download fails, the copy [kept] gives back (with its day)
  /// and the reason; the error itself when there is neither.
  static Future<OpenRouterListing> load(
    CatalogFetch fetch, {
    Future<(String, DateTime)?> Function()? kept,
    Future<void> Function(String body)? keep,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Object failure;
    try {
      final body = await download(fetch, timeout: timeout);
      final entries = parse(body);
      if (keep != null) {
        try {
          await keep(body);
        } catch (_) {
          // a full or blocked store keeps nothing: the list still serves
        }
      }
      return OpenRouterListing(entries);
    } on OpenRouterCatalogError catch (e) {
      failure = e;
    }
    (String, DateTime)? copy;
    try {
      copy = await kept?.call();
    } catch (_) {}
    if (copy == null) throw failure;
    try {
      return OpenRouterListing(parse(copy.$1), copyOf: copy.$2, error: failure);
    } on OpenRouterCatalogError {
      throw failure;
    }
  }

  // ---------------------------------------------------------------- what the client needs to know

  /// Model id → reads PDFs itself, for the models of the list seen in this
  /// session and those of the user's list.
  static final Map<String, bool> _files = {};

  /// The makers of the app's fixed OpenRouter models, which all read PDFs
  /// themselves (`file` among their input modalities in the list).
  static const _fileMakers = ['anthropic/', 'openai/', 'google/', 'x-ai/', 'meta/'];

  /// Whether [id] reads PDFs itself (else OpenRouter's parser reads them):
  /// as the list said, else by its maker; a free variant or the free
  /// router is taken not to.
  static bool readsFiles(String id) {
    final known = _files[id];
    if (known != null) return known;
    if (id == 'openrouter/free' || id.endsWith(':free')) return false;
    return id == 'openrouter/auto' || _fileMakers.any(id.startsWith);
  }

  // ---------------------------------------------------------------- the user's list

  /// The models the user added from the list, in the order they were.
  static List<AiModel> get added => [
    for (final m in AiModel.registered)
      if (m.provider == AiProvider.openrouter) m,
  ];

  /// One of the app's fixed models (already offered; nothing to add).
  static bool isFixed(String id) => AiModel.all.any((m) => m.id == id);

  static String _tier(AiTier t) => switch (t) {
    AiTier.top => 't',
    AiTier.intermediate => 'i',
    AiTier.fast => 'f',
  };

  /// [models] as a compact JSON text (version 1): per model its id, label,
  /// tier, the four prices, output limit, efforts, the long-prompt rule and
  /// what it can do.
  static String encode(Iterable<AiModel> models) => jsonEncode({
    'v': 1,
    'm': [
      for (final m in models)
        {
          'i': m.id,
          'l': m.label,
          't': _tier(m.tier),
          'p': [m.input, m.output, m.cacheRead, m.cacheWrite],
          'x': m.maxOutput,
          'e': [for (final e in m.efforts) e.name],
          if (m.longAbove > 0) 'L': [m.longAbove, m.longInput, m.longOutput],
          if (m.freeTier) 'f': 1,
          if (!m.vision) 'nv': 1,
          if (!m.tools) 'nt': 1,
          if (!m.priced) 'np': 1,
          if (readsFiles(m.id)) 'd': 1,
        },
    ],
  });

  /// The models of a text of [encode] (entries it cannot read left out; an
  /// empty list for a missing or broken text), with whether each reads PDFs.
  static List<(AiModel, bool)> _decode(String? text) {
    if (text == null || text.isEmpty) return const [];
    Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      return const [];
    }
    final rows = j is Map && j['m'] is List ? j['m'] as List : const [];
    double n(Object? o, [double d = 0]) => o is num && o.isFinite ? o.toDouble() : d;
    final out = <(AiModel, bool)>[];
    for (final r in rows.whereType<Map>()) {
      final id = r['i'];
      if (id is! String || id.isEmpty) continue;
      final p = r['p'] is List ? r['p'] as List : const [];
      final long = r['L'] is List ? r['L'] as List : const [];
      final names = _strings(r['e']);
      final m = AiModel(
        AiProvider.openrouter,
        id,
        r['l'] is String && (r['l'] as String).isNotEmpty ? r['l'] as String : id,
        switch (r['t']) {
          't' => AiTier.top,
          'f' => AiTier.fast,
          _ => AiTier.intermediate,
        },
        input: n(p.elementAtOrNull(0)),
        output: n(p.elementAtOrNull(1)),
        cacheRead: n(p.elementAtOrNull(2), n(p.elementAtOrNull(0))),
        cacheWrite: n(p.elementAtOrNull(3), n(p.elementAtOrNull(0))),
        longAbove: n(long.elementAtOrNull(0)).round(),
        longInput: n(long.elementAtOrNull(1), 1),
        longOutput: n(long.elementAtOrNull(2), 1),
        maxOutput: r['x'] is num && (r['x'] as num) > 0 ? (r['x'] as num).toInt() : defaultOutput,
        compaction: false,
        efforts: [
          for (final e in AiEffort.values)
            if (names.contains(e.name)) e,
        ],
        freeTier: r['f'] == 1,
        vision: r['nv'] != 1,
        tools: r['nt'] != 1,
        priced: r['np'] != 1,
      );
      out.add((m, r['d'] == 1));
    }
    return out;
  }

  /// The models of a text of [encode].
  static List<AiModel> decode(String? text) => [for (final (m, _) in _decode(text)) m];

  /// Registers the user's list kept under [prefKey] (at start) and returns
  /// it.
  static List<AiModel> restore(String? Function(String key) getPref) {
    final out = <AiModel>[];
    for (final (m, files) in _decode(getPref(prefKey))) {
      if (isFixed(m.id)) continue;
      _files[m.id] = files;
      AiModel.register(m);
      out.add(m);
    }
    return out;
  }

  /// Keeps the user's list ([added]) under [prefKey].
  static void save(void Function(String key, String value) setPref) => setPref(prefKey, encode(added));

  /// Adds [e] to the user's list (registered and kept) and returns the model
  /// to choose: the one added, or the app's own when [e] is one of the
  /// fixed models.
  static AiModel add(OpenRouterEntry e, void Function(String key, String value) setPref) {
    if (isFixed(e.id)) return AiModel.byId(e.id);
    _files[e.id] = e.files;
    AiModel.register(e.model);
    save(setPref);
    return AiModel.find(e.id) ?? e.model;
  }

  /// Takes the model [id] out of the user's list (and of the models
  /// offered).
  static void remove(String id, void Function(String key, String value) setPref) {
    AiModel.unregister(id);
    save(setPref);
  }
}
