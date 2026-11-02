/// Project document: settings, catalog, layers, entities and management.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../hydraulics/friction.dart';
import '../io/geo.dart';
import '../units.dart';
import 'blocks.dart';
import 'catalog.dart';
import 'currency.dart';
import 'deliverables.dart'; // 1.6.0 PRB
import 'entities.dart';
import 'geometry.dart';
import 'label_rules.dart';
import 'proposal_settings.dart';
import 'read_report.dart';
import 'scenario.dart';
import 'site_climate.dart';
import 'terrain.dart';

class Layer {
  Layer({required this.name, required this.color, this.visible = true, this.locked = false});
  final String name;
  int color;
  bool visible;
  bool locked;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;
  Map<String, dynamic> toJson() => {...?extra, 'name': name, 'color': color, 'visible': visible, 'locked': locked};
  static Layer fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final name = j['name'];
    if (name is! String || name.isEmpty) throw const FormatException('layer_name');
    return Layer(name: name, color: (j['color'] as num?)?.toInt() ?? Layers.defaultColors[name] ?? 0xFFB0BEC5, visible: j['visible'] as bool? ?? true, locked: j['locked'] as bool? ?? false)
      ..extra = j.unread;
  }
}

enum SizingMethod { lp, greedy }

/// How local losses enter the calculation: a percentage of the pipe length
/// (equivalent-length method) or the coefficients K of the bends and tees
/// found in the drawing.
enum MinorLossMethod { percent, fittings }

class DesignParameters {
  DesignParameters({
    this.units = Units.metric,
    this.frictionMethod = FrictionMethod.hazenWilliams,
    this.waterTempC = 20,
    this.maxZoneVelocity = 1.5,
    this.maxMainlineVelocity = 2.0,
    this.maxLateralVelocity = 2.0,
    this.minorLossPct = 5,
    this.applyMinorLosses = true,
    this.minorLossMethod = MinorLossMethod.percent,
    this.connectTolerance = 0.05,
    this.interestRate = 0.10,
    this.termYears = 10,
    this.powerCostPerKwh = 0.75,
    this.pumpEfficiency = 0.65,
    this.hoursPerYear = 2000,
    this.zoneHoursPerYear = 500,
    this.tradeCapitalVsRunning = true,
    this.maxLateralSizes = 1,
    this.maxSubmainSizes = 3,
    this.hazenCScale = 1.0,
    this.hazenCOffset = 0.0,
    this.terrainDensify = 5.0,
    this.currency = 'R\$',
    this.currencyCode = catalogPriceCurrency,
    this.sizingMethod = SizingMethod.lp,
    this.maxMainlineSizes = 3,
    this.emittersPerPlant = 1,
    this.maxNodesPerLateral = 100,
    this.flushingVelocity = 0.3,
    this.flushingMinEndHeadM = 1.0,
    this.checkSurge = true,
    this.valveClosureTimeS = 0,
    this.selectFittings = true,
    this.pipeStickLengthM = 6,
    this.maxZoneVariationPct = 0,
    this.terrainMethod = TerrainMethod.tin,
    this.solenoidInrushA = 0.37,
    this.solenoidHoldingA = 0.22,
    this.solenoidMinVolts = 20,
    this.wireSlackPct = 10,
    this.mainsHz = 60,
  });

  Units units;
  FrictionMethod frictionMethod;
  double waterTempC;
  double maxZoneVelocity;
  double maxMainlineVelocity;
  double maxLateralVelocity;

  /// Minor losses as a percentage of pipe length (equivalent length method).
  double minorLossPct;
  bool applyMinorLosses;

  /// Percentage of the length ([minorLossPct]) or K of the drawn fittings.
  MinorLossMethod minorLossMethod;
  double connectTolerance;
  double interestRate;
  int termYears;
  double powerCostPerKwh;
  double pumpEfficiency;
  double hoursPerYear;
  double zoneHoursPerYear;
  bool tradeCapitalVsRunning;
  int maxLateralSizes;
  int maxSubmainSizes;
  double hazenCScale;
  double hazenCOffset;
  double terrainDensify;

  /// Symbol shown next to the prices ([currencyCode] tells the currency).
  String currency;

  /// ISO 4217 code of every price of the project (catalogue, energy tariff,
  /// pivot costs); empty when unknown (a custom symbol in an old file).
  String currencyCode;

  /// Pipe sizing: linear programming ("LP design") or the greedy
  /// velocity + pressure-window method.
  SizingMethod sizingMethod;
  int maxMainlineSizes;

