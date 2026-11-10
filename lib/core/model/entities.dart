/// Drawing and hydraulic entities of a design.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../design/pivot.dart' show PivotKind;
// 1.6.0 AGB
import '../design/traveller.dart' show WindClass;
// 1.6.0 CAD: the references to user blocks (entities_block_ref.dart)
import 'blocks.dart' show BlockAttributeDef, BlockDefinition;
import 'geometry.dart';
import 'pivot_machine.dart';
import 'pump_station.dart';
import 'read_report.dart';
import 'reservoir.dart';
import 'valve_pilot.dart';

export 'pivot_machine.dart';
// 1.6.0 MOT: the pumps of a pump station, the pilot of a valve, a reservoir
export 'pump_station.dart';
export 'reservoir.dart';
export 'valve_pilot.dart';

// 1.6.0 AGB: travelling-gun lanes and furrow sets
part 'field_machines.dart';

// 1.6.0 CAD
part 'entities_block_ref.dart';

enum HydraulicScope { zone, mainline }

enum EntityType {
  line,
  polyline,
  circle,
  arc,
  spline,
  hatch,
  symbol,
  text,
  dimension,
  angularDimension,
  radialDimension,
  leader,
  image,
  contour,
  spotHeight,
  pipe,
  sprayline,
  tape,
  outlet,
  controlValve,
  waterSupply,
  pump,
  misc,
  junction,
  area,
  pivot,
  controller,
  wire,
  ordinateDimension,
  comment,
  revisionCloud,
  breakline,
  // 1.6.0 AGB
  traveller,
  furrows,
  // 1.6.0 CAD: a reference to a user block (entities_block_ref.dart)
  blockRef,
}

/// Default layer names.
class Layers {
  static const drawing = 'DRAWING';
  static const text = 'TEXT';
  static const dimensions = 'DIMENSIONS';
  static const contours = 'CONTOURS';
  static const breaklines = 'BREAKLINES';
  static const spotHeights = 'SPOT_HEIGHTS';
  static const dem = 'DEM';
  static const zonePipes = 'ZONE_PIPES';
  static const mainlinePipes = 'MAINLINE_PIPES';
  static const spraylines = 'SPRAYLINES';
  static const tapes = 'TAPES';
  static const outlets = 'OUTLETS';
  static const wettedRadii = 'WETTED_RADII';
  static const controlValves = 'CONTROL_VALVES';
  static const waterSupply = 'WATER_SUPPLY';
  static const pumps = 'PUMPS';
  static const misc = 'MISC_HYDRAULIC';
  static const junctions = 'JUNCTIONS';
  static const areas = 'AREAS';
  static const labels = 'LABELS';
  static const images = 'IMAGES';
  static const hatches = 'HATCHES';
  static const symbols = 'SYMBOLS';
  static const pivots = 'PIVOTS';
  static const controllers = 'CONTROLLERS';
  static const wires = 'WIRES';
  static const comments = 'COMMENTS';
  static const revisions = 'REVISIONS';
  // 1.6.0 AGB: made with the first lane or furrow set (not in [all], so
  // the files of projects without them do not change)
  static const travellers = 'TRAVELLERS';
  static const surface = 'SURFACE_IRRIGATION';

  static const all = [
    images,
    drawing,
    hatches,
    symbols,
    text,
    dimensions,
    contours,
    breaklines,
    spotHeights,
    dem,
    zonePipes,
    mainlinePipes,
    spraylines,
    tapes,
    outlets,
    wettedRadii,
    controlValves,
    waterSupply,
    pumps,
    misc,
    junctions,
    pivots,
    wires,
    controllers,
    areas,
    labels,
    revisions,
    comments,
  ];

  static const defaultColors = <String, int>{
    drawing: 0xFFB0BEC5,
    text: 0xFFECEFF1,
    dimensions: 0xFF90A4AE,
    contours: 0xFF8D6E63,
    breaklines: 0xFFFF8A65,
    spotHeights: 0xFFA1887F,
    dem: 0xFF7E8A97,
    zonePipes: 0xFF42A5F5,
    mainlinePipes: 0xFF1E88E5,
    spraylines: 0xFF26C6DA,
    tapes: 0xFF66BB6A,
    outlets: 0xFF29B6F6,
    wettedRadii: 0x5529B6F6,
    controlValves: 0xFFFFA726,
    waterSupply: 0xFF7E57C2,
    pumps: 0xFFEF5350,
    misc: 0xFFFFCA28,
    junctions: 0xFF78909C,
    areas: 0x33AED581,
    labels: 0xFFCFD8DC,
    images: 0xFFFFFFFF,
    hatches: 0xFF78909C,
    symbols: 0xFFB0BEC5,
    pivots: 0xFF4DB6AC,
    controllers: 0xFFFF7043,
    wires: 0xFFFFEE58,
    comments: 0xFFFFB300,
    revisions: 0xFFE53935,
    // 1.6.0 AGB
    travellers: 0xFF9CCC65,
    surface: 0xFF4FC3F7,
  };
}

sealed class Entity {
  Entity({required this.id, required this.layer, this.name = ''});
  final String id;
  String layer;
  String name;

  EntityType get type;
  Bounds get bounds;
  Entity clone({String? newId});
  Entity translated(Pt d);

  /// Copy with every point mapped through [t] (rotation, mirror, scale…).
  Entity transformed(Affine t);

  /// Editable points shown as grips when the entity is selected.
  List<Pt> get grips;

  /// Moves grip [index] to [p] (in place).
  void setGrip(int index, Pt p);

  /// Pick distance in world units.
  double distanceTo(Pt p);

  Map<String, dynamic> toJson();

  /// Fields this version does not know (written by a newer one), kept as
  /// read and written back unchanged; null when there are none.
  Map<String, dynamic>? extra;

  Map<String, dynamic> _base() => {...?extra, 'type': type.name, 'id': id, 'layer': layer, if (name.isNotEmpty) 'name': name};

