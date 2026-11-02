/// Engineering operations of the design management (Design and Reports
/// menus): design alternatives, the controller programme and its CSV, the
/// extra lines of the quote, the design check, clearing the results, the
/// reports panel and the hydraulic grade line.
library;

import '../../core/api.dart';
import '../widgets/reports_panel.dart' show reportCellText, reportTabKeys;
import 'agent_tools.dart';
import 'ops_eng_common.dart';

/// Report tabs by name (the `reports.<name>` keys of the Reports menu).
final reportTabNames = [for (final k in reportTabKeys) k.substring('reports.'.length)];

/// The tables each report tab shows (get_report_table keys); empty for the
/// charts and the messages.
const reportTabTables = <String, List<String>>{
  'zone': ['zones'],
  'pipes': ['pipes'],
  'outlets': ['outlets'],
  'mainline': ['mainline', 'devices'],
  'bom': ['bom'],
  'water': ['water'],
  'hgl': [],
  'messages': ['messages'],
  'profile': [],
  'flushing': ['flushing'],
  'surge': ['surge'],
  'crop': ['crop'],
  'schedule': ['schedule'],
  'pivots': ['pivots'],
  'pivotSpans': ['pivotSpans'],
  'electrical': ['electrical'],
  'proposal': ['proposal'],
  'trench': ['trench', 'works'],
  'bomZones': ['bomZones'],
  'comments': ['comments'],
  'revisions': ['revisions'],
  'scenarios': ['scenarios'],
  'requirement': ['requirement', 'requirementTotals', 'licensing'],
  'pivotPackage': ['pivotPackageSummary', 'pivotPackage', 'pivotTimer'],
  'machines': ['cornerArm', 'vri', 'pivotElectrical'],
  'vih': ['vih'],
};

String _scenarioTable(AgentToolbox b) {
  final p = b.p;
  final u = p.params.units;
  final r = b.c.results;
  final current = r == null ? null : scenarioMetrics(p, r);
  final rows = <List<Object?>>[
    if (current != null) ['(current design)', '', for (final k in scenarioMetricKeys) reportCellText(scenarioMetricCell(k, current[k], u))],
    for (final sc in p.scenarios) [sc.name, sc.id, for (final k in scenarioMetricKeys) reportCellText(scenarioMetricCell(k, sc.metrics[k], u))],
  ];
  if (rows.isEmpty) return 'No alternatives saved${r == null ? ' and no design results to save' : ''}.';
  return engTable(['name', 'id', for (final k in scenarioMetricKeys) scenarioMetricHeader(k, p, b.t.call)], rows);
}

