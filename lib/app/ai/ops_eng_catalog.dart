/// Engineering operations of the catalogue (Design → Catalogue and its
/// manufacturer packs) that edit_catalog does not cover: fittings, the
/// detail fields of the items (variation coefficients, tolerances, curves,
/// losses, pump efficiency and NPSH, FINAME codes), duplicating items,
/// fitting a nozzle curve to a data-sheet table and its radial profile to a
/// catch-can test, importing an attached catalogue, exporting the
/// catalogue, the bundled and online packs, and the default catalogue.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../core/api.dart';
import '../io/catalog_packs.dart';
import '../widgets/dialogs/more_dialogs.dart' show hasSavedDefaultCatalog;
import 'agent_tools.dart';
import 'ai_safety.dart';
import 'ops_eng_common.dart';

const _kinds = ['pipe', 'emitter', 'tape', 'valve', 'pump', 'fitting', 'wire'];

/// The specs of [kind] in [cat] (typed as dynamic: the specs share no base).
List<dynamic> _listOf(Catalog cat, String kind) => switch (kind) {
  'pipe' => cat.pipes,
  'emitter' => cat.outlets,
  'tape' => cat.tapes,
  'valve' => cat.valves,
  'pump' => cat.pumps,
  'fitting' => cat.fittings,
  _ => cat.wires,
};

dynamic _item(Catalog cat, String kind, String id) {
  final x = _listOf(cat, kind).where((e) => e.id == id).firstOrNull;
  if (x == null) throw ToolInputError('No $kind "$id" in the catalogue (search_catalog kind "$kind").');
  return x;
}

String _packLine(CatalogPack p, Catalog cat) =>
    '${p.id} | ${p.brand} | ${p.itemCount} items | ${p.hasPrices ? 'priced (${p.meta.currency.isEmpty ? '?' : p.meta.currency})' : 'unpriced'} | ${p.meta.updated.isEmpty ? '-' : p.meta.updated} | ${p.isMergedInto(cat) ? 'in the project' : 'not added'}${p.origin.isEmpty ? '' : ' | from ${p.origin}'}${p.description.isEmpty ? '' : ' | ${AgentToolbox.short(p.description, 120)}'}${p.meta.sources.isEmpty ? '' : ' | sources: ${p.meta.sources.take(3).join(' · ')}'}';