  /// Reads an entity. Vertices without valid coordinates are dropped and
  /// options this version does not know take their default (both noted in
  /// [report]); fields it does not know are kept in [extra]. Throws a
  /// [FormatException] when the item cannot be read at all: an unknown
  /// type, a point item without a position, a terrain item without an
  /// elevation (never taken as 0 m). A missing id comes back empty (the
  /// project gives it a new one).
  static Entity fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    final e = _read(j, report);
    e.extra = j.unread;
    return e;
  }

  static Entity _read(KeyLog j, ProjectReadReport? report) {
    final typeName = j['type'];
    final type = typeName is String ? EntityType.values.asNameMap()[typeName] : null;
    if (type == null) throw FormatException('entity_type', typeName);
    final rawId = j['id'];
    final id = rawId is String ? rawId : (rawId is num ? '$rawId' : '');
    final rawLayer = j['layer'];
    final layer = rawLayer is String && rawLayer.isNotEmpty ? rawLayer : Layers.drawing;
    final rawName = j['name'];
    final name = rawName is String ? rawName : '';
    List<Pt> pts() {
      final raw = j['pts'];
      final out = <Pt>[];
      for (final p in raw is List ? raw : const []) {
        final q = Pt.tryFromList(p);
        if (q != null) {
          out.add(q);
        } else if (report != null) {
          report.droppedVertices++;
        }
      }
      return out;
    }

    // 1.6.0 MOD: closed rings of vertices (the holes of an area); a ring left
    // with fewer than three valid vertices is dropped
    List<List<Pt>> rings(String k) {
      final raw = j[k];
      final out = <List<Pt>>[];
      for (final ring in raw is List ? raw : const []) {
        final ringPts = <Pt>[];
        for (final p in ring is List ? ring : const []) {
          final q = Pt.tryFromList(p);
          if (q != null) {
            ringPts.add(q);
          } else if (report != null) {
            report.droppedVertices++;
          }
        }
        if (ringPts.length >= 3) out.add(ringPts);
      }
      return out;
    }

    Pt pt(String k) => Pt.tryFromList(j[k]) ?? (throw FormatException('entity_point', k));
    Pt pos() => pt('p');
    double d(String k, [double def = 0]) {
      final v = j[k];
      return v is num && v.isFinite ? v.toDouble() : def;
    }

    // an unknown elevation is no datum: never 0 m
    double z() {
      final v = j['z'];
      if (v is num && v.isFinite) return v.toDouble();
      throw const FormatException('entity_elevation');
    }

    HydraulicScope scope(HydraulicScope def) => enumByName(HydraulicScope.values, j['scope'], def, report: report, key: 'scope');
    switch (type) {
      case EntityType.line:
        return LineEntity(id: id, layer: layer, name: name, a: pt('a'), b: pt('b'));
      case EntityType.polyline:
        return PolylineEntity(id: id, layer: layer, name: name, points: pts(), closed: j['closed'] as bool? ?? false);
      case EntityType.circle:
        return CircleEntity(id: id, layer: layer, name: name, center: pos(), radius: d('r'));
      case EntityType.arc:
        return ArcEntity(id: id, layer: layer, name: name, center: pos(), radius: d('r'), startRad: d('s'), sweepRad: d('w'));
      case EntityType.spline:
        return SplineEntity(id: id, layer: layer, name: name, points: pts(), closed: j['closed'] as bool? ?? false);
      case EntityType.hatch:
        return HatchEntity(id: id, layer: layer, name: name, points: pts(), angleDeg: d('ang', 45), spacing: d('sp', 1), solid: j['solid'] as bool? ?? false);
      case EntityType.symbol:
        return SymbolEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          kind: enumByName(SymbolKind.values, j['kind'], SymbolKind.tree, report: report, key: 'kind'),
          size: d('size', 2),
          rotationDeg: d('rot'),
          mirrored: j['mir'] as bool? ?? false,
        );
      case EntityType.text:
        return TextEntity(id: id, layer: layer, name: name, position: pos(), text: j['text'] as String? ?? '', height: d('h', 1), rotationDeg: d('rot'));
      case EntityType.dimension:
        return DimensionEntity(id: id, layer: layer, name: name, a: pt('a'), b: pt('b'), offset: d('off', 1));
      case EntityType.angularDimension:
        return AngularDimensionEntity(id: id, layer: layer, name: name, vertex: pt('v'), a: pt('a'), b: pt('b'), radius: d('r', 2));
      case EntityType.radialDimension:
        return RadialDimensionEntity(id: id, layer: layer, name: name, center: pt('c'), point: pos(), diameter: j['dia'] as bool? ?? false);
      case EntityType.leader:
        return LeaderEntity(id: id, layer: layer, name: name, points: pts(), text: j['text'] as String? ?? '', height: d('h', 1));
      case EntityType.image:
        return ImageEntity(
          id: id,
          layer: layer,
          name: name,
          origin: pos(),
          width: d('w', 1),
          height: d('h', 1),
          rotationDeg: d('rot'),
          opacity: d('op', 1),
          mime: j['mime'] as String? ?? 'image/png',
          data: j['data'] != null ? base64Decode(j['data'] as String) : null,
          source: j['src'] as String? ?? '',
        );
      case EntityType.contour:
        return ContourEntity(id: id, layer: layer, name: name, points: pts(), elevation: z(), derived: j['gen'] as bool? ?? false);
      case EntityType.breakline:
        return BreaklineEntity(id: id, layer: layer, name: name, points: pts(), elevations: [for (final z in (j['zs'] as List?) ?? const []) z is num ? z.toDouble() : double.nan]);
      case EntityType.spotHeight:
        return SpotHeightEntity(id: id, layer: layer, name: name, position: pos(), elevation: z());
      case EntityType.pipe:
        return PipeEntity(
          id: id,
          layer: layer,
          name: name,
          points: pts(),
          // a pipe without its scope: the one its layer tells
          scope: scope(layer == Layers.mainlinePipes ? HydraulicScope.mainline : HydraulicScope.zone),
          pipeSpecId: j['spec'] as String?,
          computerSized: j['auto'] as bool? ?? true,
          depth: d('depth'),
        );
      case EntityType.sprayline:
        return SpraylineEntity(
          id: id,
          layer: layer,
          name: name,
          points: pts(),
          pipeSpecId: j['spec'] as String?,
          computerSized: j['auto'] as bool? ?? true,
          outletSpecId: j['outlet'] as String? ?? '',
          nozzleId: j['nozzle'] as String?,
          headM: d('head', 20),
          spacing: d('sp', 5),
          offset: d('off', 0),
          arcDeg: d('arc', 360),
          riserHeight: d('riser'),
          depth: d('depth'),
        );
      case EntityType.tape:
        return TapeEntity(
          id: id,
          layer: layer,
          name: name,
          points: pts(),
          tapeSpecId: j['spec'] as String? ?? '',
          inletHeadM: d('inlet', 10),
          regulated: j['reg'] as bool? ?? false,
          submainMinHeadM: d('submin', 0),
          depth: d('depth'),
          flushingFlow: d('flush'),
        );
      case EntityType.outlet:
        return OutletEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          scope: scope(HydraulicScope.zone),
          outletSpecId: j['outlet'] as String? ?? '',
          nozzleId: j['nozzle'] as String?,
          headM: d('head', 20),
          arcDeg: d('arc', 360),
          orientationDeg: d('rot'),
          riserHeight: d('riser'),
          zoneName: j['zone'] as String? ?? '',
        );
      case EntityType.controlValve:
        return ControlValveEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          valveSpecId: j['spec'] as String?,
          zoneName: j['zone'] as String? ?? name,
          orientationDeg: d('rot'),
          fixedDownstreamHeadM: (j['fixed'] as num?)?.toDouble(),
          depth: d('depth'),
          // 1.6.0 MOT: the pilot of the valve
          pilot: enumByName(ValvePilot.values, j['pilot'], ValvePilot.none, report: report, key: 'pilot'),
          pilotReduceM: d('pr'),
          pilotSustainM: d('ps'),
        );
      case EntityType.waterSupply:
        return WaterSupplyEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          calculatePressure: j['calc'] as bool? ?? true,
          designHeadM: d('dh'),
          maxHeadM: d('mh'),
          designFlow: d('dq'),
          maxFlow: d('mq'),
          waterLevelOffsetM: d('wl'),
          // 1.6.0 MOT: a reservoir or dam behind the supply
          reservoir: ReservoirSpec.fromJson(j['res'], report: report),
        );
      case EntityType.pump:
        return PumpEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          pumpSpecId: j['spec'] as String?,
          speedRatio: d('speed', 1),
          orientationDeg: d('rot'),
          scope: scope(HydraulicScope.mainline),
          hourMeter: j['hm'] != null,
          hourMeterCost: d('hm'),
          targetPressureM: d('vfd'),
          minSpeedRatio: d('vmin', 0.5),
          motorEfficiency: d('meff', 1).clamp(0.05, 1.0).toDouble(),
          // 1.6.0 MOT: a pump station, a flywheel
          station: PumpStation.fromJson(j['stn'], report: report),
          flywheelKgm2: d('fly'),
        );
      case EntityType.misc:
        return MiscHydraulicEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          valveSpecId: j['spec'] as String?,
          scope: scope(HydraulicScope.mainline),
          settingM: d('set'),
          orientationDeg: d('rot'),
          settingFlow: d('setq'),
          // 1.6.0 MOT: the pilot of the valve
          pilot: enumByName(ValvePilot.values, j['pilot'], ValvePilot.none, report: report, key: 'pilot'),
          pilotReduceM: d('pr'),
          pilotSustainM: d('ps'),
        );
      case EntityType.junction:
        return JunctionEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          scope: scope(HydraulicScope.zone),
          fixedElevation: (j['z'] as num?)?.toDouble(),
          // 1.6.0 MOT: an air vessel at the junction
          vesselLiters: d('vl'),
          vesselGasLiters: d('vg'),
          vesselConnectionMm: d('vd', 100),
          vesselCost: d('vc'),
        );
      case EntityType.area:
        return AreaEntity(
          id: id,
          layer: layer,
          name: name,
          points: pts(),
          netDepthMmPerDay: d('depth', 5),
          efficiency: d('eff', 0.9),
          crop: j['crop'] as String? ?? '',
          emittersPerPlant: (j['epp'] as num?)?.toInt() ?? 0,
          useWaterBalance: j['wb'] as bool? ?? false,
          etoMmDay: d('eto', 5),
          kc: d('kc', 1),
          awcMmPerM: d('awc', 120),
          rootDepthM: d('root', 0.6),
          mad: d('mad', 0.5),
          plantSpacingM: d('psp'),
          rowSpacingM: d('rsp'),
          wettedFraction: d('wf', 1),
          cropKey: j['ck'] as String? ?? '',
          plantingMonthDay: j['pd'] as String? ?? '',
          soilKey: j['soil'] as String? ?? '',
          slopePct: d('slope'),
          irrigationMethod: j['im'] as String? ?? 'sprinkler',
          groundCover: d('gc', 1),
          ecwDsM: d('ecw'),
          rainMethod: j['erm'] as String? ?? 'usdaScs',
          useDependableRain: j['dep'] as bool? ?? false,
          plantWaterUse: j['pwu'] as String? ?? '',
          // 1.6.0 AGR
          localizedKr: d('kr'),
          yieldPotentialPct: d('yp', 100),
          climateKc: j['kcc'] as bool? ?? true,
          // 1.6.0 MOD
          holes: rings('holes'),
          // 1.7.0 ROW
          rowDirectionDeg: switch (j['rdir']) {
            final num v when v.isFinite => (v.toDouble() % 180 + 180) % 180,
            _ => null,
          },
        );
      case EntityType.pivot:
        return PivotEntity(
          id: id,
          layer: layer,
          name: name,
          center: pos(),
          radiusM: d('r', 400),
          angleDeg: d('ang'),
          kind: enumByName(PivotKind.values, j['kind'], PivotKind.pivot, report: report, key: 'kind'),
          travelM: d('travel'),
          spanLengthM: d('span', 50),
          pipeSpecId: j['spec'] as String?,
          pipeInnerMm: d('idmm', 162),
          hazenC: d('c', 130),
          pipeHeightM: d('hp', 3.5),
          endPressureM: d('hend', 14),
          endGunFlow: d('qg'),
          endGunPressureM: d('hg'),
          endThrowM: d('throw', 5),
          grossDepthMm: d('depth', 8),
          hoursPerCycle: d('hours', 24),
          wettedWidthM: d('ww', 18),
          machineLossM: d('hm', 2),
          maxAppRateMmH: d('imax'),
          sectorDeg: d('sector', 360),
          machineCost: d('cost'),
          zoneName: j['zone'] as String? ?? '',
          sprinklerSpacingM: d('ssp', 2.5),
          sprinklerSpecId: j['sspec'] as String?,
          regulatorSpecId: j['rspec'] as String?,
          towerCost: d('tcost'),
          machine: PivotMachine.fromJson(j['mach'] as Map<String, dynamic>?),
        );
      case EntityType.controller:
        return ControllerEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          stations: (j['st'] as num?)?.toInt() ?? 12,
          outputVolts: d('v', 24),
          cost: d('cost'),
          maxSimultaneous: (j['sim'] as num?)?.toInt() ?? 0,
          // 1.6.0 AGR
          stationMaxA: d('ist'),
          totalMaxA: d('itot'),
          accessories: {
            for (final e in ((j['acc'] as Map?) ?? const {}).entries)
              if (e.value is num) e.key as String: (e.value as num).toDouble(),
          },
        );
      case EntityType.wire:
        return WireEntity(id: id, layer: layer, name: name, points: pts());
      case EntityType.comment:
        return CommentEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          text: j['text'] as String? ?? '',
          author: j['author'] as String? ?? '',
          date: j['date'] as String? ?? '',
          resolved: j['done'] as bool? ?? false,
          photo: j['photo'] as String? ?? '',
        );
      case EntityType.revisionCloud:
        return RevisionCloudEntity(
          id: id,
          layer: layer,
          name: name,
          points: pts(),
          revision: j['rev'] as String? ?? '',
          date: j['date'] as String? ?? '',
          description: j['desc'] as String? ?? '',
          arcLength: d('arc', 0),
        );
      case EntityType.ordinateDimension:
        return OrdinateDimensionEntity(id: id, layer: layer, name: name, point: pos(), leaderEnd: pt('e'), origin: j['o'] == null ? Pt.zero : pt('o'), xAxis: j['x'] as bool? ?? true);
      // 1.6.0 AGB
      case EntityType.traveller:
        return TravellerEntity._read(j, id, layer, name, pt, d, report);
      case EntityType.furrows:
        return FurrowEntity._read(j, id, layer, name, pts(), d);
      // 1.6.0 CAD
      case EntityType.blockRef:
        final sc = d('sc', 1);
        return BlockRefEntity(
          id: id,
          layer: layer,
          name: name,
          position: pos(),
          blockName: j['block'] as String? ?? '',
          rotationDeg: d('rot'),
          scale: sc > 0 ? sc : 1,
          mirrored: j['mir'] as bool? ?? false,
          attributes: {
            for (final e in ((j['attrs'] as Map?) ?? const {}).entries)
              if (e.value is String) '${e.key}': e.value as String,
          },
        );
    }
  }
}

mixin PointEntity on Entity {
  Pt get position;
  set position(Pt p);
  @override
  Bounds get bounds => Bounds(position.x, position.y, position.x, position.y);
  @override
  double distanceTo(Pt p) => position.distanceTo(p);
  @override
  List<Pt> get grips => [position];
  @override
  void setGrip(int index, Pt p) => position = p;
}

mixin PolyEntity on Entity {
  List<Pt> get points;
  double get length => polylineLength(points);
  @override
  Bounds get bounds => Bounds.ofPoints(points);
  @override
  double distanceTo(Pt p) {
    var best = double.infinity;
    for (var i = 1; i < points.length; i++) {
      best = math.min(best, distanceToSegment(p, points[i - 1], points[i]));
    }
    if (points.length == 1) best = points.first.distanceTo(p);
    return best;
  }

  @override
  List<Pt> get grips => points;
  @override
  void setGrip(int index, Pt p) {
    if (index >= 0 && index < points.length) points[index] = p;
  }

  void insertVertex(int index, Pt p) => points.insert(index.clamp(0, points.length), p);
  void removeVertex(int index) {
    if (points.length > 2 && index >= 0 && index < points.length) points.removeAt(index);
  }
}

List<List<double>> _ptsJson(List<Pt> pts) => pts.map((p) => p.toList()).toList();
List<Pt> _map(List<Pt> pts, Affine t) => pts.map(t.apply).toList();
double _rotDeg(Affine t, double deg) => radToDeg(t.transformAngle(degToRad(deg)));

/// [deg] in (-180, 180], without the rounding noise of the trigonometry.
double _norm360(double deg) {
  var d = deg % 360;
  if (d > 180) d -= 360;
  final r = d.roundToDouble();
  return (d - r).abs() < 1e-9 ? r : d;
}

// ---------------------------------------------------------------- drawing

class LineEntity extends Entity {
  LineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.a, required this.b});
  Pt a, b;
  @override
  EntityType get type => EntityType.line;
  @override
  Bounds get bounds => Bounds.ofPoints([a, b]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, a, b);
  double get length => a.distanceTo(b);
  @override
  List<Pt> get grips => [a, b];
  @override
  void setGrip(int index, Pt p) => index == 0 ? a = p : b = p;
  @override
  LineEntity clone({String? newId}) => LineEntity(id: newId ?? id, layer: layer, name: name, a: a, b: b)..extra = extra;
  @override
  LineEntity translated(Pt d) => LineEntity(id: id, layer: layer, name: name, a: a + d, b: b + d)..extra = extra;
  @override
  LineEntity transformed(Affine t) => LineEntity(id: id, layer: layer, name: name, a: t.apply(a), b: t.apply(b))..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'a': a.toList(), 'b': b.toList()};
}

class PolylineEntity extends Entity with PolyEntity {
  PolylineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.points, this.closed = false});

  /// Perimeter when closed, open length otherwise.
  @override
  double get length => polylineLength(points) + (closed && points.length > 2 ? points.last.distanceTo(points.first) : 0);
  @override
  List<Pt> points;
  bool closed;
  @override
  EntityType get type => EntityType.polyline;
  @override
  double distanceTo(Pt p) {
    var d = super.distanceTo(p);
    if (closed && points.length > 2) d = math.min(d, distanceToSegment(p, points.last, points.first));
    return d;
  }

  double get area => closed ? polygonArea(points).abs() : 0;
  @override
  PolylineEntity clone({String? newId}) => PolylineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), closed: closed)..extra = extra;
  @override
  PolylineEntity translated(Pt d) => PolylineEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), closed: closed)..extra = extra;
  @override
  PolylineEntity transformed(Affine t) => PolylineEntity(id: id, layer: layer, name: name, points: _map(points, t), closed: closed)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'closed': closed};
}

