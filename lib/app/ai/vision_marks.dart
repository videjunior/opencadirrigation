/// What the AI assistant's pictures mark on the drawing for the model,
/// beyond the drawing itself (view_snapshot `colour_by` and `marks`, and the
/// picture shown after a round of changes):
///
/// - its own changes: the items it added, changed and removed, against the
///   drawing before its first change of the task (the user's message) or of
///   the round of tools ([ChangeTracker], [ChangeMarks]);
/// - the design messages at the items they are about, numbered as
///   get_design_messages numbers them ([IssueMarks]);
/// - every zone in its own colour, its name at its valve ([ZoneColours]).
///
/// The marks are drawn over the drawing and the grid; their text, written
/// once the picture's frame is known, says what each colour or number is
/// and where it lies in pixels.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/advisor.dart';
import '../../core/io/sheet_set.dart' show zoneMembers;
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../widgets/advice_panel.dart' show adviceTitle;
import 'vision_mapping.dart';
import 'vision_render.dart' show PicturePainter, pictureAnchor;

// ---------------------------------------------------------------- changes

/// Items added and changed (as they are now) and removed (as they were).
class EntityDiff {
  const EntityDiff(this.added, this.changed, this.removed);
  final List<Entity> added, changed, removed;

  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty;
  int get count => added.length + changed.length + removed.length;

  /// Where the changes lie.
  Bounds get bounds => [...added, ...changed, ...removed].fold(Bounds.empty, (Bounds b, e) => b.union(e.bounds));

  static String _sig(Entity e) => jsonEncode(e.toJson()..remove('data'));

  static EntityDiff between(List<Entity> before, List<Entity> now) {
    final old = {for (final e in before) e.id: e};
    final added = <Entity>[], changed = <Entity>[];
    final seen = <String>{};
    for (final e in now) {
      seen.add(e.id);
      final o = old[e.id];
      if (o == null) {
        added.add(e);
      } else if (o.runtimeType != e.runtimeType || _sig(o) != _sig(e)) {
        changed.add(e);
      }
    }
    return EntityDiff(added, changed, [
      for (final e in before)
        if (!seen.contains(e.id)) e,
    ]);
  }

  /// "3 added, 1 changed, 2 removed" ("nothing" when empty).
  String counts() =>
      isEmpty ? 'nothing' : [if (added.isNotEmpty) '${added.length} added', if (changed.isNotEmpty) '${changed.length} changed', if (removed.isNotEmpty) '${removed.length} removed'].join(', ');
}

/// The drawing before the assistant's changes: as it was before its first
/// change of the task and of the current round of tools. The tools call
/// [beforeWrite] before every change; the assistant ends the round after
/// its tools and the task when the answer is complete, and the task's
/// changes stay readable until the next task changes something.
class ChangeTracker {
  ChangeTracker(this.c);
  final ProjectController c;
  List<Entity>? _task, _round;
  bool _taskEnded = false;

  /// Before a change: keeps the drawing as it is when the round (and the
  /// task) has nothing kept yet.
  void beforeWrite() {
    if (_taskEnded) {
      _task = null;
      _taskEnded = false;
    }
    if (_round != null) return;
    final now = [for (final e in c.project.entities) e.clone()];
    _round = now;
    _task ??= now;
  }

  /// The changes of this round of tools; null when it changed nothing.
  EntityDiff? get round => _round == null ? null : EntityDiff.between(_round!, c.project.entities);

  /// The changes of this task (or, once it ended, of the last task that
  /// changed something); null when none was made.
  EntityDiff? get task => _task == null ? null : EntityDiff.between(_task!, c.project.entities);

  /// The task in [task] is over (its changes stay readable).
  bool get taskEnded => _taskEnded;

  void endRound() => _round = null;

  void endTask() {
    _round = null;
    if (_task != null) _taskEnded = true;
  }
}

/// Colours of the change marks: none of the program's layers or of the
/// grid over a photo, and clear over green fields, soil and the dark canvas.
const changeAdded = Color(0xFF00E5FF), changeChanged = Color(0xFFFFAB00), changeRemoved = Color(0xFFFF1744);

