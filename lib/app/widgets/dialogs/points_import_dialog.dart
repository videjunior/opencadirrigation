/// File → Import of a points file (CSV, TXT, XYZ, PTS, PNEZD) through a
/// wizard: the first lines of the file as a table, the role of each column
/// (point, easting, northing, elevation, latitude, longitude, description),
/// the separator, the decimal mark, the header and the lines to skip, the
/// encoding of the text and the coordinate system; and, before anything is
/// imported, where the points land: on a small world map (latitude and
/// longitude in the order chosen, and where the other order would put
/// them) and against the area of the project, with the distance when they
/// fall far from it.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/io/codepages.dart';
import '../../../core/io/datum.dart';
import '../../../core/io/geo.dart';
import '../../../core/io/points_csv.dart';
import '../../../core/model/geometry.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The files the wizard reads.
bool isPointsFile(String name) {
  final l = name.toLowerCase();
  return l.endsWith('.csv') || l.endsWith('.txt') || l.endsWith('.xyz') || l.endsWith('.pts') || l.endsWith('.pnezd');
}

/// The encodings offered: automatic, UTF-8 and UTF-16, and code pages by number.
const pointsEncodings = <String>['auto', 'utf8', '1252', '28591', 'utf16le', 'utf16be', '1250', '1251', '1253', '1254', '1257', '1258', '874', '932', '936', '949', '950'];

/// [bytes] as text in encoding [enc] (one of [pointsEncodings]).
String decodePointsText(Uint8List bytes, String enc) => switch (enc) {
  'auto' => decodeTextBytes(bytes),
  'utf8' => utf8.decode(bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF ? bytes.sublist(3) : bytes, allowMalformed: true),
  'utf16le' => decodeUtf16(bytes, littleEndian: true, start: byteOrderMark(bytes) == 'utf16le' ? 2 : 0),
  'utf16be' => decodeUtf16(bytes, littleEndian: false, start: byteOrderMark(bytes) == 'utf16be' ? 2 : 0),
  _ => decodeCodepage(bytes, int.parse(enc)),
};

String _encodingLabel(ProjectController c, String enc) => switch (enc) {
  'auto' => c.t('ptsimp.enc.auto'),
  'utf8' => 'UTF-8',
  '28591' => 'ISO-8859-1',
  'utf16le' => 'UTF-16 LE',
  'utf16be' => 'UTF-16 BE',
  '932' => 'Shift-JIS (932)',
  '936' => 'GBK (936)',
  '949' => 'EUC-KR (949)',
  '950' => 'Big5 (950)',
  _ => 'Windows-$enc',
};

/// Lines read for the preview (a large file is imported whole, but shown by
/// its first lines).
const _previewLines = 2000;

/// The latitude/longitude centre of the points of [r] (local coordinates on
/// [g]), or null without a georeference.
(double, double)? _centre(PointsImportResult r, GeoReference? g) {
  if (g == null || r.document.entities.isEmpty) return null;
  var sx = 0.0, sy = 0.0;
  for (final e in r.document.entities) {
    sx += e.points.first.x;
    sy += e.points.first.y;
  }
  final n = r.document.entities.length;
  return g.toLatLon(sx / n, sy / n);
}

