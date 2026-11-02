/// Operations (find_operations / run_operation) added in 1.6.0 for automatic design:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import 'dart:math' as math;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/auto_fix.dart';
import '../../../core/design/block_generator.dart' show SubmainPosition;
import '../../../core/design/lateral_limit.dart';
import '../../../core/design/region_trace.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../state/fix_review.dart';
import '../../tools/trace_image_tool.dart';
import '../../widgets/lateral_limit_view.dart' show emitterLimitInput, limitingRun, tapeLimitInput;
import '../agent_tools.dart';
import '../agent_tools_design.dart' show outlineOf;
import '../agent_tools_ops.dart';
import '../vision_render.dart' show VisionRenderer;

String _len(double m) => '${fmt(m, m >= 100 ? 0 : 1)} m';

String _run(LateralRun r) => r.emitters == 0
    ? 'no emitter works within the limits'
    : '${_len(r.length)} (${r.emitters} emitters, inlet ${fmt(r.inletHeadM, 2)} m, flow ${fmt(r.inletFlow * 3600, 3)} m³/h, flow variation ${fmt(r.flowVariationPct, 1)} %, pressure ${fmt(r.minHeadM, 2)}–${fmt(r.maxHeadM, 2)} m, limited by ${r.limitedBy.name})';

/// The changes "fix automatically" made, one line each with its id.
String _steps(AgentToolbox b, List<FixStep> steps) =>
    [for (final s in steps) '- ${s.id}: ${b.t(s.result.key, s.result.args)}${s.entityIds.isEmpty ? '' : ' (items ${s.entityIds.take(8).join(', ')})'}'].join('\n');

String _changes(AgentToolbox b, List<OptimizeChange> changes) => [for (final ch in changes) '- ${ch.id}: ${b.t(ch.result.key, ch.result.args)}'].join('\n');

OptimizeOptions _optOptions(ToolArgs a) =>
    OptimizeOptions(choosePumps: a.flag('choose_pumps') ?? true, resizeValves: a.flag('resize_valves') ?? true, resizeFixedPipes: a.flag('resize_fixed_pipes') ?? false);

String _score(DesignScore d) => '${d.errors} errors, ${d.warnings} warnings, annual cost ${fmt(d.annualTotal, 2)}';

