/// Operations (find_operations / run_operation) added in 1.6.0 for file formats:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations]: the points import wizard
/// (preview_points_attachment, import_points_attachment), the stake-out
/// points of the field (export_stakeout_points) and the downloads kept on
/// the device (data_cache_info, set_data_cache, clear_data_cache).
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/io/codepages.dart';
import '../../../core/io/datum.dart';
import '../../../core/io/points_csv.dart';
import '../../../core/io/stakeout.dart';
import '../../io/data_cache_store.dart';
import '../../widgets/dialogs/points_import_dialog.dart' show decodePointsText, isPointsFile, pointsEncodings;
import '../../widgets/dialogs/stakeout_dialog.dart' show stakeoutFileName, stakeoutPointsOf;
import '../agent_tools.dart';
import '../ops_eng_common.dart';

/// The column roles the operations take (`columns`), as JSON names.
const _roles = {'name': PointsRole.name, 'x': PointsRole.x, 'y': PointsRole.y, 'z': PointsRole.z, 'lat': PointsRole.lat, 'lon': PointsRole.lon, 'description': PointsRole.description};

const _crs = {
  'auto': PointsCrsKind.auto,
  'local': PointsCrsKind.local,
  'project_utm': PointsCrsKind.projectUtm,
  'geographic': PointsCrsKind.geographic,
  'utm': PointsCrsKind.utm,
  'epsg': PointsCrsKind.epsg,
};

Map<String, Object?> _pointsProps() => {
  'name': str('File name as attached (.csv, .txt, .xyz, .pts, .pnezd).'),
  'encoding': str('Text encoding; default auto (byte order mark, UTF-16 told by its zeros, UTF-8, else Windows-1252). Code pages by number.', pointsEncodings),
  'separator': str('Column separator; default auto.', [for (final s in PointsSeparator.values) s.name]),
  'decimal': str('Decimal mark: point (1.5), comma (1,5) or auto (default).', [for (final d in PointsDecimal.values) d.name]),
  'header': bool_('The first line (after skip) names the columns; omitted = told from it.'),
  'skip': int_('Lines left out at the start (default 0).'),
  'columns': obj({for (final k in _roles.keys) k: int_('0-based index of the column with the point ${k == 'x' ? 'easting' : (k == 'y' ? 'northing' : k)}.')}),
  'crs': str(
    'Coordinate system: auto (degrees told by their range, large metres moved by the project origin), local metres, project_utm (the UTM zone of the project georeference), geographic (lat/lon on datum), utm (zone/north on datum), epsg (code).',
    _crs.keys.toList(),
  ),
  'datum': str('Datum of geographic or utm (default wgs84; SIRGAS 2000 agrees with it).', [for (final d in GeodeticDatum.values) d.name]),
  'zone': int_('UTM zone 1–60 (crs utm).'),
  'north': bool_('Northern hemisphere (crs utm; default false).'),
  'epsg': int_('EPSG code (crs epsg): 4326, 4674, 31983, 5880 (Brazil Polyconic), 10857 (Brazil Albers)…'),
};

/// The wizard's choices from the input of an operation.
PointsImportOptions _options(AgentToolbox b, ToolArgs a, String text) {
  var o = PointsCsvReader.detect(text, georef: b.p.meta.georef);
  final sep = a.str('separator'), dec = a.str('decimal'), crs = a.str('crs'), datum = a.str('datum');
  o = o.copyWith(
    separator: sep == null ? null : PointsSeparator.values.byName(sep),
    decimal: dec == null ? null : PointsDecimal.values.byName(dec),
    header: a.flag('header'),
    skip: a.integer('skip', min: 0, max: 100000),
    crs: crs == null ? null : _crs[crs],
    datum: datum == null ? null : GeodeticDatum.values.byName(datum),
    zone: a.integer('zone', min: 1, max: 60),
    north: a.flag('north'),
    epsg: a.integer('epsg', min: 1, max: 999999),
  );
  final cols = a.input['columns'];
  if (cols is Map && cols.isNotEmpty) {
    final at = <int, PointsRole>{};
    for (final e in cols.entries) {
      final role = _roles['${e.key}'];
      final i = e.value;
      if (role == null || i is! num || i < 0 || i > 200 || i != i.roundToDouble()) throw ToolInputError('"columns.${e.key}" must be a column index (0-based).');
      at[i.toInt()] = role;
    }
    final n = at.keys.fold<int>(0, (m, i) => i + 1 > m ? i + 1 : m);
    o = o.copyWith(roles: [for (var i = 0; i < n; i++) at[i] ?? PointsRole.ignore]);
  } else if (sep != null || dec != null || a.has('skip') || a.has('header')) {
    // the columns as the reader takes them with the lines and the separator given
    o = o.copyWith(roles: PointsCsvReader.rolesFor(text, o, georef: b.p.meta.georef));
  }
  if (o.crs == PointsCrsKind.projectUtm && b.p.meta.georef == null) {
    throw ToolInputError('crs "project_utm" needs a project georeference: set_site or set_georeference first, or give the zone (crs "utm").');
  }
  return o;
}

