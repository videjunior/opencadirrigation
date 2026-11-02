/// Catalog import/export: JSON (full catalog format) and CSV per group
/// (manufacturer price lists). Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../hydraulics/emitter.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/water_hammer.dart';
import '../model/catalog.dart';
import '../units.dart';
import 'xlsx.dart';

enum CatalogGroup { pipes, outlets, tapes, valves, pumps, fittings, wires }

class CatalogImportResult {
  CatalogImportResult(this.catalog, this.count, {this.group, Set<String>? generatedIds, List<int>? skippedRows, this.pnAsBar = 0}) : generatedIds = generatedIds ?? {}, skippedRows = skippedRows ?? [];
  final Catalog catalog;
  final int count;
  final CatalogGroup? group;

  /// Ids made up for rows without an `id` column (from the supplier, code
  /// and name): such an item replaces only the same item of an earlier
  /// import, never another one ([mergeInto]).
  final Set<String> generatedIds;

  /// Table lines (1 = the first after the header) that were left out: a
  /// pipe without any diameter, a pump without a curve, a wire without a
  /// section.
  final List<int> skippedRows;

  /// Rows whose `pn` had no unit and was read in bar because it is at most
  /// 25 (PN 10 = 10 bar); the app asks before taking it so
  /// ([CatalogIo.parse] with `pnInBar`).
  final int pnAsBar;

  /// Merges the items into [target]: an id given by the file replaces the
  /// item of that id; a made-up id ([generatedIds]) replaces only an item
  /// of the same name (the same row imported again, with a new price),
  /// another item keeps its id and the new one gets a free id. [used] are
  /// the catalogue ids the drawing uses: replacing one of them is reported.
  CatalogMergeReport mergeInto(Catalog target, {Set<String> used = const {}}) {
    var added = 0, replaced = 0;
    final inUse = <String>[];
    void go<T>(List<T> mine, List<T> theirs, String Function(T) idOf, String Function(T) nameOf, T Function(T, String) withId) {
      for (var t in theirs) {
        final i = mine.indexWhere((m) => idOf(m) == idOf(t));
        if (i < 0) {
          mine.add(t);
          added++;
          continue;
        }
        if (generatedIds.contains(idOf(t)) && nameOf(mine[i]) != nameOf(t)) {
          t = withId(t, target.newId('${idOf(t)}_'));
          mine.add(t);
          added++;
          continue;
        }
        if (used.contains(idOf(t))) inUse.add(idOf(t));
        mine[i] = t;
        replaced++;
      }
    }

    T copy<T>(T item, String id, T Function(Map<String, dynamic>) read, Map<String, dynamic> Function(T) write) => read(write(item)..['id'] = id);
    go<PipeSpec>(target.pipes, catalog.pipes, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, PipeSpec.fromJson, (x) => x.toJson()));
    go<OutletSpec>(target.outlets, catalog.outlets, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, OutletSpec.fromJson, (x) => x.toJson()));
    go<TapeSpec>(target.tapes, catalog.tapes, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, TapeSpec.fromJson, (x) => x.toJson()));
    go<ValveSpec>(target.valves, catalog.valves, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, ValveSpec.fromJson, (x) => x.toJson()));
    go<PumpSpec>(target.pumps, catalog.pumps, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, PumpSpec.fromJson, (x) => x.toJson()));
    go<FittingSpec>(target.fittings, catalog.fittings, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, FittingSpec.fromJson, (x) => x.toJson()));
    go<WireSpec>(target.wires, catalog.wires, (x) => x.id, (x) => x.name, (x, id) => copy(x, id, WireSpec.fromJson, (x) => x.toJson()));
    target.finame.addAll(catalog.finame);
    return CatalogMergeReport(added: added, replaced: replaced, replacedInUse: inUse);
  }
}

/// What [CatalogImportResult.mergeInto] did.
class CatalogMergeReport {
  const CatalogMergeReport({required this.added, required this.replaced, this.replacedInUse = const []});
  final int added, replaced;

  /// Ids of replaced items that entities of the drawing use (their
  /// diameters, curves or prices may have changed).
  final List<String> replacedInUse;
  int get total => added + replaced;
}

/// Head loss law of a valve or device from its flow coefficient [kv] (m³/h
/// of water through it with a loss of 1 bar, IEC 60534): Δp [bar] =
/// (Q [m³/h] / Kv)², so h [m] = 3600²·Q²/(Kv²·0.0980665) with Q in m³/s.
DeviceLossCurve kvLossCurve(double kv) => DeviceLossCurve(k: 3600 * 3600 / (kv * kv * barPerMeterHead), n: 2);