  /// Emitters per plant for the Keller-Karmeli EU (areas can override).
  int emittersPerPlant;

  /// Maximum lumped emitter nodes per lateral (commercial CADs use up to 200).
  int maxNodesPerLateral;

  /// Flushing analysis: target velocity at the tape end (m/s) and minimum
  /// pressure head kept at the open end (m).
  double flushingVelocity;
  double flushingMinEndHeadM;

  /// Water-hammer (Joukowsky) check of each pipe's pressure class.
  bool checkSurge;

  /// Valve closure time (s); 0 = instantaneous (worst case).
  double valveClosureTimeS;

  /// Automatic fitting selection for the BOM.
  bool selectFittings;

  /// Pipe stick length (m) used to count couplers; 0 = no couplers per stick.
  double pipeStickLengthM;

  /// Maximum allowed pressure variation in a zone (% of nominal; 0 = from the
  /// emitter flow tolerance only).
  double maxZoneVariationPct;

  /// Terrain interpolation: Delaunay TIN (DTM) or inverse distance weighting.
  TerrainMethod terrainMethod;

  /// Valve solenoids (24 V AC): current while opening (inrush) and once
  /// open (holding), in amperes, and the least voltage that opens them.
  double solenoidInrushA;
  double solenoidHoldingA;
  double solenoidMinVolts;

  /// Wire length added to the routes for splices and loops (%).
  double wireSlackPct;

  /// Frequency of the electricity mains (Hz): fixed-speed pumps whose curves
  /// were measured at another frequency turn proportionally slower or
  /// faster (PumpSpec.mainsSpeedRatio).
  double mainsHz;