/// The changes of [diff] marked over a picture: a cyan halo along every
/// added item, an amber one along every changed item, a dashed red outline
/// where a removed item was.
class ChangeMarks {
  ChangeMarks(this.diff, {required this.since});
  final EntityDiff diff;

  /// What the changes are counted from ("since your first change of this
  /// task").
  final String since;

  int _in(List<Entity> es, Bounds w) => es.where((e) => e.bounds.intersects(w)).length;

  /// The text for the model about the marks in [f].
  String describe(PictureFrame f) {
    if (diff.isEmpty) return 'Changes: none $since.';
    final w = f.world;
    final a = _in(diff.added, w), ch = _in(diff.changed, w), r = _in(diff.removed, w);
    final outside = diff.count - a - ch - r;
    final b = diff.bounds;
    return 'Changes $since: ${diff.counts()}; in this picture ${a == 0 && ch == 0 && r == 0 ? 'none' : [if (a > 0) '$a added (cyan halo)', if (ch > 0) '$ch changed (amber halo)', if (r > 0) '$r removed (dashed red outline of what was there)'].join(', ')}'
        '${outside > 0 ? '; $outside outside it (all the changes lie within ${_box(b)} m)' : ''}.';
  }

  void paint(Canvas canvas, PictureFrame f) {
    final w = f.world.inflate(5 * f.mpp);
    final dark = Paint()
      ..color = const Color(0xCC000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint halo(Color c) => Paint()
      ..color = c.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final (es, col) in [(diff.changed, changeChanged), (diff.added, changeAdded)]) {
      final p = halo(col);
      for (final e in es) {
        if (!e.bounds.intersects(w)) continue;
        _outline(f, e, (pts, closed) => canvas.drawPath(Path()..addPolygon(pts, closed), p), (o, r) {
          if (r < 6) {
            canvas.drawCircle(o, 7, p);
          } else {
            canvas.drawCircle(o, r, p);
          }
        });
      }
    }
    final red = Paint()
      ..color = changeRemoved
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.butt;
    for (final e in diff.removed) {
      if (!e.bounds.intersects(w)) continue;
      _outline(
        f,
        e,
        (pts, closed) {
          final line = closed && pts.isNotEmpty ? [...pts, pts.first] : pts;
          _dashed(canvas, line, dark);
          _dashed(canvas, line, red);
        },
        (o, r) {
          final rr = r < 6 ? 7.0 : r;
          final ring = [for (var k = 0; k <= 48; k++) o + Offset(rr * math.cos(k * math.pi / 24), rr * math.sin(k * math.pi / 24))];
          _dashed(canvas, ring, dark, dash: 5, gap: 4);
          _dashed(canvas, ring, red, dash: 5, gap: 4);
          if (r < 6) {
            canvas.drawLine(o + const Offset(-4, -4), o + const Offset(4, 4), red);
            canvas.drawLine(o + const Offset(-4, 4), o + const Offset(4, -4), red);
          }
        },
      );
    }
  }
}

/// The outline of [e] on [f]: a line (closed or not) or a circle (radius
/// in pixels; 0 for a point item, which has no size of its own).
void _outline(PictureFrame f, Entity e, void Function(List<Offset> pts, bool closed) line, void Function(Offset centre, double radius) circle) {
  switch (e) {
    case PivotEntity x:
      circle(f.toPx(x.center), x.radiusM / f.mpp);
    case CircleEntity x:
      circle(f.toPx(x.center), x.radius / f.mpp);
    case PointEntity x:
      circle(f.toPx(x.position), 0);
    default:
      final pts = e.linearPoints;
      if (pts != null && pts.length >= 2) {
        line([for (final q in pts) f.toPx(q)], e.isClosedShape);
      } else {
        final b = e.bounds;
        if (b.isEmpty) return;
        line([f.toPx(Pt(b.minX, b.minY)), f.toPx(Pt(b.maxX, b.minY)), f.toPx(Pt(b.maxX, b.maxY)), f.toPx(Pt(b.minX, b.maxY))], true);
      }
  }
}

