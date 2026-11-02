/// OpenCADIrrigation on the command line: designs, analyses, checks, exports
/// and lists the materials of `.oci.json` projects with the engine of the app
/// (lib/core), in the Dart VM, without Flutter or a browser.
///
///   dart run bin/oci.dart --help
///   dart run bin/oci.dart design examples/pt/garden.oci.json --lang pt --out designed.oci.json --report report.xlsx
///   dart run bin/oci.dart check project.oci.json && echo ok
///   dart run bin/oci.dart validate project.oci.json
///   dart run bin/oci.dart export project.oci.json --format dxf --out project.dxf
///   dart run bin/oci.dart import survey.dxf field.kml --out farm.oci.json
///   dart run bin/oci.dart new --out lawn.oci.json --boundary lawn.kml --layout --currency USD --hz 60
///   dart run bin/oci.dart design projects/ --out-dir designed/
///
/// Besides lib/core it reads two plain-Dart files of lib/app that the design
/// worker also compiles without Flutter: the string table (i18n.dart) and the
/// version (version.dart). Language packs (assets/i18n) and the PDF fonts
/// (assets/fonts) are read from the package folder.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/version.dart' show appName, appVersionFull;
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart' show layoutLandscape;
import 'package:opencadirrigation/core/io/drawing_import.dart';
import 'package:opencadirrigation/core/io/fonts/pdf_fonts.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/area_holes.dart' show fitsAsHole, holesOf;
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart' show catalogPackExtension;
import 'package:opencadirrigation/core/model/currency.dart' show catalogPriceCurrency, currencyByCode, exchangeRate;
import 'package:opencadirrigation/core/model/edit_ops.dart' show areaOutline;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/read_report.dart';
import 'package:opencadirrigation/core/model/schema.dart';
import 'package:opencadirrigation/core/units.dart';

Future<void> main(List<String> args) async {
  exitCode = await runOci(args);
}

/// Exit codes of [runOci].
abstract final class OciExit {
  static const ok = 0;

  /// `check` found at least one error.
  static const problems = 1;

  /// Bad command line.
  static const usage = 2;

  /// A file could not be read or written, or is not a project.
  static const io = 3;

  /// The calculation or the export failed.
  static const failed = 4;
}

const _commands = ['design', 'analyze', 'check', 'validate', 'export', 'bom', 'schema', 'import', 'new', 'set', 'pack'];
const _valueOptions = {'out', 'report', 'results', 'lang', 'format', 'georef', 'paper', 'out-dir', 'into', 'units', 'currency', 'hz', 'name', 'boundary', 'outlet'};
const _flagOptions = {'design', 'analyze', 'portrait', 'json', 'help', 'version', 'no-results', 'layout'};

/// The commands that run on projects and take several of them (files or
/// folders of `.oci.json`) in one go.
const _batchCommands = {'design', 'analyze', 'check', 'validate', 'export', 'bom'};

const usageText =
    '''
Usage: dart run bin/oci.dart <command> <project.oci.json>… [options]

Commands:
  design    Size the pipes and analyse the design (F5 in the app) and print a summary.
  analyze   Analyse the design as drawn, without changing any pipe size.
  check     List the problems of the project (design check and the design assistant's
            messages); exit code 1 when there is an error.
  validate  Read the file item by item and list what had to be repaired (items set
            aside, renumbered ids, dropped vertices, unknown options, a newer format)
            and the errors of the design check; exit code 1 when there is any.
  export    Write the drawing in another format (--format, --out).
  bom       Size the design and print the bill of materials.
  schema    Print the JSON Schema of the project file (built from the model; no file).
  import    Make a project of drawings, maps and surveys: import <file>… --out <project>
            (DXF, DWG, DGN, KML/KMZ, shapefile or zip, GeoJSON, GPX, LandXML, EPANET .inp,
            LAS, GeoTIFF elevations, CSV points); --into <project> adds them to one.
  new       A new project: new --out <project> [--name] [--units] [--currency] [--hz]
            [--georef]; --boundary <file> makes the largest closed outline of a drawing an
            irrigated area, --layout lays sprinklers over it (--outlet <catalogue id>).
  set       Change a project: set <project> [--units] [--currency] [--hz] [--name]
            [--georef] [--out <file>] (the prices follow the currency at the reference rates;
            without --out the file is rewritten; the results are left out).
  pack add  Add catalogue packs: pack add <project> <pack.oci.cat or bundled id>… [--out]
            (ids kept, prices converted to the project's currency).

design, analyze, check, validate, export and bom take several projects (or folders of
.oci.json files) in one run; --out-dir tells where their files go.

Options:
  --out <file>        design: the designed project (.oci.json) with its results, as the app
                      saves it; export: the exported file (default: next to the project); bom:
                      the bill of materials (.csv, .txt, .xlsx or .pdf).
  --no-results        design: the --out project without the results.
  --report <file>     design, analyze: every report table (.csv, .txt, .xlsx or .pdf).
  --results <file>    design, analyze: the design results as JSON.
  --lang <code>       language of the names, reports and messages (default en):
                      ${'{languages}'}
  --format <name>     export: dxf, dwg, pdf, svg, kml, kmz, geojson, shp (zip), gpx,
                      landxml, ifc or inp (EPANET).
  --georef <lat,lon>  export: WGS84 position of the drawing origin (0, 0) for a project
                      without a georeference (kml, kmz, geojson and gpx need one); import,
                      new, set: the georeference of the project.
  --design            export, check: size and analyse first (sized pipes, results, all
                      the messages); bom sizes by default.
  --analyze           export, check, bom: analyse first, keeping the pipe sizes as drawn.
  --paper <size>      export pdf, svg: a4, a3 (default), a2, a1, a0, letter or tabloid.
  --portrait          export pdf, svg: portrait sheet (default landscape).
  --json              check, validate: the messages as JSON.
  --out-dir <dir>     several projects: where the designed projects, exports, reports
                      and bills go, named after each project (default: next to it).
  --into <project>    import: add the drawings to this project (default: a new one).
  --units <system>    new, set: metric or us.
  --currency <code>   new, set: ISO 4217 code of the prices (BRL, USD, EUR…).
  --hz <50|60>        new, set: mains frequency of the pumps.
  --name <text>       new, set: name of the project.
  --boundary <file>   new: the drawing whose largest closed outline is the area.
  --layout            new: lay sprinkler heads over the area.
  --outlet <id>       new --layout: the sprinkler family (default the first enabled one).
  -h, --help          This help.
  --version           The version of the engine.

Exit codes: 0 done, 1 check found errors (validate: repairs or errors), 2 bad command
line, 3 a file could not be read or written, 4 the calculation or the export failed.''';