  double get kinematicViscosity => waterKinematicViscosity(waterTempC);
  double adjustedC(double c) => c * hazenCScale + hazenCOffset;

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'units': units.toJson(),
    'method': frictionMethod.name,
    'temp': waterTempC,
    'vZone': maxZoneVelocity,
    'vMain': maxMainlineVelocity,
    'vLat': maxLateralVelocity,
    'minorPct': minorLossPct,
    'minor': applyMinorLosses,
    'minorMethod': minorLossMethod.name,
    'tol': connectTolerance,
    'interest': interestRate,
    'term': termYears,
    'kwh': powerCostPerKwh,
    'eff': pumpEfficiency,
    'hours': hoursPerYear,
    'zoneHours': zoneHoursPerYear,
    'trade': tradeCapitalVsRunning,
    'latSizes': maxLateralSizes,
    'subSizes': maxSubmainSizes,
    'cScale': hazenCScale,
    'cOffset': hazenCOffset,
    'densify': terrainDensify,
    'currency': currency,
    'currencyCode': currencyCode,
    'sizing': sizingMethod.name,
    'mainSizes': maxMainlineSizes,
    'epp': emittersPerPlant,
    'maxNodes': maxNodesPerLateral,
    'flushV': flushingVelocity,
    'flushH': flushingMinEndHeadM,
    'surge': checkSurge,
    'closure': valveClosureTimeS,
    'fittings': selectFittings,
    'stick': pipeStickLengthM,
    'zoneVar': maxZoneVariationPct,
    'terrain': terrainMethod.name,
    'inrushA': solenoidInrushA,
    'holdA': solenoidHoldingA,
    'minV': solenoidMinVolts,
    'slack': wireSlackPct,
    if (mainsHz != 60) 'hz': mainsHz,
  };

  /// Reads the parameters; options this version does not know take their
  /// default (noted in [report]) and unknown fields are kept in [extra].
  /// A missing key takes the value of a new project.
  static DesignParameters fromJson(Map<String, dynamic>? json, {ProjectReadReport? report}) {
    if (json == null) return DesignParameters();
    final j = KeyLog(json);
    double d(String k, double def) {
      final v = j[k];
      return v is num && v.isFinite ? v.toDouble() : def;
    }

    final units = j['units'];
    if (units is Map && report != null) {
      for (final (key, values) in [('length', LengthUnit.values), ('flow', FlowUnit.values), ('pressure', PressureUnit.values), ('diameter', DiameterUnit.values)]) {
        final v = units[key];
        if (v != null && !values.any((u) => u.name == v)) report.unknownValues.add('$key=$v');
      }
    }
    return DesignParameters(
      units: Units.fromJson(units is Map ? units.cast<String, dynamic>() : null),
      frictionMethod: enumByName(FrictionMethod.values, j['method'], FrictionMethod.hazenWilliams, report: report, key: 'method'),
      waterTempC: d('temp', 20),
      maxZoneVelocity: d('vZone', 1.5),
      maxMainlineVelocity: d('vMain', 2.0),
      maxLateralVelocity: d('vLat', 2.0),
      minorLossPct: d('minorPct', 5),
      applyMinorLosses: j['minor'] as bool? ?? true,
      minorLossMethod: MinorLossMethod.values.asNameMap()[j['minorMethod'] as String? ?? ''] ?? MinorLossMethod.percent,
      connectTolerance: d('tol', 0.05),
      interestRate: d('interest', 0.1),
      termYears: (j['term'] as num?)?.toInt() ?? 10,
      powerCostPerKwh: d('kwh', 0.75),
      pumpEfficiency: d('eff', 0.65),
      hoursPerYear: d('hours', 2000),
      zoneHoursPerYear: d('zoneHours', 500),
      tradeCapitalVsRunning: j['trade'] as bool? ?? true,
      maxLateralSizes: (j['latSizes'] as num?)?.toInt() ?? 1,
      maxSubmainSizes: (j['subSizes'] as num?)?.toInt() ?? 3,
      hazenCScale: d('cScale', 1),
      hazenCOffset: d('cOffset', 0),
      terrainDensify: d('densify', 5),
      currency: j['currency'] as String? ?? 'R\$',
      // files written before the code existed: tell it from the symbol
      currencyCode: j['currencyCode'] as String? ?? currencyCodeForSymbol(j['currency'] as String? ?? 'R\$') ?? '',
      sizingMethod: enumByName(SizingMethod.values, j['sizing'], SizingMethod.lp, report: report, key: 'sizing'),
      maxMainlineSizes: (j['mainSizes'] as num?)?.toInt() ?? 3,
      emittersPerPlant: (j['epp'] as num?)?.toInt() ?? 1,
      maxNodesPerLateral: (j['maxNodes'] as num?)?.toInt() ?? 100,
      flushingVelocity: d('flushV', 0.3),
      flushingMinEndHeadM: d('flushH', 1.0),
      checkSurge: j['surge'] as bool? ?? true,
      valveClosureTimeS: d('closure', 0),
      selectFittings: j['fittings'] as bool? ?? true,
      pipeStickLengthM: d('stick', 6),
      maxZoneVariationPct: d('zoneVar', 0),
      // files of version 1 without the key were interpolated by IDW (the
      // migration states it); a file without it now gets a new project's TIN
      terrainMethod: enumByName(TerrainMethod.values, j['terrain'], TerrainMethod.tin, report: report, key: 'terrain'),
      solenoidInrushA: d('inrushA', 0.37),
      solenoidHoldingA: d('holdA', 0.22),
      solenoidMinVolts: d('minV', 20),
      wireSlackPct: d('slack', 10),
      mainsHz: d('hz', 60),
    )..extra = j.unread;
  }
}

/// A set of zones operating simultaneously (a "system flow" or shift).
class SystemFlow {
  SystemFlow({required this.id, required this.name, Set<String>? valveIds, this.startHour = 0, this.durationHours = 1}) : valveIds = valveIds ?? <String>{};
  final String id;
  String name;

  /// What runs: zone valves and pivots (entity ids) and valve-in-head
  /// stations (the outlet id of a head of its own, `vih:<station name>` for
  /// heads sharing one; see `design/valve_in_head.dart`).
  final Set<String> valveIds;
  double startHour;
  double durationHours;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {...?extra, 'id': id, 'name': name, 'valves': valveIds.toList(), 'start': startHour, 'dur': durationHours};
  static SystemFlow fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final id = j['id'];
    if (id is! String || id.isEmpty) throw const FormatException('flow_id');
    return SystemFlow(
      id: id,
      name: j['name'] as String? ?? '',
      valveIds: {
        for (final v in (j['valves'] as List?) ?? const [])
          if (v is String) v,
      },
      startHour: (j['start'] as num?)?.toDouble() ?? 0,
      durationHours: (j['dur'] as num?)?.toDouble() ?? 1,
    )..extra = j.unread;
  }
}

class ProjectMeta {
  ProjectMeta({this.name = 'New project', this.client = '', this.site = '', this.designer = '', this.notes = '', this.georef, String? uid, DateTime? created, this.modified})
    : uid = uid ?? newUid(),
      created = created ?? DateTime.now();

