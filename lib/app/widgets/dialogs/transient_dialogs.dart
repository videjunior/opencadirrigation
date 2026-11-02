/// Mainline dialogs: hydraulic transients (water hammer) of the system
/// flows, air valve placement and sizing, and the 24-hour simulation with
/// its energy cost.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/design/air_valves.dart';
import '../../../core/design/transient_analysis.dart';
import '../../../core/hydraulics/pump.dart' show atmosphericHead;
import '../../../core/model/entities.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

Widget _row(List<Widget> children) => Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

Widget _cell(String s, {bool bold = false, Color? color, bool mono = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(
    s,
    style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null, color: color, fontFamily: mono ? 'monospace' : null),
  ),
);

Widget _table(List<List<Widget>> rows) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Table(
    defaultColumnWidth: const IntrinsicColumnWidth(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [for (final r in rows) TableRow(children: r)],
  ),
);

Widget _hint(String s, {Color? color}) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70)),
);

/// Gives the frame a chance to paint (the progress indicator) before a long
/// synchronous computation: after the next frame, or 16 ms when no frame
/// comes (tests, headless).
Future<void> _yieldFrame() async {
  final frame = Completer<void>();
  try {
    final b = SchedulerBinding.instance;
    b.addPostFrameCallback((_) {
      if (!frame.isCompleted) frame.complete();
    });
    b.scheduleFrame();
  } catch (_) {
    // no binding: the timer below
  }
  await Future.any<void>([frame.future, Future<void>.delayed(const Duration(milliseconds: 16))]);
  await Future<void>.delayed(Duration.zero);
}

/// Display name of an entity: its name, else its catalogue item, else its id.
String _nameOf(ProjectController c, String? id) {
  if (id == null) return '—';
  final e = c.project.byId(id);
  if (e == null) return id;
  if (e.name.isNotEmpty) return e.name;
  final cat = c.project.catalog;
  final spec = switch (e) {
    PumpEntity p => cat.pump(p.pumpSpecId)?.name,
    MiscHydraulicEntity m => cat.valve(m.valveSpecId)?.name,
    WaterSupplyEntity _ => c.t('tool.supply'),
    _ => null,
  };
  return spec == null || spec.isEmpty ? id : spec;
}

/// The last transient analysis of a controller, valid while its project,
/// history position and results stay the same (the air valve dialog checks
/// its minimum envelope against vacuum).
final _lastTransient = Expando<(Object, Object?, int, TransientAnalysis)>();

TransientAnalysis? lastTransientAnalysis(ProjectController c) {
  final v = _lastTransient[c];
  if (v == null || !identical(v.$1, c.project) || !identical(v.$2, c.results) || v.$3 != c.historyIndex) return null;
  return v.$4;
}

// ---------------------------------------------------------------- chart

/// A series of a [_Chart]: (x, y) points, NaN y breaks the line.
class _Line {
  const _Line(this.label, this.color, this.points, {this.dashed = false, this.width = 1.6, this.step = false, this.fill = false});
  final String label;
  final Color color;
  final List<(double, double)> points;
  final bool dashed, step, fill;
  final double width;
}

/// Line chart in the style of the profile and grade line charts: grid,
/// axes in display units, legend and a hover readout of every series.
class _Chart extends StatefulWidget {
  const _Chart({super.key, required this.lines, this.title = '', this.yLabel = '', this.xFormat, this.decimals = 1});
  final List<_Line> lines;
  final String title, yLabel;
  final String Function(double x)? xFormat;
  final int decimals;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  Offset? _hover;

