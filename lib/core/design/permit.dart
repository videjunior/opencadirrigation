/// Water-use permit table and self-monitoring plan of every water source of
/// the project (1.6.0): what the permit forms of the water agencies ask for
/// a point of abstraction — its coordinates on SIRGAS 2000 (degrees,
/// minutes and seconds, and UTM), the source, the water body and its basin,
/// the purpose, the irrigated area and its crops, the pumps (power, flow,
/// head) — and the operating regime of every month: flow (m³/h), hours a
/// day, days a month, volume a day and a month, laid out as the permits of
/// the Brazilian National Water Agency write it (flow, hours/day,
/// days/month, m³/day and m³/month by month).
///
/// Volumes: the gross requirement of every irrigated area by month, by the
/// rule every report shares (area_water.dart: the FAO-56 requirement table
/// of its crop, the water balance with the ETo and Kc typed on it, or the
/// fixed net depth over its efficiency), summed by the water source that
/// waters the area (the share of each source in the system flows that water
/// its zones; the nearest source without a design).
///
/// Regime: the flow is the installed one (the largest flow the source
/// delivers in the design, else its design flow, else the one the peak
/// month needs in [PermitSettings.maxHoursPerDay]); every month either runs
/// the days with irrigation for the hours they need (rounded up to 0.1 h),
/// or a fixed number of hours a day for the days it takes. The volume of
/// the permit is flow × hours × days, never below the need.
///
/// Rules and sources:
/// - Law 9.433/1997 (National Water Resources Policy): the permit
///   (outorga) of the right to use water;
/// - Resolution ANA 1.939/2017, Annex I: monthly volume Vmn = 10 × NIB × A
///   (NIB gross requirement in mm, A in ha), at least 300 m³/ha a month in
///   the electronic processing, the maximum flow from the largest monthly
///   volume and the operating regime ([PermitSettings.federalFloor]);
/// - Resolution ANA 188/2024: self-monitoring of the volumes abstracted —
///   direct (flow, volume or level measured) or indirect (estimated, with
///   the operating time measured), the declaration (DURH) yearly by 31
///   January with the monthly data, monthly by the 7th of the next month, or
///   by telemetry (measured at least every 15 min, sent daily) above the
///   thresholds of its Annex I by management unit ([monitoringUnits]), up
///   to 10 % imprecision, records kept for 36 months;
/// - IBGE R.PR 1/2005: SIRGAS 2000, Brazil's geodetic reference, equal to
///   WGS 84 at the accuracy of a project map (see io/datum.dart).
library;

import 'dart:math' as math;

import '../io/datum.dart' show GeodeticDatum;
import '../io/geo.dart';
import '../io/tech_doc.dart';
import '../model/catalog.dart';
import '../model/deliverables.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'agronomy.dart' show areasOfMachine, areasOfZone;
import 'area_water.dart';
import 'climate.dart' show daysInMonth;
import 'design_check.dart' show CheckIssue, CheckSeverity;
import 'irrigation_requirement.dart';
import 'report_tables.dart' show RNum, ReportTable;
import 'results.dart';

/// Year of the typical-year tables (a common year).
const _year = 2001;

/// The floor of the federal electronic processing (m³ per hectare a month,
/// Resolution ANA 1.939/2017, Annex I).
const federalFloorM3PerHa = 300.0;

/// Gross water need of an irrigated area in each month of the typical year
/// (index 0 = January): volume (m³) and the days with irrigation.
class MonthlyNeed {
  MonthlyNeed(this.volumeM3, this.days);
  final List<double> volumeM3;
  final List<int> days;
  double get annualM3 => volumeM3.fold(0.0, (a, b) => a + b);
}

/// The monthly need of area [a] by the rule of area_water.dart: the rows of
/// its FAO-56 requirement table (the volume of each month and its days with
/// the crop in the field), the water balance month by month with the ETo of
/// the site climate (or the one typed on the area), or the fixed net depth
/// over the efficiency every day.
MonthlyNeed areaMonthlyNeed(Project p, AreaEntity a) {
  final v = List<double>.filled(12, 0), d = List<int>.filled(12, 0);
  if (a.points.length < 3) return MonthlyNeed(v, d);
  final input = a.useWaterBalance ? requirementInputOf(p, a) : null;
  if (input != null) {
    final table = irrigationRequirement(input);
    for (final r in table.monthly) {
      final m = r.start.month - 1;
      v[m] += r.volumeM3;
      if (r.volumeM3 > 0) d[m] = math.min(daysInMonth(_year, m + 1), d[m] + r.cropDays);
    }
    return MonthlyNeed(v, d);
  }
  for (var m = 1; m <= 12; m++) {
    final b = areaWaterBasis(p, a, month: m);
    final n = daysInMonth(_year, m);
    v[m - 1] = math.max(0.0, b.grossMmDay) * n * a.area / 1000;
    d[m - 1] = v[m - 1] > 0 ? n : 0;
  }
  return MonthlyNeed(v, d);
}

