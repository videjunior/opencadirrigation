/// Turns a project into a native CAD drawing ([CadDrawing]) for the
/// R2000 DXF and DWG exports, so the work can go on in a CAD program:
///
/// * drawing entities stay what they are: lines, lightweight polylines (the
///   arcs of revision clouds and pivot sectors as bulges), circles, arcs,
///   splines (the app's curve as cubic Bézier spans, plus its fit points),
///   hatches (solid, or ANSI31 turned and scaled to the hatch's angle and
///   spacing), text and multiline text;
/// * dimensions are DIMENSION entities (aligned, 3-point angular, radius,
///   diameter, ordinate) with their anonymous `*D` blocks already drawn, so
///   programs show them without recomputing; leaders are LEADER entities
///   with their note as multiline text;
/// * symbols and hydraulic items are references to small blocks (one per
///   kind) whose invisible attributes carry the entity's name and catalogue
///   item, on the item's layer;
/// * contours keep their elevation, spot heights and breakline vertices are
///   3D points; tapes, wire routes and breaklines use a dashed linetype.
library;

import 'dart:math' as math;

import '../design/pivot.dart' show PivotKind;
import '../model/blocks.dart' show resolveBlockRefs;
import '../model/dim_style.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../units.dart';
import 'cad_drawing.dart';

/// Builds the [CadDrawing] of a project; [units] decide the unit dimensions
/// show (the drawing itself is always in metres).
class CadExport {
  CadExport(this.project, {this.units = Units.metric});
  final Project project;
  final Units units;

  static const outletBlock = 'OCI_OUTLET', valveBlock = 'OCI_VALVE', supplyBlock = 'OCI_SUPPLY', pumpBlock = 'OCI_PUMP', miscBlock = 'OCI_MISC';
  static const junctionBlock = 'OCI_JUNCTION', controllerBlock = 'OCI_CONTROLLER', pivotBlock = 'OCI_PIVOT', towerBlock = 'OCI_TOWER';
  static const dimStyle = 'OCI', dimStyleHorizontal = 'OCI_H';
  static const dashed = 'DASHED';
  static const defpoints = 'Defpoints';

  /// Paper sizes of the dimension styles are those of ISO-25 (2.5 mm text);
  /// this DIMSCALE makes the text 0.5 m, the height the R12 export used.
  static const dimScale = 0.2;

  /// Layers whose lines are dashed in the app (and in the plot).
  static const dashedLayers = {Layers.tapes, Layers.breaklines, Layers.wires};

  /// Block name of a symbol kind (`OCI_SYMBOL_NORTH_ARROW`…).
  static String symbolBlock(SymbolKind k) => 'OCI_SYMBOL_${k.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase()}';

  final _entities = <CadEntity>[];
  final _blocks = <String, CadBlock>{};

  /// 1.6.0 CAD: the drawing's name of each user block, by its name in the project.
  final _userBlocks = <String, String>{};

  /// Where [_add] puts entities: model space, or the block being converted.
  late List<CadEntity> _out = _entities;
  final _layerNames = <String, String>{};
  var _dims = 0;

  CadDimStyle get _alignedStyle =>
      CadDimStyle(dimStyle, scale: dimScale, lengthFactor: _dimUnits.lengthFromSi(1), suffix: _suffix, decimals: _ds.decimals, textHeight: _dimTextHeight, arrowSize: _dimArrowSize);
  CadDimStyle get _horizontalStyle => CadDimStyle(
    dimStyleHorizontal,
    scale: dimScale,
    lengthFactor: _dimUnits.lengthFromSi(1),
    suffix: _suffix,
    horizontalText: true,
    decimals: _ds.decimals,
    textHeight: _dimTextHeight,
    arrowSize: _dimArrowSize,
  );
  String get _suffix => _dimUnits.length == LengthUnit.m || !_ds.showUnit ? '' : '<> ${_dimUnits.lengthLabel}';

  // 1.6.0 CAD: the project's dimension style — decimals, unit and the text
  // height and arrowheads in metres of the drawing (paper sizes of the
  // styles are those sizes over DIMSCALE)
  DimStyle get _ds => project.dimStyle;
  Units get _dimUnits => _ds.unitsFor(units);
  double get _dimTextHeight => _ds.textHeightM > 0 ? _ds.textHeightM / dimScale : 2.5;
  double get _dimArrowSize => _ds.arrowSizeM > 0 ? _ds.arrowSizeM / dimScale : _dimTextHeight;

  /// The layer name in the drawing (a valid table name).
  String _layer(String name) => _layerNames.putIfAbsent(name, () {
    final n = cadTableName(name);
    // table names do not tell case apart: "Tubos" and "TUBOS" are one layer
    return _layerKeys.putIfAbsent(n.toLowerCase(), () => n);
  });