class CircleEntity extends Entity {
  CircleEntity({required super.id, super.layer = Layers.drawing, super.name, required this.center, required this.radius});
  Pt center;
  double radius;
  @override
  EntityType get type => EntityType.circle;
  @override
  Bounds get bounds => Bounds(center.x - radius, center.y - radius, center.x + radius, center.y + radius);
  @override
  double distanceTo(Pt p) => (center.distanceTo(p) - radius).abs();
  @override
  List<Pt> get grips => [center, center + Pt(radius, 0), center + Pt(0, radius), center + Pt(-radius, 0), center + Pt(0, -radius)];
  @override
  void setGrip(int index, Pt p) {
    if (index == 0) {
      center = p;
    } else {
      radius = math.max(1e-6, center.distanceTo(p));
    }
  }

  @override
  CircleEntity clone({String? newId}) => CircleEntity(id: newId ?? id, layer: layer, name: name, center: center, radius: radius)..extra = extra;
  @override
  CircleEntity translated(Pt d) => CircleEntity(id: id, layer: layer, name: name, center: center + d, radius: radius)..extra = extra;
  @override
  CircleEntity transformed(Affine t) => CircleEntity(id: id, layer: layer, name: name, center: t.apply(center), radius: radius * t.scale)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': center.toList(), 'r': radius};
}

class ArcEntity extends Entity {
  ArcEntity({required super.id, super.layer = Layers.drawing, super.name, required this.center, required this.radius, required this.startRad, required this.sweepRad});
  Pt center;
  double radius;
  double startRad;
  double sweepRad;
  @override
  EntityType get type => EntityType.arc;
  Pt get startPoint => center + Pt.polar(radius, startRad);
  Pt get endPoint => center + Pt.polar(radius, startRad + sweepRad);
  Pt get midPoint => center + Pt.polar(radius, startRad + sweepRad / 2);
  double get length => radius * sweepRad.abs();

  /// Sampled polyline along the arc.
  List<Pt> polyline([int segments = 32]) {
    final n = math.max(2, (segments * sweepRad.abs() / (2 * math.pi)).ceil());
    return [for (var i = 0; i <= n; i++) center + Pt.polar(radius, startRad + sweepRad * i / n)];
  }

  @override
  Bounds get bounds => Bounds.ofPoints(polyline());
  @override
  double distanceTo(Pt p) {
    final ang = (p - center).angle;
    var rel = (ang - startRad) % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;
    final sweep = sweepRad.abs();
    final inside = sweepRad >= 0 ? rel <= sweep : (2 * math.pi - rel) <= sweep;
    if (inside) return (center.distanceTo(p) - radius).abs();
    return math.min(p.distanceTo(startPoint), p.distanceTo(endPoint));
  }

  @override
  List<Pt> get grips => [center, startPoint, endPoint, midPoint];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        center = p;
      case 1:
        final end = startPoint + (endPoint - startPoint);
        final a = arcThrough(p, midPoint, end);
        if (a != null) _set(a);
      case 2:
        final a = arcThrough(startPoint, midPoint, p);
        if (a != null) _set(a);
      default:
        final a = arcThrough(startPoint, p, endPoint);
        if (a != null) _set(a);
    }
  }

  void _set((Pt, double, double, double) a) {
    center = a.$1;
    radius = a.$2;
    startRad = a.$3;
    sweepRad = a.$4;
  }

  @override
  ArcEntity clone({String? newId}) => ArcEntity(id: newId ?? id, layer: layer, name: name, center: center, radius: radius, startRad: startRad, sweepRad: sweepRad)..extra = extra;
  @override
  ArcEntity translated(Pt d) => ArcEntity(id: id, layer: layer, name: name, center: center + d, radius: radius, startRad: startRad, sweepRad: sweepRad)..extra = extra;
  @override
  ArcEntity transformed(Affine t) =>
      ArcEntity(id: id, layer: layer, name: name, center: t.apply(center), radius: radius * t.scale, startRad: t.transformAngle(startRad), sweepRad: t.isMirror ? -sweepRad : sweepRad)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': center.toList(), 'r': radius, 's': startRad, 'w': sweepRad};
}

/// Smooth curve through fit points (centripetal Catmull-Rom).
class SplineEntity extends Entity with PolyEntity {
  SplineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.points, this.closed = false});
  @override
  List<Pt> points;
  bool closed;
  @override
  EntityType get type => EntityType.spline;
  List<Pt> curve([int segments = 8]) => catmullRom(points, closed: closed, segments: segments);
  @override
  double get length => polylineLength(curve());
  @override
  Bounds get bounds => Bounds.ofPoints(curve());
  @override
  double distanceTo(Pt p) {
    final c = curve();
    var best = double.infinity;
    for (var i = 1; i < c.length; i++) {
      best = math.min(best, distanceToSegment(p, c[i - 1], c[i]));
    }
    return best;
  }

  @override
  SplineEntity clone({String? newId}) => SplineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), closed: closed)..extra = extra;
  @override
  SplineEntity translated(Pt d) => SplineEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), closed: closed)..extra = extra;
  @override
  SplineEntity transformed(Affine t) => SplineEntity(id: id, layer: layer, name: name, points: _map(points, t), closed: closed)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'closed': closed};
}

/// Hatched (or solid filled) polygon.
class HatchEntity extends Entity with PolyEntity {
  HatchEntity({required super.id, super.layer = Layers.hatches, super.name, required this.points, this.angleDeg = 45, this.spacing = 1, this.solid = false});
  @override
  List<Pt> points;
  double angleDeg;
  double spacing;
  bool solid;
  @override
  EntityType get type => EntityType.hatch;
  double get area => polygonArea(points).abs();
  List<List<Pt>> patternLines() => solid ? const [] : hatchLines(points, degToRad(angleDeg), spacing);
  @override
  double distanceTo(Pt p) => pointInPolygon(p, points) ? 0 : math.min(super.distanceTo(p), points.length > 2 ? distanceToSegment(p, points.last, points.first) : double.infinity);
  @override
  HatchEntity clone({String? newId}) => HatchEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), angleDeg: angleDeg, spacing: spacing, solid: solid)..extra = extra;
  @override
  HatchEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  HatchEntity transformed(Affine t) => HatchEntity(id: id, layer: layer, name: name, points: _map(points, t), angleDeg: _rotDeg(t, angleDeg), spacing: spacing * t.scale, solid: solid)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'ang': angleDeg, 'sp': spacing, 'solid': solid};
}

enum SymbolKind { northArrow, tree, building, tank, well, valveBox, pumpHouse, gate, filterStation }

/// Vector symbol (north arrow, tree, building…), sized in world metres.
class SymbolEntity extends Entity with PointEntity {
  SymbolEntity({required super.id, super.layer = Layers.symbols, super.name, required this.position, this.kind = SymbolKind.tree, this.size = 2, this.rotationDeg = 0, this.mirrored = false});
  @override
  Pt position;
  SymbolKind kind;
  double size;
  double rotationDeg;

  /// The glyph is reflected across its own vertical axis before it is
  /// turned (a symbol of a mirrored drawing: the north arrow of a drawing
  /// mirrored top to bottom points south).
  bool mirrored;
  @override
  EntityType get type => EntityType.symbol;
  @override
  Bounds get bounds => Bounds(position.x - size, position.y - size, position.x + size, position.y + size);
  @override
  double distanceTo(Pt p) => math.max(0, position.distanceTo(p) - size * 0.7);

  /// Glyph strokes in world coordinates (unit glyph scaled by [size]).
  List<List<Pt>> strokes() {
    final turn = Affine.rotation(degToRad(rotationDeg)).then(Affine.scaling(size)).then(Affine.translation(position));
    final t = mirrored ? Affine.mirror(Pt.zero, const Pt(0, 1)).then(turn) : turn;
    List<Pt> poly(List<List<double>> pts) => [for (final p in pts) t.apply(Pt(p[0], p[1]))];
    List<Pt> circle(double cx, double cy, double r, [int n = 24]) => [for (var i = 0; i <= n; i++) t.apply(Pt(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)))];
    switch (kind) {
      case SymbolKind.northArrow:
        return [
          poly([
            [0, -1],
            [0, 1],
          ]),
          poly([
            [-0.25, 0.55],
            [0, 1],
            [0.25, 0.55],
            [0, 0.7],
            [-0.25, 0.55],
          ]),
          poly([
            [-0.18, -0.5],
            [-0.18, -0.15],
            [0.18, -0.5],
            [0.18, -0.15],
          ]), // "N"
        ];
      case SymbolKind.tree:
        return [
          circle(0, 0, 1),
          circle(0, 0, 0.08),
          poly([
            [0, 0],
            [0.7, 0.7],
          ]),
          poly([
            [0, 0],
            [-0.7, 0.7],
          ]),
          poly([
            [0, 0],
            [0, -1],
          ]),
        ];
      case SymbolKind.building:
        return [
          poly([
            [-1, -0.7],
            [1, -0.7],
            [1, 0.7],
            [-1, 0.7],
            [-1, -0.7],
          ]),
          poly([
            [-1, -0.7],
            [1, 0.7],
          ]),
          poly([
            [-1, 0.7],
            [1, -0.7],
          ]),
        ];
      case SymbolKind.tank:
        return [
          circle(0, 0, 1),
          circle(0, 0, 0.8),
          poly([
            [-0.5, 0],
            [0.5, 0],
          ]),
          poly([
            [0, -0.5],
            [0, 0.5],
          ]),
        ];
      case SymbolKind.well:
        return [
          circle(0, 0, 0.8),
          poly([
            [-0.8, 0],
            [0.8, 0],
          ]),
          poly([
            [0, 0.8],
            [0, -0.8],
          ]),
          poly([
            [-0.57, -0.57],
            [0.57, 0.57],
          ]),
          poly([
            [-0.57, 0.57],
            [0.57, -0.57],
          ]),
        ];
      case SymbolKind.valveBox:
        return [
          poly([
            [-1, -0.6],
            [1, -0.6],
            [1, 0.6],
            [-1, 0.6],
            [-1, -0.6],
          ]),
          poly([
            [-0.5, -0.3],
            [0.5, 0.3],
            [0.5, -0.3],
            [-0.5, 0.3],
            [-0.5, -0.3],
          ]),
        ];
      case SymbolKind.pumpHouse:
        return [
          poly([
            [-1, -0.8],
            [1, -0.8],
            [1, 0.4],
            [0, 1],
            [-1, 0.4],
            [-1, -0.8],
          ]),
          circle(0, -0.1, 0.35),
          poly([
            [0.35, -0.1],
            [0.7, -0.1],
          ]),
        ];
      case SymbolKind.gate:
        return [
          poly([
            [-1, 0],
            [1, 0],
          ]),
          poly([
            [-1, -0.3],
            [-1, 0.3],
          ]),
          poly([
            [1, -0.3],
            [1, 0.3],
          ]),
          poly([
            [-0.6, 0],
            [-0.6, 0.5],
            [0.6, 0.5],
            [0.6, 0],
          ]),
        ];
      case SymbolKind.filterStation:
        return [
          poly([
            [-1, -0.6],
            [1, -0.6],
            [1, 0.6],
            [-1, 0.6],
            [-1, -0.6],
          ]),
          poly([
            [-0.6, -0.3],
            [-0.2, 0.3],
          ]),
          poly([
            [-0.2, -0.3],
            [0.2, 0.3],
          ]),
          poly([
            [0.2, -0.3],
            [0.6, 0.3],
          ]),
        ];
    }
  }

  @override
  SymbolEntity clone({String? newId}) =>
      SymbolEntity(id: newId ?? id, layer: layer, name: name, position: position, kind: kind, size: size, rotationDeg: rotationDeg, mirrored: mirrored)..extra = extra;
  @override
  SymbolEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  SymbolEntity transformed(Affine t) {
    // a mirror reflects the glyph itself: the turn of a reflected glyph is
    // the image of its direction less a half turn, its reflection toggles
    final rot = t.isMirror ? _norm360(_rotDeg(t, rotationDeg) - 180) : _rotDeg(t, rotationDeg);
    return SymbolEntity(id: id, layer: layer, name: name, position: t.apply(position), kind: kind, size: size * t.scale, rotationDeg: rot, mirrored: mirrored != t.isMirror)..extra = extra;
  }

  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'kind': kind.name, 'size': size, 'rot': rotationDeg, if (mirrored) 'mir': true};
}