/// A pump of a water source, as the permit forms ask for it.
class PermitPump {
  const PermitPump({required this.id, required this.name, required this.model, required this.powerKw, required this.flowM3h, required this.headM, required this.hourMeter});
  final String id;
  final String name;

  /// Catalogue item ('' without one).
  final String model;

  /// Rated motor power (kW; 0 = not given) and the duty of the design (0
  /// without results).
  final double powerKw;
  final double flowM3h;
  final double headM;
  final bool hourMeter;

  /// Power in metric horsepower (cv: 735.5 W).
  double get powerCv => powerKw / 0.7355;
}

/// One water source (point of abstraction) of the permit study.
class PermitSource {
  PermitSource({
    required this.supply,
    required this.info,
    required this.lat,
    required this.lon,
    required this.utm,
    required this.epsg,
    required this.elevationM,
    required this.areaIds,
    required this.areaHa,
    required this.methods,
    required this.crops,
    required this.installedFlowM3h,
    required this.flowFromDemand,
    required this.needM3,
    required this.flowM3h,
    required this.hoursPerDay,
    required this.daysPerMonth,
    required this.floorRaised,
    required this.peakHoursNeeded,
    required this.pumps,
    required this.meter,
    required this.warnings,
  });
  final WaterSupplyEntity supply;
  final SourcePermitInfo info;

  /// WGS 84 ≡ SIRGAS 2000 latitude and longitude (degrees) and UTM in the
  /// zone of the point, with the EPSG code of SIRGAS 2000 / UTM; null
  /// without a georeference.
  final double? lat, lon;
  final UtmPoint? utm;
  final int? epsg;

  /// Ground elevation of the point (m; null when unknown).
  final double? elevationM;

  /// Irrigated areas the source waters and their area (ha, its share of
  /// the areas watered by several sources).
  final List<String> areaIds;
  final double areaHa;

  /// Irrigation methods (`req.method.*` keys) and crop names of those areas.
  final List<String> methods;
  final List<String> crops;

  /// Installed flow (m³/h); [flowFromDemand] when it is the flow the peak
  /// month needs (no design, no design flow).
  final double installedFlowM3h;
  final bool flowFromDemand;

  /// Gross need of every month (m³) and the regime: flow (m³/h), hours a
  /// day and days a month (0 in a month without irrigation), and the months
  /// raised to the federal floor.
  final List<double> needM3;
  final List<double> flowM3h;
  final List<double> hoursPerDay;
  final List<int> daysPerMonth;
  final List<bool> floorRaised;

  /// Hours a day the month of highest demand needs at the installed flow,
  /// over its days with irrigation.
  final double peakHoursNeeded;
  final List<PermitPump> pumps;

  /// A flow or volume meter on the source (direct monitoring).
  final bool meter;

  /// Message codes (`permit_*`).
  final List<String> warnings;

  /// Volume a day and a month of the permit (m³).
  List<double> get volumeDayM3 => [for (var m = 0; m < 12; m++) flowM3h[m] * hoursPerDay[m]];
  List<double> get volumeMonthM3 => [for (var m = 0; m < 12; m++) flowM3h[m] * hoursPerDay[m] * daysPerMonth[m]];
  double get annualM3 => volumeMonthM3.fold(0.0, (a, b) => a + b);
  double get annualNeedM3 => needM3.fold(0.0, (a, b) => a + b);
  double get hoursPerYear => [for (var m = 0; m < 12; m++) hoursPerDay[m] * daysPerMonth[m]].fold(0.0, (a, b) => a + b);

  /// The months with abstraction (1–12).
  List<int> get months => [
    for (var m = 0; m < 12; m++)
      if (daysPerMonth[m] > 0) m + 1,
  ];

  /// An hour meter on one of its pumps (indirect monitoring).
  bool get hourMeter => pumps.any((p) => p.hourMeter);

  /// Largest flow of the permit (m³/h).
  double get maxFlowM3h => flowM3h.fold(0.0, math.max);
}

/// A management unit of the self-monitoring thresholds of Resolution ANA
/// 188/2024, Annex I: the frequency of the declaration and the largest
/// flow of the enterprise (m³/h) from which it is due, and from which it
/// goes by telemetry.
class MonitoringUnit {
  const MonitoringUnit(this.key, {required this.monthly, required this.limitM3h, required this.telemetryM3h});
  final String key;
  final bool monthly;
  final double limitM3h;
  final double telemetryM3h;
}