/// A pressure written in a table cell, in metres of water: with its unit
/// (`10 bar`, `150 psi`, `1 MPa`, `600 kPa`, `6 kgf/cm²`, `80 m`, `80 mca`);
/// without one, [noUnit] tells what the number is. Null when there is none.
double? pressureCellM(String cell, {required double Function(double v) noUnit}) {
  final v = parseNumber(cell, lenient: true);
  if (v == null) return null;
  final l = cell.toLowerCase();
  if (l.contains('mpa')) return v * 1000 / kPaPerMeterHead;
  if (l.contains('kpa')) return v / kPaPerMeterHead;
  if (l.contains('bar')) return v / barPerMeterHead;
  if (l.contains('psi')) return v / psiPerMeterHead;
  if (l.contains('kgf') || l.contains('kg/cm')) return v * 98.0665 / kPaPerMeterHead;
  if (RegExp(r'\d\s*(m|mca|m\.c\.a\.?|mh2o)\s*$').hasMatch(l)) return v;
  return noUnit(v);
}

/// Stable id of a table row without an id: [prefix] and a hash of its
/// supplier, code and name (the same row imported again gets the same id).
String rowId(String prefix, String supplier, String code, String name) {
  var h = 7;
  for (final u in utf8.encode('${supplier.trim().toLowerCase()}|${code.trim().toLowerCase()}|${name.trim().toLowerCase()}')) {
    h = (h * 131 + u) % 4294967291;
  }
  return '${prefix}_${h.toRadixString(36)}';
}

/// File extension of a manufacturer catalogue pack (JSON inside; see
/// `catalogs/README.md` for the format).
const catalogPackExtension = '.oci.cat';

/// `format` value of a catalogue pack file.
const catalogPackFormat = 'opencadirrigation-catalog';

/// `format` value of a catalogue index (`index.json` listing packs).
const catalogIndexFormat = 'opencadirrigation-catalog-index';

/// Version of the pack / index file formats written by this build.
const catalogPackVersion = 1;

/// Metadata of a catalogue pack: who made the products, who wrote the file.
class CatalogPackMeta {
  const CatalogPackMeta({
    required this.id,
    required this.brand,
    this.name = '',
    this.description = '',
    this.source = '',
    this.license = '',
    this.updated = '',
    this.author = '',
    this.currency = '',
    this.sources = const [],
  });

  /// Stable identifier (lowercase, `[a-z0-9_-]`), also the file name.
  final String id;
  final String brand;
  final String name;
  final String description;

  /// Where the data came from (data sheet or catalogue URL).
  final String source;
  final String license;

  /// Date of the data (`YYYY-MM-DD`).
  final String updated;
  final String author;

  /// ISO 4217 code of the prices in the pack (empty: unknown, or no prices).
  final String currency;

  /// The documents the data were taken from (data sheets, catalogues, URLs).
  final List<String> sources;

  String get title => name.isEmpty ? brand : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    if (name.isNotEmpty) 'name': name,
    if (description.isNotEmpty) 'description': description,
    if (source.isNotEmpty) 'source': source,
    if (license.isNotEmpty) 'license': license,
    if (updated.isNotEmpty) 'updated': updated,
    if (author.isNotEmpty) 'author': author,
    if (currency.isNotEmpty) 'currency': currency,
    if (sources.isNotEmpty) 'sources': sources,
  };

  static CatalogPackMeta fromJson(Map<String, dynamic> j, {String fallbackId = 'pack'}) {
    final id = (j['id'] as String?)?.trim();
    final brand = (j['brand'] as String?)?.trim();
    return CatalogPackMeta(
      id: id == null || id.isEmpty ? fallbackId : id,
      brand: brand == null || brand.isEmpty ? (j['name'] as String? ?? fallbackId) : brand,
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      source: j['source'] as String? ?? '',
      license: j['license'] as String? ?? '',
      updated: j['updated'] as String? ?? '',
      author: j['author'] as String? ?? '',
      currency: (j['currency'] as String? ?? '').trim().toUpperCase(),
      sources: [
        for (final x in (j['sources'] as List?) ?? const [])
          if (x is String && x.trim().isNotEmpty) x.trim(),
      ],
    );
  }

  /// A safe id derived from a file name or free text (`Rain Bird 5000.oci.cat`
  /// → `rain_bird_5000`).
  static String idFrom(String text) {
    var t = text.trim().toLowerCase();
    for (final ext in [catalogPackExtension, '.json', '.cat']) {
      if (t.endsWith(ext)) t = t.substring(0, t.length - ext.length);
    }
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return t.isEmpty ? 'pack' : t;
  }
}

/// A parsed catalogue pack: its metadata and the products.
class CatalogPackFile {
  const CatalogPackFile(this.meta, this.catalog);
  final CatalogPackMeta meta;
  final Catalog catalog;
  int get itemCount => catalog.itemCount;
}

/// One row of a catalogue index: where a pack is and what it holds.
class CatalogIndexEntry {
  const CatalogIndexEntry({required this.meta, required this.file, this.items = 0});
  final CatalogPackMeta meta;

  /// File name (or URL) of the pack, relative to the index.
  final String file;
  final int items;

  // the index stays short: the document list lives in the pack only
  Map<String, dynamic> toJson() => {...meta.toJson()..remove('sources'), 'file': file, 'items': items};
  static CatalogIndexEntry fromJson(Map<String, dynamic> j) => CatalogIndexEntry(
    meta: CatalogPackMeta.fromJson(j, fallbackId: CatalogPackMeta.idFrom(j['file'] as String? ?? 'pack')),
    file: j['file'] as String? ?? '',
    items: (j['items'] as num?)?.toInt() ?? 0,
  );
}

