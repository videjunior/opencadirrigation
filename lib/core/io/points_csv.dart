/// Survey points from text files (CSV / TXT / XYZ / PNEZD): X, Y, Z columns
/// detected from the header or by position; comma, semicolon, tab or space
/// separated; decimal comma tolerated. Geographic coordinates (lon/lat) are
/// recognised and projected through a [GeoReference].
///
/// Header names are compared without case, accents, units or punctuation
/// ("E (m)", "Coord. N", "Cota [m]", "Leste"). Without a header, a column of
/// UTM eastings (100–900 km) and one of northings (beyond 1 000 km) tell
/// P,E,N,Z from P,N,E,Z; latitude and longitude, which both fit ±90° in
/// most of the world, are taken in the order people type them and map
/// links give them (latitude first) unless the other order lands nearer the
/// project. The order assumed is said.
///
/// The import wizard of the app chooses all of it instead
/// ([PointsImportOptions], [PointsCsvReader.parseWith]): the separator and
/// the decimal mark, whether there is a header, the lines to skip, the role
/// of every column (point, easting, northing, elevation, latitude,
/// longitude, description) and the coordinate system (local metres, the
/// project's UTM, latitude/longitude on a datum, a UTM zone on a datum, an
/// EPSG code).
library;

import '../model/geometry.dart';
import '../units.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';

/// The separator of the columns of a points file.
enum PointsSeparator { auto, comma, semicolon, tab, space }

/// The decimal mark of the numbers.
enum PointsDecimal { auto, point, comma }

/// What a column of a points file holds.
enum PointsRole { ignore, name, x, y, z, lat, lon, description }

/// How the coordinates of a points file are taken.
enum PointsCrsKind {
  /// As the reader decides: degrees by their range and precision, large
  /// metres moved by the project's origin.
  auto,

  /// Plain local metres, as they are.
  local,

  /// Eastings and northings in the UTM zone of the project's georeference.
  projectUtm,

  /// Latitude and longitude (degrees) on [PointsImportOptions.datum].
  geographic,

  /// Eastings and northings of a UTM zone on [PointsImportOptions.datum].
  utm,

  /// The system of an EPSG code ([PointsImportOptions.epsg]).
  epsg,
}

/// The choices of the import wizard.
class PointsImportOptions {
  const PointsImportOptions({
    this.separator = PointsSeparator.auto,
    this.decimal = PointsDecimal.auto,
    this.header,
    this.skip = 0,
    this.roles,
    this.crs = PointsCrsKind.auto,
    this.datum = GeodeticDatum.wgs84,
    this.zone = 23,
    this.north = false,
    this.epsg,
    this.layer = 'SPOT_HEIGHTS',
  });
  final PointsSeparator separator;
  final PointsDecimal decimal;

  /// The first line (after [skip]) names the columns; null: told from it.
  final bool? header;

  /// Lines left out at the start of the file.
  final int skip;

  /// The role of each column; null: from the header or the values.
  final List<PointsRole>? roles;
  final PointsCrsKind crs;
  final GeodeticDatum datum;
  final int zone;
  final bool north;
  final int? epsg;
  final String layer;

  /// Everything automatic: [PointsCsvReader.parse].
  bool get automatic => separator == PointsSeparator.auto && decimal == PointsDecimal.auto && header == null && skip == 0 && roles == null && crs == PointsCrsKind.auto;

  PointsImportOptions copyWith({
    PointsSeparator? separator,
    PointsDecimal? decimal,
    bool? header,
    bool clearHeader = false,
    int? skip,
    List<PointsRole>? roles,
    bool clearRoles = false,
    PointsCrsKind? crs,
    GeodeticDatum? datum,
    int? zone,
    bool? north,
    int? epsg,
    String? layer,
  }) => PointsImportOptions(
    separator: separator ?? this.separator,
    decimal: decimal ?? this.decimal,
    header: clearHeader ? null : (header ?? this.header),
    skip: skip ?? this.skip,
    roles: clearRoles ? null : (roles ?? this.roles),
    crs: crs ?? this.crs,
    datum: datum ?? this.datum,
    zone: zone ?? this.zone,
    north: north ?? this.north,
    epsg: epsg ?? this.epsg,
    layer: layer ?? this.layer,
  );
}