/// The units of Resolution ANA 188/2024, Annex I (water bodies of the
/// Union), `other` last: the other federal units and the state units. The
/// telemetry threshold of a sub-unit printed without its own is that of its
/// unit (the merged cells of the table).
const monitoringUnits = [
  MonitoringUnit('mrs', monthly: true, limitM3h: 50, telemetryM3h: 1000),
  MonitoringUnit('piranhas', monthly: true, limitM3h: 50, telemetryM3h: 1000),
  MonitoringUnit('parnaiba', monthly: false, limitM3h: 800, telemetryM3h: 2000),
  MonitoringUnit('javaes', monthly: true, limitM3h: 200, telemetryM3h: 1000),
  MonitoringUnit('tocantins', monthly: false, limitM3h: 1500, telemetryM3h: 4000),
  MonitoringUnit('preto', monthly: false, limitM3h: 1000, telemetryM3h: 4000),
  MonitoringUnit('saoFrancisco', monthly: false, limitM3h: 2000, telemetryM3h: 4000),
  MonitoringUnit('verdeGrande', monthly: true, limitM3h: 50, telemetryM3h: 2000),
  MonitoringUnit('pardo', monthly: true, limitM3h: 50, telemetryM3h: 1000),
  MonitoringUnit('jequitinhonha', monthly: false, limitM3h: 150, telemetryM3h: 1000),
  MonitoringUnit('doce', monthly: false, limitM3h: 200, telemetryM3h: 1000),
  MonitoringUnit('grande', monthly: false, limitM3h: 600, telemetryM3h: 1500),
  MonitoringUnit('saoMarcos', monthly: true, limitM3h: 36, telemetryM3h: 2000),
  MonitoringUnit('paranaiba', monthly: false, limitM3h: 800, telemetryM3h: 2000),
  MonitoringUnit('paraguai', monthly: false, limitM3h: 500, telemetryM3h: 2000),
  MonitoringUnit('parana', monthly: false, limitM3h: 800, telemetryM3h: 3000),
  MonitoringUnit('paranapanema', monthly: false, limitM3h: 300, telemetryM3h: 1000),
  MonitoringUnit('pcj', monthly: false, limitM3h: 300, telemetryM3h: 1000),
  MonitoringUnit('paraibaSul', monthly: false, limitM3h: 120, telemetryM3h: 1000),
  MonitoringUnit('iguacu', monthly: false, limitM3h: 300, telemetryM3h: 2000),
  MonitoringUnit('negro', monthly: true, limitM3h: 500, telemetryM3h: 3000),
  MonitoringUnit('quarai', monthly: true, limitM3h: 1000, telemetryM3h: 3000),
  MonitoringUnit('uruguai', monthly: false, limitM3h: 1500, telemetryM3h: 3000),
  MonitoringUnit('other', monthly: false, limitM3h: 1500, telemetryM3h: 4000),
];

/// The unit of key [key] ('' or unknown: `other`).
MonitoringUnit monitoringUnitOf(String key) => monitoringUnits.firstWhere((u) => u.key == key, orElse: () => monitoringUnits.last);

/// What Resolution ANA 188/2024 asks of the enterprise for [unit], by the
/// sum of the largest flows of its points [flowsM3h] (Art. 5): `telemetry`
/// (from the telemetry threshold), `monthly` or `annual` (the declaration
/// is due; the frequency of the unit) or `none` (below the threshold).
String monitoringObligation(MonitoringUnit unit, List<double> flowsM3h) {
  final sum = flowsM3h.fold(0.0, (a, b) => a + b);
  if (sum <= 0 || sum < unit.limitM3h) return 'none';
  if (sum >= unit.telemetryM3h) return 'telemetry';
  return unit.monthly ? 'monthly' : 'annual';
}

/// The points among [flowsM3h] the obligation leaves out (Art. 5, § 1):
/// those whose largest flow is below 10 % of the threshold without
/// telemetry, as long as together they stay within 20 % of it (all false
/// when the enterprise has no obligation).
List<bool> monitoringExemptions(MonitoringUnit unit, List<double> flowsM3h) {
  final small = [for (final q in flowsM3h) q > 0 && q < 0.1 * unit.limitM3h];
  final sum = [
    for (var i = 0; i < flowsM3h.length; i++)
      if (small[i]) flowsM3h[i],
  ].fold(0.0, (a, b) => a + b);
  if (monitoringObligation(unit, flowsM3h) == 'none' || sum > 0.2 * unit.limitM3h) return List.filled(flowsM3h.length, false);
  return small;
}

/// The permit study of the project.
class PermitStudy {
  PermitStudy({required this.sources, required this.warnings, required this.unit, required this.obligation, List<bool>? exempt}) : exempt = exempt ?? List.filled(sources.length, false);
  final List<PermitSource> sources;

  /// Project-level message codes (`permit_no_source`, `permit_no_areas`,
  /// `permit_machine_no_area:<id>`).
  final List<String> warnings;
  final MonitoringUnit unit;

  /// [monitoringObligation] of the sources together, and the points it
  /// leaves out ([monitoringExemptions], by source).
  final String obligation;
  final List<bool> exempt;

  double get totalFlowM3h => sources.fold(0.0, (a, s) => a + s.maxFlowM3h);
  double get annualM3 => sources.fold(0.0, (a, s) => a + s.annualM3);
}