  @override
  Widget build(BuildContext context) {
    if (!widget.lines.any((l) => l.points.length >= 2)) return const Center(child: Text('—'));
    return MouseRegion(
      onHover: (e) => setState(() => _hover = e.localPosition),
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        onTapDown: (d) => setState(() => _hover = d.localPosition),
        onPanUpdate: (d) => setState(() => _hover = d.localPosition),
        child: CustomPaint(painter: _ChartPainter(widget, _hover), size: Size.infinite),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.w, this.hover);
  final _Chart w;
  final Offset? hover;

  static double _at(_Line l, double x) {
    final p = l.points;
    if (p.isEmpty || x < p.first.$1 - 1e-9 || x > p.last.$1 + 1e-9) return double.nan;
    for (var i = 1; i < p.length; i++) {
      if (x <= p[i].$1 + 1e-12) {
        final (x0, y0) = p[i - 1];
        final (x1, y1) = p[i];
        if (l.step) return x >= x1 - 1e-12 ? y1 : y0;
        return x1 - x0 < 1e-12 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0);
      }
    }
    return p.last.$2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 54.0, right = 14.0, top = 20.0;
    // legend rows below the plot
    final txt = TextStyle(color: Cad.fg60, fontSize: 10);
    final items = [
      for (final l in w.lines)
        if (l.label.isNotEmpty && l.points.length >= 2) l,
    ];
    final legend = <(double, double, _Line, TextPainter)>[];
    var lx = left, ly = 0.0;
    for (final l in items) {
      final tp = TextPainter(
        text: TextSpan(text: l.label, style: txt),
        textDirection: TextDirection.ltr,
      )..layout();
      final wItem = 18 + tp.width + 14;
      if (lx + wItem > size.width - right && lx > left) {
        lx = left;
        ly += 14;
      }
      legend.add((lx, ly, l, tp));
      lx += wItem;
    }
    final legendH = items.isEmpty ? 0.0 : ly + 16;
    final bottom = 22.0 + legendH;
    final width = size.width - left - right, h = size.height - top - bottom;
    if (width <= 10 || h <= 10) return;
    var xMin = double.infinity, xMax = -double.infinity, yMin = double.infinity, yMax = -double.infinity;
    for (final l in w.lines) {
      for (final (x, y) in l.points) {
        if (!x.isFinite) continue;
        xMin = math.min(xMin, x);
        xMax = math.max(xMax, x);
        if (!y.isFinite) continue;
        yMin = math.min(yMin, y);
        yMax = math.max(yMax, y);
      }
    }
    if (!xMin.isFinite || !yMin.isFinite) return;
    if (xMax - xMin < 1e-9) xMax = xMin + 1;
    if (yMax - yMin < 1e-6) {
      yMax += 0.5;
      yMin -= 0.5;
    }
    final pad = (yMax - yMin) * 0.08;
    yMin -= pad;
    yMax += pad;
    Offset pt(double x, double y) => Offset(left + (x - xMin) / (xMax - xMin) * width, top + (1 - (y - yMin) / (yMax - yMin)) * h);
    final grid = Paint()
      ..color = Cad.chartGrid
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = yMin + (yMax - yMin) * i / 5;
      final o = pt(xMin, y);
      canvas.drawLine(Offset(left, o.dy), Offset(left + width, o.dy), grid);
      final tp = TextPainter(
        text: TextSpan(text: fmt(y, w.decimals), style: txt),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, o.dy - tp.height / 2));
    }
    for (var i = 0; i <= 6; i++) {
      final x = xMin + (xMax - xMin) * i / 6;
      final o = pt(x, yMin);
      canvas.drawLine(Offset(o.dx, top), Offset(o.dx, top + h), grid);
      final tp = TextPainter(
        text: TextSpan(text: w.xFormat?.call(x) ?? fmt(x, 0), style: txt),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, top + h + 4));
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, top - 1, width, h + 2));
    for (final l in w.lines) {
      if (l.points.length < 2) continue;
      final path = Path();
      var open = false;
      double? lastY;
      for (final (x, y) in l.points) {
        if (!y.isFinite || !x.isFinite) {
          open = false;
          lastY = null;
          continue;
        }
        final o = pt(x, y);
        if (!open) {
          path.moveTo(o.dx, o.dy);
          open = true;
        } else {
          if (l.step && lastY != null) {
            final s = pt(x, lastY);
            path.lineTo(s.dx, s.dy);
          }
          path.lineTo(o.dx, o.dy);
        }
        lastY = y;
      }
      final paint = Paint()
        ..color = l.color
        ..strokeWidth = l.width
        ..style = PaintingStyle.stroke;
      if (l.fill) {
        final fill = Path()..addPath(path, Offset.zero);
        final first = l.points.firstWhere((p) => p.$2.isFinite), last = l.points.lastWhere((p) => p.$2.isFinite);
        fill
          ..lineTo(pt(last.$1, yMin).dx, top + h)
          ..lineTo(pt(first.$1, yMin).dx, top + h)
          ..close();
        canvas.drawPath(fill, Paint()..color = l.color.withValues(alpha: 0.14));
      }
      if (l.dashed) {
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 9) {
            canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
    final title = TextPainter(
      text: TextSpan(
        text: '${w.title}${w.yLabel.isEmpty ? '' : '   ${w.yLabel}'}',
        style: TextStyle(color: Cad.fg70, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(10, size.width - left));
    title.paint(canvas, const Offset(left, 3));
    final ly0 = top + h + 22;
    for (final (x, y, l, tp) in legend) {
      final yy = ly0 + y + 6;
      final p = Paint()
        ..color = l.color
        ..strokeWidth = 2.5;
      if (l.dashed) {
        canvas.drawLine(Offset(x, yy), Offset(x + 5, yy), p);
        canvas.drawLine(Offset(x + 9, yy), Offset(x + 14, yy), p);
      } else {
        canvas.drawLine(Offset(x, yy), Offset(x + 14, yy), p);
      }
      tp.paint(canvas, Offset(x + 18, yy - tp.height / 2));
    }
    // hover readout
    final hv = hover;
    if (hv == null || hv.dx < left || hv.dx > left + width || hv.dy < top || hv.dy > top + h) return;
    final x = xMin + (hv.dx - left) / width * (xMax - xMin);
    canvas.drawLine(
      Offset(hv.dx, top),
      Offset(hv.dx, top + h),
      Paint()
        ..color = Cad.fg30
        ..strokeWidth = 1,
    );
    final lines = <String>[w.xFormat?.call(x) ?? fmt(x, 1)];
    for (final l in items) {
      final y = _at(l, x);
      if (!y.isFinite) continue;
      canvas.drawCircle(pt(x, y), 3, Paint()..color = l.color);
      lines.add('${l.label}: ${fmt(y, w.decimals)}');
    }
    final t = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: TextStyle(color: Cad.fg, fontSize: 10.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var tx = hv.dx + 10;
    if (tx + t.width > size.width - 4) tx = hv.dx - t.width - 10;
    final ty = (hv.dy - t.height / 2).clamp(top, math.max(top, top + h - t.height)).toDouble();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tx - 4, ty - 3, t.width + 8, t.height + 6), const Radius.circular(3)), Paint()..color = Cad.overlayStrong);
    t.paint(canvas, Offset(tx, ty));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}

Color get _cPipe => Cad.chartGround;
Color get _cSteady => Cad.chartHgl;
Color get _cMax => Cad.chartMax;
Color get _cMin => Cad.chartLow;
Color get _cRating => Cad.chartRating;
Color get _cVapour => Cad.chartVapour;
Color get _cGround => Cad.chartGroundDark;

// ---------------------------------------------------------------- transients

/// Hydraulic transients of the mainline: scenario options, the simulation
/// of every system flow with a progress bar, the envelopes along the
/// critical path, the pressure in time, the pipes against their class and
/// the messages.
Future<void> showTransientDialog(BuildContext context, ProjectController c) => showDialog<void>(context: context, builder: (ctx) => _TransientDialog(c));

class _TransientDialog extends StatefulWidget {
  const _TransientDialog(this.c);
  final ProjectController c;

  @override
  State<_TransientDialog> createState() => _TransientDialogState();
}

class _TransientDialogState extends State<_TransientDialog> {
  ProjectController get c => widget.c;
  late final _isolation = isolationDevices(c.project);
  final _scenarios = <TransientScenario>{TransientScenario.valveClosure};
  late double _closure = c.project.params.valveClosureTimeS;
  late double _isoClosure = math.max(c.project.params.valveClosureTimeS, 5);
  late String? _isoId = _isolation.isEmpty ? null : _isolation.first.id;
  int _poles = 2;
  double _inertia = 0, _duration = 0;
  bool _cavities = true, _airValves = true;
  String _flow = '';
  bool _busy = false;

  /// The user asked to stop the simulation (checked between the runs).
  bool _cancel = false;
  int _done = 0, _total = 0;
  TransientAnalysis? _analysis;
  int _run = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analysis = lastTransientAnalysis(c);
    if (_analysis != null) _run = math.max(0, _analysis!.worstRun);
  }

  String _scenarioLabel(TransientScenario s) => c.t('tr.sc.${s.name}');

  Future<void> _simulate() async {
    if (_busy || _scenarios.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _cancel = false;
      _error = null;
      _done = 0;
      _total = 0;
    });
    await _yieldFrame();
    try {
      final study = TransientStudy(
        c.project,
        results: c.results,
        label: c.t.call,
        options: TransientStudyOptions(
          scenarios: {..._scenarios},
          flowIds: _flow.isEmpty ? null : {_flow},
          closureTime: _closure,
          isolationId: _isoId,
          isolationClosureTime: _isoClosure,
          motorPoles: _poles,
          inertia: _inertia > 0 ? _inertia : null,
          duration: _duration > 0 ? _duration : null,
          columnSeparation: _cavities,
          airValves: _airValves,
        ),
      );
      final jobs = study.jobs;
      if (mounted) setState(() => _total = jobs.length);
      final runs = <TransientRun>[];
      for (final j in jobs) {
        await _yieldFrame();
        if (!mounted) return;
        if (_cancel) {
          // the last analysis (if any) stays on screen
          c.notify(c.t('ui.stopped'));
          return;
        }
        runs.add(study.run(j));
        setState(() => _done = runs.length);
      }
      final a = TransientStudy.combine(runs);
      _lastTransient[c] = (c.project, c.results, c.historyIndex, a);
      if (!mounted) return;
      setState(() {
        _analysis = a;
        _run = math.max(0, a.worstRun);
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final u = c.units;
    final flows = [for (final f in c.project.systemFlows) f];
    final a = _analysis;
    return AlertDialog(
      title: Text(t('tr.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(context, 860),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(t('tr.hint')),
              if (c.results == null) _hint(t('tr.noResults'), color: Cad.warning),
              SectionTitle(t('tr.scenarios')),
              for (final s in TransientScenario.values)
                CheckboxListTile(
                  key: Key('tr_sc_${s.name}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  visualDensity: VisualDensity.compact,
                  title: Text(_scenarioLabel(s), style: const TextStyle(fontSize: 12)),
                  value: _scenarios.contains(s),
                  onChanged: _busy ? null : (v) => setState(() => v == true ? _scenarios.add(s) : _scenarios.remove(s)),
                ),
              _row([
                NumField(key: const Key('tr_closure'), label: t('dlg.closureTime'), value: _closure, onChanged: (v) => setState(() => _closure = v < 0 ? 0 : v)),
                SpecDropdown<String>(
                  key: const Key('tr_flow'),
                  label: t('rep.flowName'),
                  value: _flow,
                  items: ['', for (final f in flows) f.id],
                  labelOf: (id) => id.isEmpty ? t('tr.allFlows') : flows.firstWhere((f) => f.id == id).name,
                  idOf: (id) => id,
                  onChanged: (v) => setState(() => _flow = v ?? ''),
                ),
              ]),
              if (_scenarios.contains(TransientScenario.isolationClosure))
                _isolation.isEmpty
                    ? _hint(t('tr.noIsolation'), color: Cad.warning)
                    : _row([
                        SpecDropdown<MiscHydraulicEntity>(
                          key: const Key('tr_iso'),
                          label: t('tr.isolation'),
                          value: _isoId,
                          items: _isolation,
                          labelOf: (e) => '${_nameOf(c, e.id)} (${e.id})',
                          idOf: (e) => e.id,
                          onChanged: (v) => setState(() => _isoId = v),
                        ),
                        NumField(label: t('tr.isolationClosure'), value: _isoClosure, onChanged: (v) => setState(() => _isoClosure = v < 0 ? 0 : v)),
                      ]),
              if (_scenarios.contains(TransientScenario.pumpTrip))
                _row([
                  SpecDropdown<int>(
                    key: const Key('tr_poles'),
                    label: t('tr.motor'),
                    value: '$_poles',
                    items: const [2, 4],
                    labelOf: (p) => t('tr.polesN', {'n': '$p', 'rpm': fmt(TransientStudyOptions.speedForPoles(p, c.project.params.mainsHz), 0)}),
                    idOf: (p) => '$p',
                    onChanged: (v) => setState(() => _poles = int.tryParse(v ?? '') ?? 2),
                  ),
                  NumField(key: const Key('tr_inertia'), label: t('tr.inertia'), value: _inertia, decimals: 3, onChanged: (v) => setState(() => _inertia = v < 0 ? 0 : v)),
                ]),
              _row([
                NumField(key: const Key('tr_duration'), label: t('tr.duration'), value: _duration, decimals: 0, onChanged: (v) => setState(() => _duration = v.clamp(0, 600).toDouble())),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('tr.columnSeparation'), style: const TextStyle(fontSize: 12)),
                  value: _cavities,
                  onChanged: _busy ? null : (v) => setState(() => _cavities = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('tr.airValves'), style: const TextStyle(fontSize: 12)),
                  value: _airValves,
                  onChanged: _busy ? null : (v) => setState(() => _airValves = v),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(key: const Key('tr_run'), onPressed: _busy || _scenarios.isEmpty ? null : _simulate, icon: const Icon(Icons.play_arrow, size: 16), label: Text(t('tr.run'))),
                  if (_busy) ...[
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(key: const Key('tr_progress'), value: _total > 0 ? _done / _total : null),
                    ),
                    Text(t('tr.running', {'i': '${math.min(_done + 1, math.max(_total, 1))}', 'n': '${math.max(_total, 1)}'}), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
                    TextButton(key: const Key('tr_cancel'), onPressed: _cancel ? null : () => setState(() => _cancel = true), child: Text(t('cancel'))),
                  ],
                ],
              ),
              if (_error != null) _hint(c.t('msg.error', {'e': _error!}), color: Cad.warning),
              if (a != null && !_busy) ..._results(a, u),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t('close')))],
    );
  }

  List<Widget> _results(TransientAnalysis a, Units u) {
    final t = c.t;
    if (a.runs.isEmpty) return [_hint(t('tr.none'))];
    final run = a.runs[_run.clamp(0, a.runs.length - 1)];
    String p(double h) => '${fmt(u.pressureFromHead(h), 1)} ${u.pressureLabel}';
    final over = a.pipes.where((x) => x.overRating).length, vac = a.pipes.where((x) => x.vacuum).length;
    final out = <Widget>[
      SectionTitle(t('dens.results')),
      _hint(t('tr.summary', {'n': '${a.runs.where((r) => r.ran).length}', 'o': '$over', 'v': '$vac'}), color: over + vac > 0 ? Cad.warning : Cad.ok),
      SpecDropdown<int>(
        key: const Key('tr_pick'),
        label: t('tr.pick'),
        value: '${_run.clamp(0, a.runs.length - 1)}',
        items: [for (var i = 0; i < a.runs.length; i++) i],
        labelOf: (i) {
          final r = a.runs[i];
          final target = r.targetId == null ? '' : ' (${_nameOf(c, r.targetId)})';
          return '${r.flowName} — ${_scenarioLabel(r.scenario)}$target${r.ran ? '' : ' · ${t('tr.skipped')}'}';
        },
        idOf: (i) => '$i',
        onChanged: (v) => setState(() => _run = int.tryParse(v ?? '') ?? 0),
      ),
    ];
    if (!run.ran) {
      out.add(_hint(t.warning(run.skipped!, entityName: (id) => _nameOf(c, id)), color: Cad.warning));
      return out;
    }
    final worstPipe = run.pipes.isEmpty ? null : run.pipes.reduce((x, y) => x.maxPressure >= y.maxPressure ? x : y);
    final lowPipe = run.pipes.isEmpty ? null : run.pipes.reduce((x, y) => x.minPressure <= y.minPressure ? x : y);
    out.addAll([
      KV(t('tr.maxSurge'), '${p(run.maxSurge)}${run.maxSurgeEntity == null ? '' : ' · ${c.entityName(run.maxSurgeEntity!)}'}'),
      if (worstPipe != null) KV(t('tr.maxPressure'), '${p(worstPipe.maxPressure)} · ${c.entityName(worstPipe.entityId)}', color: worstPipe.overRating ? Cad.warning : null),
      if (lowPipe != null) KV(t('tr.minPressure'), '${p(lowPipe.minPressure)} · ${c.entityName(lowPipe.entityId)}', color: lowPipe.vacuum ? Cad.warning : null),
      if (run.checkValves.isNotEmpty) KV(t('tr.checkValve'), [for (final e in run.checkValves.entries) '${_nameOf(c, e.key)} ${fmt(e.value, 2)} s'].join(' · ')),
      KV(t('tr.timeStep'), '${fmt(run.timeStep * 1000, 1)} ms · ${fmt(run.duration, 0)} s · ${run.steps}'),
      SectionTitle(t('tr.profile')),
      SizedBox(height: 240, child: _profileChart(run, u)),
      SectionTitle(t('tr.series')),
      SizedBox(height: 190, child: _seriesChart(run, u)),
      SectionTitle(t('tr.pipes')),
      _pipeTable(run, u),
      SectionTitle(t('rep.warnings')),
      if (run.messages.isEmpty) _hint(t('tr.none'), color: Cad.ok),
      for (final m in run.messages) _hint('• ${t.warning(m, entityName: (id) => c.entityName(id))}', color: Cad.warning),
    ]);
    return out;
  }

  Widget _profileChart(TransientRun run, Units u) {
    final t = c.t;
    final pr = run.profile;
    double y(double v) => u.lengthFromSi(v);
    double x(double v) => u.lengthFromSi(v);
    return _Chart(
      key: const Key('tr_profile'),
      title: t('tr.profile'),
      yLabel: '${t('tr.head')} (${u.lengthLabel})',
      xFormat: (v) => '${fmt(v, 0)} ${u.lengthLabel}',
      lines: [
        _Line(t('tr.lg.ground'), _cGround, [for (final p in pr) (x(p.chainage), y(p.ground))], width: 1, fill: true),
        _Line(t('tr.lg.pipe'), _cPipe, [for (final p in pr) (x(p.chainage), y(p.elevation))], width: 2),
        _Line(t('tr.lg.steady'), _cSteady, [for (final p in pr) (x(p.chainage), y(p.steadyHead))]),
        _Line(t('tr.lg.max'), _cMax, [for (final p in pr) (x(p.chainage), y(p.maxHead))]),
        _Line(t('tr.lg.min'), _cMin, [for (final p in pr) (x(p.chainage), y(p.minHead))]),
        _Line(t('dlg.pipeClass'), _cRating, [for (final p in pr) (x(p.chainage), p.ratingHead.isFinite ? y(p.ratingHead) : double.nan)], dashed: true),
        _Line(t('tr.lg.vapour'), _cVapour, [for (final p in pr) (x(p.chainage), y(p.elevation + run.vapourGauge))], dashed: true, width: 1.2),
      ],
    );
  }

  Widget _seriesChart(TransientRun run, Units u) {
    final t = c.t;
    final lines = <_Line>[];
    List<(double, double)> pts(TransientTrace tr) => [for (var i = 0; i < tr.times.length && i < tr.pressures.length; i++) (tr.times[i], u.pressureFromHead(tr.pressures[i]))];
    final s = run.source, w = run.worst;
    if (s != null) lines.add(_Line('${t(s.flows.isEmpty ? 'tr.lg.lineStart' : 'tr.lg.source')} (${_nameOf(c, s.entityId)})', _cMax, pts(s)));
    if (w != null && w.nodeId != s?.nodeId) lines.add(_Line('${t('tr.lg.worst')} (${_nameOf(c, w.entityId)})', _cMin, pts(w)));
    return _Chart(key: const Key('tr_series'), title: t('tr.series'), yLabel: u.pressureLabel, xFormat: (v) => '${fmt(v, 1)} s', lines: lines);
  }

  Widget _pipeTable(TransientRun run, Units u) {
    final t = c.t;
    final rows = [...run.pipes]..sort((a, b) => (b.overRating || b.vacuum ? 1 : 0).compareTo(a.overRating || a.vacuum ? 1 : 0));
    String p(double h) => fmt(u.pressureFromHead(h), 1);
    return _table([
      [
        _cell(t('rep.entity'), bold: true),
        _cell(t('rep.pipe'), bold: true),
        _cell('${t('rep.pn')} (${u.pressureLabel})', bold: true),
        _cell('${t('rep.pStatic')} (${u.pressureLabel})', bold: true),
        _cell('${t('rep.pMax')} (${u.pressureLabel})', bold: true),
        _cell('${t('rep.pMin')} (${u.pressureLabel})', bold: true),
        _cell(t('rep.status'), bold: true),
      ],
      for (final e in rows)
        [
          _cell(c.entityName(e.entityId)),
          _cell(e.pipeName),
          _cell(e.rating > 0 ? p(e.rating) : '—', mono: true),
          _cell(p(e.steadyMaxPressure), mono: true),
          _cell(p(e.maxPressure), mono: true, color: e.overRating ? Cad.warning : null),
          _cell(p(e.minPressure), mono: true, color: e.vacuum ? Cad.unconnected : (e.belowAtmosphere ? Cad.warning : null)),
          _cell([if (e.overRating) t('tr.st.over'), if (e.vacuum) t('tr.st.vacuum') else if (e.belowAtmosphere) t('tr.st.below')].join(' · ').ifEmpty(t('rep.ok')), color: e.ok ? Cad.ok : Cad.warning),
        ],
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// ---------------------------------------------------------------- air valves

/// Air valves on the mainline (AWWA M51): the suggested places, types and
/// orifice sizes, with a button that draws the missing ones on the pipes as
/// one undo step.
Future<void> showAirValveDialog(BuildContext context, ProjectController c) => showDialog<void>(context: context, builder: (ctx) => _AirValveDialog(c));

class _AirValveDialog extends StatefulWidget {
  const _AirValveDialog(this.c);
  final ProjectController c;

  @override
  State<_AirValveDialog> createState() => _AirValveDialogState();
}

class _AirValveDialogState extends State<_AirValveDialog> {
  ProjectController get c => widget.c;
  MainlineFlows? _mainline;
  AirValveStudy? _study;
  late final TransientAnalysis? _transient = lastTransientAnalysis(c);
  late bool _useTransient = _transient != null;
  double _maxSpacing = 800;
  bool _combination = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _compute(first: true);
  }

  /// Computes the suggestions after a frame (the progress bar shows first);
  /// no setState before it on the first call, from initState.
  Future<void> _compute({bool first = false}) async {
    if (!first) setState(() => _study = null);
    await _yieldFrame();
    if (!mounted) return;
    try {
      final m = _mainline ??= MainlineFlows(c.project, results: c.results, label: c.t.call);
      final o = AirValveOptions(maxSpacing: _maxSpacing, minSpacing: _maxSpacing / 2, preferCombination: _combination, barometricHead: atmosphericHead(m.siteElevation));
      final s = suggestMainlineAirValvesOn(m, transient: _useTransient ? _transient : null, options: o);
      if (mounted) setState(() => _study = s);
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _insert() {
    final s = _study;
    if (s == null) return;
    final missing = [
      for (final v in s.missing)
        if (v.specId != null) v,
    ];
    if (missing.isEmpty) return;
    final n = c.mutate(() {
      final list = airValveEntities(missing, c.project.newId);
      c.project.entities.addAll(list);
      return list.length;
    }, label: 'hist.airValves|${missing.length}');
    if (n == null) return;
    c.notify(c.t('av.inserted', {'n': '$n'}));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final u = c.units;
    final s = _study;
    final missing = s == null ? 0 : s.missing.where((v) => v.specId != null).length;
    return AlertDialog(
      title: Text(t('av.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(context, 900),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(t('av.hint')),
              if (c.results == null) _hint(t('tr.noResults'), color: Cad.warning),
              if (_transient == null)
                _hint(t('av.noTransient'), color: Cad.fg54)
              else
                SwitchListTile(
                  key: const Key('av_transient'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('av.useTransient'), style: const TextStyle(fontSize: 12)),
                  value: _useTransient,
                  onChanged: (v) {
                    _useTransient = v;
                    _compute();
                  },
                ),
              _row([
                NumField(
                  key: const Key('av_spacing'),
                  label: '${t('av.maxSpacing')} (${u.lengthLabel})',
                  value: u.lengthFromSi(_maxSpacing),
                  decimals: 0,
                  onChanged: (v) {
                    final m = u.lengthToSi(v);
                    if (m < 50) return;
                    _maxSpacing = m;
                    _compute();
                  },
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('av.combination'), style: const TextStyle(fontSize: 12)),
                  value: _combination,
                  onChanged: (v) {
                    _combination = v;
                    _compute();
                  },
                ),
              ]),
              if (_error != null) _hint(c.t('msg.error', {'e': _error!}), color: Cad.warning),
              if (s == null && _error == null) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
              if (s != null) ...[
                SectionTitle(t('dens.results')),
                if (s.suggestions.isEmpty) _hint(t('av.none')) else _table(_rows(s, u)),
                if (s.usedTransient) _hint(t('av.withTransient'), color: Cad.fg54),
                for (final m in s.messages) _hint('• ${t.warning(m, entityName: (id) => c.entityName(id))}', color: Cad.warning),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('close'))),
        FilledButton.icon(
          key: const Key('av_insert'),
          onPressed: missing == 0 ? null : _insert,
          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
          label: Text(t('av.insert', {'n': '$missing'})),
        ),
      ],
    );
  }

  List<List<Widget>> _rows(AirValveStudy s, Units u) {
    final t = c.t;
    String mm(double m) => m > 0 ? fmt(u.diameterFromSi(m), u.diameterLabel == 'mm' ? 0 : 2) : '—';
    return [
      [
        _cell('#', bold: true),
        _cell(t('rep.pipe'), bold: true),
        _cell('${t('tr.chainage')} (${u.lengthLabel})', bold: true),
        _cell(t('rep.type'), bold: true),
        _cell(t('av.reasons'), bold: true),
        _cell('${t('av.large')} (${u.diameterLabel})', bold: true),
        _cell('${t('av.small')} (${u.diameterLabel})', bold: true),
        _cell('${t('av.size')} (${u.diameterLabel})', bold: true),
        _cell(t('av.spec'), bold: true),
        _cell(t('rep.status'), bold: true),
      ],
      for (var i = 0; i < s.suggestions.length; i++)
        () {
          final v = s.suggestions[i];
          return [
            _cell('${i + 1}'),
            _cell(c.entityName(v.pipeEntityId ?? '')),
            _cell(fmt(u.lengthFromSi(v.chainage), 0), mono: true),
            _cell(t('av.type.${v.type.name}')),
            _cell([for (final r in v.reasons) t('av.reason.${r.code}')].join(', ')),
            _cell(mm(v.sizing.largeOrifice), mono: true),
            _cell(mm(v.sizing.smallOrifice), mono: true),
            _cell(mm(v.sizing.nominalSize), mono: true),
            _cell(v.specId == null ? '—' : (c.project.catalog.valve(v.specId)?.name ?? v.specId!)),
            _cell(v.existing ? '${t('av.existing')} (${_nameOf(c, v.existingId)})' : t('av.new'), color: v.existing ? Cad.ok : Cad.warning),
          ];
        }(),
    ];
  }
}

// ---------------------------------------------------------------- 24 hours

/// A day of operation: the system flows at their hours, the pumps on while
/// a flow they serve runs, with charts of the flow, the pump power and the
/// lowest pressure at the running valves, and the energy and cost per pump
/// and per hour at the tariff of the parameters with an optional peak band.
Future<void> showEpsDialog(BuildContext context, ProjectController c) => showDialog<void>(context: context, builder: (ctx) => _EpsDialog(c));

class _EpsDialog extends StatefulWidget {
  const _EpsDialog(this.c);
  final ProjectController c;

  @override
  State<_EpsDialog> createState() => _EpsDialogState();
}

class _EpsDialogState extends State<_EpsDialog> {
  ProjectController get c => widget.c;
  MainlineFlows? _mainline;
  late double _price = c.project.params.powerCostPerKwh;
  double _peakStart = 18, _peakEnd = 21, _peakFactor = 1;
  EpsDay? _day;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // the day is simulated at once, after the first frame
    _busy = true;
    _run();
  }

  Future<void> _simulate() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    await _run();
  }

  Future<void> _run() async {
    await _yieldFrame();
    if (!mounted) return;
    try {
      final m = _mainline ??= MainlineFlows(c.project, results: c.results, label: c.t.call);
      final d = simulateDayOn(
        m,
        options: EpsDayOptions(pricePerKwh: _price, peakStartHour: _peakStart, peakEndHour: _peakEnd, peakMultiplier: _peakFactor),
      );
      if (mounted) setState(() => _day = d);
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _flowName(String id) {
    for (final f in _mainline?.flows ?? const []) {
      if (f.id == id) return f.name;
    }
    return c.entityName(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final u = c.units;
    final cur = c.project.params.currency;
    final d = _day;
    return AlertDialog(
      title: Text(t('eps.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(context, 860),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(t('eps.hint')),
              if (c.results == null) _hint(t('tr.noResults'), color: Cad.warning),
              _row([
                NumField(key: const Key('eps_price'), label: t('dlg.energyCost', {'c': cur}), value: _price, decimals: 3, onChanged: (v) => setState(() => _price = v < 0 ? 0 : v)),
                NumField(key: const Key('eps_peak_start'), label: t('eps.peakStart'), value: _peakStart, onChanged: (v) => setState(() => _peakStart = v.clamp(0, 24).toDouble())),
                NumField(key: const Key('eps_peak_end'), label: t('eps.peakEnd'), value: _peakEnd, onChanged: (v) => setState(() => _peakEnd = v.clamp(0, 24).toDouble())),
                NumField(key: const Key('eps_peak_factor'), label: t('eps.peakFactor'), value: _peakFactor, onChanged: (v) => setState(() => _peakFactor = v < 0 ? 0 : v)),
              ]),
              const SizedBox(height: 6),
              Row(
                children: [
                  FilledButton.icon(key: const Key('eps_run'), onPressed: _busy ? null : _simulate, icon: const Icon(Icons.play_arrow, size: 16), label: Text(t('tr.run'))),
                  const SizedBox(width: 12),
                  if (_busy) const SizedBox(width: 160, child: LinearProgressIndicator()),
                ],
              ),
              if (_error != null) _hint(c.t('msg.error', {'e': _error!}), color: Cad.warning),
              if (d != null && !_busy) ..._results(d, u, cur),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t('close')))],
    );
  }

  List<Widget> _results(EpsDay d, Units u, String cur) {
    final t = c.t;
    String hh(double x) {
      final m = (x / 60).round();
      return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    }

    List<(double, double)> steps(List<double> v, double Function(double) f) => [for (var i = 0; i < d.times.length && i < v.length; i++) (d.times[i] / 3600, v[i].isFinite ? f(v[i]) : double.nan)];
    String hoursFmt(double x) => '${fmt(x, 0)} h';
    return [
      SectionTitle(t('dens.results')),
      KV(t('eps.dayEnergy'), '${fmt(d.energyKwh, 1)} kWh'),
      KV(t('eps.dayCost'), '$cur ${fmt(d.cost, 2)}'),
      KV(t('eps.dayVolume'), '${fmt(u.volumeFromM3(d.volume), 1)} ${u.volumeLabel}'),
      SizedBox(
        height: 170,
        child: _Chart(
          key: const Key('eps_flow'),
          title: t('rep.flow'),
          yLabel: u.flowLabel,
          xFormat: hoursFmt,
          lines: [_Line(t('rep.flow'), _cMin, steps(d.flow, u.flowFromSi), step: true, fill: true)],
        ),
      ),
      SizedBox(
        height: 170,
        child: _Chart(
          key: const Key('eps_power'),
          title: t('eps.power'),
          yLabel: 'kW',
          xFormat: hoursFmt,
          decimals: 2,
          lines: [_Line(t('eps.power'), _cMax, steps(d.powerKw, (v) => v), step: true, fill: true)],
        ),
      ),
      SizedBox(
        height: 170,
        child: _Chart(
          key: const Key('eps_pressure'),
          title: t('eps.lowest'),
          yLabel: u.pressureLabel,
          xFormat: hoursFmt,
          lines: [_Line(t('eps.lowest'), _cSteady, steps(d.lowestPressure, u.pressureFromHead), step: true)],
        ),
      ),
      SectionTitle(t('eps.pumps')),
      if (d.pumps.isEmpty)
        _hint(t('eps.noPumps'))
      else
        _table([
          [
            _cell(t('rep.pump'), bold: true),
            _cell('kWh', bold: true),
            _cell(cur, bold: true),
            _cell(t('eps.hoursOn'), bold: true),
            _cell('${t('rep.volume')} (${u.volumeLabel})', bold: true),
            _cell(t('eps.maxPower'), bold: true),
          ],
          for (final p in d.pumps)
            [
              _cell(p.calculated ? t('eps.calcSupply', {'n': _nameOf(c, p.entityId)}) : _nameOf(c, p.entityId)),
              _cell(fmt(p.energyKwh, 2), mono: true),
              _cell(fmt(p.cost, 2), mono: true),
              _cell(fmt(p.hoursOn, 2), mono: true),
              _cell(fmt(u.volumeFromM3(p.volume), 1), mono: true),
              _cell('${fmt(p.maxPowerKw, 2)} kW', mono: true),
            ],
          [_cell(t('rep.totalRow'), bold: true), _cell(fmt(d.energyKwh, 2), bold: true, mono: true), _cell(fmt(d.cost, 2), bold: true, mono: true), _cell(''), _cell(''), _cell('')],
        ]),
      SectionTitle(t('eps.hourly')),
      _table([
        [
          _cell(t('eps.hour'), bold: true),
          _cell(t('rep.flowName'), bold: true),
          _cell('${t('rep.flow')} (${u.flowLabel})', bold: true),
          _cell('kW', bold: true),
          _cell('kWh', bold: true),
          _cell(cur, bold: true),
          _cell('${t('eps.lowest')} (${u.pressureLabel})', bold: true),
        ],
        for (final h in d.hours)
          if (h.flows.isNotEmpty || h.powerKw > 0)
            [
              _cell('${hh(h.hour * 3600.0)}–${hh((h.hour + 1) * 3600.0)}'),
              _cell(h.flows.map(_flowName).join(', ')),
              _cell(fmt(u.flowFromSi(h.flow), 2), mono: true),
              _cell(fmt(h.powerKw, 2), mono: true),
              _cell(fmt(h.energyKwh, 2), mono: true),
              _cell(
                fmt(h.cost, 2),
                mono: true,
                color: _peakFactor != 1 && EpsDayOptions(peakStartHour: _peakStart, peakEndHour: _peakEnd).inPeak(h.hour + 0.5) ? Cad.warning : null,
              ),
              _cell(
                h.lowestPressure.isFinite ? '${fmt(u.pressureFromHead(h.lowestPressure), 1)} (${_nameOf(c, h.lowestValve)})' : '—',
                mono: true,
                color: h.lowestMargin.isFinite && h.lowestMargin < -0.05 ? Cad.warning : null,
              ),
            ],
      ]),
      if (d.messages.isNotEmpty) SectionTitle(t('rep.warnings')),
      for (final m in d.messages) _hint('• ${t.warning(m, entityName: (id) => id.contains(':') ? id : _flowNameOrEntity(id))}', color: Cad.warning),
    ];
  }

  String _flowNameOrEntity(String id) {
    for (final f in _mainline?.flows ?? const []) {
      if (f.id == id) return f.name;
    }
    return _nameOf(c, id);
  }
}