/// The attached points file [a] names, as text in its encoding.
Future<(String, String)> _attached(AgentToolbox b, ToolArgs a) async {
  final files = b.host?.files ?? const {};
  final name = a.str('name', required: true)!;
  final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
  if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
  if (!isPointsFile(name)) throw ToolInputError('"$name" is not a points file (.csv, .txt, .xyz, .pts, .pnezd): import_attachment takes the other formats.');
  final enc = a.str('encoding') ?? 'auto';
  if (!pointsEncodings.contains(enc)) throw ToolInputError('"encoding" must be one of: ${pointsEncodings.join(', ')}.');
  if (loadableCjkCodepages.contains(int.tryParse(enc))) await loadCjkCodepages();
  return (name, decodePointsText(bytes, enc));
}

String _rolesText(PointsImportOptions o) {
  final r = o.roles;
  if (r == null) return 'automatic';
  return [
    for (var i = 0; i < r.length; i++)
      if (r[i] != PointsRole.ignore) '${r[i].name}=$i',
  ].join(', ');
}

/// The stake-out kinds as JSON names.
const _kinds = {'outlets': StakeoutKind.outlets, 'valves': StakeoutKind.valves, 'devices': StakeoutKind.devices, 'pipe_vertices': StakeoutKind.pipeVertices, 'lateral_ends': StakeoutKind.lateralEnds};