List<AgentTool> designManagementOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    // ---------------------------------------------------------------- scenarios
    engOp(
      b,
      name: 'design_alternatives',
      effect: ToolEffect.read,
      effectFor: (i) => (i['action'] ?? 'list') == 'list' ? ToolEffect.read : ToolEffect.write,
      confirm: (i) => i['action'] == 'restore',
      description: 'Design → Alternatives (scenarios): "list" compares the saved alternatives with the current design figure by figure (capital, energy, annual total, peak flow, pump head, pressures, uniformity, pipe lengths, messages; display units); "save" stores the designed project under a name with its results (needs design results); "restore" brings an alternative back — its drawing, settings and results replace the current ones (one undo step, always confirmed); "delete" removes one. Use it to compare options (e.g. two pipe materials) before choosing. Inputs: action list|save|restore|delete (default list), name (save; default "Alternative n"), id (restore/delete: the id or the name). Output: the comparison table after the action.',
      schema: obj({
        'action': str('Default list.', ['list', 'save', 'restore', 'delete']),
        'name': str('Name of the alternative to save.'),
        'id': str('Id or name of the alternative (restore, delete).'),
      }),
      summary: (i) => engSummary(b, 'ai.op.design_alternatives.${i['action'] ?? 'list'}', 'ai.op.design_alternatives.list', {'n': '${i['name'] ?? i['id'] ?? ''}'}),
      run: (a, _) async {
        final action = a.str('action') ?? 'list';
        if (action != 'list') engNotBusy(c);
        Scenario find() {
          final ref = a.str('id', required: true)!, low = ref.toLowerCase();
          return b.p.scenarios.where((s) => s.id == ref || s.name.toLowerCase() == low).firstOrNull ??
              (throw ToolInputError('No alternative "$ref". Saved: ${b.p.scenarios.map((s) => '${s.id} (${s.name})').join(', ')}.'));
        }

        switch (action) {
          case 'save':
            engNeedResults(c);
            final sc = c.saveScenario(a.str('name') ?? '');
            if (sc == null) throw ToolInputError('Not saved: no design results.');
            return ToolOutput('Saved "${sc.name}" (${sc.id}).\n${_scenarioTable(b)}');
          case 'restore':
            final sc = find();
            if (!c.restoreScenario(sc.id)) throw ToolInputError('"${sc.name}" could not be restored (its data are damaged, or a design is running).');
            return ToolOutput('Restored "${sc.name}": its drawing, settings and results are the current ones now.\n${_scenarioTable(b)}');
          case 'delete':
            final sc = find();
            c.deleteScenario(sc.id);
            return ToolOutput('Deleted "${sc.name}".\n${_scenarioTable(b)}');
          default:
            return ToolOutput(_scenarioTable(b));
        }
      },
    ),
    // ---------------------------------------------------------------- controller programme
    engOp(
      b,
      name: 'controller_program',
      effect: ToolEffect.read,
      effectFor: (i) => i['apply_durations'] == true ? ToolEffect.write : ToolEffect.read,
      description: 'Design → Management → Schedule: the controller programme the system flows give over the coming days — which flow runs when, with which zones, for how long — from the irrigation requirement of the areas (crop, climate, soil), the run time each flow needs per irrigation day, the busiest day and the warnings. apply_durations true sets each system flow\'s duration to the time it needs (the dialog\'s Apply; one undo step; results discarded). set_system_flows edits the flows themselves; export_controller_program saves the CSV. Better with design results (real flows). Inputs: days 1–60 (default 7), day_start_hour 0–23 (default 6), keep_start_hours (keep each flow\'s own start hour instead of running them one after another; default false), entries_limit 1–500 (default 60), apply_durations. Output: hours per flow, the busiest day, the warnings and the programme table (date, flow, zones, start, end, hours).',
      schema: obj({
        'days': int_('Days to programme, 1–60; default 7.'),
        'day_start_hour': num_('Hour the irrigation day starts, 0–23; default 6.'),
        'keep_start_hours': bool_('Keep the start hours of the flows (default false).'),
        'entries_limit': int_('Rows of the programme, 1–500; default 60.'),
        'apply_durations': bool_('Set each flow\'s duration to the hours it needs.'),
      }),
      summary: (i) => t(i['apply_durations'] == true ? 'ai.op.controller_program.apply' : 'ai.op.controller_program'),
      run: (a, _) async {
        final p = b.p;
        final prog = buildControllerProgram(
          p,
          c.results,
          days: a.integer('days', min: 1, max: 60) ?? 7,
          dayStartHour: a.number('day_start_hour', min: 0, max: 23) ?? 6,
          keepStartHours: a.flag('keep_start_hours') ?? false,
        );
        // rounded to the minute, "+1 d" after midnight
        String hhmm(double h) => clockText(h);

        final out = <String>[
          if (c.results == null) 'No design results: the flows are estimated from the catalogue; run_design for the real ones.',
          if (p.systemFlows.isEmpty) 'The project has no system flows (every zone runs at once): set_system_flows first.',
          for (final f in p.systemFlows) '${f.name}: needs ${engN(prog.perFlowHours[f.id] ?? 0, 2)} h per irrigation day (set ${engN(f.durationHours, 2)} h, from ${engN(f.startHour, 2)} h).',
          'Busiest day: ${engN(prog.maxDailyHours, 1)} h of irrigation${prog.maxDailyHours > 24 ? ' (MORE THAN A DAY)' : ''}.',
          if (prog.entries.isEmpty)
            'No programme: the areas need a crop or a daily depth, and the system flows zones (msg: ${t('msg.noAreas')}).'
          else
            engTable(
              ['date', 'flow', 'zones', 'start', 'end', 'hours'],
              [
                for (final e in prog.entries) [e.day.toIso8601String().substring(0, 10), e.flowName, e.zones.join(' + '), hhmm(e.startHour), hhmm(e.endHour), engN(e.durationHours, 2)],
              ],
              max: a.integer('entries_limit', min: 1, max: 500) ?? 60,
            ),
        ];
        if (a.flag('apply_durations') ?? false) {
          if (prog.entries.isEmpty) throw ToolInputError('Nothing to apply: the programme is empty.');
          engNotBusy(c);
          final n = b.change('controller_program', () {
            var k = 0;
            for (final f in b.p.systemFlows) {
              final h = prog.perFlowHours[f.id];
              if (h != null && h > 0) {
                f.durationHours = double.parse(h.toStringAsFixed(2));
                k++;
              }
            }
            return k;
          });
          out.add('Applied: durations of $n system flows set. Results discarded: run the design again.');
        }
        return ToolOutput(out.join('\n') + engCodes(b, prog.warnings));
      },
    ),
    engOp(
      b,
      name: 'export_controller_program',
      effect: ToolEffect.export,
      description: 'File → Export report → Controller programme: saves the irrigation programme of the system flows as a CSV file (date, flow, zones, start, end, duration) to load into a controller or hand to the operator. Always confirmed by the user (a download in the browser). Inputs: days 1–60 (default 14, as the menu), day_start_hour 0–23 (default 6), keep_start_hours (default false). Output: the file name and the rows.',
      schema: obj({'days': int_('Days, 1–60; default 14.'), 'day_start_hour': num_('0–23; default 6.'), 'keep_start_hours': bool_('Keep the start hours of the flows (default false).')}),
      run: (a, _) async {
        final prog = buildControllerProgram(
          b.p,
          c.results,
          days: a.integer('days', min: 1, max: 60) ?? 14,
          dayStartHour: a.number('day_start_hour', min: 0, max: 23) ?? 6,
          keepStartHours: a.flag('keep_start_hours') ?? false,
        );
        if (prog.entries.isEmpty) throw ToolInputError('${t('msg.noAreas')} (no programme to export: the areas need a crop or a daily depth and the flows zones).');
        final file = '${engStem(c)}_schedule.csv';
        await engFileSink(c, file, 'text/csv', controllerProgramCsv(prog, t: t.call));
        return ToolOutput('Saved $file (${prog.entries.length} rows).');
      },
    ),
    // ---------------------------------------------------------------- quote extras
    engOp(
      b,
      name: 'set_quote_extras',
      effect: ToolEffect.write,
      description: 'Design → Quote → Extra lines: services and items outside the bill of materials (design fee, commissioning, transport of a machine…) added to the quote; set_quote sets the percentages and terms, get_report_table "proposal" reads the quote. One undo step; the results are kept. Inputs: action add|update|remove|clear|replace; items [{description, unit, quantity, unit_price (project currency)}] (add, replace; update takes the first item); index (0-based line, update/remove). Output: the extra lines with their totals.',
      schema: obj(
        {
          'action': str(null, ['add', 'update', 'remove', 'clear', 'replace']),
          'items': arr(
            obj(
              {'description': str('What the line is.'), 'unit': str('Unit (default "serv.").'), 'quantity': num_('Default 1.'), 'unit_price': num_('Project currency; negative for a credit.')},
              required: ['description'],
            ),
            'Extra lines.',
            50,
          ),
          'index': int_('Line number (0-based) for update or remove.'),
        },
        required: ['action'],
      ),
      summary: (i) => engSummary(b, 'ai.op.set_quote_extras.${i['action']}', 'ai.op.set_quote_extras'),
      run: (a, i) async {
        engNotBusy(c);
        final action = a.str('action', required: true)!;
        final items = <ProposalExtra>[];
        for (final raw in (i['items'] as List?) ?? const []) {
          final x = ToolArgs(Map<String, dynamic>.from(raw as Map));
          items.add(
            ProposalExtra(
              description: x.str('description', required: true)!,
              unit: x.str('unit') ?? t('proposal.unitService'),
              quantity: x.number('quantity', min: 0, max: 1e9) ?? 1,
              unitPrice: x.number('unit_price', min: -1e12, max: 1e12) ?? 0,
            ),
          );
        }
        final extras = b.p.proposal.extras;
        int index() {
          final k = a.integer('index', min: 0, required: true)!;
          if (k >= extras.length) throw ToolInputError('No line $k: the quote has ${extras.length} extra lines.');
          return k;
        }

        if ((action == 'add' || action == 'replace' || action == 'update') && items.isEmpty) throw ToolInputError('"items" is needed to $action.');
        final k = action == 'update' || action == 'remove' ? index() : -1;
        b.change('set_quote_extras', () {
          final ex = b.p.proposal.extras;
          switch (action) {
            case 'add':
              ex.addAll(items);
            case 'update':
              ex[k] = items.first;
            case 'remove':
              ex.removeAt(k);
            case 'clear':
              ex.clear();
            default:
              ex
                ..clear()
                ..addAll(items);
          }
          return ex.length;
        }, invalidate: false);
        final cur = b.p.params.currency;
        final now = b.p.proposal.extras;
        return ToolOutput(
          now.isEmpty
              ? 'The quote has no extra lines.'
              : 'Extra lines of the quote:\n${engTable(['#', 'description', 'unit', 'quantity', 'unit price $cur', 'total $cur'], [
                  for (var j = 0; j < now.length; j++) ['$j', now[j].description, now[j].unit, engN(now[j].quantity), engN(now[j].unitPrice), engN(now[j].total)],
                ])}',
        );
      },
    ),
    // ---------------------------------------------------------------- design check
    engOp(
      b,
      name: 'design_check',
      description: 'Design → Design check: runs the check of the drawing and the settings (unconnected items, missing catalogue references, zones without a valve, settings out of range…), marks the unconnected items on the user\'s drawing as the menu does, and returns every message with its explanation and corrections — the same list as get_design_messages (apply_fix takes its numbers). Use it after drawing, before run_design. No input. Output: the error and warning counts and the numbered messages.',
      schema: obj({}),
      run: (a, _) async {
        final r = c.runDesignCheckReport();
        return ToolOutput('Design check: ${r.errors} errors, ${r.warnings} warnings in the drawing.\n${messagesText(b)}');
      },
    ),
    engOp(
      b,
      name: 'clear_results',
      effect: ToolEffect.write,
      description: 'Design → Clear results: removes the design results from the screen and the reports (the drawing, the pipe sizes and the settings stay; run_design or analyse_design computes them again). Use it when the user asks, or to show the drawing without result colours. Not an undo step (results are recomputed, not restored). No input.',
      schema: obj({}),
      run: (a, _) async {
        engNotBusy(c);
        if (c.results == null) return const ToolOutput('There were no results.');
        c.clearResults();
        return const ToolOutput('Results cleared.');
      },
    ),
    // ---------------------------------------------------------------- reports panel
    engOp(
      b,
      name: 'show_report_tab',
      description: 'Reports menu: opens the reports panel on the user\'s screen at a tab (a view change; the project is not changed), to show the user a table or chart. To READ a table yourself use get_report_table (this op says which tables a tab holds); hydraulic_grade_line and terrain_profile give the two charts as numbers; get_design_messages the messages. Input: tab. Output: the tab opened and its table keys.',
      schema: obj({'tab': str(null, reportTabNames)}, required: ['tab']),
      summary: (i) => t('ai.op.show_report_tab', {'n': t.has('reports.${i['tab']}') ? t('reports.${i['tab']}') : '${i['tab']}'}),
      run: (a, _) async {
        final tab = a.str('tab', required: true)!;
        final k = reportTabNames.indexOf(tab);
        c.reportTab = k;
        c.showReports = true;
        c.refresh();
        final keys = reportTabTables[tab] ?? const [];
        return ToolOutput(
          'Reports panel opened at "${t('reports.$tab')}".${keys.isEmpty ? (tab == 'hgl' ? ' Its chart: hydraulic_grade_line.' : (tab == 'profile' ? ' Its chart: terrain_profile (and hydraulic_grade_line for a designed pipe).' : '')) : ' Tables: ${keys.join(', ')} (get_report_table).'}${c.results == null && !const {'water', 'messages', 'profile', 'crop', 'schedule', 'trench', 'comments', 'revisions', 'scenarios', 'requirement'}.contains(tab) ? ' The tab needs design results (run_design).' : ''}',
        );
      },
    ),
    // ---------------------------------------------------------------- hydraulic grade line
    engOp(
      b,
      name: 'hydraulic_grade_line',
      description: 'Reports → Grade line: the hydraulic grade line along a designed pipe, lateral or drip tape, segment by segment — chainage, ground/pipe elevation, pressure head, the grade line (elevation + pressure), flow, velocity, diameter — with the pressure window of its zone. Given a zone valve or a zone name, the lateral of the zone\'s lowest-pressure emitter (as the panel). Needs design results; changes nothing. Inputs: id (pipe, lateral, tape, valve or zone name; default the first lateral of the first zone), limit 1–500 segments (default 100). Output: the window and the segment table (m).',
      schema: obj({'id': str('Pipe, lateral, tape, valve or zone name.'), 'limit': int_('Segments, 1–500; default 100.')}),
      run: (a, _) async {
        engNeedResults(c);
        final r = c.results!;
        final by = r.pipesByEntity;
        String? id;
        double? lo, hi;
        var title = '';
        if (a.has('id')) {
          final e = b.find(a.str('id')!);
          id = e.id;
          if (e is ControlValveEntity) {
            final z = r.zones[e.id];
            if (z == null || z.minOutlet == null) throw ToolInputError('Zone "${e.zoneName}" has no design result with emitters.');
            id = z.minOutlet!.entityId;
            lo = z.allowedMin;
            hi = z.allowedMax;
            title = z.zoneName;
          }
          if (by[id] == null) throw ToolInputError('"${a.str('id')}" has no designed segments (pipes, laterals and tapes do; run_design).');
          for (final z in r.zones.values) {
            if (z.pipes.any((x) => x.entityId == id)) {
              lo ??= z.allowedMin;
              hi ??= z.allowedMax;
              if (title.isEmpty) title = z.zoneName;
            }
          }
        } else {
          for (final z in r.zones.values) {
            final first = z.pipes.where((x) => b.p.byId(x.entityId) is SpraylineEntity || b.p.byId(x.entityId) is TapeEntity).firstOrNull;
            if (first != null) {
              id = first.entityId;
              lo = z.allowedMin;
              hi = z.allowedMax;
              title = z.zoneName;
              break;
            }
          }
          if (id == null) throw ToolInputError('No designed lateral: give "id" (a pipe, lateral or tape).');
        }
        final segs = [...by[id]!]..sort((x, y) => x.segmentIndex.compareTo(y.segmentIndex));
        var d = 0.0;
        final rows = <List<Object?>>[];
        for (final s in segs) {
          rows.add([
            engN(d, 1),
            engN(d + s.length, 1),
            engN(s.elevationA, 2),
            engN(s.elevationB, 2),
            engN(s.pressureStart, 2),
            engN(s.pressureEnd, 2),
            engN(s.elevationA + s.pressureStart, 2),
            engN(s.elevationB + s.pressureEnd, 2),
            engN(s.flow * 3600, 3),
            engN(s.velocity, 2),
            engN(s.diameter * 1000, 1),
          ]);
          d += s.length;
        }
        final e = b.p.byId(id);
        return ToolOutput(
          '${e == null ? id : '${b.kindOf(e)} ${b.nameOf(e)} ($id)'}${title.isEmpty ? '' : ', zone $title'}: ${engN(d, 1)} m in ${segs.length} segments${lo != null ? '; zone pressure window ${engN(lo, 2)}–${engN(hi!, 2)} m' : ''}.\n${engTable(['from m', 'to m', 'z start', 'z end', 'p start m', 'p end m', 'HGL start', 'HGL end', 'flow m³/h', 'v m/s', 'ID mm'], rows, max: a.integer('limit', min: 1, max: 500) ?? 100)}',
        );
      },
    ),
  ];
}