class PointsImportResult {
  PointsImportResult({required this.document, required this.count, required this.georef, required this.geographic, required this.columns, this.warnings = const []});
  final DxfDocument document;
  final int count;

  /// Georeference created for geographic input (null when metric input).
  final GeoReference? georef;
  final bool geographic;

  /// Detected column indices (x, y, z, name).
  final (int, int, int?, int?) columns;

  /// Notes for the import message: `points_order:<order>` (the order of the
  /// columns assumed without a header), `points_latlon_assumed`.
  final List<String> warnings;
}

class PointsCsvReader {
  static final _sep = RegExp(r'[;\t]|,(?=\s*[-+\d"a-zA-Z])|\s+');

  static List<String> _split(String line) {
    final l = line.trim();
    if (l.isEmpty) return const [];
    // prefer explicit separators; fall back to whitespace
    if (l.contains(';')) return l.split(';').map((s) => s.trim()).toList();
    if (l.contains('\t')) return l.split('\t').map((s) => s.trim()).toList();
    final commas = ','.allMatches(l).length;
    final dots = '.'.allMatches(l).length;
    if (commas >= 2 && (dots > 0 || !RegExp(r'\d,\d').hasMatch(l))) return l.split(',').map((s) => s.trim()).toList();
    if (commas >= 1 && dots > 0) return l.split(',').map((s) => s.trim()).toList();
    // whitespace-separated columns with decimal commas ("10,5 20,5 100,2"):
    // every column holds at most one comma, its decimal separator
    final words = l.split(RegExp(r'\s+'));
    if (words.length >= 2 && words.every((w) => ','.allMatches(w).length <= 1 && !w.startsWith(',') && !w.endsWith(','))) return words;
    return l.split(_sep).where((s) => s.isNotEmpty).toList();
  }

  static double? _num(String s, [String? decimalSeparator]) => parseNumber(s.replaceAll('"', ''), decimalSeparator: decimalSeparator);

  /// Header names by the column they name.
  static const _xNames = {
    'x',
    'e',
    'east',
    'easting',
    'este',
    'leste',
    'lon',
    'long',
    'lng',
    'longitude',
    'longitud',
    'utm e',
    'e utm',
    'x utm',
    'este utm',
    'coord x',
    'coord e',
    'coordenada x',
    'coordenada e',
    'coordenada este',
    'coordenada leste',
  };
  static const _yNames = {
    'y',
    'n',
    'north',
    'northing',
    'norte',
    'lat',
    'latitude',
    'latitud',
    'utm n',
    'n utm',
    'y utm',
    'norte utm',
    'coord y',
    'coord n',
    'coordenada y',
    'coordenada n',
    'coordenada norte',
  };
  static const _zNames = {'z', 'elev', 'elevation', 'elevacao', 'cota', 'alt', 'altitude', 'altura', 'h', 'height', 'altitude ortometrica', 'altitude elipsoidal', 'cota ortometrica'};
  static const _nameNames = {'id', 'name', 'nome', 'nombre', 'ponto', 'point', 'punto', 'pt', 'desc', 'descricao', 'descripcion', 'code', 'codigo', 'cod', 'estaca', 'marco', 'label', 'rotulo'};
  static const _geoNames = {'lat', 'latitude', 'latitud', 'lon', 'long', 'lng', 'longitude', 'longitud'};

