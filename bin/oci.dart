/// OpenCADIrrigation on the command line: designs, analyses, checks, exports
/// and lists the materials of `.oci.json` projects with the engine of the app
/// (lib/core), in the Dart VM, without Flutter or a browser.
///
///   dart run bin/oci.dart --help
///   dart run bin/oci.dart design examples/pt/garden.oci.json --lang pt --out designed.oci.json --report report.xlsx
///   dart run bin/oci.dart check project.oci.json && echo ok
///   dart run bin/oci.dart export project.oci.json --format dxf --out project.dxf
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
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/fonts/pdf_fonts.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
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

const _commands = ['design', 'analyze', 'check', 'export', 'bom'];
const _valueOptions = {'out', 'report', 'results', 'lang', 'format', 'georef', 'paper'};
const _flagOptions = {'design', 'analyze', 'portrait', 'json', 'help', 'version'};

const usageText = '''
Usage: dart run bin/oci.dart <command> <project.oci.json> [options]

Commands:
  design    Size the pipes and analyse the design (F5 in the app) and print a summary.
  analyze   Analyse the design as drawn, without changing any pipe size.
  check     List the problems of the project (design check and the design assistant's
            messages); exit code 1 when there is an error.
  export    Write the drawing in another format (--format, --out).
  bom       Size the design and print the bill of materials.

Options:
  --out <file>        design: the designed project (.oci.json); export: the exported file
                      (default: next to the project); bom: the bill of materials (.csv, .txt,
                      .xlsx or .pdf).
  --report <file>     design, analyze: every report table (.csv, .txt, .xlsx or .pdf).
  --results <file>    design, analyze: the design results as JSON.
  --lang <code>       language of the names, reports and messages (default en):
                      ${'{languages}'}
  --format <name>     export: dxf, dwg, pdf, svg, kml, kmz, geojson, shp (zip), gpx,
                      landxml, ifc or inp (EPANET).
  --georef <lat,lon>  export: WGS84 position of the drawing origin (0, 0) for a project
                      without a georeference (kml, kmz, geojson and gpx need one).
  --design            export, check: size and analyse first (sized pipes, results, all
                      the messages); bom sizes by default.
  --analyze           export, check, bom: analyse first, keeping the pipe sizes as drawn.
  --paper <size>      export pdf, svg: a4, a3 (default), a2, a1, a0, letter or tabloid.
  --portrait          export pdf, svg: portrait sheet (default landscape).
  --json              check: the messages as JSON.
  -h, --help          This help.
  --version           The version of the engine.

Exit codes: 0 done, 1 check found errors, 2 bad command line, 3 a file could not be
read or written, 4 the calculation or the export failed.''';

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
  if (a.positional.length != 1) {
    e.writeln('oci: $command needs one project file (.oci.json)');
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
    final project = session.readProject(a.positional.single);
    return await switch (command) {
      'design' => session.design(project, a, size: true),
      'analyze' => session.design(project, a, size: false),
      'check' => session.check(project, a),
      'export' => session.export(project, a, a.positional.single),
      'bom' => session.bom(project, a),
      _ => OciExit.usage,
    };
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

  Project readProject(String path) {
    final f = File(path);
    if (!f.existsSync()) throw _Failure(OciExit.io, '$path: no such file');
    try {
      return Project.fromJsonString(f.readAsStringSync());
    } on FormatException catch (x) {
      throw _Failure(OciExit.io, '$path: not an OpenCADIrrigation project (${x.message})');
    } catch (x) {
      throw _Failure(OciExit.io, '$path: cannot be read ($x)');
    }
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
      _write(projectOut, project.toJsonString(pretty: true));
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

  // ------------------------------------------------------------------ check

  Future<int> check(Project project, _Args a) async {
    DesignResults? r;
    if (a.flags.contains('design') || a.flags.contains('analyze')) r = run(project, size: a.flags.contains('design'));
    final advice = buildAdvice(project, results: r);
    final count = {for (final l in AdviceLevel.values) l: advice.where((x) => x.level == l).length};
    if (a.flags.contains('json')) {
      out.writeln(const JsonEncoder.withIndent('  ').convert({
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
      }));
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
    out.writeln('${t('reports.messages')}: ${count[AdviceLevel.error]} ${t('adv.level.error')}, ${count[AdviceLevel.warning]} ${t('adv.level.warning')}, ${count[AdviceLevel.info]} ${t('adv.level.info')}');
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
      labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w, entityName: entityName), entityName: entityName),
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
              [z.zoneName, RNum(u.flowFromSi(z.totalFlow), 1), RNum(u.pressureFromHead(z.requiredUpstreamHead), 1), RNum(u.pressureFromHead(z.minOutletPressure), 1), RNum(u.pressureFromHead(z.maxOutletPressure), 1), RNum(z.uniformity.eu, 1), z.warnings.length],
          ],
        ),
      if (r.systemFlows.isNotEmpty)
        ReportTable(
          key: 'flows',
          title: t('reports.mainline'),
          headers: [t('rep.flowName'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.supply')} ${t('rep.pRequired')} ($p)', t('rep.warnings')],
          rows: [
            for (final f in r.systemFlows)
              [f.name, RNum(u.flowFromSi(f.totalFlow), 1), f.supplies.isEmpty ? '-' : RNum(u.pressureFromHead(f.supplies.map((s) => s.requiredHead).reduce((x, y) => x > y ? x : y)), 1), f.warnings.length],
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
      XlsxSheet(name: tb.title, headers: tb.headers, rows: [
        for (final r in tb.rows) [for (final c in r) c is RNum ? double.parse(c.value.toStringAsFixed(c.decimals)) : c],
      ]),
  ]);

  /// Registers in [PdfFonts.shared] the bundled fonts the PDF texts need
  /// (as the app does before a PDF export), read from assets/fonts.
  void _preparePdfFonts(Project project, ProjectExporter ex, {required bool reports}) {
    final fonts = PdfFonts.shared..language = lang;
    final texts = <String>[
      project.meta.name, project.meta.client, project.meta.site, project.meta.designer, project.meta.notes,
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
        for (final tb in ex.reportTables()) ...[tb.title, ...tb.headers, for (final row in tb.rows) for (final c in row) if (c is String) c],
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
