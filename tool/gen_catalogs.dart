/// Maintains the catalogue pack repository (`catalogs/`):
/// - builds the generic pipe packs from lib/core/model/pipe_standards.dart
///   (astm, en12201, is4984, is4985, iso1452: the dimension tables of the
///   standards with their reference prices), checks every wall against its
///   pressure class and the physical plausibility, and writes them;
/// - validates every `*.oci.cat` (format, unique ids, k/x curves, the
///   physical plausibility of catalog_check.dart);
/// - rewrites each pack normalised (pretty JSON, `items` count);
/// - rebuilds `catalogs/index.json` from the packs.
///
/// Run: dart run tool/gen_catalogs.dart [--check]
/// With `--check` nothing is written; the exit code is 1 when a file would
/// change (a generated pack that differs from its file included) or a pack
/// is invalid (for CI).
library;

import 'dart:io';

import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_check.dart';
import 'package:opencadirrigation/core/model/pipe_standards.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final dir = Directory('catalogs');
  if (!dir.existsSync()) {
    stderr.writeln('catalogs/ not found (run from the repository root)');
    exit(2);
  }
  var problems = 0, changed = 0;
  // the packs built from the standards: a wall too thin for its table or its
  // class, an implausible value, then the file as built
  for (final pack in standardCatalogPacks()) {
    final name = '${pack.meta.id}$catalogPackExtension';
    for (final issue in [...standardCatalogIssues(pack.catalog), ...catalogPlausibility(pack.catalog)]) {
      stderr.writeln('$name: built pipe fails $issue');
      problems++;
    }
    final f = File('${dir.path}/$name');
    final text = '${CatalogIo.encodePack(pack.meta, pack.catalog)}\n';
    if (!f.existsSync() || f.readAsStringSync() != text) {
      changed++;
      if (check) {
        stderr.writeln('$name: differs from the pack built from the standards (run without --check)');
      } else {
        f.writeAsStringSync(text);
      }
    }
  }
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith(catalogPackExtension)).toList()..sort((a, b) => a.path.compareTo(b.path));
  final entries = <CatalogIndexEntry>[];
  final ids = <String, String>{};
  final defaults = Catalog.defaultCatalog();
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    late CatalogPackFile pack;
    try {
      pack = CatalogIo.parsePack(f.readAsStringSync(), fallbackId: CatalogPackMeta.idFrom(name));
    } catch (e) {
      stderr.writeln('$name: cannot parse: $e');
      problems++;
      continue;
    }
    final expectedName = '${pack.meta.id}$catalogPackExtension';
    if (name != expectedName) {
      stderr.writeln('$name: id "${pack.meta.id}" does not match the file name (expected $expectedName)');
      problems++;
    }
    if (pack.itemCount == 0) {
      stderr.writeln('$name: empty pack');
      problems++;
    }
    for (final id in _ids(pack.catalog)) {
      final other = ids[id];
      if (other != null) {
        stderr.writeln('$name: id "$id" also in $other');
        problems++;
      }
      ids[id] = name;
      if (_ids(defaults).contains(id)) {
        stderr.writeln('$name: id "$id" clashes with the built-in catalogue');
        problems++;
      }
    }
    for (final o in pack.catalog.outlets) {
      for (final n in o.nozzles) {
        if (!(n.curve.k > 0) || n.curve.x < 0 || n.curve.x > 1.2) {
          stderr.writeln('$name: nozzle ${o.id}/${n.id} has an implausible curve (k=${n.curve.k}, x=${n.curve.x})');
          problems++;
        }
      }
    }
    // a wall too thin for its class, a nozzle above an ideal orifice, a pump curve above its motor
    for (final issue in catalogPlausibility(pack.catalog)) {
      stderr.writeln('$name: implausible $issue');
      problems++;
    }
    final text = '${CatalogIo.encodePack(pack.meta, pack.catalog)}\n';
    if (text != f.readAsStringSync()) {
      changed++;
      if (check) {
        stderr.writeln('$name: not normalised (run without --check)');
      } else {
        f.writeAsStringSync(text);
      }
    }
    entries.add(CatalogIndexEntry(meta: pack.meta, file: name, items: pack.itemCount));
    stdout.writeln('$name: ${pack.meta.brand}, ${pack.itemCount} items');
  }
  final index = File('${dir.path}/index.json');
  final indexText = '${CatalogIo.encodeIndex(entries)}\n';
  if (!index.existsSync() || index.readAsStringSync() != indexText) {
    changed++;
    if (check) {
      stderr.writeln('index.json: out of date (run without --check)');
    } else {
      index.writeAsStringSync(indexText);
    }
  }
  stdout.writeln('${entries.length} packs, ${ids.length} items${check ? '' : ', $changed file(s) written'}');
  if (problems > 0 || (check && changed > 0)) exit(1);
}

Set<String> _ids(Catalog c) => {
  ...c.pipes.map((e) => e.id),
  ...c.outlets.map((e) => e.id),
  ...c.tapes.map((e) => e.id),
  ...c.valves.map((e) => e.id),
  ...c.pumps.map((e) => e.id),
  ...c.fittings.map((e) => e.id),
  ...c.wires.map((e) => e.id),
};
