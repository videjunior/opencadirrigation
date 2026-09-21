/// Project document: settings, catalog, layers, entities and management.
library;

import 'dart:convert';

import '../hydraulics/friction.dart';
import '../io/geo.dart';
import '../units.dart';
import 'catalog.dart';
import 'currency.dart';
import 'entities.dart';
import 'geometry.dart';
import 'terrain.dart';

class Layer {
  Layer({required this.name, required this.color, this.visible = true, this.locked = false});
  final String name;
  int color;
  bool visible;
  bool locked;
  Map<String, dynamic> toJson() => {'name': name, 'color': color, 'visible': visible, 'locked': locked};
  static Layer fromJson(Map<String, dynamic> j) => Layer(name: j['name'] as String, color: j['color'] as int, visible: j['visible'] as bool? ?? true, locked: j['locked'] as bool? ?? false);
}

enum SizingMethod { lp, greedy }

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

  double get kinematicViscosity => waterKinematicViscosity(waterTempC);
  double adjustedC(double c) => c * hazenCScale + hazenCOffset;

  Map<String, dynamic> toJson() => {
    'units': units.toJson(), 'method': frictionMethod.name, 'temp': waterTempC, 'vZone': maxZoneVelocity,
    'vMain': maxMainlineVelocity, 'vLat': maxLateralVelocity, 'minorPct': minorLossPct, 'minor': applyMinorLosses,
    'tol': connectTolerance, 'interest': interestRate, 'term': termYears, 'kwh': powerCostPerKwh, 'eff': pumpEfficiency,
    'hours': hoursPerYear, 'zoneHours': zoneHoursPerYear, 'trade': tradeCapitalVsRunning, 'latSizes': maxLateralSizes,
    'subSizes': maxSubmainSizes, 'cScale': hazenCScale, 'cOffset': hazenCOffset, 'densify': terrainDensify, 'currency': currency, 'currencyCode': currencyCode,
    'sizing': sizingMethod.name, 'mainSizes': maxMainlineSizes, 'epp': emittersPerPlant, 'maxNodes': maxNodesPerLateral, 'flushV': flushingVelocity, 'flushH': flushingMinEndHeadM,
    'surge': checkSurge, 'closure': valveClosureTimeS, 'fittings': selectFittings, 'stick': pipeStickLengthM, 'zoneVar': maxZoneVariationPct, 'terrain': terrainMethod.name,
  };
  static DesignParameters fromJson(Map<String, dynamic>? j) {
    if (j == null) return DesignParameters();
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return DesignParameters(
      units: Units.fromJson(j['units'] as Map<String, dynamic>?),
      frictionMethod: FrictionMethod.values.byName(j['method'] as String? ?? 'hazenWilliams'),
      waterTempC: d('temp', 20),
      maxZoneVelocity: d('vZone', 1.5),
      maxMainlineVelocity: d('vMain', 2.0),
      maxLateralVelocity: d('vLat', 2.0),
      minorLossPct: d('minorPct', 5),
      applyMinorLosses: j['minor'] as bool? ?? true,
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
      sizingMethod: SizingMethod.values.byName(j['sizing'] as String? ?? 'lp'),
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
      terrainMethod: TerrainMethod.values.byName(j['terrain'] as String? ?? 'idw'),
    );
  }
}

/// A set of zones operating simultaneously (a "system flow" or shift).
class SystemFlow {
  SystemFlow({required this.id, required this.name, Set<String>? valveIds, this.startHour = 0, this.durationHours = 1}) : valveIds = valveIds ?? <String>{};
  final String id;
  String name;
  final Set<String> valveIds;
  double startHour;
  double durationHours;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'valves': valveIds.toList(), 'start': startHour, 'dur': durationHours};
  static SystemFlow fromJson(Map<String, dynamic> j) => SystemFlow(
    id: j['id'] as String,
    name: j['name'] as String,
    valveIds: ((j['valves'] as List?) ?? []).cast<String>().toSet(),
    startHour: (j['start'] as num?)?.toDouble() ?? 0,
    durationHours: (j['dur'] as num?)?.toDouble() ?? 1,
  );
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
  Map<String, dynamic> toJson() => {'uid': uid, 'created': created.toIso8601String(), if (modified != null) 'modified': modified!.toIso8601String(), 'name': name, 'client': client, 'site': site, 'designer': designer, 'notes': notes, if (georef != null) 'georef': georef!.toJson()};
  static ProjectMeta fromJson(Map<String, dynamic>? j) => j == null
      ? ProjectMeta()
      : ProjectMeta(
          uid: j['uid'] as String?,
          created: DateTime.tryParse(j['created'] as String? ?? ''),
          modified: DateTime.tryParse(j['modified'] as String? ?? ''),
          name: j['name'] as String? ?? '',
          client: j['client'] as String? ?? '',
          site: j['site'] as String? ?? '',
          designer: j['designer'] as String? ?? '',
          notes: j['notes'] as String? ?? '',
          georef: j['georef'] != null ? GeoReference.fromJson(j['georef'] as Map<String, dynamic>) : null,
        );
}

