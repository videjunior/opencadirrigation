/// An ICC colour profile of the sRGB space (IEC 61966-2-1), built here
/// rather than shipped: the output intent of PDF/A documents
/// (ISO 19005-2, 6.2.3) names the colour space of their DeviceRGB
/// colours with it. A version 2.1 display profile: the sRGB primaries
/// adapted to the D50 of the profile connection space (Bradford), the D65
/// white of the display and the sRGB tone curve as a 1024-entry table.
///
/// Reference: ICC.1:2001-04 (version 2 profile format); IEC 61966-2-1:1999.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The profile's bytes (3 KB).
Uint8List srgbIccProfile() => _profile ??= _build();
Uint8List? _profile;

Uint8List _build() {
  final tags = <(String, List<int>)>[];
  List<int> s15(double v) {
    final x = (v * 65536).round();
    final u = x < 0 ? x + 4294967296 : x;
    return [(u >> 24) & 0xFF, (u >> 16) & 0xFF, (u >> 8) & 0xFF, u & 0xFF];
  }

  List<int> be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  List<int> sig(String s) => s.codeUnits;
  List<int> xyz(double x, double y, double z) => [...sig('XYZ '), 0, 0, 0, 0, ...s15(x), ...s15(y), ...s15(z)];
  // textDescriptionType: ASCII, then empty Unicode and ScriptCode descriptions
  List<int> desc(String text) => [...sig('desc'), 0, 0, 0, 0, ...be32(text.length + 1), ...text.codeUnits, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...List.filled(67, 0)];
  List<int> text(String t) => [...sig('text'), 0, 0, 0, 0, ...t.codeUnits, 0];
  // the sRGB transfer function, decoded (display values to linear light)
  final curve = <int>[...sig('curv'), 0, 0, 0, 0, ...be32(1024)];
  for (var i = 0; i < 1024; i++) {
    final v = i / 1023;
    final lin = v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final u = (lin * 65535).round();
    curve
      ..add((u >> 8) & 0xFF)
      ..add(u & 0xFF);
  }
  tags
    ..add(('desc', desc('sRGB IEC61966-2.1')))
    ..add(('cprt', text('No copyright, use freely')))
    ..add(('wtpt', xyz(0.950455, 1.0, 1.089050)))
    ..add(('rXYZ', xyz(0.436066, 0.222488, 0.013916)))
    ..add(('gXYZ', xyz(0.385147, 0.716873, 0.097076)))
    ..add(('bXYZ', xyz(0.143066, 0.060608, 0.714096)))
    ..add(('rTRC', curve))
    ..add(('gTRC', curve))
    ..add(('bTRC', curve));
  // tag data after the header and the table, each 4-byte aligned; the three
  // curves share one copy
  final table = 4 + 12 * tags.length;
  var at = 128 + table;
  final data = BytesBuilder();
  final placed = <List<int>, (int, int)>{};
  final entries = <(String, int, int)>[];
  for (final (name, bytes) in tags) {
    final known = placed[bytes];
    if (known != null) {
      entries.add((name, known.$1, known.$2));
      continue;
    }
    entries.add((name, at, bytes.length));
    placed[bytes] = (at, bytes.length);
    data.add(bytes);
    at += bytes.length;
    while (at % 4 != 0) {
      data.addByte(0);
      at++;
    }
  }
  final size = at;
  final b = BytesBuilder()
    ..add(be32(size))
    ..add(const [0, 0, 0, 0]) // preferred CMM
    ..add(be32(0x02100000)) // version 2.1
    ..add(sig('mntr'))
    ..add(sig('RGB '))
    ..add(sig('XYZ '))
    ..add(const [0x07, 0xCE, 0, 2, 0, 9, 0, 6, 0, 49, 0, 0]) // 1998-02-09 06:49:00
    ..add(sig('acsp'))
    ..add(const [0, 0, 0, 0]) // platform
    ..add(const [0, 0, 0, 0]) // flags
    ..add(const [0, 0, 0, 0, 0, 0, 0, 0]) // device manufacturer and model
    ..add(List.filled(8, 0)) // device attributes
    ..add(be32(0)) // perceptual intent
    ..add([...s15(0.9642), ...s15(1.0), ...s15(0.8249)]) // D50 illuminant of the PCS
    ..add(const [0, 0, 0, 0]) // creator
    ..add(List.filled(44, 0)); // profile id and reserved
  b.add(be32(tags.length));
  for (final (name, offset, length) in entries) {
    b
      ..add(sig(name))
      ..add(be32(offset))
      ..add(be32(length));
  }
  b.add(data.toBytes());
  return b.toBytes();
}
