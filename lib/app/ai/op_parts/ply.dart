/// Operations (find_operations / run_operation) added in 1.7.0 for the
/// irrigation programme played on the plan: a picture of the plan at a
/// moment of the programme (what runs, its flows, velocities, pumps,
/// pressure at the supply, reservoir levels), the animation (GIF) or a
/// frame (PNG) as a file, and the programme as a calendar file (.ics).
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart, joined to
/// [AgentToolbox.operations].
library;

import 'package:flutter/painting.dart' show Canvas, Size;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/programme_calendar.dart';
import '../../../core/design/programme_playback.dart';
import '../../../core/model/geometry.dart';
import '../../canvas/playback_overlay.dart';
import '../../i18n.dart';
import '../../io/playback_export.dart';
import '../../state/controller.dart' show BaseMap, OverlayMode;
import '../../theme.dart';
import '../../widgets/dialogs/programme_player_dialogs.dart' show loadProgrammePlayback;
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../ops_eng_common.dart' show engFileSink, engN, engNotBusy;
import '../view_snapshot.dart';

/// The playback of the programme of the project, or an error the model can
/// act on.
ProgrammePlayback _playback(AgentToolbox b, ToolArgs a, {bool withReservoirs = true}) {
  final month = a.integer('month', min: 1, max: 12);
  if (b.c.results == null) throw ToolInputError('No design results: call run_design first (the player shows the flows, pressures and pumps of the results of every system flow).');
  final (pb, _) = loadProgrammePlayback(b.c, month: month, withReservoirs: withReservoirs);
  if (pb == null) throw ToolInputError('${I18n('en')('ply.noRuns')} (set_system_flows groups the zones; irrigation_programme shows the programme.)');
  return pb;
}

/// The moment asked for: `day` (1 = the first of the cycle) and `time`
/// ("HH:MM"), else the first start of a run.
double _moment(ProgrammePlayback pb, ToolArgs a) {
  final tl = pb.timeline;
  final day = a.integer('day', min: 1, max: tl.days);
  final time = a.str('time');
  if (day == null && time == null) return tl.nextStart(-1e-6) ?? 0;
  if (time == null) {
    // a day alone: its first start, else its midnight
    final from = (day! - 1) * 24.0;
    final starts = [
      for (final s in tl.spans)
        if (!s.carried && s.start >= from && s.start < from + 24) s.start,
    ];
    return starts.isEmpty ? from : starts.first;
  }
  final m = RegExp(r'^\s*(\d{1,2})(?::(\d{2}))?\s*$').firstMatch(time);
  if (m == null) throw ToolInputError('"time" must be "HH:MM" (24 hours), e.g. "06:30".');
  final hh = int.parse(m.group(1)!), mm = int.parse(m.group(2) ?? '0');
  if (hh > 24 || mm > 59 || (hh == 24 && mm > 0)) throw ToolInputError('"time" must be between 00:00 and 24:00.');
  return tl.wrap(((day ?? 1) - 1) * 24 + hh + mm / 60);
}

String _clock(ProgrammePlayback pb, double h) => pb.timeline.clockAt(h, dayLabel: (d) => 'day $d');

/// The cycle as text: its days and every run.
String _timelineText(AgentToolbox b, ProgrammePlayback pb, {int max = 60}) {
  final tl = pb.timeline;
  final out = StringBuffer(
    tl.days <= 1
        ? 'Cycle: one day (every flow runs daily; every day alike).'
        : tl.exact
        ? 'Cycle: ${tl.days} days, then the programme repeats (the flows run every few days on staggered days).'
        : 'Cycle: the programme repeats only every ${tl.periodDays} days; the first ${tl.days} are shown.',
  );
  out.write(
    ' Month of the run times: ${tl.programme.base.month == null ? 'the design month of every area' : _monthName(tl.programme.base.month!)}. Runs (day, start–end, system flow, zones, cycle, flow):',
  );
  var n = 0;
  for (final s in tl.spans) {
    if (s.carried) continue;
    if (++n > max) {
      out.write('\n… ${tl.spans.length - max} more.');
      break;
    }
    final r = s.run;
    final q = pb.flows[r.flowId]?.totalFlow ?? r.flow;
    out.write(
      '\n- ${_clock(pb, s.start)}–${_clock(pb, s.start + r.durationHours)} ${r.flowId} "${r.flowName}": ${r.zones.join(', ')}${r.cycles > 1 ? ' (cycle ${r.cycle} of ${r.cycles})' : ''}, ${engN(r.durationHours * 60, 0)} min, ${engN(q * 3600, 2)} m³/h',
    );
  }
  if (tl.overlaps) out.write('\nSome runs overlap in time (the programme does not fit its window): their flows are added, not solved together.');
  return out.toString();
}

