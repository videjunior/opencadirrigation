/// The irrigation programme played on the drawing (1.7.0): the state of the
/// player of every tab and the picture of one moment over the drawing — a
/// veil over the system at rest, the areas of the running groups tinted,
/// their sprinklers and emitters wet, the pipes that carry water coloured by
/// their velocity (the ramp of the velocity overlay) and drawn wider with
/// more flow, the pumps on or off, and a panel with the clock, the flow, the
/// pressure at the supply and the reservoir levels.
///
/// On the canvas it is drawn in the overlay layer (CadPainter.paintOverlay),
/// over the cached scene, so playing only redraws what moves; the same
/// painting makes the frames of the exports and the assistant's pictures
/// through a [PlaybackPaintView] of the picture.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/design/programme_playback.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'camera.dart';

/// The player of one tab: the programme loaded, the moment shown, and
/// whether it shows on the drawing (the canvas repaints when it changes).
class ProgrammePlayer extends ChangeNotifier {
  ProgrammePlayback? _playback;

  /// Where the clock panel starts, from the top of the drawing: lower on a
  /// phone, whose hint of the tool sits in that corner (set by the player's
  /// panel, which knows the layout).
  double panelTop = 12;
  double _hour = 0;
  PlaybackFrame? _frame;
  bool _shown = false;

  ProgrammePlayback? get playback => _playback;
  bool get shown => _shown && _playback != null;

  /// Hours from the start of the cycle.
  double get hour => _hour;
  set hour(double h) {
    final pb = _playback;
    final x = pb == null ? h : pb.timeline.wrap(h);
    if (x == _hour) return;
    _hour = x;
    _frame = null;
    notifyListeners();
  }

  /// The state shown (null without a programme).
  PlaybackFrame? get frame {
    final pb = _playback;
    if (pb == null) return null;
    return _frame ??= pb.frameAt(_hour);
  }

  /// Shows [pb] on the drawing, from [hour].
  void show(ProgrammePlayback pb, {double? hour}) {
    _playback = pb;
    _hour = pb.timeline.wrap(hour ?? _hour);
    _frame = null;
    _shown = true;
    notifyListeners();
  }

  /// Leaves the drawing as it is (the programme stays loaded).
  void hide() {
    if (!_shown) return;
    _shown = false;
    notifyListeners();
  }

  /// Forgets the programme (after the design changed).
  void clear() {
    _playback = null;
    _frame = null;
    _shown = false;
    notifyListeners();
  }
}

final _players = Expando<ProgrammePlayer>('programmePlayer');

extension ProgrammePlayerOf on ProjectController {
  /// The player of this tab.
  ProgrammePlayer get programmePlayer => _players[this] ??= ProgrammePlayer();
}

/// Where a picture of the overlay goes: world → pixels, pixels per metre,
/// the area seen and the size of the picture.
class PlaybackPaintView {
  const PlaybackPaintView({required this.toScreen, required this.scale, required this.visible, required this.size});
  factory PlaybackPaintView.ofCamera(Camera cam, Size size) => PlaybackPaintView(toScreen: cam.toScreen, scale: cam.scale, visible: cam.visible, size: size);
  final Offset Function(Pt p) toScreen;
  final double scale;
  final Bounds visible;
  final Size size;
}

/// What the overlay draws besides the system: the veil over what rests,
/// the panel of the moment, the bar of the cycle at the bottom.
class PlaybackLook {
  const PlaybackLook({this.veil = true, this.panel = true, this.timeBar = false, this.decimalPoint = false, this.panelTop = 12});

  /// Distance of the clock panel from the top of the picture.
  final double panelTop;

  /// Dims the drawing so the running groups stand out (the screen and the
  /// animations; the assistant's pictures keep the drawing as it is).
  final bool veil;
  final bool panel;
  final bool timeBar;

  /// Numbers with a decimal point whatever the language (pictures for the
  /// assistant).
  final bool decimalPoint;
}