/// The source each item of [items] is nearest to.
String? _nearestSupply(List<WaterSupplyEntity> supplies, Pt p) {
  String? best;
  var d = double.infinity;
  for (final s in supplies) {
    final x = s.position.distanceTo(p);
    if (x < d) {
      d = x;
      best = s.id;
    }
  }
  return best;
}

/// The water source each meter (a device of kind meter) and each pump
/// belongs to: the only one, else the nearest.
Map<String, String> _assignToSupplies(List<WaterSupplyEntity> supplies, Iterable<Entity> items) => {
  for (final e in items)
    if (e is PointEntity) e.id: ?_nearestSupply(supplies, e.position),
};

/// Meters of [p]: the devices whose catalogue item is a flow meter.
List<MiscHydraulicEntity> flowMeters(Project p) => [
  for (final e in p.entities)
    if (e is MiscHydraulicEntity && p.catalog.valve(e.valveSpecId)?.kind == ValveKind.meter) e,
];

/// Design checks of the permit: `supply_no_meter`, a water source without a
/// flow meter on its line nor an hour meter on its pumps (the
/// self-monitoring of Resolution ANA 188/2024 and the conditions of most
/// permits measure the volume, or at least the pumping time). Informative.
List<CheckIssue> permitChecks(Project p) {
  final supplies = p.entities.whereType<WaterSupplyEntity>().toList();
  if (supplies.isEmpty) return const [];
  final meters = _assignToSupplies(supplies, flowMeters(p));
  final pumps = _assignToSupplies(supplies, p.entities.whereType<PumpEntity>().where((x) => x.hourMeter));
  return [
    for (final s in supplies)
      if (!meters.values.contains(s.id) && !pumps.values.contains(s.id)) CheckIssue('supply_no_meter', CheckSeverity.info, entityIds: [s.id], value: s.name),
  ];
}