/// [pts] drawn as a dashed line.
void _dashed(Canvas canvas, List<Offset> pts, Paint paint, {double dash = 7, double gap = 5}) {
  var phase = 0.0;
  var on = true;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], d = pts[i] - pts[i - 1];
    final len = d.distance;
    if (len < 1e-6) continue;
    var pos = 0.0;
    while (pos < len) {
      final step = math.min((on ? dash : gap) - phase, len - pos);
      if (on) canvas.drawLine(a + d * (pos / len), a + d * ((pos + step) / len), paint);
      pos += step;
      phase += step;
      if (phase >= (on ? dash : gap) - 1e-9) {
        phase = 0;
        on = !on;
      }
    }
  }
}

String _box(Bounds b) => '[${fmt(b.minX, 1)}, ${fmt(b.minY, 1)}, ${fmt(b.maxX, 1)}, ${fmt(b.maxY, 1)}]';

// ---------------------------------------------------------------- issues

/// Colours of the message marks by severity.
Color issueColour(AdviceLevel l) => switch (l) {
  AdviceLevel.error => const Color(0xFFFF1744),
  AdviceLevel.warning => const Color(0xFFFFC400),
  AdviceLevel.info => const Color(0xFF40C4FF),
};

/// The design messages of [c] (as get_design_messages numbers them) marked
/// at the items they are about: a disc in the colour of the severity with
/// the message number, messages at the same spot sharing one mark.
class IssueMarks {
  IssueMarks(this.c);
  final ProjectController c;

  /// Messages listed (as get_design_messages lists them).
  static const maxMessages = 80;

  /// Marks per message.
  static const perMessage = 6;

  final List<String> _lines = [];
  final List<(Offset, List<int>, AdviceLevel)> _marks = [];