/// Draws the player of [c] on the canvas (nothing when it is not shown).
void paintProgrammePlayer(Canvas canvas, Size size, Camera cam, ProjectController c) {
  final pl = c.programmePlayer;
  if (!pl.shown) return;
  final f = pl.frame;
  final pb = pl.playback;
  if (f == null || pb == null) return;
  paintPlayback(canvas, PlaybackPaintView.ofCamera(cam, size), c, pb, f, look: PlaybackLook(panelTop: pl.panelTop));
}

/// Water on the drawing: the tint of the areas and the wet sprinklers.
Color _wetTint() => Cad.ink(const Color(0xFF4FC3F7));

/// The emitters that drip.
Color _drops() => Cad.isLight ? const Color(0xFF0277BD) : const Color(0xFFB3E5FC);

/// The ramp of the velocity overlay of the drawing (blue at rest, green at
/// half the allowed velocity, orange at it, red at half as much again), in
/// steps of 1/16.
Color playbackVelocityColor(double v, double vmax) {
  final t = ((v / math.max(vmax, 1e-6)).clamp(0.0, 1.5) * 16).roundToDouble() / 16;
  final blue = Cad.ink(const Color(0xFF42A5F5)), green = Cad.ink(const Color(0xFF66BB6A)), orange = Cad.ink(const Color(0xFFFFA726));
  if (t <= 0.5) return Color.lerp(blue, green, t / 0.5)!;
  if (t <= 1.0) return Color.lerp(green, orange, (t - 0.5) / 0.5)!;
  return Color.lerp(orange, const Color(0xFFE53935), (t - 1.0) / 0.5)!;
}