  /// Stable identifier used by autosave, recent files and versions.
  String uid;
  DateTime created;
  DateTime? modified;

  static int _seq = 0;
  static String newUid() {
    _seq++;
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = (DateTime.now().hashCode ^ (_seq * 2654435761)).toUnsigned(32).toRadixString(36);
    return 'p$t$r';
  }

  String name;
  String client;
  String site;
  String designer;
  String notes;

  /// Set when data was imported from geographic coordinates (KML/KMZ).
  GeoReference? georef;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;
  Map<String, dynamic> toJson() => {
    ...?extra,
    'uid': uid,
    'created': created.toIso8601String(),
    if (modified != null) 'modified': modified!.toIso8601String(),
    'name': name,
    'client': client,
    'site': site,
    'designer': designer,
    'notes': notes,
    if (georef != null) 'georef': georef!.toJson(),
  };
  static ProjectMeta fromJson(Map<String, dynamic>? json, {ProjectReadReport? report}) {
    if (json == null) return ProjectMeta();
    final j = KeyLog(json);
    String text(String k) => j[k] is String ? j[k] as String : '';
    GeoReference? georef;
    final g = j['georef'];
    if (g is Map) {
      try {
        georef = GeoReference.fromJson(g.cast<String, dynamic>());
      } catch (_) {
        // a damaged georeference: the drawing opens without it
        report?.skip('georef');
      }
    }
    final uid = j['uid'];
    final meta = ProjectMeta(
      uid: uid is String && uid.isNotEmpty ? uid : null,
      created: DateTime.tryParse(text('created')),
      modified: DateTime.tryParse(text('modified')),
      name: text('name'),
      client: text('client'),
      site: text('site'),
      designer: text('designer'),
      notes: text('notes'),
      georef: georef,
    );
    var unread = j.unread;
    // kept as it was, so a later version can still read it
    if (g != null && georef == null) (unread ??= {})['georef'] = g;
    return meta..extra = unread;
  }
}

class Project {
  Project({
    ProjectMeta? meta,
    DesignParameters? params,
    Catalog? catalog,
    List<Layer>? layers,
    List<Entity>? entities,
    List<SystemFlow>? systemFlows,
    ProposalSettings? proposal,
    List<Scenario>? scenarios,
    this.climate,
    List<LabelRule>? labelRules,
    BlockLibrary? blocks,
    this.aiNotes = '',
    int nextId = 1,
    // 1.6.0 PRB
    DeliverableSettings? deliverables,
  }) : meta = meta ?? ProjectMeta(),
       deliverables = deliverables ?? DeliverableSettings(),
       proposal = proposal ?? ProposalSettings(),
       scenarios = scenarios ?? [],
       labelRules = labelRules ?? [],
       blocks = blocks ?? BlockLibrary(),
       params = params ?? DesignParameters(),
       catalog = catalog ?? Catalog.defaultCatalog(),
       layers = layers ?? defaultLayers(),
       entities = entities ?? [],
       systemFlows = systemFlows ?? [],
       // ignore: prefer_initializing_formals
       _nextId = nextId;

  static const formatName = 'opencadirrigation';
  static const legacyFormatName = 'irrigationcad';

  /// Version of the file layout written. 2: a missing key takes the value
  /// of a new project (version 1 files are read through [migrations]).
  static const formatVersion = 2;

