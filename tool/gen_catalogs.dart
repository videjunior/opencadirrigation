/// Maintains the catalogue pack repository (`catalogs/`):
/// - validates every `*.oci.cat` (format, unique ids, k/x curves);
/// - rewrites each pack normalised (pretty JSON, `items` count);
/// - rebuilds `catalogs/index.json` from the packs.
///
/// Run: dart run tool/gen_catalogs.dart [--check]
/// With `--check` nothing is written; the exit code is 1 when a file would
/// change or a pack is invalid (for CI).
library;
import 'dart:io';

import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final dir = Directory('catalogs');
  if (!dir.existsSync()) {
    stderr.writeln('catalogs/ not found (run from the repository root)');
    exit(2);
  }
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith(catalogPackExtension)).toList()..sort((a, b) => a.path.compareTo(b.path));
  final entries = <CatalogIndexEntry>[];
  final ids = <String, String>{};
  final defaults = Catalog.defaultCatalog();
  var problems = 0, changed = 0;
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
};