List<AgentTool> catalogOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  // packs loaded from a URL in this conversation, by id
  final loaded = <String, CatalogPack>{};
  return [
    // ---------------------------------------------------------------- fittings
    engOp(
      b,
      name: 'catalog_fittings',
      effect: ToolEffect.write,
      description:
          'Design → Catalogue → Fittings (edit_catalog covers the other kinds): adds, updates, enables, disables or removes the fittings the bill of materials picks (couplers, elbows, tees, crosses, reducers, end caps, adapters, take-offs, tape ends, risers) — e.g. from a manufacturer price list. One undo step. Inputs: action add|update|enable|disable|remove; id (update/enable/disable/remove; optional for add); item {name, kind (${FittingKind.values.map((k) => k.name).join('|')}), size_mm (run size 5–2000), size2_mm (branch or reduced size; 0 = same), cost (project currency), supplier, code, material} (add; for update only the fields to change). Output: the fitting.',
      schema: obj(
        {
          'action': str(null, ['add', 'update', 'enable', 'disable', 'remove']),
          'id': str('Fitting id (search_catalog kind "fitting").'),
          'item': obj({
            'name': str('Name; default "<kind> <size> mm".'),
            'kind': str(null, [for (final k in FittingKind.values) k.name]),
            'size_mm': num_('Run size, 5–2000 mm.'),
            'size2_mm': num_('Branch or reduced size, 0–2000 mm; 0 = same.'),
            'cost': num_('Unit price, project currency.'),
            'supplier': str('Supplier or manufacturer.'),
            'code': str('Manufacturer code.'),
            'material': str('Material, e.g. PVC, PE.'),
          }),
        },
        required: ['action'],
      ),
      summary: (i) => engSummary(b, 'ai.op.catalog_fittings.${i['action']}', 'ai.op.catalog_fittings', {'n': '${(i['item'] as Map?)?['name'] ?? i['id'] ?? ''}'}),
      run: (a, i) async {
        engNotBusy(c);
        final action = a.str('action', required: true)!;
        final m = ToolArgs(i['item'] is Map ? Map<String, dynamic>.from(i['item'] as Map) : <String, dynamic>{});
        final id = a.str('id');
        final cat = b.p.catalog;
        if (action != 'add' && (id == null || cat.fitting(id) == null)) throw ToolInputError('"id" must name a fitting of the catalogue to $action (search_catalog kind "fitting").');
        switch (action) {
          case 'add':
            final kind = m.str('kind', required: true)!;
            final size = m.number('size_mm', min: 5, max: 2000, required: true)!;
            final newId = id != null && RegExp(r'^[a-zA-Z0-9_\-]{1,40}$').hasMatch(id) && cat.fitting(id) == null ? id : cat.newId('fit');
            final f = FittingSpec(
              id: newId,
              name: m.str('name') ?? '${t('fit.$kind')} ${engN(size, 0)} mm',
              kind: FittingKind.values.byName(kind),
              sizeMm: size,
              size2Mm: m.number('size2_mm', min: 0, max: 2000) ?? 0,
              cost: m.number('cost', min: 0, max: 1e9) ?? 0,
              supplier: m.str('supplier') ?? '',
              code: m.str('code') ?? '',
              material: m.str('material') ?? '',
            );
            b.change('catalog_fittings', () {
              b.p.catalog.fittings.add(f);
              return 1;
            });
            return ToolOutput('Added fitting "${f.id}" (${f.name}, ${f.kind.name} ${engN(f.sizeMm, 0)}${f.size2Mm > 0 ? '×${engN(f.size2Mm, 0)}' : ''} mm, cost ${engN(f.cost)}).');
          case 'update':
            if ((i['item'] as Map?)?.isEmpty ?? true) throw ToolInputError('"item" with the fields to change is needed to update.');
            final kind = m.str('kind');
            final size = m.number('size_mm', min: 5, max: 2000), size2 = m.number('size2_mm', min: 0, max: 2000), cost = m.number('cost', min: 0, max: 1e9);
            b.change('catalog_fittings', () {
              final f = b.p.catalog.fitting(id)!;
              f.name = m.str('name') ?? f.name;
              if (kind != null) f.kind = FittingKind.values.byName(kind);
              f.sizeMm = size ?? f.sizeMm;
              f.size2Mm = size2 ?? f.size2Mm;
              f.cost = cost ?? f.cost;
              f.supplier = m.str('supplier') ?? f.supplier;
              f.code = m.str('code') ?? f.code;
              f.material = m.str('material') ?? f.material;
              return 1;
            });
            final f = b.p.catalog.fitting(id)!;
            return ToolOutput('Updated fitting "$id" (${f.name}, ${f.kind.name} ${engN(f.sizeMm, 0)} mm, cost ${engN(f.cost)}).');
          case 'enable' || 'disable':
            b.change('catalog_fittings', () => b.p.catalog.fitting(id)!.enabled = action == 'enable');
            return ToolOutput('${action == 'enable' ? 'Enabled' : 'Disabled'} fitting "$id".');
          default:
            b.change('catalog_fittings', () {
              b.p.catalog.fittings.removeWhere((x) => x.id == id);
              return 1;
            });
            return ToolOutput('Removed fitting "$id".');
        }
      },
    ),
    // ---------------------------------------------------------------- detail fields
    engOp(
      b,
      name: 'catalog_item_details',
      effect: ToolEffect.write,
      description: 'Design → Catalogue, the detail columns edit_catalog does not take: emitter nozzles — cv (manufacturer\'s variation coefficient), flow_tol_pct (flow tolerance below and above, %), k_lph and x of the curve q = k·Hˣ (L/h per mˣ), min_head_m / max_head_m / default_head_m, arc_deg; drip tapes — barb_k (loss of the connection), cv, tol_below_pct / tol_above_pct (inlet pressure window %); valves and devices — loss_k and loss_n of the loss curve h = k·Qⁿ (Q in m³/s, h in m); pumps — efficiency_points [[flow_m3h, efficiency 0–1 or %], …] and npsh_points [[flow_m3h, NPSH required m], …] ([] removes them); any kind — finame (the BNDES FINAME code; "" removes it). One undo step; results discarded. Inputs: kind, id, nozzle (emitters; default every nozzle of the emitter) and the fields. Output: the item\'s values after the change.',
      schema: obj(
        {
          'kind': str(null, _kinds),
          'id': str('Item id (search_catalog).'),
          'nozzle': str('Emitters: nozzle id (default every nozzle).'),
          'cv': num_('Variation coefficient, 0–0.5.'),
          'flow_tol_pct': num_('Emitter flow tolerance, 0–50 %.'),
          'k_lph': num_('Emitter curve k, L/h per mˣ.'),
          'x': num_('Emitter exponent, 0–1.'),
          'min_head_m': num_('Emitter: least operating head, 0–300 m.'),
          'max_head_m': num_('Emitter: largest operating head, 0–300 m.'),
          'default_head_m': num_('Emitter: head of the rated flow, 0–300 m.'),
          'arc_deg': num_('Nozzle arc, 1–360°.'),
          'barb_k': num_('Tape: loss coefficient of the connection, 0–10.'),
          'tol_below_pct': num_('Tape: allowed drop below the inlet head, 0–60 %.'),
          'tol_above_pct': num_('Tape: allowed rise above the inlet head, 0–60 %.'),
          'loss_k': num_('Valve: k of h = k·Qⁿ (m per (m³/s)ⁿ).'),
          'loss_n': num_('Valve: n of h = k·Qⁿ, 1–3.'),
          'efficiency_points': arr(numbers('[flow_m3h, efficiency]', n: 2), 'Pump efficiency curve.', 30),
          'npsh_points': arr(numbers('[flow_m3h, npsh_m]', n: 2), 'Pump NPSH required curve.', 30),
          'finame': str('FINAME code; "" removes it.'),
        },
        required: ['kind', 'id'],
      ),
      summary: (i) => t('ai.op.catalog_item_details', {'n': '${i['id']}'}),
      run: (a, i) async {
        engNotBusy(c);
        final kind = a.str('kind', required: true)!, id = a.str('id', required: true)!;
        final cat = b.p.catalog;
        final item = _item(cat, kind, id);
        final fields = [
          for (final k in i.keys)
            if (k != 'kind' && k != 'id' && k != 'nozzle') k,
        ];
        if (fields.isEmpty) throw ToolInputError('Give at least one field to change.');
        const allowed = {
          'emitter': {'cv', 'flow_tol_pct', 'k_lph', 'x', 'min_head_m', 'max_head_m', 'default_head_m', 'arc_deg', 'finame'},
          'tape': {'barb_k', 'cv', 'tol_below_pct', 'tol_above_pct', 'finame'},
          'valve': {'loss_k', 'loss_n', 'finame'},
          'pump': {'efficiency_points', 'npsh_points', 'finame'},
        };
        final ok = allowed[kind] ?? const {'finame'};
        final bad = fields.where((k) => !ok.contains(k)).toList();
        if (bad.isNotEmpty) {
          throw ToolInputError(
            '${bad.join(', ')} do not apply to a $kind. For a $kind: ${ok.join(', ')}${kind == 'emitter' || kind == 'tape' || kind == 'valve' || kind == 'pump' ? '' : ' (the other fields: edit_catalog)'}.',
          );
        }
        final nozzleRef = a.str('nozzle');
        if (kind == 'emitter' && nozzleRef != null && (item as OutletSpec).nozzle(nozzleRef) == null) {
          throw ToolInputError('Emitter "$id" has no nozzle "$nozzleRef"; nozzles: ${item.nozzles.map((n) => n.id).join(', ')}.');
        }
        final eff = engPairs(i['efficiency_points'], 'efficiency_points', minItems: 0, maxItems: 30);
        final npsh = engPairs(i['npsh_points'], 'npsh_points', minItems: 0, maxItems: 30);
        double? n(String k, double min, double max) => a.number(k, min: min, max: max);
        final vals = (
          cv: n('cv', 0, 0.5),
          tol: n('flow_tol_pct', 0, 50),
          k: n('k_lph', 1e-6, 1e6),
          x: n('x', 0, 1),
          minH: n('min_head_m', 0, 300),
          maxH: n('max_head_m', 0, 300),
          defH: n('default_head_m', 0, 300),
          arc: n('arc_deg', 1, 360),
          barb: n('barb_k', 0, 10),
          tolB: n('tol_below_pct', 0, 60),
          tolA: n('tol_above_pct', 0, 60),
          lossK: n('loss_k', 0, 1e12),
          lossN: n('loss_n', 1, 3),
        );
        b.change('catalog_item_details', () {
          final cat = b.p.catalog;
          final it = _item(cat, kind, id);
          switch (kind) {
            case 'emitter':
              for (final nz in (it as OutletSpec).nozzles) {
                if (nozzleRef != null && nz.id != nozzleRef) continue;
                nz.cv = vals.cv ?? nz.cv;
                if (vals.tol != null) {
                  nz.flowTolBelow = vals.tol! / 100;
                  nz.flowTolAbove = vals.tol! / 100;
                }
                if (vals.k != null || vals.x != null) {
                  nz.curve = EmitterCurve(k: vals.k == null ? nz.curve.k : vals.k! * m3sPerLph, x: vals.x ?? nz.curve.x, radiusA: nz.curve.radiusA, radiusB: nz.curve.radiusB);
                }
                nz.minHeadM = vals.minH ?? nz.minHeadM;
                nz.maxHeadM = vals.maxH ?? nz.maxHeadM;
                nz.defaultHeadM = vals.defH ?? nz.defaultHeadM;
                nz.arcDeg = vals.arc ?? nz.arcDeg;
              }
            case 'tape':
              final tp = it as TapeSpec;
              tp.barbK = vals.barb ?? tp.barbK;
              tp.cv = vals.cv ?? tp.cv;
              tp.tolBelowPct = vals.tolB ?? tp.tolBelowPct;
              tp.tolAbovePct = vals.tolA ?? tp.tolAbovePct;
            case 'valve':
              final v = it as ValveSpec;
              if (vals.lossK != null || vals.lossN != null) v.loss = DeviceLossCurve(k: vals.lossK ?? v.loss.k, n: vals.lossN ?? v.loss.n, c: v.loss.c);
            case 'pump':
              final p = it as PumpSpec;
              if (eff != null) {
                p.efficiencyPoints = [
                  for (final (q, e) in eff)
                    if (e > 0) (q * m3sPerM3h, e > 1 ? e / 100 : e),
                ];
              }
              if (npsh != null) p.npshPoints = [for (final (q, h) in npsh) (q * m3sPerM3h, h)];
          }
          if (i.containsKey('finame')) {
            final f = a.str('finame') ?? '';
            if (f.isEmpty) {
              cat.finame.remove(id);
            } else {
              cat.finame[id] = f;
            }
          }
          return 1;
        });
        final it = _item(b.p.catalog, kind, id);
        final now = switch (kind) {
          'emitter' => [
            for (final nz in (it as OutletSpec).nozzles)
              if (nozzleRef == null || nz.id == nozzleRef)
                '${nz.id}: k ${engN(nz.curve.k / m3sPerLph, 4)} L/h·m⁻ˣ, x ${engN(nz.curve.x, 3)}, cv ${engN(nz.cv, 3)}, tolerance ${engN(nz.flowTolBelow * 100, 1)}/${engN(nz.flowTolAbove * 100, 1)} %, heads ${engN(nz.minHeadM, 1)}–${engN(nz.maxHeadM, 1)} (default ${engN(nz.defaultHeadM, 1)}) m, arc ${engN(nz.arcDeg, 0)}°',
          ].join('; '),
          'tape' => 'barb K ${engN((it as TapeSpec).barbK, 2)}, cv ${engN(it.cv, 3)}, window −${engN(it.tolBelowPct, 0)} / +${engN(it.tolAbovePct, 0)} %',
          'valve' => 'loss h = ${engN((it as ValveSpec).loss.k, 2)}·Q^${engN(it.loss.n, 2)}',
          'pump' => 'efficiency points ${(it as PumpSpec).efficiencyPoints.length}, NPSH points ${it.npshPoints.length}',
          _ => '',
        };
        final fin = b.p.catalog.finame[id];
        return ToolOutput('Updated $kind "$id" (${fields.join(', ')}). $now${fin == null ? '' : '; FINAME $fin'}. Results discarded: run the design again.');
      },
    ),
    engOp(
      b,
      name: 'duplicate_catalog_item',
      effect: ToolEffect.write,
      description: 'Design → Catalogue → Duplicate: copies a catalogue item under a new id and the name "<name> *" (or the name given), to make a variant (another price, size or supplier) with edit_catalog / catalog_item_details; for an emitter "nozzle" copies one nozzle inside the same emitter instead. One undo step. Inputs: kind, id, name (optional), nozzle (emitters only). Output: the new id.',
      schema: obj(
        {'kind': str(null, _kinds), 'id': str('Item id (search_catalog).'), 'name': str('Name of the copy.'), 'nozzle': str('Emitters: copy this nozzle inside the emitter.')},
        required: ['kind', 'id'],
      ),
      summary: (i) => t('ai.op.duplicate_catalog_item', {'n': '${i['id']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final kind = a.str('kind', required: true)!, id = a.str('id', required: true)!;
        final item = _item(b.p.catalog, kind, id);
        final nozzle = a.str('nozzle');
        if (nozzle != null) {
          if (kind != 'emitter') throw ToolInputError('"nozzle" applies to emitters only.');
          final o = item as OutletSpec;
          final n = o.nozzle(nozzle) ?? (throw ToolInputError('Emitter "$id" has no nozzle "$nozzle".'));
          var k = o.nozzles.length + 1;
          while (o.nozzles.any((x) => x.id == '${o.id}_n$k')) {
            k++;
          }
          final nid = '${o.id}_n$k';
          b.change('duplicate_catalog_item', () {
            final live = b.p.catalog.outlet(id)!;
            live.nozzles.add(NozzleSpec.fromJson(n.toJson()..['id'] = nid)..name = a.str('name') ?? '${n.name} *');
            return 1;
          });
          return ToolOutput('Added nozzle "$nid" to emitter "$id" (a copy of "$nozzle").');
        }
        final prefix = switch (kind) {
          'emitter' => 'out',
          'fitting' => 'fit',
          _ => kind,
        };
        final nid = b.p.catalog.newId(prefix);
        final j = Map<String, dynamic>.from((item as dynamic).toJson() as Map)..['id'] = nid;
        final dynamic copy = switch (kind) {
          'pipe' => PipeSpec.fromJson(j),
          'emitter' => OutletSpec.fromJson(j),
          'tape' => TapeSpec.fromJson(j),
          'valve' => ValveSpec.fromJson(j),
          'pump' => PumpSpec.fromJson(j),
          'fitting' => FittingSpec.fromJson(j),
          _ => WireSpec.fromJson(j),
        };
        copy.name = a.str('name') ?? '${(item as dynamic).name} *';
        b.change('duplicate_catalog_item', () {
          _listOf(b.p.catalog, kind).add(copy);
          return 1;
        });
        return ToolOutput('Added $kind "$nid" (${copy.name}), a copy of "$id".');
      },
    ),
    // ---------------------------------------------------------------- nozzle fit and profile
    engOp(
      b,
      name: 'fit_nozzle_curve',
      effect: ToolEffect.write,
      description: 'Design → Catalogue → Fit to a table: fits the curve of an emitter nozzle (q = k·Hˣ and, with radii, R = a·Hᵇ) to the rows of its data sheet — pressure head, flow and optionally the wetted radius per row — and stores it (one undo step; results discarded). Use it when the user attaches or types a manufacturer table. Inputs: outlet (emitter id), nozzle (id), rows [[head_m, flow, radius_m?], …] (≥2 rows with flow), flow_unit lph|lpm|lps|m3h|gpm of the flow column (default lph). Without radii the radius curve is kept. Output: k and x, the flow at the default head, the worst flow error and, with radii, a, b and their worst error.',
      schema: obj(
        {
          'outlet': str('Emitter id.'),
          'nozzle': str('Nozzle id.'),
          'rows': arr(
            {
              'type': 'array',
              'items': {'type': 'number'},
              'description': '[head_m, flow, radius_m?]',
            },
            'Data-sheet rows.',
            60,
          ),
          'flow_unit': str('Unit of the flow column; default lph.', [for (final f in FlowUnit.values) f.name]),
        },
        required: ['outlet', 'nozzle', 'rows'],
      ),
      summary: (i) => t('ai.op.fit_nozzle_curve', {'n': '${i['outlet']}/${i['nozzle']}'}),
      run: (a, i) async {
        engNotBusy(c);
        final oid = a.str('outlet', required: true)!, nid = a.str('nozzle', required: true)!;
        final o = b.p.catalog.outlet(oid) ?? (throw ToolInputError('Unknown emitter "$oid".'));
        final n = o.nozzle(nid) ?? (throw ToolInputError('Emitter "$oid" has no nozzle "$nid"; nozzles: ${o.nozzles.map((x) => x.id).join(', ')}.'));
        final fu = Units(flow: FlowUnit.values.byName(a.str('flow_unit') ?? 'lph'));
        final rows = <(double, double, double?)>[];
        final raw = i['rows'] as List;
        for (var k = 0; k < raw.length; k++) {
          final r = engNumbers(raw[k], 'rows[$k]')!;
          if (r.length < 2) throw ToolInputError('rows[$k] needs at least [head_m, flow].');
          rows.add((r[0], fu.flowToSi(r[1]), r.length >= 3 ? r[2] : null));
        }
        final fit = EmitterCurve.fitTable(rows);
        if (!fit.isUsable || fit.flowRows < 2) throw ToolInputError('The rows do not give a usable curve: at least two rows with a positive head and flow are needed.');
        final curve = fit.radiusRows > 0 ? fit.curve : EmitterCurve(k: fit.curve.k, x: fit.curve.x, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB);
        b.change('fit_nozzle_curve', () {
          b.p.catalog.outlet(oid)!.nozzle(nid)!.curve = curve;
          return 1;
        });
        return ToolOutput(
          'Nozzle $oid/$nid: q = k·Hˣ with k ${engN(curve.k / m3sPerLph, 4)} L/h·m⁻ˣ, x ${engN(curve.x, 3)}; at the default head ${engN(n.defaultHeadM, 1)} m: ${engN(fu.flowFromSi(curve.flow(n.defaultHeadM)), 2)} ${fu.flowLabel}; worst flow error ${engN(fit.maxFlowError * 100, 1)} %.${fit.radiusRows > 0 ? ' R = a·Hᵇ with a ${engN(curve.radiusA, 3)}, b ${engN(curve.radiusB, 3)}; worst radius error ${engN(fit.maxRadiusError * 100, 1)} %.' : ' Radius curve kept (no radii given).'} Results discarded: run the design again.',
        );
      },
    ),
    engOp(
      b,
      name: 'set_nozzle_profile',
      effect: ToolEffect.write,
      description: 'Design → Catalogue → Radial profile: stores the measured water distribution of an emitter nozzle from a catch-can test — rows of distance from the head (m) and depth or rate (any unit: the profile is scaled to the wetted radius and the largest value) — used by the densogram and the layout uniformity instead of the generic profile; clear removes it. One undo step. Inputs: outlet, nozzle, rows [[distance_m, depth], …] (≥3 rows, from the head outwards), clear. Output: the stations stored.',
      schema: obj(
        {'outlet': str('Emitter id.'), 'nozzle': str('Nozzle id.'), 'rows': arr(numbers('[distance_m, depth]', n: 2), 'Catch-can rows.', 200), 'clear': bool_('Remove the measured profile.')},
        required: ['outlet', 'nozzle'],
      ),
      summary: (i) => t('ai.op.set_nozzle_profile', {'n': '${i['outlet']}/${i['nozzle']}'}),
      run: (a, i) async {
        engNotBusy(c);
        final oid = a.str('outlet', required: true)!, nid = a.str('nozzle', required: true)!;
        final o = b.p.catalog.outlet(oid) ?? (throw ToolInputError('Unknown emitter "$oid".'));
        if (o.nozzle(nid) == null) throw ToolInputError('Emitter "$oid" has no nozzle "$nid"; nozzles: ${o.nozzles.map((x) => x.id).join(', ')}.');
        List<(double, double)> prof;
        if (a.flag('clear') ?? false) {
          prof = const [];
        } else {
          final rows = engPairs(i['rows'], 'rows', minItems: 3, maxItems: 200) ?? (throw ToolInputError('Give "rows" (or clear).'));
          prof = profileFromTable(rows) ?? (throw ToolInputError('The rows do not give a profile: distances from 0 outwards with at least one positive depth are needed.'));
        }
        b.change('set_nozzle_profile', () {
          b.p.catalog.outlet(oid)!.nozzle(nid)!.profile = prof;
          return 1;
        }, invalidate: false);
        return ToolOutput(prof.isEmpty ? 'Measured profile of $oid/$nid removed.' : 'Measured profile of $oid/$nid stored (${prof.length} stations).');
      },
    ),
    // ---------------------------------------------------------------- import / export
    engOp(
      b,
      name: 'import_catalog_attachment',
      effect: ToolEffect.write,
      description: 'Design → Catalogue → Import: merges a catalogue file the user attached to the conversation into the project catalogue (items with the same id are replaced): the program\'s catalogue JSON, a CSV or text table of one group, an Excel workbook written by the catalogue export (or with the same columns), or a manufacturer pack (.oci.cat, prices converted to the project currency with the reference rate). One undo step; results discarded. Inputs: name (file name as attached), group (CSV/TXT only: pipes|outlets|tapes|valves|pumps|fittings|wires). Output: how many items were added or replaced.',
      schema: obj(
        {
          'name': str('File name as attached.'),
          'group': str('Group of a CSV/TXT table.', [for (final g in CatalogGroup.values) g.name]),
        },
        required: ['name'],
      ),
      summary: (i) => t('ai.op.import_catalog_attachment', {'n': '${i['name']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final files = b.host?.files ?? const <String, Uint8List>{};
        final name = a.str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        final lower = name.toLowerCase();
        try {
          if (lower.endsWith('.cat')) {
            final pack = CatalogPack.parse(utf8.decode(bytes, allowMalformed: true), origin: name);
            final r = b.change('import_catalog_attachment', () => addCatalogPack(b.p.catalog, pack, projectCurrency: b.p.params.currencyCode));
            return ToolOutput(
              'Pack ${pack.brand}: ${r.added} items added${r.converted ? ' (prices ${r.from} → ${r.to} at ${engN(r.rate!, 6)})' : ''}${r.unknownCurrency ? ' (prices kept: no reference rate for the pack currency)' : ''}. Results discarded.',
            );
          }
          final group = a.has('group') ? CatalogGroup.values.byName(a.str('group')!) : null;
          if ((lower.endsWith('.csv') || lower.endsWith('.txt')) && group == null) throw ToolInputError('A CSV or text table needs "group" (the catalogue group of its rows).');
          final r = lower.endsWith('.xlsx') ? CatalogIo.parseXlsx(bytes) : CatalogIo.parse(utf8.decode(bytes, allowMalformed: true), group: group);
          if (r.count == 0) throw ToolInputError('No catalogue item could be read from "$name".');
          // 1.6.0 MOD: a row without an id never replaces another item
          final m = b.change('import_catalog_attachment', () => r.mergeInto(b.p.catalog, used: b.p.catalogIdsInUse));
          return ToolOutput(
            'Imported $name: ${m.added} items added, ${m.replaced} replaced${m.replacedInUse.isEmpty ? '' : ' (in use by the drawing: ${m.replacedInUse.join(', ')})'}${r.skippedRows.isEmpty ? '' : '; rows left out (no diameter, curve or section): ${r.skippedRows.join(', ')}'}${r.pnAsBar > 0 ? '; ${r.pnAsBar} PN values without unit read in bar' : ''}. Results discarded.',
          );
        } on FormatException catch (e) {
          throw ToolInputError('"$name" could not be read as a catalogue (${e.message}).');
        }
      },
    ),
    engOp(
      b,
      name: 'export_catalog',
      effect: ToolEffect.export,
      description: 'Design → Catalogue → Export: saves the project catalogue as a file — "json" (the whole catalogue, re-importable), "csv" (one group as a table), "xlsx" (every group, one sheet each) or "pack" (a manufacturer pack .oci.cat to share or publish, with brand, name, description and source). Always confirmed by the user (a download in the browser). Inputs: format, group (csv: pipes|outlets|tapes|valves|pumps|fittings|wires; default pipes), brand / name / description / source (pack; brand defaults to the client or the project name). Output: the file name.',
      schema: obj(
        {
          'format': str(null, ['json', 'csv', 'xlsx', 'pack']),
          'group': str('Group of the CSV.', [for (final g in CatalogGroup.values) g.name]),
          'brand': str('Pack brand.'),
          'name': str('Pack name.'),
          'description': str('Pack description.'),
          'source': str('Where the data come from (pack).'),
        },
        required: ['format'],
      ),
      summary: (i) => t('ai.op.export_catalog', {'n': '${i['format']}'}),
      run: (a, _) async {
        final cat = b.p.catalog;
        switch (a.str('format', required: true)) {
          case 'json':
            await engFileSink(c, 'catalog.json', 'application/json', CatalogIo.exportJson(cat));
            return const ToolOutput('Saved catalog.json.');
          case 'csv':
            final g = CatalogGroup.values.byName(a.str('group') ?? 'pipes');
            final file = 'catalog_${g.name}.csv';
            await engFileSink(c, file, 'text/csv', CatalogIo.exportCsv(cat, g));
            return ToolOutput('Saved $file.');
          case 'xlsx':
            await engFileSink(c, 'catalog.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', CatalogIo.exportXlsx(cat));
            return const ToolOutput('Saved catalog.xlsx.');
          default:
            final m = b.p.meta;
            final brand = a.str('brand') ?? (m.client.trim().isEmpty ? m.name : m.client);
            final name = a.str('name') ?? '';
            final id = CatalogPackMeta.idFrom(name.isEmpty ? brand : name);
            final meta = CatalogPackMeta(
              id: id,
              brand: brand.trim().isEmpty ? id : brand.trim(),
              name: name.trim(),
              description: (a.str('description') ?? '').trim(),
              source: (a.str('source') ?? '').trim(),
              updated: DateTime.now().toIso8601String().substring(0, 10),
              author: m.designer,
              currency: catalogHasPrices(cat) ? b.p.params.currencyCode : '',
            );
            final file = '$id$catalogPackExtension';
            await engFileSink(c, file, 'application/json', CatalogIo.encodePack(meta, cat));
            return ToolOutput('Saved $file (${cat.itemCount} items).');
        }
      },
    ),
    // ---------------------------------------------------------------- packs
    engOp(
      b,
      name: 'list_catalog_packs',
      effect: ToolEffect.read,
      effectFor: (i) => i['url'] == null ? ToolEffect.read : ToolEffect.network,
      // an address outside the program's own site and repository is confirmed whatever the mode
      confirm: (i) => i['url'] is String && !aiKnownPackUrl(i['url'] as String),
      description: 'Design → Catalogue → Manufacturer packs: lists the catalogue packs bundled with the program (manufacturers\' pipes, emitters, tapes, valves, pumps, fittings, read from their data sheets), or — with url — the pack or pack index (index.json of a community repository) at that address (the address is fetched; the user approves it unless changes apply automatically, and always when it is not on the program\'s own site or repository). add_catalog_pack adds one to the project. Inputs: url (optional), query (text in the id, brand or description). Output: id | brand | items | prices | updated | whether it is in the project | origin | description | sources.',
      schema: obj({'url': str('Address of a pack (.oci.cat) or of an index.json.'), 'query': str('Filter (case-insensitive).')}),
      summary: (i) => i['url'] == null
          ? t('ai.op.list_catalog_packs')
          : '${t('ai.op.list_catalog_packs.url', {'n': AgentToolbox.short('${i['url']}', 60)})} — ${t('ai.ask.fetchFrom', {'h': aiHost('${i['url']}')})}',
      run: (a, _) async {
        final url = a.str('url');
        List<CatalogPack> packs;
        try {
          if (url != null) {
            packs = await loadCatalogPacksFromUrl(url);
            for (final p in packs) {
              loaded[p.id] = p;
            }
          } else {
            packs = await loadBundledCatalogPacks();
          }
        } catch (e) {
          throw ToolInputError('The packs could not be loaded (${c.describeError(e)}).');
        }
        final q = a.str('query')?.toLowerCase();
        final hits = [
          for (final p in packs)
            if (q == null || '${p.id} ${p.brand} ${p.description}'.toLowerCase().contains(q)) p,
        ];
        if (hits.isEmpty) return ToolOutput('No pack${q == null ? '' : ' matches "$q"'}.');
        return ToolOutput(
          '${hits.length} packs${url == null ? ' bundled with the program' : ' at $url'}:\nid | brand | items | prices | updated | status\n${hits.map((p) => _packLine(p, b.p.catalog)).join('\n')}',
        );
      },
    ),
    engOp(
      b,
      name: 'add_catalog_pack',
      effect: ToolEffect.write,
      confirm: (i) => i['url'] is String && !aiKnownPackUrl(i['url'] as String),
      description: 'Design → Catalogue → Manufacturer packs → Add: merges a pack into the project catalogue — the items it does not have yet (by id), prices converted from the pack currency to the project currency with the reference rate. One undo step; results discarded. Inputs: id (a bundled pack, or one listed from a url in this conversation; list_catalog_packs) or url (a pack or index to fetch and add; the address is fetched). Output: the items added and the conversion.',
      schema: obj({'id': str('Pack id (list_catalog_packs).'), 'url': str('Address of a pack or index to fetch and add.')}),
      summary: (i) => i['url'] is String
          ? '${t('ai.op.add_catalog_pack', {'n': AgentToolbox.short('${i['url']}', 60)})} — ${t('ai.ask.fetchFrom', {'h': aiHost('${i['url']}')})}'
          : t('ai.op.add_catalog_pack', {'n': '${i['id'] ?? ''}'}),
      run: (a, _) async {
        engNotBusy(c);
        final id = a.str('id'), url = a.str('url');
        if ((id == null) == (url == null)) throw ToolInputError('Give "id" or "url".');
        List<CatalogPack> packs;
        try {
          packs = url != null ? await loadCatalogPacksFromUrl(url) : [...await loadBundledCatalogPacks(), ...loaded.values];
        } catch (e) {
          throw ToolInputError('The packs could not be loaded (${c.describeError(e)}).');
        }
        final chosen = url != null ? packs : [...packs.where((p) => p.id == id)];
        if (chosen.isEmpty) throw ToolInputError(url != null ? 'No pack at $url.' : 'No pack "$id". Packs: ${packs.map((p) => p.id).join(', ')}.');
        final lines = <String>[];
        b.change('add_catalog_pack', () {
          for (final p in chosen) {
            final r = addCatalogPack(b.p.catalog, p, projectCurrency: b.p.params.currencyCode);
            lines.add(
              '${p.brand} (${p.id}): ${r.added} items added${r.converted ? ', prices ${r.from} → ${r.to} at ${engN(r.rate!, 6)}' : ''}${r.unknownCurrency ? ', prices kept as they are (no reference rate)' : ''}',
            );
          }
          return lines.length;
        });
        return ToolOutput('${lines.join('\n')}\nResults discarded: run the design again.');
      },
    ),
    engOp(
      b,
      name: 'catalog_default',
      effect: ToolEffect.write,
      // every action is confirmed: a preference of this browser, or the whole catalogue replaced
      confirm: (_) => true,
      description: 'Design → Catalogue → the default catalogue, as the three buttons of the catalogue editor and "Use as default": "save" keeps the project catalogue as the catalogue of new projects on this browser (a preference, not an undo step); "load" puts that saved catalogue into this project (one undo step; results discarded; fails when none is saved); "factory" puts the program\'s own catalogue for the language and currency into this project (one undo step; results discarded) and keeps the saved default; "forget" drops the saved default (new projects get the program\'s catalogue again), the project\'s catalogue staying as it is. "reset" is the older name of "factory". Every action is confirmed by the user. Input: action. Output: what was done.',
      schema: obj(
        {
          'action': str(null, ['save', 'load', 'factory', 'forget', 'reset']),
        },
        required: ['action'],
      ),
      summary: (i) => engSummary(b, 'ai.op.catalog_default.${i['action']}', 'ai.op.catalog_default'),
      run: (a, _) async {
        // the project catalogue replaced by [d]: one undo step, results discarded
        void replace(Catalog d) {
          engNotBusy(c);
          b.change('catalog_default', () {
            final cat = b.p.catalog;
            cat.pipes
              ..clear()
              ..addAll(d.pipes);
            cat.outlets
              ..clear()
              ..addAll(d.outlets);
            cat.tapes
              ..clear()
              ..addAll(d.tapes);
            cat.valves
              ..clear()
              ..addAll(d.valves);
            cat.pumps
              ..clear()
              ..addAll(d.pumps);
            cat.fittings
              ..clear()
              ..addAll(d.fittings);
            cat.wires
              ..clear()
              ..addAll(d.wires);
            return 1;
          });
        }

        const after = 'Items of the drawing that pointed to removed ids need new ones (get_design_messages). Results discarded.';
        switch (a.str('action', required: true)) {
          case 'save':
            c.saveDefaultCatalog();
            return ToolOutput('The project catalogue (${b.p.catalog.itemCount} items) is now the catalogue of new projects.');
          case 'forget':
            if (!hasSavedDefaultCatalog()) return const ToolOutput('No default catalogue was saved on this browser: new projects already get the program\'s catalogue.');
            c.clearDefaultCatalog();
            return const ToolOutput('Saved default catalogue forgotten: new projects get the program\'s catalogue; this project\'s catalogue stays as it is.');
          case 'load':
            if (!hasSavedDefaultCatalog()) {
              throw ToolInputError('No default catalogue is saved on this browser: action "save" keeps the project\'s catalogue as the default, "factory" puts the program\'s catalogue in.');
            }
            replace(c.defaultCatalog());
            return ToolOutput('The default catalogue saved on this browser is now the project catalogue (${b.p.catalog.itemCount} items). $after');
          default:
            // factory (and its older name, reset): the saved default stays
            replace(Catalog.defaultCatalog(lang: c.lang, currency: b.p.params.currencyCode));
            return ToolOutput(
              'Catalogue reset to the program\'s default (${b.p.catalog.itemCount} items)${hasSavedDefaultCatalog() ? '; the default saved on this browser stays (action "load" brings it in, "forget" drops it)' : ''}. $after',
            );
        }
      },
    ),
  ];
}
