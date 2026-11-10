/// The tools, resources and prompts of the OpenCADIrrigation MCP server
/// (`dart run bin/oci.dart mcp --root <folder>`, docs/MCP.md): what the
/// command line does (bin/oci.dart: new, import, set, pack add, design,
/// analyze, check, validate, export, bom, schema), plus reading a project's
/// contents, its catalogue and its report tables, editing its items and
/// copying the shipped examples, for any AI application that speaks the
/// Model Context Protocol.
///
/// The tools do not reach the files or the command line themselves: an
/// [OciMcpHost] does (bin/oci.dart provides it), which keeps every path
/// inside the root folder and runs the command line's own functions, so no
/// engine logic is repeated here and this library stays pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../design/advisor.dart';
import '../design/report_tables.dart';
import '../design/results.dart';
import '../hydraulics/friction.dart';
import '../io/drawing_import.dart' show drawingImportExtensions;
import '../io/pdf_sheet.dart' show PageSize;
import '../io/project_export.dart';
import '../model/default_layers.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/read_report.dart';
import '../model/schema.dart';
import '../model/terrain.dart' show TerrainMethod;
import '../units.dart';
import 'mcp_server.dart';

/// A file or folder under the root, its path already checked.
class McpFile {
  const McpFile({required this.path, required this.absolute, required this.exists, this.isDirectory = false, this.size = 0, this.modified});

  /// Relative to the root, with `/` between folders (`''` is the root).
  final String path;

  /// The absolute path, symbolic links resolved: what the command line is
  /// given.
  final String absolute;
  final bool exists;
  final bool isDirectory;

  /// Bytes (0 for a folder or a file not there yet).
  final int size;
  final DateTime? modified;
}

/// What one command of the command line printed.
class OciRun {
  const OciRun(this.code, this.out, this.err);

  /// Its exit code (0 done, 1 problems found, 2 bad command line, 3 a file,
  /// 4 the calculation or the export).
  final int code;
  final String out;
  final String err;
}

/// What the tools need from the machine. bin/oci.dart implements it with
/// the command line's own functions and a root folder that confines every
/// path (symbolic links resolved, no `..`, no absolute path outside it).
/// Its methods throw [McpToolError] with a message for the model.
abstract interface class OciMcpHost {
  /// The language of names, reports and messages.
  String get lang;

  /// The languages the examples and messages come in.
  List<String> get languages;

  /// The root folder (absolute, symbolic links resolved).
  String get rootPath;

  /// Loads what the language needs (once per isolate).
  Future<void> prepare();

  /// [path] (relative to the root, or absolute inside it) as a file under
  /// the root.
  McpFile resolve(String path);

  /// The files under [folder] (hidden ones left out), at most [limit].
  List<McpFile> list(McpFile folder, {required bool recursive, required int limit});

  /// The bytes of [file], refused above [maxBytes].
  Uint8List read(McpFile file, {required int maxBytes});

  /// Writes [file] whole (through a temporary file renamed over it),
  /// making its folders.
  void write(McpFile file, List<int> bytes);

  /// Makes the folders of [file] (for what the command line writes) and
  /// gives it checked again.
  McpFile makeFolders(McpFile file);

  /// A file of the program's own folder (`examples/…`, `catalogs/…`); null
  /// when it is not there.
  Uint8List? asset(String relative);

  /// The absolute path of a file of the program's own folder, or null.
  String? assetPath(String relative);

  /// Runs a command of the command line (absolute paths; `--lang` is
  /// added) with its output captured.
  Future<OciRun> run(List<String> args);

  /// Reads a project as the command line does; the repairs it needed as
  /// sentences.
  (Project, List<String>) readProject(McpFile file);

  /// The command line's --units, --currency, --hz, --name and --georef on
  /// [project]; what it had to say (a currency without a reference rate).
  List<String> settings(Project project, {String? units, String? currency, String? hz, String? name, String? georef});

  /// Sizes ([size]) and analyses [project] in place as the command line
  /// does; null when there is nothing to design.
  DesignResults? design(Project project, {required bool size});

  /// The command line's exporter (report tables, drawings) in the language.
  ProjectExporter exporter(Project project, DesignResults? results);

  /// One line for a message of the design assistant, as the command line
  /// writes it.
  String adviceText(Project project, Advice advice);

  /// The summary tables the command line prints after a design.
  List<ReportTable> summaryTables(Project project, DesignResults results);

  /// A text of the string table.
  String text(String key, [Map<String, String>? args]);
  bool hasText(String key);
}

/// Limits of the tools (docs/MCP.md, "Limits").
abstract final class OciMcpLimits {
  /// The largest file a tool reads (a project, a drawing, a survey, a pack).
  static const maxFileBytes = 256 * 1024 * 1024;

  /// Rows of a table or items of a list in one answer.
  static const maxRows = 1000;
  static const defaultRows = 100;

  /// Items in full (their project-file JSON) in one answer.
  static const maxFullItems = 200;

  /// Files list_files names in one answer.
  static const maxFiles = 2000;

  /// Changes edit_entities takes in one call.
  static const maxEdits = 5000;

  /// Files import_files and packs add_catalog_pack take in one call.
  static const maxInputs = 50;

  /// Messages a design summary lists (check_project lists them all).
  static const summaryMessages = 60;
}

/// The examples that ship with the program (`examples/<language>/<id>.oci.json`).
const ociExampleIds = ['orchard', 'garden', 'sportsField', 'rowCrop', 'pivot', 'greenhouse', 'nursery', 'coffee', 'bananas', 'sugarcane', 'gravity', 'pasture', 'golf', 'sectorPivot', 'linear'];

/// The kinds of catalogue item list_catalog lists.
const ociCatalogKinds = ['pipes', 'outlets', 'tapes', 'valves', 'pumps', 'fittings', 'wires'];

/// The parts of the project schema project_schema gives.
List<String> get ociSchemaParts => [
  'overview',
  'full',
  'meta',
  'params',
  'layers',
  'systemFlows',
  'catalog',
  for (final k in ociCatalogKinds) 'catalog.$k',
  for (final t in EntityType.values) 'entity.${t.name}',
];

// ------------------------------------------------------------------ schema pieces

const _pathMax = 1024;

Map<String, Object?> _object(Map<String, Object?> properties, {List<String> required = const []}) => {
  'type': 'object',
  'properties': properties,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};

Map<String, Object?> _text(String description, {int max = _pathMax, String? pattern}) => {'type': 'string', 'minLength': 1, 'maxLength': max, 'pattern': ?pattern, 'description': description};

Map<String, Object?> _choice(List<Object> values, String description) => {'enum': values, 'description': description};

Map<String, Object?> _flag(String description) => {'type': 'boolean', 'description': description};

Map<String, Object?> _whole(String description, {int min = 0, int? max}) => {'type': 'integer', 'minimum': min, 'maximum': ?max, 'description': description};

final _project = _text('Path of the project file (.oci.json), relative to the root folder of the server, e.g. "field.oci.json" or "farm/block-a.oci.json".');

Map<String, Object?> _out(String what) => _text('Where to write $what, relative to the root (default: next to the project, named after it).');

final _projectOut = _text('Where to save the changed project (.oci.json), relative to the root; default: over the project file itself.');

final _georef = {
  'type': 'object',
  'description': 'WGS84 position of the drawing origin (0, 0): the drawing is then in metres on the UTM zone of that point, and the map formats (KML, GeoJSON, GPX) and base maps can place it.',
  'properties': {
    'lat': {'type': 'number', 'minimum': -90, 'maximum': 90, 'description': 'latitude in decimal degrees, north positive'},
    'lon': {'type': 'number', 'minimum': -180, 'maximum': 180, 'description': 'longitude in decimal degrees, east positive'},
  },
  'required': ['lat', 'lon'],
  'additionalProperties': false,
};

final _settings = <String, Object?>{
  'name': _text('Name of the project.', max: 200),
  'units': _choice(const ['metric', 'us'], 'Display units of the reports: metric (m, m³/h, bar or kPa, mm) or us (ft, gpm, psi, in). The file itself is always SI.'),
  'currency': _text('ISO 4217 code of the prices (BRL, USD, EUR, INR…); the catalogue prices are converted at reference rates.', max: 3, pattern: r'^[A-Za-z]{3}$'),
  'mains_hz': _choice(const [50, 60], 'Frequency of the electricity mains (Hz), for the speed of the pumps.'),
  'georef': _georef,
};

final _offset = _whole('Skip this many rows (paging; default 0).');
final _limit = _whole('Rows at most (default ${OciMcpLimits.defaultRows}).', min: 1, max: OciMcpLimits.maxRows);
final _sizePipes = _flag('Size the pipes the design may choose before (default true); false keeps the sizes drawn.');

const _table = {
  'type': 'object',
  'description': 'a table: title, column headers (with their units) and rows of values',
  'properties': {
    'title': {'type': 'string'},
    'headers': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'rows': {
      'type': 'array',
      'items': {'type': 'array'},
    },
  },
};