List<AgentTool> opsFmt(AgentToolbox b) {
  final c = b.c;
  return [
    engOp(
      b,
      name: 'preview_points_attachment',
      description: 'The import wizard of File → Import for a points file the user attached (CSV, TXT, XYZ, PTS, PNEZD), without importing: its first lines split into columns, the choices the reader would make (separator, header, the role of each column, degrees or metres), how many points those choices read and where they land (latitude/longitude of their centre, the distance from the project area). Check it before import_points_attachment when the order of the columns or the coordinate system is not obvious (latitude and longitude both within ±90°, eastings and northings without a header). Inputs as import_points_attachment.',
      schema: obj(_pointsProps(), required: ['name']),
      run: (a, _) async {
        final (name, text) = await _attached(b, a);
        final o = _options(b, a, text);
        final rows = PointsCsvReader.table(text, o, max: 6);
        final out = StringBuffer('$name — separator ${o.separator.name}, decimal ${o.decimal.name}, header ${o.header ?? 'auto'}, skip ${o.skip}, columns ${_rolesText(o)}, crs ${o.crs.name}\n');
        out.write(engTable([for (var i = 0; i < rows.fold<int>(0, (m, r) => r.length > m ? r.length : m); i++) 'col $i'], [for (final r in rows) r], max: 6));
        try {
          final r = PointsCsvReader.parseWith(text, o, georef: b.p.meta.georef);
          final g = r.georef ?? b.p.meta.georef;
          out.write('\n${r.count} points${r.warnings.isEmpty ? '' : ' (${r.warnings.join('; ')})'}.');
          if (g != null && r.document.entities.isNotEmpty) {
            var sx = 0.0, sy = 0.0;
            for (final e in r.document.entities) {
              sx += e.points.first.x;
              sy += e.points.first.y;
            }
            final n = r.document.entities.length;
            final (lat, lon) = g.toLatLon(sx / n, sy / n);
            out.write(' Centre at lat ${engN(lat, 5)}, lon ${engN(lon, 5)}${r.georef != null ? ' (a georeference would be created there)' : ''}.');
          }
        } on FormatException catch (e) {
          out.write('\nNo points with these choices: ${c.describeError(e)}.');
        }
        return ToolOutput(out.toString());
      },
    ),
    engOp(
      b,
      name: 'import_points_attachment',
      effect: ToolEffect.write,
      description: 'File → Import of a points file the user attached, with the choices of the import wizard: encoding, separator, decimal mark, header, lines to skip, the column of each role (name, x = easting, y = northing, z, lat, lon, description; 0-based) and the coordinate system (auto, local, project_utm, geographic on a datum, utm zone/hemisphere on a datum, an EPSG code: Albers, Lambert and polyconic systems included). Points with an elevation become spot heights of the terrain, the others markers; a geographic or UTM file creates the georeference when the project has none. One undo step. Look first with preview_points_attachment when unsure.',
      schema: obj(_pointsProps(), required: ['name']),
      summary: (i) => b.t('ai.op.import_points_attachment', {'n': '${i['name'] ?? ''}'}),
      run: (a, _) async {
        engNotBusy(c);
        final (name, text) = await _attached(b, a);
        final o = _options(b, a, text);
        try {
          return ToolOutput('Imported $name: ${c.importPointsWith(text, o)}');
        } on FormatException catch (e) {
          throw ToolInputError('The points could not be read with these choices (${c.describeError(e)}): look at them with preview_points_attachment.');
        }
      },
    ),
    engOp(
      b,
      name: 'export_stakeout_points',
      effect: ToolEffect.export,
      description: 'File → Export drawing → Stake-out points: the comma-separated list a total station or a GNSS RTK receiver loads directly, one line per point (number, northing, easting, elevation, description in pnezd order, or easting before northing in penzd), with the UTM coordinates of the project (local ones without a georeference) and the terrain elevation (empty without terrain data). Kinds: outlets (sprinklers, emitters, the outlets of laterals), valves, devices (pumps, supplies, filters, junctions, controllers), pipe_vertices, lateral_ends; default all but lateral_ends. Always confirmed by the user (a download).',
      schema: obj({
        'order': str('Column order; default pnezd.', [for (final o in StakeoutOrder.values) o.name]),
        'kinds': arr(str(null, _kinds.keys.toList()), 'What goes into the list.'),
        'first_number': int_('Number of the first point (default 1).'),
        'decimals': int_('Decimals of the coordinates, 2 to 4 (default 3).'),
      }),
      confirm: (_) => true,
      run: (a, _) async {
        final names = a.strings('kinds');
        final kinds = names.isEmpty ? {StakeoutKind.outlets, StakeoutKind.valves, StakeoutKind.devices, StakeoutKind.pipeVertices} : {for (final n in names) _kinds[n]!};
        final points = stakeoutPointsOf(c, kinds, firstNumber: a.integer('first_number', min: 0, max: 1000000000) ?? 1);
        if (points.isEmpty) throw ToolInputError('No point of those kinds in the project.');
        final order = StakeoutOrder.values.byName(a.str('order') ?? 'pnezd');
        final text = stakeoutCsv(points, order: order, decimals: a.integer('decimals', min: 2, max: 4) ?? 3);
        final file = stakeoutFileName(c);
        await engFileSink(c, file, 'text/csv', text);
        final noZ = points.where((p) => p.elevation == null).length;
        return ToolOutput(
          'Exported $file: ${points.length} points (${order.name.toUpperCase()}), ${b.p.meta.georef == null ? 'local coordinates (no georeference)' : 'UTM ${b.p.meta.georef!.crsName}'}${noZ > 0 ? '; $noZ without an elevation (no terrain data there)' : ''}.',
        );
      },
    ),
    engOp(
      b,
      name: 'data_cache_info',
      description: 'File → Saved downloaded data: what this device keeps of the downloads of the online elevation models (dem), of the climate series (climate) and of the weather forecasts (forecast): count, size, since when, where (the browser database or a folder), and whether new downloads are kept. Kept downloads make download_terrain and the climate download read from the device instead of the network.',
      schema: obj({}),
      run: (a, _) async {
        final dc = appDataCache();
        final out = StringBuffer('Keeping downloads: ${dc.enabled ? 'on' : 'off'}; store: ${dc.store.kind}${dc.store.location.isEmpty ? '' : ' (${dc.store.location})'}.');
        for (final k in const ['dem', 'climate', 'forecast']) {
          final s = await dc.stats(k);
          out.write('\n$k: ${s.count} entries, ${engN(s.bytes / 1e6, 2)} MB${s.oldest == null ? '' : ', since ${s.oldest!.toIso8601String().substring(0, 10)}'}');
        }
        return ToolOutput(out.toString());
      },
    ),
    engOp(
      b,
      name: 'set_data_cache',
      effect: ToolEffect.write,
      description: 'Turns on or off the keeping of downloads (online elevations and climate series) on this device ("Keep what is downloaded" of File → Saved downloaded data). What is kept stays until cleared.',
      schema: obj({'enabled': bool_('Keep new downloads.')}, required: ['enabled']),
      summary: (i) => b.t(i['enabled'] == true ? 'ai.op.set_data_cache.on' : 'ai.op.set_data_cache.off'),
      run: (a, _) async {
        final on = a.flag('enabled')!;
        setDataCacheEnabled(on);
        return ToolOutput('Keeping downloads is now ${on ? 'on' : 'off'}.');
      },
    ),
    engOp(
      b,
      name: 'clear_data_cache',
      effect: ToolEffect.write,
      description: 'Clears the downloads kept on this device: of the online elevation models (dem), of the climate series (climate), of the weather forecasts (forecast) or all (default). The next download fetches them again. Always confirmed by the user.',
      schema: obj({
        'kind': str('What to clear; default all.', ['dem', 'climate', 'forecast', 'all']),
      }),
      confirm: (_) => true,
      summary: (i) => b.t('ai.op.clear_data_cache', {'k': '${i['kind'] ?? 'all'}'}),
      run: (a, _) async {
        final k = a.str('kind') ?? 'all';
        final n = await appDataCache().clear(k == 'all' ? null : k);
        return ToolOutput('Cleared $n kept download${n == 1 ? '' : 's'} ($k).');
      },
    ),
  ];
}
