/// Hydraulic data carried by the DXF and DWG exports as extended entity
/// data (XDATA, registered application [xdataApp]): every pipe, lateral,
/// drip line and hydraulic item keeps, on its polyline or block reference,
/// what a CAD user wants to query and tabulate (kind, catalogue item,
/// nominal and inner diameter, length, and with design results the flow,
/// velocity, head loss and pressures), plus the item itself in the
/// program's own format, so a drawing exported by the app and imported
/// again comes back as pipes and items, not as lines and circles.
///
/// The groups follow the XDATA conventions: 1001 the application, then
/// pairs of a 1000 name and its value (1000 text, 1040 real); the item is
/// a 1000 `JSON` followed by 1002 `{`, 1000 chunks of at most 250 ASCII
/// characters (non-ASCII characters and spaces as JSON escapes: a DXF
/// reader may trim the values) and 1002 `}`. What is drawn for an item
/// besides its own entity (the label of a pipe, the name of a valve, the
/// outlet symbols of a lateral) carries only `PART_OF` and the item's id
/// ([partXdata]): an import that restores the item leaves it out.
library;

import 'dart:convert';

import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';

/// The registered application name of the XDATA (APPID table).
const xdataApp = 'OPENCADIRRIGATION';

/// First string of the data: the format and its version.
const xdataSignature = 'OCI:1';

/// One XDATA group: its code (1000 text, 1002 brace, 1040 real, 1070
/// 16-bit integer) and value (String or double or int).
typedef XGroup = (int, Object);

/// The XDATA groups (after the 1001 application group) of hydraulic item
/// [e] of [project]; [results] add the flows and pressures. Empty for an
/// item that is not hydraulic.
List<XGroup> hydraulicXdata(Entity e, Project project, DesignResults? results) {
  final cat = project.catalog;
  final out = <XGroup>[(1000, xdataSignature)];
  void s(String key, String value) {
    if (value.isEmpty) return;
    out
      ..add((1000, key))
      ..add((1000, _ascii(value, 250)));
  }

  void n(String key, double? value, [int decimals = 4]) {
    if (value == null || !value.isFinite) return;
    out
      ..add((1000, key))
      ..add((1040, double.parse(value.toStringAsFixed(decimals))));
  }

  final String kind;
  final Map<String, dynamic> json;
  switch (e) {
    case PipeEntity p:
      kind = p.scope == HydraulicScope.zone ? 'zone_pipe' : 'mainline_pipe';
      final spec = cat.pipe(p.pipeSpecId);
      s('KIND', kind);
      s('ID', p.id);
      s('NAME', p.name);
      s('ITEM', spec?.name ?? '');
      n('DN_MM', spec?.nominalMm);
      n('ID_MM', spec?.innerDiameterMm);
      n('LENGTH_M', p.length, 3);
      _pipeResults(results?.pipesByEntity[p.id], n);
      json = p.toJson()..remove('pts');
    case SpraylineEntity l:
      kind = 'lateral';
      final spec = cat.pipe(l.pipeSpecId), outlet = cat.outlet(l.outletSpecId);
      s('KIND', kind);
      s('ID', l.id);
      s('NAME', l.name);
      s('ITEM', spec?.name ?? '');
      s('OUTLET', outlet?.name ?? '');
      n('DN_MM', spec?.nominalMm);
      n('ID_MM', spec?.innerDiameterMm);
      n('LENGTH_M', l.length, 3);
      n('SPACING_M', l.spacing, 3);
      _pipeResults(results?.pipesByEntity[l.id], n);
      _outletResults(results?.outletsByEntity[l.id], n);
      json = l.toJson()..remove('pts');
    case TapeEntity t:
      kind = 'drip_line';
      final spec = cat.tape(t.tapeSpecId);
      s('KIND', kind);
      s('ID', t.id);
      s('NAME', t.name);
      s('ITEM', spec?.name ?? '');
      n('LENGTH_M', t.length, 3);
      _pipeResults(results?.pipesByEntity[t.id], n);
      _outletResults(results?.outletsByEntity[t.id], n);
      json = t.toJson()..remove('pts');
    case OutletEntity o:
      kind = 'outlet';
      final spec = cat.outlet(o.outletSpecId);
      s('KIND', kind);
      s('ID', o.id);
      s('NAME', o.name);
      s('ITEM', spec?.name ?? '');
      s('NOZZLE', spec?.nozzle(o.nozzleId)?.name ?? '');
      _outletResults(results?.outletsByEntity[o.id], n);
      json = o.toJson()..remove('p');
    case ControlValveEntity v:
      kind = 'zone_valve';
      s('KIND', kind);
      s('ID', v.id);
      s('NAME', v.name);
      s('ZONE', v.zoneName);
      s('ITEM', cat.valve(v.valveSpecId)?.name ?? '');
      final z = results?.zones[v.id];
      if (z != null) {
        n('FLOW_M3H', z.totalFlow * 3600, 3);
        n('PRESSURE_REQUIRED_M', z.requiredUpstreamHead, 2);
        n('VALVE_LOSS_M', z.valveLoss, 2);
      }
      json = v.toJson()..remove('p');
    case PumpEntity p:
      kind = 'pump';
      s('KIND', kind);
      s('ID', p.id);
      s('NAME', p.name);
      s('ITEM', cat.pump(p.pumpSpecId)?.name ?? '');
      json = p.toJson()..remove('p');
    case WaterSupplyEntity w:
      kind = 'supply';
      s('KIND', kind);
      s('ID', w.id);
      s('NAME', w.name);
      json = w.toJson()..remove('p');
    case MiscHydraulicEntity m:
      kind = 'device';
      s('KIND', kind);
      s('ID', m.id);
      s('NAME', m.name);
      s('ITEM', cat.valve(m.valveSpecId)?.name ?? '');
      json = m.toJson()..remove('p');
    case JunctionEntity j:
      kind = 'junction';
      s('KIND', kind);
      s('ID', j.id);
      s('NAME', j.name);
      json = j.toJson()..remove('p');
    default:
      return const [];
  }
  // the item in the program's own format, its geometry left to the CAD entity
  final text = _asciiJson(jsonEncode(json));
  out
    ..add((1000, 'JSON'))
    ..add((1002, '{'));
  for (var i = 0; i < text.length; i += 250) {
    out.add((1000, text.substring(i, i + 250 > text.length ? text.length : i + 250)));
  }
  out.add((1002, '}'));
  return out;
}