class CatalogIo {
  static String exportJson(Catalog c) => const JsonEncoder.withIndent('  ').convert(c.toJson());

  // ---------------------------------------------------------------- packs

  /// Serialises a catalogue pack (`*.oci.cat`).
  static String encodePack(CatalogPackMeta meta, Catalog c) => const JsonEncoder.withIndent('  ').convert(packJson(meta, c));

  static Map<String, dynamic> packJson(CatalogPackMeta meta, Catalog c) => {'format': catalogPackFormat, 'version': catalogPackVersion, ...meta.toJson(), 'items': c.itemCount, 'catalog': c.toJson()};

  /// Whether [j] is a pack file (as opposed to a bare catalogue or an index).
  static bool isPackJson(Map<String, dynamic> j) => j['format'] == catalogPackFormat || (j['catalog'] is Map && j.containsKey('brand'));

  /// Parses a pack file. A bare catalogue (the JSON exported by the catalogue
  /// editor) is accepted too, with [fallbackId] as id and brand.
  static CatalogPackFile parsePack(String text, {String fallbackId = 'pack'}) {
    final j = jsonDecode(text.trim());
    if (j is! Map<String, dynamic>) throw const FormatException('catalog_json_unknown');
    if (j['format'] == catalogIndexFormat) throw const FormatException('catalog_index_not_pack');
    if (j['format'] == catalogPackFormat || j['catalog'] is Map<String, dynamic>) {
      final v = (j['version'] as num?)?.toInt() ?? 1;
      if (v > catalogPackVersion) throw const FormatException('catalog_pack_version');
      final cat = Catalog.fromJson(j['catalog'] as Map<String, dynamic>);
      return CatalogPackFile(CatalogPackMeta.fromJson(j, fallbackId: fallbackId), cat);
    }
    if (j.containsKey('pipes') || j.containsKey('fittings') || j.containsKey('outlets') || j.containsKey('tapes') || j.containsKey('valves') || j.containsKey('pumps') || j.containsKey('wires')) {
      return CatalogPackFile(CatalogPackMeta(id: fallbackId, brand: fallbackId), Catalog.fromJson(j));
    }
    throw const FormatException('catalog_json_unknown');
  }

  /// Serialises an index of packs (`index.json`).
  static String encodeIndex(List<CatalogIndexEntry> packs) =>
      const JsonEncoder.withIndent('  ').convert({'format': catalogIndexFormat, 'version': catalogPackVersion, 'packs': packs.map((p) => p.toJson()).toList()});

  static bool isIndexJson(Map<String, dynamic> j) => j['format'] == catalogIndexFormat || j['packs'] is List;

