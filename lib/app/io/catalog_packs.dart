/// Loads manufacturer catalogue packs (`*.oci.cat`): the ones bundled with
/// the app (repository folder `catalogs/`, declared as assets) and any pack
/// or pack index reachable by URL (a community repository, a manufacturer's
/// site, a raw file on GitHub).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/io/catalog_io.dart';
import '../../core/model/catalog_packs.dart';
import 'http.dart';

/// Asset folder of the bundled packs.
const bundledCatalogsPath = 'catalogs';

/// Reads a text resource: the asset bundle by default, overridable by tests.
Future<String> Function(String path) catalogAssetLoader = rootBundle.loadString;

/// Fetches a URL: the app's HTTP helper by default, overridable by tests.
Future<String> Function(String url) catalogUrlLoader = (url) => httpRequest('GET', url);

Future<List<CatalogPack>>? _bundled;

/// The packs shipped with the app (cached after the first call).
Future<List<CatalogPack>> loadBundledCatalogPacks({bool refresh = false}) {
  if (refresh) _bundled = null;
  return _bundled ??= _loadBundled().catchError((Object e) {
    _bundled = null;
    throw e;
  });
}

Future<List<CatalogPack>> _loadBundled() async {
  final index = CatalogIo.parseIndex(await catalogAssetLoader('$bundledCatalogsPath/index.json'));
  final out = <CatalogPack>[];
  for (final e in index) {
    final text = await catalogAssetLoader('$bundledCatalogsPath/${e.file}');
    out.add(CatalogPack.fromFile(CatalogIo.parsePack(text, fallbackId: e.meta.id)));
  }
  return out;
}

/// Loads the pack at [url], or every pack of the index at [url] (pack files
/// are resolved relative to the index).
Future<List<CatalogPack>> loadCatalogPacksFromUrl(String url) async {
  final u = url.trim();
  if (u.isEmpty) return const [];
  final text = await catalogUrlLoader(u);
  final j = jsonDecode(text.trim());
  if (j is Map<String, dynamic> && CatalogIo.isIndexJson(j)) {
    final base = Uri.parse(u);
    final out = <CatalogPack>[];
    for (final e in CatalogIo.parseIndex(text)) {
      final target = base.resolve(e.file).toString();
      out.add(CatalogPack.parse(await catalogUrlLoader(target), origin: target, fallbackId: e.meta.id));
    }
    return out;
  }
  return [CatalogPack.parse(text, origin: u)];
}
