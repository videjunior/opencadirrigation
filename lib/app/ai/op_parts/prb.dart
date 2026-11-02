/// Operations (find_operations / run_operation) added in 1.6.0 for deliverables, second set (water permit tables, descriptive and calculation memorial, operation and maintenance plan, budget by compositions with BDI and schedule, life-cycle cost):
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/budget.dart';
import '../../../core/design/life_cycle.dart';
import '../../../core/design/permit.dart';
import '../../../core/model/deliverables.dart';
import '../../../core/model/entities.dart' show WaterSupplyEntity;
import '../../widgets/dialogs/deliverables_dialogs.dart' show DocFormat, buildTechDocument, techDocumentData, techDocumentFileName, techDocumentKeys;
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../ops_eng_common.dart' show engFileSink, engMonths, engN, engNotBusy, engTable;

/// The title of document [key] in the user's language (the approval line).
String _docTitle(AgentToolbox b, Object? key) => switch (key) {
  'permit' => b.t('prb.permit.title'),
  'memorial' => b.t('prb.mem.title'),
  'om' => b.t('prb.om.title'),
  'budget' => b.t('prb.bud.title'),
  'lcc' => b.t('prb.lcc.title'),
  _ => '$key',
};

/// The water source named by [ref] (id or name), or every one.
List<PermitSource> _sourcesOf(AgentToolbox b, PermitStudy st, String? ref) {
  if (ref == null || ref.isEmpty) return st.sources;
  final low = ref.toLowerCase();
  final found = [
    for (final s in st.sources)
      if (s.supply.id == ref || s.supply.name.toLowerCase() == low) s,
  ];
  if (found.isEmpty) throw ToolInputError('No water supply "$ref". Supplies: ${st.sources.map((s) => '${s.supply.id} (${s.supply.name})').join(', ')}.');
  return found;
}

/// The id of the water supply [ref] (id or name).
String _supplyId(AgentToolbox b, String ref) {
  final low = ref.toLowerCase();
  final sup = b.p.entities.whereType<WaterSupplyEntity>().where((e) => e.id == ref || e.name.toLowerCase() == low).firstOrNull;
  if (sup == null) throw ToolInputError('No water supply "$ref": list_entities with type waterSupply gives the ids.');
  return sup.id;
}