  static List<CatalogIndexEntry> parseIndex(String text) {
    final j = jsonDecode(text.trim());
    if (j is! Map<String, dynamic> || !isIndexJson(j)) throw const FormatException('catalog_index_unknown');
    return ((j['packs'] as List?) ?? const []).map((e) => CatalogIndexEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Parses JSON (catalog format or a single group list) or CSV. For CSV the
  /// group is detected from the header columns unless [group] is given.
  ///
  /// [pnInBar] tells how a `pn` column without units is read: in bar
  /// (true), in metres (false) or, when null, in bar up to 25 (the ISO
  /// classes) and in metres above (the PN 40 / 60 / 80 of metres of head);
  /// [CatalogImportResult.pnAsBar] counts the rows the automatic rule read
  /// in bar.
  static CatalogImportResult parse(String text, {CatalogGroup? group, bool? pnInBar}) {
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final j = jsonDecode(trimmed);
      if (j is Map<String, dynamic>) {
        if (j.containsKey('pipes') || j.containsKey('fittings') || j.containsKey('outlets') || j.containsKey('wires')) {
          final c = Catalog.fromJson(j);
          return CatalogImportResult(c, c.itemCount);
        }
        if (j['catalog'] is Map<String, dynamic>) {
          final c = Catalog.fromJson(j['catalog'] as Map<String, dynamic>);
          return CatalogImportResult(c, c.itemCount);
        }
      }
      if (j is List && group != null) {
        final c = Catalog();
        for (final e in j.cast<Map<String, dynamic>>()) {
          _addJson(c, group, e);
        }
        return CatalogImportResult(c, c.itemCount, group: group);
      }
      throw const FormatException('catalog_json_unknown');
    }
    return parseCsv(text, group: group, pnInBar: pnInBar);
  }

  static void _addJson(Catalog c, CatalogGroup g, Map<String, dynamic> e) {
    switch (g) {
      case CatalogGroup.pipes:
        c.pipes.add(PipeSpec.fromJson(e));
      case CatalogGroup.outlets:
        c.outlets.add(OutletSpec.fromJson(e));
      case CatalogGroup.tapes:
        c.tapes.add(TapeSpec.fromJson(e));
      case CatalogGroup.valves:
        c.valves.add(ValveSpec.fromJson(e));
      case CatalogGroup.pumps:
        c.pumps.add(PumpSpec.fromJson(e));
      case CatalogGroup.fittings:
        c.fittings.add(FittingSpec.fromJson(e));
      case CatalogGroup.wires:
        c.wires.add(WireSpec.fromJson(e));
    }
  }

  /// The fields of a table line (RFC 4180): a quote delimits a field only
  /// when it opens it (`"a; b"`, two quotes inside one are a quote); anywhere else it is a
  /// character of the field, as the inch mark of `Tubo PVC 2"` or `3/4"`.
  static List<String> splitLine(String line, String sep) {
    final out = <String>[];
    var i = 0;
    while (true) {
      final cur = StringBuffer();
      var j = i;
      while (j < line.length && (line[j] == ' ' || line[j] == '\t') && line[j] != sep) {
        j++;
      }
      if (j < line.length && line[j] == '"') {
        // quoted field: up to the closing quote ("" is a quote)
        j++;
        while (j < line.length) {
          if (line[j] == '"') {
            if (j + 1 < line.length && line[j + 1] == '"') {
              cur.write('"');
              j += 2;
              continue;
            }
            j++;
            break;
          }
          cur.write(line[j++]);
        }
        // anything between the closing quote and the separator
        while (j < line.length && line[j] != sep) {
          cur.write(line[j++]);
        }
      } else {
        j = i;
        while (j < line.length && line[j] != sep) {
          cur.write(line[j++]);
        }
      }
      out.add(cur.toString().trim());
      if (j >= line.length) break;
      i = j + 1;
    }
    return out;
  }

  /// Pump curve points written as "Q@H" pairs (m³/h @ m), separated by
  /// ";", "|", ", " or spaces ("10@30,20@25" also works), the numbers with
  /// a decimal point or comma. Pairs that do not parse are skipped.
  static List<(double, double)> parseCurvePoints(String text) {
    final out = <(double, double)>[];
    for (final tok in text.split(RegExp(r'[;|]|,\s+|\s+'))) {
      final chunks = '@'.allMatches(tok).length > 1 ? tok.split(',') : [tok];
      for (final c in chunks) {
        final parts = c.split('@');
        if (parts.length != 2) continue;
        final q = parseNumber(parts[0]), h = parseNumber(parts[1]);
        if (q != null && h != null) out.add((q, h));
      }
    }
    return out;
  }

  static CatalogImportResult parseCsv(String text, {CatalogGroup? group, bool? pnInBar}) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) throw const FormatException('catalog_csv_empty');
    final first = lines.first.replaceFirst('﻿', '');
    final sep = first.contains(';') ? ';' : (first.contains('\t') ? '\t' : ',');
    final header = splitLine(first, sep).map((h) => h.toLowerCase().replaceAll(' ', '')).toList();
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final g = group ?? _detectGroup(header);
    if (g == null) throw const FormatException('catalog_csv_columns');
    final c = Catalog();
    final idC = col(['id']), nameC = col(['name', 'nome', 'nombre', 'description', 'descricao']);
    final costC = col(['cost', 'custo', 'costo', 'price', 'preco']);
    final supC = col(['supplier', 'fornecedor', 'proveedor']), codeC = col(['code', 'codigo', 'sku']), finameC = col(['finame', 'bndes']);
    // 1.6.0 UI (UI-08): the decimal separator of the table, from the plain numbers that tell ("12,5", "1.234,5"):
    // in a table of decimal commas a "1.250" is then 1250, not 1.25
    final decimal = guessDecimalSeparator([
      for (final l in lines.skip(1).take(1000))
        for (final cell in splitLine(l, sep))
          if (RegExp(r'^[^A-Za-z]*\d[^A-Za-z]*$').hasMatch(cell)) cell,
    ]);
    // "1.234,56", "R$ 12,50", "35 m"…
    double num(List<String> r, int i, [double def = 0]) => i >= 0 && i < r.length ? (parseNumber(r[i], lenient: true, decimalSeparator: decimal) ?? def) : def;
    String str(List<String> r, int i, [String def = '']) => i >= 0 && i < r.length ? r[i] : def;
    // emitters along a tape: a spacing of 0 is a missing value
    double tapeSpacing(double v) => v > 0 ? v : 0.5;
    // pump type: "submersible", "submersa", "sumergible", "sub"…
    bool isSubmersible(String v) => RegExp(r'^\s*(sub|sum)', caseSensitive: false).hasMatch(v);
    // the pressure class: `ratingM` in metres (as exported), `pn` in bar up
    // to 25 without a unit (see [parse]), `rating` in metres; a unit in the
    // cell wins
    var pnAsBar = 0;
    double rating(List<String> r, double def) {
      final m = col(['ratingm']), pn = col(['pn']), any = col(['rating']);
      if (m >= 0 && str(r, m).isNotEmpty) return pressureCellM(str(r, m), noUnit: (v) => v) ?? def;
      if (pn >= 0 && str(r, pn).isNotEmpty) {
        return pressureCellM(
              str(r, pn),
              noUnit: (v) {
                final bar = pnInBar ?? v <= 25;
                if (bar && pnInBar == null) pnAsBar++;
                return bar ? v / barPerMeterHead : v;
              },
            ) ??
            def;
      }
      if (any >= 0 && str(r, any).isNotEmpty) return pressureCellM(str(r, any), noUnit: (v) => v) ?? def;
      return def;
    }