const _messagesSchema = {
  'type': 'object',
  'description': 'messages of the design assistant: counts by level and the first ones',
  'properties': {
    'errors': {'type': 'integer'},
    'warnings': {'type': 'integer'},
    'notes': {'type': 'integer'},
    'list': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'level': {'type': 'string'},
          'code': {'type': 'string'},
          'message': {'type': 'string'},
          'entities': {'type': 'array'},
        },
      },
    },
    'more': {'type': 'integer', 'description': 'messages left out of the list (check_project lists them all)'},
  },
};

const _summarySchema = {
  'type': 'object',
  'properties': {
    'project': {'type': 'string'},
    'name': {'type': 'string'},
    'sized': {'type': 'boolean', 'description': 'the pipes were sized'},
    'saved': {'type': 'string', 'description': 'where the designed project was written'},
    'tables': {
      'type': 'object',
      'description': 'zones, flows (the mainline of each system flow) and pivots, as tables',
      'properties': {'zones': _table, 'flows': _table, 'pivots': _table},
    },
    'totals': {
      'type': 'object',
      'properties': {
        'capitalCost': {'type': 'number'},
        'currency': {'type': 'string'},
        'bomLines': {'type': 'integer'},
      },
    },
    'messages': _messagesSchema,
  },
  'required': ['project', 'name', 'sized', 'tables', 'totals', 'messages'],
};

const _projectSummarySchema = {
  'type': 'object',
  'properties': {
    'project': {'type': 'string'},
    'name': {'type': 'string'},
    'units': {'type': 'object'},
    'currency': {'type': 'string'},
    'mainsHz': {'type': 'number'},
    'georef': {
      'type': ['object', 'null'],
    },
    'bounds': {
      'type': ['object', 'null'],
    },
    'entities': {'type': 'object'},
    'zones': {'type': 'array'},
    'supplies': {'type': 'array'},
    'pivots': {'type': 'array'},
    'systemFlows': {'type': 'array'},
    'layers': {'type': 'array', 'description': 'the layers that hold items'},
    'layerCount': {'type': 'integer', 'description': 'all the layers, empty ones too'},
    'catalog': {'type': 'object'},
    'repairs': {'type': 'array'},
    'parameters': {'type': 'object'},
    'log': {'type': 'array', 'description': 'what the writing tool did'},
  },
  'required': ['project', 'name', 'units', 'currency', 'entities'],
};

const _writtenSchema = {
  'type': 'object',
  'properties': {
    'written': {'type': 'string', 'description': 'path of the file written, relative to the root'},
    'bytes': {'type': 'integer'},
    'format': {'type': 'string'},
  },
  'required': ['written', 'bytes', 'format'],
};

// ------------------------------------------------------------------ the toolset

/// The MCP tools of OpenCADIrrigation over [host]; [readOnly] leaves out
/// every tool that writes a file.
class OciMcpTools {
  OciMcpTools(this.host, {this.readOnly = false});
  final OciMcpHost host;
  final bool readOnly;

  /// Guidance for the model (initialize and discover).
  String get instructions => [
    'OpenCADIrrigation designs pressurised irrigation systems (sprinklers, sprays and rotors, drip and micro-irrigation, centre pivots and linear moves) on this computer: hydraulic analysis, pipe sizing, bill of materials, drawings and reports.',
    'Every file is under one root folder: give paths relative to it ("field.oci.json", "plans/site.dxf"). Projects are .oci.json files.',
    if (!readOnly) 'A session: list_files → copy_example, create_project or import_files → read_project, list_entities, list_catalog → edit_entities or set_project → design_project → check_project → bill_of_materials, report_table → export_drawing, export_report.',
    if (readOnly) 'This server is read-only: it reads, analyses, checks and reports on the projects of the root folder and writes nothing.',
    'Inside a project file everything is SI: coordinates and lengths in metres, elevations in metres, flows in m³/s, pressures as heads in metres of water, diameters in mm where the key says so. Result tables use the project\'s display units, stated in their headers.',
    'Messages and names come in the server\'s language (${host.lang}). No tool reaches the internet.',
  ].join('\n');

  /// The tools, in a fixed order (reading first).
  List<McpTool> get tools => [
    _listFiles(),
    _readProject(),
    _listEntities(),
    _listCatalog(),
    _analyze(),
    _check(),
    _validate(),
    _bom(),
    _reportTable(),
    _schema(),
    _listExamples(),
    _listPacks(),
    if (!readOnly) ...[_create(), _copyExample(), _import(), _set(), _edit(), _addPack(), _design(), _exportDrawing(), _exportReport()],
  ];

  McpTool _tool(
    String name,
    String title,
    String description,
    Map<String, Object?> input,
    McpToolAnnotations annotations,
    Future<Object?> Function(Map<String, Object?> a) body, {
    Map<String, Object?>? output,
  }) => McpTool(
    name: name,
    title: title,
    description: description,
    inputSchema: input,
    outputSchema: output,
    annotations: annotations,
    call: (a) async {
      await host.prepare();
      try {
        return McpToolResult.ok(await body(a));
      } on McpToolError catch (e) {
        return McpToolResult.error(_rel(e.message));
      }
    },
  );

  static const _write = McpToolAnnotations(readOnly: false, destructive: true, idempotent: true);

  // ------------------------------------------------------------------ helpers

  /// [s] with the root folder left out of its paths.
  String _rel(String s) => s.replaceAll('${host.rootPath}/', '').replaceAll(host.rootPath, '.');

  static String? _str(Map<String, Object?> a, String k) => a[k] as String?;
  static bool _bool(Map<String, Object?> a, String k, bool def) => a[k] as bool? ?? def;
  static int _int(Map<String, Object?> a, String k, int def) => (a[k] as num?)?.toInt() ?? def;