List<AgentTool> opsPrb(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  final docs = str('Which document: permit (water permit table and self-monitoring sheet), memorial (descriptive and calculation memorial), om (operation and maintenance plan), budget (budget by compositions, BDI and physical-financial schedule), lcc (life-cycle cost of the alternatives).', techDocumentKeys);
  return [
    // ---------------------------------------------------------------- permit table (PRD-02)
    cadOp(
      b,
      group: 'engineering',
      name: 'permit_table',
      description:
          'Reports → Technical documents → Water permit table: for every water supply (point of abstraction) the fields a water-use permit application asks for — its coordinates on SIRGAS 2000 (degrees, minutes and seconds, decimal degrees, UTM with the EPSG code; blank without a georeference), the kind of source, water body, basin, municipality, register and permit numbers, status, the purpose, irrigation methods, crops and area it waters, its pumps (model, rated power in kW and cv, duty flow and head, hour meter), whether it has a flow meter — and the monthly regime as the federal permits write it: flow (m³/h), hours a day, days a month, m³/day, m³/month and the gross requirement of the areas, never below it; plus the capacity check against the peak month, the federal floor of 300 m³/ha (Resolution ANA 1.939/2017, when on), and the self-monitoring obligation of Resolution ANA 188/2024 for the chosen management unit. Volumes in SI whatever the display units. Change the permit data and the regime with set_permit_info; export the document with export_document "permit". Input: source (id or name; omitted: all). Output: the fields, the monthly table and the remarks of each source.',
      schema: obj({'source': str('Water supply id or name; omitted: every source.')}),
      run: (a, _) async {
        final st = buildPermitStudy(b.p, c.results, cropName: c.exporter().labels.category);
        if (st.sources.isEmpty) throw ToolInputError(t('prb.warn.permit_no_source'));
        final s = b.p.deliverables.permit;
        final out = StringBuffer(
          'Monitoring unit ${st.unit.key} (threshold ${engN(st.unit.limitM3h, 0)} m³/h, ${st.unit.monthly ? 'monthly' : 'yearly'} declaration; telemetry from ${engN(st.unit.telemetryM3h, 0)} m³/h); sum of the largest flows ${engN(st.totalFlowM3h, 1)} m³/h → ${st.obligation}. Regime: ${s.fixedHoursPerDay > 0 ? '${engN(s.fixedHoursPerDay, 1)} h a day' : 'the days with irrigation'}; capacity checked at ${engN(s.maxHoursPerDay, 1)} h/day; federal floor ${s.federalFloor ? 'on' : 'off'}.',
        );
        for (final w in st.warnings) {
          out.write('\n${permitWarningText(w, t.call, name: c.entityName)}');
        }
        for (final src in _sourcesOf(b, st, a.str('source'))) {
          final i = src.info;
          final u = src.utm;
          out.write('\n\nSource ${src.supply.id} "${src.supply.name}": kind ${i.kind}, water body "${i.waterBody}", basin "${i.basin}", municipality "${i.municipality}", register "${i.registry}", permit "${i.permitNumber}", status ${i.status}.');
          if (src.lat == null || src.lon == null || u == null) {
            out.write('\nCoordinates: none (no georeference).');
          } else {
            final lat = src.lat!, lon = src.lon!;
            out.write(
              '\nCoordinates SIRGAS 2000: ${dmsText(lat, 'N', 'S')}, ${dmsText(lon, 'E', 'W')} (${engN(lat, 6)}, ${engN(lon, 6)}); '
              'UTM E ${engN(u.easting, 1)} N ${engN(u.northing, 1)} zone ${u.zone}${u.north ? 'N' : 'S'}${src.epsg == null ? '' : ' (EPSG:${src.epsg})'}.',
            );
          }
          out.write(
            '\nWaters ${engN(src.areaHa, 2)} ha (${src.areaIds.join(', ')}); methods ${src.methods.map((k) => k.split('.').last).join(', ')}; crops ${src.crops.join(', ')}. Installed flow ${engN(src.installedFlowM3h, 1)} m³/h${src.flowFromDemand ? ' (from the peak month: no design and no design flow)' : ''}; peak month needs ${engN(src.peakHoursNeeded, 1)} h/day. Year: ${engN(src.annualM3, 0)} m³ granted, ${engN(src.annualNeedM3, 0)} m³ needed, ${engN(src.hoursPerYear, 0)} h. Flow meter ${src.meter ? 'yes' : 'no'}, hour meter ${src.hourMeter ? 'yes' : 'no'}.',
          );
          final rows = [
            for (var m = 0; m < 12; m++)
              [
                engMonths[m],
                engN(src.flowM3h[m], 1),
                engN(src.hoursPerDay[m], 1),
                src.daysPerMonth[m],
                engN(src.volumeDayM3[m], 1),
                engN(src.volumeMonthM3[m], 0),
                engN(src.needM3[m], 0),
              ],
          ];
          final table = engTable(const ['Month', 'Q m³/h', 'h/day', 'days', 'm³/day', 'm³/month', 'need m³'], rows);
          out.write('\n$table');
          if (src.pumps.isNotEmpty) {
            final pumps = [
              for (final p in src.pumps)
                '${p.id} ${p.model} ${engN(p.powerKw, 1)} kW (${engN(p.powerCv, 1)} cv), ${engN(p.flowM3h, 1)} m³/h at ${engN(p.headM, 1)} m, hour meter ${p.hourMeter ? 'yes' : 'no'}',
            ];
            out.write('\nPumps: ${pumps.join('; ')}.');
          }
          for (final w in src.warnings) {
            out.write('\n- ${permitWarningText(w, t.call, src: src, s: s, name: c.entityName)}');
          }
        }
        return ToolOutput(out.toString());
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'set_permit_info',
      effect: ToolEffect.write,
      description:
          'Reports → Technical documents → Water permit table, its fields: the permit data of one water supply (kind surface|groundwater, water_body, basin, municipality, registry — the number in the register of water users, CNARH in Brazil —, permit_number, status project|operation) and the regime of the table (fixed_hours_per_day: the pumping hours a day written in every month, 0 = the days with irrigation and the hours they need; max_hours_per_day for the capacity check, default 21; federal_floor: the 300 m³/ha a month floor of Resolution ANA 1.939/2017; monitoring_unit: the management unit of the self-monitoring thresholds of Resolution ANA 188/2024, Annex I, "other" for the remaining federal units and the state units). Give "source" (id or name) for the source fields. One undo step; the design results are kept. Output: what was set.',
      schema: obj({
        'source': str('Water supply id or name (for the source fields).'),
        'kind': str('Kind of source.', SourcePermitInfo.kinds),
        'water_body': str('River, stream, reservoir or aquifer.'),
        'basin': str('River basin or management unit.'),
        'municipality': str('Municipality and state.'),
        'registry': str('Number in the register of water users.'),
        'permit_number': str('Number of the permit or of its application.'),
        'status': str('Planned or in operation.', SourcePermitInfo.statuses),
        'fixed_hours_per_day': num_('0–24; 0 = by the days of the month.'),
        'max_hours_per_day': num_('1–24 (default 21).'),
        'federal_floor': bool_('The floor of 300 m³/ha a month.'),
        'monitoring_unit': str('Management unit (Res. ANA 188/2024, Annex I).', [for (final u in monitoringUnits) u.key]),
      }),
      run: (a, _) async {
        engNotBusy(c);
        const sourceFields = ['kind', 'water_body', 'basin', 'municipality', 'registry', 'permit_number', 'status'];
        final String? id = sourceFields.any(a.has) ? _supplyId(b, a.str('source', required: true)!) : null;
        final fixed = a.number('fixed_hours_per_day', min: 0, max: 24);
        final max = a.number('max_hours_per_day', min: 1, max: 24);
        if (id == null && fixed == null && max == null && !a.has('federal_floor') && !a.has('monitoring_unit')) {
          throw ToolInputError('Nothing to set: give the source fields with "source", or the regime fields.');
        }
        final set = <String>[];
        b.change('set_permit_info', () {
          final s = b.p.deliverables.permit;
          if (id != null) {
            final info = s.source(id);
            if (a.has('kind')) info.kind = a.str('kind')!;
            if (a.has('water_body')) info.waterBody = a.str('water_body')!;
            if (a.has('basin')) info.basin = a.str('basin')!;
            if (a.has('municipality')) info.municipality = a.str('municipality')!;
            if (a.has('registry')) info.registry = a.str('registry')!;
            if (a.has('permit_number')) info.permitNumber = a.str('permit_number')!;
            if (a.has('status')) info.status = a.str('status')!;
            set.add('source $id');
          }
          if (fixed != null) {
            s.fixedHoursPerDay = fixed;
            set.add('fixed hours $fixed');
          }
          if (max != null) {
            s.maxHoursPerDay = max;
            set.add('max hours $max');
          }
          if (a.has('federal_floor')) {
            s.federalFloor = a.flag('federal_floor')!;
            set.add('federal floor ${s.federalFloor}');
          }
          if (a.has('monitoring_unit')) {
            final u = a.str('monitoring_unit')!;
            s.monitoringUnit = u == 'other' ? '' : u;
            set.add('unit $u');
          }
          return set.length;
        }, invalidate: false);
        return ToolOutput('Set ${set.join(', ')}. permit_table shows the table.');
      },
    ),
    // ---------------------------------------------------------------- every document
    cadOp(
      b,
      group: 'engineering',
      name: 'document_text',
      args: (i) => {'n': _docTitle(b, i['document'])},
      description:
          'Reports → Technical documents: one of the documents built from the project without the AI, as Markdown — the water permit table (permit), the descriptive and calculation memorial (memorial: identification, objective, areas and crops, climate and water requirement, water source, design criteria, the formulas of the engine with their sources, zones, network, pumping and energy, operation, checks, materials, notes, references), the operation and maintenance plan (om: start-up, pressure test, pressure sheet of every zone, flushing, filters, chlorination, off-season, schedule by component, self-monitoring, spare parts), the budget by compositions (budget: items, compositions of labour and equipment, BDI, hourly costs, physical-financial schedule) or the life-cycle cost of the alternatives (lcc). Read it to review, summarise or rewrite it for the user; the texts the designer adds are set with set_memorial_texts, the figures with the set_… operations, and the file is written with export_document. Inputs: document, max_chars (default 20000). Output: the Markdown text.',
      schema: obj({'document': docs, 'max_chars': int_('Most characters returned, 1000–100000 (default 20000).')}, required: ['document']),
      run: (a, _) async {
        final key = a.str('document', required: true)!;
        if (!techDocumentKeys.contains(key)) throw ToolInputError('"document" must be one of ${techDocumentKeys.join(', ')}.');
        final max = a.integer('max_chars', min: 1000, max: 100000) ?? 20000;
        return ToolOutput(buildTechDocument(c, key).toMarkdown()).clip(max);
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'export_document',
      effect: ToolEffect.export,
      args: (i) => {'n': _docTitle(b, i['document'])},
      description:
          'Reports → Technical documents → Export: writes one of the documents (permit, memorial, om, budget, lcc — see document_text) as a file: pdf (A4 pages with header and page numbers; the permit table, the budget and the life-cycle cost in landscape), xlsx (a sheet with the text and one per table, numbers as numbers), csv (semicolons, to paste into a form) or md (Markdown, to edit). Always confirmed by the user (a download in the browser). Inputs: document, format. Output: the file name.',
      schema: obj({'document': docs, 'format': str('File format.', [for (final f in DocFormat.values) f.name])}, required: ['document', 'format']),
      run: (a, _) async {
        final key = a.str('document', required: true)!;
        if (!techDocumentKeys.contains(key)) throw ToolInputError('"document" must be one of ${techDocumentKeys.join(', ')}.');
        final f = DocFormat.values.byName(a.str('format', required: true)!);
        final doc = buildTechDocument(c, key);
        final data = await techDocumentData(c, doc, f);
        final file = techDocumentFileName(c, doc, f);
        await engFileSink(c, file, f.mime, data);
        return ToolOutput('Saved $file (${doc.sections.length} sections, ${doc.tables.length} tables).');
      },
    ),
    // ---------------------------------------------------------------- life-cycle cost (PRD-20)
    cadOp(
      b,
      group: 'engineering',
      name: 'life_cycle_cost',
      description:
          'Reports → Technical documents → Life-cycle cost: compares the current design (with results) and every alternative saved with Design → Alternatives over N years — LCC = I + Repl − Res + E + W + OM&R, every term a present value at the discount rate (NIST Handbook 135): the investment (the quote total, or the bill of materials), the replacement of each category of parts at the end of its life, the residual value at the end, the energy of the design (raised by the escalation), the water at its price and the yearly maintenance — with the equivalent annual cost, the cost per hectare a year and per m³, and the rank. Alternatives saved without results count their capital in one category (marked approximate). Change the horizon, rates, water price and the life and maintenance of the categories with set_life_cycle_settings. No input. Output: the settings and the table of the alternatives.',
      schema: obj({}),
      run: (a, _) async {
        final st = buildLifeCycleStudy(b.p, c.results, currentName: t('prb.lcc.current'));
        if (st.alternatives.isEmpty) throw ToolInputError(t('prb.lcc.none'));
        final cur = b.p.params.currency;
        final best = st.best!;
        final rows = [
          for (final x in st.alternatives)
            [
              x.approximate ? '${x.name} (approximate)' : x.name,
              engN(x.investment, 0),
              engN(x.replacements, 0),
              engN(x.residual, 0),
              engN(x.energy, 0),
              engN(x.water, 0),
              engN(x.maintenance, 0),
              engN(x.lcc, 0),
              engN(x.eac, 0),
              x.areaHa > 0 ? engN(x.perHaYear, 0) : '-',
              x.annualWaterM3 > 0 ? engN(x.perM3, 3) : '-',
            ],
        ];
        final table = engTable(const ['Alternative', 'I', 'Repl', 'Res', 'E', 'W', 'OM&R', 'LCC', 'EAC/yr', 'per ha·yr', 'per m³'], rows);
        final head =
            'Horizon ${st.years} years, discount ${engN(st.rate * 100, 2)} %, energy escalation ${engN(st.escalation * 100, 2)} %, water $cur ${engN(st.waterPrice, 4)}/m³, '
            'residual ${st.residual ? 'credited' : 'not credited'}; money in $cur, present values.';
        return ToolOutput('$head\n$table\nLowest LCC: ${best.name}.');
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'set_life_cycle_settings',
      effect: ToolEffect.write,
      description:
          'Reports → Technical documents → Life-cycle cost, its settings: years (1–100, default 20), discount_pct (% a year; use_design_interest true = back to the interest of the design parameters), energy_escalation_pct (real rise of the energy price a year), water_price (project currency per m³), residual (credit the value left at the end), life {category: years} and maintenance {category: % of its cost a year} by category of the bill of materials (bom.pipes, bom.fittings, bom.takeoffs, bom.risers, bom.tapes, bom.outlets, bom.valves, bom.devices, bom.pumps, bom.pivots, bom.electrical, other), reset_categories (back to the reference values). One undo step; the results are kept. Output: what was set.',
      schema: obj({
        'years': int_('1–100.'),
        'discount_pct': num_('0–100 % a year.'),
        'use_design_interest': bool_('Take the interest of the design parameters.'),
        'energy_escalation_pct': num_('-50–50 % a year.'),
        'water_price': num_('Project currency per m³, ≥ 0.'),
        'residual': bool_('Credit the residual value.'),
        'life': {'type': 'object', 'description': 'Years of life by category (1–100).'},
        'maintenance': {'type': 'object', 'description': 'Yearly maintenance by category (% of its cost, 0–100).'},
        'reset_categories': bool_('Back to the reference lives and maintenance.'),
      }),
      run: (a, i) async {
        engNotBusy(c);
        Map<String, double> byCategory(String k, double min, double max) {
          final v = i[k];
          if (v == null) return const {};
          if (v is! Map) throw ToolInputError('"$k" must be an object {category: number}.');
          final out = <String, double>{};
          for (final e in v.entries) {
            final x = e.value;
            if (x is! num || !x.isFinite || x < min || x > max) throw ToolInputError('"$k.${e.key}" must be a number from $min to $max.');
            out['${e.key}'] = x.toDouble();
          }
          return out;
        }

        final years = a.integer('years', min: 1, max: 100);
        final rate = a.number('discount_pct', min: 0, max: 100);
        final esc = a.number('energy_escalation_pct', min: -50, max: 50);
        final water = a.number('water_price', min: 0, max: 1e6);
        final life = byCategory('life', 1, 100), maint = byCategory('maintenance', 0, 100);
        final set = [
          for (final k in i.keys)
            if (i[k] != null) k,
        ];
        if (set.isEmpty) throw ToolInputError('Nothing to set.');
        b.change('set_life_cycle_settings', () {
          final s = b.p.deliverables.lifeCycle;
          if (years != null) s.years = years;
          if (a.flag('use_design_interest') ?? false) {
            s.discountPct = null;
          } else if (rate != null) {
            s.discountPct = rate;
          }
          if (esc != null) s.energyEscalationPct = esc;
          if (water != null) s.waterPrice = water;
          if (a.has('residual')) s.residual = a.flag('residual')!;
          if (a.flag('reset_categories') ?? false) {
            s.life.clear();
            s.maintenance.clear();
          }
          s.life.addAll(life);
          s.maintenance.addAll(maint);
          return set.length;
        }, invalidate: false);
        return ToolOutput('Set ${set.join(', ')}. life_cycle_cost shows the comparison.');
      },
    ),
    // ---------------------------------------------------------------- memorial and O&M plan (PRD-03, PRD-12)
    cadOp(
      b,
      group: 'engineering',
      name: 'set_memorial_texts',
      effect: ToolEffect.write,
      description:
          'Reports → Technical documents → Memorial, its texts: objective (the objective and scope, printed before the generated objective) and notes (closing remarks). The rest of the memorial comes from the project (document_text "memorial" reads it). An empty text clears it. One undo step. Output: what was set.',
      schema: obj({'objective': str('Objective and scope.'), 'notes': str('Closing remarks.')}),
      run: (a, _) async {
        engNotBusy(c);
        if (!a.has('objective') && !a.has('notes')) throw ToolInputError('Give "objective" and/or "notes".');
        b.change('set_memorial_texts', () {
          final s = b.p.deliverables.memorial;
          if (a.has('objective')) s.objective = a.str('objective')!;
          if (a.has('notes')) s.notes = a.str('notes')!;
          return true;
        }, invalidate: false);
        return const ToolOutput('Set. document_text "memorial" shows the memorial.');
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'set_om_settings',
      effect: ToolEffect.write,
      description:
          'Reports → Technical documents → Operation and maintenance plan, the figures the project does not hold: filter_delta_m (rise of the pressure loss of a filter over its clean loss that calls for cleaning, metres of water, default 5), chlorine_product_pct (available chlorine of the product, default 10), chlorine_continuous_mg_l (default 1) and chlorine_shock_mg_l (default 10) for the injection rates of every system flow, spares_pct (spare parts as % of what is installed, default 2). One undo step. Output: what was set.',
      schema: obj({
        'filter_delta_m': num_('0.1–50 m.'),
        'chlorine_product_pct': num_('0.1–100 %.'),
        'chlorine_continuous_mg_l': num_('0–100 mg/L.'),
        'chlorine_shock_mg_l': num_('0–500 mg/L.'),
        'spares_pct': num_('0–100 %.'),
      }),
      run: (a, i) async {
        engNotBusy(c);
        final dp = a.number('filter_delta_m', min: 0.1, max: 50);
        final prod = a.number('chlorine_product_pct', min: 0.1, max: 100);
        final cont = a.number('chlorine_continuous_mg_l', min: 0, max: 100);
        final shock = a.number('chlorine_shock_mg_l', min: 0, max: 500);
        final spares = a.number('spares_pct', min: 0, max: 100);
        if ([dp, prod, cont, shock, spares].every((x) => x == null)) throw ToolInputError('Nothing to set.');
        b.change('set_om_settings', () {
          final s = b.p.deliverables.om;
          if (dp != null) s.filterDeltaM = dp;
          if (prod != null) s.chlorineProductPct = prod;
          if (cont != null) s.chlorineContinuousMgL = cont;
          if (shock != null) s.chlorineShockMgL = shock;
          if (spares != null) s.sparesPct = spares;
          return true;
        }, invalidate: false);
        return ToolOutput('Set ${[for (final k in i.keys) if (i[k] != null) k].join(', ')}. document_text "om" shows the plan.');
      },
    ),
    // ---------------------------------------------------------------- budget by compositions (PRD-21)
    cadOp(
      b,
      group: 'engineering',
      name: 'set_budget_settings',
      effect: ToolEffect.write,
      description:
          'Reports → Technical documents → Budget by compositions, its rates: the parts of the BDI of the services in % (central_admin_pct, insurance_guarantee_pct, risk_pct, financial_pct, profit_pct; taxes pis_pct, cofins_pct, iss_pct, cprb_pct — BDI = (1 + AC + S + G + R)(1 + DF)(1 + L)/(1 − I) − 1, Acórdão TCU 2622/2013; defaults the first quartile of the ruling for water-supply networks), materials_bdi_pct (the BDI of the supply of materials; -1 = the BDI of the services), hourly_costs {resource: project currency per hour} for the resources ${[for (final r in budgetResources) r.key].join(', ')} (null value or reset_hourly_costs: back to the reference ones), period_days (working days of a period of the physical-financial schedule: 5 a week, 22 a month). One undo step; the results are kept. Output: the BDI now and what was set; document_text "budget" reads the budget.',
      schema: obj({
        'central_admin_pct': num_('0–100.'),
        'insurance_guarantee_pct': num_('0–100.'),
        'risk_pct': num_('0–100.'),
        'financial_pct': num_('0–100.'),
        'profit_pct': num_('0–100.'),
        'pis_pct': num_('0–100.'),
        'cofins_pct': num_('0–100.'),
        'iss_pct': num_('0–100.'),
        'cprb_pct': num_('0–100 (4.5 under the payroll relief of Law 13.161/2015).'),
        'materials_bdi_pct': num_('-1 (same as the services) or 0–100.'),
        'hourly_costs': {'type': 'object', 'description': 'Resource key → hourly cost (project currency).'},
        'reset_hourly_costs': bool_('Back to the reference hourly costs.'),
        'period_days': int_('1–260 working days.'),
      }),
      run: (a, i) async {
        engNotBusy(c);
        const pcts = ['central_admin_pct', 'insurance_guarantee_pct', 'risk_pct', 'financial_pct', 'profit_pct', 'pis_pct', 'cofins_pct', 'iss_pct', 'cprb_pct'];
        final values = {for (final k in pcts) k: a.number(k, min: 0, max: 100)};
        final mat = a.number('materials_bdi_pct', min: -1, max: 100);
        final period = a.integer('period_days', min: 1, max: 260);
        final costs = <String, double?>{};
        final raw = i['hourly_costs'];
        if (raw != null) {
          if (raw is! Map) throw ToolInputError('"hourly_costs" must be an object {resource: cost}.');
          for (final e in raw.entries) {
            final key = '${e.key}';
            if (!budgetResources.any((r) => r.key == key)) throw ToolInputError('No resource "$key": ${[for (final r in budgetResources) r.key].join(', ')}.');
            final v = e.value;
            if (v != null && (v is! num || !v.isFinite || v < 0)) throw ToolInputError('"hourly_costs.$key" must be a number ≥ 0 (or null for the reference).');
            costs[key] = (v as num?)?.toDouble();
          }
        }
        final set = [
          for (final k in i.keys)
            if (i[k] != null) k,
        ];
        if (set.isEmpty) throw ToolInputError('Nothing to set.');
        b.change('set_budget_settings', () {
          final s = b.p.deliverables.budget;
          void pct(String k, void Function(double v) to) {
            final v = values[k];
            if (v != null) to(v);
          }

          pct('central_admin_pct', (v) => s.centralAdminPct = v);
          pct('insurance_guarantee_pct', (v) => s.insuranceGuaranteePct = v);
          pct('risk_pct', (v) => s.riskPct = v);
          pct('financial_pct', (v) => s.financialPct = v);
          pct('profit_pct', (v) => s.profitPct = v);
          pct('pis_pct', (v) => s.pisPct = v);
          pct('cofins_pct', (v) => s.cofinsPct = v);
          pct('iss_pct', (v) => s.issPct = v);
          pct('cprb_pct', (v) => s.cprbPct = v);
          if (mat != null) s.materialsBdiPct = mat < 0 ? -1.0 : mat;
          if (a.flag('reset_hourly_costs') ?? false) s.rates.clear();
          for (final e in costs.entries) {
            if (e.value == null) {
              s.rates.remove(e.key);
            } else {
              s.rates[e.key] = e.value!;
            }
          }
          if (period != null) s.periodDays = period;
          return true;
        }, invalidate: false);
        final s = b.p.deliverables.budget;
        return ToolOutput('Set ${set.join(', ')}. BDI of the services ${engN(s.servicesBdi * 100, 2)} %, of the materials ${engN(s.materialsBdi * 100, 2)} %.');
      },
    ),
  ];
}