/// Draws moment [f] of [pb] for [c] through [v].
void paintPlayback(Canvas canvas, PlaybackPaintView v, ProjectController c, ProgrammePlayback pb, PlaybackFrame f, {PlaybackLook look = const PlaybackLook()}) {
  final size = v.size;
  if (look.veil) canvas.drawRect(Offset.zero & size, Paint()..color = Cad.canvas.withValues(alpha: f.idle ? 0.6 : 0.5));
  final vis = v.visible.inflate(30 / math.max(v.scale, 1e-6));
  final water = _wetTint();
  // areas and machines of the running groups
  final tint = Paint()..color = water.withValues(alpha: 0.28);
  final edge = Paint()
    ..color = water.withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  for (final g in f.flows) {
    for (final a in g.areas) {
      if (a.points.length < 3 || !Bounds.ofPoints(a.points).intersects(vis)) continue;
      final path = Path()..fillType = PathFillType.evenOdd;
      path.addPolygon([for (final q in a.points) v.toScreen(q)], true);
      for (final h in a.holes) {
        if (h.length >= 3) path.addPolygon([for (final q in h) v.toScreen(q)], true);
      }
      canvas.drawPath(path, tint);
      canvas.drawPath(path, edge);
    }
    for (final m in g.machines) {
      final pts = m.outline();
      if (pts.length < 3 || !Bounds.ofPoints(pts).intersects(vis)) continue;
      final path = Path()..addPolygon([for (final q in pts) v.toScreen(q)], true);
      canvas.drawPath(path, tint);
      canvas.drawPath(path, edge);
    }
  }
  // the throw of the sprinklers
  final wetFill = Paint()..color = water.withValues(alpha: 0.2);
  var discs = 0;
  for (final g in f.flows) {
    for (final w in g.wet) {
      final r = w.radius * v.scale;
      if (r < 2 || !vis.contains(w.p) || ++discs > 6000) continue;
      final o = v.toScreen(w.p);
      if (w.arcDeg >= 360) {
        canvas.drawCircle(o, r, wetFill);
      } else {
        final start = -w.orientationDeg * math.pi / 180;
        canvas.drawArc(Rect.fromCircle(center: o, radius: r), start - w.arcDeg * math.pi / 180, w.arcDeg * math.pi / 180, true, wetFill);
      }
    }
  }
  // the pipes that carry water: colour by velocity, width by flow
  var qmax = 0.0;
  for (final g in f.flows) {
    for (final p in g.pipes) {
      qmax = math.max(qmax, p.flow);
    }
  }
  final lines = <(Color, double), List<double>>{};
  final shared = f.flows.length > 1 ? <(Pt, Pt), double>{} : null;
  for (final g in f.flows) {
    for (final p in g.pipes) {
      if (shared != null) {
        shared[(p.a, p.b)] = (shared[(p.a, p.b)] ?? 0) + p.flow;
        continue;
      }
      _addPipe(lines, v, vis, p.a, p.b, p.flow, p.velocity, p.maxVelocity, qmax);
    }
  }
  if (shared != null) {
    // overlapping groups: the flows of a shared pipe added (velocity scaled with them)
    final first = <(Pt, Pt), PipeFlow>{};
    for (final g in f.flows) {
      for (final p in g.pipes) {
        first.putIfAbsent((p.a, p.b), () => p);
      }
    }
    var top = 0.0;
    for (final q in shared.values) {
      top = math.max(top, q);
    }
    for (final e in shared.entries) {
      final p = first[e.key]!;
      final vel = p.flow > 0 ? p.velocity * e.value / p.flow : p.velocity;
      _addPipe(lines, v, vis, p.a, p.b, e.value, vel, p.maxVelocity, top);
    }
  }
  for (final e in lines.entries) {
    canvas.drawRawPoints(
      ui.PointMode.lines,
      Float32List.fromList(e.value),
      Paint()
        ..color = e.key.$1
        ..strokeWidth = e.key.$2
        ..strokeCap = StrokeCap.round,
    );
  }
  // the emitters, as dots at least 6 px apart
  final seen = <int>{};
  final dots = <double>[];
  for (final g in f.flows) {
    for (final w in g.wet) {
      if (!vis.contains(w.p)) continue;
      final o = v.toScreen(w.p);
      final key = ((o.dx / 6).floor() & 0xFFFF) << 16 | ((o.dy / 6).floor() & 0xFFFF);
      if (!seen.add(key)) continue;
      dots
        ..add(o.dx)
        ..add(o.dy);
      if (dots.length > 60000) break;
    }
  }
  if (dots.isNotEmpty) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(dots),
      Paint()
        ..color = _drops()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }
  // the pumps, on or off
  final turn = f.hour * 2 * math.pi * 3;
  for (final pm in pb.pumps) {
    if (!vis.contains(pm.p)) continue;
    final o = v.toScreen(pm.p);
    final on = f.pumpsOn.contains(pm.id);
    final ring = Paint()
      ..color = on ? Cad.ok : Cad.fg54
      ..style = PaintingStyle.stroke
      ..strokeWidth = on ? 2.6 : 1.6;
    canvas.drawCircle(o, on ? 12 : 10, ring);
    if (on) {
      for (var k = 0; k < 3; k++) {
        final a = turn + k * 2 * math.pi / 3;
        canvas.drawLine(o + Offset(math.cos(a), math.sin(a)) * 6, o + Offset(math.cos(a), math.sin(a)) * 11, ring);
      }
    } else {
      final bar = Paint()
        ..color = Cad.fg54
        ..strokeWidth = 2;
      canvas.drawLine(o + const Offset(-3, -4), o + const Offset(-3, 4), bar);
      canvas.drawLine(o + const Offset(3, -4), o + const Offset(3, 4), bar);
    }
  }
  if (look.panel) _panel(canvas, size, c, pb, f, look);
  if (look.timeBar) _timeBar(canvas, size, pb, f);
}

void _addPipe(Map<(Color, double), List<double>> lines, PlaybackPaintView v, Bounds vis, Pt a, Pt b, double q, double vel, double vmax, double qmax) {
  if (!(vis.contains(a) || vis.contains(b) || Bounds.ofPoints([a, b]).intersects(vis))) return;
  final w = ((1.6 + 4.4 * math.sqrt(qmax > 0 ? (q / qmax).clamp(0.0, 1.0) : 0)) * 2).roundToDouble() / 2;
  final oa = v.toScreen(a), ob = v.toScreen(b);
  (lines[(playbackVelocityColor(vel, vmax), w)] ??= [])
    ..add(oa.dx)
    ..add(oa.dy)
    ..add(ob.dx)
    ..add(ob.dy);
}

/// "Day 2 06:30" (or the time alone on a one-day cycle).
String playbackClock(ProjectController c, ProgrammePlayback pb, double hour) => pb.timeline.clockAt(hour, dayLabel: (d) => c.t('ply.day', {'n': '$d'}));