  /// The name each layer got, by its lower case.
  final _layerKeys = <String, String>{};

  /// Adds [e] unless a coordinate or size is not a number (a damaged
  /// project): CAD programs reject files with NaN.
  void _add(CadEntity e) {
    if (_finite(e)) _out.add(e);
  }

  static bool _finite(CadEntity e) {
    if (!e.extentPoints.every((p) => p.x.isFinite && p.y.isFinite)) return false;
    return switch (e) {
      CadLine l => l.z.isFinite,
      CadPolyline p => p.elevation.isFinite && p.bulges.every((b) => b.isFinite),
      CadArc a => a.startDeg.isFinite && a.endDeg.isFinite,
      CadPoint p => p.z.isFinite,
      CadText t => t.height.isFinite && t.rotationDeg.isFinite && t.z.isFinite,
      CadMText m => m.height.isFinite && m.rotationDeg.isFinite,
      CadSpline s => s.knots.every((k) => k.isFinite),
      CadHatch h => h.patternAngleDeg.isFinite && h.patternScale.isFinite && h.loops.every((l) => l.points.every((p) => p.x.isFinite && p.y.isFinite)),
      CadInsert i => i.scale.isFinite && i.rotationDeg.isFinite,
      CadDimension d => d.measurement.isFinite,
      _ => true,
    };
  }

  CadDrawing build() {
    _entities.clear();
    _blocks.clear();
    _out = _entities;
    _dims = 0;
    // 1.6.0 CAD: the names the user's blocks take in the drawing, known
    // before the entities (block references insert them); the names of the
    // program's own blocks (OCI_…) stay theirs
    resolveBlockRefs(project);
    _userBlocks.clear();
    final blockKeys = <String>{};
    for (final b in project.blocks.blocks) {
      var name = cadTableName(b.name, 'BLOCK');
      if (b.isEmpty || name.startsWith('*')) continue;
      if (name.toUpperCase().startsWith('OCI_')) name = 'U_$name';
      // block names do not tell case apart either: another spelling of a name taken gets a number
      bool taken(String n) => blockKeys.contains(n.toLowerCase());
      if (taken(name)) {
        var k = 2;
        while (taken('${name}_$k')) {
          k++;
        }
        name = '${name}_$k';
      }
      blockKeys.add(name.toLowerCase());
      _userBlocks[b.name] = name;
    }
    for (final e in project.entities) {
      _entity(e);
    }
    // the user's blocks, ready to insert in the CAD program (their entities
    // are already in block coordinates; 1.6.0 CAD: with their attributes)
    for (final b in project.blocks.blocks) {
      final name = _userBlocks[b.name];
      if (name == null) continue;
      final ents = <CadEntity>[];
      _out = ents;
      for (final e in b.entities) {
        _entity(e);
      }
      _out = _entities;
      _blocks[name] = CadBlock(
        name,
        ents,
        attdefs: [for (final a in b.attributes) CadAttrib(a.tag, a.defaultValue, a.position, a.height, rotationDeg: a.rotationDeg, invisible: !a.visible, prompt: a.prompt.isEmpty ? a.tag : a.prompt)],
      );
    }
    // layers: '0', the project's (with colours, linetypes and states), any
    // other layer an entity uses, and Defpoints for the dimension points
    final layers = <CadLayer>[const CadLayer('0')];
    final seen = {'0'};
    for (final l in project.layers) {
      final name = _layer(l.name);
      if (!seen.add(name)) continue;
      final rgb = l.color & 0xFFFFFF;
      final aci = nearestAci(rgb);
      layers.add(CadLayer(name, aci: aci, rgb: aciRgb(aci) == rgb ? null : rgb, linetype: dashedLayers.contains(l.name) ? dashed : 'Continuous', off: !l.visible, locked: l.locked));
    }
    for (final e in [..._entities, for (final b in _blocks.values) ...b.entities]) {
      if (!seen.add(e.layer)) continue;
      layers.add(e.layer == defpoints ? const CadLayer(defpoints, plot: false) : CadLayer(e.layer, linetype: dashedLayers.contains(e.layer) ? dashed : 'Continuous'));
    }
    return CadDrawing(
      layers: layers,
      linetypes: const [
        CadLinetype(dashed, 'Dashed __ __ __', [0.5, -0.25]),
      ],
      dimStyles: [_alignedStyle, _horizontalStyle],
      blocks: _blocks.values.toList(),
      entities: List.of(_entities),
      // spot heights and breakline vertices drawn as small crosses
      pointMode: 2,
      pointSize: 0.5,
    );
  }