/// The permit study of [p] (design results [r] give the flows, the pumps'
/// duty and which source waters which area).
PermitStudy buildPermitStudy(Project p, DesignResults? r, {String Function(String key)? cropName}) {
  final s = p.deliverables.permit;
  final supplies = p.entities.whereType<WaterSupplyEntity>().toList();
  final warnings = <String>[];
  final unit = monitoringUnitOf(s.monitoringUnit);
  if (supplies.isEmpty) return PermitStudy(sources: const [], warnings: ['permit_no_source'], unit: unit, obligation: 'none');
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3) a,
  ];
  if (areas.isEmpty) warnings.add('permit_no_areas');
  for (final pv in p.entities.whereType<PivotEntity>()) {
    if (areasOfMachine(p, pv).isEmpty) warnings.add('permit_machine_no_area:${pv.id}');
  }
  // ---- which source waters which area (shares that add up to 1)
  final share = <String, Map<String, double>>{}; // area → supply → weight
  if (r != null && supplies.length > 1) {
    for (final f in r.systemFlows) {
      final q = f.supplies.fold(0.0, (a, x) => a + math.max(0.0, x.flow));
      if (q <= 0) continue;
      final watered = <String>{};
      for (final v in f.valves) {
        final e = p.byId(v.valveId);
        for (final a in e is PivotEntity ? areasOfMachine(p, e) : areasOfZone(p, r, v.valveId)) {
          watered.add(a.id);
        }
      }
      for (final id in watered) {
        final m = share.putIfAbsent(id, () => {});
        for (final x in f.supplies) {
          if (x.flow > 0) m[x.supplyId] = (m[x.supplyId] ?? 0) + x.flow / q;
        }
      }
    }
  }
  for (final a in areas) {
    final m = share[a.id];
    if (m == null || m.isEmpty) {
      final id = supplies.length == 1 ? supplies.first.id : _nearestSupply(supplies, polygonCentroid(a.points));
      share[a.id] = {?id: 1};
    } else {
      final sum = m.values.fold(0.0, (x, y) => x + y);
      m.updateAll((_, v) => v / sum);
    }
  }
  final needs = {for (final a in areas) a.id: areaMonthlyNeed(p, a)};
  // ---- meters and pumps of every source
  final meterOf = _assignToSupplies(supplies, flowMeters(p));
  final pumpEntities = p.entities.whereType<PumpEntity>().toList();
  final pumpOf = <String, String>{};
  if (r != null) {
    // a pump of a flow that only one source feeds belongs to it
    for (final f in r.systemFlows) {
      final feeding = [
        for (final x in f.supplies)
          if (x.flow > 0) x.supplyId,
      ];
      if (feeding.length != 1) continue;
      for (final d in f.devices) {
        if (p.byId(d.entityId) is PumpEntity) pumpOf.putIfAbsent(d.entityId, () => feeding.single);
      }
    }
  }
  for (final e in _assignToSupplies(supplies, pumpEntities).entries) {
    pumpOf.putIfAbsent(e.key, () => e.value);
  }
  final g = p.meta.georef;
  final terrain = p.buildTerrain();
  final sources = <PermitSource>[];
  for (final sup in supplies) {
    final info = s.sources[sup.id] ?? SourcePermitInfo();
    final codes = <String>[];
    // ---- where
    double? lat, lon;
    UtmPoint? utm;
    int? epsg;
    if (g != null) {
      (lat, lon) = g.toLatLon(sup.position.x, sup.position.y);
      utm = latLonToUtm(lat, lon);
      epsg = GeodeticDatum.sirgas2000.utmEpsg(utm.zone, utm.north);
    } else {
      codes.add('permit_no_georef');
    }
    double? elevation;
    final duty = r?.systemFlows.expand((f) => f.supplies).where((x) => x.supplyId == sup.id).firstOrNull;
    if (duty != null) {
      elevation = duty.elevation;
    } else if (!terrain.isEmpty) {
      elevation = terrain.elevationAt(sup.position);
    }
    // ---- what it waters
    final need = List<double>.filled(12, 0);
    final days = List<int>.filled(12, 0);
    var ha = 0.0;
    final ids = <String>[];
    final methods = <String>{}, crops = <String>{};
    for (final a in areas) {
      final w = share[a.id]?[sup.id] ?? 0;
      if (w <= 0) continue;
      ids.add(a.id);
      ha += w * a.area / 10000;
      methods.add('req.method.${areaIrrigationMethod(a)}');
      final crop = a.cropKey.isNotEmpty ? (cropName?.call(a.cropKey) ?? a.cropKey) : a.crop.trim();
      if (crop.isNotEmpty) crops.add(crop);
      final n = needs[a.id]!;
      for (var m = 0; m < 12; m++) {
        need[m] += w * n.volumeM3[m];
        if (n.volumeM3[m] > 0) days[m] = math.max(days[m], n.days[m]);
      }
    }
    // the federal floor of the months with irrigation
    final raised = List<bool>.filled(12, false);
    final volume = [...need];
    if (s.federalFloor && ha > 0) {
      for (var m = 0; m < 12; m++) {
        if (volume[m] > 0 && volume[m] < federalFloorM3PerHa * ha) {
          volume[m] = federalFloorM3PerHa * ha;
          raised[m] = true;
        }
      }
    }
    // ---- the installed flow
    var q = 0.0;
    for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
      for (final x in f.supplies) {
        if (x.supplyId == sup.id) q = math.max(q, x.flow * 3600);
      }
    }
    if (q <= 0 && sup.designFlow > 0) q = sup.designFlow * 3600;
    var fromDemand = false;
    if (q <= 0) {
      for (var m = 0; m < 12; m++) {
        if (volume[m] > 0 && days[m] > 0) q = math.max(q, volume[m] / (days[m] * s.maxHoursPerDay));
      }
      q = (q * 10).ceil() / 10;
      fromDemand = q > 0;
      if (fromDemand) codes.add('permit_flow_from_demand');
    }
    // ---- the regime of every month
    final flow = List<double>.filled(12, 0), hours = List<double>.filled(12, 0);
    final dpm = List<int>.filled(12, 0);
    var peakHours = 0.0;
    for (var m = 0; m < 12; m++) {
      final v = volume[m];
      if (v <= 0 || q <= 0) continue;
      final nDays = daysInMonth(_year, m + 1);
      final irrigationDays = math.max(1, days[m]);
      peakHours = math.max(peakHours, v / (q * irrigationDays));
      double h;
      int d;
      if (s.fixedHoursPerDay > 0) {
        h = s.fixedHoursPerDay;
        d = (v / (q * h) - 1e-9).ceil();
        if (d > nDays) {
          d = nDays;
          h = _up(v / (q * d));
        }
      } else {
        d = irrigationDays;
        h = _up(v / (q * d));
      }
      flow[m] = q;
      hours[m] = h;
      dpm[m] = math.max(1, d);
    }
    if (peakHours > 24 + 1e-9) {
      codes.add('permit_hours_over_24');
    } else if (peakHours > s.maxHoursPerDay + 1e-9) {
      codes.add('permit_capacity');
    }
    if (raised.contains(true)) codes.add('permit_federal_floor');
    // ---- pumps and meters
    final pumps = <PermitPump>[];
    for (final pu in pumpEntities) {
      if (pumpOf[pu.id] != sup.id) continue;
      final spec = p.catalog.pump(pu.pumpSpecId);
      var pq = 0.0, ph = 0.0;
      for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
        for (final d in f.devices) {
          if (d.entityId == pu.id && d.flow * 3600 > pq) {
            pq = d.flow * 3600;
            ph = d.pumpHead;
          }
        }
      }
      pumps.add(PermitPump(id: pu.id, name: pu.name, model: spec?.name ?? '', powerKw: spec?.powerKw ?? 0, flowM3h: pq, headM: ph, hourMeter: pu.hourMeter));
    }
    final meter = meterOf.values.contains(sup.id);
    if (!meter && !pumps.any((x) => x.hourMeter)) codes.add('permit_no_meter');
    sources.add(
      PermitSource(
        supply: sup,
        info: info,
        lat: lat,
        lon: lon,
        utm: utm,
        epsg: epsg,
        elevationM: elevation,
        areaIds: ids,
        areaHa: ha,
        methods: methods.toList()..sort(),
        crops: crops.toList()..sort(),
        installedFlowM3h: q,
        flowFromDemand: fromDemand,
        needM3: need,
        flowM3h: flow,
        hoursPerDay: hours,
        daysPerMonth: dpm,
        floorRaised: raised,
        peakHoursNeeded: peakHours,
        pumps: pumps,
        meter: meter,
        warnings: codes,
      ),
    );
  }
  final flows = [for (final x in sources) x.maxFlowM3h];
  return PermitStudy(sources: sources, warnings: warnings, unit: unit, obligation: monitoringObligation(unit, flows), exempt: monitoringExemptions(unit, flows));
}