/// The XDATA groups of a CAD entity drawn for hydraulic item [ownerId]
/// (its label, the outlet symbols of a lateral).
List<XGroup> partXdata(String ownerId) => [(1000, xdataSignature), (1000, 'PART_OF'), (1000, _ascii(ownerId, 250))];

void _pipeResults(List<PipeSegmentResult>? segs, void Function(String, double?, [int]) n) {
  if (segs == null || segs.isEmpty) return;
  var q = 0.0, v = 0.0, hl = 0.0, pMin = double.infinity, pMax = -double.infinity;
  for (final s in segs) {
    if (s.flow.abs() > q.abs()) q = s.flow;
    if (s.velocity.abs() > v.abs()) v = s.velocity;
    hl += s.headLoss;
    for (final p in [s.pressureStart, s.pressureEnd]) {
      if (p < pMin) pMin = p;
      if (p > pMax) pMax = p;
    }
  }
  n('FLOW_M3H', q.abs() * 3600, 3);
  n('VELOCITY_MS', v.abs(), 3);
  n('HEADLOSS_M', hl, 3);
  n('PRESSURE_IN_M', segs.first.pressureStart, 2);
  n('PRESSURE_OUT_M', segs.last.pressureEnd, 2);
  n('PRESSURE_MIN_M', pMin.isFinite ? pMin : null, 2);
  n('PRESSURE_MAX_M', pMax.isFinite ? pMax : null, 2);
}

void _outletResults(List<OutletResult>? outs, void Function(String, double?, [int]) n) {
  if (outs == null || outs.isEmpty) return;
  var q = 0.0, pMin = double.infinity, pMax = -double.infinity;
  for (final o in outs) {
    q += o.flow * o.count;
    if (o.pressure < pMin) pMin = o.pressure;
    if (o.pressure > pMax) pMax = o.pressure;
  }
  n('OUTLET_FLOW_M3H', q * 3600, 4);
  n('OUTLET_PRESSURE_MIN_M', pMin, 2);
  n('OUTLET_PRESSURE_MAX_M', pMax, 2);
}