class TextEntity extends Entity with PointEntity {
  TextEntity({required super.id, super.layer = Layers.text, super.name, required this.position, required this.text, this.height = 1, this.rotationDeg = 0});
  @override
  Pt position;
  String text;
  double height;
  double rotationDeg;
  @override
  EntityType get type => EntityType.text;

  /// Corners of the (approximate) text box, turned with the text.
  List<Pt> get corners {
    final w = height * 0.6 * text.length;
    if (rotationDeg == 0) return [position, position + Pt(w, 0), position + Pt(w, height), position + Pt(0, height)];
    final u = Pt.polar(1, degToRad(rotationDeg)), v = u.perpendicular;
    return [position, position + u * w, position + u * w + v * height, position + v * height];
  }

  @override
  Bounds get bounds => Bounds.ofPoints(corners);
  @override
  double distanceTo(Pt p) {
    if (pointInPolygon(p, corners)) return 0;
    return position.distanceTo(p);
  }

  @override
  TextEntity clone({String? newId}) => TextEntity(id: newId ?? id, layer: layer, name: name, position: position, text: text, height: height, rotationDeg: rotationDeg)..extra = extra;
  @override
  TextEntity translated(Pt d) => TextEntity(id: id, layer: layer, name: name, position: position + d, text: text, height: height, rotationDeg: rotationDeg)..extra = extra;
  @override
  TextEntity transformed(Affine t) {
    if (!t.isMirror) return TextEntity(id: id, layer: layer, name: name, position: t.apply(position), text: text, height: height * t.scale, rotationDeg: _rotDeg(t, rotationDeg))..extra = extra;
    // mirrored, the text keeps reading left to right over the mirrored box:
    // the baseline starts at the image of the top corner, or of the far end
    // (and turns half round) when the image of its direction points left
    final c = corners;
    final dir = _rotDeg(t, rotationDeg);
    final left = math.cos(degToRad(dir)) < -1e-9;
    final at = left ? t.apply(c[1]) : t.apply(c[3]);
    return TextEntity(id: id, layer: layer, name: name, position: at, text: text, height: height * t.scale, rotationDeg: _norm360(left ? dir - 180 : dir))..extra = extra;
  }

  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'text': text, 'h': height, 'rot': rotationDeg};
}

class DimensionEntity extends Entity {
  DimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.a, required this.b, this.offset = 1});
  Pt a, b;
  double offset;
  @override
  EntityType get type => EntityType.dimension;
  double get length => a.distanceTo(b);
  Pt get normal => (b - a).normalized.perpendicular;
  @override
  Bounds get bounds => Bounds.ofPoints([a, b, a + normal * offset, b + normal * offset]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, a + normal * offset, b + normal * offset);
  @override
  List<Pt> get grips => [a, b, Pt.lerp(a, b, 0.5) + normal * offset];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        a = p;
      case 1:
        b = p;
      default:
        offset = (p - a).dot(normal);
    }
  }

  @override
  DimensionEntity clone({String? newId}) => DimensionEntity(id: newId ?? id, layer: layer, name: name, a: a, b: b, offset: offset)..extra = extra;
  @override
  DimensionEntity translated(Pt d) => DimensionEntity(id: id, layer: layer, name: name, a: a + d, b: b + d, offset: offset)..extra = extra;
  @override
  DimensionEntity transformed(Affine t) => DimensionEntity(id: id, layer: layer, name: name, a: t.apply(a), b: t.apply(b), offset: offset * t.scale * (t.isMirror ? -1 : 1))..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'a': a.toList(), 'b': b.toList(), 'off': offset};
}

/// Angle between the rays vertex→a and vertex→b, drawn as an arc of [radius].
class AngularDimensionEntity extends Entity {
  AngularDimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.vertex, required this.a, required this.b, this.radius = 2});
  Pt vertex, a, b;
  double radius;
  @override
  EntityType get type => EntityType.angularDimension;
  double get startRad => (a - vertex).angle;

  /// Counter-clockwise sweep from a to b, in (0, 2π).
  double get sweepRad {
    var s = ((b - vertex).angle - startRad) % (2 * math.pi);
    if (s < 0) s += 2 * math.pi;
    return s;
  }

  double get angleDeg => radToDeg(sweepRad);
  List<Pt> arcPoints([int segments = 32]) {
    final n = math.max(2, (segments * sweepRad / (2 * math.pi)).ceil());
    return [for (var i = 0; i <= n; i++) vertex + Pt.polar(radius, startRad + sweepRad * i / n)];
  }

  Pt get textPoint => vertex + Pt.polar(radius * 1.15, startRad + sweepRad / 2);
  @override
  Bounds get bounds => Bounds.ofPoints([vertex, a, b, ...arcPoints(8)]);
  @override
  double distanceTo(Pt p) {
    final pts = arcPoints();
    var best = math.min(distanceToSegment(p, vertex, a), distanceToSegment(p, vertex, b));
    for (var i = 1; i < pts.length; i++) {
      best = math.min(best, distanceToSegment(p, pts[i - 1], pts[i]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [vertex, a, b, vertex + Pt.polar(radius, startRad + sweepRad / 2)];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        vertex = p;
      case 1:
        a = p;
      case 2:
        b = p;
      default:
        radius = math.max(0.1, vertex.distanceTo(p));
    }
  }

  @override
  AngularDimensionEntity clone({String? newId}) => AngularDimensionEntity(id: newId ?? id, layer: layer, name: name, vertex: vertex, a: a, b: b, radius: radius)..extra = extra;
  @override
  AngularDimensionEntity translated(Pt d) => AngularDimensionEntity(id: id, layer: layer, name: name, vertex: vertex + d, a: a + d, b: b + d, radius: radius)..extra = extra;
  @override
  AngularDimensionEntity transformed(Affine t) =>
      t.isMirror
            ? AngularDimensionEntity(id: id, layer: layer, name: name, vertex: t.apply(vertex), a: t.apply(b), b: t.apply(a), radius: radius * t.scale)
            : AngularDimensionEntity(id: id, layer: layer, name: name, vertex: t.apply(vertex), a: t.apply(a), b: t.apply(b), radius: radius * t.scale)
        ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'v': vertex.toList(), 'a': a.toList(), 'b': b.toList(), 'r': radius};
}

/// Radius dimension from [center] to [point] on the circle, or, with
/// [diameter], a diameter dimension across the circle through the centre.
class RadialDimensionEntity extends Entity {
  RadialDimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.center, required this.point, this.diameter = false});
  Pt center, point;
  bool diameter;
  @override
  EntityType get type => EntityType.radialDimension;
  double get radius => center.distanceTo(point);

  /// The value written: the radius, or twice it for a diameter dimension.
  double get value => diameter ? 2 * radius : radius;

  /// Far end of the dimension line: the centre (radius) or the point
  /// opposite [point] on the circle (diameter).
  Pt get start => diameter ? center * 2 - point : center;
  @override
  Bounds get bounds => Bounds.ofPoints([center, point, start]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, start, point);
  @override
  List<Pt> get grips => [center, point];
  @override
  void setGrip(int index, Pt p) => index == 0 ? center = p : point = p;
  @override
  RadialDimensionEntity clone({String? newId}) => RadialDimensionEntity(id: newId ?? id, layer: layer, name: name, center: center, point: point, diameter: diameter)..extra = extra;
  @override
  RadialDimensionEntity translated(Pt d) => RadialDimensionEntity(id: id, layer: layer, name: name, center: center + d, point: point + d, diameter: diameter)..extra = extra;
  @override
  RadialDimensionEntity transformed(Affine t) => RadialDimensionEntity(id: id, layer: layer, name: name, center: t.apply(center), point: t.apply(point), diameter: diameter)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'c': center.toList(), 'p': point.toList(), if (diameter) 'dia': true};
}

/// Leader: arrow polyline ending at a text note.
class LeaderEntity extends Entity with PolyEntity {
  LeaderEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.points, this.text = '', this.height = 1});
  @override
  List<Pt> points;
  String text;
  double height;
  @override
  EntityType get type => EntityType.leader;
  Pt get textPosition => points.isEmpty ? Pt.zero : points.last;
  @override
  Bounds get bounds => Bounds.ofPoints([...points, if (points.isNotEmpty) points.last + Pt(height * 0.6 * text.length, height)]);
  @override
  LeaderEntity clone({String? newId}) => LeaderEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), text: text, height: height)..extra = extra;
  @override
  LeaderEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  LeaderEntity transformed(Affine t) => LeaderEntity(id: id, layer: layer, name: name, points: _map(points, t), text: text, height: height * t.scale)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'text': text, 'h': height};
}

/// Raster image (georeferenced background, aerial photo, scanned plan).
/// [origin] is the bottom-left corner in world metres; the image spans
/// [width] × [height] metres rotated by [rotationDeg] about the origin.
class ImageEntity extends Entity {
  ImageEntity({
    required super.id,
    super.layer = Layers.images,
    super.name,
    required this.origin,
    required this.width,
    required this.height,
    this.rotationDeg = 0,
    this.opacity = 1,
    this.mime = 'image/png',
    this.data,
    this.source = '',
  });
  Pt origin;
  double width;
  double height;
  double rotationDeg;
  double opacity;
  String mime;

  /// Encoded image bytes (PNG/JPEG); null when the file was not embedded.
  Uint8List? data;
  String source;
  @override
  EntityType get type => EntityType.image;

  /// Corners: bottom-left, bottom-right, top-right, top-left.
  List<Pt> get corners {
    final r = degToRad(rotationDeg);
    final u = Pt.polar(width, r), v = Pt.polar(height, r + math.pi / 2);
    return [origin, origin + u, origin + u + v, origin + v];
  }

  @override
  Bounds get bounds => Bounds.ofPoints(corners);
  @override
  double distanceTo(Pt p) {
    final c = corners;
    if (pointInPolygon(p, c)) return 0;
    var best = double.infinity;
    for (var i = 0; i < 4; i++) {
      best = math.min(best, distanceToSegment(p, c[i], c[(i + 1) % 4]));
    }
    return best;
  }

  @override
  List<Pt> get grips => corners;
  @override
  void setGrip(int index, Pt p) {
    final r = degToRad(rotationDeg);
    final u = Pt.polar(1, r), v = Pt.polar(1, r + math.pi / 2);
    switch (index) {
      case 0:
        origin = p;
      case 1:
        width = math.max(0.01, (p - origin).dot(u));
      case 2:
        width = math.max(0.01, (p - origin).dot(u));
        height = math.max(0.01, (p - origin).dot(v));
      default:
        height = math.max(0.01, (p - origin).dot(v));
    }
  }

  @override
  ImageEntity clone({String? newId}) =>
      ImageEntity(id: newId ?? id, layer: layer, name: name, origin: origin, width: width, height: height, rotationDeg: rotationDeg, opacity: opacity, mime: mime, data: data, source: source)
        ..extra = extra;
  @override
  ImageEntity translated(Pt d) => clone()
    ..origin = origin + d
    ..extra = extra;
  @override
  ImageEntity transformed(Affine t) {
    final c = corners.map(t.apply).toList();
    final e = clone();
    e.origin = t.isMirror ? c[1] : c[0];
    e.width = width * t.scale;
    e.height = height * t.scale;
    // a mirrored image keeps its raster and is placed on the mirrored
    // rectangle: origin at the mirrored second corner, bottom edge towards
    // the mirrored first corner
    e.rotationDeg = t.isMirror ? radToDeg((c[0] - c[1]).angle) : radToDeg((c[1] - c[0]).angle);
    return e;
  }

  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': origin.toList(),
    'w': width,
    'h': height,
    'rot': rotationDeg,
    'op': opacity,
    'mime': mime,
    if (data != null) 'data': base64Encode(data!),
    if (source.isNotEmpty) 'src': source,
  };
}

