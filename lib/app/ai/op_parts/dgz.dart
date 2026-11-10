/// Operations (find_operations / run_operation) added in 1.7.0 for the
/// curves of a chart (Design → Digitise a curve from a picture): the
/// assistant reads the chart of an attached picture with its own vision and
/// hands the points here, which fit them as the dialog does and put the
/// same pump, outlet or profile entries into the catalogue ([OpTool]s built
/// like those of lib/app/ai/ops_cad_*.dart, joined to
/// [AgentToolbox.operations]).
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/curve_digitiser.dart';
import '../../../core/design/curve_fits.dart';
import '../../../core/model/catalog.dart';
import '../../../core/units.dart';
import '../../project_name.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../ops_eng_common.dart' show engFileSink, engN, engNotBusy, engPairs, engTable;

const _kinds = ['pump', 'emitter', 'profile'];

/// The points of a chart as the operations take them: each curve in the
/// units given, and in the engine's.
class _ChartInput {
  _ChartInput(this.kind, this.units, this.curves);
  final CurveKind kind;

  /// The unit of every quantity of the chart.
  final Map<ChartQuantity, AxisUnit> units;

  /// Curve → points (horizontal, vertical) in [units].
  final Map<CurveRole, List<(double, double)>> curves;

  /// Curve → points in the engine's units ((H, q) for an outlet).
  List<(double, double)> si(CurveRole r) {
    final (xq, yq) = quantitiesOf(r);
    final ux = units[xq]!, uy = units[yq]!;
    return [for (final (x, y) in curves[r] ?? const <(double, double)>[]) (ux.toSi(x), uy.toSi(y))];
  }

  PumpChartFit pump() => fitPumpChart(head: si(CurveRole.head), efficiency: si(CurveRole.efficiency), npsh: si(CurveRole.npsh), power: si(CurveRole.power));
  EmitterChartFit emitter() => fitEmitterChart(si(CurveRole.flowPressure));
  ProfileChartFit profile() => fitProfileChart(si(CurveRole.profile));

  String label(ChartQuantity q) => units[q]!.label;
}

/// The input keys of each curve.
const _curveKeys = {
  CurveRole.head: 'head',
  CurveRole.efficiency: 'efficiency',
  CurveRole.npsh: 'npsh',
  CurveRole.power: 'power',
  CurveRole.flowPressure: 'flow_pressure',
  CurveRole.profile: 'profile',
};

_ChartInput _read(ToolArgs a, Map<String, dynamic> i) {
  final kindName = a.str('kind', required: true)!;
  if (!_kinds.contains(kindName)) throw ToolInputError('"kind" must be one of ${_kinds.join(', ')}.');
  final kind = CurveKind.values.byName(kindName);
  AxisUnit unit(ChartQuantity q, String key, String def) {
    final code = a.str(key) ?? def;
    final u = AxisUnit.of(q, code);
    if (u == null) throw ToolInputError('"$key" must be one of ${[for (final x in AxisUnit.all(q)) x.code].join(', ')}.');
    return u;
  }

  final units = {
    ChartQuantity.flow: unit(ChartQuantity.flow, 'flow_unit', kind == CurveKind.pump ? 'm3h' : 'lph'),
    ChartQuantity.head: unit(ChartQuantity.head, 'pressure_unit', 'mH2O'),
    ChartQuantity.power: unit(ChartQuantity.power, 'power_unit', 'kw'),
    ChartQuantity.efficiency: unit(ChartQuantity.efficiency, 'efficiency_unit', 'pct'),
    ChartQuantity.distance: unit(ChartQuantity.distance, 'distance_unit', 'm'),
    ChartQuantity.rate: unit(ChartQuantity.rate, 'rate_unit', 'mmh'),
  };
  final curves = <CurveRole, List<(double, double)>>{};
  for (final r in rolesOf(kind)) {
    final pts = engPairs(i[_curveKeys[r]], _curveKeys[r]!, maxItems: 500);
    if (pts != null) curves[r] = pts;
  }
  for (final e in _curveKeys.entries) {
    if (!rolesOf(kind).contains(e.key) && i[e.value] != null) {
      throw ToolInputError('"${e.value}" is not a curve of a $kindName chart: give ${[for (final r in rolesOf(kind)) _curveKeys[r]].join(', ')}.');
    }
  }
  if (curves.isEmpty) throw ToolInputError('No points: give ${[for (final r in rolesOf(kind)) '"${_curveKeys[r]}"'].join(' or ')} as [[x, y], …].');
  return _ChartInput(kind, units, curves);
}