List<AgentTool> opsAut(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  void notBusy() {
    if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
  }

  return [
    // ---------------------------------------------------------------- the computed maximum lateral length
    OpTool(
      group: 'engineering',
      name: 'max_lateral_length',
      description:
          'The longest lateral a block can have (as the block, SUBDIV and LAYOUT dialogs compute it): how far a drip tape, or a lateral pipe with an emitter or sprinkler every spacing_m, can run from its inlet before the flow of its emitters varies more than flow_variation_pct (default 10 %, the usual rule; about 20 % of pressure for sprinklers), with the mean emitter pressure at head_m, inside the pressure window of the emitter and the velocity limit, uphill and downhill on the slope. '
          'The slope: slope_pct, or from the terrain of the project fitted over the closed shape area along direction_deg (default: along its longest edge). lateral "tape" (tape id, head_m = its inlet pressure) or "emitter" (outlet, nozzle, pipe — default the largest lateral pipe — and spacing_m). '
          'feed "start"/"end"/"centre" says which way the laterals of the block run (start: along direction_deg) and picks the limit that applies. Output: the longest lateral uphill and downhill (length, emitters, inlet pressure, flow, variation, what limits it). No side effects.',
      inputSchema: obj({
        'lateral': str('What the lateral is (default tape when a tape id is given).', ['tape', 'emitter']),
        'tape': str('Drip tape id (search_catalog kind "tape").'),
        'outlet': str('Emitter or sprinkler family id (search_catalog kind "emitter").'),
        'nozzle': str('Nozzle id of that family (default its first).'),
        'pipe': str('Lateral pipe id (default the largest enabled lateral pipe).'),
        'spacing_m': num_('Emitter spacing along the lateral, 0.05–100 m (emitter laterals).'),
        'head_m': num_('Mean emitter pressure (tape: its inlet pressure), 0.5–120 m; default the item\'s nominal.'),
        'flow_variation_pct': num_('Flow variation allowed along the lateral, 1–50 % (default 10).'),
        'slope_pct': num_('Slope along the lateral from its inlet, −50–50 % (uphill positive); default from the terrain over area.'),
        'area': str('Closed shape (block, field) whose terrain gives the slope.'),
        'direction_deg': num_('Direction of the rows, degrees counter-clockwise from east (default the longest edge of area).'),
        'feed': str('Where the laterals of the block are fed.', ['start', 'end', 'centre']),
      }),
      summary: (_) => t('ai.op.max_lateral_length'),
      handler: (i) async {
        final a = ToolArgs(i);
        final p = b.p;
        final cat = p.catalog;
        double? slope = a.number('slope_pct', min: -50, max: 50);
        var dir = a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : null;
        if (slope == null && a.has('area')) {
          final poly = outlineOf(b.find(a.str('area')!));
          if (poly == null) throw ToolInputError('"${a.str('area')}" is not a closed shape.');
          if (dir == null) {
            var best = 0.0;
            for (var k = 0; k < poly.length; k++) {
              final e = poly[(k + 1) % poly.length] - poly[k];
              if (e.length > best) {
                best = e.length;
                dir = e.normalized;
              }
            }
          }
          slope = terrainSlopeAlong(b.terrain, poly, dir ?? const Pt(1, 0));
        }
        final tapeId = a.str('tape');
        final kind = a.str('lateral') ?? (tapeId != null ? 'tape' : 'emitter');
        final head = a.number('head_m', min: 0.5, max: 120);
        final variation = a.number('flow_variation_pct', min: 1, max: 50) ?? defaultLateralFlowVariationPct;
        final input = switch (kind) {
          'tape' => () {
            final tp = cat.tape(tapeId ?? '') ?? (throw ToolInputError('Give tape: a drip tape id (search_catalog kind "tape").'));
            return tapeLimitInput(p, tp.id, head ?? tp.defaultInletHeadM, slope);
          }(),
          _ => () {
            final o = cat.outlet(a.str('outlet') ?? '') ?? (throw ToolInputError('Give outlet: an emitter or sprinkler family id (search_catalog kind "emitter").'));
            final n = o.nozzle(a.str('nozzle')) ?? o.nozzles.firstOrNull ?? (throw ToolInputError('"${o.id}" has no nozzles.'));
            final spacing = a.number('spacing_m', min: 0.05, max: 100, required: true)!;
            final pipe = a.str('pipe');
            if (pipe != null && cat.pipe(pipe) == null) throw ToolInputError('No pipe "$pipe" in the catalogue.');
            return emitterLimitInput(p, o.id, n.id, head ?? n.defaultHeadM, pipe, spacing, slope);
          }(),
        };
        if (input == null) throw ToolInputError('The catalogue lacks an item of that lateral (a lateral pipe for an emitter lateral?).');
        final runs = maxLateralRunsBothWays(
          input.spec,
          nominalHeadM: input.nominalHeadM,
          allowedFlowVariationPct: variation,
          slopePct: input.slopePct ?? 0,
          minHeadM: input.minHeadM,
          maxHeadM: input.maxHeadM,
          maxVelocity: input.maxVelocity,
        );
        final feed = switch (a.str('feed')) {
          'start' => SubmainPosition.start,
          'end' => SubmainPosition.end,
          'centre' => SubmainPosition.centre,
          _ => null,
        };
        final s = input.slopePct ?? 0;
        final limit = limitingRun(runs, s, feed);
        return ToolOutput(
          [
            'Flow variation allowed ${fmt(variation, 1)} %, mean emitter pressure ${fmt(input.nominalHeadM, 2)} m${input.pipeName == null ? '' : ', on ${input.pipeName}'}; slope along the rows ${input.slopePct == null ? 'none (no terrain: level)' : '${fmt(s, 2)} %'}.',
            if (s.abs() < 1e-9) 'Longest lateral (level): ${_run(runs.uphill)}.' else ...['Longest lateral fed uphill: ${_run(runs.uphill)}.', 'Longest lateral fed downhill: ${_run(runs.downhill)}.'],
            'The limit for ${feed == null ? 'either way (the shorter)' : 'laterals fed at the ${feed.name}'}: ${_len(limit.length)}.',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- review of "fix automatically"
    OpTool(
      group: 'engineering',
      name: 'preview_auto_fix',
      description: 'What "Fix automatically" would correct, item by item, without keeping it: runs the corrections (designing between rounds), lists each with its id, then puts the project back as it was (the corrections stay one redo step away). Use it to show the user the list and ask which to keep; then auto_fix_selected with the ids they keep. A booster pump on a mains connection is listed among the decisions, never applied. Output: the corrections with ids and what is left.',
      inputSchema: obj({}),
      effect: ToolEffect.write,
      summary: (_) => t('ai.op.preview_auto_fix'),
      handler: (_) async {
        notBusy();
        final r = await c.autoFixAll(skip: (a, kind, results) => addsBoosterToMains(b.p, a, kind, results));
        if (r == null) throw ToolInputError('Refused: a design is running.');
        // the project (and the history) as it was
        c.undo();
        return ToolOutput(
          r.steps.isEmpty
              ? 'Nothing could be fixed automatically (${r.remaining.length} messages left).'
              : '${r.steps.length} corrections (the project was put back as it was; run auto_fix_selected with the ids to keep):\n${_steps(b, r.steps)}\nAfter them ${r.errors} errors and ${r.warnings} warnings would be left.',
        );
      },
    ),
    OpTool(
      group: 'engineering',
      name: 'auto_fix_selected',
      description: '"Fix automatically" with only the corrections whose ids preview_auto_fix listed in keep (the others left out, as the user ticks them in the review of the dialog): the corrections are made in rounds with the design between them, so one that only comes up after a correction left out does not happen. One undo step. Output: the corrections applied and the messages left.',
      inputSchema: obj({'keep': arr(str(), 'Ids of the corrections to make (from preview_auto_fix).', 200)}, required: ['keep']),
      effect: ToolEffect.write,
      summary: (i) => t('ai.op.auto_fix_selected', {'n': '${(i['keep'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        notBusy();
        final keep = ToolArgs(i).strings('keep', required: true).toSet();
        final r = await c.autoFixAll(skip: (a, kind, results) => addsBoosterToMains(b.p, a, kind, results) || !keep.contains(fixStepId(a, kind)));
        if (r == null) throw ToolInputError('Refused: a design is running.');
        final missing = keep.difference({for (final s in r.steps) s.id});
        return ToolOutput(
          '${r.steps.isEmpty ? 'No correction was made.' : 'Made ${r.steps.length}:\n${_steps(b, r.steps)}'}${missing.isEmpty ? '' : '\nNot made (no longer offered after the others): ${missing.take(20).join(', ')}.'}\nLeft: ${r.errors} errors, ${r.warnings} warnings.',
        );
      },
    ),
    // ---------------------------------------------------------------- review of "optimise"
    OpTool(
      group: 'engineering',
      name: 'preview_optimize',
      description: 'What "Optimise" would change, item by item, without keeping it: runs the optimisation (the changes kept only when the design gets cheaper without new errors or warnings), lists each change with its id and the before/after scores, then puts the project back as it was. Use it to show the user the list; then optimize_selected with the ids to keep. Inputs as optimize_design.',
      inputSchema: obj({
        'choose_pumps': bool_('Pick the pump of each pumped supply (default true).'),
        'resize_valves': bool_('Pick the zone valves by flow (default true).'),
        'resize_fixed_pipes': bool_('Let the design resize the pipes fixed by hand too (default false).'),
      }),
      effect: ToolEffect.write,
      summary: (_) => t('ai.op.preview_optimize'),
      handler: (i) async {
        notBusy();
        final r = await c.optimizeDesign(_optOptions(ToolArgs(i)));
        if (r == null) throw ToolInputError('Refused: a design is running.');
        if (!r.improved) return ToolOutput('Nothing to keep: no change made the design better (before: ${_score(r.before)}).');
        c.undo();
        return ToolOutput(
          '${r.changes.length} changes (the project was put back as it was; run optimize_selected with the same options and the ids to keep):\n${_changes(b, r.changes)}\nBefore: ${_score(r.before)}. With all of them: ${_score(r.after)}.',
        );
      },
    ),
    OpTool(
      group: 'engineering',
      name: 'optimize_selected',
      description: '"Optimise" keeping only the changes whose ids preview_optimize listed in keep: the optimisation runs, then the project goes back to before it and only those changes are made again (the same valves, the pump chosen for the same duties) and designed. One undo step. Output: the changes kept and the before/after scores.',
      inputSchema: obj(
        {
          'keep': arr(str(), 'Ids of the changes to keep (from preview_optimize).', 200),
          'choose_pumps': bool_('As in preview_optimize (default true).'),
          'resize_valves': bool_('As in preview_optimize (default true).'),
          'resize_fixed_pipes': bool_('As in preview_optimize (default false).'),
        },
        required: ['keep'],
      ),
      effect: ToolEffect.write,
      summary: (i) => t('ai.op.optimize_selected', {'n': '${(i['keep'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        notBusy();
        final a = ToolArgs(i);
        final keep = a.strings('keep', required: true).toSet();
        final r = await c.optimizeDesign(_optOptions(a));
        if (r == null) throw ToolInputError('Refused: a design is running.');
        if (!r.improved) return ToolOutput('Nothing kept: no change made the design better (before: ${_score(r.before)}).');
        final kept = await c.keepOptimizeChanges(r, keep);
        if (kept == null) return ToolOutput('None of those changes is offered now: the project is as it was (before: ${_score(r.before)}).');
        return ToolOutput('Kept ${kept.changes.length}:\n${_changes(b, kept.changes)}\nBefore: ${_score(r.before)}. After: ${_score(kept.after)}.');
      },
    ),
    // ---------------------------------------------------------------- the outline traced on the satellite image (PRD-05)
    OpTool(
      group: 'site',
      name: 'outline_from_image',
      description: 'The Draw → Trace on image tool (WAND): traces the region of the aerial image around the point at — a field, a lawn, a pond, a yard — by image processing (as trace_region does) and adds it to the project at once as an irrigated area (output "area", default) or a closed polyline, one undo step. tolerance (ΔE 1–80, default automatic), blur_m (0.2–10, default 1; 3–6 for orchards and wide rows) and detail_m (simplification, 0.05–20 m) as in trace_region; name names the area. Needs a georeference and the online imagery. Output: the new id, its area, vertices and how sure the boundary is.',
      inputSchema: obj(
        {
          'at': {...point, 'description': 'A point inside the region, [x, y] in metres.'},
          'output': str('What the outline becomes (default area).', ['area', 'polyline']),
          'tolerance': num_('Colour tolerance in ΔE, 1–80 (default automatic).'),
          'blur_m': num_('Side of the box the colours are averaged over, 0.2–10 m (default 1).'),
          'detail_m': num_('Simplification of the outline, 0.05–20 m (default about a pixel).'),
          'name': str('Name of the new area.'),
        },
        required: ['at'],
      ),
      effect: ToolEffect.write,
      summary: (_) => t('ai.op.outline_from_image'),
      handler: (i) async {
        notBusy();
        final a = ToolArgs(i);
        final seed = a.point('at', required: true)!;
        final renderer = switch (b.snapshots) {
          final VisionRenderer v => v,
          _ => TraceImageSession.renderer,
        };
        final options = RegionTraceOptions(tolerance: a.number('tolerance', min: 1, max: 80), blurM: a.number('blur_m', min: 0.2, max: 10) ?? 1.0, simplifyM: a.number('detail_m', min: 0.05, max: 20));
        ImageTrace tr;
        try {
          tr = await traceImageAt(c, seed, renderer, options: options, tiles: TraceImageSession.of(c).tiles);
        } on ImageTraceError catch (e) {
          throw ToolInputError(switch (e.key) {
            'wand.noGeoref' => 'The project has no georeference: set_site first (find_site gives the coordinates of an address).',
            'wand.noImagery' => 'The aerial imagery could not be loaded here (offline, or no tiles), so nothing can be traced.',
            'wand.noData' => 'The point lies where the imagery has no data: pick a point well inside the region.',
            _ => 'Nothing could be traced around ${AgentToolbox.pt(seed)}: pick a point well inside the region, or give a larger tolerance.',
          });
        }
        final asArea = (a.str('output') ?? 'area') == 'area';
        final pts = List<Pt>.of(tr.outline);
        final Entity e = asArea
            ? AreaEntity(id: b.p.newId(), points: pts, name: a.str('name') ?? '${t('name.area')} ${b.p.entities.whereType<AreaEntity>().length + 1}')
            : PolylineEntity(id: b.p.newId(), points: pts, closed: true, name: a.str('name') ?? '');
        b.change('outline_from_image', () {
          b.p.entities.add(e);
          return 1;
        });
        final r = tr.trace;
        return ToolOutput(
          [
            'Added ${asArea ? 'area' : 'closed polyline'} ${e.id}: ${pts.length} vertices, ${fmt(tr.area, 1)} m² (${fmt(tr.area / 1e4, 4)} ha), tolerance ${fmt(r.tolerance, 1)} ΔE${r.automatic ? ' (automatic)' : ''}.',
            if (r.automatic && !r.clearBoundary) 'No clear boundary was found (the colours change gradually): look at it (view_snapshot) and give a tolerance when it is wrong.',
            if (r.touchesEdge) 'The region still reaches the edge of the area searched (${fmt(math.max(tr.pixels.frame.width, tr.pixels.frame.height), 0)} m): it may go on beyond.',
            if (r.holeCount > 0) '${r.holeCount} holes inside were filled (trees, buildings, water): trace_region with holes true gives their outlines.',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- default burial depths of the quote (AUT-25)
    OpTool(
      group: 'engineering',
      name: 'set_trench_depths',
      description: 'Quote settings (Design → Proposal, Trenches): how deep the pipes drawn without a depth of their own lie, for the trench volumes, their cost and the works schedule: mainline_depth_m (default 0.6; 0 = on the surface) and zone_depth_m (zone pipes and submains; default 0 = on the surface; laterals and tapes always on the surface). The automatic tools also bury the pipes they draw this deep (zone pipes 0.4 m while zone_depth_m is 0). Output: the depths now.',
      inputSchema: obj({'mainline_depth_m': num_('0–5 m.'), 'zone_depth_m': num_('0–5 m.')}),
      effect: ToolEffect.write,
      summary: (_) => t('ai.op.set_trench_depths'),
      handler: (i) async {
        final a = ToolArgs(i);
        final main = a.number('mainline_depth_m', min: 0, max: 5), zone = a.number('zone_depth_m', min: 0, max: 5);
        if (main == null && zone == null) throw ToolInputError('Give mainline_depth_m and/or zone_depth_m.');
        b.change('set_trench_depths', () {
          final q = b.p.proposal;
          q.mainlineDepthM = main ?? q.mainlineDepthM;
          q.zoneDepthM = zone ?? q.zoneDepthM;
          return 1;
        }, invalidate: false);
        final q = b.p.proposal;
        return ToolOutput(
          'Pipes without a depth of their own: mainline ${fmt(q.mainlineDepthM, 2)} m, zone pipes ${q.zoneDepthM > 0 ? '${fmt(q.zoneDepthM, 2)} m' : 'on the surface'} (report table "trench" and the quote).',
        );
      },
    ),
  ];
}