// ---------------------------------------------------------------- terrain

class ContourEntity extends Entity with PolyEntity {
  ContourEntity({required super.id, super.layer = Layers.contours, super.name, required this.points, required this.elevation, this.derived = false});
  @override
  List<Pt> points;
  double elevation;

  /// Generated from the terrain model (not a survey input): drawn, exported,
  /// but not fed back into the DTM.
  bool derived;
  @override
  EntityType get type => EntityType.contour;
  @override
  ContourEntity clone({String? newId}) => ContourEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), elevation: elevation, derived: derived)..extra = extra;
  @override
  ContourEntity translated(Pt d) => ContourEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), elevation: elevation, derived: derived)..extra = extra;
  @override
  ContourEntity transformed(Affine t) => ContourEntity(id: id, layer: layer, name: name, points: _map(points, t), elevation: elevation, derived: derived)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'z': elevation, if (derived) 'gen': true};
}

/// Breakline of the terrain model: a ridge, a channel bottom, the edge of a
/// terrace, road or embankment that the triangulation must not cut across.
/// Every vertex may carry its surveyed elevation; NaN takes it from the
/// other terrain data at that point.
class BreaklineEntity extends Entity with PolyEntity {
  BreaklineEntity({required super.id, super.layer = Layers.breaklines, super.name, required this.points, List<double>? elevations}) : elevations = elevations ?? List.filled(points.length, double.nan);
  @override
  List<Pt> points;
  List<double> elevations;

  /// Elevation of vertex [i] (NaN = from the terrain).
  double elevationOf(int i) => i < elevations.length ? elevations[i] : double.nan;
  @override
  EntityType get type => EntityType.breakline;
  @override
  BreaklineEntity clone({String? newId}) => BreaklineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), elevations: List.of(elevations))..extra = extra;
  @override
  BreaklineEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  BreaklineEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'pts': _ptsJson(points),
    if (elevations.any((z) => z.isFinite)) 'zs': [for (var i = 0; i < points.length; i++) elevationOf(i).isFinite ? elevationOf(i) : null],
  };
}

class SpotHeightEntity extends Entity with PointEntity {
  SpotHeightEntity({required super.id, super.layer = Layers.spotHeights, super.name, required this.position, required this.elevation});
  @override
  Pt position;
  double elevation;
  @override
  EntityType get type => EntityType.spotHeight;

  /// A point downloaded from an online elevation model (named "DEM …" by
  /// the import), as opposed to a surveyed or typed spot height.
  bool get isDem => name.startsWith('DEM ');
  @override
  SpotHeightEntity clone({String? newId}) => SpotHeightEntity(id: newId ?? id, layer: layer, name: name, position: position, elevation: elevation)..extra = extra;
  @override
  SpotHeightEntity translated(Pt d) => SpotHeightEntity(id: id, layer: layer, name: name, position: position + d, elevation: elevation)..extra = extra;
  @override
  SpotHeightEntity transformed(Affine t) => SpotHeightEntity(id: id, layer: layer, name: name, position: t.apply(position), elevation: elevation)..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'z': elevation};
}

// ---------------------------------------------------------------- hydraulic (linear)

class PipeEntity extends Entity with PolyEntity {
  PipeEntity({required super.id, String? layer, super.name, required this.points, required this.scope, this.pipeSpecId, this.computerSized = true, this.depth = 0})
    : super(layer: layer ?? (scope == HydraulicScope.zone ? Layers.zonePipes : Layers.mainlinePipes));
  @override
  List<Pt> points;
  HydraulicScope scope;
  String? pipeSpecId;
  bool computerSized;
  double depth;
  @override
  EntityType get type => EntityType.pipe;
  @override
  PipeEntity clone({String? newId}) =>
      PipeEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), scope: scope, pipeSpecId: pipeSpecId, computerSized: computerSized, depth: depth)..extra = extra;
  @override
  PipeEntity translated(Pt d) =>
      PipeEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), scope: scope, pipeSpecId: pipeSpecId, computerSized: computerSized, depth: depth)..extra = extra;
  @override
  PipeEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'scope': scope.name, if (pipeSpecId != null) 'spec': pipeSpecId, 'auto': computerSized, 'depth': depth};
}

/// Lateral with equally spaced outlets (a "connected" sprayline: analysed as one unit).
class SpraylineEntity extends Entity with PolyEntity {
  SpraylineEntity({
    required super.id,
    super.layer = Layers.spraylines,
    super.name,
    required this.points,
    this.pipeSpecId,
    this.computerSized = true,
    required this.outletSpecId,
    this.nozzleId,
    this.headM = 20,
    this.spacing = 5,
    this.offset = 0,
    this.arcDeg = 360,
    this.riserHeight = 0,
    this.depth = 0,
  });
  @override
  List<Pt> points;
  String? pipeSpecId;
  bool computerSized;
  String outletSpecId;
  String? nozzleId;
  double headM;
  double spacing;

  /// Distance from the start to the first outlet (0 = half spacing rule not applied; first at [offset] if > 0, else at [spacing]).
  double offset;
  double arcDeg;
  double riserHeight;
  double depth;
  @override
  EntityType get type => EntityType.sprayline;

  double get firstOutletDistance => offset > 0 ? offset : spacing;
  int get outletCount {
    final l = length;
    final first = firstOutletDistance;
    if (!first.isFinite || first < 0 || l < first - 1e-9) return 0;
    // no spacing (a value typed as 0, a damaged file): the first outlet only
    if (!(spacing > 0) || !spacing.isFinite) return 1;
    return ((l - first) / spacing + 1e-9).floor() + 1;
  }

  List<Pt> outletPositions() => [for (var i = 0; i < outletCount; i++) pointAlongPolyline(points, firstOutletDistance + i * spacing)];

  @override
  SpraylineEntity clone({String? newId}) => SpraylineEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    points: List.of(points),
    pipeSpecId: pipeSpecId,
    computerSized: computerSized,
    outletSpecId: outletSpecId,
    nozzleId: nozzleId,
    headM: headM,
    spacing: spacing,
    offset: offset,
    arcDeg: arcDeg,
    riserHeight: riserHeight,
    depth: depth,
  )..extra = extra;
  @override
  SpraylineEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  SpraylineEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..spacing = spacing * t.scale
    ..offset = offset * t.scale
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'pts': _ptsJson(points),
    if (pipeSpecId != null) 'spec': pipeSpecId,
    'auto': computerSized,
    'outlet': outletSpecId,
    if (nozzleId != null) 'nozzle': nozzleId,
    'head': headM,
    'sp': spacing,
    'off': offset,
    'arc': arcDeg,
    'riser': riserHeight,
    'depth': depth,
  };
}

class TapeEntity extends Entity with PolyEntity {
  TapeEntity({
    required super.id,
    super.layer = Layers.tapes,
    super.name,
    required this.points,
    required this.tapeSpecId,
    this.inletHeadM = 10,
    this.regulated = false,
    this.submainMinHeadM = 0,
    this.depth = 0,
    this.flushingFlow = 0,
  });
  @override
  List<Pt> points;
  String tapeSpecId;
  double inletHeadM;
  bool regulated;
  double submainMinHeadM;
  double depth;

  /// Extra end flow for flushing analysis (m³/s).
  double flushingFlow;
  @override
  EntityType get type => EntityType.tape;
  @override
  TapeEntity clone({String? newId}) => TapeEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    points: List.of(points),
    tapeSpecId: tapeSpecId,
    inletHeadM: inletHeadM,
    regulated: regulated,
    submainMinHeadM: submainMinHeadM,
    depth: depth,
    flushingFlow: flushingFlow,
  )..extra = extra;
  @override
  TapeEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  TapeEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'spec': tapeSpecId, 'inlet': inletHeadM, 'reg': regulated, 'submin': submainMinHeadM, 'depth': depth, 'flush': flushingFlow};
}

// ---------------------------------------------------------------- hydraulic (point)

class OutletEntity extends Entity with PointEntity {
  OutletEntity({
    required super.id,
    super.layer = Layers.outlets,
    super.name,
    required this.position,
    this.scope = HydraulicScope.zone,
    required this.outletSpecId,
    this.nozzleId,
    this.headM = 20,
    this.arcDeg = 360,
    this.orientationDeg = 0,
    this.riserHeight = 0,
    this.zoneName = '',
  });
  @override
  Pt position;
  HydraulicScope scope;
  String outletSpecId;
  String? nozzleId;
  double headM;
  double arcDeg;
  double orientationDeg;
  double riserHeight;

  /// For mainline outlets (valve-in-head heads), the station: heads sharing
  /// a non-empty name open together on one controller station, an empty one
  /// is a station of its own (`design/valve_in_head.dart`).
  String zoneName;
  @override
  EntityType get type => EntityType.outlet;
  @override
  OutletEntity clone({String? newId}) => OutletEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    scope: scope,
    outletSpecId: outletSpecId,
    nozzleId: nozzleId,
    headM: headM,
    arcDeg: arcDeg,
    orientationDeg: orientationDeg,
    riserHeight: riserHeight,
    zoneName: zoneName,
  )..extra = extra;
  @override
  OutletEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;

  /// The wetted sector runs counter-clockwise from [orientationDeg] over
  /// [arcDeg]; a mirror turns it clockwise, so the mirrored sector starts at
  /// the image of its far edge.
  @override
  OutletEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, t.isMirror && arcDeg < 360 ? orientationDeg + arcDeg : orientationDeg)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'scope': scope.name,
    'outlet': outletSpecId,
    if (nozzleId != null) 'nozzle': nozzleId,
    'head': headM,
    'arc': arcDeg,
    'rot': orientationDeg,
    'riser': riserHeight,
    if (zoneName.isNotEmpty) 'zone': zoneName,
  };
}

class ControlValveEntity extends Entity with PointEntity {
  ControlValveEntity({
    required super.id,
    super.layer = Layers.controlValves,
    super.name,
    required this.position,
    this.valveSpecId,
    this.zoneName = '',
    this.orientationDeg = 0,
    this.fixedDownstreamHeadM,
    this.depth = 0,
    this.pilot = ValvePilot.none,
    this.pilotReduceM = 0,
    this.pilotSustainM = 0,
  });
  @override
  Pt position;
  String? valveSpecId;
  String zoneName;
  double orientationDeg;

  /// If set, the zone is analysed with this downstream pressure (Detailed Analysis).
  double? fixedDownstreamHeadM;
  double depth;

  /// 1.6.0 MOT: the pilot of the valve. A reducing pilot holds the zone at
  /// [pilotReduceM] (0 = at the pressure the design finds for it) and passes
  /// no surplus on; a sustaining one keeps the mainline before the valve at
  /// [pilotSustainM] or more, throttling the zone rather than letting it
  /// fall below.
  ValvePilot pilot;
  double pilotReduceM;
  double pilotSustainM;
  @override
  EntityType get type => EntityType.controlValve;
  @override
  ControlValveEntity clone({String? newId}) => ControlValveEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    valveSpecId: valveSpecId,
    zoneName: zoneName,
    orientationDeg: orientationDeg,
    fixedDownstreamHeadM: fixedDownstreamHeadM,
    depth: depth,
    pilot: pilot,
    pilotReduceM: pilotReduceM,
    pilotSustainM: pilotSustainM,
  )..extra = extra;
  @override
  ControlValveEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  ControlValveEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    if (valveSpecId != null) 'spec': valveSpecId,
    'zone': zoneName,
    'rot': orientationDeg,
    if (fixedDownstreamHeadM != null) 'fixed': fixedDownstreamHeadM,
    'depth': depth,
    if (pilot != ValvePilot.none) 'pilot': pilot.name,
    if (pilotReduceM > 0) 'pr': pilotReduceM,
    if (pilotSustainM > 0) 'ps': pilotSustainM,
  };
}

class WaterSupplyEntity extends Entity with PointEntity {
  WaterSupplyEntity({
    required super.id,
    super.layer = Layers.waterSupply,
    super.name,
    required this.position,
    this.calculatePressure = true,
    this.designHeadM = 0,
    this.maxHeadM = 0,
    this.designFlow = 0,
    this.maxFlow = 0,
    this.waterLevelOffsetM = 0,
    this.reservoir,
  });
  @override
  Pt position;
  bool calculatePressure;
  double designHeadM;
  double maxHeadM;
  double designFlow;
  double maxFlow;