  // ------------------------------------------------------------------ entities

  void _entity(Entity e) {
    final layer = _layer(e.layer);
    final labels = _layer(Layers.labels);
    final cat = project.catalog;
    switch (e) {
      case LineEntity l:
        _add(CadLine(layer, l.a, l.b));
      case PolylineEntity p:
        _add(CadPolyline(layer, p.points, closed: p.closed));
      case CircleEntity c:
        _add(CadCircle(layer, c.center, c.radius));
      case ArcEntity a:
        final (s, en) = arcDegrees(a.startRad, a.sweepRad);
        _add(CadArc(layer, a.center, a.radius, s, en));
      case SplineEntity sp:
        final s = catmullRomSpline(sp.points, closed: sp.closed);
        if (s != null) _add(CadSpline(layer, control: s.control, knots: s.knots, fit: s.fit, closed: s.closed, startTangent: s.startTangent, endTangent: s.endTangent));
      case HatchEntity h:
        _hatch(h, layer);
      case SymbolEntity sy:
        _add(CadInsert(layer, _symbol(sy.kind), sy.position, scale: sy.size, rotationDeg: sy.rotationDeg));
      case TextEntity tx:
        if (tx.text.contains('\n')) {
          _add(CadMText(layer, tx.position, tx.text, tx.height, rotationDeg: tx.rotationDeg));
        } else {
          _add(CadText(layer, tx.position, tx.text, tx.height, rotationDeg: tx.rotationDeg));
        }
      case DimensionEntity d:
        _aligned(d, layer);
      case AngularDimensionEntity ad:
        // the rays the app draws with the angle, then the dimension itself
        _add(CadPolyline(layer, [ad.a, ad.vertex, ad.b]));
        _angular(ad, layer);
      case RadialDimensionEntity rd:
        _radial(rd, layer);
      case OrdinateDimensionEntity od:
        _ordinate(od, layer);
      case LeaderEntity le:
        if (le.points.length >= 2) _add(CadLeader(layer, le.points, style: dimStyle));
        if (le.text.trim().isNotEmpty) _add(CadMText(layer, le.textPosition + Pt(0.3 * le.height, 0), le.text, le.height));
      case ImageEntity im:
        _add(CadPolyline(layer, im.corners, closed: true));
      case ContourEntity c:
        _add(CadPolyline(layer, c.points, elevation: c.elevation));
        if (c.points.isNotEmpty) _add(CadText(layer, c.points.first, fmt(c.elevation, 1), 0.5, z: c.elevation));
      case BreaklineEntity b:
        _add(CadPolyline(layer, b.points));
        for (var i = 0; i < b.points.length; i++) {
          if (b.elevationOf(i).isFinite) _add(CadPoint(layer, b.points[i], z: b.elevationOf(i)));
        }
      case CommentEntity n:
        _add(CadCircle(layer, n.position, 0.6));
        final note = [if (n.author.isNotEmpty) '${n.author}:', n.text].join(' ').trim();
        if (note.isNotEmpty) _add(CadMText(layer, n.position + const Pt(0.9, 0), note, 0.6));
      case RevisionCloudEntity r:
        _cloud(r, layer);
      case SpotHeightEntity s:
        _add(CadPoint(layer, s.position, z: s.elevation));
        _add(CadText(layer, s.position, fmt(s.elevation, 1), 0.5, z: s.elevation));
      case PipeEntity p:
        _add(CadPolyline(layer, p.points));
        final spec = cat.pipe(p.pipeSpecId);
        if (spec != null && p.points.length >= 2) _add(CadText(labels, Pt.lerp(p.points[0], p.points[1], 0.5), spec.name, 0.6));
      case SpraylineEntity s:
        _add(CadPolyline(layer, s.points));
        final (item, nozzle) = _outletItem(s.outletSpecId, s.nozzleId);
        final outlets = _layer(Layers.outlets);
        for (final o in s.outletPositions()) {
          _add(_insert(outletBlock, outlets, o, {'NAME': s.name, 'ITEM': item, 'NOZZLE': nozzle}, scale: 0.6));
        }
      case TapeEntity tp:
        _add(CadPolyline(layer, tp.points));
      case OutletEntity o:
        final (item, nozzle) = _outletItem(o.outletSpecId, o.nozzleId);
        _add(_insert(outletBlock, layer, o.position, {'NAME': o.name, 'ITEM': item, 'NOZZLE': nozzle}, rotationDeg: o.orientationDeg));
      case ControlValveEntity v:
        _add(_insert(valveBlock, layer, v.position, {'NAME': v.name, 'ZONE': v.zoneName, 'ITEM': cat.valve(v.valveSpecId)?.name ?? ''}, rotationDeg: v.orientationDeg));
        if (v.zoneName.isNotEmpty) _add(CadText(labels, v.position + const Pt(1.2, 0), v.zoneName, 0.8));
      case WaterSupplyEntity s:
        _add(_insert(supplyBlock, layer, s.position, {'NAME': s.name}));
        if (s.name.isNotEmpty) _add(CadText(labels, s.position + const Pt(1.8, 0), s.name, 0.8));
      case PumpEntity p:
        _add(_insert(pumpBlock, layer, p.position, {'NAME': p.name, 'ITEM': cat.pump(p.pumpSpecId)?.name ?? ''}, rotationDeg: p.orientationDeg));
      case MiscHydraulicEntity m:
        _add(_insert(miscBlock, layer, m.position, {'NAME': m.name, 'ITEM': cat.valve(m.valveSpecId)?.name ?? ''}, rotationDeg: m.orientationDeg));
      case JunctionEntity j:
        _add(_insert(junctionBlock, layer, j.position, {'NAME': j.name}));
      case AreaEntity a:
        _add(CadPolyline(layer, a.points, closed: true));
      case PivotEntity pv:
        _pivot(pv, layer, labels);
      case ControllerEntity k:
        _add(_insert(controllerBlock, layer, k.position, {'NAME': k.name, 'STATIONS': '${k.stations}'}));
        if (k.name.isNotEmpty) _add(CadText(labels, k.position + const Pt(1.3, 0), k.name, 0.8));
      case WireEntity w:
        _add(CadPolyline(layer, w.points));
      // 1.6.0 AGB: the strip of a traveller lane with its axis, the field of a furrow set with its head line
      case TravellerEntity tv:
        _add(CadPolyline(layer, tv.outline(), closed: true));
        _add(CadPolyline(layer, [tv.start, tv.end]));
        if (tv.name.isNotEmpty) _add(CadText(labels, tv.start + const Pt(1, 1), tv.name, 0.8));
      case FurrowEntity fs when fs.points.length >= 2:
        _add(CadPolyline(layer, fs.outline(), closed: true));
        _add(CadPolyline(layer, fs.points));
        if (fs.name.isNotEmpty) _add(CadText(labels, fs.points.first + const Pt(1, 1), fs.name, 0.8));
      // 1.6.0 CAD: a reference to a user block is an INSERT of it with its
      // attributes; a mirrored one (an INSERT of one scale only) or one whose
      // block is missing goes in as what it draws
      case BlockRefEntity r:
        final name = _userBlocks[r.blockName];
        final d = r.definition;
        if (name == null || d == null || r.mirrored) {
          for (final x in r.expanded()) {
            _entity(x);
          }
        } else {
          final t = r.placement;
          _add(
            CadInsert(
              layer,
              name,
              r.position,
              scale: r.scale,
              rotationDeg: r.rotationDeg,
              attribs: [
                for (final a in d.attributes)
                  CadAttrib(a.tag, r.attribute(a.tag), t.apply(a.position), a.height * r.scale, rotationDeg: r.rotationDeg + a.rotationDeg, invisible: !a.visible),
              ],
            ),
          );
        }
      default:
        break;
    }
  }