  /// An existing file to read, at most [OciMcpLimits.maxFileBytes].
  McpFile _input(String path, {String what = 'file'}) {
    final f = host.resolve(path);
    if (!f.exists) throw McpToolError('$path: no such $what under the root (list_files names what there is)');
    if (f.isDirectory) throw McpToolError('$path is a folder, not a $what');
    if (f.size > OciMcpLimits.maxFileBytes) throw McpToolError('$path: ${_mb(f.size)}, above the ${_mb(OciMcpLimits.maxFileBytes)} a tool reads');
    return f;
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 10 * 1024 * 1024 ? 1 : 0)} MB';

  /// A file to write: one of [extensions], not a folder, not replacing an
  /// existing file unless [overwrite] (or it is [same], the project itself).
  McpFile _target(String path, List<String> extensions, {bool overwrite = false, McpFile? same}) {
    final f = host.resolve(path);
    if (f.isDirectory) throw McpToolError('$path is a folder: give a file name');
    if (same != null && f.absolute == same.absolute) return f;
    final lower = f.path.toLowerCase();
    if (!extensions.any((e) => lower.endsWith(e))) throw McpToolError('$path: this tool writes ${extensions.join(' or ')} files only');
    if (f.exists && !overwrite) throw McpToolError('$path exists already: choose another name${extensions.contains('.oci.json') ? '' : ' or pass overwrite: true'}');
    return host.makeFolders(f);
  }

  (Project, List<String>, McpFile) _open(Map<String, Object?> a) {
    final f = _input(_str(a, 'project')!, what: 'project');
    final (p, repairs) = host.readProject(f);
    return (p, repairs, f);
  }

  /// The path of [project] without `.oci.json` (or `.json`).
  static String _stem(String path) => path.replaceFirst(RegExp(r'\.oci\.json$|\.json$', caseSensitive: false), '');

  void _save(McpFile f, Project p, {DesignResults? results}) {
    final j = p.toJson();
    if (results != null) j['results'] = results.toJson();
    host.write(f, utf8.encode(encodeJson(j, pretty: true)));
  }

  Future<OciRun> _cli(List<String> args, {Set<int> ok = const {0}}) async {
    final r = await host.run(args);
    if (!ok.contains(r.code)) {
      final lines = [
        for (final l in const LineSplitter().convert(r.err))
          if (l.trim().isNotEmpty && !l.contains(': wrote ')) l.replaceFirst(RegExp(r'^oci: '), ''),
      ];
      throw McpToolError(lines.isEmpty ? 'the command line stopped (exit code ${r.code})' : lines.take(12).join('\n'));
    }
    return r;
  }

  /// The warnings the command line wrote (not its "wrote" lines).
  List<String> _notes(OciRun r) => [
    for (final l in const LineSplitter().convert(r.err))
      if (l.trim().isNotEmpty && !l.contains(': wrote ')) _rel(l.replaceFirst(RegExp(r'^oci: '), '')),
  ];

  static Object? _cell(Object? c) => switch (c) {
    RNum n => !n.value.isFinite ? null : (n.decimals <= 0 ? n.value.round() : double.parse(n.value.toStringAsFixed(n.decimals.clamp(0, 12)))),
    RBar b => '${b.start}-${b.end}/${b.total}',
    double d => d.isFinite ? d : null,
    num x => x,
    String s => s,
    null => null,
    _ => '$c',
  };

  static List<List<Object?>> _rows(ReportTable t, {int offset = 0, int? limit}) => [
    for (final r in t.rows.skip(offset).take(limit ?? t.rows.length)) [for (final c in r) _cell(c)],
  ];

  static Map<String, Object?> _tableJson(ReportTable t) => {'title': t.title, 'headers': t.headers, 'rows': _rows(t)};

  static bool _same(Units a, Units b) => a.length == b.length && a.flow == b.flow && a.pressure == b.pressure && a.diameter == b.diameter;

  static double _round(double v, [int d = 3]) => v.isFinite ? double.parse(v.toStringAsFixed(d)) : 0;

  Map<String, Object?> _messages(Project p, List<Advice> advice, {int limit = OciMcpLimits.summaryMessages}) => {
    'errors': advice.where((x) => x.level == AdviceLevel.error).length,
    'warnings': advice.where((x) => x.level == AdviceLevel.warning).length,
    'notes': advice.where((x) => x.level == AdviceLevel.info).length,
    'list': [
      for (final x in advice.take(limit)) {'level': x.level.name, 'code': x.code, 'message': host.adviceText(p, x), if (x.entityIds.isNotEmpty) 'entities': x.entityIds.take(20).toList()},
    ],
    if (advice.length > limit) 'more': advice.length - limit,
  };

  Map<String, Object?> _summary(McpFile f, Project p, DesignResults r, {required bool sized, String? saved}) => {
    'project': f.path,
    'name': p.meta.name,
    'sized': sized,
    'saved': ?saved,
    'tables': {for (final t in host.summaryTables(p, r)) t.key: _tableJson(t)},
    'totals': {'capitalCost': _round(r.capitalCost, 2), 'currency': p.params.currencyCode, 'bomLines': r.bom.length},
    'messages': _messages(p, buildAdvice(p, results: r)),
  };

  DesignResults _designed(Project p, {required bool size}) => host.design(p, size: size) ?? (throw McpToolError(host.text('msg.noValves')));

  Map<String, Object?> _projectSummary(McpFile f, Project p, List<String> repairs, {bool parameters = false}) {
    final u = p.params.units;
    final counts = <String, int>{};
    var bounds = Bounds.empty;
    for (final e in p.entities) {
      counts[e.type.name] = (counts[e.type.name] ?? 0) + 1;
      final b = e.bounds;
      if (!b.isEmpty && b.minX.isFinite && b.maxX.isFinite) bounds = bounds.union(b);
    }
    final g = p.meta.georef;
    final origin = g?.toLatLon(0, 0);
    final cat = p.catalog;
    String nameOf(Entity e) => e.name.isNotEmpty ? e.name : '${e.type.name} ${e.id}';
    return {
      'project': f.path,
      'name': p.meta.name,
      if (p.meta.client.isNotEmpty) 'client': p.meta.client,
      if (p.meta.site.isNotEmpty) 'site': p.meta.site,
      if (p.meta.designer.isNotEmpty) 'designer': p.meta.designer,
      if (p.meta.notes.isNotEmpty) 'notes': p.meta.notes,
      'units': {
        'system': _same(u, Units.metric) ? 'metric' : (_same(u, Units.us) ? 'us' : 'custom'),
        'length': u.lengthLabel,
        'flow': u.flowLabel,
        'pressure': u.pressureLabel,
        'diameter': u.diameterLabel,
      },
      'currency': p.params.currencyCode,
      'mainsHz': p.params.mainsHz,
      'georef': g == null || origin == null
          ? null
          : {
              'crs': g.crsName,
              'epsg': g.epsg,
              'origin': {'lat': _round(origin.$1, 7), 'lon': _round(origin.$2, 7)},
            },
      'bounds': bounds.isEmpty ? null : {'minX': _round(bounds.minX), 'minY': _round(bounds.minY), 'maxX': _round(bounds.maxX), 'maxY': _round(bounds.maxY)},
      'entities': {'total': p.entities.length, 'byType': counts},
      'zones': [
        for (final v in p.entities.whereType<ControlValveEntity>()) {'id': v.id, 'zone': v.zoneName},
      ],
      'supplies': [
        for (final s in p.entities.whereType<WaterSupplyEntity>()) {'id': s.id, 'name': nameOf(s)},
      ],
      'pivots': [
        for (final s in p.entities.whereType<PivotEntity>()) {'id': s.id, 'name': nameOf(s)},
      ],
      'systemFlows': [
        for (final s in p.systemFlows) {'id': s.id, 'name': s.name, 'runs': s.valveIds.toList()},
      ],
      // the layers that hold items (a new project has some thirty, empty)
      'layers': [
        for (final l in p.layers)
          if (p.entities.any((e) => e.layer == l.name)) l.name,
      ],
      'layerCount': p.layers.length,
      'catalog': {
        'pipes': cat.pipes.length,
        'outlets': cat.outlets.length,
        'tapes': cat.tapes.length,
        'valves': cat.valves.length,
        'pumps': cat.pumps.length,
        'fittings': cat.fittings.length,
        'wires': cat.wires.length,
      },
      'repairs': repairs.map(_rel).toList(),
      if (parameters) 'parameters': p.params.toJson(),
    };
  }

  // ------------------------------------------------------------------ reading tools

  static const _kinds = ['all', 'projects', 'importable', 'catalogue_packs', 'other'];

  static String _kindOf(String path) {
    final l = path.toLowerCase();
    if (l.endsWith('.oci.json')) return 'project';
    if (l.endsWith('.oci.cat')) return 'catalogue_pack';
    if (drawingImportExtensions.any(l.endsWith)) return 'importable';
    return 'other';
  }

  McpTool _listFiles() => _tool(
    'list_files',
    'List files',
    'List the files under the root folder of this server, or under one of its folders: projects (.oci.json), drawings, maps and surveys import_files can read (DXF, DWG, DGN, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML, EPANET .inp, LAS, GeoTIFF, CSV), catalogue packs (.oci.cat) and everything else, with their size in bytes. Every path of every tool is relative to this root. Hidden files (names starting with a dot) are left out.',
    _object({
      'folder': _text('A folder under the root (default: the root itself).'),
      'recursive': _flag('Look into the folders inside too (default true).'),
      'kind': _choice(_kinds, 'Only files of this kind (default all).'),
    }),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'folder': {'type': 'string'},
        'files': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
              'kind': {'type': 'string'},
              'bytes': {'type': 'integer'},
            },
          },
        },
        'truncated': {'type': 'boolean'},
      },
      'required': ['folder', 'files', 'truncated'],
    },
    (a) async {
      final folder = host.resolve(_str(a, 'folder') ?? '.');
      if (!folder.exists || !folder.isDirectory) throw McpToolError('${_str(a, 'folder')}: no such folder under the root');
      final kind = _str(a, 'kind') ?? 'all';
      final all = host.list(folder, recursive: _bool(a, 'recursive', true), limit: OciMcpLimits.maxFiles + 1);
      final want = switch (kind) {
        'projects' => 'project',
        'importable' => 'importable',
        'catalogue_packs' => 'catalogue_pack',
        'other' => 'other',
        _ => null,
      };
      final files = [
        for (final f in all.take(OciMcpLimits.maxFiles))
          if (!f.isDirectory && (want == null || _kindOf(f.path) == want)) {'path': f.path, 'kind': _kindOf(f.path), 'bytes': f.size},
      ];
      return {'folder': folder.path.isEmpty ? '.' : folder.path, 'files': files, 'truncated': all.length > OciMcpLimits.maxFiles};
    },
  );

  McpTool _readProject() => _tool(
    'read_project',
    'Read a project',
    'Read a project file (.oci.json): its name and details, display units, currency, mains frequency, georeference, the extent of the drawing (metres), how many items of each type it holds, its zones (control valves and their zone names), water supplies, pivots, system flows (zones that run together), layers, the size of its catalogue and what reading the file had to repair. With parameters: true, also the design parameters as the file stores them (SI units; project_schema part "params" explains every key).',
    _object({'project': _project, 'parameters': _flag('Also give the design parameters (default false).')}, required: ['project']),
    const McpToolAnnotations.reading(),
    output: _projectSummarySchema,
    (a) async {
      final (p, repairs, f) = _open(a);
      return _projectSummary(f, p, repairs, parameters: _bool(a, 'parameters', false));
    },
  );

  static const _columns = ['id', 'type', 'name', 'layer', 'spec', 'x', 'y', 'length_m', 'area_m2', 'zone'];

  List<Object?> _entityRow(Entity e) {
    final j = e.toJson();
    Object? first(Object? v) => v is List && v.isNotEmpty ? (v.first is List ? v.first : v) : null;
    final at = first(j['p'] ?? j['c'] ?? j['a'] ?? j['pts']);
    final xy = at is List && at.length >= 2 && at[0] is num && at[1] is num ? [_round((at[0] as num).toDouble()), _round((at[1] as num).toDouble())] : [null, null];
    final pts = e.linearPoints;
    return [
      e.id,
      e.type.name,
      e.name,
      e.layer,
      j['spec'] ?? j['outlet'],
      xy[0],
      xy[1],
      pts != null && pts.length > 1 ? _round(polylineLength(pts), 2) : null,
      e is AreaEntity ? _round(e.area, 1) : null,
      e is ControlValveEntity ? e.zoneName : null,
    ];
  }

  McpTool _listEntities() => _tool(
    'list_entities',
    'List the items of a project',
    'List the items (entities) of a project, filtered by type, layer or id, a page at a time, as a table: id, type, name, layer, the catalogue item it uses (spec), its position x, y (metres, drawing coordinates: the first point of a line), length (lines, pipes, tapes) or area (irrigated areas) and the zone of a control valve. With full: true, each item instead exactly as the project file stores it (project_schema part "entity.<type>" explains the keys), ready to change with edit_entities.',
    _object(
      {
        'project': _project,
        'types': {
          'type': 'array',
          'items': _choice([for (final t in EntityType.values) t.name], 'an item type'),
          'description': 'Only these types (e.g. ["pipe", "outlet", "controlValve"]).',
        },
        'layer': _text('Only items on this layer.', max: 200),
        'ids': {
          'type': 'array',
          'items': {'type': 'string', 'minLength': 1, 'maxLength': 100},
          'maxItems': OciMcpLimits.maxRows,
          'description': 'Only these ids.',
        },
        'full': _flag('Each item as the project file stores it (at most ${OciMcpLimits.maxFullItems} a page; default false).'),
        'offset': _offset,
        'limit': _limit,
      },
      required: ['project'],
    ),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'total': {'type': 'integer', 'description': 'items that match'},
        'offset': {'type': 'integer'},
        'columns': {'type': 'array'},
        'rows': {'type': 'array'},
        'entities': {'type': 'array'},
      },
      'required': ['total', 'offset'],
    },
    (a) async {
      final (p, _, _) = _open(a);
      final types = (a['types'] as List?)?.cast<String>().toSet();
      final layer = _str(a, 'layer');
      final ids = (a['ids'] as List?)?.cast<String>().toSet();
      final matching = [
        for (final e in p.entities)
          if ((types == null || types.contains(e.type.name)) && (layer == null || e.layer == layer) && (ids == null || ids.contains(e.id))) e,
      ];
      final full = _bool(a, 'full', false);
      final offset = _int(a, 'offset', 0);
      final limit = _int(a, 'limit', OciMcpLimits.defaultRows).clamp(1, full ? OciMcpLimits.maxFullItems : OciMcpLimits.maxRows);
      final page = matching.skip(offset).take(limit);
      return {
        'total': matching.length,
        'offset': offset,
        if (full) 'entities': [for (final e in page) e.toJson()],
        if (!full) 'columns': _columns,
        if (!full) 'rows': [for (final e in page) _entityRow(e)],
      };
    },
  );

  McpTool _listCatalog() => _tool(
    'list_catalog',
    'List a project\'s catalogue',
    'List the components of a project\'s catalogue, one kind at a time: pipes, outlets (emitters: sprinklers, sprays, rotors, micro-sprinklers, drippers, each with its nozzles), tapes (drip tapes and driplines), valves (and devices: filters, meters, pressure regulators…), pumps, fittings or wires. The items of the drawing name them by id: a pipe\'s "spec", an outlet\'s "outlet" and "nozzle", a tape\'s "spec"; create_project\'s outlet takes an emitter id. Sizes are in mm, pressures in metres of water (m), flows in m³/s and prices in the project\'s currency, as the project file stores them.',
    _object(
      {
        'project': _project,
        'kind': _choice(ociCatalogKinds, 'Which kind of component.'),
        'search': _text('Only items whose id or name contains this text (any case).', max: 200),
        'enabled_only': _flag('Only the items the design may choose (default false).'),
        'offset': _offset,
        'limit': _limit,
      },
      required: ['project', 'kind'],
    ),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'kind': {'type': 'string'},
        'currency': {'type': 'string'},
        'total': {'type': 'integer'},
        'items': {'type': 'array'},
      },
      'required': ['kind', 'currency', 'total', 'items'],
    },
    (a) async {
      final (p, _, _) = _open(a);
      final c = p.catalog;
      final kind = _str(a, 'kind')!;
      final List<Map<String, dynamic>> all = switch (kind) {
        'pipes' => [for (final x in c.pipes) x.toJson()],
        'outlets' => [
          for (final x in c.outlets)
            {
              ...x.toJson(),
              'nozzles': [
                for (final n in x.nozzles) {'id': n.id, 'name': n.name},
              ],
            },
        ],
        'tapes' => [for (final x in c.tapes) x.toJson()],
        'valves' => [for (final x in c.valves) x.toJson()],
        'pumps' => [for (final x in c.pumps) x.toJson()],
        'fittings' => [for (final x in c.fittings) x.toJson()],
        _ => [for (final x in c.wires) x.toJson()],
      };
      final q = _str(a, 'search')?.toLowerCase();
      final enabledOnly = _bool(a, 'enabled_only', false);
      final items = [
        for (final j in all)
          if ((q == null || '${j['id']}'.toLowerCase().contains(q) || '${j['name']}'.toLowerCase().contains(q)) && (!enabledOnly || j['enabled'] != false)) j,
      ];
      final offset = _int(a, 'offset', 0), limit = _int(a, 'limit', OciMcpLimits.defaultRows);
      return {'kind': kind, 'currency': p.params.currencyCode, 'total': items.length, 'items': items.skip(offset).take(limit).toList()};
    },
  );

  McpTool _analyze() => _tool(
    'analyze_project',
    'Analyse a project',
    'Run the hydraulic analysis of a project without changing its file: flow, required pressure, lowest and highest emitter pressure and emission uniformity (EU %) of every zone, the flow and supply pressure of every system flow (mainline), the pivots, the capital cost and the messages of the design assistant (errors, warnings, notes, with their codes). By default the pipes keep the sizes drawn; size_pipes: true sizes them first, as design_project does, without saving anything.',
    _object({'project': _project, 'size_pipes': _flag('Size the pipes first (default false).')}, required: ['project']),
    const McpToolAnnotations.reading(),
    output: _summarySchema,
    (a) async {
      final (p, _, f) = _open(a);
      final size = _bool(a, 'size_pipes', false);
      return _summary(f, p, _designed(p, size: size), sized: size);
    },
  );

  McpTool _check() => _tool(
    'check_project',
    'Check a project',
    'List the problems of a project, as the command line\'s check does: the design check (unconnected items, catalogue items that are missing, settings that cannot work…) and the messages of the design assistant, each with its level (error, warning or info), code, text, the items involved (ids) and, with explain, why it matters, how to fix it and which automatic corrections apply. run: "design" (default) sizes and analyses first, in memory, to give every message; "analyze" analyses the sizes drawn; "none" checks the drawing only. Nothing is saved.',
    _object(
      {
        'project': _project,
        'run': _choice(const ['design', 'analyze', 'none'], 'What to calculate first (default design).'),
        'explain': _flag('Add why and how to each message (default true).'),
      },
      required: ['project'],
    ),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'project': {'type': 'string'},
        'designed': {'type': 'boolean'},
        'errors': {'type': 'integer'},
        'warnings': {'type': 'integer'},
        'notes': {'type': 'integer'},
        'messages': {'type': 'array'},
      },
      'required': ['project', 'designed', 'errors', 'warnings', 'notes', 'messages'],
    },
    (a) async {
      final f = _input(_str(a, 'project')!, what: 'project');
      final run = _str(a, 'run') ?? 'design';
      final r = await _cli(['check', f.absolute, '--json', if (run == 'design') '--design', if (run == 'analyze') '--analyze'], ok: const {0, 1});
      final j = jsonDecode(r.out) as Map<String, dynamic>;
      final explain = _bool(a, 'explain', true);
      return {
        ...j,
        'name': j['project'],
        'project': f.path,
        'messages': [
          for (final m in (j['messages'] as List).cast<Map<String, dynamic>>())
            {
              for (final e in m.entries)
                if (explain || (e.key != 'why' && e.key != 'how')) e.key: e.value,
            },
        ],
      };
    },
  );

  McpTool _validate() => _tool(
    'validate_project',
    'Validate a project file',
    'Read a project file item by item, as the command line\'s validate does, and report what had to be repaired (items set aside, renumbered ids, vertices without valid coordinates, values not understood, a newer format) and the errors of the design check. Use it on a file written or edited outside this server.',
    _object({'project': _project}, required: ['project']),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'project': {'type': 'string'},
        'version': {
          'type': ['integer', 'null'],
        },
        'repairs': {'type': 'array'},
        'errors': {'type': 'array'},
        'clean': {'type': 'boolean'},
      },
      'required': ['project', 'repairs', 'errors', 'clean'],
    },
    (a) async {
      final f = _input(_str(a, 'project')!, what: 'project');
      final r = await _cli(['validate', f.absolute, '--json'], ok: const {0, 1});
      final j = jsonDecode(r.out) as Map<String, dynamic>;
      return {
        ...j,
        'name': j['project'],
        'project': f.path,
        'repairs': [for (final x in j['repairs'] as List) _rel('$x')],
        'clean': r.code == 0,
      };
    },
  );

  McpTool _bom() => _tool(
    'bill_of_materials',
    'Bill of materials',
    'The bill of materials of a project, as the app and the command line\'s bom give it: every pipe, emitter, tape, valve, device, pump, fitting and wire with quantity, unit, unit price and total in the project\'s currency (the headers name the columns), and the capital cost. The design runs first in memory; nothing is saved.',
    _object({'project': _project, 'size_pipes': _sizePipes, 'offset': _offset, 'limit': _limit}, required: ['project']),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'project': {'type': 'string'},
        'currency': {'type': 'string'},
        'capitalCost': {'type': 'number'},
        'title': {'type': 'string'},
        'headers': {'type': 'array'},
        'rows': {'type': 'array'},
        'totalRows': {'type': 'integer'},
      },
      'required': ['project', 'currency', 'capitalCost', 'headers', 'rows', 'totalRows'],
    },
    (a) async {
      final (p, _, f) = _open(a);
      final r = _designed(p, size: _bool(a, 'size_pipes', true));
      final t = host.exporter(p, r).reportTables().where((t) => t.key == 'bom').firstOrNull;
      if (t == null) throw McpToolError(host.text('msg.needResults'));
      return {
        'project': f.path,
        'currency': p.params.currencyCode,
        'capitalCost': _round(r.capitalCost, 2),
        'title': t.title,
        'headers': t.headers,
        'rows': _rows(t, offset: _int(a, 'offset', 0), limit: _int(a, 'limit', OciMcpLimits.defaultRows)),
        'totalRows': t.rows.length,
      };
    },
  );

  McpTool _reportTable() => _tool(
    'report_table',
    'Report tables',
    'The report tables of a design, the ones the app shows and exports (zones, pipes, outlets, mainline, bill of materials, water, schedule, flushing, surge, electrical, messages…, depending on the project). Without table: the list of the tables there are, each with its key, title, columns and number of rows. With table (a key from that list): its rows, a page at a time. Numbers are in the project\'s display units, which the headers state. The design runs first in memory; nothing is saved.',
    _object(
      {'project': _project, 'table': _text('Key of the table (from the list; a key that repeats is "key#2", "key#3"…).', max: 100), 'size_pipes': _sizePipes, 'offset': _offset, 'limit': _limit},
      required: ['project'],
    ),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'project': {'type': 'string'},
        'tables': {'type': 'array'},
        'key': {'type': 'string'},
        'title': {'type': 'string'},
        'headers': {'type': 'array'},
        'rows': {'type': 'array'},
        'totalRows': {'type': 'integer'},
      },
      'required': ['project'],
    },
    (a) async {
      final (p, _, f) = _open(a);
      final r = host.design(p, size: _bool(a, 'size_pipes', true));
      final tables = host.exporter(p, r).reportTables();
      final seen = <String, int>{};
      final keyed = [for (final t in tables) (t, (seen[t.key] = (seen[t.key] ?? 0) + 1) == 1 ? t.key : '${t.key}#${seen[t.key]}')];
      final want = _str(a, 'table');
      if (want == null) {
        return {
          'project': f.path,
          'tables': [
            for (final (t, k) in keyed) {'key': k, 'title': t.title, 'columns': t.headers, 'rows': t.rows.length},
          ],
        };
      }
      final hit = keyed.where((x) => x.$2 == want).firstOrNull;
      if (hit == null) throw McpToolError('no table "$want" in this project: ${keyed.map((x) => x.$2).join(', ')}');
      final t = hit.$1;
      return {
        'project': f.path,
        'key': want,
        'title': t.title,
        'headers': t.headers,
        'rows': _rows(t, offset: _int(a, 'offset', 0), limit: _int(a, 'limit', OciMcpLimits.defaultRows)),
        'totalRows': t.rows.length,
      };
    },
  );

  Map<String, Object?> _schemaPart(String part) {
    final s = projectJsonSchema();
    final props = s['properties'] as Map<String, dynamic>;
    if (part == 'full') return s;
    if (part == 'overview') {
      return {
        for (final k in const [r'$schema', r'$id', 'title', 'description', 'type', 'required']) k: s[k],
        'properties': {
          for (final e in props.entries)
            e.key: {
              for (final k in const ['type', 'description', 'enum', 'default'])
                if ((e.value as Map).containsKey(k)) k: (e.value as Map)[k],
            },
        },
        'parts': ociSchemaParts,
      };
    }
    if (part.startsWith('catalog.')) return ((props['catalog'] as Map)['properties'] as Map)[part.substring(8)] as Map<String, Object?>;
    if (part.startsWith('entity.')) {
      final type = part.substring(7);
      return (((props['entities'] as Map)['items'] as Map)['oneOf'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['title'] == type);
    }
    return props[part] as Map<String, Object?>;
  }

  McpTool _schema() => _tool(
    'project_schema',
    'Project file schema',
    'The JSON Schema (2020-12) of the project file (.oci.json), built from the program\'s own model: every key, its type, its meaning and unit (in the descriptions) and the default of a new project. part: "overview" (default: the top-level keys and the list of parts), "params" (design parameters, for set_project), "meta", "layers", "systemFlows", "catalog", "catalog.<kind>", "entity.<type>" (one item type, for edit_entities) or "full" (all of it, about 70 KB).',
    _object({'part': _choice(ociSchemaParts, 'Which part (default overview).')}),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'part': {'type': 'string'},
        'schema': {'type': 'object'},
      },
      'required': ['part', 'schema'],
    },
    (a) async {
      final part = _str(a, 'part') ?? 'overview';
      return {'part': part, 'schema': _schemaPart(part)};
    },
  );

  Map<String, dynamic>? _example(String lang, String id) {
    final bytes = host.asset('examples/$lang/$id.oci.json');
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  McpTool _listExamples() => _tool(
    'list_examples',
    'List the examples',
    'List the example projects that ship with the program (a garden, a sports field, an orchard, drip row crops, a greenhouse, a nursery, coffee on contour lines, bananas, subsurface drip sugarcane, gravity-fed drip, a pasture, a golf hole, centre and sector pivots, a linear move): id, name, client, site and what they hold. Starting points for copy_example${readOnly ? ' (not available on this read-only server)' : ''}.',
    _object({'language': _choice(host.languages, 'Language of their texts (default the server\'s).')}),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'language': {'type': 'string'},
        'examples': {'type': 'array'},
      },
      'required': ['language', 'examples'],
    },
    (a) async {
      final lang = _str(a, 'language') ?? host.lang;
      final out = <Map<String, Object?>>[];
      for (final id in ociExampleIds) {
        final j = _example(lang, id);
        if (j == null) continue;
        final meta = j['meta'] as Map? ?? const {};
        final counts = <String, int>{};
        for (final e in (j['entities'] as List? ?? const [])) {
          if (e is Map && e['type'] is String) counts[e['type'] as String] = (counts[e['type']] ?? 0) + 1;
        }
        out.add({'id': id, 'name': meta['name'], 'client': meta['client'], 'site': meta['site'], 'entities': counts});
      }
      if (out.isEmpty) throw McpToolError('the examples are not installed with this copy of the program (examples/$lang is missing)');
      return {'language': lang, 'examples': out};
    },
  );

  McpTool _listPacks() => _tool(
    'list_catalog_packs',
    'List the catalogue packs',
    'List the catalogue packs that ship with the program: manufacturers\' pipes, emitters, drip tapes, valves and pumps, and pipe standards (ISO, EN, ASTM, IS…), each with its id, brand, description, number of items, source and licence. The ids are what add_catalog_pack${readOnly ? ' (not available on this read-only server)' : ''} takes.',
    _object({'search': _text('Only packs whose id, brand, name or description contains this text (any case).', max: 200)}),
    const McpToolAnnotations.reading(),
    output: const {
      'type': 'object',
      'properties': {
        'packs': {'type': 'array'},
      },
      'required': ['packs'],
    },
    (a) async {
      final bytes = host.asset('catalogs/index.json');
      if (bytes == null) throw McpToolError('the catalogue packs are not installed with this copy of the program (catalogs/index.json is missing)');
      final index = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final q = _str(a, 'search')?.toLowerCase();
      return {
        'packs': [
          for (final p in (index['packs'] as List).cast<Map<String, dynamic>>())
            if (q == null || [p['id'], p['brand'], p['name'], p['description']].any((v) => '$v'.toLowerCase().contains(q)))
              {
                for (final k in const ['id', 'brand', 'name', 'description', 'items', 'source', 'license', 'updated']) k: p[k],
              },
        ],
      };
    },
  );

  // ------------------------------------------------------------------ writing tools

  /// The command line's options for [_settings]'s arguments.
  static List<String> _settingArgs(Map<String, Object?> a) {
    final g = a['georef'] as Map?;
    return [
      if (a['name'] != null) ...['--name', a['name'] as String],
      if (a['units'] != null) ...['--units', a['units'] as String],
      if (a['currency'] != null) ...['--currency', (a['currency'] as String).toUpperCase()],
      if (a['mains_hz'] != null) ...['--hz', '${(a['mains_hz'] as num).toInt()}'],
      if (g != null) ...['--georef', '${g['lat']},${g['lon']}'],
    ];
  }

  Map<String, Object?> _after(McpFile f, List<String> log) {
    final file = host.resolve(f.path);
    final (p, repairs) = host.readProject(file);
    return {..._projectSummary(file, p, repairs), 'log': log};
  }

  McpTool _create() => _tool(
    'create_project',
    'Create a project',
    'Create a new project file (.oci.json) as the app makes one: the default catalogue in the server\'s language, prices in currency (an ISO 4217 code; converted at reference rates), the display units, the mains frequency, a name and optionally a georeference (the WGS84 latitude and longitude of the drawing origin). With boundary (a drawing or map file under the root: DXF, DWG, KML, shapefile, GeoJSON…), its largest closed outline becomes the irrigated area; layout: true then lays sprinkler heads over that area (outlet: an emitter id of the catalogue, see list_catalog; default the first sprinkler), with no zones or pipes yet. Never replaces an existing file. Returns the new project as read_project does.',
    _object(
      {
        'out': _text('The new project file, relative to the root (it must end in .oci.json and not exist yet).'),
        ..._settings,
        'boundary': _text('A drawing or map whose largest closed outline is the irrigated area.'),
        'layout': _flag('Lay sprinkler heads over the area of boundary (default false).'),
        'outlet': _text('With layout: the catalogue id of the sprinkler family.', max: 100),
      },
      required: ['out'],
    ),
    const McpToolAnnotations(readOnly: false),
    output: _projectSummarySchema,
    (a) async {
      final out = _target(_str(a, 'out')!, const ['.oci.json']);
      final boundary = _str(a, 'boundary');
      if (_bool(a, 'layout', false) && boundary == null) throw McpToolError('layout needs boundary: the drawing of the area to lay the heads over');
      if (a['outlet'] != null && !_bool(a, 'layout', false)) throw McpToolError('outlet is the sprinkler family of layout: pass layout: true too');
      final r = await _cli([
        'new',
        '--out',
        out.absolute,
        ..._settingArgs(a),
        if (boundary != null) ...['--boundary', _input(boundary, what: 'drawing').absolute],
        if (_bool(a, 'layout', false)) '--layout',
        if (a['outlet'] != null) ...['--outlet', a['outlet'] as String],
      ]);
      return _after(out, [...const LineSplitter().convert(r.out).map(_rel), ..._notes(r)]);
    },
  );

  McpTool _copyExample() => _tool(
    'copy_example',
    'Copy an example',
    'Copy one of the example projects that ship with the program into the root folder, as a starting point to study or change (list_examples describes them). The copy is a project of its own (a new identifier), with its texts in language (default the server\'s). Never replaces an existing file. Returns the copy as read_project does.',
    _object(
      {
        'example': _choice(ociExampleIds, 'Which example.'),
        'out': _text('The new project file, relative to the root (it must end in .oci.json and not exist yet).'),
        'language': _choice(host.languages, 'Language of its texts (default the server\'s).'),
      },
      required: ['example', 'out'],
    ),
    const McpToolAnnotations(readOnly: false),
    output: _projectSummarySchema,
    (a) async {
      final out = _target(_str(a, 'out')!, const ['.oci.json']);
      final lang = _str(a, 'language') ?? host.lang;
      final id = _str(a, 'example')!;
      final bytes = host.asset('examples/$lang/$id.oci.json');
      if (bytes == null) throw McpToolError('the example $id is not installed with this copy of the program (examples/$lang)');
      final file = readProjectFile(utf8.decode(bytes));
      final p = file.project
        ..meta.uid = ProjectMeta.newUid()
        ..meta.created = DateTime.now();
      _save(out, p);
      return _after(out, ['copied the example $id ($lang)']);
    },
  );

  McpTool _import() => _tool(
    'import_files',
    'Import drawings and surveys',
    'Make a project of drawings, maps and surveys, or add them to an existing project (into), as File → Import of the app reads them: DXF, DWG, DGN, KML/KMZ, shapefiles (.shp or zipped), GeoJSON, GPX, LandXML, EPANET .inp, LAS point clouds, GeoTIFF elevations and CSV points (a georeferenced file sets the project\'s georeference). A new project is named after the first file (or name), written to out (default: the first file with .oci.json) and takes the settings given; it never replaces an existing file. Returns what each file brought in and the project as read_project does.',
    _object(
      {
        'files': {'type': 'array', 'minItems': 1, 'maxItems': OciMcpLimits.maxInputs, 'items': _text('a drawing, map or survey under the root'), 'description': 'The files to import, in order.'},
        'out': _text('The new project (.oci.json), relative to the root.'),
        'into': _text('An existing project to add them to (instead of a new one); it is saved over.'),
        ..._settings,
      },
      required: ['files'],
    ),
    _write,
    output: _projectSummarySchema,
    (a) async {
      final files = [for (final p in (a['files'] as List).cast<String>()) _input(p, what: 'drawing')];
      final into = _str(a, 'into');
      if (into != null && a['out'] != null) throw McpToolError('give out (a new project) or into (an existing one), not both');
      if (into != null && _settingArgs(a).isNotEmpty) throw McpToolError('the settings are for a new project: change those of an existing one with set_project');
      final McpFile target;
      if (into != null) {
        target = _input(into, what: 'project');
      } else {
        final first = files.first.path;
        final dot = first.lastIndexOf('.');
        target = _target(_str(a, 'out') ?? '${dot > first.lastIndexOf('/') + 1 ? first.substring(0, dot) : first}.oci.json', const ['.oci.json']);
      }
      final r = await _cli([
        'import',
        for (final f in files) f.absolute,
        if (into != null) ...['--into', target.absolute] else ...['--out', target.absolute],
        ..._settingArgs(a),
      ]);
      return _after(target, [...const LineSplitter().convert(r.out).map(_rel), ..._notes(r)]);
    },
  );

  /// The design parameters set_project takes, with the type of each (the
  /// keys of the params section of the project file, but those the other
  /// arguments set).
  static Map<String, Object> get _paramKeys {
    final base = DesignParameters().toJson()
      ..remove('units')
      ..remove('currency')
      ..remove('currencyCode');
    return {...base, 'hz': 60.0, 'realOp': false}.map((k, v) => MapEntry(k, v as Object));
  }

  static final _paramEnums = <String, List<String>>{
    'method': [for (final m in FrictionMethod.values) m.name],
    'minorMethod': [for (final m in MinorLossMethod.values) m.name],
    'sizing': [for (final m in SizingMethod.values) m.name],
    'terrain': [for (final m in TerrainMethod.values) m.name],
  };

  /// The design parameters of [p] with [patch] applied; refused with every
  /// problem when a key or a value is not one of the file's.
  static DesignParameters _patched(DesignParameters p, Map<String, Object?> patch) {
    final keys = _paramKeys;
    final problems = <String>[];
    for (final e in patch.entries) {
      final def = keys[e.key];
      final v = e.value;
      if (def == null) {
        problems.add('parameters.${e.key}: not a design parameter (they are ${keys.keys.join(', ')}; units, currency and mains_hz have arguments of their own)');
      } else if (_paramEnums[e.key] case final options?) {
        if (v is! String || !options.contains(v)) problems.add('parameters.${e.key}: one of ${options.join(', ')}');
      } else if (def is bool) {
        if (v is! bool) problems.add('parameters.${e.key}: true or false');
      } else if (def is num) {
        if (v is! num || !v.isFinite) {
          problems.add('parameters.${e.key}: a number');
        } else if (def is int && v != v.roundToDouble()) {
          problems.add('parameters.${e.key}: a whole number');
        }
      } else if (v is! String) {
        problems.add('parameters.${e.key}: a text');
      }
    }
    if (problems.isNotEmpty) throw McpToolError(problems.join('\n'));
    return DesignParameters.fromJson({...p.toJson(), ...patch});
  }

  McpTool _set() => _tool(
    'set_project',
    'Change a project\'s settings',
    'Change the settings of a project, as the command line\'s set does: name, display units (metric or us), currency (the prices follow at reference rates), mains frequency and georeference; also the project details (client, site, designer, notes) and any design parameter (parameters: keys of the params section of the project file with their new values, e.g. {"vZone": 1.5, "sizing": "lp", "tol": 0.05}; project_schema part "params" lists them with units and defaults; read_project with parameters: true shows the current ones). Saved to out, or over the project file; the results of an earlier design are left out (run design_project again).',
    _object(
      {
        'project': _project,
        'out': _projectOut,
        ..._settings,
        'client': _text('Client of the project.', max: 200),
        'site': _text('Site (farm, address…).', max: 200),
        'designer': _text('Designer.', max: 200),
        'notes': {'type': 'string', 'maxLength': 4000, 'description': 'Notes of the project.'},
        'parameters': {'type': 'object', 'description': 'Design parameters to change, by their key in the project file.'},
      },
      required: ['project'],
    ),
    _write,
    output: _projectSummarySchema,
    (a) async {
      final (p, _, f) = _open(a);
      final out = a['out'] == null ? f : _target(_str(a, 'out')!, const ['.oci.json'], overwrite: true, same: f);
      final g = a['georef'] as Map?;
      final changed = [
        for (final k in const ['name', 'units', 'currency', 'mains_hz', 'georef', 'client', 'site', 'designer', 'notes', 'parameters'])
          if (a[k] != null) k,
      ];
      if (changed.isEmpty) throw McpToolError('nothing to change: give at least one setting');
      final patch = (a['parameters'] as Map?)?.cast<String, Object?>();
      // checked before anything changes
      if (patch != null) _patched(p.params, patch);
      final log = host.settings(
        p,
        units: _str(a, 'units'),
        currency: _str(a, 'currency')?.toUpperCase(),
        hz: a['mains_hz'] == null ? null : '${(a['mains_hz'] as num).toInt()}',
        name: _str(a, 'name'),
        georef: g == null ? null : '${g['lat']},${g['lon']}',
      );
      if (a['client'] != null) p.meta.client = _str(a, 'client')!;
      if (a['site'] != null) p.meta.site = _str(a, 'site')!;
      if (a['designer'] != null) p.meta.designer = _str(a, 'designer')!;
      if (a['notes'] != null) p.meta.notes = _str(a, 'notes')!;
      // in the currency the project ends with
      if (patch != null) p.params = _patched(p.params, patch);
      _save(out, p);
      return _after(out, ['changed: ${changed.join(', ')}', ...log.map(_rel)]);
    },
  );

  McpTool _edit() => _tool(
    'edit_entities',
    'Edit the items of a project',
    'Add, change and delete items (entities) of a project\'s drawing, in the format of the project file: project_schema part "entity.<type>" gives the keys of each type (coordinates in metres in the drawing\'s system; flows m³/s, pressures in metres of water). add: new items, each with its "type" (pipe, outlet, controlValve, waterSupply, pump, misc, tape, sprayline, area, polyline, text…), and "id" (optional: a new one is given) and "layer" (optional: the usual layer of the type). update: [{"id": …, "set": {key: value}}] changes keys of existing items (not their type or id). delete: ids. Everything is checked first: when any change is refused, the file is not touched. Pipes join items at their vertices (within the connection tolerance, params key "tol"). Returns the ids and the problems the design check finds in the items changed. Saved to out, or over the project file.',
    _object(
      {
        'project': _project,
        'out': _projectOut,
        'add': {
          'type': 'array',
          'maxItems': OciMcpLimits.maxEdits,
          'items': {'type': 'object', 'description': 'an item as the project file stores it, with its "type"'},
          'description': 'Items to add.',
        },
        'update': {
          'type': 'array',
          'maxItems': OciMcpLimits.maxEdits,
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string', 'minLength': 1, 'maxLength': 100},
              'set': {'type': 'object', 'description': 'keys of the item and their new values'},
            },
            'required': ['id', 'set'],
            'additionalProperties': false,
          },
          'description': 'Changes of existing items.',
        },
        'delete': {
          'type': 'array',
          'maxItems': OciMcpLimits.maxEdits,
          'items': {'type': 'string', 'minLength': 1, 'maxLength': 100},
          'description': 'Ids of the items to delete.',
        },
      },
      required: ['project'],
    ),
    _write,
    output: const {
      'type': 'object',
      'properties': {
        'project': {'type': 'string'},
        'added': {'type': 'array'},
        'updated': {'type': 'array'},
        'deleted': {'type': 'array'},
        'entities': {'type': 'integer'},
        'problems': {'type': 'array', 'description': 'design check issues about the items changed: level, code, items'},
      },
      'required': ['project', 'added', 'updated', 'deleted', 'entities', 'problems'],
    },
    (a) async {
      final (p, _, f) = _open(a);
      final out = a['out'] == null ? f : _target(_str(a, 'out')!, const ['.oci.json'], overwrite: true, same: f);
      final add = (a['add'] as List? ?? const []).cast<Map<String, dynamic>>();
      final update = (a['update'] as List? ?? const []).cast<Map<String, dynamic>>();
      final delete = (a['delete'] as List? ?? const []).cast<String>();
      if (add.isEmpty && update.isEmpty && delete.isEmpty) throw McpToolError('nothing to change: give add, update or delete');
      final problems = <String>[];
      final ids = {for (final e in p.entities) e.id};

      Entity? build(Map<String, dynamic> j, String where) {
        final report = ProjectReadReport();
        final Entity e;
        try {
          e = Entity.fromJson(j, report: report);
        } on FormatException catch (x) {
          problems.add(
            '$where: ${x.message == 'entity_type' ? 'unknown type ${x.source} (one of ${EntityType.values.map((t) => t.name).join(', ')})' : 'invalid ${x.message}${x.source == null ? '' : ' (${x.source})'}'}',
          );
          return null;
        } catch (x) {
          problems.add('$where: invalid item ($x)');
          return null;
        }
        if (report.droppedVertices > 0) problems.add('$where: ${report.droppedVertices} vertices without valid coordinates [x, y]');
        if (report.unknownValues.isNotEmpty) problems.add('$where: values not understood: ${report.unknownValues.join(', ')}');
        final pts = e.linearPoints;
        if (pts != null && pts.length < 2) problems.add('$where: needs at least 2 points');
        if (e is AreaEntity && (e.points.length < 3 || polygonArea(e.points).abs() < 0.01)) problems.add('$where: an area needs at least 3 points enclosing a surface');
        return e;
      }

      final removed = <String>[];
      for (final id in delete) {
        if (!ids.contains(id)) {
          problems.add('delete: no item $id');
        } else {
          removed.add(id);
        }
      }
      final changedItems = <int, Entity>{};
      for (var i = 0; i < update.length; i++) {
        final u = update[i];
        final id = u['id'] as String;
        final index = p.entities.indexWhere((e) => e.id == id);
        if (index < 0) {
          problems.add('update[$i]: no item $id');
          continue;
        }
        final set = (u['set'] as Map).cast<String, dynamic>();
        if (set.containsKey('id') || set.containsKey('type')) problems.add('update[$i]: the type and the id of an item cannot change (delete it and add another)');
        final e = build({...p.entities[index].toJson(), ...set, 'id': id, 'type': p.entities[index].type.name}, 'update[$i] ($id)');
        if (e != null) changedItems[index] = e;
      }
      final added = <Entity>[];
      final newIds = <String>{};
      for (var i = 0; i < add.length; i++) {
        final j = Map<String, dynamic>.from(add[i]);
        final given = j['id'];
        if (given != null && (given is! String || given.isEmpty || ids.contains(given) || newIds.contains(given))) {
          problems.add('add[$i]: id $given is taken (leave it out to get a new one)');
          continue;
        }
        if (given == null) j['id'] = '_new$i';
        final e = build(j, 'add[$i]');
        if (e == null) continue;
        newIds.add(e.id);
        added.add(given == null ? e.clone(newId: p.newId()) : e);
        if (j['layer'] == null) added.last.layer = defaultLayerFor(added.last);
      }
      if (problems.isNotEmpty) throw McpToolError('nothing was changed:\n- ${problems.take(40).join('\n- ')}${problems.length > 40 ? '\n- … ${problems.length - 40} more' : ''}');
      for (final e in changedItems.entries) {
        p.entities[e.key] = e.value;
      }
      p.entities.removeWhere((e) => removed.contains(e.id));
      // a deleted valve or pivot no longer runs in a system flow
      for (final f in p.systemFlows) {
        f.valveIds.removeAll(removed);
      }
      p.entities.addAll(added);
      p.ensureNextId(Project.nextIdAfter(p.entities));
      for (final e in added) {
        if (!p.layers.any((l) => l.name == e.layer)) p.layers.add(Layer(name: e.layer, color: Layers.defaultColors[e.layer] ?? 0xFFFFFFFF));
      }
      _save(out, p);
      final touched = {...added.map((e) => e.id), ...changedItems.values.map((e) => e.id)};
      return {
        'project': out.path,
        'added': [for (final e in added) e.id],
        'updated': [for (final e in changedItems.values) e.id],
        'deleted': removed,
        'entities': p.entities.length,
        // the design check and the assistant, as check_project run "none" gives them
        'problems': [
          for (final x in buildAdvice(p))
            if (x.entityIds.any(touched.contains)) {'level': x.level.name, 'code': x.code, 'message': host.adviceText(p, x), 'entities': x.entityIds.take(20).toList()},
        ],
      };
    },
  );

  McpTool _addPack() => _tool(
    'add_catalog_pack',
    'Add catalogue packs',
    'Add catalogue packs to a project, as the command line\'s pack add does: the id of a pack that ships with the program (list_catalog_packs; e.g. "netafim", "iso1452") or a .oci.cat file under the root. The items keep their ids (an id the catalogue has already is not added again); prices are converted to the project\'s currency at reference rates. Saved to out, or over the project file.',
    _object(
      {
        'project': _project,
        'packs': {
          'type': 'array',
          'minItems': 1,
          'maxItems': OciMcpLimits.maxInputs,
          'items': _text('a bundled pack id, or a .oci.cat file under the root'),
          'description': 'The packs to add, in order.',
        },
        'out': _projectOut,
      },
      required: ['project', 'packs'],
    ),
    _write,
    output: _projectSummarySchema,
    (a) async {
      final f = _input(_str(a, 'project')!, what: 'project');
      final out = a['out'] == null ? f : _target(_str(a, 'out')!, const ['.oci.json'], overwrite: true, same: f);
      final refs = <String>[];
      for (final ref in (a['packs'] as List).cast<String>()) {
        final bundled = RegExp(r'^[a-z0-9_-]+$').hasMatch(ref) ? host.assetPath('catalogs/$ref.oci.cat') : null;
        refs.add(bundled ?? _input(ref, what: 'catalogue pack').absolute);
      }
      final r = await _cli(['pack', 'add', f.absolute, ...refs, '--out', out.absolute]);
      return _after(out, [...const LineSplitter().convert(r.out).map(_rel), ..._notes(r)]);
    },
  );

  McpTool _design() => _tool(
    'design_project',
    'Design a project',
    'Design a project as the app\'s Design command (F5) does: size the pipes the design may choose, analyse every zone, the mainline of each system flow and the pivots, price the bill of materials, then save the designed project with its results (to out, or over the project file). Returns the same summary as analyze_project; check_project explains every message, bill_of_materials and report_table give the details.',
    _object({'project': _project, 'out': _projectOut}, required: ['project']),
    _write,
    output: _summarySchema,
    (a) async {
      final (p, _, f) = _open(a);
      final out = a['out'] == null ? f : _target(_str(a, 'out')!, const ['.oci.json'], overwrite: true, same: f);
      final r = _designed(p, size: true);
      _save(out, p, results: r);
      return _summary(f, p, r, sized: true, saved: out.path);
    },
  );

  static const _calculate = {'design': '--design', 'analyze': '--analyze', 'none': null};

  McpTool _exportDrawing() => _tool(
    'export_drawing',
    'Export the drawing',
    'Write the drawing of a project into the root folder in another format: dxf (R2000) or dxfR12, dwg (R2000), pdf or svg (a plotted sheet with the title block and, after a design, the result tables), kml, kmz, geojson or gpx (map formats; they need a georeference: the project\'s, or georef), shp (zipped shapefiles), landxml, ifc or inp (an EPANET network). calculate: "design" (default) sizes and analyses first so the drawing shows sized pipes and results (the project file is not changed), "analyze" analyses the sizes drawn, "none" exports the drawing as it is. Refuses to replace an existing file unless overwrite is true.',
    _object(
      {
        'project': _project,
        'format': _choice([for (final f in DrawingFormat.values) f.name], 'The format.'),
        'out': _out('the file (its extension must be the format\'s: .dxf, .dwg, .pdf, .svg, .kml, .kmz, .geojson, .zip for shp, .gpx, .xml for landxml, .ifc, .inp)'),
        'calculate': _choice(const ['design', 'analyze', 'none'], 'What to calculate first (default design).'),
        'paper': _choice([for (final s in PageSize.values) s.name], 'pdf, svg: sheet size (default a3).'),
        'portrait': _flag('pdf, svg: portrait sheet (default landscape).'),
        'georef': _georef,
        'overwrite': _flag('Replace the file if it exists (default false).'),
      },
      required: ['project', 'format'],
    ),
    _write,
    output: _writtenSchema,
    (a) async {
      final f = _input(_str(a, 'project')!, what: 'project');
      final format = DrawingFormat.values.byName(_str(a, 'format')!);
      final out = _target(_str(a, 'out') ?? '${_stem(f.path)}.${format.extension}', ['.${format.extension}'], overwrite: _bool(a, 'overwrite', false));
      final g = a['georef'] as Map?;
      final calc = _calculate[_str(a, 'calculate') ?? 'design'];
      await _cli([
        'export',
        f.absolute,
        '--format',
        format.name,
        '--out',
        out.absolute,
        '--paper',
        _str(a, 'paper') ?? 'a3',
        if (_bool(a, 'portrait', false)) '--portrait',
        ?calc,
        if (g != null) ...['--georef', '${g['lat']},${g['lon']}'],
      ]);
      final written = host.resolve(out.path);
      return {'written': written.path, 'bytes': written.size, 'format': format.name};
    },
  );

  McpTool _exportReport() => _tool(
    'export_report',
    'Export the reports',
    'Write the report tables of a project into the root folder as csv, txt, xlsx or pdf: every table (tables: "all", default) or the bill of materials alone ("bom"). The design runs first (size_pipes: false analyses the sizes drawn); the project file is not changed. Refuses to replace an existing file unless overwrite is true.',
    _object(
      {
        'project': _project,
        'format': _choice([for (final f in ReportFormat.values) f.name], 'The format.'),
        'tables': _choice(const ['all', 'bom'], 'Which tables (default all).'),
        'size_pipes': _sizePipes,
        'out': _out('the file (its extension must be the format\'s)'),
        'overwrite': _flag('Replace the file if it exists (default false).'),
      },
      required: ['project', 'format'],
    ),
    _write,
    output: _writtenSchema,
    (a) async {
      final f = _input(_str(a, 'project')!, what: 'project');
      final format = ReportFormat.values.byName(_str(a, 'format')!);
      final bom = _str(a, 'tables') == 'bom';
      final size = _bool(a, 'size_pipes', true);
      final out = _target(_str(a, 'out') ?? '${_stem(f.path)}.${bom ? 'bom' : 'report'}.${format.extension}', ['.${format.extension}'], overwrite: _bool(a, 'overwrite', false));
      await _cli(bom ? ['bom', f.absolute, '--out', out.absolute, if (!size) '--analyze'] : [size ? 'design' : 'analyze', f.absolute, '--report', out.absolute]);
      final written = host.resolve(out.path);
      return {'written': written.path, 'bytes': written.size, 'format': format.name};
    },
  );

  // ------------------------------------------------------------------ resources and prompts

  /// The schema of the project file, the index of the catalogue packs and
  /// the examples in the server's language.
  List<McpResource> get resources => [
    McpResource(
      uri: 'oci://schema/project.json',
      name: 'project.schema.json',
      title: 'Project file schema',
      description: 'JSON Schema (2020-12) of the .oci.json project file, built from the model: keys, types, units and defaults.',
      mimeType: 'application/schema+json',
      read: () => McpResourceContents(text: const JsonEncoder.withIndent('  ').convert(projectJsonSchema()), mimeType: 'application/schema+json'),
    ),
    McpResource(
      uri: 'oci://catalogs/index.json',
      name: 'catalogs-index.json',
      title: 'Catalogue packs',
      description: 'The catalogue packs that ship with the program: ids, brands, items, sources and licences.',
      mimeType: 'application/json',
      read: () {
        final b = host.asset('catalogs/index.json');
        return b == null ? null : McpResourceContents(text: utf8.decode(b), mimeType: 'application/json');
      },
    ),
    for (final id in ociExampleIds)
      McpResource(
        uri: 'oci://examples/${host.lang}/$id.oci.json',
        name: '$id.oci.json',
        title: 'Example: $id',
        description: 'The example project "$id" (${host.lang}), as the program ships it.',
        mimeType: 'application/json',
        read: () {
          final b = host.asset('examples/${host.lang}/$id.oci.json');
          return b == null ? null : McpResourceContents(text: utf8.decode(b), mimeType: 'application/json');
        },
      ),
  ];

  /// Two starting points for a conversation.
  List<McpPrompt> get prompts => [
    McpPrompt(
      name: 'design_irrigation',
      title: 'Design an irrigation system',
      description: 'Design a system for a field or garden from a drawing or map under the root folder.',
      arguments: const [
        McpPromptArgument(name: 'drawing', description: 'The drawing, map or survey of the area (a file under the root).', required: true),
        McpPromptArgument(name: 'what', description: 'What is irrigated and how (e.g. "lawn with rotors", "drip on tomatoes").'),
      ],
      text: (x) => [
        'Design a pressurised irrigation system with the OpenCADIrrigation tools for the area in ${x['drawing']}${(x['what'] ?? '').isEmpty ? '' : ' (${x['what']})'}.',
        '1. read the files (list_files) and make a project of the drawing (import_files, or create_project with boundary and layout for sprinklers);',
        '2. read it (read_project, list_entities) and the catalogue (list_catalog); add what is missing with edit_entities (a water supply, control valves with their zones, pipes joining every item; project_schema part "entity.<type>" for the keys);',
        '3. design it (design_project), read every message (check_project) and correct the errors before going on;',
        '4. give me the bill of materials (bill_of_materials) and export a PDF sheet and a DXF (export_drawing).',
        'Tell me the assumptions you make (pressure and flow of the supply, emitter, spacing) and the uniformity of each zone.',
      ].join('\n'),
    ),
    McpPrompt(
      name: 'review_project',
      title: 'Review a project',
      description: 'Check a project and explain its problems and how to correct them.',
      arguments: const [McpPromptArgument(name: 'project', description: 'The project file (.oci.json) under the root.', required: true)],
      text: (x) => [
        'Review the irrigation project ${x['project']} with the OpenCADIrrigation tools:',
        'read it (read_project), analyse it (analyze_project with size_pipes true) and list its problems (check_project);',
        'for each error and warning, say what it means for the system and how to correct it; then sum up the zones (flow, pressure, uniformity) and the cost.',
        'Do not change the file unless I ask.',
      ].join('\n'),
    ),
  ];
}