  /// Static water level relative to ground (tank +, well −).
  double waterLevelOffsetM;

  /// 1.6.0 MOT: the reservoir or dam whose water the supply takes (its
  /// outline, basin and levels, PRD-16); null = a supply of fixed level.
  ReservoirSpec? reservoir;
  @override
  EntityType get type => EntityType.waterSupply;
  @override
  WaterSupplyEntity clone({String? newId}) => WaterSupplyEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    calculatePressure: calculatePressure,
    designHeadM: designHeadM,
    maxHeadM: maxHeadM,
    designFlow: designFlow,
    maxFlow: maxFlow,
    waterLevelOffsetM: waterLevelOffsetM,
    reservoir: reservoir?.copy(),
  )..extra = extra;
  @override
  WaterSupplyEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  WaterSupplyEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'calc': calculatePressure,
    'dh': designHeadM,
    'mh': maxHeadM,
    'dq': designFlow,
    'mq': maxFlow,
    'wl': waterLevelOffsetM,
    if (reservoir != null) 'res': reservoir!.toJson(),
  };
}

class PumpEntity extends Entity with PointEntity {
  PumpEntity({
    required super.id,
    super.layer = Layers.pumps,
    super.name,
    required this.position,
    this.pumpSpecId,
    this.speedRatio = 1,
    this.orientationDeg = 0,
    this.scope = HydraulicScope.mainline,
    this.hourMeter = false,
    this.hourMeterCost = 0,
    this.targetPressureM = 0,
    this.minSpeedRatio = 0.5,
    this.motorEfficiency = 1,
    this.station,
    this.flywheelKgm2 = 0,
  });
  @override
  Pt position;
  String? pumpSpecId;
  double speedRatio;
  double orientationDeg;
  HydraulicScope scope;

  /// 1.6.0 MOT: the other pumps of a pump station this item stands for (in
  /// parallel or in series, on duty or on standby); null = a single pump.
  PumpStation? station;

  /// 1.6.0 MOT: moment of inertia (kg·m²) of a flywheel fitted to the pump
  /// against the water hammer: added to that of the pump and its motor in
  /// the transient study, it slows the run-down after a power failure.
  double flywheelKgm2;

  /// Efficiency (0–1) of the motor and of its drive, from the wire to the
  /// pump shaft: the energy divides by it as well as by the pump's own
  /// efficiency. 1 = the pump efficiency stands for the whole set.
  double motorEfficiency;

  /// An hour meter on the pump panel (operating hours, asked by water-use
  /// permits), with its price for the bill of materials.
  bool hourMeter;
  double hourMeterCost;

  /// Variable-speed drive keeping this pressure (m) at the pump outlet in
  /// every system flow, between [minSpeedRatio] and [speedRatio]; 0 = fixed
  /// speed.
  double targetPressureM;
  double minSpeedRatio;
  @override
  EntityType get type => EntityType.pump;
  @override
  PumpEntity clone({String? newId}) => PumpEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    pumpSpecId: pumpSpecId,
    speedRatio: speedRatio,
    orientationDeg: orientationDeg,
    scope: scope,
    hourMeter: hourMeter,
    hourMeterCost: hourMeterCost,
    targetPressureM: targetPressureM,
    minSpeedRatio: minSpeedRatio,
    motorEfficiency: motorEfficiency,
    station: station?.copy(),
    flywheelKgm2: flywheelKgm2,
  )..extra = extra;
  @override
  PumpEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  PumpEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    if (pumpSpecId != null) 'spec': pumpSpecId,
    'speed': speedRatio,
    'rot': orientationDeg,
    'scope': scope.name,
    if (hourMeter) 'hm': hourMeterCost,
    if (targetPressureM > 0) 'vfd': targetPressureM,
    if (targetPressureM > 0) 'vmin': minSpeedRatio,
    if (motorEfficiency != 1) 'meff': motorEfficiency,
    if (station case final s? when !s.isEmpty || s.extra != null) 'stn': s.toJson(),
    if (flywheelKgm2 > 0) 'fly': flywheelKgm2,
  };
}

class MiscHydraulicEntity extends Entity with PointEntity {
  MiscHydraulicEntity({
    required super.id,
    super.layer = Layers.misc,
    super.name,
    required this.position,
    this.valveSpecId,
    this.scope = HydraulicScope.mainline,
    this.settingM = 0,
    this.orientationDeg = 0,
    this.settingFlow = 0,
    this.pilot = ValvePilot.none,
    this.pilotReduceM = 0,
    this.pilotSustainM = 0,
  });
  @override
  Pt position;
  String? valveSpecId;
  HydraulicScope scope;

  /// 1.6.0 MOT: the pilot of a valve of any kind (a master or control
  /// valve of the mainline): reducing (it then works as a PRV set to
  /// [pilotReduceM], 0 = the model's setting), sustaining (a PSV set to
  /// [pilotSustainM]) or both, the sustaining part first.
  ValvePilot pilot;
  double pilotReduceM;
  double pilotSustainM;

  /// Pressure setting (m): downstream of a PRV, upstream of a PSV.
  double settingM;
  double orientationDeg;

  /// Flow an FCV (hydrant flow limiter) lets through (m³/s; 0 = the valve's
  /// maximum flow).
  double settingFlow;
  @override
  EntityType get type => EntityType.misc;
  @override
  MiscHydraulicEntity clone({String? newId}) => MiscHydraulicEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    valveSpecId: valveSpecId,
    scope: scope,
    settingM: settingM,
    orientationDeg: orientationDeg,
    settingFlow: settingFlow,
    pilot: pilot,
    pilotReduceM: pilotReduceM,
    pilotSustainM: pilotSustainM,
  )..extra = extra;
  @override
  MiscHydraulicEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  MiscHydraulicEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    if (valveSpecId != null) 'spec': valveSpecId,
    'scope': scope.name,
    'set': settingM,
    'rot': orientationDeg,
    if (settingFlow > 0) 'setq': settingFlow,
    if (pilot != ValvePilot.none) 'pilot': pilot.name,
    if (pilotReduceM > 0) 'pr': pilotReduceM,
    if (pilotSustainM > 0) 'ps': pilotSustainM,
  };
}

class JunctionEntity extends Entity with PointEntity {
  JunctionEntity({
    required super.id,
    super.layer = Layers.junctions,
    super.name,
    required this.position,
    this.scope = HydraulicScope.zone,
    this.fixedElevation,
    this.vesselLiters = 0,
    this.vesselGasLiters = 0,
    this.vesselConnectionMm = 100,
    this.vesselCost = 0,
  });
  @override
  Pt position;
  HydraulicScope scope;
  double? fixedElevation;

  /// 1.6.0 MOT: an air vessel (hydropneumatic tank) at the junction, against
  /// the water hammer (PRD-31): its volume (L; 0 = none), the gas it holds
  /// in the steady state (L; 0 = a third of the volume), the bore of its
  /// connection (mm) and its price for the bill of materials.
  double vesselLiters;
  double vesselGasLiters;
  double vesselConnectionMm;
  double vesselCost;

  /// Whether the junction holds an air vessel.
  bool get hasVessel => vesselLiters > 0;
  @override
  EntityType get type => EntityType.junction;
  @override
  JunctionEntity clone({String? newId}) => JunctionEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    scope: scope,
    fixedElevation: fixedElevation,
    vesselLiters: vesselLiters,
    vesselGasLiters: vesselGasLiters,
    vesselConnectionMm: vesselConnectionMm,
    vesselCost: vesselCost,
  )..extra = extra;
  @override
  JunctionEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  JunctionEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'scope': scope.name,
    if (fixedElevation != null) 'z': fixedElevation,
    if (vesselLiters > 0) 'vl': vesselLiters,
    if (vesselLiters > 0 && vesselGasLiters > 0) 'vg': vesselGasLiters,
    if (vesselLiters > 0 && vesselConnectionMm != 100) 'vd': vesselConnectionMm,
    if (vesselLiters > 0 && vesselCost > 0) 'vc': vesselCost,
  };
}

/// Centre pivot or linear-move machine: a demand point on the mainline whose
/// flow and required inlet pressure come from the machine hydraulics
/// (see `design/pivot.dart`). Drawn as the irrigated circle (or strip), the
/// span pipe and its towers.
class PivotEntity extends Entity {
  PivotEntity({
    required super.id,
    super.layer = Layers.pivots,
    super.name,
    required this.center,
    this.radiusM = 400,
    this.angleDeg = 0,
    this.kind = PivotKind.pivot,
    this.travelM = 0,
    this.spanLengthM = 50,
    this.pipeSpecId,
    this.pipeInnerMm = 162,
    this.hazenC = 130,
    this.pipeHeightM = 3.5,
    this.endPressureM = 14,
    this.endGunFlow = 0,
    this.endGunPressureM = 0,
    this.endThrowM = 5,
    this.grossDepthMm = 8,
    this.hoursPerCycle = 24,
    this.wettedWidthM = 18,
    this.machineLossM = 2,
    this.maxAppRateMmH = 0,
    this.sectorDeg = 360,
    this.machineCost = 0,
    this.zoneName = '',
    this.sprinklerSpacingM = 2.5,
    this.sprinklerSpecId,
    this.regulatorSpecId,
    this.towerCost = 0,
    PivotMachine? machine,
  }) : machine = machine ?? PivotMachine();

  /// Package, drive, corner arm, variable rate and electrical data.
  PivotMachine machine;

  /// Sprinkler package: spacing along the span, catalogue sprinkler and
  /// pressure regulator (bill of materials and sprinkler chart).
  double sprinklerSpacingM;
  String? sprinklerSpecId;
  String? regulatorSpecId;

  /// Price of one tower (span + drive), for the bill of materials.
  double towerCost;

  /// Pivot point (inlet) — a mainline node.
  Pt center;

  /// Span pipe length to the last sprinkler (m).
  double radiusM;

  /// Drawing angle of the span (pivot) or of the lateral (linear), degrees.
  double angleDeg;
  PivotKind kind;

  /// Linear only: travel length perpendicular to the lateral (m).
  double travelM;
  double spanLengthM;

  /// Catalogue pipe for the spans (null: use [pipeInnerMm] / [hazenC]).
  String? pipeSpecId;
  double pipeInnerMm;
  double hazenC;
  double pipeHeightM;
  double endPressureM;

  /// End gun flow (m³/s) and pressure (m); 0 = no end gun.
  double endGunFlow;
  double endGunPressureM;
  double endThrowM;
  double grossDepthMm;
  double hoursPerCycle;
  double wettedWidthM;
  double machineLossM;
  double maxAppRateMmH;
  double sectorDeg;

  /// Machine price for the bill of materials (0 = not costed).
  double machineCost;
  String zoneName;

  double get irrigatedRadius => radiusM + endThrowM;
  double get angleRad => degToRad(angleDeg);
  Pt get direction => Pt.polar(1, angleRad);

  /// Far end of the span pipe (the radius grip).
  Pt get endPoint => center + direction * radiusM;

  /// Irrigated outline (circle / sector for a pivot, rectangle for a linear).
  List<Pt> outline([int segments = 72]) {
    if (kind == PivotKind.linear) {
      final along = direction * irrigatedRadius, across = direction.perpendicular * travelM;
      return [center, center + along, center + along + across, center + across];
    }
    final sweep = degToRad(sectorDeg.clamp(1.0, 360.0));
    final full = sweep >= 2 * math.pi - 1e-9;
    final start = full ? 0.0 : angleRad - sweep / 2;
    final n = math.max(8, (segments * sweep / (2 * math.pi)).round());
    return [if (!full) center, for (var i = 0; i <= n; i++) center + Pt.polar(irrigatedRadius, start + sweep * i / n)];
  }

  /// Tower positions along the drawn span.
  List<Pt> towerPositions() {
    if (spanLengthM <= 0) return const [];
    final n = math.max(1, (radiusM / spanLengthM).floor());
    return [for (var i = 1; i <= n; i++) center + direction * (i * spanLengthM)];
  }