  (String, String) _outletItem(String specId, String? nozzleId) {
    final spec = project.catalog.outlet(specId);
    return (spec?.name ?? '', spec?.nozzle(nozzleId)?.name ?? '');
  }

  void _hatch(HatchEntity h, String layer) {
    if (h.points.length < 3) return;
    final loop = CadLoop(h.points);
    if (h.solid) {
      _add(CadHatch(layer, [loop], solid: true));
    } else {
      // ANSI31 is one family of 45° lines 3.175 apart: turned and scaled it
      // gives the hatch's lines at their angle and spacing
      final sp = h.spacing > 0 ? h.spacing : 1.0;
      final a = degToRad(h.angleDeg);
      _add(
        CadHatch(
          layer,
          [loop],
          pattern: 'ANSI31',
          patternAngleDeg: _deg360(h.angleDeg - 45),
          patternScale: sp / 3.175,
          lines: [CadHatchLine(_deg360(h.angleDeg), Pt.zero, Pt.polar(sp, a + math.pi / 2))],
        ),
      );
    }
    // the outline the app draws around it
    _add(CadPolyline(layer, h.points, closed: true));
  }

  /// Revision cloud: the chord points of its arcs with a bulge of 0.7 (a
  /// sagitta of 0.35 chord, as the app's scallops), turned outwards.
  void _cloud(RevisionCloudEntity r, String layer) {
    if (r.points.length >= 3) {
      final ring = [...r.points, r.points.first];
      // a positive bulge bulges to the right of the travel: outwards on a counter-clockwise ring
      final out = polygonArea(r.points) > 0 ? 0.7 : -0.7;
      final step = r.effectiveArc;
      final pts = <Pt>[];
      for (var i = 1; i < ring.length; i++) {
        final a = ring[i - 1], b = ring[i];
        final len = a.distanceTo(b);
        if (len < 1e-9) continue;
        final n = math.max(1, (len / step).round());
        for (var k = 0; k < n; k++) {
          pts.add(Pt.lerp(a, b, k / n));
        }
      }
      if (pts.length >= 2) _add(CadPolyline(layer, pts, bulges: List.filled(pts.length, out), closed: true));
    } else if (r.points.length == 2) {
      _add(CadPolyline(layer, r.points));
    }
    final note = [if (r.revision.isNotEmpty) r.revision, r.description].where((x) => x.isNotEmpty).join(' — ');
    if (r.points.isNotEmpty && note.isNotEmpty) _add(CadText(layer, Pt(r.bounds.maxX, r.bounds.maxY), note, 0.8));
  }