  /// Works out the marks of [f]; returns the painter (null: nothing to
  /// mark there).
  PicturePainter? prepare(PictureFrame f) {
    _lines.clear();
    _marks.clear();
    final adv = c.advice;
    final p = c.project;
    if (adv.isEmpty) {
      _lines.add(c.results == null ? 'Messages: none so far (pressures and flows are only checked after run_design).' : 'Messages: none.');
      return null;
    }
    final placed = <int>[], outside = <int>[], global = <int>[];
    final where = <int, List<Offset>>{};
    for (var i = 0; i < adv.length && i < maxMessages; i++) {
      final a = adv[i];
      final pts = <Pt>[];
      if (a.at != null) pts.add(a.at!);
      final ids = [...a.entityIds, if (a.entityIds.isEmpty && a.contextId != null) a.contextId!];
      for (final id in ids) {
        if (pts.length >= perMessage) break;
        final e = p.byId(id);
        if (e == null) continue;
        final q = pictureAnchor(e, f.world);
        if (q != null) pts.add(q);
      }
      final inside = [
        for (final q in pts)
          if (f.world.contains(q)) f.toPx(q),
      ];
      if (inside.isNotEmpty) {
        placed.add(i);
        where[i] = inside;
      } else if (ids.isEmpty && a.at == null) {
        global.add(i);
      } else {
        outside.add(i);
      }
    }
    // one mark per spot: messages within a disc of each other share it
    for (final i in placed) {
      for (final o in where[i]!) {
        final k = _marks.indexWhere((m) => (m.$1 - o).distance < 16);
        if (k < 0) {
          _marks.add((o, [i], adv[i].level));
        } else if (!_marks[k].$2.contains(i)) {
          final m = _marks[k];
          _marks[k] = (m.$1, [...m.$2, i], adv[i].level.index < m.$3.index ? adv[i].level : m.$3);
        }
      }
    }
    _lines.add(
      'Marks (messages, numbered as get_design_messages): a disc at the items of each message, red error, amber warning, blue note; '
      '${placed.length} of ${math.min(adv.length, maxMessages)} messages in this picture.',
    );
    for (final i in placed.take(40)) {
      final a = adv[i];
      final at = where[i]!.take(3).map((o) => '(${o.dx.round()}, ${o.dy.round()})').join(' ');
      _lines.add('#$i ${a.level.name} [${a.code}] ${adviceTitle(c, a)} — px $at');
    }
    if (placed.length > 40) _lines.add('(${placed.length - 40} more marked)');
    if (outside.isNotEmpty) _lines.add('Outside this picture: ${outside.take(30).map((i) => '#$i').join(', ')}${outside.length > 30 ? '…' : ''} (region "items" with their ids frames them).');
    if (global.isNotEmpty) _lines.add('About the whole project (no place to mark): ${global.take(30).map((i) => '#$i').join(', ')}.');
    return _marks.isEmpty ? null : _paint;
  }

  /// The text for the model (after [prepare]).
  List<String> get lines => List.unmodifiable(_lines);

  void _paint(Canvas canvas, PictureFrame f) {
    for (final (o, ids, level) in _marks) {
      final text = ids.length <= 3 ? ids.join(',') : '${ids.take(3).join(',')}+';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 10.5, color: Colors.black, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = math.max(18.0, tp.width + 8), h = 18.0;
      // the mark sits above-right of the spot, a stem points at it
      final box = Rect.fromLTWH(o.dx + 6, o.dy - h - 6, w, h);
      final fill = Paint()..color = issueColour(level);
      final edge = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(
        o,
        box.bottomLeft + const Offset(3, 0),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 3,
      );
      canvas.drawLine(o, box.bottomLeft + const Offset(3, 0), fill..strokeWidth = 1.6);
      canvas.drawCircle(o, 3.5, fill);
      canvas.drawCircle(o, 3.5, edge);
      final r = RRect.fromRectAndRadius(box, const Radius.circular(9));
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, edge);
      tp.paint(canvas, Offset(box.left + (w - tp.width) / 2, box.top + (h - tp.height) / 2));
      tp.dispose();
    }
  }
}

// ---------------------------------------------------------------- zones

/// Colours of the zones, in turn: distinct over the dark canvas and over
/// aerial imagery, none of them the yellow of the selection and of the grid
/// over a photo nor the magenta of proposed geometry.
const zonePalette = [
  Color(0xFFE6194B),
  Color(0xFF3CB44B),
  Color(0xFF4363D8),
  Color(0xFFF58231),
  Color(0xFF911EB4),
  Color(0xFF42D4F4),
  Color(0xFFBFEF45),
  Color(0xFFFABED4),
  Color(0xFF469990),
  Color(0xFFDCBEFF),
  Color(0xFF9A6324),
  Color(0xFFAAFFC3),
  Color(0xFF808000),
  Color(0xFFFFD8B1),
];

/// The mainline when the picture is coloured by zones.
const mainlineColour = Color(0xFFFFFFFF);

/// One colour per zone (its valve and every item it reaches), white for the
/// mainline; other items keep their layer colours.
class ZoneColours {
  ZoneColours._(this.zones, this._byEntity, this._names);

  factory ZoneColours.of(ProjectController c) {
    final p = c.project;
    final members = zoneMembers(p, c.results);
    String nameOf(String valveId) {
      final v = p.byId(valveId);
      if (v is ControlValveEntity && v.zoneName.isNotEmpty) return v.zoneName;
      return (v?.name.isNotEmpty ?? false) ? v!.name : valveId;
    }

    final order = members.keys.toList()..sort((a, b) => _natural(nameOf(a), nameOf(b)));
    final zones = <ZoneColour>[];
    final byEntity = <String, Color>{};
    for (var k = 0; k < order.length; k++) {
      final colour = zonePalette[k % zonePalette.length];
      final ids = members[order[k]]!;
      zones.add(ZoneColour(order[k], nameOf(order[k]), colour, ids.length));
      for (final id in ids) {
        byEntity.putIfAbsent(id, () => colour);
      }
    }
    return ZoneColours._(zones, byEntity, {for (final z in zones) z.valveId: z.name});
  }