  @override
  EntityType get type => EntityType.pivot;
  @override
  Bounds get bounds => Bounds.ofPoints(outline(24)).include(center);
  @override
  double distanceTo(Pt p) {
    final dc = p.distanceTo(center);
    if (kind == PivotKind.pivot) {
      // pivot point, span line or the outline circle
      return math.min(math.min(dc, distanceToSegment(p, center, endPoint)), (dc - irrigatedRadius).abs());
    }
    final o = outline();
    var best = math.min(dc, distanceToSegment(p, center, endPoint));
    for (var i = 0; i < o.length; i++) {
      best = math.min(best, distanceToSegment(p, o[i], o[(i + 1) % o.length]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [center, endPoint];
  @override
  void setGrip(int index, Pt p) {
    if (index == 0) {
      center = p;
    } else {
      final d = p - center;
      if (d.length > 1e-6) {
        radiusM = d.length;
        angleDeg = radToDeg(d.angle);
      }
    }
  }

  @override
  PivotEntity clone({String? newId}) => PivotEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    center: center,
    radiusM: radiusM,
    angleDeg: angleDeg,
    kind: kind,
    travelM: travelM,
    spanLengthM: spanLengthM,
    pipeSpecId: pipeSpecId,
    pipeInnerMm: pipeInnerMm,
    hazenC: hazenC,
    pipeHeightM: pipeHeightM,
    endPressureM: endPressureM,
    endGunFlow: endGunFlow,
    endGunPressureM: endGunPressureM,
    endThrowM: endThrowM,
    grossDepthMm: grossDepthMm,
    hoursPerCycle: hoursPerCycle,
    wettedWidthM: wettedWidthM,
    machineLossM: machineLossM,
    maxAppRateMmH: maxAppRateMmH,
    sectorDeg: sectorDeg,
    machineCost: machineCost,
    zoneName: zoneName,
    sprinklerSpacingM: sprinklerSpacingM,
    sprinklerSpecId: sprinklerSpecId,
    regulatorSpecId: regulatorSpecId,
    towerCost: towerCost,
    machine: machine.clone(),
  )..extra = extra;
  @override
  PivotEntity translated(Pt d) => clone()
    ..center = center + d
    ..extra = extra;
  @override
  PivotEntity transformed(Affine t) => clone()
    ..center = t.apply(center)
    ..radiusM = radiusM * t.scale
    ..travelM = travelM * t.scale
    ..angleDeg = _rotDeg(t, angleDeg)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': center.toList(),
    'r': radiusM,
    'ang': angleDeg,
    'kind': kind.name,
    if (travelM > 0) 'travel': travelM,
    'span': spanLengthM,
    if (pipeSpecId != null) 'spec': pipeSpecId,
    'idmm': pipeInnerMm,
    'c': hazenC,
    'hp': pipeHeightM,
    'hend': endPressureM,
    if (endGunFlow > 0) 'qg': endGunFlow,
    if (endGunPressureM > 0) 'hg': endGunPressureM,
    'throw': endThrowM,
    'depth': grossDepthMm,
    'hours': hoursPerCycle,
    'ww': wettedWidthM,
    'hm': machineLossM,
    if (maxAppRateMmH > 0) 'imax': maxAppRateMmH,
    if (sectorDeg != 360) 'sector': sectorDeg,
    if (machineCost > 0) 'cost': machineCost,
    if (zoneName.isNotEmpty) 'zone': zoneName,
    'ssp': sprinklerSpacingM,
    if (sprinklerSpecId != null) 'sspec': sprinklerSpecId,
    if (regulatorSpecId != null) 'rspec': regulatorSpecId,
    if (towerCost > 0) 'tcost': towerCost,
    if (!machine.isDefault) 'mach': machine.toJson(),
  };
}

class AreaEntity extends Entity with PolyEntity {
  AreaEntity({
    required super.id,
    super.layer = Layers.areas,
    super.name,
    required this.points,
    this.netDepthMmPerDay = 5,
    this.efficiency = 0.9,
    this.crop = '',
    this.emittersPerPlant = 0,
    this.useWaterBalance = false,
    this.etoMmDay = 5,
    this.kc = 1,
    this.awcMmPerM = 120,
    this.rootDepthM = 0.6,
    this.mad = 0.5,
    this.plantSpacingM = 0,
    this.rowSpacingM = 0,
    this.wettedFraction = 1,
    this.cropKey = '',
    this.plantingMonthDay = '',
    this.soilKey = '',
    this.slopePct = 0,
    this.irrigationMethod = 'sprinkler',
    this.groundCover = 1,
    this.ecwDsM = 0,
    this.rainMethod = 'usdaScs',
    this.useDependableRain = false,
    this.plantWaterUse = '',
    this.localizedKr = 0,
    this.yieldPotentialPct = 100,
    this.climateKc = true,
    // 1.6.0 MOD
    List<List<Pt>>? holes,
    // 1.7.0 ROW
    this.rowDirectionDeg,
  }) : holes = holes ?? [];
  @override
  List<Pt> points;

  /// Islands inside the outline that are not irrigated (a pond, a building,
  /// a bed of other plants): closed polygons of at least three vertices
  /// within [points]. [area] leaves them out, [contains] is false in them
  /// and the layout keeps the heads out of them (1.6.0 MOD).
  List<List<Pt>> holes;
  double netDepthMmPerDay;

  /// Crop of the FAO-56 table (`crop.*`; '' = the free-text [crop] with a
  /// single Kc) and its planting or green-up date (`MM-DD`; '' = the table's
  /// planting month), for the requirement by month and growth stage.
  String cropKey;
  String plantingMonthDay;

  /// Soil texture class (`soil.*`; '' = typed values) and ground slope (%).
  String soilKey;
  double slopePct;

  /// `sprinkler`, `localized` or `surface`: the leaching formula and, for
  /// localized irrigation, the ground-cover reduction of Kc.
  String irrigationMethod;

  /// Fraction of the ground shaded by the crop (localized irrigation Kr).
  double groundCover;

  /// Salinity of the irrigation water (dS/m; 0 = no leaching).
  double ecwDsM;

  /// Effective rain method (`EffectiveRainMethod` name) and whether the
  /// dependable rain replaces the mean.
  String rainMethod;
  bool useDependableRain;

  /// Water use of the plants of a landscape hydrozone (`veryLow`, `low`,
  /// `moderate`, `high`; '' = not a hydrozone), for the water budget.
  String plantWaterUse;
  double efficiency;
  String crop;

  /// Emitters per plant for the EU formula (0 = project default).
  int emittersPerPlant;

  /// Agronomy (crop water requirement and soil water balance).
  bool useWaterBalance;
  double etoMmDay;
  double kc;

  /// Available water capacity of the soil (mm per metre of depth).
  double awcMmPerM;
  double rootDepthM;

  /// Management allowed depletion (fraction).
  double mad;
  double plantSpacingM;
  double rowSpacingM;

  /// Direction of the planting rows, degrees counter-clockwise from the x
  /// axis in [0, 180) (read from the aerial image, 1.7.0 ROW); null when not
  /// set. With [rowSpacingM] the default of the laterals of Field blocks,
  /// Tree rings and Block over the area.
  double? rowDirectionDeg;

  /// Fraction of the area wetted (localized irrigation).
  double wettedFraction;

  /// Localized irrigation reduction factor Kr typed by the designer (0 =
  /// from [groundCover]).
  double localizedKr;

  /// Yield potential (%) whose soil salinity sets the leaching requirement
  /// (FAO-29; 100 = no yield loss).
  double yieldPotentialPct;

  /// Adjust Kc mid and Kc end of a crop of the FAO-56 table to the minimum
  /// humidity and wind of the site climate (FAO-56 eqs. 62 and 65).
  bool climateKc;

  /// Irrigated surface (m²): the outline less its [holes].
  double get area {
    final gross = grossArea;
    if (holes.isEmpty) return gross;
    final islands = holes.fold(0.0, (s, h) => s + (h.length >= 3 ? polygonArea(h).abs() : 0.0));
    return math.max(0.0, gross - islands);
  }

  /// Surface inside the outline, the [holes] included (m²).
  double get grossArea => polygonArea(points).abs();

  /// Whether [p] lies inside one of the [holes] (on its outline, where the
  /// heads round an island stand, it does not).
  bool inHole(Pt p) {
    for (final h in holes) {
      if (h.length >= 3 && pointInPolygon(p, h) && !pointOnPolygonBoundary(p, h, tol: 0.01)) return true;
    }
    return false;
  }

  /// Whether [p] lies in the irrigated area: inside the outline and in none
  /// of the [holes].
  bool contains(Pt p) => pointInPolygon(p, points) && !inHole(p);

  /// Crop evapotranspiration ETc = ETo·Kc (mm/day).
  double get etcMmDay => etoMmDay * kc;

  /// Net depth per day actually used by the reports (balance or fixed).
  double get effectiveNetDepthMmPerDay => useWaterBalance ? etcMmDay : netDepthMmPerDay;
  @override
  EntityType get type => EntityType.area;
  @override
  double distanceTo(Pt p) {
    if (contains(p)) return 0;
    var d = math.min(super.distanceTo(p), points.length > 2 ? distanceToSegment(p, points.last, points.first) : double.infinity);
    // a click in a hole picks the area only near the hole's outline
    for (final h in holes) {
      for (var i = 0; i < h.length; i++) {
        d = math.min(d, distanceToSegment(p, h[i], h[(i + 1) % h.length]));
      }
    }
    return d;
  }

  @override
  AreaEntity clone({String? newId}) => AreaEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    points: List.of(points),
    netDepthMmPerDay: netDepthMmPerDay,
    efficiency: efficiency,
    crop: crop,
    emittersPerPlant: emittersPerPlant,
    useWaterBalance: useWaterBalance,
    etoMmDay: etoMmDay,
    kc: kc,
    awcMmPerM: awcMmPerM,
    rootDepthM: rootDepthM,
    mad: mad,
    plantSpacingM: plantSpacingM,
    rowSpacingM: rowSpacingM,
    wettedFraction: wettedFraction,
    cropKey: cropKey,
    plantingMonthDay: plantingMonthDay,
    soilKey: soilKey,
    slopePct: slopePct,
    irrigationMethod: irrigationMethod,
    groundCover: groundCover,
    ecwDsM: ecwDsM,
    rainMethod: rainMethod,
    useDependableRain: useDependableRain,
    plantWaterUse: plantWaterUse,
    localizedKr: localizedKr,
    yieldPotentialPct: yieldPotentialPct,
    climateKc: climateKc,
    holes: [for (final h in holes) List.of(h)],
    rowDirectionDeg: rowDirectionDeg,
  )..extra = extra;
  @override
  AreaEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..holes = [for (final h in holes) h.map((p) => p + d).toList()]
    ..extra = extra;
  @override
  AreaEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..holes = [for (final h in holes) _map(h, t)]
    // 1.7.0 ROW: the rows turn (and mirror) with the area
    ..rowDirectionDeg = rowDirectionDeg == null ? null : (radToDeg(t.transformAngle(degToRad(rowDirectionDeg!))) % 180 + 180) % 180
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'pts': _ptsJson(points),
    // 1.6.0 MOD: written only when the area has islands
    if (holes.isNotEmpty) 'holes': [for (final h in holes) _ptsJson(h)],
    'depth': netDepthMmPerDay,
    'eff': efficiency,
    'crop': crop,
    if (emittersPerPlant > 0) 'epp': emittersPerPlant,
    if (useWaterBalance) 'wb': true,
    'eto': etoMmDay,
    'kc': kc,
    'awc': awcMmPerM,
    'root': rootDepthM,
    'mad': mad,
    if (plantSpacingM > 0) 'psp': plantSpacingM,
    if (rowSpacingM > 0) 'rsp': rowSpacingM,
    if (wettedFraction != 1) 'wf': wettedFraction,
    if (cropKey.isNotEmpty) 'ck': cropKey,
    if (plantingMonthDay.isNotEmpty) 'pd': plantingMonthDay,
    if (soilKey.isNotEmpty) 'soil': soilKey,
    if (slopePct != 0) 'slope': slopePct,
    if (irrigationMethod != 'sprinkler') 'im': irrigationMethod,
    if (groundCover != 1) 'gc': groundCover,
    if (ecwDsM > 0) 'ecw': ecwDsM,
    if (rainMethod != 'usdaScs') 'erm': rainMethod,
    if (useDependableRain) 'dep': true,
    if (plantWaterUse.isNotEmpty) 'pwu': plantWaterUse,
    if (localizedKr > 0) 'kr': localizedKr,
    if (yieldPotentialPct != 100) 'yp': yieldPotentialPct,
    if (!climateKc) 'kcc': false,
    if (rowDirectionDeg != null) 'rdir': rowDirectionDeg,
  };
}