String _usage() => usageText.replaceFirst('{languages}', supportedLanguages.join(', '));

class _UsageError implements Exception {
  _UsageError(this.message);
  final String message;
}

class _Args {
  String? command;
  final positional = <String>[];
  final values = <String, String>{};
  final flags = <String>{};

  /// A copy to change for one project of a batch.
  _Args copy() => _Args()
    ..command = command
    ..positional.addAll(positional)
    ..values.addAll(values)
    ..flags.addAll(flags);
}

_Args _parse(List<String> args) {
  final a = _Args();
  for (var i = 0; i < args.length; i++) {
    final s = args[i];
    if (s == '-h') {
      a.flags.add('help');
    } else if (s.startsWith('--')) {
      final eq = s.indexOf('=');
      final name = eq > 0 ? s.substring(2, eq) : s.substring(2);
      if (_flagOptions.contains(name) && eq < 0) {
        a.flags.add(name);
      } else if (_valueOptions.contains(name)) {
        if (eq > 0) {
          a.values[name] = s.substring(eq + 1);
        } else if (i + 1 < args.length) {
          a.values[name] = args[++i];
        } else {
          throw _UsageError('--$name needs a value');
        }
      } else {
        throw _UsageError('unknown option $s');
      }
    } else if (a.command == null && a.positional.isEmpty && _commands.contains(s)) {
      a.command = s;
    } else {
      a.positional.add(s);
    }
  }
  return a;
}

/// Runs one command; returns the exit code ([OciExit]). [out] and [err]
/// default to stdout and stderr; [home] is the package folder (language
/// packs, PDF fonts), found from the script or the working folder when null.
Future<int> runOci(List<String> args, {StringSink? out, StringSink? err, String? home}) async {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final _Args a;
  try {
    a = _parse(args);
  } on _UsageError catch (x) {
    e.writeln('oci: ${x.message}\n');
    e.writeln(_usage());
    return OciExit.usage;
  }
  if (a.flags.contains('version')) {
    o.writeln('$appName $appVersionFull');
    return OciExit.ok;
  }
  if (a.flags.contains('help') || (a.command == null && a.positional.isEmpty)) {
    o.writeln('$appName $appVersionFull: irrigation design on the command line\n');
    o.writeln(_usage());
    return a.command == null && a.positional.isEmpty && !a.flags.contains('help') ? OciExit.usage : OciExit.ok;
  }
  final command = a.command;
  if (command == null) {
    e.writeln('oci: unknown command ${a.positional.first} (one of ${_commands.join(', ')})');
    return OciExit.usage;
  }
  if (command == 'schema') {
    o.writeln(const JsonEncoder.withIndent('  ').convert(projectJsonSchema()));
    return OciExit.ok;
  }
  if (_batchCommands.contains(command) && a.positional.isEmpty) {
    e.writeln('oci: $command needs a project file (.oci.json), several, or a folder of them');
    return OciExit.usage;
  }
  final lang = a.values['lang'] ?? 'en';
  if (!supportedLanguages.contains(lang)) {
    e.writeln('oci: unknown language $lang (one of ${supportedLanguages.join(', ')})');
    return OciExit.usage;
  }
  final root = home ?? _findHome();
  final session = _Session(o, e, root, lang);
  try {
    await session.loadLanguage();
    switch (command) {
      case 'import':
        return await session.importDrawings(a);
      case 'new':
        return await session.newProject(a);
      case 'set':
        return await session.setProject(a);
      case 'pack':
        return await session.pack(a);
    }
    final inputs = session.projectFiles(a.positional);
    if (inputs.length == 1 && !a.values.containsKey('out-dir')) return await session.runOn(command, inputs.single, a);
    return await session.batch(command, inputs, a);
  } on _UsageError catch (x) {
    e.writeln('oci: ${x.message}');
    return OciExit.usage;
  } on _Failure catch (x) {
    e.writeln('oci: ${x.message}');
    return x.code;
  }
}