class Project {
  Project({ProjectMeta? meta, DesignParameters? params, Catalog? catalog, List<Layer>? layers, List<Entity>? entities, List<SystemFlow>? systemFlows, int nextId = 1})
      : meta = meta ?? ProjectMeta(),
        params = params ?? DesignParameters(),
        catalog = catalog ?? Catalog.defaultCatalog(),
        layers = layers ?? defaultLayers(),
        entities = entities ?? [],
        systemFlows = systemFlows ?? [],
        // ignore: prefer_initializing_formals
        _nextId = nextId;

  static const formatName = 'opencadirrigation';
  static const legacyFormatName = 'irrigationcad';
  static const formatVersion = 1;

  ProjectMeta meta;
  DesignParameters params;
  Catalog catalog;
  List<Layer> layers;
  final List<Entity> entities;
  final List<SystemFlow> systemFlows;
  int _nextId;

  static List<Layer> defaultLayers() => [for (final n in Layers.all) Layer(name: n, color: Layers.defaultColors[n] ?? 0xFFFFFFFF)];

  String newId([String prefix = 'e']) => '$prefix${_nextId++}';
  int get nextIdValue => _nextId;

  /// Multiplies every price of the project by [factor]: catalogue costs, the
  /// energy tariff and the pivot machine and tower costs.
  void scalePrices(double factor) {
    if (factor == 1) return;
    scaleCatalogPrices(catalog, factor);
    params.powerCostPerKwh *= factor;
    for (final e in entities) {
      if (e is PivotEntity) {
        e.machineCost *= factor;
        e.towerCost *= factor;
      }
    }
  }

  /// Switches the project to currency [code]; with [rate] (units of the new
  /// currency per unit of the old one) the prices are converted too.
  void setCurrency(String code, {double? rate, String? symbol}) {
    if (rate != null) scalePrices(rate);
    params.currencyCode = code;
    params.currency = symbol ?? currencySymbol(code);
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
    layers[i] = Layer(name: name, color: old.color, visible: old.visible, locked: old.locked);
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
    final l = Layer(name: name, color: 0xFFB0BEC5);
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

  Bounds get bounds {
    var b = Bounds.empty;
    for (final e in entities) {
      b = b.union(e.bounds);
    }
    return b;
  }

  /// Builds the DEM from contour and spot-height entities.
  Terrain buildTerrain() {
    final t = Terrain(densify: params.terrainDensify, method: params.terrainMethod);
    for (final e in entities) {
      if (e is ContourEntity && !e.derived) t.addContour(e.points, e.elevation);
      if (e is SpotHeightEntity) t.addSpot(e.position, e.elevation);
    }
    return t;
  }

  String uniqueZoneName([String prefix = 'Zone']) {
    final used = entities.whereType<ControlValveEntity>().map((v) => v.zoneName).toSet();
    var i = 1;
    while (used.contains('$prefix $i')) {
      i++;
    }
    return '$prefix $i';
  }

  Map<String, dynamic> toJson({bool includeEntities = true}) => {
    'format': formatName,
    'version': formatVersion,
    'meta': meta.toJson(),
    'params': params.toJson(),
    'catalog': catalog.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'entities': includeEntities ? entities.map((e) => e.toJson()).toList() : const [],
    'systemFlows': systemFlows.map((s) => s.toJson()).toList(),
    'nextId': _nextId,
    if (currentLayer != Layers.drawing) 'currentLayer': currentLayer,
  };

  String toJsonString({bool pretty = false}) => pretty ? const JsonEncoder.withIndent('  ').convert(toJson()) : jsonEncode(toJson());

  static Project fromJson(Map<String, dynamic> j) {
    if (j['format'] != formatName && j['format'] != legacyFormatName) throw const FormatException('Not an OpenCADIrrigation project');
    return Project(
      meta: ProjectMeta.fromJson(j['meta'] as Map<String, dynamic>?),
      params: DesignParameters.fromJson(j['params'] as Map<String, dynamic>?),
      catalog: j['catalog'] != null ? Catalog.fromJson(j['catalog'] as Map<String, dynamic>) : Catalog.defaultCatalog(),
      layers: ((j['layers'] as List?) ?? []).map((l) => Layer.fromJson(l as Map<String, dynamic>)).toList().let((l) => l.isEmpty ? defaultLayers() : l),
      entities: ((j['entities'] as List?) ?? []).map((e) => Entity.fromJson(e as Map<String, dynamic>)).toList(),
      systemFlows: ((j['systemFlows'] as List?) ?? []).map((s) => SystemFlow.fromJson(s as Map<String, dynamic>)).toList(),
      nextId: (j['nextId'] as num?)?.toInt() ?? 1,
    )..currentLayer = j['currentLayer'] as String? ?? Layers.drawing;
  }

  static Project fromJsonString(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Deep copy via JSON (used for undo snapshots).
  Project copy() => fromJson(toJson());
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