    final generated = <String>{};
    final skipped = <int>[];
    var n = 0;
    for (var li = 1; li < lines.length; li++) {
      final r = splitLine(lines[li], sep);
      if (r.every((x) => x.isEmpty)) continue;
      final name = str(r, nameC, 'item $li');
      final cost = num(r, costC);
      final sup = str(r, supC), code = str(r, codeC);
      var id = str(r, idC);
      if (id.isEmpty) {
        // no id column: one made from the row, the same on every import of
        // the same list (several rows of one emitter are its nozzles)
        id = rowId(g.name.substring(0, 2), sup, code, name);
        if (g != CatalogGroup.outlets) {
          final base = id;
          for (var k = 2; generated.contains(id); k++) {
            id = '${base}_$k';
          }
        }
        generated.add(id);
      }
      final finame = str(r, finameC).trim();
      if (finame.isNotEmpty) c.finame[id] = finame;
      switch (g) {
        case CatalogGroup.pipes:
          final usageS = str(r, col(['usage', 'uso']), 'zone,mainline').toLowerCase();
          final usage = <PipeUsage>{
            if (usageS.contains('lat') || usageS.contains('l,') || usageS == 'l') PipeUsage.lateral,
            if (usageS.contains('zon') || usageS.contains('z')) PipeUsage.zone,
            if (usageS.contains('main') || usageS.contains('m')) PipeUsage.mainline,
          };
          final matS = str(r, col(['material']), 'pvc').toLowerCase();
          final mat = PipeMaterial.values.firstWhere(
            (m) => m.name == matS || m.label.toLowerCase() == matS,
            orElse: () => matS.contains('pe') ? PipeMaterial.pehd : (matS.contains('aco') || matS.contains('steel') ? PipeMaterial.steel : PipeMaterial.pvc),
          );
          final nominal = num(r, col(['nominalmm', 'dn', 'nominal']));
          final inner = num(r, col(['idmm', 'di', 'innermm', 'inner']), nominal * 0.9);
          if (!(inner > 0)) {
            skipped.add(li);
            continue;
          }
          c.pipes.add(
            PipeSpec(
              id: id,
              name: name,
              nominalMm: nominal > 0 ? nominal : inner,
              innerDiameterMm: inner,
              material: mat,
              hazenC: num(r, col(['c', 'hazenc']), 150),
              roughnessMm: num(r, col(['roughmm', 'roughness']), 0.0015),
              pressureRatingM: rating(r, 60),
              wallThicknessMm: num(r, col(['wallmm', 'wall']), 2),
              costPerM: cost,
              usage: usage.isEmpty ? {PipeUsage.zone, PipeUsage.mainline} : usage,
              supplier: sup,
              code: code,
            ),
          );
        case CatalogGroup.fittings:
          final kindS = str(r, col(['kind', 'tipo', 'type']), 'coupler');
          final kind = FittingKind.values.firstWhere((k) => k.name.toLowerCase() == kindS.toLowerCase(), orElse: () => fittingKindFromText(kindS));
          c.fittings.add(
            FittingSpec(id: id, name: name, kind: kind, sizeMm: num(r, col(['sizemm', 'dn', 'size'])), size2Mm: num(r, col(['size2mm', 'dn2', 'size2'])), cost: cost, supplier: sup, code: code),
          );
        case CatalogGroup.tapes:
          final q = num(r, col(['qlph', 'q', 'flow']), 1.6);
          final h = num(r, col(['headm', 'head', 'h', 'inleth']), 10);
          final x = num(r, col(['x', 'exponent']), 0.5);
          final inner = num(r, col(['idmm', 'di']), 15.6);
          c.tapes.add(
            TapeSpec(
              id: id,
              name: name,
              innerDiameterMm: inner,
              emitterSpacingM: tapeSpacing(num(r, col(['spacing', 'espacamento', 'sp']), 0.5)),
              emitter: EmitterCurve.fromNominal(flow: q * m3sPerLph, head: h, x: x),
              nominalMm: num(r, col(['nominalmm', 'dn']), 16),
              cv: num(r, col(['cv']), 0.03),
              minHeadM: num(r, col(['minh', 'pmin']), 4),
              maxHeadM: num(r, col(['maxh', 'pmax']), 15),
              defaultInletHeadM: h,
              pressureRatingM: rating(r, 25),
              costPerM: cost,
              supplier: sup,
              code: code,
            ),
          );
        case CatalogGroup.valves:
          final kindS = str(r, col(['kind', 'tipo', 'type']), 'control').toLowerCase();
          final kind = ValveKind.values.firstWhere(
            (k) => k.name == kindS,
            orElse: () => kindS.contains('prv') || kindS.contains('regul')
                ? ValveKind.prv
                : (kindS.contains('filt') ? ValveKind.filter : (kindS.contains('check') || kindS.contains('reten') ? ValveKind.check : ValveKind.control)),
          );
          final size = num(r, col(['sizemm', 'dn', 'size']), 50);
          // `k` + `n`: the law h = k·Q^n with Q in m³/s (as exported); `kv`:
          // the flow coefficient of the data sheets (m³/h at 1 bar); `kcoef`
          // (`kfactor`, `zeta`): the K of h = K·v²/2g; none: K = 5
          final k = num(r, col(['k'])), kv = num(r, col(['kv'])), kc = num(r, col(['kcoef', 'kfactor', 'zeta']));
          final loss = k > 0 ? DeviceLossCurve(k: k, n: num(r, col(['n']), 2)) : (kv > 0 ? kvLossCurve(kv) : DeviceLossCurve.fromK(kc > 0 ? kc : 5, size / 1000));
          c.valves.add(
            ValveSpec(
              id: id,
              name: name,
              kind: kind,
              sizeMm: size,
              loss: loss,
              minFlow: num(r, col(['minqm3h', 'qmin'])) * m3sPerM3h,
              maxFlow: num(r, col(['maxqm3h', 'qmax']), 1000) * m3sPerM3h,
              cost: cost,
              defaultSettingM: num(r, col(['setting'])),
              supplier: sup,
              code: code,
            ),
          );
        case CatalogGroup.pumps:
          final ptsS = str(r, col(['points', 'curve', 'curva']));
          final pts = [for (final (q, h) in parseCurvePoints(ptsS)) (q * m3sPerM3h, h)];
          if (pts.isEmpty) {
            final q = num(r, col(['qm3h', 'q'])), h = num(r, col(['hm', 'h', 'head']));
            if (q > 0 && h > 0) pts.add((q * m3sPerM3h, h));
          }
          if (pts.isEmpty) {
            skipped.add(li);
            continue;
          }
          c.pumps.add(
            PumpSpec(
              id: id,
              name: name,
              points: pts,
              efficiency: num(r, col(['eff', 'efficiency', 'rendimento']), 0.65),
              maxFlow: pts.map((p) => p.$1).reduce((a, b) => a > b ? a : b) * 1.2,
              cost: cost,
              powerKw: num(r, col(['kw', 'power'])),
              submersible: isSubmersible(str(r, col(['type', 'tipo', 'install']))),
              ratedHz: num(r, col(['hz', 'frequency', 'frequencia', 'frecuencia'])),
              supplier: sup,
              code: code,
            ),
          );
        case CatalogGroup.wires:
          var mm2 = num(r, col(['mm2', 'section', 'secao', 'seccion', 'area']));
          final awg = num(r, col(['awg', 'gauge']));
          if (mm2 <= 0 && awg > 0) mm2 = awgMm2(awg.round());
          if (mm2 <= 0) {
            skipped.add(li);
            continue;
          }
          c.wires.add(
            WireSpec(id: id, name: name, sectionMm2: mm2, ohmPerKm: num(r, col(['ohmkm', 'ohm', 'resistance', 'resistencia']), copperOhmPerKm(mm2)), costPerM: cost, supplier: sup, code: code),
          );
        case CatalogGroup.outlets:
          final kindS = str(r, col(['kind', 'tipo', 'type']), 'sprinkler').toLowerCase();
          final kind = OutletKind.values.firstWhere(
            (k) => k.name.toLowerCase() == kindS,
            orElse: () => kindS.contains('micro')
                ? OutletKind.microSprinkler
                : (kindS.contains('drip') || kindS.contains('gotej') ? OutletKind.dripper : (kindS.contains('gun') || kindS.contains('canh') ? OutletKind.gun : OutletKind.sprinkler)),
          );
          final q = num(r, col(['qlph', 'q', 'flow']), 50);
          final h = num(r, col(['headm', 'head', 'h']), 20);
          final x = num(r, col(['x', 'exponent']), 0.5);
          final radius = num(r, col(['radiusm', 'radius', 'raio']));
          final nozzleName = str(r, col(['nozzle', 'bocal', 'boquilla']), '${fmt(q, 0)} L/h');
          final nozzle = NozzleSpec(
            id: '${id}_n',
            name: nozzleName,
            curve: EmitterCurve.fromNominal(flow: q * m3sPerLph, head: h, x: x, radius: radius, radiusB: radius > 0 ? 0.35 : 0),
            minHeadM: num(r, col(['minh', 'pmin']), h * 0.6),
            maxHeadM: num(r, col(['maxh', 'pmax']), h * 1.6),
            defaultHeadM: h,
            cv: num(r, col(['cv']), 0.04),
            arcDeg: num(r, col(['arc']), 360),
          );
          // several rows with the same outlet id become nozzles of one outlet
          final existing = c.outlet(id);
          if (existing != null) {
            existing.nozzles.add(
              NozzleSpec(
                id: '${id}_n${existing.nozzles.length + 1}',
                name: nozzle.name,
                curve: nozzle.curve,
                minHeadM: nozzle.minHeadM,
                maxHeadM: nozzle.maxHeadM,
                defaultHeadM: nozzle.defaultHeadM,
                cv: nozzle.cv,
                arcDeg: nozzle.arcDeg,
              ),
            );
          } else {
            c.outlets.add(
              OutletSpec(id: id, name: name, kind: kind, nozzles: [nozzle], cost: cost, inletMm: num(r, col(['inletmm', 'inlet']), kind == OutletKind.sprinkler ? 20 : 0), supplier: sup, code: code),
            );
          }
      }
      n++;
    }
    return CatalogImportResult(c, n, group: g, generatedIds: generated, skippedRows: skipped, pnAsBar: pnAsBar);
  }

  static FittingKind fittingKindFromText(String s) {
    final l = s.toLowerCase().trim();
    if (l.contains('90') || l.contains('cotov') || l.contains('elbow') || l.contains('codo')) return l.contains('45') ? FittingKind.elbow45 : FittingKind.elbow90;
    // before the tee: "tampão", "take-off" and "tape end" also start with a t
    if (l.contains('cap') || l.contains('tamp') || l.contains('plug')) return FittingKind.endCap;
    if (l.contains('take') || l.contains('inicial') || l.contains('start')) return FittingKind.takeOff;
    if (l.contains('tee') || l.contains('tê') || RegExp(r'^t(?![a-z])').hasMatch(l)) return FittingKind.tee;
    if (l.contains('cross') || l.contains('cruz')) return FittingKind.cross;
    if (l.contains('red')) return FittingKind.reducer;
    if (l.contains('adapt')) return FittingKind.adapter;
    if (l.contains('end') || l.contains('final')) return FittingKind.tapeEnd;
    if (l.contains('riser') || l.contains('haste') || l.contains('subida')) return FittingKind.riser;
    return FittingKind.coupler;
  }

  static CatalogGroup? _detectGroup(List<String> header) {
    bool has(String s) => header.contains(s);
    if (has('points') || has('curve') || has('curva') || has('eff')) return CatalogGroup.pumps;
    if (has('mm2') || has('awg') || has('ohmkm')) return CatalogGroup.wires;
    if (has('spacing') || has('espacamento')) return CatalogGroup.tapes;
    if (has('nozzle') || has('bocal') || has('radiusm') || has('radius') || has('arc')) return CatalogGroup.outlets;
    if (has('size2mm') || has('dn2') || (has('kind') && has('sizemm') && !has('k'))) return CatalogGroup.fittings;
    if (has('k') || has('kv') || has('maxqm3h') || has('setting')) return CatalogGroup.valves;
    if (has('idmm') || has('nominalmm') || has('dn') || has('c')) return CatalogGroup.pipes;
    return null;
  }

  /// Whole catalogue as an Excel workbook, one sheet per group (the sheets
  /// round-trip through [parseXlsx]; prices can be edited in a spreadsheet).
  static Uint8List exportXlsx(Catalog c) {
    final sheets = <XlsxSheet>[];
    for (final g in CatalogGroup.values) {
      final lines = exportCsv(c, g).replaceFirst('\ufeff', '').split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) continue;
      final headers = splitLine(lines.first, ';');
      final rows = <List<Object?>>[];
      for (final l in lines.skip(1)) {
        rows.add([for (final cell in splitLine(l, ';')) double.tryParse(cell) ?? cell]);
      }
      sheets.add(XlsxSheet(name: g.name, headers: headers, rows: rows));
    }
    return XlsxWriter.write(sheets);
  }

  /// Parses a workbook written by [exportXlsx] (or any sheet whose header
  /// row uses the CSV column names); every sheet is merged into one catalogue.
  static CatalogImportResult parseXlsx(Uint8List bytes, {bool? pnInBar}) {
    final merged = Catalog();
    var n = 0, pnAsBar = 0;
    CatalogGroup? last;
    final generated = <String>{}, skipped = <int>[];
    for (final sheet in XlsxReader.read(bytes)) {
      if (sheet.rows.isEmpty) continue;
      final group = CatalogGroup.values.where((g) => g.name.toLowerCase() == sheet.name.toLowerCase().trim()).firstOrNull;
      final b = StringBuffer();
      String cell(Object? v) {
        if (v == null) return '';
        final s = v is double ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '$v';
        return s.contains(';') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
      }

      b.writeln(sheet.headers.join(';'));
      for (final r in sheet.rows) {
        if (r.every((v) => v == null || '$v'.trim().isEmpty)) continue;
        b.writeln(r.map(cell).join(';'));
      }
      CatalogImportResult part;
      try {
        part = parseCsv(b.toString(), group: group, pnInBar: pnInBar);
      } on FormatException {
        continue;
      }
      merged.pipes.addAll(part.catalog.pipes);
      merged.outlets.addAll(part.catalog.outlets);
      merged.tapes.addAll(part.catalog.tapes);
      merged.valves.addAll(part.catalog.valves);
      merged.pumps.addAll(part.catalog.pumps);
      merged.fittings.addAll(part.catalog.fittings);
      merged.wires.addAll(part.catalog.wires);
      merged.finame.addAll(part.catalog.finame);
      n += part.count;
      pnAsBar += part.pnAsBar;
      generated.addAll(part.generatedIds);
      skipped.addAll(part.skippedRows);
      last = part.group;
    }
    if (n == 0) throw const FormatException('catalog_csv_columns');
    return CatalogImportResult(merged, n, group: last, generatedIds: generated, skippedRows: skipped, pnAsBar: pnAsBar);
  }

  /// CSV of one group (round-trips through [parseCsv]).
  static String exportCsv(Catalog c, CatalogGroup g) {
    final b = StringBuffer('﻿');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    switch (g) {
      case CatalogGroup.pipes:
        b.writeln('id;name;nominalMm;idMm;material;c;roughMm;ratingM;wallMm;cost;usage;supplier;code');
        for (final p in c.pipes) {
          b.writeln(
            [
              p.id,
              q(p.name),
              p.nominalMm,
              p.innerDiameterMm,
              p.material.name,
              p.hazenC,
              p.roughnessMm,
              p.pressureRatingM,
              p.wallThicknessMm,
              p.costPerM,
              p.usage.map((u) => u.name).join(','),
              q(p.supplier),
              q(p.code),
            ].join(';'),
          );
        }
      case CatalogGroup.fittings:
        b.writeln('id;name;kind;sizeMm;size2Mm;cost;supplier;code');
        for (final f in c.fittings) {
          b.writeln([f.id, q(f.name), f.kind.name, f.sizeMm, f.size2Mm, f.cost, q(f.supplier), q(f.code)].join(';'));
        }
      case CatalogGroup.tapes:
        b.writeln('id;name;nominalMm;idMm;spacing;qLph;headM;x;cv;minH;maxH;ratingM;cost;supplier;code');
        for (final t in c.tapes) {
          b.writeln(
            [
              t.id,
              q(t.name),
              t.nominalMm,
              t.innerDiameterMm,
              t.emitterSpacingM,
              t.emitter.flow(t.defaultInletHeadM) / m3sPerLph,
              t.defaultInletHeadM,
              t.emitter.x,
              t.cv,
              t.minHeadM,
              t.maxHeadM,
              t.pressureRatingM,
              t.costPerM,
              q(t.supplier),
              q(t.code),
            ].join(';'),
          );
        }
      case CatalogGroup.valves:
        b.writeln('id;name;kind;sizeMm;k;n;minQm3h;maxQm3h;setting;cost;supplier;code');
        for (final v in c.valves) {
          b.writeln([v.id, q(v.name), v.kind.name, v.sizeMm, v.loss.k, v.loss.n, v.minFlow / m3sPerM3h, v.maxFlow / m3sPerM3h, v.defaultSettingM, v.cost, q(v.supplier), q(v.code)].join(';'));
        }
      case CatalogGroup.pumps:
        b.writeln('id;name;points;eff;kw;type;hz;cost;supplier;code');
        for (final p in c.pumps) {
          b.writeln(
            [
              p.id,
              q(p.name),
              q(p.points.map((pt) => '${fmt(pt.$1 / m3sPerM3h, 2)}@${fmt(pt.$2, 2)}').join('|')),
              p.efficiency,
              p.powerKw,
              p.submersible ? 'submersible' : 'surface',
              p.ratedHz > 0 ? p.ratedHz : '',
              p.cost,
              q(p.supplier),
              q(p.code),
            ].join(';'),
          );
        }
      case CatalogGroup.wires:
        b.writeln('id;name;mm2;ohmKm;cost;supplier;code');
        for (final w in c.wires) {
          b.writeln([w.id, q(w.name), w.sectionMm2, w.ohmPerKm, w.costPerM, q(w.supplier), q(w.code)].join(';'));
        }
      case CatalogGroup.outlets:
        b.writeln('id;name;kind;nozzle;qLph;headM;x;radiusM;minH;maxH;cv;arc;inletMm;cost;supplier;code');
        for (final o in c.outlets) {
          for (final n in o.nozzles) {
            b.writeln(
              [
                o.id,
                q(o.name),
                o.kind.name,
                q(n.name),
                n.curve.flow(n.defaultHeadM) / m3sPerLph,
                n.defaultHeadM,
                n.curve.x,
                n.curve.radius(n.defaultHeadM),
                n.minHeadM,
                n.maxHeadM,
                n.cv,
                n.arcDeg,
                o.inletMm,
                o.cost,
                q(o.supplier),
                q(o.code),
              ].join(';'),
            );
          }
        }
    }
    if (c.finame.isEmpty) return b.toString();
    // the BNDES FINAME codes as a last column, by the id of each row
    final lines = b.toString().split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].isEmpty) lines[i] else if (i == 0) '${lines[i]};finame' else '${lines[i]};${q(c.finame[lines[i].split(';').first] ?? '')}',
    ].join('\n');
  }
}