  /// Upgrades of a file of version k to k + 1, applied in order on read to
  /// a copy of the file's JSON.
  static final migrations = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
    // version 1 files without the terrain key were written before the TIN
    // existed: they were interpolated by IDW
    1: (j) {
      final p = j['params'];
      if (p is Map && !p.containsKey('terrain')) j['params'] = {...p.cast<String, dynamic>(), 'terrain': TerrainMethod.idw.name};
      return j;
    },
  };

  /// Items of the file that could not be read, by section (`entities`,
  /// `layers`, `systemFlows`, `scenarios`, `labelRules`), kept as they were
  /// and written back under `unreadable`: every read tries them again, so a
  /// later version of the app that knows them gets them back.
  final Map<String, List<Object?>> unreadable = {};

  /// Top-level fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  ProjectMeta meta;
  DesignParameters params;
  Catalog catalog;
  List<Layer> layers;
  final List<Entity> entities;
  final List<SystemFlow> systemFlows;

  /// Commercial settings of the quote (Design → Quote).
  ProposalSettings proposal;

  /// Design alternatives saved for comparison (Design → Alternatives).
  final List<Scenario> scenarios;

  /// Conditional labels of the drawing (View → Conditional labels).
  final List<LabelRule> labelRules;

  /// User blocks (Edit → Save selection as block, Insert block).
  final BlockLibrary blocks;

  // 1.6.0 PRB: settings of the technical documents (permit table, memorial,
  // operation and maintenance plan, budget by compositions, life-cycle cost)
  DeliverableSettings deliverables;

  /// Notes the AI assistant keeps about this project (requirements,
  /// decisions, the designer's preferences); read at the start of a task.
  String aiNotes;

  /// Monthly climate normals of the site (Design → Site climate), for the
  /// crop water requirement and solar pumping.
  SiteClimate? climate;
  int _nextId;

  static List<Layer> defaultLayers() => [for (final n in Layers.all) Layer(name: n, color: Layers.defaultColors[n] ?? 0xFFFFFFFF)];

  String newId([String prefix = 'e']) => '$prefix${_nextId++}';
  int get nextIdValue => _nextId;

  /// Multiplies every price of the project by [factor]: catalogue costs, the
  /// energy tariff, the quote, the pivot machine and tower costs, the
  /// controller and its accessories and the pump hour meters (the money
  /// fields of the entities are listed in [entityMoneyKeys]). The
  /// alternatives follow in [setCurrency].
  void scalePrices(double factor) {
    if (factor == 1) return;
    scaleCatalogPrices(catalog, factor);
    params.powerCostPerKwh *= factor;
    proposal.scalePrices(factor);
    deliverables.scalePrices(factor); // 1.6.0 PRB
    for (final e in entities) {
      switch (e) {
        case PivotEntity p:
          p.machineCost *= factor;
          p.towerCost *= factor;
        case ControllerEntity c:
          c.cost *= factor;
          c.accessories.updateAll((_, v) => v * factor);
        case PumpEntity p:
          p.hourMeterCost *= factor;
        default:
          break;
      }
    }
  }

  /// The JSON keys of every entity field that holds money, by type: what
  /// [scalePrices] converts (a test fails when a new price field is left
  /// out).
  static const entityMoneyKeys = {
    EntityType.pivot: {'cost', 'tcost'},
    EntityType.controller: {'cost', 'acc'},
    EntityType.pump: {'hm'},
  };

  /// Switches the project to currency [code]; with [rate] (units of the new
  /// currency per unit of the old one) the prices are converted too, and so
  /// are the money figures and the projects of the alternatives (whose
  /// results, priced in the old currency, are dropped).
  void setCurrency(String code, {double? rate, String? symbol}) {
    if (rate != null) scalePrices(rate);
    params.currencyCode = code;
    params.currency = symbol ?? currencySymbol(code);
    for (final s in scenarios) {
      s.convertCurrency(code, params.currency, rate: rate);
    }
  }

  /// Raises the id counter so ids created elsewhere (a design job running in
  /// a worker) never collide with future ids.
  void ensureNextId(int value) {
    if (value > _nextId) _nextId = value;
  }

  /// Layer that new drawing entities go to.
  String currentLayer = Layers.drawing;

  Layer? findLayer(String name) {
    for (final l in layers) {
      if (l.name == name) return l;
    }
    return null;
  }

  /// Renames a layer and moves its entities. Returns false when the name exists.
  bool renameLayer(String from, String to) {
    final name = to.trim();
    if (name.isEmpty || findLayer(name) != null) return false;
    final i = layers.indexWhere((l) => l.name == from);
    if (i < 0) return false;
    final old = layers[i];
    layers[i] = Layer(name: name, color: old.color, visible: old.visible, locked: old.locked)..extra = old.extra;
    for (final e in entities) {
      if (e.layer == from) e.layer = name;
    }
    if (currentLayer == from) currentLayer = name;
    return true;
  }

  /// Removes a layer; its entities move to [target] (default DRAWING).
  void removeLayer(String name, {String target = Layers.drawing}) {
    if (name == target) return;
    layers.removeWhere((l) => l.name == name);
    layerNamed(target);
    for (final e in entities) {
      if (e.layer == name) e.layer = target;
    }
    if (currentLayer == name) currentLayer = target;
  }

  bool isLocked(String layer) => findLayer(layer)?.locked ?? false;

  Layer layerNamed(String name) {
    for (final l in layers) {
      if (l.name == name) return l;
    }
    final l = Layer(name: name, color: Layers.defaultColors[name] ?? 0xFFB0BEC5);
    layers.add(l);
    return l;
  }

  Entity? byId(String id) {
    for (final e in entities) {
      if (e.id == id) return e;
    }
    return null;
  }

  Iterable<T> ofType<T extends Entity>() => entities.whereType<T>();

  /// Catalogue ids the entities use: pipes, emitters, tapes, valves and
  /// devices, pumps, and the pipe, sprinklers, regulators and end gun of
  /// the pivots.
  Set<String> get catalogIdsInUse => {
    for (final e in entities)
      ...switch (e) {
        PipeEntity x => [?x.pipeSpecId],
        SpraylineEntity x => [?x.pipeSpecId, x.outletSpecId],
        TapeEntity x => [x.tapeSpecId],
        OutletEntity x => [x.outletSpecId],
        ControlValveEntity x => [?x.valveSpecId],
        MiscHydraulicEntity x => [?x.valveSpecId],
        PumpEntity x => [?x.pumpSpecId],
        PivotEntity x => [?x.pipeSpecId, ?x.sprinklerSpecId, ?x.regulatorSpecId, ?x.machine.endGunSpecId],
        _ => const <String>[],
      },
  };

  /// Whether the head [o] waters the area [poly] ([watersArea] with the arc
  /// its nozzle really covers).
  bool outletWatersArea(OutletEntity o, List<Pt> poly) {
    final nz = catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
    return watersArea(o.position, poly, arcDeg: nz?.effectiveArcDeg(o.arcDeg) ?? o.arcDeg, orientationDeg: o.orientationDeg);
  }

  Bounds get bounds {
    var b = Bounds.empty;
    for (final e in entities) {
      b = b.union(e.bounds);
    }
    return b;
  }

  /// Builds the DEM from contour and spot-height entities. The same model
  /// comes back while the terrain data and settings stay as they were, so a
  /// large survey is triangulated once, not on every query. Callers only
  /// read it.
  Terrain buildTerrain() {
    final key = <double>[params.terrainDensify, params.terrainMethod.index.toDouble()];
    for (final e in entities) {
      switch (e) {
        case ContourEntity c when !c.derived:
          key
            ..add(1)
            ..add(c.elevation)
            ..add(c.points.length.toDouble());
          for (final p in c.points) {
            key
              ..add(p.x)
              ..add(p.y);
          }
        case SpotHeightEntity s:
          key
            ..add(_isDemSpot(s) ? 3 : 2)
            ..add(s.position.x)
            ..add(s.position.y)
            ..add(s.elevation);
        case BreaklineEntity b:
          key
            ..add(4)
            ..add(b.points.length.toDouble());
          for (var i = 0; i < b.points.length; i++) {
            key
              ..add(b.points[i].x)
              ..add(b.points[i].y)
              ..add(b.elevationOf(i));
          }
        default:
          break;
      }
    }
    final cached = _terrain, cachedKey = _terrainKey;
    if (cached != null && cachedKey != null && cachedKey.length == key.length) {
      var same = true;
      for (var i = 0; i < key.length && same; i++) {
        final a = cachedKey[i], b = key[i];
        same = a == b || (a.isNaN && b.isNaN);
      }
      if (same) return cached;
    }
    final t = Terrain(densify: params.terrainDensify, method: params.terrainMethod);
    for (final e in entities) {
      if (e is ContourEntity && !e.derived) t.addContour(e.points, e.elevation);
      if (e is SpotHeightEntity) t.addSpot(e.position, e.elevation, dem: _isDemSpot(e));
      if (e is BreaklineEntity) t.addBreakline(e.points, [for (var i = 0; i < e.points.length; i++) e.elevationOf(i)]);
    }
    _terrain = t;
    _terrainKey = Float64List.fromList(key);
    return t;
  }

  static bool _isDemSpot(SpotHeightEntity s) => s.isDem || s.layer == Layers.dem;

  Terrain? _terrain;
  Float64List? _terrainKey;

  String uniqueZoneName([String prefix = 'Zone']) {
    final used = entities.whereType<ControlValveEntity>().map((v) => v.zoneName).toSet();
    var i = 1;
    while (used.contains('$prefix $i')) {
      i++;
    }
    return '$prefix $i';
  }

  Map<String, dynamic> toJson({bool includeEntities = true}) => {
    ...?extra,
    'format': formatName,
    'version': formatVersion,
    'meta': meta.toJson(),
    'params': params.toJson(),
    'catalog': catalog.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'entities': includeEntities ? entities.map((e) => e.toJson()).toList() : const [],
    'systemFlows': systemFlows.map((s) => s.toJson()).toList(),
    if (!proposal.isDefault) 'proposal': proposal.toJson(),
    if (scenarios.isNotEmpty) 'scenarios': [for (final x in scenarios) x.toJson()],
    if (climate != null) 'climate': climate!.toJson(),
    if (labelRules.isNotEmpty) 'labelRules': [for (final r in labelRules) r.toJson()],
    if (blocks.isNotEmpty) 'blocks': blocks.toJson(),
    if (aiNotes.isNotEmpty) 'aiNotes': aiNotes,
    if (!deliverables.isDefault) 'deliverables': deliverables.toJson(), // 1.6.0 PRB
    'nextId': _nextId,
    if (currentLayer != Layers.drawing) 'currentLayer': currentLayer,
    if (unreadable.isNotEmpty) 'unreadable': {for (final e in unreadable.entries) e.key: List.of(e.value)},
  };

  String toJsonString({bool pretty = false}) => encodeJson(toJson(), pretty: pretty);

  /// Top-level keys other parts of the app write beside the project (the
  /// design results of a saved file): not fields of the project itself.
  static const _companionKeys = {'results'};

  /// Reads a project file. The file opens item by item: an item that
  /// cannot be read (damaged, or of a newer version) is set aside in
  /// [unreadable], vertices without coordinates are dropped, repeated or
  /// missing entity ids get new ones, options this version does not know
  /// take their default and fields it does not know are kept; [report]
  /// lists the repairs. Files of an older layout are upgraded through
  /// [migrations]; a missing key takes the value of a new project. Throws a
  /// [FormatException] (`project_format`) only when [json] is no project.
  static Project fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final rep = report ?? ProjectReadReport();
    if (json['format'] != formatName && json['format'] != legacyFormatName) throw const FormatException('project_format');
    final version = json['version'] is num ? (json['version'] as num).toInt() : null;
    rep.fileVersion = version;
    var migrated = Map<String, dynamic>.of(json);
    if (version != null && version > formatVersion) rep.newerVersion = true;
    for (var v = version ?? formatVersion; v < formatVersion; v++) {
      migrated = migrations[v]?.call(migrated) ?? migrated;
    }
    final j = KeyLog(migrated);
    // read above, and rewritten by toJson
    j
      ..containsKey('format')
      ..containsKey('version');
    final aside = <String, List<Object?>>{};
    // the items of [section] (and those set aside last time, tried again)
    List<T> each<T>(String section, T Function(Map<String, dynamic>) read) {
      final out = <T>[];
      final retry = j['unreadable'] is Map ? (j['unreadable'] as Map)[section] : null;
      for (final list in [j[section], retry]) {
        if (list == null) continue;
        if (list is! List) {
          rep.skip(section);
          continue;
        }
        for (final x in list) {
          try {
            out.add(read((x as Map).cast<String, dynamic>()));
          } catch (_) {
            rep.skip(section);
            // kept for a later version (anything but an object is no item)
            if (x is Map) (aside[section] ??= []).add(x);
          }
        }
      }
      return out;
    }

    Map<String, dynamic>? object(String key) => j[key] is Map ? (j[key] as Map).cast<String, dynamic>() : null;
    final params = DesignParameters.fromJson(object('params'), report: rep);
    final entities = each('entities', (e) => Entity.fromJson(e, report: rep));
    // a file without the counter (written by hand or by another program)
    // or with a stale one must not hand out ids that are already taken
    var next = math.max((j['nextId'] as num?)?.toInt() ?? 1, nextIdAfter(entities));
    for (final raw in aside['entities'] ?? const []) {
      final m = _idNumber.firstMatch('${(raw as Map)['id']}');
      if (m != null) next = math.max(next, (int.tryParse(m.group(1)!) ?? 0) + 1);
    }
    // an id met twice (a merged or hand-written file) or missing: a new one
    final ids = <String>{};
    for (var i = 0; i < entities.length; i++) {
      if (entities[i].id.isNotEmpty && ids.add(entities[i].id)) continue;
      entities[i] = entities[i].clone(newId: 'e${next++}');
      ids.add(entities[i].id);
      rep.renumbered++;
    }
    final layers = each('layers', Layer.fromJson);
    Catalog catalog;
    final catJson = object('catalog');
    if (catJson != null) {
      catalog = Catalog.fromJson(catJson, report: rep);
    } else {
      // a file without its catalogue: a new project's, priced in the file's currency
      catalog = Catalog.defaultCatalog(currency: exchangeRate(catalogPriceCurrency, params.currencyCode) != null ? params.currencyCode : catalogPriceCurrency);
      if (j['catalog'] != null) rep.skip('catalog');
    }
    ProposalSettings proposal;
    try {
      proposal = ProposalSettings.fromJson(object('proposal'));
    } catch (_) {
      proposal = ProposalSettings();
      rep.skip('proposal');
    }
    SiteClimate? climate;
    try {
      climate = SiteClimate.fromJson(object('climate'));
    } catch (_) {
      rep.skip('climate');
    }
    BlockLibrary blocks;
    try {
      blocks = BlockLibrary.fromJson(j['blocks'] is List ? j['blocks'] as List : null);
    } catch (_) {
      blocks = BlockLibrary();
      rep.skip('blocks');
    }
    // 1.6.0 PRB
    final deliverables = DeliverableSettings.fromJson(object('deliverables'));
    if (j['deliverables'] != null && j['deliverables'] is! Map) rep.skip('deliverables');
    final p = Project(
      meta: ProjectMeta.fromJson(object('meta'), report: rep),
      params: params,
      catalog: catalog,
      layers: layers.isEmpty ? defaultLayers() : layers,
      entities: entities,
      systemFlows: each('systemFlows', SystemFlow.fromJson),
      proposal: proposal,
      scenarios: each('scenarios', Scenario.fromJson),
      climate: climate,
      labelRules: each('labelRules', LabelRule.fromJson),
      blocks: blocks,
      aiNotes: j['aiNotes'] is String ? j['aiNotes'] as String : '',
      nextId: next,
      deliverables: deliverables, // 1.6.0 PRB
    )..currentLayer = j['currentLayer'] is String ? j['currentLayer'] as String : Layers.drawing;
    p.unreadable.addAll(aside);
    _companionKeys.forEach(j.containsKey);
    var unread = j.unread;
    // sections that failed as a whole stay in the file as they were
    for (final k in ['proposal', 'climate', 'blocks', 'deliverables']) {
      if (rep.skipped.containsKey(k) && migrated[k] != null) (unread ??= {})[k] = migrated[k];
    }
    p.extra = unread;
    return p;
  }

  /// The first free number for [newId] given the ids of [entities]
  /// (`e<number>`).
  static int nextIdAfter(Iterable<Entity> entities) {
    var n = 1;
    for (final e in entities) {
      final m = _idNumber.firstMatch(e.id);
      if (m == null) continue;
      final v = int.tryParse(m.group(1)!);
      if (v != null && v >= n) n = v + 1;
    }
    return n;
  }

  static final _idNumber = RegExp(r'^e(\d{1,15})$');

  /// Reads a project file's text ([fromJson]); a text that is not JSON (cut
  /// short, damaged) throws a [FormatException] `project_json`.
  static Project fromJsonString(String s, {ProjectReadReport? report}) {
    final Object? j;
    try {
      j = jsonDecode(s);
    } on FormatException {
      throw const FormatException('project_json');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('project_format');
    return fromJson(j, report: report);
  }

  /// Deep copy via JSON (used for undo snapshots).
  Project copy() => fromJson(toJson());
}

/// A project file as read: the project, the design results the file keeps
/// beside it (JSON, null when none) and what reading it had to repair.
typedef ProjectFile = ({Project project, Map<String, dynamic>? results, ProjectReadReport report});

/// Reads the text of a project file (see [Project.fromJson]); throws a
/// [FormatException] `project_json` or `project_format` when it is no
/// project at all.
ProjectFile readProjectFile(String text) {
  final Object? j;
  try {
    j = jsonDecode(text);
  } on FormatException {
    throw const FormatException('project_json');
  }
  if (j is! Map<String, dynamic>) throw const FormatException('project_format');
  final report = ProjectReadReport();
  final p = Project.fromJson(j, report: report);
  final r = j['results'];
  return (project: p, results: r is Map<String, dynamic> ? r : null, report: report);
}

/// JSON text of [value] in which a number that is not finite (NaN, ±∞,
/// left by a damaged import or a failed calculation) is written as null,
/// instead of the whole project failing to save.
String encodeJson(Object? value, {bool pretty = false}) => JsonEncoder.withIndent(pretty ? '  ' : null, _finiteOrNull).convert(value);

Object? _finiteOrNull(Object? o) => o is double ? null : (o as dynamic).toJson();