/// [s] in printable ASCII (other characters as `?`), at most [max] long.
String _ascii(String s, int max) {
  final b = StringBuffer();
  for (final r in s.runes) {
    b.writeCharCode(r >= 0x20 && r < 0x7F ? r : 0x3F);
    if (b.length >= max) break;
  }
  return b.toString();
}

/// JSON text with every character beyond ASCII as a `\uXXXX` escape (the
/// XDATA strings of the formats hold single bytes), and the spaces too (a
/// chunk must not start or end with one: DXF readers trim the values;
/// [jsonEncode] writes spaces only inside strings, where the escape holds).
String _asciiJson(String s) {
  final b = StringBuffer();
  for (final u in s.codeUnits) {
    if (u > 0x20 && u < 0x7F) {
      b.writeCharCode(u);
    } else {
      b.write('\\u${u.toRadixString(16).padLeft(4, '0')}');
    }
  }
  return b.toString();
}

/// The data of the application read back from the XDATA groups of an
/// entity ([groups]: code and text value, from its 1001 group on): the
/// named values, `JSON` the item. Null when the groups are not the app's.
Map<String, String>? readHydraulicXdata(List<(int, String)> groups) {
  var i = 0;
  // the groups of this application only
  while (i < groups.length && !(groups[i].$1 == 1001 && groups[i].$2.trim().toUpperCase() == xdataApp)) {
    i++;
  }
  if (i < groups.length) i++;
  if (i >= groups.length || groups[i].$2.trim() != xdataSignature) return null;
  i++;
  final out = <String, String>{};
  while (i < groups.length) {
    final (code, key) = groups[i];
    if (code == 1001) break;
    if (code != 1000 || i + 1 >= groups.length) {
      i++;
      continue;
    }
    if (key == 'JSON' && groups[i + 1].$1 == 1002) {
      final b = StringBuffer();
      i += 2;
      while (i < groups.length && groups[i].$1 != 1002) {
        if (groups[i].$1 == 1000) b.write(groups[i].$2);
        i++;
      }
      out['JSON'] = b.toString();
      i++;
      continue;
    }
    out[key] = groups[i + 1].$2.trim();
    i += 2;
  }
  return out;
}

/// The hydraulic item an imported entity carried in its XDATA ([data] from
/// [readHydraulicXdata]), with its geometry from the drawing: [points] of
/// a polyline (pipes, laterals, drip lines) or [position] of a block
/// reference, and the id [id] of the project it goes into; on [layer] when
/// [project] has no layer of the item's. Null when it cannot be restored:
/// not an item of the program, damaged data, or a catalogue item that
/// [project] does not have (the drawing then keeps the plain geometry).
Entity? restoreHydraulic(Map<String, String> data, Project project, {List<Pt>? points, Pt? position, required String id, String? layer}) {
  final text = data['JSON'];
  if (text == null || text.isEmpty) return null;
  final Map<String, dynamic> j;
  try {
    final v = jsonDecode(text);
    if (v is! Map<String, dynamic>) return null;
    j = v;
  } on FormatException {
    return null;
  }
  if (points != null) j['pts'] = [for (final p in points) p.toList()];
  if (position != null) j['p'] = position.toList();
  j['id'] = id;
  final Entity e;
  try {
    e = Entity.fromJson(j);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
  final cat = project.catalog;
  final ok = switch (e) {
    PipeEntity p => p.pipeSpecId == null || cat.pipe(p.pipeSpecId) != null,
    SpraylineEntity l => cat.outlet(l.outletSpecId) != null && (l.pipeSpecId == null || cat.pipe(l.pipeSpecId) != null),
    TapeEntity t => cat.tape(t.tapeSpecId) != null,
    OutletEntity o => cat.outlet(o.outletSpecId) != null,
    ControlValveEntity v => v.valveSpecId == null || cat.valve(v.valveSpecId) != null,
    PumpEntity p => p.pumpSpecId == null || cat.pump(p.pumpSpecId) != null,
    MiscHydraulicEntity m => m.valveSpecId == null || cat.valve(m.valveSpecId) != null,
    WaterSupplyEntity() || JunctionEntity() => true,
    _ => false,
  };
  if (!ok) return null;
  if (layer != null && project.findLayer(e.layer) == null) e.layer = layer;
  return e;
}