/// The lines of the panel of moment [f]: (text, colour or null).
List<(String, Color?)> playbackPanelLines(ProjectController c, ProgrammePlayback pb, PlaybackFrame f, {bool decimalPoint = false}) {
  final t = c.t;
  final u = c.units;
  String n(double x, int d) => decimalPoint ? fmt(x, d) : fmtLocale(x, d, c.lang);
  final out = <(String, Color?)>[];
  final names = <String>[];
  for (final s in f.running) {
    final name = s.run.cycles > 1 ? '${s.run.flowName} (${s.run.cycle}/${s.run.cycles})' : s.run.flowName;
    if (!names.contains(name)) names.add(name);
  }
  out.add((f.idle ? t('ply.idle') : names.join(' + '), f.idle ? null : _wetTint()));
  out.add(('${t('rep.flow')}: ${n(u.flowFromSi(f.totalFlow), 1)} ${u.flowLabel}', null));
  // the pressure the system gets: after the pumps that run, else at the supply
  final pumped = [
    for (final pm in pb.pumps)
      if (f.pumpHeads.containsKey(pm.id)) pm,
  ];
  for (final pm in pumped) {
    out.add(('${t('ply.pumpP')}${pumped.length > 1 ? ' ${pm.name}' : ''}: ${n(u.pressureFromHead(f.pumpHeads[pm.id]!), 1)} ${u.pressureLabel}', null));
  }
  for (final s in f.supplies) {
    if (pumped.isNotEmpty && s.head.abs() < 0.05) continue;
    out.add(('${t('ply.supplyP')}${f.supplies.length > 1 ? ' ${s.name}' : ''}: ${n(u.pressureFromHead(s.head), 1)} ${u.pressureLabel}', null));
  }
  if (pb.pumps.isNotEmpty) out.add((t('ply.pumps', {'on': '${pb.pumps.where((p) => f.pumpsOn.contains(p.id)).length}', 'n': '${pb.pumps.length}'}), null));
  for (final r in pb.reservoirs) {
    final level = f.levels[r.supplyId] ?? r.levelAt(f.hour);
    final usable = r.study.usableVolume;
    final pct = usable > 0 ? 100 * (r.volumeAt(f.hour) - r.study.volumeAt(r.study.minLevel)) / usable : 100.0;
    final name = c.project.byId(r.supplyId)?.name ?? '';
    out.add(('${t('res.level')}${name.isEmpty ? '' : ' $name'}: ${n(u.lengthFromSi(level), 2)} ${u.lengthLabel} (${n(pct.clamp(0, 100).toDouble(), 0)} %)', null));
  }
  if (f.overlap) out.add((t('ply.overlap'), Cad.caution));
  return out;
}

TextPainter _tp(String s, double size, Color color, {FontWeight weight = FontWeight.normal, double? maxWidth, int maxLines = 2}) => TextPainter(
  text: TextSpan(
    text: s,
    style: TextStyle(fontSize: size, color: color, fontWeight: weight),
  ),
  textDirection: TextDirection.ltr,
  maxLines: maxLines,
  ellipsis: '…',
)..layout(maxWidth: maxWidth ?? double.infinity);

/// The clock and the numbers of the moment, top left.
void _panel(Canvas canvas, Size size, ProjectController c, ProgrammePlayback pb, PlaybackFrame f, PlaybackLook look) {
  final maxW = math.min(320.0, size.width - 24);
  if (maxW < 80) return;
  final clock = _tp(playbackClock(c, pb, f.hour), 16, Cad.canvasText, weight: FontWeight.bold);
  final rows = [for (final (s, col) in playbackPanelLines(c, pb, f, decimalPoint: look.decimalPoint)) _tp(s, 11, col ?? Cad.canvasText, maxWidth: maxW - 16)];
  var w = clock.width, h = clock.height + 4;
  for (final r in rows) {
    w = math.max(w, r.width);
    h += r.height + 1;
  }
  final o = Offset(12, look.panelTop);
  final box = RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, math.min(maxW, w + 16), h + 12), const Radius.circular(6));
  canvas.drawRRect(box, Paint()..color = Cad.canvas.withValues(alpha: 0.82));
  canvas.drawRRect(
    box,
    Paint()
      ..color = Cad.fg30
      ..style = PaintingStyle.stroke,
  );
  var y = o.dy + 6;
  clock.paint(canvas, Offset(o.dx + 8, y));
  y += clock.height + 4;
  for (final r in rows) {
    r.paint(canvas, Offset(o.dx + 8, y));
    y += r.height + 1;
    r.dispose();
  }
  clock.dispose();
}