String _monthName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][(m - 1).clamp(0, 11)];

/// The state of the system at [f] as text.
String _frameText(AgentToolbox b, ProgrammePlayback pb, PlaybackFrame f) {
  final c = b.c;
  final out = StringBuffer('Moment ${_clock(pb, f.hour)} (${engN(f.hour, 2)} h from the start of the cycle): ');
  if (f.idle) {
    out.write('nothing runs — the system is at rest (pumps off, no flow).');
  } else {
    out.write(
      'running ${{for (final s in f.running) '${s.run.flowId} "${s.run.flowName}"${s.run.cycles > 1 ? ' cycle ${s.run.cycle}/${s.run.cycles}' : ''} (zones ${s.run.zones.join(', ')})'}.join(' + ')}; total flow ${engN(f.totalFlow * 3600, 2)} m³/h.',
    );
  }
  for (final s in f.supplies) {
    out.write('\nSupply ${s.id} "${s.name}": pressure head ${engN(s.head, 2)} m, flow ${engN(s.flow * 3600, 2)} m³/h.');
  }
  if (pb.pumps.isNotEmpty) {
    out.write('\nPumps: ${[for (final p in pb.pumps) '${p.id} ${f.pumpsOn.contains(p.id) ? 'on (outlet pressure head ${engN(f.pumpHeads[p.id] ?? double.nan, 2)} m)' : 'off'}'].join(', ')}.');
  }
  for (final r in pb.reservoirs) {
    out.write(
      '\nReservoir of ${r.supplyId}: level ${engN(f.levels[r.supplyId] ?? r.levelAt(f.hour), 3)} m (full ${engN(r.study.fullLevel, 2)} m, lowest operating ${engN(r.study.minLevel, 2)} m)${r.dry ? '; it reaches its lowest level in the cycle' : ''}${r.spills ? '; it fills and spills in the cycle' : ''}; change over the cycle ${engN(r.netChange, 1)} m³.',
    );
  }
  for (final g in f.flows) {
    if (g.pipes.isEmpty) continue;
    var vmax = 0.0, qmax = 0.0;
    for (final p in g.pipes) {
      if (p.velocity > vmax) vmax = p.velocity;
      if (p.flow > qmax) qmax = p.flow;
    }
    out.write(
      '\n${g.flowId}: ${g.pipes.length} pipe segments carry water (up to ${engN(qmax * 3600, 2)} m³/h, ${engN(vmax, 2)} m/s), ${g.wet.length} emitter groups or sprinklers wet, areas ${g.areas.map((x) => c.entityName(x.id)).join(', ')}.',
    );
  }
  if (f.overlap) out.write('\nTwo groups run at once: their flows are added on shared pipes and the supply shows the higher pressure; the design did not solve them together.');
  return out.toString();
}

const _legend =
    'How to read it: the areas of the running groups are tinted blue, the throw of their sprinklers is a light blue disc or sector, their emitters are light dots; the pipes that carry water are coloured by velocity (blue slow, green at half the allowed velocity, orange at it, red above) and drawn wider with more flow; a pump with a green ring and turning spokes is on, a grey ring with two bars is off; the panel at the top left gives the clock, what runs, the flow, the pressure at the supply, the pumps on and the reservoir levels. The rest of the drawing is as the canvas draws it in layer colours.';