  final List<ZoneColour> zones;
  final Map<String, Color> _byEntity;
  final Map<String, String> _names;

  /// The colour of [e] in the picture (null: its layer's).
  Color? tint(Entity e) => _byEntity[e.id] ?? (e.hydraulicScope == HydraulicScope.mainline ? mainlineColour : null);

  /// The text for the model.
  String describe(ProjectController c, PictureFrame f) {
    if (zones.isEmpty) return 'Colours: no zone yet (no control valve reaches a zone item), so the drawing keeps its layer colours; the mainline is white.';
    final p = c.project;
    var loose = 0;
    for (final e in p.entities) {
      if (e.hydraulicScope == HydraulicScope.zone && !_byEntity.containsKey(e.id)) loose++;
    }
    String hex(Color x) => '#${(x.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final shown = [for (final z in zones.take(40)) '${z.name} ${hex(z.colour)} (valve ${z.valveId}, ${z.items} items${_inFrame(p, z.valveId, f) ? '' : ', valve outside the picture'})'];
    return 'Colours: every zone in its own colour, its name boxed at its valve: ${shown.join('; ')}${zones.length > 40 ? '; …' : ''}. '
        '${zones.length > zonePalette.length ? 'With ${zones.length} zones the ${zonePalette.length} colours repeat: tell zones of one colour apart by the names at the valves. ' : ''}'
        'The mainline is white; other items keep their layer colours.${loose > 0 ? ' $loose zone items belong to no zone (not reached from a valve: unconnected) and keep their layer colours.' : ''}';
  }

  static bool _inFrame(Project p, String id, PictureFrame f) {
    final e = p.byId(id);
    return e is ControlValveEntity && f.world.contains(e.position);
  }

  /// The zone names at their valves.
  void paintLabels(ProjectController c, Canvas canvas, PictureFrame f) {
    final taken = <Rect>[];
    for (final z in zones) {
      final v = c.project.byId(z.valveId);
      if (v is! ControlValveEntity || !f.world.contains(v.position)) continue;
      final o = f.toPx(v.position);
      final light = z.colour.computeLuminance() > 0.35;
      final tp = TextPainter(
        text: TextSpan(
          text: _names[z.valveId]!.length > 18 ? '${_names[z.valveId]!.substring(0, 17)}…' : _names[z.valveId],
          style: TextStyle(fontSize: 10.5, color: light ? Colors.black : Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      Rect? box;
      for (final s in [Offset(8, -tp.height - 8), Offset(8, 6), Offset(-tp.width - 14, -tp.height - 8), Offset(-tp.width - 14, 6)]) {
        final r = Rect.fromLTWH(o.dx + s.dx, o.dy + s.dy, tp.width + 6, tp.height + 3);
        if (taken.every((x) => !x.overlaps(r))) {
          box = r;
          break;
        }
      }
      box ??= Rect.fromLTWH(o.dx + 8, o.dy - tp.height - 8, tp.width + 6, tp.height + 3);
      taken.add(box);
      canvas.drawRect(box, Paint()..color = z.colour);
      canvas.drawRect(
        box,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      tp.paint(canvas, box.topLeft + const Offset(3, 1.5));
      tp.dispose();
    }
  }
}

/// A zone and its colour.
class ZoneColour {
  const ZoneColour(this.valveId, this.name, this.colour, this.items);
  final String valveId, name;
  final Color colour;

  /// Items of the zone, its valve included.
  final int items;
}

/// "Zone 2" before "Zone 10".
int _natural(String a, String b) {
  final ra = RegExp(r'(\d+)|(\D+)').allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final rb = RegExp(r'(\d+)|(\D+)').allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < ra.length && i < rb.length; i++) {
    final x = int.tryParse(ra[i]), y = int.tryParse(rb[i]);
    final c = x != null && y != null ? x.compareTo(y) : ra[i].compareTo(rb[i]);
    if (c != 0) return c;
  }
  return ra.length.compareTo(rb.length);
}