/// The wizard; returns the summary of the import, or null when cancelled.
Future<String?> showPointsImportDialog(BuildContext context, ProjectController c, String name, Uint8List bytes) async {
  final t = c.t;
  var enc = 'auto';
  var text = decodePointsText(bytes, enc);
  // the first lines only: a large file stays quick to preview
  String sample() => PointsCsvReader.dataLines(text).take(_previewLines).join('\n');
  var preview = sample();
  final georef = c.project.meta.georef;
  var o = PointsCsvReader.detect(preview, georef: georef);
  final epsgCtl = TextEditingController(text: o.epsg?.toString() ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // the points of the preview, or why there are none
        PointsImportResult? r;
        String? problem;
        try {
          r = PointsCsvReader.parseWith(preview, o, georef: georef);
        } on FormatException catch (e) {
          problem = c.describeError(e);
        }
        final rows = PointsCsvReader.table(preview, o, max: 6);
        final cols = rows.fold<int>(0, (m, r) => math.max(m, r.length));
        final roles = [for (var i = 0; i < cols; i++) i < (o.roles?.length ?? 0) ? o.roles![i] : PointsRole.ignore];
        void setRole(int i, PointsRole role) {
          final next = [...roles];
          // a role belongs to one column
          if (role != PointsRole.ignore) {
            for (var k = 0; k < next.length; k++) {
              if (next[k] == role) next[k] = PointsRole.ignore;
            }
          }
          next[i] = role;
          final geo = next.contains(PointsRole.lat) || next.contains(PointsRole.lon);
          setState(() {
            o = o.copyWith(roles: next);
            if (geo && (o.crs == PointsCrsKind.auto || o.crs == PointsCrsKind.local || o.crs == PointsCrsKind.projectUtm)) o = o.copyWith(crs: PointsCrsKind.geographic);
          });
        }

        final lat = roles.indexOf(PointsRole.lat), lon = roles.indexOf(PointsRole.lon);
        // where the points land, in the order chosen and the other one
        final used = r?.georef ?? georef;
        final centre = r == null ? null : _centre(r, used);
        (double, double)? swapped;
        if (centre != null && lat >= 0 && lon >= 0 && centre.$1.abs() <= 90 && centre.$2.abs() <= 90) swapped = (centre.$2, centre.$1);
        final projectBox = c.project.bounds;
        final pts = r == null ? const <Pt>[] : [for (final e in r.document.entities) e.points.first];
        final box = Bounds.ofPoints(pts);
        double? farKm;
        if (georef != null && !projectBox.isEmpty && !box.isEmpty && r?.georef == null) {
          final d = math.max(0.0, math.max(box.minX - projectBox.maxX, projectBox.minX - box.maxX));
          final e = math.max(0.0, math.max(box.minY - projectBox.maxY, projectBox.minY - box.maxY));
          final km = math.sqrt(d * d + e * e) / 1000;
          if (km > 50) farKm = km;
        }
        final skipped = r == null ? 0 : r.warnings.where((w) => w.startsWith('points_skipped')).map((w) => int.tryParse(w.split(':').last) ?? 0).fold<int>(0, (a, b) => a + b);
        Widget drop<T>(String label, T value, List<T> values, String Function(T) text, ValueChanged<T> on, {Key? key}) => InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.fromLTRB(8, 6, 4, 6)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              key: key,
              value: value,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: 12, color: Cad.fg),
              items: [
                for (final v in values)
                  DropdownMenuItem(
                    value: v,
                    child: Text(text(v), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) on(v);
              },
            ),
          ),
        );
        final crsKinds = [
          for (final k in PointsCrsKind.values)
            if (k != PointsCrsKind.projectUtm || georef != null) k,
        ];
        return AlertDialog(
          title: Text(t('ptsimp.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 720),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 12, color: Cad.fg70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 170,
                        child: drop<String>(t('ptsimp.encoding'), enc, pointsEncodings, (e) => _encodingLabel(c, e), (e) async {
                          // an East Asian page: its tables first (loaded once)
                          if (loadableCjkCodepages.contains(int.tryParse(e))) await loadCjkCodepages();
                          if (!ctx.mounted) return;
                          setState(() {
                            enc = e;
                            text = decodePointsText(bytes, e);
                            preview = sample();
                          });
                        }, key: const Key('ptsimp_encoding')),
                      ),
                      SizedBox(
                        width: 150,
                        child: drop<PointsSeparator>(t('ptsimp.separator'), o.separator, PointsSeparator.values, (s) => t('ptsimp.sep.${s.name}'), (s) {
                          // other columns: their roles as the reader takes them
                          setState(() {
                            o = o.copyWith(separator: s, clearRoles: true);
                            o = o.copyWith(roles: PointsCsvReader.rolesFor(preview, o, georef: georef));
                          });
                        }, key: const Key('ptsimp_separator')),
                      ),
                      SizedBox(
                        width: 150,
                        child: drop<PointsDecimal>(
                          t('ptsimp.decimal'),
                          o.decimal,
                          PointsDecimal.values,
                          (d) => t('ptsimp.dec.${d.name}'),
                          (d) => setState(() => o = o.copyWith(decimal: d)),
                          key: const Key('ptsimp_decimal'),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: NumField(
                          key: const Key('ptsimp_skip'),
                          label: t('ptsimp.skip'),
                          value: o.skip.toDouble(),
                          decimals: 0,
                          signed: false,
                          onChanged: (v) => setState(() => o = o.copyWith(skip: v.round().clamp(0, 1000).toInt())),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    key: const Key('ptsimp_header'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(t('ptsimp.header'), style: const TextStyle(fontSize: 12)),
                    value: o.header ?? false,
                    onChanged: (v) => setState(() => o = o.copyWith(header: v ?? false)),
                  ),
                  Text(t('ptsimp.preview'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      border: TableBorder.all(color: Cad.divider),
                      children: [
                        TableRow(
                          children: [
                            for (var i = 0; i < cols; i++)
                              SizedBox(
                                width: 136,
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<PointsRole>(
                                    key: Key('ptsimp_role_$i'),
                                    value: roles[i],
                                    isExpanded: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    style: TextStyle(fontSize: 12, color: roles[i] == PointsRole.ignore ? Cad.fg54 : Cad.accentText),
                                    items: [
                                      for (final role in PointsRole.values)
                                        DropdownMenuItem(
                                          value: role,
                                          child: Text(t('ptsimp.role.${role.name}'), overflow: TextOverflow.ellipsis),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setRole(i, v);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (final (k, row) in rows.indexed)
                          TableRow(
                            decoration: BoxDecoration(color: k == 0 && (o.header ?? false) ? Cad.overlayFaint : null),
                            children: [
                              for (var i = 0; i < cols; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Text(i < row.length ? row[i] : '', style: TextStyle(fontSize: 11.5, fontStyle: k == 0 && (o.header ?? false) ? FontStyle.italic : null), maxLines: 1),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 230,
                        child: drop<PointsCrsKind>(
                          t('ptsimp.crs'),
                          crsKinds.contains(o.crs) ? o.crs : PointsCrsKind.auto,
                          crsKinds,
                          (k) => t('ptsimp.crs.${k.name}'),
                          (k) => setState(() => o = o.copyWith(crs: k)),
                          key: const Key('ptsimp_crs'),
                        ),
                      ),
                      if (o.crs == PointsCrsKind.geographic || o.crs == PointsCrsKind.utm)
                        SizedBox(
                          width: 170,
                          child: drop<GeodeticDatum>(
                            t('ptsimp.datum'),
                            o.datum,
                            GeodeticDatum.values,
                            (d) => d.ogcName,
                            (d) => setState(() => o = o.copyWith(datum: d)),
                            key: const Key('ptsimp_datum'),
                          ),
                        ),
                      if (o.crs == PointsCrsKind.utm) ...[
                        SizedBox(
                          width: 100,
                          child: drop<int>(t('ptsimp.zone'), o.zone, [for (var z = 1; z <= 60; z++) z], (z) => '$z', (z) => setState(() => o = o.copyWith(zone: z)), key: const Key('ptsimp_zone')),
                        ),
                        SizedBox(
                          width: 120,
                          child: drop<bool>(
                            t('ptsimp.hemisphere'),
                            o.north,
                            const [false, true],
                            (n) => t(n ? 'ptsimp.hemisphere.north' : 'ptsimp.hemisphere.south'),
                            (n) => setState(() => o = o.copyWith(north: n)),
                            key: const Key('ptsimp_hemisphere'),
                          ),
                        ),
                      ],
                      if (o.crs == PointsCrsKind.epsg)
                        SizedBox(
                          width: 140,
                          child: TextField(
                            key: const Key('ptsimp_epsg'),
                            controller: epsgCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: t('ptsimp.crs.epsg'), isDense: true),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (s) => setState(() => o = o.copyWith(epsg: int.tryParse(s.trim()))),
                          ),
                        ),
                      if (lat >= 0 && lon >= 0)
                        OutlinedButton.icon(
                          key: const Key('ptsimp_swap'),
                          onPressed: () {
                            final next = [...roles];
                            next[lat] = PointsRole.lon;
                            next[lon] = PointsRole.lat;
                            setState(() => o = o.copyWith(roles: next));
                          },
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: Text(t('ptsimp.swap'), style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(t('ptsimp.map'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        if (centre != null)
                          Expanded(
                            child: CustomPaint(
                              key: const Key('ptsimp_world'),
                              painter: _WorldPainter(centre, swapped, land: Cad.fg24, sea: Cad.inset, grid: Cad.fg12, dot: Cad.accent, ring: Cad.attention),
                            ),
                          ),
                        if (centre != null) const SizedBox(width: 8),
                        Expanded(
                          child: CustomPaint(
                            key: const Key('ptsimp_local'),
                            painter: _LocalPainter(pts, projectBox, area: Cad.fg24, point: Cad.accent, frame: Cad.divider),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (centre != null) Text(t('ptsimp.centre', {'lat': fmtUi(centre.$1, 5), 'lon': fmtUi(centre.$2, 5)}), key: const Key('ptsimp_centre'), style: const TextStyle(fontSize: 11.5)),
                  if (swapped != null) Text(t('ptsimp.swappedHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  if (farKm != null)
                    Text(
                      t('ptsimp.far', {'km': fmtUi(farKm, 0)}),
                      key: const Key('ptsimp_far'),
                      style: TextStyle(fontSize: 11.5, color: Cad.attention),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    problem ?? t('ptsimp.count', {'n': '${r!.count}', 's': '$skipped'}),
                    key: const Key('ptsimp_count'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: problem != null ? Cad.attention : null),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('ptsimp_import'),
              onPressed: problem != null
                  ? null
                  : () {
                      try {
                        Navigator.pop(ctx, c.importPointsWith(text, o));
                      } on FormatException catch (e) {
                        c.notify(c.t('msg.error', {'e': c.describeError(e)}));
                      }
                    },
              child: Text(t('ptsimp.import')),
            ),
          ],
        );
      },
    ),
  );
  epsgCtl.dispose();
  return result;
}

/// Rough outlines of the continents (longitude, latitude), for a map that
/// only has to say on which part of the world the points fall.
const _continents = <List<(double, double)>>[
  // South America
  [
    (-81, 8),
    (-72, 12),
    (-62, 10.5),
    (-51, 4),
    (-48, -1),
    (-35, -5),
    (-35, -9),
    (-39, -15),
    (-41, -22),
    (-48, -26),
    (-53, -34),
    (-58, -38),
    (-63, -41),
    (-65, -47),
    (-68, -52),
    (-73, -53),
    (-75, -48),
    (-73, -40),
    (-71, -30),
    (-70, -18),
    (-76, -14),
    (-81, -6),
    (-80, 0),
    (-77, 4),
  ],
  // North and Central America
  [
    (-168, 66),
    (-160, 71),
    (-140, 70),
    (-125, 70),
    (-95, 72),
    (-80, 73),
    (-65, 62),
    (-60, 55),
    (-52, 47),
    (-66, 44),
    (-70, 41),
    (-76, 35),
    (-81, 31),
    (-80, 25),
    (-82, 28),
    (-89, 30),
    (-97, 27),
    (-97, 21),
    (-90, 16),
    (-87, 21),
    (-88, 15),
    (-83, 9),
    (-80, 8),
    (-86, 12),
    (-92, 15),
    (-105, 20),
    (-110, 24),
    (-117, 32),
    (-124, 40),
    (-124, 48),
    (-132, 55),
    (-146, 61),
    (-158, 58),
    (-165, 61),
  ],
  // Greenland
  [(-73, 78), (-60, 82), (-30, 83), (-20, 75), (-22, 70), (-43, 60), (-52, 64), (-58, 75)],
  // Europe and Asia
  [
    (-10, 36),
    (-9, 43),
    (-2, 43.5),
    (-5, 48),
    (2, 51),
    (8, 54),
    (10, 57),
    (5, 61),
    (12, 66),
    (20, 70),
    (30, 71),
    (40, 67),
    (60, 69),
    (80, 73),
    (105, 78),
    (140, 72),
    (160, 70),
    (180, 68),
    (180, 65),
    (170, 60),
    (162, 56),
    (156, 51),
    (142, 54),
    (140, 47),
    (130, 42),
    (126, 35),
    (121, 31),
    (122, 25),
    (110, 20),
    (108, 11),
    (104, 8),
    (100, 13),
    (98, 8),
    (103, 1),
    (98, 16),
    (94, 17),
    (90, 22),
    (80, 15),
    (77, 8),
    (73, 17),
    (67, 25),
    (57, 25),
    (55, 22),
    (59, 22),
    (52, 16),
    (43, 13),
    (39, 21),
    (34, 28),
    (32, 31),
    (35, 36),
    (27, 37),
    (26, 40),
    (23, 37),
    (20, 40),
    (13, 45),
    (16, 38),
    (12, 38),
    (8, 44),
    (3, 43),
    (-5, 36),
  ],
  // Africa
  [
    (-17, 21),
    (-13, 27),
    (-9, 33),
    (-6, 36),
    (10, 37),
    (11, 33),
    (20, 31),
    (25, 32),
    (32, 31),
    (34, 28),
    (38, 18),
    (43, 12),
    (51, 12),
    (51, 4),
    (40, -3),
    (40, -10),
    (35, -24),
    (33, -27),
    (28, -33),
    (20, -35),
    (18, -31),
    (12, -18),
    (14, -10),
    (9, -1),
    (9, 4),
    (5, 6),
    (-8, 4.5),
    (-13, 8),
    (-17, 14),
  ],
  // Madagascar, Great Britain, Japan, Borneo, Sumatra, New Guinea
  [(44, -25), (47, -25), (50, -15), (49, -12), (44, -17)],
  [(-6, 50), (2, 51), (-1, 57), (-3, 58.5), (-6, 57), (-5, 54)],
  [(130, 31), (141, 36), (141, 42), (145, 44), (141, 45), (139, 40), (135, 34), (130, 33)],
  [(109, 2), (117, 7), (119, 1), (116, -4), (110, -3)],
  [(95, 5), (106, -6), (102, -5)],
  [(131, -1), (141, -2), (150, -10), (141, -9)],
  // Australia, New Zealand
  [(114, -22), (122, -18), (130, -12), (137, -12), (142, -11), (146, -19), (153, -26), (150, -37), (141, -38), (135, -34), (129, -32), (116, -35), (114, -28)],
  [(172, -34), (178, -38), (174, -42), (167, -46), (171, -41)],
  // Antarctica
  [(-180, -66), (-60, -64), (0, -70), (60, -67), (120, -66), (180, -66), (180, -90), (-180, -90)],
];

/// A world map (plate carrée) with the centre of the points and, as a
/// ring, where the other order of latitude and longitude would put it.
class _WorldPainter extends CustomPainter {
  _WorldPainter(this.at, this.swapped, {required this.land, required this.sea, required this.grid, required this.dot, required this.ring});
  final (double, double) at;
  final (double, double)? swapped;
  final Color land, sea, grid, dot, ring;

  @override
  void paint(Canvas canvas, Size size) {
    // 2:1 within the box
    final w = math.min(size.width, size.height * 2), h = w / 2;
    final ox = (size.width - w) / 2, oy = (size.height - h) / 2;
    Offset map(double lat, double lon) => Offset(ox + (lon + 180) / 360 * w, oy + (90 - lat) / 180 * h);
    canvas.drawRect(Rect.fromLTWH(ox, oy, w, h), Paint()..color = sea);
    final g = Paint()
      ..color = grid
      ..strokeWidth = 0.6;
    for (var lat = -60; lat <= 60; lat += 30) {
      canvas.drawLine(map(lat.toDouble(), -180), map(lat.toDouble(), 180), g);
    }
    for (var lon = -120; lon <= 120; lon += 60) {
      canvas.drawLine(map(90, lon.toDouble()), map(-90, lon.toDouble()), g);
    }
    final fill = Paint()..color = land;
    for (final c in _continents) {
      final path = Path()..moveTo(map(c.first.$2, c.first.$1).dx, map(c.first.$2, c.first.$1).dy);
      for (final (lon, lat) in c.skip(1)) {
        final p = map(lat, lon);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), fill);
    }
    final s = swapped;
    if (s != null) {
      canvas.drawCircle(
        map(s.$1, s.$2),
        5,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    canvas.drawCircle(map(at.$1.clamp(-90, 90).toDouble(), at.$2.clamp(-180, 180).toDouble()), 4, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.at != at || old.swapped != swapped || old.land != land || old.dot != dot;
}

/// The points of the import against the area of the project.
class _LocalPainter extends CustomPainter {
  _LocalPainter(this.points, this.project, {required this.area, required this.point, required this.frame});
  final List<Pt> points;
  final Bounds project;
  final Color area, point, frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke,
    );
    var b = Bounds.ofPoints(points);
    if (!project.isEmpty) b = b.union(project);
    if (b.isEmpty) return;
    final span = math.max(math.max(b.maxX - b.minX, b.maxY - b.minY), 1e-6);
    final k = math.min(size.width, size.height) * 0.9 / span;
    final cx = (b.minX + b.maxX) / 2, cy = (b.minY + b.maxY) / 2;
    Offset map(Pt p) => Offset(size.width / 2 + (p.x - cx) * k, size.height / 2 - (p.y - cy) * k);
    if (!project.isEmpty) {
      canvas.drawRect(Rect.fromPoints(map(Pt(project.minX, project.minY)), map(Pt(project.maxX, project.maxY))), Paint()..color = area);
    }
    final p = Paint()..color = point;
    // at most a few thousand dots
    final step = math.max(1, points.length ~/ 4000);
    for (var i = 0; i < points.length; i += step) {
      canvas.drawCircle(map(points[i]), 1.6, p);
    }
  }

  @override
  bool shouldRepaint(_LocalPainter old) => !identical(old.points, points) || old.project != project || old.point != point;
}
