/// Manufacturer catalogue packs.
///
/// A pack is an open JSON file (`*.oci.cat`, format documented in
/// `catalogs/README.md`) holding a [Catalog] subset plus metadata (brand,
/// description, source, licence). The packs shipped with the app live in the
/// repository folder `catalogs/` (bundled as Flutter assets and served with
/// the web app); any other pack can be loaded from a file or a URL, and a
/// community repository is just a folder with the packs and an `index.json`.
///
/// This file is pure Dart: the in-memory pack and the merge helper. Loading
/// from assets or the network is done by the app layer
/// (`lib/app/io/catalog_packs.dart`); parsing is in `core/io/catalog_io.dart`.
library;

import '../io/catalog_io.dart';
import 'catalog.dart';
import 'currency.dart';

/// A loaded pack: where it came from and its products.
class CatalogPack {
  const CatalogPack({required this.meta, required this.catalog, this.origin = ''});

  final CatalogPackMeta meta;
  final Catalog catalog;

  /// File name or URL the pack was read from (empty for bundled packs).
  final String origin;

  String get id => meta.id;

  /// Whether any product of the pack has a price.
  bool get hasPrices => catalogHasPrices(catalog);
  String get brand => meta.brand;
  String get description => meta.description;
  int get itemCount => catalog.itemCount;

  /// True when every item of the pack is already in [target].
  bool isMergedInto(Catalog target) =>
      catalog.pipes.every((p) => target.pipe(p.id) != null) &&
      catalog.outlets.every((o) => target.outlet(o.id) != null) &&
      catalog.tapes.every((x) => target.tape(x.id) != null) &&
      catalog.valves.every((v) => target.valve(v.id) != null) &&
      catalog.pumps.every((p) => target.pump(p.id) != null) &&
      catalog.fittings.every((f) => target.fitting(f.id) != null);

  static CatalogPack fromFile(CatalogPackFile f, {String origin = ''}) => CatalogPack(meta: f.meta, catalog: f.catalog, origin: origin);

  /// Parses a pack file text (see [CatalogIo.parsePack]).
  static CatalogPack parse(String text, {String origin = '', String? fallbackId}) =>
      fromFile(CatalogIo.parsePack(text, fallbackId: fallbackId ?? CatalogPackMeta.idFrom(origin.isEmpty ? 'pack' : origin.split('/').last)), origin: origin);
}

/// Adds the items of [pack] that [target] does not have yet (by id). Returns
/// the number of items added.
int mergeCatalogPack(Catalog target, Catalog pack) {
  var n = 0;
  bool has(String id) => target.pipe(id) != null || target.outlet(id) != null || target.tape(id) != null || target.valve(id) != null || target.pump(id) != null || target.fittings.any((f) => f.id == id);
  for (final p in pack.pipes) {
    if (has(p.id)) continue;
    target.pipes.add(p);
    n++;
  }
  for (final o in pack.outlets) {
    if (has(o.id)) continue;
    target.outlets.add(o);
    n++;
  }
  for (final t in pack.tapes) {
    if (has(t.id)) continue;
    target.tapes.add(t);
    n++;
  }
  for (final v in pack.valves) {
    if (has(v.id)) continue;
    target.valves.add(v);
    n++;
  }
  for (final p in pack.pumps) {
    if (has(p.id)) continue;
    target.pumps.add(p);
    n++;
  }
  for (final f in pack.fittings) {
    if (has(f.id)) continue;
    target.fittings.add(f);
    n++;
  }
  return n;
}

/// What [addCatalogPack] did.
class PackMergeResult {
  const PackMergeResult({required this.added, this.from = '', this.to = '', this.rate, this.unknownCurrency = false});

  /// Items added (those whose id the catalogue did not have yet).
  final int added;

  /// Currency of the pack prices and of the project.
  final String from;
  final String to;

  /// Exchange rate applied to the pack prices (null: none applied).
  final double? rate;

  /// The pack has prices but its currency (or the project's) is unknown or
  /// has no reference rate: the prices were added as they are.
  final bool unknownCurrency;

  bool get converted => rate != null && rate != 1;
}

/// Adds [pack] to [target] like [mergeCatalogPack], on a copy of its items
/// (the pack itself is never changed) whose prices are converted from the
/// pack currency ([CatalogPackMeta.currency]) to [projectCurrency] with the
/// reference rates.
PackMergeResult addCatalogPack(Catalog target, CatalogPack pack, {required String projectCurrency}) {
  final copy = Catalog.fromJson(pack.catalog.toJson());
  final from = pack.meta.currency;
  final to = projectCurrency.trim().toUpperCase();
  if (!catalogHasPrices(copy) || from == to) return PackMergeResult(added: mergeCatalogPack(target, copy), from: from, to: to);
  final rate = from.isEmpty || to.isEmpty ? null : exchangeRate(from, to);
  if (rate == null) return PackMergeResult(added: mergeCatalogPack(target, copy), from: from, to: to, unknownCurrency: true);
  scaleCatalogPrices(copy, rate);
  return PackMergeResult(added: mergeCatalogPack(target, copy), from: from, to: to, rate: rate);
}
