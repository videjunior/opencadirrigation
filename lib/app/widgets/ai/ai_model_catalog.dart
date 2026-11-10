/// The browser of OpenRouter's models: the public list downloaded from
/// OpenRouter when the dialog opens (the last copy kept in the app's data
/// cache serves when it cannot be downloaded), searched by name or maker,
/// filtered (free only, reads pictures, calls tools — on at first, since the
/// assistant works through tools) and sorted by price or name. Choosing a
/// row adds the model to the user's list (kept in the preferences and
/// offered with OpenRouter's own models) and returns it; a model of the list
/// can be taken out again. The rows are built as they scroll into view: the
/// list has hundreds.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/ai/openrouter_catalog.dart';
import '../../io/data_cache_store.dart';
import '../../io/http.dart';
import '../../io/place_search.dart' show siteFetch;
import '../../io/prefs.dart';
import '../../state/controller.dart';
import '../../theme.dart';

/// The key of the downloaded list in the app's data cache.
final openRouterCacheKey = 'openrouter:${OpenRouterCatalog.modelsUrl}';

/// How the dialog downloads the list: the app's GET of JSON documents
/// ([siteFetch], which the tests replace), an HTTP status as such.
Future<String> openRouterFetch(Uri url, Map<String, String> headers) async {
  try {
    return await siteFetch(url, headers);
  } on HttpStatusException catch (e) {
    throw OpenRouterCatalogError(CatalogFailure.status, status: e.status, message: e.message);
  }
}

/// The copy of the list kept in the data cache, with its day.
Future<(String, DateTime)?> _kept() async {
  final cache = appDataCache();
  if (!cache.enabled) return null;
  final bytes = await cache.store.get(openRouterCacheKey);
  if (bytes == null) return null;
  final when = (await cache.store.entries()).where((e) => e.key == openRouterCacheKey).firstOrNull?.date ?? DateTime.now();
  return (utf8.decode(bytes, allowMalformed: true), when);
}

/// Keeps [body] in the data cache (when the user keeps downloads).
Future<void> _keep(String body) async {
  final cache = appDataCache();
  if (cache.enabled) await cache.store.put(openRouterCacheKey, Uint8List.fromList(utf8.encode(body)), DateTime.now());
}

/// Opens the browser; the model chosen (added to the user's list when it was
/// not one of the app's own), or null.
Future<AiModel?> showOpenRouterCatalog(BuildContext context, ProjectController c) => showDialog<AiModel>(
  context: context,
  builder: (_) => _Catalog(c: c),
);

class _Catalog extends StatefulWidget {
  const _Catalog({required this.c});
  final ProjectController c;

  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  final _search = TextEditingController();
  OpenRouterListing? _listing;
  Object? _error;
  bool _loading = true;
  bool _freeOnly = false, _vision = false, _tools = true, _byName = false;

  /// The note on the free models shown (at first: on a wide window).
  bool? _freeOpen;