  void _pivot(PivotEntity pv, String layer, String labels) {
    final sweep = degToRad(pv.sectorDeg.clamp(1.0, 360.0));
    if (pv.kind != PivotKind.linear && sweep >= 2 * math.pi - 1e-9) {
      _add(CadCircle(layer, pv.center, pv.irrigatedRadius));
    } else if (pv.kind != PivotKind.linear) {
      // sector: centre, then the arc as one bulge (tan of a quarter of its angle)
      final start = pv.angleRad - sweep / 2;
      _add(
        CadPolyline(layer, [pv.center, pv.center + Pt.polar(pv.irrigatedRadius, start), pv.center + Pt.polar(pv.irrigatedRadius, start + sweep)], bulges: [0, math.tan(sweep / 4), 0], closed: true),
      );
    } else {
      _add(CadPolyline(layer, pv.outline(), closed: true));
    }
    _add(CadLine(layer, pv.center, pv.endPoint));
    _add(_insert(pivotBlock, layer, pv.center, {'NAME': pv.name, 'ZONE': pv.zoneName}));
    for (final tw in pv.towerPositions()) {
      _add(_insert(towerBlock, layer, tw, const {}, rotationDeg: pv.angleDeg));
    }
    if (pv.name.isNotEmpty) _add(CadText(labels, pv.center + const Pt(2, 1.5), pv.name, 1.0));
  }

  // ------------------------------------------------------------------ blocks

  /// Reference to the hydraulic block [name] (defined on first use) with
  /// the attribute [values] placed like the block's definitions.
  CadInsert _insert(String name, String layer, Pt at, Map<String, String> values, {double scale = 1, double rotationDeg = 0}) {
    final blk = _blocks.putIfAbsent(name, () => _hydraulicBlock(name, values.keys.toList()));
    final r = degToRad(rotationDeg);
    final attribs = [for (final a in blk.attdefs) CadAttrib(a.tag, values[a.tag] ?? '', at + (a.position * scale).rotate(r), a.height * scale, rotationDeg: rotationDeg, invisible: a.invisible)];
    return CadInsert(layer, name, at, scale: scale, rotationDeg: rotationDeg, attribs: attribs);
  }