/// What the fit of [ci] gives, for the model.
String _report(_ChartInput ci) {
  final out = StringBuffer();
  final fu = ci.units[ChartQuantity.flow]!, hu = ci.units[ChartQuantity.head]!;
  switch (ci.kind) {
    case CurveKind.pump:
      final f = ci.pump();
      final curve = f.curve;
      if (curve == null) {
        out.write('Head curve: ${f.head.length} usable points (at least $minPumpHeadPoints for a new pump).');
      } else {
        out.write(
          'Head curve: ${f.head.length} points, ${curve.throughPoints ? 'the monotone cubic through the points (no parabola stands for them within 3 % of the highest head, ISO 9906 grade 1B)' : 'least-squares parabola H = ${engN(curve.a, 2)}·Q² + ${engN(curve.b, 3)}·Q + ${engN(curve.c, 3)} (Q m³/s, H m)'}; '
          'largest residual ${engN(hu.fromSi(f.maxGap), 3)} ${hu.label} (${engN(f.topHead > 0 ? f.maxGap / f.topHead * 100 : 0, 1)} % of the highest head), RMS ${engN(hu.fromSi(f.rmsGap), 3)} ${hu.label}; '
          'shutoff ${engN(hu.fromSi(curve.shutoffHead), 2)} ${hu.label}${curve.runoutFlow.isFinite ? ', runout ${engN(fu.fromSi(curve.runoutFlow), 2)} ${fu.label}' : ''}.',
        );
        final rows = [
          for (var k = 0; k < f.head.length; k++) [engN(fu.fromSi(f.head[k].$1), 3), engN(hu.fromSi(f.head[k].$2), 3), engN(hu.fromSi(curve.head(f.head[k].$1)), 3), engN(hu.fromSi(f.headGaps[k]), 3)],
        ];
        out.write('\n${engTable(['Q ${fu.label}', 'H ${hu.label}', 'fit', 'residual'], rows)}');
      }
      if (f.bestEfficiency != null) {
        out.write('\nEfficiency: ${f.efficiency.length} points${f.efficiencyFromPower ? ' from the shaft power and the head curve (η = ρgQH/P)' : ''}, best ${engN(f.bestEfficiency! * 100, 1)} %.');
      }
      if (f.rejectedEfficiency > 0) out.write(' ${f.rejectedEfficiency} power points left out (outside the head curve\'s flows, or an efficiency above 100 %: check the power unit).');
      if (f.npsh.isNotEmpty) out.write('\nNPSH required: ${f.npsh.length} points, ${engN(hu.fromSi(f.npsh.first.$2), 2)} to ${engN(hu.fromSi(f.npsh.last.$2), 2)} ${hu.label}.');
      if (f.maxPowerKw != null) out.write('\nShaft power: ${f.power.length} points, largest ${engN(f.maxPowerKw!, 2)} kW.');
    case CurveKind.emitter:
      final f = ci.emitter();
      if (!f.isUsable) return 'Flow–pressure: ${f.points.length} usable points (pressure and flow above zero); at least $minCurvePoints are needed.';
      out.write(
        'q = k·H^x: k ${engN(f.curve.k / m3sPerLph, 5)} L/h per m^x, x ${engN(f.curve.x, 4)} (H in m); largest flow error ${engN(f.fit.maxFlowError * 100, 2)} %; pressures ${engN(hu.fromSi(f.minHead), 2)} to ${engN(hu.fromSi(f.maxHead), 2)} ${hu.label}.',
      );
      final rows = [
        for (var k = 0; k < f.points.length; k++)
          [engN(hu.fromSi(f.points[k].$1), 3), engN(fu.fromSi(f.points[k].$2), 4), engN(fu.fromSi(f.curve.flow(f.points[k].$1)), 4), '${engN(f.gaps[k] * 100, 2)} %'],
      ];
      out.write('\n${engTable(['p ${hu.label}', 'q ${fu.label}', 'fit', 'error'], rows)}');
    case CurveKind.profile:
      final f = ci.profile();
      final du = ci.units[ChartQuantity.distance]!, ru = ci.units[ChartQuantity.rate]!;
      if (!f.isUsable) return 'Profile: ${f.points.length} points; at least $minCurvePoints with water are needed.';
      out.write(
        'Profile: wetted radius read ${engN(du.fromSi(f.radiusM), 2)} ${du.label}, largest rate ${engN(ru.fromSi(f.peakRate), 2)} ${ru.label}; ${f.profile!.length} stations as the nozzle keeps them (distance / radius, rate / largest):',
      );
      out.write(
        '\n${engTable(['d / R', 'rate / max'], [
          for (final (x, y) in f.profile!) [engN(x, 3), engN(y, 3)],
        ])}',
      );
  }
  return out.toString();
}