/// Height (pixels) of the band over an exported frame [width] pixels wide:
/// two lines of text and, with [timeBar], the bar of the cycle.
double playbackBandHeight(int width, {bool timeBar = true}) {
  final font = (width / 36).clamp(11.0, 22.0);
  return (font * 2.6 + 10 + (timeBar ? 12 : 0)).roundToDouble();
}

/// The band over an exported frame ([size]: its width and height): the
/// clock and what runs on the first line, the flow, pressures, pumps and
/// levels on the second, and the bar of the cycle under them; so that no
/// text covers the drawing of a small picture.
void paintPlaybackBand(Canvas canvas, Size size, ProjectController c, ProgrammePlayback pb, PlaybackFrame f, {bool timeBar = true}) {
  canvas.drawRect(Offset.zero & size, Paint()..color = Color.lerp(Cad.canvas, Cad.fg, 0.07)!);
  final font = (size.width / 36).clamp(11.0, 22.0);
  final lines = playbackPanelLines(c, pb, f);
  final clock = _tp(playbackClock(c, pb, f.hour), font * 1.1, Cad.canvasText, weight: FontWeight.bold);
  final first = _tp(lines.first.$1, font, lines.first.$2 ?? Cad.fg70, maxWidth: math.max(10, size.width - clock.width - 30), maxLines: 1);
  final rest = _tp([for (final l in lines.skip(1)) l.$1].join('  ·  '), font * 0.9, Cad.canvasText, maxWidth: size.width - 16, maxLines: 1);
  clock.paint(canvas, const Offset(8, 4));
  first.paint(canvas, Offset(clock.width + 20, 4 + (clock.height - first.height) / 2));
  rest.paint(canvas, Offset(8, 6 + clock.height));
  for (final tp in [clock, first, rest]) {
    tp.dispose();
  }
  if (timeBar) _timeBar(canvas, size, pb, f, y: size.height - 10, x0: 8);
}

/// The cycle as a bar: the runs as blocks, the moment as a line.
void _timeBar(Canvas canvas, Size size, ProgrammePlayback pb, PlaybackFrame f, {double? y, double x0 = 12}) {
  final tl = pb.timeline;
  final x1 = size.width - x0;
  y ??= size.height - 16;
  if (x1 - x0 < 40) return;
  double x(double h) => x0 + (x1 - x0) * h / tl.hours;
  canvas.drawRect(Rect.fromLTRB(x0, y, x1, y + 6), Paint()..color = Cad.fg24);
  final block = Paint()..color = _wetTint();
  for (final s in tl.spans) {
    canvas.drawRect(Rect.fromLTRB(x(s.start), y, math.max(x(s.end), x(s.start) + 1), y + 6), block);
  }
  for (var d = 1; d < tl.days; d++) {
    canvas.drawLine(Offset(x(d * 24.0), y - 2), Offset(x(d * 24.0), y + 8), Paint()..color = Cad.fg54);
  }
  final at = x(f.hour);
  canvas.drawLine(
    Offset(at, y - 5),
    Offset(at, y + 11),
    Paint()
      ..color = Cad.canvasText
      ..strokeWidth = 2,
  );
}

/// The area of the drawing worth showing in a picture of [pb]: the groups,
/// else the drawing.
Bounds playbackWorld(ProjectController c, ProgrammePlayback pb) {
  var b = pb.bounds;
  for (final pm in pb.pumps) {
    b = b.include(pm.p);
  }
  for (final s in c.project.entities.whereType<WaterSupplyEntity>()) {
    b = b.include(s.position);
  }
  if (b.isEmpty) b = c.project.bounds;
  return b.inflate(math.max(2.0, 0.06 * math.max(b.width, b.height)));
}