  ProjectController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    OpenRouterListing? got;
    Object? error;
    try {
      got = await OpenRouterCatalog.load(openRouterFetch, kept: _kept, keep: _keep);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _listing = got ?? _listing;
      _error = error;
    });
  }

  List<OpenRouterEntry> get _shown {
    final q = _search.text.trim().toLowerCase();
    final out = [
      for (final e in _listing?.entries ?? const <OpenRouterEntry>[])
        if ((q.isEmpty || e.name.toLowerCase().contains(q) || e.maker.toLowerCase().contains(q) || e.id.toLowerCase().contains(q)) &&
            (!_freeOnly || e.free) &&
            (!_vision || e.model.vision) &&
            (!_tools || e.model.tools))
          e,
    ];
    int byName(OpenRouterEntry a, OpenRouterEntry b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    out.sort(_byName ? byName : (a, b) => a.sortPrice != b.sortPrice ? a.sortPrice.compareTo(b.sortPrice) : byName(a, b));
    return out;
  }

  static String _tokens(int n) {
    if (n >= 1000000) {
      final m = n / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    return n >= 1000 ? '${(n / 1000).round()}K' : '$n';
  }

  static String _day(DateTime d) {
    String two(int v) => '$v'.padLeft(2, '0');
    final l = d.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  void _choose(OpenRouterEntry e) {
    final m = OpenRouterCatalog.add(e, setPref);
    Navigator.of(context).pop(m);
  }

  void _remove(OpenRouterEntry e) {
    OpenRouterCatalog.remove(e.id, setPref);
    setState(() {});
  }

  Widget _row(OpenRouterEntry e, int k) {
    final t = c.t;
    final m = e.model;
    final fixed = OpenRouterCatalog.isFixed(e.id);
    final added = !fixed && AiModel.registered.any((x) => x.id == e.id);
    final price = e.router
        ? t('aor.router')
        : e.free
        ? t('aor.free')
        : t('aor.price', {'p': m.priceText});
    final facts = [
      e.maker,
      price,
      if (e.context > 0) t('aor.context', {'n': _tokens(e.context)}),
      if (fixed) t('aor.fixed') else if (added) t('aor.inList'),
    ];
    Widget badge(IconData icon, String tip, bool on) => Tooltip(
      message: tip,
      child: Icon(icon, size: 15, color: on ? Cad.accentIcon : Cad.fg24),
    );
    return ListTile(
      key: Key('aor_row_$k'),
      dense: true,
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 0),
      selected: fixed || added,
      title: Text(
        e.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(facts.join(' · '), style: TextStyle(fontSize: 11, color: Cad.fg60)),
      onTap: () => _choose(e),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge(Icons.image_outlined, t(m.vision ? 'aor.vision' : 'ai.model.noVision'), m.vision),
          const SizedBox(width: 4),
          badge(Icons.handyman_outlined, t(m.tools ? 'aor.tools' : 'aor.noTools'), m.tools),
          if (added)
            IconButton(key: Key('aor_remove_$k'), tooltip: t('aor.remove'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: () => _remove(e))
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final size = MediaQuery.sizeOf(context);
    _freeOpen ??= size.width >= 640;
    final width = math.min(size.width - 56, 600.0);
    final listing = _listing;
    final shown = _shown;
    final note = TextStyle(fontSize: 11, color: Cad.fg60);
    Widget chip(String key, String label, bool on, void Function(bool) set) => FilterChip(
      key: Key(key),
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: on,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (v) => setState(() => set(v)),
    );
    Widget sort(String key, String label, bool name) => ChoiceChip(
      key: Key(key),
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: _byName == name,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => setState(() => _byName = name),
    );
    // the filters, the count and what the user should know before choosing:
    // the first item of the list, scrolled away with the rows (a phone with
    // its keyboard up keeps the search and a few rows)
    Widget head(OpenRouterListing listing) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              chip('aor_free', t('aor.freeOnly'), _freeOnly, (v) => _freeOnly = v),
              chip('aor_vision', t('aor.vision'), _vision, (v) => _vision = v),
              chip('aor_tools', t('aor.tools'), _tools, (v) => _tools = v),
              sort('aor_by_price', t('aor.byPrice'), false),
              sort('aor_by_name', t('aor.byName'), true),
            ],
          ),
          const SizedBox(height: 6),
          if (listing.copyOf != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t('aor.offline', {'e': '${listing.error}', 'd': _day(listing.copyOf!)}),
                key: const Key('aor_offline'),
                style: TextStyle(fontSize: 11, color: Cad.warning),
              ),
            ),
          Text(t('aor.noTools'), style: note),
          InkWell(
            key: const Key('aor_free_more'),
            onTap: () => setState(() => _freeOpen = !(_freeOpen ?? false)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(_freeOpen ?? false ? Icons.expand_less : Icons.expand_more, size: 16, color: Cad.fg60),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(t('aor.freeMore'), style: note.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          if (_freeOpen ?? false) Text(t('aor.freeNote'), key: const Key('aor_free_note'), style: note),
          const SizedBox(height: 2),
          Text(t('aor.source'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(t('aor.count', {'n': '${shown.length}'}), key: const Key('aor_count'), style: note),
              ),
              if (_loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(t('aor.none'), key: const Key('aor_none'), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
    final Widget body;
    if (listing == null && _loading) {
      body = Column(
        key: const Key('aor_loading'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(t('aor.loading'), style: note),
        ],
      );
    } else if (listing == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('aor.failed', {'e': '$_error'}),
            key: const Key('aor_failed'),
            style: TextStyle(fontSize: 12, color: Cad.error),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(key: const Key('aor_retry'), onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: Text(t('ai.retry'))),
        ],
      );
    } else {
      // as tall as the window lets it be, up to 520 px; the rows are built as
      // they scroll into view
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Scrollbar(
          child: ListView.builder(key: const Key('aor_list'), itemCount: shown.length + 1, itemBuilder: (context, i) => i == 0 ? head(listing) : _row(shown[i - 1], i - 1)),
        ),
      );
    }
    return AlertDialog(
      key: const Key('aor_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Text(t('aor.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('aor_search'),
              controller: _search,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: t('aor.search')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Flexible(child: body),
          ],
        ),
      ),
      actions: [TextButton(key: const Key('aor_close'), onPressed: () => Navigator.of(context).pop(), child: Text(t('close')))],
    );
  }
}