  /// Small symbol blocks in metres, drawn on layer 0 so they take the colour
  /// of the layer they are inserted on; [tags] become invisible attributes.
  CadBlock _hydraulicBlock(String name, List<String> tags) {
    List<Pt> square(double r) => [Pt(-r, -r), Pt(r, -r), Pt(r, r), Pt(-r, r)];
    CadLoop disc(double r) => CadLoop([Pt(r, 0), Pt(-r, 0)], const [1, 1]);
    CadText letter(String s, double h) => CadText('0', Pt.zero, s, h, hAlign: 1, vAlign: 2);
    final (ents, size) = switch (name) {
      outletBlock => (
        [
          const CadCircle('0', Pt.zero, 0.5),
          CadHatch('0', [disc(0.5)], solid: true),
        ],
        0.5,
      ),
      valveBlock => (
        [
          const CadPolyline('0', [Pt(-1, -0.7), Pt(1, 0.7), Pt(1, -0.7), Pt(-1, 0.7)], closed: true),
          CadSolid.triangle('0', const Pt(-1, -0.7), Pt.zero, const Pt(-1, 0.7)),
          CadSolid.triangle('0', const Pt(1, 0.7), Pt.zero, const Pt(1, -0.7)),
        ],
        1.0,
      ),
      supplyBlock => ([CadPolyline('0', square(1.5), closed: true), letter('W', 1.5)], 1.5),
      pumpBlock => ([const CadCircle('0', Pt.zero, 1), letter('P', 1)], 1.0),
      miscBlock => (
        [
          const CadPolyline('0', [Pt(0, 0.8), Pt(0.8, 0), Pt(0, -0.8), Pt(-0.8, 0)], closed: true),
          const CadHatch('0', [
            CadLoop([Pt(0, 0.8), Pt(0.8, 0), Pt(0, -0.8), Pt(-0.8, 0)]),
          ], solid: true),
        ],
        0.8,
      ),
      junctionBlock => (
        [
          const CadCircle('0', Pt.zero, 0.25),
          CadHatch('0', [disc(0.25)], solid: true),
        ],
        0.25,
      ),
      controllerBlock => ([CadPolyline('0', square(1), closed: true), letter('C', 1)], 1.0),
      pivotBlock => (
        [
          const CadCircle('0', Pt.zero, 1.5),
          CadHatch('0', [disc(1.5)], solid: true),
        ],
        1.5,
      ),
      _ => (
        [
          CadPolyline('0', square(0.8), closed: true),
          CadHatch('0', [CadLoop(square(0.8))], solid: true),
        ],
        0.8,
      ),
    };
    return CadBlock(name, ents, attdefs: [for (var i = 0; i < tags.length; i++) CadAttrib(tags[i], '', Pt(size * 1.3, size * 0.3 - i * 0.7), 0.5, prompt: tags[i])]);
  }

  /// Block of a symbol kind: the app's glyph at size 1, its circles as
  /// circles.
  String _symbol(SymbolKind k) {
    final name = symbolBlock(k);
    _blocks.putIfAbsent(name, () {
      final ents = <CadEntity>[];
      for (final st in SymbolEntity(id: '', position: Pt.zero, kind: k, size: 1).strokes()) {
        final c = _asCircle(st);
        if (c != null) {
          ents.add(CadCircle('0', c.$1, c.$2));
        } else if (st.length >= 2) {
          final closed = st.length > 3 && st.first.distanceTo(st.last) < 1e-9;
          ents.add(CadPolyline('0', closed ? st.sublist(0, st.length - 1) : st, closed: closed));
        }
      }
      return CadBlock(name, ents);
    });
    return name;
  }

  /// A closed stroke whose points all lie on one circle, as (centre, radius).
  static (Pt, double)? _asCircle(List<Pt> st) {
    if (st.length < 13 || st.first.distanceTo(st.last) > 1e-9) return null;
    final ring = st.sublist(0, st.length - 1);
    final c = ring.fold(Pt.zero, (s, p) => s + p) / ring.length.toDouble();
    final r = c.distanceTo(ring.first);
    if (r < 1e-9 || ring.any((p) => (p.distanceTo(c) - r).abs() > 1e-6 * r)) return null;
    return (c, r);
  }

  // ------------------------------------------------------------------ dimensions

  /// Anonymous block of a dimension (`*D1`, `*D2`…) holding [ents].
  String _dimBlock(List<CadEntity> ents) {
    final name = '*D${++_dims}';
    _blocks[name] = CadBlock(name, ents);
    return name;
  }

  String _length(double metres, CadDimStyle st) {
    final v = fmt(metres * st.lengthFactor, st.decimals);
    return st.suffix.isEmpty ? v : st.suffix.replaceAll('<>', v);
  }

  /// Closed filled arrowhead with its tip at [tip], pointing along [dir].
  static CadSolid _arrow(Pt tip, Pt dir, double size) {
    final n = dir.perpendicular * (size / 6);
    return CadSolid.triangle('0', tip, tip - dir * size + n, tip - dir * size - n, color: 0);
  }

  /// Text angle (degrees) that reads left to right or bottom to top.
  static double _readable(double deg) {
    var a = deg % 360;
    if (a > 180) a -= 360;
    if (a > 90 + 1e-9) a -= 180;
    if (a <= -90 + 1e-9) a += 180;
    return a;
  }

  static List<CadEntity> _defPoints(List<Pt> pts) => [for (final p in pts) CadPoint(defpoints, p)];