class _Failure implements Exception {
  _Failure(this.code, this.message);
  final int code;
  final String message;
}

/// The package folder: two levels above bin/oci.dart, else the working folder
/// or one of its parents with the app's pubspec.yaml.
String? _findHome() {
  bool isHome(Directory d) => File('${d.path}/pubspec.yaml').existsSync() && Directory('${d.path}/assets').existsSync();
  final script = Platform.script;
  if (script.scheme == 'file' && script.path.endsWith('.dart')) {
    final d = File.fromUri(script).parent.parent;
    if (isHome(d)) return d.path;
  }
  var d = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    if (isHome(d)) return d.path;
    if (d.parent.path == d.path) break;
    d = d.parent;
  }
  return null;
}

class _Session {
  _Session(this.out, this.err, this.home, this.lang) : t = I18n(lang);

  final StringSink out;
  final StringSink err;
  final String? home;
  final String lang;
  final I18n t;

  // ------------------------------------------------------------------ input

  Future<void> loadLanguage() async {
    if (isLanguageLoaded(lang)) return;
    final file = home == null ? null : File('$home/assets/i18n/$lang.json');
    if (file == null || !file.existsSync()) {
      err.writeln('oci: no language pack for $lang (assets/i18n/$lang.json): English is used');
      return;
    }
    installLanguagePack(lang, LanguagePack.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>));
  }

  /// What reading the project had to repair ([readProject]).
  ProjectReadReport report = ProjectReadReport();

  /// Reads the project item by item; the repairs go to [report] and, one
  /// line each, to the error output.
  Project readProject(String path) {
    final f = File(path);
    if (!f.existsSync()) throw _Failure(OciExit.io, '$path: no such file');
    final ProjectFile file;
    try {
      file = readProjectFile(f.readAsStringSync());
    } on FormatException catch (x) {
      throw _Failure(OciExit.io, '$path: ${t.has('imp.err.${x.message}') ? t('imp.err.${x.message}') : 'not an OpenCADIrrigation project (${x.message})'}');
    } catch (x) {
      throw _Failure(OciExit.io, '$path: cannot be read ($x)');
    }
    report = file.report;
    for (final n in report.notes) {
      err.writeln('oci: $path: ${_note(n)}');
    }
    return file.project;
  }

  String _note(ReadNote n) => t.has('read.${n.code}') ? t('read.${n.code}', n.args) : '$n';

  // ------------------------------------------------------------------ several projects (1.6.0 MOD)

  /// The project files of [paths]: the files as given, and every `.oci.json`
  /// inside a folder (and its folders), in order.
  List<String> projectFiles(List<String> paths) {
    final out = <String>[];
    for (final path in paths) {
      if (FileSystemEntity.isDirectorySync(path)) {
        final found = [
          for (final f in Directory(path).listSync(recursive: true).whereType<File>())
            if (f.path.toLowerCase().endsWith('.oci.json')) f.path,
        ]..sort();
        if (found.isEmpty) throw _UsageError('$path: no project file (.oci.json) in it');
        out.addAll(found);
      } else {
        out.add(path);
      }
    }
    return out;
  }

  /// Runs [command] on the project file [path].
  Future<int> runOn(String command, String path, _Args a) async {
    final project = readProject(path);
    return switch (command) {
      'design' => await design(project, a, size: true),
      'analyze' => await design(project, a, size: false),
      'check' => await check(project, a),
      'validate' => await validate(project, a),
      'export' => await export(project, a, path),
      'bom' => await bom(project, a),
      _ => throw _UsageError('$command does not run on projects'),
    };
  }

  /// Runs [command] on every project of [inputs] in turn: the files of each
  /// (designed project, export, report, results, bill of materials) go to
  /// --out-dir, or next to the project, named after it; a project that
  /// fails does not stop the others. The exit code is the worst of all.
  Future<int> batch(String command, List<String> inputs, _Args a) async {
    if (a.values.containsKey('out') && command != 'bom') throw _UsageError('several projects: --out-dir tells where their files go (not --out)');
    final dir = a.values['out-dir'];
    if (dir != null) {
      try {
        Directory(dir).createSync(recursive: true);
      } on FileSystemException catch (x) {
        throw _Failure(OciExit.io, '$dir: cannot be made (${x.osError?.message ?? x.message})');
      }
    }
    String ext(String v) => v.contains('.') ? v.split('.').last : v;
    final formatName = a.values['format']?.toLowerCase();
    final format = formatName == null ? null : DrawingFormat.values.where((f) => f.name == formatName).firstOrNull;
    var worst = OciExit.ok, ok = 0, problems = 0, failed = 0;
    for (final path in inputs) {
      final stem = File(_stem(path)).uri.pathSegments.last;
      final folder = dir ?? File(path).parent.path;
      String named(String suffix) => '$folder/$stem$suffix';
      final per = a.copy()..values.remove('out-dir');
      if (command == 'design' && dir != null) per.values['out'] = named('.oci.json');
      if (command == 'export' && format != null) per.values['out'] = named('.${format.extension}');
      final bomOut = a.values['out'], report = a.values['report'];
      if (command == 'bom' && bomOut != null) per.values['out'] = named('.bom.${ext(bomOut)}');
      if (report != null) per.values['report'] = named('.report.${ext(report)}');
      if (a.values['results'] != null) per.values['results'] = named('.results.json');
      out.writeln('== $path');
      int code;
      try {
        code = await runOn(command, path, per);
      } on _Failure catch (x) {
        err.writeln('oci: $path: ${x.message}');
        code = x.code;
      }
      if (code > worst) worst = code;
      if (code == OciExit.ok) {
        ok++;
      } else if (code == OciExit.problems) {
        problems++;
      } else {
        failed++;
      }
    }
    out.writeln('${inputs.length} projects: $ok done, $problems with problems, $failed failed');
    return worst;
  }

  // ------------------------------------------------------------------ making projects (1.6.0 MOD)

  /// A new project as the app makes one: the default catalogue in the
  /// language and in the currency of --currency (the energy price too),
  /// then --units, --hz, --name and --georef.
  Project blankProject(_Args a) {
    final code = (a.values['currency'] ?? catalogPriceCurrency).toUpperCase();
    final currency = currencyByCode(code);
    if (currency == null) throw _UsageError('unknown currency $code (an ISO 4217 code: BRL, USD, EUR…)');
    final project = Project(catalog: Catalog.defaultCatalog(lang: lang, currency: code));
    final defaults = DesignParameters();
    final rate = exchangeRate(defaults.currencyCode, code);
    project.params
      ..currencyCode = code
      ..currency = currency.symbol
      ..powerCostPerKwh = defaults.powerCostPerKwh * (rate ?? 1);
    project.meta.name = t('name.newProject');
    _settings(project, a, currency: false);
    return project;
  }

  /// --units, --hz, --name, --georef and (with [currency]) --currency on
  /// [project]: a new currency converts every price at the reference rate.
  void _settings(Project project, _Args a, {bool currency = true}) {
    final units = a.values['units'];
    if (units != null) {
      project.params.units = switch (units.toLowerCase()) {
        'metric' || 'si' => Units.metric,
        'us' || 'imperial' => Units.us,
        _ => throw _UsageError('--units: metric or us'),
      };
    }
    final hz = a.values['hz'];
    if (hz != null) {
      final v = double.tryParse(hz);
      if (v != 50 && v != 60) throw _UsageError('--hz: 50 or 60');
      project.params.mainsHz = v!;
    }
    final name = a.values['name'];
    if (name != null) project.meta.name = name;
    final georef = a.values['georef'];
    if (georef != null) {
      final ll = parseLatLon(georef);
      if (ll == null) throw _UsageError('--georef: not a position: $georef (e.g. -22.9068,-43.1729)');
      project.meta.georef = GeoReference.fromLatLonOrigin(ll.$1, ll.$2);
    }
    final code = a.values['currency'];
    if (currency && code != null) {
      final to = code.toUpperCase();
      if (currencyByCode(to) == null) throw _UsageError('unknown currency $to (an ISO 4217 code: BRL, USD, EUR…)');
      final from = project.params.currencyCode;
      if (to != from) {
        final rate = from.isEmpty ? null : exchangeRate(from, to);
        if (rate == null) err.writeln('oci: no reference rate from ${from.isEmpty ? '?' : from} to $to: the prices keep their numbers');
        project.setCurrency(to, rate: rate);
      }
    }
  }

  void _writeProject(String path, Project project) => _write(path, encodeJson(project.toJson(), pretty: true));

  /// import: drawings, maps and surveys into a new project, or into --into.
  Future<int> importDrawings(_Args a) async {
    if (a.positional.isEmpty) throw _UsageError('import needs one or more files (${drawingImportExtensions.join(' ')})');
    final into = a.values['into'];
    final project = into == null ? blankProject(a) : readProject(into);
    if (into == null) project.meta.name = a.values['name'] ?? File(_stem(a.positional.first)).uri.pathSegments.last;
    for (final path in a.positional) {
      _importInto(project, path);
    }
    _writeProject(a.values['out'] ?? into ?? '${_stem(a.positional.first)}.oci.json', project);
    return OciExit.ok;
  }

  /// Reads the drawing [path] into [project] (as File → Import does) and
  /// says what came in.
  FileImport _importInto(Project project, String path) {
    final f = File(path);
    if (!f.existsSync()) throw _Failure(OciExit.io, '$path: no such file');
    final FileImport r;
    try {
      r = importFileInto(project, f.uri.pathSegments.last, f.readAsBytesSync());
    } on FormatException catch (x) {
      throw _Failure(OciExit.io, '$path: ${_importError(x.message)}');
    }
    final geo = r.georefTaken ? ' (georeference ${project.meta.georef?.crsName ?? '-'})' : '';
    out.writeln('$path: ${r.kind}, ${r.entities.length} items$geo');
    for (final w in r.warnings) {
      err.writeln('oci: $path: ${t.warning(w)}');
    }
    return r;
  }

  String _importError(String code) => switch (code) {
    'import_format' => 'not a format the command line imports (${drawingImportExtensions.join(' ')}); PDF plans and pictures come in with the app',
    'import_not_dem' => 'a GeoTIFF without elevations: pictures come in with the app',
    'file_corrupt' => 'the file is damaged (a reader could not go on)',
    _ => t.has('imp.err.$code') ? t('imp.err.$code') : code,
  };

  /// new: a project with --boundary as its irrigated area and, with
  /// --layout, sprinkler heads over it.
  Future<int> newProject(_Args a) async {
    final dest = a.values['out'] ?? (a.positional.length == 1 ? a.positional.single : null);
    if (dest == null) throw _UsageError('new needs --out <project.oci.json>');
    final project = blankProject(a);
    AreaEntity? area;
    final boundary = a.values['boundary'];
    if (boundary != null) {
      final r = _importInto(project, boundary);
      area = _areaOf(project, r.entities);
      if (area == null) throw _Failure(OciExit.failed, '$boundary: no closed outline to make the area of');
      out.writeln('area «${area.name}»: ${fmt(area.area / 10000, 4)} ha');
    }
    if (a.flags.contains('layout')) {
      if (area == null) throw _UsageError('--layout needs --boundary <file> (the area to lay the heads over)');
      final heads = _layout(project, area, a.values['outlet']);
      final family = project.catalog.outlet(heads.first.outletSpecId)?.name ?? heads.first.outletSpecId;
      out.writeln('layout: ${heads.length} heads of $family');
    }
    _writeProject(dest, project);
    return OciExit.ok;
  }

  /// The largest closed outline among [made] (a closed polyline, the
  /// polygon of a map, a hatch, a circle…) made an irrigated area in its
  /// place; null without one.
  AreaEntity? _areaOf(Project project, List<Entity> made) {
    (Entity, List<Pt>)? best;
    for (final e in made) {
      final o = e is AreaEntity ? e.points : areaOutline(e, tol: project.params.connectTolerance);
      if (o == null || o.length < 3) continue;
      if (best == null || polygonArea(o).abs() > polygonArea(best.$2).abs()) best = (e, o);
    }
    if (best == null) return null;
    final (e, outline) = best;
    if (e is AreaEntity) return e;
    final area = AreaEntity(id: e.id, name: e.name.isNotEmpty ? e.name : t('name.area'), points: List.of(outline));
    final i = project.entities.indexOf(e);
    if (i >= 0) project.entities[i] = area;
    // the other closed outlines inside it (the holes of a polygon of a map,
    // a pond drawn in the field) are its islands
    for (final other in made) {
      if (identical(other, e) || other is AreaEntity) continue;
      final o = areaOutline(other, tol: project.params.connectTolerance);
      if (o == null || !fitsAsHole(area, o)) continue;
      area.holes.add(o);
      project.entities.remove(other);
    }
    return area;
  }

  /// Sprinkler heads of [outletId] (default: the first enabled sprinkler of
  /// the catalogue) over [area], as the automatic layout of the app lays
  /// them (no zones or pipes yet).
  List<OutletEntity> _layout(Project project, AreaEntity area, String? outletId) {
    final cat = project.catalog;
    final family = outletId != null
        ? (cat.outlet(outletId) ?? (throw _UsageError('--outlet: no emitter $outletId in the catalogue')))
        : cat.outlets.where((o) => o.enabled && o.kind == OutletKind.sprinkler).firstOrNull;
    if (family == null) throw _Failure(OciExit.failed, 'no enabled sprinkler in the catalogue: pass --outlet <id>');
    final layout = layoutLandscape(outline: area.points, exclusions: holesOf(area), family: family);
    if (layout.isEmpty) throw _Failure(OciExit.failed, 'no head fits the area (${layout.messages.join(', ')})');
    final heads = layout.toOutlets(project);
    project.entities.addAll(heads);
    return heads;
  }

  /// set: --units, --currency, --hz, --name, --georef on a project.
  Future<int> setProject(_Args a) async {
    if (a.positional.length != 1) throw _UsageError('set needs one project file (.oci.json)');
    final path = a.positional.single;
    final project = readProject(path);
    _settings(project, a);
    _writeProject(a.values['out'] ?? path, project);
    return OciExit.ok;
  }

  /// pack add: catalogue packs (a file, or the id of a bundled pack of
  /// catalogs/) added to a project as the app adds them.
  Future<int> pack(_Args a) async {
    if (a.positional.length < 3 || a.positional.first != 'add') throw _UsageError('pack add <project.oci.json> <pack.oci.cat or bundled pack id>…');
    final path = a.positional[1];
    final project = readProject(path);
    for (final ref in a.positional.skip(2)) {
      final File? file = File(ref).existsSync() ? File(ref) : (home == null ? null : File('$home/catalogs/$ref$catalogPackExtension'));
      if (file == null || !file.existsSync()) throw _Failure(OciExit.io, '$ref: no such pack (a .oci.cat file or the id of a pack in catalogs/)');
      final CatalogPack pack;
      try {
        pack = CatalogPack.parse(file.readAsStringSync(), origin: file.path);
      } catch (x) {
        throw _Failure(OciExit.io, '$ref: not a catalogue pack ($x)');
      }
      final r = addCatalogPack(project.catalog, pack, projectCurrency: project.params.currencyCode);
      final from = r.from.isEmpty ? '?' : r.from;
      final prices = r.converted ? ', prices from ${r.from} to ${r.to}' : (r.unknownCurrency ? ', prices kept as they are (no rate from $from)' : '');
      out.writeln('${pack.id}: ${r.added} items added$prices');
    }
    _writeProject(a.values['out'] ?? path, project);
    return OciExit.ok;
  }

  // ------------------------------------------------------------------ design

  /// Sizes ([size]) and analyses the project in place, as the app's design
  /// worker does; null when there is nothing to design.
  DesignResults? run(Project project, {required bool size}) {
    if (!project.entities.any((e) => e is ControlValveEntity || e is WaterSupplyEntity || e is PivotEntity)) return null;
    try {
      return Designer(project, label: (k) => t(k)).designAll(sizeZones: size, sizeMain: size);
    } catch (x, st) {
      throw _Failure(OciExit.failed, 'the calculation failed: $x\n$st');
    }
  }

  Future<int> design(Project project, _Args a, {required bool size}) async {
    final r = run(project, size: size);
    if (r == null) throw _Failure(OciExit.failed, t('msg.noValves'));
    _summary(project, r, size ? 'design' : 'analyze');
    final ex = exporter(project, r);
    final projectOut = a.values['out'];
    if (projectOut != null) {
      if (!size) throw _UsageError('analyze does not change the project: --out is for design');
      // as the app saves it: the project and the results of its design
      final j = project.toJson();
      if (!a.flags.contains('no-results')) j['results'] = r.toJson();
      _write(projectOut, encodeJson(j, pretty: true));
    }
    final resultsOut = a.values['results'];
    if (resultsOut != null) _write(resultsOut, const JsonEncoder.withIndent('  ').convert(r.toJson()));
    final reportOut = a.values['report'];
    if (reportOut != null) {
      final f = _reportFormat(reportOut);
      if (f == ReportFormat.pdf) _preparePdfFonts(project, ex, reports: true);
      _write(reportOut, ex.exportReport(f));
    }
    return OciExit.ok;
  }

  // ------------------------------------------------------------------ validate

  /// The repairs reading the file needed and the errors of the design check.
  Future<int> validate(Project project, _Args a) async {
    final check = runDesignCheck(project);
    final errors = check.issues.where((i) => i.severity == CheckSeverity.error).toList();
    if (a.flags.contains('json')) {
      out.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'project': project.meta.name,
          'version': report.fileVersion,
          'readsVersion': Project.formatVersion,
          'newerVersion': report.newerVersion,
          'skipped': report.skipped,
          'renumbered': report.renumbered,
          'droppedVertices': report.droppedVertices,
          'unknownValues': report.unknownValues,
          'repairs': [for (final n in report.notes) _note(n)],
          'errors': [for (final i in errors) i.toJson()],
        }),
      );
    } else {
      out.writeln('${project.meta.name}: format ${report.fileVersion ?? '-'} (this version writes ${Project.formatVersion})');
      out.writeln(report.clean ? '- nothing to repair' : '- ${report.notes.map(_note).join('\n- ')}');
      for (final i in errors) {
        out.writeln('- ${t.has('check.${i.code}') ? t('check.${i.code}') : i.code}${i.value.isEmpty ? '' : ' (${i.value})'}${i.entityIds.isEmpty ? '' : ': ${i.entityIds.take(8).join(', ')}'}');
      }
    }
    return report.clean && errors.isEmpty ? OciExit.ok : OciExit.problems;
  }

  // ------------------------------------------------------------------ check

  Future<int> check(Project project, _Args a) async {
    DesignResults? r;
    if (a.flags.contains('design') || a.flags.contains('analyze')) r = run(project, size: a.flags.contains('design'));
    final advice = buildAdvice(project, results: r);
    final count = {for (final l in AdviceLevel.values) l: advice.where((x) => x.level == l).length};
    if (a.flags.contains('json')) {
      out.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'project': project.meta.name,
          'designed': r != null,
          'errors': count[AdviceLevel.error],
          'warnings': count[AdviceLevel.warning],
          'notes': count[AdviceLevel.info],
          'messages': [
            for (final x in advice)
              {
                'level': x.level.name,
                'code': x.code,
                'raw': x.raw,
                'message': adviceText(project, x),
                if (x.context.isNotEmpty) 'context': x.context,
                if (x.entityIds.isNotEmpty) 'entities': x.entityIds,
                if (x.value.isNotEmpty) 'value': x.value,
                if (t.has('adv.${x.code}.why')) 'why': t('adv.${x.code}.why'),
                if (t.has('adv.${x.code}.how')) 'how': t('adv.${x.code}.how'),
                if (x.fixes.isNotEmpty) 'fixes': [for (final f in x.fixes) f.name],
              },
          ],
        }),
      );
    } else {
      out.writeln('${t('check.title')}: ${project.meta.name}');
      _printAdvice(project, advice, explain: true);
    }
    return count[AdviceLevel.error]! > 0 ? OciExit.problems : OciExit.ok;
  }

  /// One line for a message, as the app titles it: the zone or flow, the
  /// message, the value and the items involved.
  String adviceText(Project project, Advice x) {
    final base = t.has('check.${x.raw}') ? t('check.${x.raw}') : (t.has('warn.${x.raw}') ? t('warn.${x.raw}') : (t.has('adv.${x.code}.title') ? t('adv.${x.code}.title') : x.raw));
    final names = [
      for (final id in x.entityIds.take(3))
        if (project.byId(id) case final e?) e.name.isNotEmpty ? e.name : '${e.type.name} ${e.id}',
      if (x.entityIds.length > 3) '+${x.entityIds.length - 3}',
    ];
    final value = x.code == 'unconnected' || x.code == 'duplicate_item' ? '' : x.value;
    final extra = [if (value.isNotEmpty) value, if (names.isNotEmpty) names.join(', ')].join(' · ');
    final head = x.context.isEmpty ? base : '${x.context}: $base';
    return extra.isEmpty ? head : '$head ($extra)';
  }

  void _printAdvice(Project project, List<Advice> advice, {bool explain = false}) {
    final count = {for (final l in AdviceLevel.values) l: advice.where((x) => x.level == l).length};
    out.writeln(
      '${t('reports.messages')}: ${count[AdviceLevel.error]} ${t('adv.level.error')}, ${count[AdviceLevel.warning]} ${t('adv.level.warning')}, ${count[AdviceLevel.info]} ${t('adv.level.info')}',
    );
    for (final x in advice) {
      out.writeln('  ${x.level.name.padRight(7)} ${adviceText(project, x)}');
      if (!explain) continue;
      if (t.has('adv.${x.code}.why')) out.writeln('          ${t('adv.why')}: ${t('adv.${x.code}.why')}');
      if (t.has('adv.${x.code}.how')) out.writeln('          ${t('adv.how')}: ${t('adv.${x.code}.how')}');
    }
  }

  // ------------------------------------------------------------------ export

  Future<int> export(Project project, _Args a, String input) async {
    final name = a.values['format'];
    if (name == null) throw _UsageError('export needs --format (${DrawingFormat.values.map((f) => f.name).join(', ')})');
    final format = DrawingFormat.values.where((f) => f.name == name.toLowerCase()).firstOrNull;
    if (format == null) throw _UsageError('unknown format $name (${DrawingFormat.values.map((f) => f.name).join(', ')})');
    if (project.entities.isEmpty) throw _Failure(OciExit.failed, t('msg.nothingToExport'));
    final georef = a.values['georef'];
    if (georef != null && project.meta.georef == null) {
      final ll = parseLatLon(georef);
      if (ll == null) throw _UsageError('--georef: not a position: $georef (e.g. -22.9068,-43.1729)');
      project.meta.georef = GeoReference.fromLatLonOrigin(ll.$1, ll.$2);
    }
    if (format.needsGeoref && project.meta.georef == null) {
      throw _Failure(OciExit.failed, '${format.name} needs a georeference: pass --georef <lat,lon>, the WGS84 position of the drawing origin (0, 0)');
    }
    final r = a.flags.contains('design') || a.flags.contains('analyze') ? run(project, size: a.flags.contains('design')) : null;
    final ex = exporter(project, r);
    final sheet = SheetOptions(page: _paper(a.values['paper']), landscape: !a.flags.contains('portrait'));
    if (format == DrawingFormat.pdf) _preparePdfFonts(project, ex, reports: r != null);
    final Object data;
    try {
      data = ex.exportDrawing(format, sheet: sheet);
    } on GeoReferenceMissing {
      throw _Failure(OciExit.failed, '${format.name} needs a georeference: pass --georef <lat,lon>');
    } catch (x, st) {
      throw _Failure(OciExit.failed, '${format.name} export failed: $x\n$st');
    }
    final path = a.values['out'] ?? '${_stem(input)}.${format.extension}';
    _write(path, data);
    return OciExit.ok;
  }

  // ------------------------------------------------------------------ bom

  Future<int> bom(Project project, _Args a) async {
    final r = run(project, size: !a.flags.contains('analyze'));
    if (r == null) throw _Failure(OciExit.failed, t('msg.noValves'));
    final ex = exporter(project, r);
    final tables = ex.reportTables().where((tb) => tb.key == 'bom').toList();
    if (tables.isEmpty) throw _Failure(OciExit.failed, t('msg.needResults'));
    out.write(reportTablesToText(tables, header: ['$appName $appVersionFull · ${project.meta.name}']));
    final path = a.values['out'];
    if (path != null) {
      final f = _reportFormat(path);
      if (f == ReportFormat.pdf) _preparePdfFonts(project, ex, reports: true);
      _write(path, switch (f) {
        ReportFormat.csv => reportTablesToCsv(tables),
        ReportFormat.txt => reportTablesToText(tables, header: ['$appName · ${project.meta.name}']),
        ReportFormat.xlsx => xlsxOf(tables),
        ReportFormat.pdf => ex.sheetBuilder().buildReport(tables),
      });
    }
    return OciExit.ok;
  }

  // ------------------------------------------------------------------ output

  /// The exporter of the app for [project], [results] and the language.
  ProjectExporter exporter(Project project, DesignResults? results) {
    String entityName(String id) {
      final n = project.byId(id)?.name ?? '';
      return n.isEmpty ? id : n;
    }

    return ProjectExporter(
      project: project,
      results: results,
      unconnected: results?.unconnected ?? const {},
      layerNames: {for (final l in project.layers) l.name: t.has('layer.${l.name}') ? t('layer.${l.name}') : l.name},
      labels: ReportLabels(
        t: t.call,
        has: t.has,
        warning: (w) => t.warning(w, entityName: entityName),
        entityName: entityName,
      ),
    );
  }

  void _summary(Project project, DesignResults r, String what) {
    final u = project.params.units;
    final p = u.pressureLabel;
    out.writeln('$appName $appVersionFull · $what · ${project.meta.name}');
    final tables = <ReportTable>[
      if (r.zones.isNotEmpty)
        ReportTable(
          key: 'zones',
          title: t('reports.zone'),
          headers: [t('rep.zone'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.pRequired')} ($p)', '${t('rep.pMin')} ($p)', '${t('rep.pMax')} ($p)', 'EU %', t('rep.warnings')],
          rows: [
            for (final z in r.zones.values)
              [
                z.zoneName,
                RNum(u.flowFromSi(z.totalFlow), 1),
                RNum(u.pressureFromHead(z.requiredUpstreamHead), 1),
                RNum(u.pressureFromHead(z.minOutletPressure), 1),
                RNum(u.pressureFromHead(z.maxOutletPressure), 1),
                RNum(z.uniformity.eu, 1),
                z.warnings.length,
              ],
          ],
        ),
      if (r.systemFlows.isNotEmpty)
        ReportTable(
          key: 'flows',
          title: t('reports.mainline'),
          headers: [t('rep.flowName'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.supply')} ${t('rep.pRequired')} ($p)', t('rep.warnings')],
          rows: [
            for (final f in r.systemFlows)
              [
                f.name,
                RNum(u.flowFromSi(f.totalFlow), 1),
                f.supplies.isEmpty ? '-' : RNum(u.pressureFromHead(f.supplies.map((s) => s.requiredHead).reduce((x, y) => x > y ? x : y)), 1),
                f.warnings.length,
              ],
          ],
        ),
      if (r.pivots.isNotEmpty)
        ReportTable(
          key: 'pivots',
          title: t('reports.pivots'),
          headers: [t('rep.pivot'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.pRequired')} ($p)', t('rep.warnings')],
          rows: [
            for (final v in r.pivots.values) [v.name, RNum(u.flowFromSi(v.flow), 1), RNum(u.pressureFromHead(v.inletHead), 1), v.warnings.length],
          ],
        ),
    ];
    out.write(reportTablesToText(tables));
    out.writeln('${t('rep.total')} (${project.params.currency}): ${fmt(r.capitalCost, 2)} · ${t('reports.bom')}: ${r.bom.length}');
    _printAdvice(project, buildAdvice(project, results: r));
  }

  ReportFormat _reportFormat(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ReportFormat.values.where((f) => f.extension == ext).firstOrNull ?? (throw _UsageError('$path: a report is .csv, .txt, .xlsx or .pdf'));
  }

  PageSize _paper(String? name) {
    if (name == null) return PageSize.a3;
    return PageSize.values.where((s) => s.name == name.toLowerCase()).firstOrNull ?? (throw _UsageError('unknown paper $name (${PageSize.values.map((s) => s.name).join(', ')})'));
  }

  /// The XLSX of the app's report export, for some tables only.
  Uint8List xlsxOf(List<ReportTable> tables) => XlsxWriter.write([
    for (final tb in tables)
      XlsxSheet(
        name: tb.title,
        headers: tb.headers,
        rows: [
          for (final r in tb.rows) [for (final c in r) c is RNum ? double.parse(c.value.toStringAsFixed(c.decimals)) : c],
        ],
      ),
  ]);

  /// Registers in [PdfFonts.shared] the bundled fonts the PDF texts need
  /// (as the app does before a PDF export), read from assets/fonts.
  void _preparePdfFonts(Project project, ProjectExporter ex, {required bool reports}) {
    final fonts = PdfFonts.shared..language = lang;
    final texts = <String>[
      project.meta.name,
      project.meta.client,
      project.meta.site,
      project.meta.designer,
      project.meta.notes,
      for (final l in project.layers) l.name,
      for (final e in project.entities) ...[
        e.name,
        if (e is TextEntity) e.text,
        if (e is LeaderEntity) e.text,
        if (e is CommentEntity) ...[e.text, e.author],
        if (e is ControlValveEntity) e.zoneName,
      ],
      for (final k in const ['plot.title', 'reports.zone', 'reports.bom', 'rep.zone', 'rep.description', 'menu.mainline', 'name.report']) t(k),
      if (reports)
        for (final tb in ex.reportTables()) ...[
          tb.title,
          ...tb.headers,
          for (final row in tb.rows)
            for (final c in row)
              if (c is String) c,
        ],
    ].where((s) => s.isNotEmpty).toList();
    for (var round = 0; round < 3; round++) {
      final missing = fonts.missingFor(texts);
      if (missing.isEmpty) return;
      var loaded = false;
      for (final name in missing) {
        final f = home == null ? null : File('$home/${BundledFonts.asset(name)}');
        if (f != null && f.existsSync() && fonts.register(name, f.readAsBytesSync())) loaded = true;
      }
      if (!loaded) return;
    }
  }

  void _write(String path, Object data) {
    try {
      final f = File(path);
      if (data is Uint8List) {
        f.writeAsBytesSync(data);
      } else {
        f.writeAsStringSync(data as String);
      }
      err.writeln('oci: wrote $path (${f.lengthSync()} bytes)');
    } on FileSystemException catch (x) {
      throw _Failure(OciExit.io, '$path: cannot be written (${x.osError?.message ?? x.message})');
    }
  }

  static String _stem(String input) {
    final s = input.replaceAll(RegExp(r'\.oci\.json$|\.json$', caseSensitive: false), '');
    return s;
  }
}