  /// A header cell reduced to its name: lower case, without accents, units
  /// in parentheses or brackets, or punctuation ("E (m)" → "e", "Coord. N"
  /// → "coord n", "Cota [m]" → "cota", "Nº" → "id").
  static String headerKey(String h) {
    var s = h.replaceAll('"', '').trim().toLowerCase();
    if (RegExp(r'^(n\s*[º°o]\.?|no\.|num\.?|numero|número|#)$').hasMatch(s)) return 'id';
    s = s.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüý';
    const to = 'aaaaaaceeeeiiiinooooouuuuy';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'[._:/\\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _eastingLike(double v) => v >= 100000 && v <= 900000;
  static bool _northingLike(double v) => v > 1000000 && v <= 10000000;

  /// The lines of a points file that hold data (empty lines and `#`
  /// comments left out).
  static List<String> dataLines(String text) => text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#')).toList();

  /// The cells of [line] split by [sep] (quotes around a cell taken off).
  static List<String> splitLine(String line, PointsSeparator sep) {
    final l = line.trim();
    if (l.isEmpty) return const [];
    final cells = switch (sep) {
      PointsSeparator.auto => _split(l),
      PointsSeparator.comma => l.split(','),
      PointsSeparator.semicolon => l.split(';'),
      PointsSeparator.tab => l.split('\t'),
      PointsSeparator.space => l.split(RegExp(r'\s+')),
    };
    return [for (final c in cells) c.trim().replaceAll(RegExp(r'^"|"$'), '')];
  }

  /// The first [max] rows of [text] split as [o] says (after the lines it
  /// skips), for the preview of the wizard.
  static List<List<String>> table(String text, PointsImportOptions o, {int max = 8}) {
    final lines = dataLines(text);
    return [for (final l in lines.skip(o.skip).take(max)) splitLine(l, o.separator)];
  }

  /// [s] as a number with the decimal mark [d] (spaces between digit
  /// groups tolerated), or null.
  static double? numberOf(String s, PointsDecimal d) {
    final t = s.replaceAll('"', '').trim();
    switch (d) {
      case PointsDecimal.auto:
        return _num(t);
      case PointsDecimal.point:
        return double.tryParse(t.replaceAll(RegExp(r'[\s,]'), ''));
      case PointsDecimal.comma:
        return double.tryParse(t.replaceAll(RegExp(r'[\s.]'), '').replaceAll(',', '.'));
    }
  }

  /// The choices the reader would make itself for [text] (the starting
  /// point of the wizard): the separator, the header, the role of each
  /// column and degrees or metres.
  static PointsImportOptions detect(String text, {GeoReference? georef}) {
    final lines = dataLines(text);
    if (lines.isEmpty) return const PointsImportOptions();
    final first = lines.first;
    final sep = first.contains(';')
        ? PointsSeparator.semicolon
        : (first.contains('\t') ? PointsSeparator.tab : (','.allMatches(first).length >= 2 || (first.contains(',') && first.contains('.')) ? PointsSeparator.comma : PointsSeparator.space));
    final cells = splitLine(first, sep);
    final header = cells.where((c) => _num(c) != null).length < 2;
    final roles = List.filled(cells.length, PointsRole.ignore);
    try {
      final r = parse(text, georef: georef);
      final (xi, yi, zi, ni) = r.columns;
      final geo = r.geographic;
      void set(int? i, PointsRole role) {
        if (i != null && i >= 0 && i < roles.length) roles[i] = role;
      }

      if (geo && header) {
        // the header names them: x is the longitude
        set(xi, PointsRole.lon);
        set(yi, PointsRole.lat);
      } else if (geo) {
        // without a header: the column beyond ±90° is the longitude, else
        // the reader's note says the order it took
        final a = xi < yi ? xi : yi, b = xi < yi ? yi : xi;
        double most(int col) {
          var m = 0.0;
          for (final l in lines.take(50)) {
            final c = splitLine(l, sep);
            final v = col < c.length ? _num(c[col]) : null;
            if (v != null && v.abs() > m) m = v.abs();
          }
          return m;
        }

        var lonFirst = most(a) > 90 || most(b) <= 90;
        for (final w in r.warnings) {
          if (w.startsWith('points_latlon_assumed:')) lonFirst = w.endsWith('lon, lat');
        }
        set(a, lonFirst ? PointsRole.lon : PointsRole.lat);
        set(b, lonFirst ? PointsRole.lat : PointsRole.lon);
      } else {
        set(xi, PointsRole.x);
        set(yi, PointsRole.y);
      }
      set(zi, PointsRole.z);
      set(ni, PointsRole.name);
      return PointsImportOptions(separator: sep, header: header, roles: roles, crs: geo ? PointsCrsKind.geographic : PointsCrsKind.auto);
    } on FormatException {
      return PointsImportOptions(separator: sep, header: header, roles: roles);
    }
  }

  /// The role of each column of the lines [o] selects (after its lines to
  /// skip, split by its separator), its own roles left aside: by the names
  /// of a header; else as [detect] takes them when it splits the lines into
  /// the same columns; else easting, northing and elevation in the first
  /// numeric columns (point, northing, easting, elevation when the first
  /// of four or more numeric columns is the first column).
  static List<PointsRole> rolesFor(String text, PointsImportOptions o, {GeoReference? georef}) {
    final lines = dataLines(text).skip(o.skip).toList();
    if (lines.isEmpty) return const [];
    final first = splitLine(lines.first, o.separator);
    final header = o.header ?? first.where((c) => numberOf(c, o.decimal) != null).length < 2;
    if (header) {
      final roles = List.filled(first.length, PointsRole.ignore);
      final keys = [for (final c in first) headerKey(c)];
      void by(Set<String> names, PointsRole role) {
        if (roles.contains(role)) return;
        for (var i = 0; i < keys.length; i++) {
          if (roles[i] == PointsRole.ignore && names.contains(keys[i])) {
            roles[i] = role;
            return;
          }
        }
      }

      // latitude and longitude by their own names, then the metric ones
      by(_yNames.intersection(_geoNames), PointsRole.lat);
      by(_xNames.intersection(_geoNames), PointsRole.lon);
      if (!(roles.contains(PointsRole.lat) && roles.contains(PointsRole.lon))) {
        for (var i = 0; i < roles.length; i++) {
          if (roles[i] == PointsRole.lat || roles[i] == PointsRole.lon) roles[i] = PointsRole.ignore;
        }
        by(_xNames.difference(_geoNames), PointsRole.x);
        by(_yNames.difference(_geoNames), PointsRole.y);
      }
      by(_zNames, PointsRole.z);
      by(_nameNames, PointsRole.name);
      if (roles.contains(PointsRole.lat) || roles.contains(PointsRole.x)) return roles;
    }
    // the reader's own choice, when it splits the lines into the same columns
    final auto = detect(lines.join('\n'), georef: georef);
    final r = auto.roles;
    if (r != null && r.length == first.length && (auto.header ?? false) == header && (r.contains(PointsRole.x) || r.contains(PointsRole.lat))) {
      if (auto.separator == o.separator || [for (final l in lines.take(20)) splitLine(l, auto.separator).length].every((n) => n == first.length)) return r;
    }
    // by position, from the first row of data
    final row = splitLine(lines[header && lines.length > 1 ? 1 : 0], o.separator);
    final nums = [
      for (var i = 0; i < row.length; i++)
        if (numberOf(row[i], o.decimal) != null) i,
    ];
    final out = List.filled(row.length > first.length ? row.length : first.length, PointsRole.ignore);
    if (nums.length >= 4 && nums.first == 0) {
      out[0] = PointsRole.name;
      out[nums[1]] = PointsRole.y;
      out[nums[2]] = PointsRole.x;
      out[nums[3]] = PointsRole.z;
    } else if (nums.length >= 2) {
      out[nums[0]] = PointsRole.x;
      out[nums[1]] = PointsRole.y;
      if (nums.length > 2) out[nums[2]] = PointsRole.z;
    }
    return out;
  }

  /// Reads [text] as the wizard's [o] says; all automatic, as [parse].
  /// Rows without both coordinates are skipped (counted in the warning
  /// `points_skipped:<n>`).
  static PointsImportResult parseWith(String text, PointsImportOptions o, {GeoReference? georef}) {
    if (o.automatic) return parse(text, georef: georef, layer: o.layer);
    final lines = dataLines(text).skip(o.skip).toList();
    if (lines.isEmpty) throw const FormatException('points_empty');
    final firstCells = splitLine(lines.first, o.separator);
    final header = o.header ?? firstCells.where((c) => numberOf(c, o.decimal) != null).length < 2;
    final body = header ? lines.skip(1) : lines;
    // the roles: the wizard's, else from the header and the values of the columns it splits
    final rs = o.roles ?? rolesFor(text, o, georef: georef);
    int? col(PointsRole r) {
      final i = rs.indexOf(r);
      return i < 0 ? null : i;
    }

    final latI = col(PointsRole.lat), lonI = col(PointsRole.lon);
    final geo = latI != null && lonI != null;
    final xi = geo ? lonI : col(PointsRole.x), yi = geo ? latI : col(PointsRole.y);
    if (xi == null || yi == null) throw const FormatException('points_no_columns');
    final zi = col(PointsRole.z), ni = col(PointsRole.name), di = col(PointsRole.description);
    final rows = <(double, double, double?, String)>[];
    var skipped = 0;
    for (final l in body) {
      final c = splitLine(l, o.separator);
      final x = xi < c.length ? numberOf(c[xi], o.decimal) : null, y = yi < c.length ? numberOf(c[yi], o.decimal) : null;
      if (x == null || y == null) {
        skipped++;
        continue;
      }
      final z = zi != null && zi < c.length ? numberOf(c[zi], o.decimal) : null;
      final name = [if (ni != null && ni < c.length) c[ni], if (di != null && di < c.length) c[di]].where((s) => s.isNotEmpty).join(' ');
      rows.add((x, y, z, name));
    }
    if (rows.isEmpty) throw const FormatException('points_no_columns');
    final warnings = <String>[if (skipped > 0) 'points_skipped:$skipped'];
    // the coordinate system
    CrsInfo? crs;
    var kind = o.crs;
    if (kind == PointsCrsKind.auto) kind = geo ? PointsCrsKind.geographic : PointsCrsKind.local;
    switch (kind) {
      case PointsCrsKind.geographic:
        crs = CrsInfo.geographic(o.datum);
      case PointsCrsKind.utm:
        crs = CrsInfo.utm(o.zone.clamp(1, 60), o.north, datum: o.datum);
      case PointsCrsKind.epsg:
        crs = o.epsg == null ? null : crsFromEpsg(o.epsg!);
        if (crs != null && !crs.recognised) throw FormatException(crs.problem ?? 'crs_epsg_unknown');
      case PointsCrsKind.projectUtm:
        if (georef == null) throw const FormatException('points_no_georef');
        crs = CrsInfo.utm(georef.zone, georef.north);
      case PointsCrsKind.local || PointsCrsKind.auto:
        crs = null;
    }
    final doc = DxfDocument(layers: [DxfLayer(o.layer, color: 3)]);
    GeoReference? created;
    if (crs == null) {
      // local metres: large ones moved by the project's origin, as the reader does
      for (final r in rows) {
        final p = o.crs == PointsCrsKind.auto && georef != null && r.$1.abs() > 100000 ? Pt(r.$1 - georef.originEasting, r.$2 - georef.originNorthing) : Pt(r.$1, r.$2);
        doc.entities.add(DxfEntity(type: 'POINT', layer: o.layer, points: [p], elevation: r.$3, name: r.$4));
      }
    } else {
      final plan = GeoPlacement.plan(crs, [for (final r in rows) (r.$1, r.$2)], georef: georef);
      if (plan.georefCreated) created = plan.georef;
      warnings.addAll(plan.warnings);
      for (final r in rows) {
        doc.entities.add(DxfEntity(type: 'POINT', layer: o.layer, points: [plan.place(r.$1, r.$2)], elevation: r.$3, name: r.$4));
      }
    }
    return PointsImportResult(document: doc, count: rows.length, georef: created, geographic: crs?.kind == CrsKind.geographic, columns: (xi, yi, zi, ni), warnings: warnings);
  }

  /// Parses the text. [georef] places geographic points relative to an
  /// existing origin; [layer] names the layer of the spot heights.
  static PointsImportResult parse(String text, {GeoReference? georef, String layer = 'SPOT_HEIGHTS'}) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#')).toList();
    if (lines.isEmpty) throw const FormatException('points_empty');
    var start = 0;
    final first = _split(lines.first);
    int? xi, yi, zi, ni;
    final header = first.map(headerKey).toList();
    final numericFirst = first.where((c) => _num(c) != null).length >= 2;
    final warnings = <String>[];
    if (!numericFirst) {
      start = 1;
      int? find(Set<String> names) {
        for (var i = 0; i < header.length; i++) {
          if (names.contains(header[i])) return i;
        }
        return null;
      }

      xi = find(_xNames);
      yi = find(_yNames);
      zi = find(_zNames);
      ni = find(_nameNames);
    }
    if (start >= lines.length) throw const FormatException('points_no_columns');
    // by position: PNEZD (id, N, E, Z, desc) when 5+ columns with a leading id, else X Y Z
    final sample = _split(lines[start]);
    if (xi == null || yi == null) {
      final nums = <int>[];
      for (var i = 0; i < sample.length; i++) {
        if (_num(sample[i]) != null) nums.add(i);
      }
      // the columns' typical values (the median of the first rows)
      double typical(int col) {
        final v = <double>[];
        for (var r = start; r < lines.length && v.length < 51; r++) {
          final c = _split(lines[r]);
          final x = col < c.length ? _num(c[col]) : null;
          if (x != null) v.add(x.abs());
        }
        if (v.isEmpty) return 0;
        v.sort();
        return v[v.length ~/ 2];
      }

      if (nums.length >= 4 && sample.length >= 4 && (nums.first == 0)) {
        // id, then two coordinates and the elevation: P,N,E,Z unless the
        // first is clearly an easting and the second a northing
        ni = 0;
        final a = typical(nums[1]), b = typical(nums[2]);
        final penz = _eastingLike(a) && _northingLike(b);
        xi = penz ? nums[1] : nums[2];
        yi = penz ? nums[2] : nums[1];
        zi = nums.length > 3 ? nums[3] : null;
        warnings.add('points_order:${penz ? 'P, E, N, Z' : 'P, N, E, Z'}');
      } else if (nums.length >= 2) {
        final a = typical(nums[0]), b = typical(nums[1]);
        final nez = _northingLike(a) && _eastingLike(b);
        xi = nez ? nums[1] : nums[0];
        yi = nez ? nums[0] : nums[1];
        zi = nums.length > 2 ? nums[2] : null;
        // a text column ("P1 500 600 10") names the point
        ni ??= [
          for (var i = 0; i < sample.length; i++)
            if (!nums.contains(i)) i,
        ].firstOrNull;
        if (_eastingLike(a) || _northingLike(a) || _eastingLike(b) || _northingLike(b)) warnings.add('points_order:${nez ? 'N, E, Z' : 'E, N, Z'}');
      } else {
        throw const FormatException('points_no_columns');
      }
    }
    final rows = <(double, double, double?, String)>[];
    var manyDecimals = 0;
    int decimals(String s) {
      final t = s.replaceAll('"', '').trim().replaceAll(',', '.');
      final i = t.indexOf('.');
      return i < 0 ? 0 : t.length - i - 1;
    }

    // 1.6.0 UI (UI-08): the decimal separator of the columns, from the values that tell ("12,5", "1.234,5"): in a
    // file of decimal commas a "1.250" is then 1250, not 1.25 (none tells: each value as it reads best)
    final cells = <String>[];
    for (var i = start; i < lines.length && cells.length < 6000; i++) {
      final c = _split(lines[i]);
      for (final k in [xi, yi, zi]) {
        if (k != null && k < c.length) cells.add(c[k].replaceAll('"', ''));
      }
    }
    final decimal = guessDecimalSeparator(cells);
    for (var i = start; i < lines.length; i++) {
      final c = _split(lines[i]);
      if (c.length <= (xi > yi ? xi : yi)) continue;
      final x = _num(c[xi], decimal), y = _num(c[yi], decimal);
      if (x == null || y == null) continue;
      final z = zi != null && zi < c.length ? _num(c[zi], decimal) : null;
      final name = ni != null && ni < c.length ? c[ni].replaceAll('"', '') : '';
      if (decimals(c[xi]) >= 5 && decimals(c[yi]) >= 5) manyDecimals++;
      rows.add((x, y, z, name));
    }
    if (rows.isEmpty) throw const FormatException('points_no_columns');
    // geographic? header names, or degree-like values (small, many decimals)
    final headerGeo = !numericFirst && _geoNames.any(header.contains);
    final headerMetric = !numericFirst && (const {'x', 'y', 'e', 'n', 'east', 'north', 'easting', 'northing', 'este', 'norte', 'leste'}.any(header.contains));
    final inRange = rows.every((r) => r.$1.abs() <= 180 && r.$2.abs() <= 90) || rows.every((r) => r.$1.abs() <= 90 && r.$2.abs() <= 180);
    final geographic = inRange && (headerGeo || (!headerMetric && manyDecimals * 2 >= rows.length));
    if (geographic) warnings.removeWhere((w) => w.startsWith('points_order'));
    GeoReference? ref;
    Pt Function(double, double) project;
    if (geographic) {
      // which column is the longitude: the one beyond ±90°, the header's, or
      // (both within ±90°, no header) latitude first unless longitude first
      // lands nearer the project
      var lonI = 0; // x column is longitude by default
      final xLat = rows.every((r) => r.$1.abs() <= 90), yLat = rows.every((r) => r.$2.abs() <= 90);
      if (xLat && !yLat) {
        lonI = 1;
      } else if (xLat && yLat && numericFirst) {
        // latitude in the first of the two columns of the file
        lonI = xi < yi ? 1 : 0;
        if (georef != null) {
          double off(int li) {
            var sx = 0.0, sy = 0.0;
            for (final r in rows) {
              sx += li == 0 ? r.$2 : r.$1;
              sy += li == 0 ? r.$1 : r.$2;
            }
            final (x, y) = georef.fromLatLon(sx / rows.length, sy / rows.length);
            return x * x + y * y;
          }

          final o0 = off(0), o1 = off(1);
          if (o0 != o1) lonI = o0 < o1 ? 0 : 1;
        }
        final latFirst = (lonI == 1) == (xi < yi);
        warnings.add('points_latlon_assumed:${latFirst ? 'lat, lon' : 'lon, lat'}');
      }
      double lonOf((double, double, double?, String) r) => lonI == 0 ? r.$1 : r.$2;
      double latOf((double, double, double?, String) r) => lonI == 0 ? r.$2 : r.$1;
      if (georef != null) {
        ref = georef;
      } else {
        var sLat = 0.0, sLon = 0.0;
        for (final r in rows) {
          sLat += latOf(r);
          sLon += lonOf(r);
        }
        final u = latLonToUtm(sLat / rows.length, sLon / rows.length);
        ref = GeoReference(zone: u.zone, north: u.north, originEasting: (u.easting / 100).round() * 100.0, originNorthing: (u.northing / 100).round() * 100.0);
      }
      final g = ref;
      project = (x, y) {
        final lat = lonI == 0 ? y : x, lon = lonI == 0 ? x : y;
        final u = latLonToUtm(lat, lon, zone: g.zone);
        var northing = u.northing;
        if (g.north && lat < 0) northing -= 10000000;
        if (!g.north && lat >= 0) northing += 10000000;
        return Pt(u.easting - g.originEasting, northing - g.originNorthing);
      };
    } else {
      // large projected coordinates: shift to the project origin when a georef
      // exists, else keep as-is (the user can georeference later)
      project = (x, y) => georef != null && x.abs() > 100000 ? Pt(x - georef.originEasting, y - georef.originNorthing) : Pt(x, y);
    }
    final doc = DxfDocument(layers: [DxfLayer(layer, color: 3)]);
    for (final r in rows) {
      final p = project(r.$1, r.$2);
      doc.entities.add(DxfEntity(type: 'POINT', layer: layer, points: [p], elevation: r.$3, name: r.$4));
    }
    return PointsImportResult(document: doc, count: rows.length, georef: geographic ? ref : null, geographic: geographic, columns: (xi, yi, zi, ni), warnings: warnings);
  }
}