List<AgentTool> opsPly(AgentToolbox b) {
  final c = b.c;
  final month = int_('Month of the run times, 1–12 (default: the design month of every area).');
  final day = int_('Day of the cycle, 1 = the first (default 1).');
  final time = str('Clock time "HH:MM" (24 hours) on that day (default: the first start of a run that day, or of the cycle without a day).');
  return [
    cadOp(
      b,
      group: 'engineering',
      name: 'programme_picture',
      args: (i) => {'n': '${i['day'] == null ? '' : 'day ${i['day']} '}${i['time'] ?? ''}'.trim()},
      description:
          'Design → Agronomy → Play the programme on the plan, as a picture: the plan at one moment of the irrigation programme (the cycle of the programme: one day when every system flow runs daily, else the days until it repeats), showing which groups of zones run then (their areas tinted, sprinklers and emitters wet), the pipes that carry water coloured by their velocity and sized by their flow (the design results of that system flow), the pumps on and off, and a panel with the clock, the total flow, the pressure at the supply and the reservoir levels (a continuity balance along the cycle). '
          'Use it to look at the operation of the system, check what runs when, or show the user a moment. With the picture comes the text of the moment (what runs, flows, pressures, pumps, levels) and the whole cycle (every run: day, start, end, flow, zones). Needs design results and a programme with runs (system flows over areas with crop and climate; irrigation_programme shows it). '
          'Inputs: day, time, month, region (groups — what the programme waters, the default —, drawing, view, bbox), bbox, size, base_map (default "none"). Output: the picture with its id and pixel ↔ world mapping, and the text. No side effects.',
      schema: obj({
        'day': day,
        'time': time,
        'month': month,
        'region': str('What to frame: "groups" (the zones, pipes and pumps of the programme; default), "drawing", "view" or "bbox".', ['groups', 'drawing', 'view', 'bbox']),
        'bbox': bbox,
        'size': pictureSizeInput(b),
        'base_map': baseMapInput,
      }),
      run: (a, input) async {
        final pb = _playback(b, a);
        final h = _moment(pb, a);
        final f = pb.frameAt(h);
        final region = a.str('region') ?? (a.has('bbox') ? 'bbox' : 'groups');
        final Bounds world = region == 'groups' ? playbackWorld(c, pb) : pictureWorld(b, a, fallback: region == 'bbox' ? 'bbox' : region);
        final lead = <String>[];
        final size = pictureSideOf(b, a, lead);
        final maps = c.project.meta.georef == null ? const <BaseMap>[] : pictureMapsFor(c, input['base_map'] ?? 'none');
        Future<void Function(Canvas, PictureFrame)?> layer(PictureFrame pf) async => (canvas, fr) {
          final view = PlaybackPaintView(toScreen: fr.toPx, scale: 1 / fr.mpp, visible: fr.world, size: Size(fr.width.toDouble(), fr.height.toDouble()));
          Cad.paintWith(CadPalette.dark, () => paintPlayback(canvas, view, c, pb, f, look: const PlaybackLook(veil: false, decimalPoint: true)));
        };
        return pictureOutput(
          b,
          (id) => VisionSpec(
            world: world,
            maxSide: size,
            maxPixels: b.pictures.maxPixels,
            maxShort: b.pictures.maxShortSide,
            maps: maps,
            caption: id,
            tiles: VisionSession.of(b).tiles,
            overlay: OverlayMode.none,
            showLabels: false,
            over: [layer],
          ),
          what: (img) => pictureWhat(img, drawing: true, subject: 'the plan at ${_clock(pb, h)} of the irrigation programme'),
          lead: (_) => lead,
          tail: (_, _) => [_frameText(b, pb, f), _legend, _timelineText(b, pb)],
        );
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'export_programme_animation',
      effect: ToolEffect.export,
      args: (i) => {'n': '${i['format'] ?? 'gif'}'.toUpperCase()},
      description:
          'Design → Agronomy → Play the programme on the plan → Animation (GIF) or Frame (PNG): writes the irrigation programme played on the plan as a file — gif: the whole cycle as an animated GIF (a frame every step of the cycle and one in every short run, the clock, flow, pressure and a bar of the cycle on each; 480 px and 48 frames for a day by default, small enough for a phone message), png: the plan at one moment (day, time; 1600 px by default). '
          'What it shows is as programme_picture describes. Always confirmed by the user (a download in the browser). Inputs: format, size (longest side, 160–2000 px), frames (gif, 2–240), day and time (png), month, base_map (true: the base map on screen under the drawing, downloading its tiles). Output: the file name, its size and frames.',
      schema: obj({
        'format': str('File format (default gif).', ['gif', 'png']),
        'size': int_('Longest side in pixels, 160–2000 (default 480 for gif, 1600 for png).'),
        'frames': int_('Frames of the animation, 2–240 (default: every half hour of a day, every two hours of a longer cycle).'),
        'day': day,
        'time': time,
        'month': month,
        'base_map': bool_('Draw the base map on screen under the drawing (default false).'),
      }),
      run: (a, _) async {
        engNotBusy(c);
        final pb = _playback(b, a);
        final format = a.str('format') ?? 'gif';
        if (format != 'gif' && format != 'png') throw ToolInputError('"format" must be gif or png.');
        final map = a.flag('base_map') ?? false;
        final renderer = switch (b.snapshots) {
          final VisionRenderer r => r,
          _ => const CanvasSnapshots(),
        };
        if (format == 'png') {
          final h = _moment(pb, a);
          final png = await playbackPng(c, pb, h, maxSide: a.integer('size', min: 160, max: 2000) ?? playbackPngSide, baseMap: map, renderer: renderer);
          final file = playbackFileName(c, 'png');
          await engFileSink(c, file, 'image/png', png);
          return ToolOutput('Saved $file (${(png.length / 1024).round()} KB): the plan at ${_clock(pb, h)}.');
        }
        final gif = await playbackGif(c, pb, maxSide: a.integer('size', min: 160, max: 2000) ?? playbackGifSide, frames: a.integer('frames', min: 2, max: 240), baseMap: map, renderer: renderer);
        if (gif == null) throw ToolInputError('The animation was not made.');
        final file = playbackFileName(c, 'gif');
        await engFileSink(c, file, 'image/gif', gif.bytes);
        return ToolOutput(
          'Saved $file (${(gif.bytes.length / 1024).round()} KB, ${gif.frames} frames of ${gif.width}×${gif.height} px, ${engN(gif.frames * playbackGifDelayCs / 100, 1)} s a loop, the cycle of ${pb.timeline.days} day(s)).',
        );
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'export_programme_calendar',
      effect: ToolEffect.export,
      description: 'Design → Agronomy → Play the programme on the plan → Calendar (.ics): writes the irrigation programme as an iCalendar file (RFC 5545) for the grower\'s phone — one event per start of every group of zones (system flow, or each cycle of cycle and soak) at its local clock time (floating time, no time zone), lasting its run time, with the zones and run time in the description, repeating every cycle of the programme (RRULE FREQ=DAILY with the interval of the cycle) from today for the days asked. The run times are those of the month given (default: the design month of every area). Always confirmed by the user (a download). Inputs: days (1–366, default 30), month. Output: the file name and the events.',
      schema: obj({'days': int_('Days the calendar covers from today, 1–366 (default 30).'), 'month': month}),
      run: (a, _) async {
        final pb = _playback(b, a, withReservoirs: false);
        final days = a.integer('days', min: 1, max: 366) ?? 30;
        final name = c.project.meta.name.isEmpty ? c.t('ply.title') : c.project.meta.name;
        final events = programmeEvents(pb.timeline, projectName: name, horizonDays: days, t: c.t.call);
        final text = programmeCalendar(pb.timeline, projectName: name, stamp: DateTime.now(), horizonDays: days, t: c.t.call);
        final file = playbackFileName(c, 'ics');
        await engFileSink(c, file, 'text/calendar', text);
        final list = [
          for (final e in events.take(30))
            '- ${e.start.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} for ${e.duration.inMinutes} min${e.rrule == null ? '' : ' (${e.rrule})'}: ${e.summary}',
        ];
        return ToolOutput('Saved $file: ${events.length} events from ${pb.timeline.startDate.toIso8601String().substring(0, 10)} over $days days.\n${list.join('\n')}');
      },
    ),
  ];
}