// ---------------------------------------------------------------- electrical

/// Irrigation controller (timer): powers the valve solenoids through the
/// wire routes drawn from it; every valve reached gets a station.
/// Sensors and accessories a controller can have (keys of
/// [ControllerEntity.accessories], translated as `acc.<kind>`).
const controllerAccessoryKinds = ['rain', 'soil', 'flow', 'freeze', 'wind', 'pumpRelay', 'surge'];

class ControllerEntity extends Entity with PointEntity {
  ControllerEntity({
    required super.id,
    super.layer = Layers.controllers,
    super.name,
    required this.position,
    this.stations = 12,
    this.outputVolts = 24,
    this.cost = 0,
    this.maxSimultaneous = 0,
    this.stationMaxA = 0,
    this.totalMaxA = 0,
    Map<String, double>? accessories,
  }) : accessories = accessories ?? {};
  @override
  Pt position;

  /// Stations (valve outputs) of the controller.
  int stations;

  /// Output voltage (V AC) under load.
  double outputVolts;

  /// Price for the bill of materials (0 = not costed).
  double cost;

  /// Most stations the controller opens at once (0 = as the system flows
  /// say): the common wire carries their currents together.
  int maxSimultaneous;

  /// Largest current one station output and the whole controller deliver
  /// (A; 0 = the typical values of 24 V AC controllers, see
  /// `electrical.dart`).
  double stationMaxA;
  double totalMaxA;

  /// Sensors and accessories fitted (rain, soil moisture, flow, freeze and
  /// wind sensors, pump start relay, surge protection; see
  /// [controllerAccessoryKinds]) with their prices for the bill of materials.
  final Map<String, double> accessories;
  @override
  EntityType get type => EntityType.controller;
  @override
  ControllerEntity clone({String? newId}) => ControllerEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    position: position,
    stations: stations,
    outputVolts: outputVolts,
    cost: cost,
    maxSimultaneous: maxSimultaneous,
    stationMaxA: stationMaxA,
    totalMaxA: totalMaxA,
    accessories: Map.of(accessories),
  )..extra = extra;
  @override
  ControllerEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  ControllerEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'st': stations,
    'v': outputVolts,
    if (cost > 0) 'cost': cost,
    if (maxSimultaneous > 0) 'sim': maxSimultaneous,
    if (stationMaxA > 0) 'ist': stationMaxA,
    if (totalMaxA > 0) 'itot': totalMaxA,
    if (accessories.isNotEmpty) 'acc': accessories,
  };
}

/// Wire route (trench or conduit) from a controller towards the valves:
/// routes sharing a vertex connect, and a controller or valve on a vertex
/// or on the route joins it. Each valve reached gets its own station
/// conductor along the route and shares the common conductor.
class WireEntity extends Entity with PolyEntity {
  WireEntity({required super.id, super.layer = Layers.wires, super.name, required this.points});
  @override
  List<Pt> points;
  @override
  EntityType get type => EntityType.wire;
  @override
  WireEntity clone({String? newId}) => WireEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points))..extra = extra;
  @override
  WireEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  WireEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points)};
}

/// Ordinate dimension: the X (or Y) coordinate of [point] measured from
/// [origin], written at the end of a leader from the point to [leaderEnd].
class OrdinateDimensionEntity extends Entity {
  OrdinateDimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.point, required this.leaderEnd, this.origin = Pt.zero, this.xAxis = true});
  Pt point, leaderEnd, origin;

  /// Measures X (datum along the vertical axis) when true, else Y.
  bool xAxis;
  @override
  EntityType get type => EntityType.ordinateDimension;

  /// The coordinate written by the dimension.
  double get value => xAxis ? point.x - origin.x : point.y - origin.y;

  /// Leader from the point: straight out along the measured axis' normal,
  /// with a jog when the text was moved sideways.
  List<Pt> get leader {
    if (xAxis) {
      final mid = Pt(point.x, point.y + (leaderEnd.y - point.y) * 0.6);
      return [point, mid, Pt(leaderEnd.x, mid.y + (leaderEnd.y - point.y) * 0.1), leaderEnd];
    }
    final mid = Pt(point.x + (leaderEnd.x - point.x) * 0.6, point.y);
    return [point, mid, Pt(mid.x + (leaderEnd.x - point.x) * 0.1, leaderEnd.y), leaderEnd];
  }

  @override
  Bounds get bounds => Bounds.ofPoints([point, leaderEnd]);
  @override
  double distanceTo(Pt p) {
    final l = leader;
    var best = double.infinity;
    for (var i = 1; i < l.length; i++) {
      best = math.min(best, distanceToSegment(p, l[i - 1], l[i]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [point, leaderEnd];
  @override
  void setGrip(int index, Pt p) => index == 0 ? point = p : leaderEnd = p;
  @override
  OrdinateDimensionEntity clone({String? newId}) => OrdinateDimensionEntity(id: newId ?? id, layer: layer, name: name, point: point, leaderEnd: leaderEnd, origin: origin, xAxis: xAxis)..extra = extra;
  @override
  OrdinateDimensionEntity translated(Pt d) => clone()
    ..point = point + d
    ..leaderEnd = leaderEnd + d
    ..extra = extra;
  @override
  OrdinateDimensionEntity transformed(Affine t) => clone()
    ..point = t.apply(point)
    ..leaderEnd = t.apply(leaderEnd)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': point.toList(), 'e': leaderEnd.toList(), if (origin != Pt.zero) 'o': origin.toList(), 'x': xAxis};
}

// ---------------------------------------------------------------- review

/// A note pinned to the drawing for the people reviewing it (client,
/// designer, installer): text, author, date and whether it was resolved.
/// It stays out of the hydraulics and the bill of materials.
class CommentEntity extends Entity with PointEntity {
  CommentEntity({required super.id, super.layer = Layers.comments, super.name, required this.position, this.text = '', this.author = '', this.date = '', this.resolved = false, this.photo = ''});
  @override
  Pt position;
  String text;
  String author;

  /// When it was written (`YYYY-MM-DD`).
  String date;
  bool resolved;

  /// A small JPEG of a photo taken at the place (a field photo of the pump,
  /// the well, a valve box), base64; '' without one.
  String photo;
  @override
  EntityType get type => EntityType.comment;
  @override
  CommentEntity clone({String? newId}) =>
      CommentEntity(id: newId ?? id, layer: layer, name: name, position: position, text: text, author: author, date: date, resolved: resolved, photo: photo)..extra = extra;
  @override
  CommentEntity translated(Pt d) => clone()
    ..position = position + d
    ..extra = extra;
  @override
  CommentEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'text': text,
    if (author.isNotEmpty) 'author': author,
    if (date.isNotEmpty) 'date': date,
    if (resolved) 'done': true,
    if (photo.isNotEmpty) 'photo': photo,
  };
}

/// Revision cloud: a closed outline drawn as a chain of arcs around what
/// changed in a revision, tagged with the revision [revision], its date and
/// a description (the revision table of the sheet lists them).
class RevisionCloudEntity extends Entity with PolyEntity {
  RevisionCloudEntity({required super.id, super.layer = Layers.revisions, super.name, required this.points, this.revision = '', this.date = '', this.description = '', this.arcLength = 0});
  @override
  List<Pt> points;
  String revision;
  String date;
  String description;

  /// Chord of each arc (m); 0 = from the size of the outline.
  double arcLength;
  @override
  EntityType get type => EntityType.revisionCloud;

  /// The arc chord used: [arcLength] or a twelfth of the outline's mean
  /// side, kept between 0.2 m and 50 m.
  double get effectiveArc {
    if (arcLength > 0) return arcLength;
    final b = bounds;
    return ((b.width + b.height) / 24).clamp(0.2, 50.0).toDouble();
  }

  /// The scalloped outline: every side cut into chords of about
  /// [effectiveArc], each bulging outwards as a half-circle-ish arc
  /// (sampled as polylines, closed).
  List<Pt> scallops({int segmentsPerArc = 6}) {
    if (points.length < 3) return List.of(points);
    final ring = [...points, points.first];
    // outwards = to the right of a counter-clockwise ring
    final ccw = polygonArea(points) > 0;
    final out = <Pt>[];
    final step = effectiveArc;
    for (var i = 1; i < ring.length; i++) {
      final a = ring[i - 1], b = ring[i];
      final len = a.distanceTo(b);
      if (len < 1e-9) continue;
      final n = math.max(1, (len / step).round());
      final dir = (b - a) / len;
      final normal = ccw ? Pt(dir.y, -dir.x) : Pt(-dir.y, dir.x);
      for (var k = 0; k < n; k++) {
        final p0 = a + dir * (len * k / n), p1 = a + dir * (len * (k + 1) / n);
        final chord = len / n;
        for (var j = 0; j < segmentsPerArc; j++) {
          final t = j / segmentsPerArc;
          final bulge = math.sin(math.pi * t) * chord * 0.35;
          out.add(Pt.lerp(p0, p1, t) + normal * bulge);
        }
      }
    }
    if (out.isNotEmpty) out.add(out.first);
    return out;
  }

  @override
  double distanceTo(Pt p) => math.min(super.distanceTo(p), points.length > 2 ? distanceToSegment(p, points.last, points.first) : double.infinity);
  @override
  RevisionCloudEntity clone({String? newId}) =>
      RevisionCloudEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), revision: revision, date: date, description: description, arcLength: arcLength)..extra = extra;
  @override
  RevisionCloudEntity translated(Pt d) => clone()
    ..points = points.map((p) => p + d).toList()
    ..extra = extra;
  @override
  RevisionCloudEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..arcLength = arcLength * t.scale
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'pts': _ptsJson(points),
    if (revision.isNotEmpty) 'rev': revision,
    if (date.isNotEmpty) 'date': date,
    if (description.isNotEmpty) 'desc': description,
    if (arcLength > 0) 'arc': arcLength,
  };
}

extension EntityKindX on Entity {
  bool get isHydraulic => switch (type) {
    EntityType.pipe ||
    EntityType.sprayline ||
    EntityType.tape ||
    EntityType.outlet ||
    EntityType.controlValve ||
    EntityType.waterSupply ||
    EntityType.pump ||
    EntityType.misc ||
    EntityType.junction ||
    EntityType.pivot ||
    // 1.6.0 AGB
    EntityType.traveller ||
    EntityType.furrows => true,
    _ => false,
  };

  /// Linear hydraulic entity that can be cut / split.
  bool get isLinearHydraulic => this is PipeEntity || this is SpraylineEntity || this is TapeEntity;

  HydraulicScope? get hydraulicScope => switch (this) {
    PipeEntity e => e.scope,
    SpraylineEntity _ => HydraulicScope.zone,
    TapeEntity _ => HydraulicScope.zone,
    OutletEntity e => e.scope,
    ControlValveEntity _ => null, // bridges both
    WaterSupplyEntity _ => HydraulicScope.mainline,
    PumpEntity e => e.scope,
    MiscHydraulicEntity e => e.scope,
    JunctionEntity e => e.scope,
    PivotEntity _ => HydraulicScope.mainline,
    // 1.6.0 AGB
    TravellerEntity _ || FurrowEntity _ => HydraulicScope.mainline,
    _ => null,
  };

  /// Polyline geometry usable for trim/extend/offset/intersections, or null.
  List<Pt>? get linearPoints => switch (this) {
    LineEntity l => [l.a, l.b],
    PolyEntity p => p.points,
    ArcEntity a => a.polyline(),
    _ => null,
  };

  bool get isClosedShape => switch (this) {
    PolylineEntity p => p.closed,
    AreaEntity _ || HatchEntity _ || RevisionCloudEntity _ => true,
    SplineEntity s => s.closed,
    _ => false,
  };
}