  void _aligned(DimensionEntity d, String layer) {
    final st = _alignedStyle;
    final len = d.length;
    if (len < 1e-9) return;
    final u = (d.b - d.a) / len, nrm = u.perpendicular;
    final n = nrm * d.offset;
    final p1 = d.a + n, p2 = d.b + n;
    final side = d.offset >= 0 ? nrm : -nrm;
    final ents = <CadEntity>[];
    if (d.offset.abs() > st.offset) {
      ents.add(CadLine('0', d.a + side * st.offset, p1 + side * st.beyond, color: 0));
      ents.add(CadLine('0', d.b + side * st.offset, p2 + side * st.beyond, color: 0));
    }
    ents.add(CadLine('0', p1, p2, color: 0));
    final asz = st.arrowLength;
    if (len >= 2.5 * asz) {
      ents.addAll([_arrow(p1, -u, asz), _arrow(p2, u, asz)]);
    } else {
      // no room inside: arrows outside, pointing in, on short line extensions
      ents.addAll([_arrow(p1, u, asz), _arrow(p2, -u, asz), CadLine('0', p1, p1 - u * (2 * asz), color: 0), CadLine('0', p2, p2 + u * (2 * asz), color: 0)]);
    }
    final ang = _readable(radToDeg(u.angle));
    final up = Pt.polar(1, degToRad(ang) + math.pi / 2);
    final mid = Pt.lerp(p1, p2, 0.5) + up * (st.textGap + st.textSize / 2);
    ents.add(CadMText('0', mid, _length(len, st), st.textSize, color: 0, attachment: 5, rotationDeg: ang));
    ents.addAll(_defPoints([p2, d.a, d.b]));
    _add(CadDimension(layer, CadDimKind.aligned, block: _dimBlock(ents), style: st.name, defPoint: p2, textMid: mid, p13: d.a, p14: d.b, measurement: len));
  }

  void _angular(AngularDimensionEntity ad, String layer) {
    final st = _horizontalStyle;
    final v = ad.vertex, r = ad.radius, a0 = ad.startRad, sw = ad.sweepRad;
    if (r <= 0 || sw <= 1e-9 || ad.a.distanceTo(v) < 1e-9 || ad.b.distanceTo(v) < 1e-9) return;
    final ents = <CadEntity>[];
    // extension lines only where the arc lies beyond the defining points
    for (final (p, ang) in [(ad.a, a0), (ad.b, a0 + sw)]) {
      final dir = Pt.polar(1, ang);
      if (r > p.distanceTo(v) + st.offset) ents.add(CadLine('0', p + dir * st.offset, v + dir * (r + st.beyond), color: 0));
    }
    ents.add(CadArc('0', v, r, radToDeg(a0), radToDeg(a0 + sw), color: 0));
    final asz = st.arrowLength;
    if (r * sw >= 2.5 * asz) {
      // tangent to the arc, pointing out of it at both ends
      ents.add(_arrow(v + Pt.polar(r, a0), -Pt.polar(1, a0 + math.pi / 2), asz));
      ents.add(_arrow(v + Pt.polar(r, a0 + sw), Pt.polar(1, a0 + sw + math.pi / 2), asz));
    }
    final arcPoint = v + Pt.polar(r, a0 + sw / 2);
    final tp = ad.textPoint;
    ents.add(CadMText('0', tp, '${fmt(ad.angleDeg, st.angleDecimals)}°', st.textSize, color: 0, attachment: 5));
    ents.addAll(_defPoints([arcPoint, ad.a, ad.b, v]));
    _add(CadDimension(layer, CadDimKind.angular, block: _dimBlock(ents), style: st.name, defPoint: arcPoint, textMid: tp, p13: ad.a, p14: ad.b, p15: v, measurement: sw, userTextPosition: true));
  }

  void _radial(RadialDimensionEntity rd, String layer) {
    final st = _horizontalStyle;
    final c = rd.center, p = rd.point, rad = rd.radius;
    if (rad < 1e-9) return;
    final dir = (p - c) / rad;
    final asz = st.arrowLength;
    final lift = Pt(0, st.textGap + st.textSize / 2);
    final ents = <CadEntity>[];
    if (rd.diameter) {
      final s = rd.start;
      ents.addAll([CadLine('0', s, p, color: 0), _arrow(p, dir, asz), _arrow(s, -dir, asz)]);
      final mid = c + lift;
      ents.add(CadMText('0', mid, 'Ø${_length(2 * rad, st)}', st.textSize, color: 0, attachment: 5));
      ents.addAll(_defPoints([s, p]));
      _add(CadDimension(layer, CadDimKind.diameter, block: _dimBlock(ents), style: st.name, defPoint: s, textMid: mid, p15: p, measurement: 2 * rad, userTextPosition: true));
    } else {
      ents.addAll([CadLine('0', c, p, color: 0), _arrow(p, dir, asz)]);
      final mid = Pt.lerp(c, p, 0.5) + lift;
      ents.add(CadMText('0', mid, 'R${_length(rad, st)}', st.textSize, color: 0, attachment: 5));
      ents.addAll(_defPoints([c, p]));
      _add(CadDimension(layer, CadDimKind.radius, block: _dimBlock(ents), style: st.name, defPoint: c, textMid: mid, p15: p, measurement: rad, userTextPosition: true));
    }
  }