const _desc =
    'Design → Digitise a curve from a picture: the dialog reads a catalogue chart by clicks (two points per axis, linear or logarithmic, rotated or sheared pictures) or by following the curve\'s colour. You read the chart yourself from an attached picture (your vision): give the points as [[x, y], …] in the chart\'s own units, about 8–20 along each curve, from the first to the last flow drawn.';

const _unitsDesc =
    'Units (defaults): flow_unit lph|lpm|lps|m3h|gpm (m3h for a pump, lph for an emitter), pressure_unit mH2O|kPa|bar|psi|ftH2O|kgfcm2 (mH2O; also the NPSH), power_unit kw|hp|cv (kw), efficiency_unit pct|fraction (pct), distance_unit m|mm|cm|ft|inch (m), rate_unit mmh|inh (mmh).';

List<AgentTool> opsDgz(AgentToolbox b) {
  final c = b.c;
  Map<String, Object?> pairs(String d) => {
    'type': 'array',
    'items': {
      'type': 'array',
      'items': {'type': 'number'},
    },
    'description': d,
  };
  final chart = <String, Object?>{
    'kind': str(
      'pump (head, efficiency, npsh, power against flow), emitter (an outlet\'s, sprinkler\'s or dripline\'s flow against pressure), profile (a sprinkler\'s application rate against the distance from it).',
      _kinds,
    ),
    'flow_unit': str('Unit of the flows.', [for (final f in FlowUnit.values) f.name]),
    'pressure_unit': str('Unit of the heads, pressures and NPSH.', [for (final p in PressureUnit.values) p.name]),
    'power_unit': str('Unit of the power.', const ['kw', 'hp', 'cv']),
    'efficiency_unit': str('Unit of the efficiency.', const ['pct', 'fraction']),
    'distance_unit': str('Unit of the distances.', [for (final l in LengthUnit.values) l.name]),
    'rate_unit': str('Unit of the application rate.', const ['mmh', 'inh']),
    'head': pairs('pump: [[flow, head], …] along the head curve (one impeller diameter, one speed).'),
    'efficiency': pairs('pump: [[flow, efficiency], …].'),
    'npsh': pairs('pump: [[flow, NPSH required], …].'),
    'power': pairs('pump: [[flow, shaft power], …] (gives the efficiency when no efficiency curve is given).'),
    'flow_pressure': pairs('emitter: [[pressure, flow], …].'),
    'profile': pairs('profile: [[distance from the head, application rate], …], to where the rate falls to zero.'),
  };
  return [
    cadOp(
      b,
      group: 'engineering',
      name: 'fit_curve_points',
      description:
          '$_desc This fits them as the dialog does, without changing anything: a pump\'s head curve with the engine\'s fit (the least-squares parabola within 3 % of the highest head, else the monotone curve through the points) and its residuals, the efficiency (or the one of the shaft power, η = ρgQH/P), NPSH and power; an emitter\'s q = k·H^x (least squares in log–log) and its errors; a sprinkler\'s radial profile scaled as the densogram reads it. Check the fit, then apply_curve_points. $_unitsDesc Output: the fit and a table of the points with their residuals.',
      schema: obj(chart, required: ['kind']),
      run: (a, i) async => ToolOutput(_report(_read(a, i))),
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'apply_curve_points',
      effect: ToolEffect.write,
      description:
          '$_desc Puts the curves into the catalogue in one undo step, as the dialog\'s Apply: pump — a new pump named "name" (at least $minPumpHeadPoints head points), or the pump "pump_id" updated (the head curve replaces its curve and its range of flows, efficiency and NPSH replace its own, the best efficiency becomes its single one, the largest shaft power its rated power when it has none); emitter — a new outlet named "name" of "outlet_kind" (one nozzle, the chart\'s pressures as its range, the middle one as its default), or the nozzle "nozzle_id" of outlet "outlet_id" (k and x change; its wetted radius stays), or the emitter of drip tape "tape_id"; profile — the measured profile of the nozzle "nozzle_id" of outlet "outlet_id" (search_catalog gives the ids). The design results are discarded. $_unitsDesc Output: what was set and the fit.',
      schema: obj(
        {
          ...chart,
          'name': str('Name of a new pump or outlet.'),
          'pump_id': str('pump: the pump to update (omitted: a new one).'),
          'outlet_id': str('emitter or profile: the outlet whose nozzle is updated.'),
          'nozzle_id': str('emitter or profile: the nozzle of outlet_id (default its first).'),
          'tape_id': str('emitter: the drip tape whose emitter is updated.'),
          'outlet_kind': str('emitter: the kind of a new outlet (default dripper).', const ['dripper', 'microSprinkler', 'sprinkler', 'bubbler', 'gun']),
        },
        required: ['kind'],
      ),
      run: (a, i) async {
        engNotBusy(c);
        final ci = _read(a, i);
        final cat = b.p.catalog;
        final name = a.str('name')?.trim() ?? '';
        String nozzleOf() {
          final oid = a.str('outlet_id', required: true)!;
          final o = cat.outlet(oid);
          if (o == null) throw ToolInputError('No outlet "$oid" (search_catalog kind emitter).');
          final nid = a.str('nozzle_id');
          final n = o.nozzle(nid);
          if (n == null || (nid != null && n.id != nid)) throw ToolInputError('Outlet "$oid" has no nozzle "$nid": ${o.nozzles.map((x) => x.id).join(', ')}.');
          return n.id;
        }

        NozzleSpec nozzleIn(Catalog k, String oid, String nid) => k.outlet(oid)!.nozzles.firstWhere((x) => x.id == nid);
        final String done;
        switch (ci.kind) {
          case CurveKind.pump:
            final f = ci.pump();
            final pid = a.str('pump_id');
            if (pid != null && cat.pump(pid) == null) throw ToolInputError('No pump "$pid" (search_catalog kind pump).');
            if (pid == null && name.isEmpty) throw ToolInputError('Give "name" for a new pump, or "pump_id" to update one.');
            if (pid == null && f.head.length < minPumpHeadPoints) throw ToolInputError('A new pump needs at least $minPumpHeadPoints head points [flow, head].');
            if (f.isEmpty) throw ToolInputError('Too few points: at least $minCurvePoints per curve.');
            final id = b.change('apply_curve_points', () => putPumpChart(b.p.catalog, f, pumpId: pid, name: pid == null ? name : '').id);
            done = '${pid == null ? 'Added' : 'Updated'} pump "$id" (${b.p.catalog.pump(id)!.name}).';
          case CurveKind.emitter:
            final f = ci.emitter();
            if (!f.isUsable) throw ToolInputError('The flow–pressure points give no law: at least $minCurvePoints points with pressure and flow above zero.');
            final tid = a.str('tape_id');
            if (tid != null) {
              if (cat.tape(tid) == null) throw ToolInputError('No drip tape "$tid" (search_catalog kind tape).');
              b.change('apply_curve_points', () {
                putTapeEmitter(b.p.catalog.tape(tid)!, f);
                return true;
              });
              done = 'Updated the emitter of tape "$tid".';
            } else if (a.has('outlet_id')) {
              final oid = a.str('outlet_id')!;
              final nid = nozzleOf();
              b.change('apply_curve_points', () {
                putNozzleCurve(nozzleIn(b.p.catalog, oid, nid), f);
                return true;
              });
              done = 'Updated nozzle "$nid" of outlet "$oid" (its wetted radius kept).';
            } else {
              if (name.isEmpty) throw ToolInputError('Give "name" for a new outlet, or "outlet_id" (and "nozzle_id") or "tape_id" to update one.');
              final kindName = a.str('outlet_kind') ?? 'dripper';
              final kind = OutletKind.values.where((k) => k.name == kindName && k != OutletKind.demandPoint).firstOrNull;
              if (kind == null) throw ToolInputError('"outlet_kind" must be dripper, microSprinkler, sprinkler, bubbler or gun.');
              final fu = ci.units[ChartQuantity.flow]!, hu = ci.units[ChartQuantity.head]!;
              final mid = (f.minHead + f.maxHead) / 2;
              final nozzleName = '${engN(fu.fromSi(f.curve.flow(mid)), 2)} ${fu.label} @ ${engN(hu.fromSi(mid), 2)} ${hu.label}';
              final id = b.change('apply_curve_points', () => putNewOutlet(b.p.catalog, f, name: name, kind: kind, nozzleName: nozzleName).id);
              done = 'Added outlet "$id" ($name, ${kind.name}) with nozzle "${id}_n1" ($nozzleName).';
            }
          case CurveKind.profile:
            final f = ci.profile();
            if (!f.isUsable) throw ToolInputError('The profile needs at least $minCurvePoints points with water.');
            final oid = a.str('outlet_id', required: true)!;
            final nid = nozzleOf();
            b.change('apply_curve_points', () {
              putNozzleProfile(nozzleIn(b.p.catalog, oid, nid), f);
              return true;
            });
            done = 'Set the measured profile of nozzle "$nid" of outlet "$oid" (the densogram uses it when "measured profiles" is on).';
        }
        return ToolOutput('$done\n${_report(ci)}');
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'export_curve_points',
      effect: ToolEffect.export,
      description:
          '$_desc Writes the points as the dialog\'s Export CSV does (UTF-8, semicolons, decimal points; one row per point: curve; x; y; x unit; y unit), for the user to keep or open in a spreadsheet; the dialog\'s Copy puts the same points on the clipboard, tab-separated. Always confirmed by the user (a download). $_unitsDesc Output: the file name.',
      schema: obj(chart, required: ['kind']),
      run: (a, i) async {
        final ci = _read(a, i);
        final t = b.t;
        final cols = <CurveColumns>[
          for (final r in rolesOf(ci.kind))
            if (ci.curves[r] case final pts?)
              () {
                final (xq, yq) = quantitiesOf(r);
                return (name: t('dgz.role.${r.name}'), x: ci.label(xq), y: ci.label(yq), points: pts);
              }(),
        ];
        final file = '${projectFileStem(t, b.p.meta.name)}_${t('dgz.file')}.csv';
        await engFileSink(c, file, 'text/csv', curvePointsCsv(cols));
        return ToolOutput('Saved $file (${cols.fold<int>(0, (n, x) => n + x.points.length)} points).');
      },
    ),
  ];
}