/// [h] rounded up to a tenth.
double _up(double h) => (h * 10 - 1e-9).ceil() / 10;

/// Degrees, minutes and seconds of [deg] with the hemisphere letter of
/// [pos] or [neg]: `17°51'14.44" S`.
String permitDms(double deg, String pos, String neg, {int decimals = 2}) {
  final a = deg.abs();
  var d = a.floor();
  var mFull = (a - d) * 60;
  var m = mFull.floor();
  var sec = double.parse(((mFull - m) * 60).toStringAsFixed(decimals));
  if (sec >= 60) {
    sec -= 60;
    m++;
  }
  if (m >= 60) {
    m -= 60;
    d++;
  }
  return '$d°${m.toString().padLeft(2, '0')}\'${sec.toStringAsFixed(decimals).padLeft(decimals + 3, '0')}" ${deg < 0 ? neg : pos}';
}

/// The headers of the twelve months (`prb.mon.1`…) and the year.
List<String> _monthHeaders(Translate t) => [for (var m = 1; m <= 12; m++) t('prb.mon.$m')];

/// The tables of the permit of source [src]: the monthly regime, the pumps
/// and the self-monitoring sheet (the field columns empty, to be filled).
List<ReportTable> permitSourceTables(PermitSource src, PermitSettings s, Translate t) {
  final id = src.supply.id;
  final hours = src.hoursPerDay, dpm = src.daysPerMonth, flow = src.flowM3h;
  final vDay = src.volumeDayM3, vMonth = src.volumeMonthM3;
  final perHa = [for (final v in vMonth) src.areaHa > 0 ? v / src.areaHa : 0.0];
  List<Object> row(String label, List<Object> months, Object year) => [label, ...months, year];
  final over = hours.any((h) => h > s.maxHoursPerDay + 1e-9);
  final monthly = ReportTable(
    key: 'permitMonthly:$id',
    title: '${t('prb.permit.regime')} — ${_sourceName(src, t)}',
    headers: ['', ..._monthHeaders(t), t('prb.year')],
    rows: [
      row('Q (m³/h)', [for (final q in flow) RNum(q, 1)], RNum(src.maxFlowM3h, 1)),
      row(t('prb.permit.hoursDay'), [for (final h in hours) RNum(h, 1)], ''),
      row(t('prb.permit.daysMonth'), [for (final d in dpm) d], dpm.fold<int>(0, (a, b) => a + b)),
      row(t('prb.permit.hoursMonth'), [for (var m = 0; m < 12; m++) RNum(hours[m] * dpm[m], 1)], RNum(src.hoursPerYear, 1)),
      row('V (m³/${t('prb.day')})', [for (final v in vDay) RNum(v, 1)], ''),
      row('V (m³/${t('prb.month')})', [for (final v in vMonth) RNum(v, 0)], RNum(src.annualM3, 0)),
      row('${t('prb.permit.need')} (m³)', [for (final v in src.needM3) RNum(v, 0)], RNum(src.annualNeedM3, 0)),
      row('V/${t('prb.area')} (m³/ha)', [for (final v in perHa) RNum(v, 0)], RNum(perHa.fold(0.0, (a, b) => a + b), 0)),
    ],
    warn: [false, over, false, false, false, false, false, src.floorRaised.contains(true)],
  );
  final pumps = ReportTable(
    key: 'permitPumps:$id',
    title: '${t('prb.permit.pumps')} — ${_sourceName(src, t)}',
    headers: [t('tool.pump'), t('prb.model'), '${t('prb.power')} (kW)', '${t('prb.power')} (cv)', 'Q (m³/h)', 'H (m)', t('prb.hourMeter')],
    rows: [
      for (final x in src.pumps)
        [
          x.name.isNotEmpty ? x.name : (x.model.isNotEmpty ? x.model : '${t('tool.pump')} ${x.id}'),
          x.model.isEmpty ? '-' : x.model,
          x.powerKw > 0 ? RNum(x.powerKw, 1) : '-',
          x.powerKw > 0 ? RNum(x.powerCv, 1) : '-',
          x.flowM3h > 0 ? RNum(x.flowM3h, 1) : '-',
          x.flowM3h > 0 ? RNum(x.headM, 1) : '-',
          x.hourMeter ? t('prb.yes') : t('prb.no'),
        ],
    ],
  );
  final log = ReportTable(
    key: 'permitLog:$id',
    title: '${t('prb.permit.log')} — ${_sourceName(src, t)}',
    headers: [
      t('req.month'),
      '${t('prb.permit.granted')} (m³)',
      '${t('prb.permit.hoursPlanned')} (h)',
      '${t('prb.permit.meterStart')} (m³)',
      '${t('prb.permit.meterEnd')} (m³)',
      '${t('prb.permit.measured')} (m³)',
      '${t('prb.permit.hourStart')} (h)',
      '${t('prb.permit.hourEnd')} (h)',
      '${t('prb.permit.hoursMeasured')} (h)',
      '${t('prb.permit.deviation')} (%)',
    ],
    rows: [
      for (var m = 0; m < 12; m++) [t('mon.${m + 1}'), RNum(vMonth[m], 0), RNum(hours[m] * dpm[m], 1), '', '', '', '', '', '', ''],
      [t('prb.year'), RNum(src.annualM3, 0), RNum(src.hoursPerYear, 1), '', '', '', '', '', '', ''],
    ],
  );
  return [monthly, if (src.pumps.isNotEmpty) pumps, log];
}