  void _ordinate(OrdinateDimensionEntity od, String layer) {
    final st = _horizontalStyle;
    final lead = od.leader;
    if (od.point.distanceTo(od.leaderEnd) < 1e-9) return;
    // the leader starts DIMEXO away from the feature, as CAD programs draw it
    final first = lead[1].distanceTo(lead[0]) > st.offset ? lead[0] + (lead[1] - lead[0]).normalized * st.offset : lead[0];
    final axis = od.xAxis ? 'X' : 'Y';
    final mid = od.xAxis ? od.leaderEnd + Pt(0, st.textGap + st.textSize / 2) : od.leaderEnd;
    final ents = <CadEntity>[
      CadPolyline('0', [first, ...lead.skip(1)], color: 0),
      CadMText('0', mid, '$axis ${_length(od.value, st)}', st.textSize, color: 0, attachment: 5),
      ..._defPoints([od.origin, od.point, od.leaderEnd]),
    ];
    _add(
      CadDimension(
        layer,
        CadDimKind.ordinate,
        block: _dimBlock(ents),
        style: st.name,
        defPoint: od.origin,
        textMid: mid,
        p13: od.point,
        p14: od.leaderEnd,
        measurement: od.value,
        text: '$axis <>',
        userTextPosition: true,
        xOrdinate: od.xAxis,
      ),
    );
  }
}

double _deg360(double deg) {
  final a = deg % 360;
  return a < 0 ? a + 360 : a;
}

/// Start and end angles (degrees, counter-clockwise) of an arc that starts
/// at [startRad] and sweeps [sweepRad] (negative = clockwise).
(double, double) arcDegrees(double startRad, double sweepRad) {
  final s = sweepRad >= 0 ? startRad : startRad + sweepRad;
  return (radToDeg(s), radToDeg(s + sweepRad.abs()));
}

/// The app's centripetal Catmull-Rom curve through [input] (see
/// `catmullRom`) as an exact cubic B-spline: one Bézier span per pair of fit
/// points (the tangents of the Barry–Goldman form at its ends), knots of
/// multiplicity three at the joints, spaced by the chord lengths. Repeated
/// points are dropped first; null with fewer than two points.
({List<Pt> control, List<double> knots, List<Pt> fit, bool closed, Pt? startTangent, Pt? endTangent})? catmullRomSpline(List<Pt> input, {bool closed = false}) {
  final pts = <Pt>[];
  for (final p in input) {
    if (pts.isEmpty || pts.last.distanceTo(p) > 1e-9) pts.add(p);
  }
  if (pts.length > 2 && pts.first.distanceTo(pts.last) <= 1e-9) pts.removeLast();
  final n = pts.length;
  if (n < 2) return null;
  final isClosed = closed && n >= 3;
  Pt at(int i) {
    if (isClosed) return pts[(i % n + n) % n];
    if (i < 0) return pts[0] * 2 - pts[1];
    if (i >= n) return pts[n - 1] * 2 - pts[n - 2];
    return pts[i];
  }

  final control = <Pt>[pts.first];
  final knots = <double>[0, 0, 0, 0];
  var t = 0.0;
  final spans = isClosed ? n : n - 1;
  for (var i = 0; i < spans; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    final d01 = math.sqrt(p0.distanceTo(p1)), d12 = math.sqrt(p1.distanceTo(p2)), d23 = math.sqrt(p2.distanceTo(p3));
    Pt b1 = Pt.lerp(p1, p2, 1 / 3), b2 = Pt.lerp(p1, p2, 2 / 3);
    if (n > 2 && d01 > 1e-9 && d12 > 1e-9 && d23 > 1e-9) {
      final m1 = ((p1 - p0) / d01 - (p2 - p0) / (d01 + d12) + (p2 - p1) / d12) * d12;
      final m2 = ((p2 - p1) / d12 - (p3 - p1) / (d12 + d23) + (p3 - p2) / d23) * d12;
      b1 = p1 + m1 / 3;
      b2 = p2 - m2 / 3;
    }
    control.addAll([b1, b2, p2]);
    t += p1.distanceTo(p2);
    knots.addAll(i == spans - 1 ? [t, t, t, t] : [t, t, t]);
  }
  Pt? unit(Pt v) => v.length < 1e-12 ? null : v / v.length;
  return (
    control: control,
    knots: knots,
    fit: pts,
    closed: isClosed,
    startTangent: isClosed ? null : unit(control[1] - control[0]),
    endTangent: isClosed ? null : unit(control.last - control[control.length - 2]),
  );
}