String _sourceName(PermitSource src, Translate t) => src.supply.name.isNotEmpty ? src.supply.name : '${t('tool.supply')} ${src.supply.id}';

/// The text of a message code of the permit (`prb.warn.<code>` with the
/// figures of [src]).
String permitWarningText(String code, Translate t, {PermitSource? src, PermitSettings? s, String Function(String id)? name}) {
  final i = code.indexOf(':');
  final key = i < 0 ? code : code.substring(0, i);
  final arg = i < 0 ? '' : code.substring(i + 1);
  return t('prb.warn.$key', {
    'h': fmt(src?.peakHoursNeeded ?? 0, 1),
    'max': fmt(s?.maxHoursPerDay ?? 21, 1),
    'q': fmt(src?.installedFlowM3h ?? 0, 1),
    'floor': fmt(federalFloorM3PerHa, 0),
    'n': name?.call(arg) ?? arg,
  });
}

/// The permit table as a document: the enterprise, then every point of
/// abstraction (its fields, the regime by month, the pumps, the remarks),
/// the self-monitoring (the obligation by Resolution ANA 188/2024 and the
/// monthly sheet of each point) and the criteria and sources.
TechDocument permitDocument(Project p, PermitStudy study, Translate t, {String Function(String id)? entityName}) {
  final s = p.deliverables.permit;
  final m = p.meta;
  String yesNo(bool v) => v ? t('prb.yes') : t('prb.no');
  final sections = <TechSection>[
    TechSection(t('prb.permit.enterprise'), [
      TechFields([
        (t('dlg.project'), m.name),
        (t('prb.permit.user'), m.client),
        (t('prb.permit.property'), m.site),
        (t('dlg.designer'), m.designer),
        (t('prb.permit.points'), '${study.sources.length}'),
        (t('prb.permit.totalArea'), '${fmt(study.sources.fold<double>(0, (a, x) => a + x.areaHa), 2)} ha'),
        (t('prb.permit.totalFlow'), '${fmt(study.totalFlowM3h, 1)} m³/h (${fmt(study.totalFlowM3h / 3.6, 2)} L/s)'),
        (t('prb.permit.annualVolume'), '${fmt(study.annualM3, 0)} m³'),
      ]),
      for (final w in study.warnings) TechNote(permitWarningText(w, t, name: entityName), warning: true),
    ], key: 'enterprise'),
  ];
  for (final src in study.sources) {
    final info = src.info;
    final tables = permitSourceTables(src, s, t);
    final u = src.utm;
    sections.add(
      TechSection('${t('prb.permit.point')}: ${_sourceName(src, t)}', [
        TechFields([
          (t('prb.permit.kind'), t('prb.kind.${info.kind}')),
          (t('prb.permit.waterBody'), info.waterBody),
          (t('prb.permit.basin'), info.basin),
          (t('prb.permit.municipality'), info.municipality),
          (t('prb.permit.datum'), u == null ? '' : t('prb.src.sirgas')),
          (t('prb.permit.lat'), src.lat == null ? '' : '${permitDms(src.lat!, t('compass.n'), t('compass.s'))}  (${fmt(src.lat!, 6)}°)'),
          (t('prb.permit.lon'), src.lon == null ? '' : '${permitDms(src.lon!, t('compass.e'), t('compass.w'))}  (${fmt(src.lon!, 6)}°)'),
          (
            t('prb.permit.utm'),
            u == null ? '' : 'E ${fmt(u.easting, 1)} m · N ${fmt(u.northing, 1)} m · ${t('prb.permit.zone')} ${u.zone}${u.north ? 'N' : 'S'}${src.epsg == null ? '' : ' (EPSG:${src.epsg})'}',
          ),
          (t('prb.permit.elevation'), src.elevationM == null ? '' : '${fmt(src.elevationM!, 1)} m'),
          (t('prb.permit.status'), t('prb.status.${info.status}')),
          (t('prb.permit.registry'), info.registry),
          (t('prb.permit.number'), info.permitNumber),
          (t('prb.permit.purpose'), t('prb.permit.irrigation')),
          (t('prb.permit.method'), [for (final k in src.methods) t(k)].join(', ')),
          (t('prb.permit.crops'), src.crops.join(', ')),
          (t('prb.permit.area'), '${fmt(src.areaHa, 2)} ha'),
          (t('prb.permit.maxFlow'), '${fmt(src.maxFlowM3h, 1)} m³/h (${fmt(src.maxFlowM3h / 3.6, 2)} L/s)'),
          (t('prb.permit.months'), [for (final x in src.months) t('prb.mon.$x')].join(', ')),
          (t('prb.permit.hoursYear'), '${fmt(src.hoursPerYear, 0)} h'),
          (t('prb.permit.annualVolume'), '${fmt(src.annualM3, 0)} m³'),
          (t('prb.permit.meter'), yesNo(src.meter)),
          (t('prb.hourMeter'), yesNo(src.hourMeter)),
          (t('prb.permit.obligation'), t(study.exempt[study.sources.indexOf(src)] ? 'prb.obligation.exempt' : 'prb.obligation.${study.obligation}')),
        ]),
        for (final tb in tables.where((x) => !x.key.startsWith('permitLog'))) TechTable(tb),
        for (final w in src.warnings)
          TechNote(
            permitWarningText(w, t, src: src, s: s, name: entityName),
            warning: w != 'permit_federal_floor',
          ),
      ], key: 'point:${src.supply.id}'),
    );
  }
  // ---- self-monitoring
  final unit = study.unit;
  sections.add(
    TechSection(t('prb.permit.monitoring'), [
      TechFields([
        (t('prb.permit.unit'), t('prb.unit.${unit.key}')),
        (t('prb.permit.totalFlow'), '${fmt(study.totalFlowM3h, 1)} m³/h'),
        (t('prb.permit.limit'), '${fmt(unit.limitM3h, 0)} m³/h (${t(unit.monthly ? 'prb.permit.freqMonthly' : 'prb.permit.freqAnnual')})'),
        (t('prb.permit.telemetryLimit'), '${fmt(unit.telemetryM3h, 0)} m³/h'),
        (t('prb.permit.obligation'), t('prb.obligation.${study.obligation}')),
      ]),
      TechBullets([t('prb.permit.rule.direct'), t('prb.permit.rule.deadlines'), t('prb.permit.rule.accuracy'), t('prb.permit.rule.records'), t('prb.permit.rule.state')]),
      for (final src in study.sources)
        for (final tb in permitSourceTables(src, s, t).where((x) => x.key.startsWith('permitLog'))) TechTable(tb, note: t('prb.permit.logNote')),
    ], key: 'monitoring'),
  );
  // ---- criteria and sources
  sections.add(
    TechSection(t('prb.criteria'), [
      TechBullets([
        t('prb.permit.crit.volumes'),
        s.fixedHoursPerDay > 0 ? t('prb.permit.crit.fixedHours', {'h': fmt(s.fixedHoursPerDay, 1)}) : t('prb.permit.crit.days'),
        t('prb.permit.crit.flow', {'h': fmt(s.maxHoursPerDay, 1)}),
        if (s.federalFloor) t('prb.permit.crit.floor', {'floor': fmt(federalFloorM3PerHa, 0)}),
        t('prb.permit.crit.datum'),
      ]),
      TechFormula(t('prb.f.vmnExpr'), where: [('Vmn', t('prb.f.vmn')), ('NIB', t('prb.f.nib')), ('A', t('prb.f.areaHa'))], source: t('prb.src.ana1939')),
      TechFormula(t('prb.f.vqhdExpr'), where: [('Q', t('prb.f.qm3h')), ('h', t('prb.f.hDay')), ('d', t('prb.f.dMonth'))]),
      TechParagraph(t('prb.permit.refs')),
    ], key: 'criteria'),
  );
  return TechDocument(
    key: 'permit',
    title: t('prb.permit.title'),
    subtitle: [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].where((x) => x.isNotEmpty).join(' · '),
    sections: sections,
    landscape: true,
  );
}
