/// Solar pumping in the design: the PV array of the project's pumping
/// demand, its energy and what it does to the energy cost.
///
/// * Off-grid PV pumping (IEC 62253): the array of the month of largest
///   need for the daily volume of every month (the crop requirement tables,
///   else the volume the system flows pump in a day) against the total
///   dynamic head of the design, through `solar_pumping.dart` (tilted
///   irradiation of Liu & Jordan, performance ratio of IEC 61724-1). The
///   pumps then draw nothing from the grid: the energy cost of the design
///   goes to zero, and months the array cannot serve are reported.
/// * Grid-tied net metering (Sistema de Compensação de Energia Elétrica,
///   Lei 14.300/2022): the array that generates the design's yearly pumping
///   energy, E = P·Σ(days·HT·PR). The share of the generation used while it
///   is produced never reaches the meter; the rest is injected and comes back
///   as credits that offset the energy taken from the grid, paying the
///   distribution wires (Fio B) at the share of art. 27 for the year billed
///   (15 % in 2023 rising 15 points a year to 90 % in 2028; 100 % assumed
///   from 2029, when ANEEL's rule applies; none until 2045 for access asked
///   before 7 January 2023, art. 26). The design's energy cost becomes the
///   energy bought plus the Fio B of the credits.
library;

import 'dart:math' as math;

import '../model/agb_settings.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../units.dart';
import 'area_requirement.dart';
import 'pump_house.dart' show ie3Efficiency, pumpMotorKw;
import 'pump_selection.dart' show wireToWaterEfficiency;
import 'results.dart';
import 'solar_pumping.dart';

/// Share of the Fio B paid on compensated energy in [year] (Lei
/// 14.300/2022 art. 27; [grandfathered] = access asked before 7 January
/// 2023, exempt until 2045 by art. 26).
double fioBSharePaid(int year, {bool grandfathered = false}) {
  if (grandfathered) return year <= 2045 ? 0 : 1;
  if (year <= 2022) return 0;
  if (year >= 2029) return 1;
  return 0.15 * (year - 2022);
}

/// One month of the solar design.
class SolarMonthRow {
  const SolarMonthRow({required this.month, required this.peakSunHours, required this.demandM3Day, required this.pumpedM3Day, required this.generationKWh});
  final int month;

  /// Irradiation on the array (kWh/m²/day = peak sun hours).
  final double peakSunHours;

  /// Off-grid: daily volume needed and lifted (m³/day); grid-tied: 0.
  final double demandM3Day;
  final double pumpedM3Day;

  /// Energy the array generates in the month (kWh).
  final double generationKWh;

  Map<String, dynamic> toJson() => {'m': month, 'psh': peakSunHours, 'qd': demandM3Day, 'qp': pumpedM3Day, 'e': generationKWh};
  static SolarMonthRow fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return SolarMonthRow(month: (j['m'] as num?)?.toInt() ?? 1, peakSunHours: d('psh'), demandM3Day: d('qd'), pumpedM3Day: d('qp'), generationKWh: d('e'));
  }
}

/// The solar design of a project.
class SolarDesign {
  SolarDesign({
    required this.mode,
    required this.modules,
    required this.moduleWp,
    required this.arrayKWp,
    required this.areaM2,
    required this.inverterKw,
    required this.tiltDeg,
    required this.headM,
    required this.efficiency,
    required this.yieldKWhPerKWp,
    required this.generationKWh,
    required this.consumptionKWh,
    required this.gridCost,
    required this.netCost,
    required this.fioBPaidPct,
    required this.selfConsumedKWh,
    required this.compensatedKWh,
    required this.excessKWh,
    required this.months,
    this.criticalMonth,
    this.warnings = const [],
  });
  final SolarMode mode;

  /// Array: modules × module rating, power (kWp), area (m²), the pump
  /// drive or inverter (kW) and the slope (degrees).
  final int modules;
  final double moduleWp;
  final double arrayKWp;
  final double areaM2;
  final double inverterKw;
  final double tiltDeg;

  /// Total dynamic head (m) and wire-to-water efficiency used.
  final double headM;
  final double efficiency;

  /// Yearly yield per kWp (kWh), generation and the pumping consumption of
  /// the design (kWh/year).
  final double yieldKWhPerKWp;
  final double generationKWh;
  final double consumptionKWh;

  /// Energy cost of the design on the grid alone and with the array
  /// (currency per year), the Fio B share paid on the credits (%).
  final double gridCost;
  final double netCost;
  final double fioBPaidPct;

  /// Grid-tied energy balance (kWh/year): used while generated, credits
  /// compensated, credits left over.
  final double selfConsumedKWh;
  final double compensatedKWh;
  final double excessKWh;

  final List<SolarMonthRow> months;

  /// Off-grid: the month that sets the array.
  final int? criticalMonth;

  /// Codes `solar_*` (`solar_no_demand`, `solar_no_radiation`,
  /// `solar_deficit:<month>`, `solar_no_irradiation:<month>`,
  /// `solar_excess`, `solar_no_tariff`).
  final List<String> warnings;

  double get saving => gridCost - netCost;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'n': modules,
    'wp': moduleWp,
    'kwp': arrayKWp,
    'area': areaM2,
    'inv': inverterKw,
    'tilt': tiltDeg,
    'head': headM,
    'eta': efficiency,
    'yield': yieldKWhPerKWp,
    'gen': generationKWh,
    'cons': consumptionKWh,
    'grid': gridCost,
    'net': netCost,
    'fiob': fioBPaidPct,
    'self': selfConsumedKWh,
    'comp': compensatedKWh,
    'excess': excessKWh,
    'months': [for (final m in months) m.toJson()],
    if (criticalMonth != null) 'crit': criticalMonth,
    if (warnings.isNotEmpty) 'warn': warnings,
  };
  static SolarDesign fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return SolarDesign(
      mode: SolarMode.values.asNameMap()[j['mode']] ?? SolarMode.offGrid,
      modules: (j['n'] as num?)?.toInt() ?? 0,
      moduleWp: d('wp'),
      arrayKWp: d('kwp'),
      areaM2: d('area'),
      inverterKw: d('inv'),
      tiltDeg: d('tilt'),
      headM: d('head'),
      efficiency: d('eta'),
      yieldKWhPerKWp: d('yield'),
      generationKWh: d('gen'),
      consumptionKWh: d('cons'),
      gridCost: d('grid'),
      netCost: d('net'),
      fioBPaidPct: d('fiob'),
      selfConsumedKWh: d('self'),
      compensatedKWh: d('comp'),
      excessKWh: d('excess'),
      months: [for (final m in (j['months'] as List?) ?? const []) SolarMonthRow.fromJson((m as Map).cast<String, dynamic>())],
      criticalMonth: (j['crit'] as num?)?.toInt(),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Latitude of the site (degrees): the centre of the drawing on the
/// georeference, else the climate's, else 15° S.
double siteLatitude(Project p) {
  final g = p.meta.georef;
  if (g != null) {
    final b = p.bounds;
    final cx = b.isEmpty ? 0.0 : (b.minX + b.maxX) / 2, cy = b.isEmpty ? 0.0 : (b.minY + b.maxY) / 2;
    return g.toLatLon(cx, cy).$1;
  }
  final c = p.climate;
  if (c != null && c.latitudeDeg != 0) return c.latitudeDeg;
  return -15;
}

/// Total dynamic head of the design (m): the largest pump head or required
/// supply head of the system flows.
double designPumpingHead(DesignResults? r) {
  var head = 0.0;
  for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
    for (final d in f.devices) {
      head = math.max(head, d.pumpHead);
    }
    for (final s in f.supplies) {
      if (s.calculated) head = math.max(head, s.requiredHead);
    }
  }
  return head;
}

/// Wire-to-water efficiency of the pumping (the hydraulic power over the
/// electrical input of the pumps of the system flows; the design's pump
/// efficiency and an IE3 motor without catalogue pumps).
double designPumpingEfficiency(Project p, DesignResults? r) {
  var hyd = 0.0, input = 0.0;
  for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
    for (final d in f.devices) {
      if (d.pumpHead <= 0 || d.flow <= 0) continue;
      final e = p.byId(d.entityId);
      final pump = e is PumpEntity ? e : null;
      final spec = pump == null ? null : p.catalog.pump(pump.pumpSpecId);
      var eta = wireToWaterEfficiency(spec, pump, d.flow, speed: d.speedRatio, fallback: p.params.pumpEfficiency);
      if (pump != null && pump.motorEfficiency >= 1) {
        final kw = pumpMotorKw(p, pump, p.agb.pumpHouse.feederOf(pump.id), r);
        if (kw > 0) eta *= ie3Efficiency(kw, hz: p.params.mainsHz);
      }
      final ph = d.flow * d.pumpHead;
      hyd += ph;
      input += ph / math.max(eta, 0.05);
    }
  }
  if (input > 0) return hyd / input;
  return (p.params.pumpEfficiency * 0.9).clamp(0.05, 1.0).toDouble();
}

/// Daily volume of every month (m³/day, January first): the crop
/// requirement tables, else the volume of the system flows in a day.
List<double> designDailyVolumes(Project p, DesignResults? r) {
  final v = List<double>.filled(12, 0);
  for (final table in areaRequirementTables(p, r).values) {
    for (final row in table.monthly) {
      v[row.start.month - 1] += row.dailyVolumeM3;
    }
  }
  if (v.any((x) => x > 0)) return v;
  var day = 0.0;
  for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
    day += f.totalFlow * f.durationHours * 3600;
  }
  return List<double>.filled(12, day);
}

/// Yearly energy cost of the design on the grid: the system flows' (the
/// design total may already carry the solar compensation).
double designGridEnergyCost(DesignResults? r) => r == null ? 0 : r.systemFlows.fold(0.0, (a, f) => a + f.annualEnergyCost);

/// Yearly pumping energy of the design (kWh): the energy cost over the
/// tariff, or worked out at 1 per kWh when the tariff is zero.
double designPumpingEnergyKWh(Project p, DesignResults? r) {
  if (r == null) return 0;
  final tariff = p.params.powerCostPerKwh;
  if (tariff > 0) return designGridEnergyCost(r) / tariff;
  final flows = r.systemFlows;
  final total = flows.fold(0.0, (a, f) => a + f.durationHours);
  final eta = designPumpingEfficiency(p, r);
  var e = 0.0;
  for (final f in flows) {
    final share = total > 0 ? f.durationHours / total : 1.0;
    final hours = p.params.hoursPerYear * share;
    for (final d in f.devices) {
      if (d.pumpHead > 0) e += waterDensity * gravity * d.flow * d.pumpHead / eta / 1000 * hours;
    }
    for (final s in f.supplies) {
      if (s.calculated && s.requiredHead > 0) e += waterDensity * gravity * s.flow * s.requiredHead / eta / 1000 * hours;
    }
  }
  return e;
}

/// The solar design of [p] with its design [results] and [gridCost] (the
/// energy cost of the design on the grid alone); null when solar pumping is
/// off.
SolarDesign? designSolar(Project p, DesignResults? results, {double? gridCost}) {
  final s = p.agb.solar;
  if (!s.enabled) return null;
  final warnings = <String>[];
  final lat = siteLatitude(p);
  final tilt = s.tiltDeg ?? lat.abs();
  final radiation = p.climate?.solarKWhM2Day;
  if (radiation == null || radiation.length < 12) warnings.add('solar_no_radiation');
  final h = [for (var m = 0; m < 12; m++) radiation != null && radiation.length >= 12 ? radiation[m] : 5.0];
  final head = s.headM > 0 ? s.headM : designPumpingHead(results);
  final eta = s.motorPumpEfficiency > 0 ? s.motorPumpEfficiency.clamp(0.05, 1.0).toDouble() : designPumpingEfficiency(p, results);
  final tariff = p.params.powerCostPerKwh;
  final cost = gridCost ?? designGridEnergyCost(results);
  final year = DateTime.now().year;
  int days(int m) => DateTime.utc(year, m + 1).difference(DateTime.utc(year, m)).inDays;
  // irradiation on the array and the performance ratio of every month
  final ht = [for (var m = 1; m <= 12; m++) tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: h[m - 1], latitudeDeg: lat, month: m, tiltDeg: tilt, azimuthFromEquatorDeg: s.azimuthFromEquatorDeg)];
  final pr = pvPerformanceRatio(soiling: s.soiling, wiring: s.wiring, mismatch: s.mismatch);
  final yieldPerKWp = [for (var m = 1; m <= 12; m++) ht[m - 1] * pr * days(m)].fold(0.0, (a, b) => a + b);
  final wp = s.moduleWp > 0 ? s.moduleWp : 550.0;
  if (s.mode == SolarMode.offGrid) {
    final volumes = designDailyVolumes(p, results);
    if (!volumes.any((v) => v > 0) || head <= 0) warnings.add('solar_no_demand');
    // the pump drive carries the largest motor of the pumps, and the array
    // must give that motor its input at full sun (IEC 62253)
    var motor = 0.0;
    for (final e in p.entities.whereType<PumpEntity>()) {
      motor = math.max(motor, pumpMotorKw(p, e, p.agb.pumpHouse.feederOf(e.id), results));
    }
    final conv = s.converterEfficiency.clamp(0.05, 1.0).toDouble();
    final minKwp = motor > 0 && pr > 0 ? motor / ie3Efficiency(motor, hz: p.params.mainsHz) / (pr * conv) : 0.0;
    SolarPumpResult size(double oversize) => sizeSolarPumping(
      SolarPumpInput(
        months: [for (var m = 0; m < 12; m++) SolarPumpMonth(month: m + 1, dailyVolumeM3: volumes[m], horizontalKWhM2Day: h[m])],
        latitudeDeg: lat,
        headM: head,
        tiltDeg: tilt,
        azimuthFromEquatorDeg: s.azimuthFromEquatorDeg,
        motorPumpEfficiency: eta,
        converterEfficiency: conv,
        soiling: s.soiling,
        wiring: s.wiring,
        mismatch: s.mismatch,
        performanceRatio: pr,
        modulePowerWp: wp,
        oversize: oversize,
        gridTariffPerKWh: tariff,
        year: year,
      ),
    );
    var r = size(math.max(s.oversize, 1));
    if (minKwp > 0 && r.requiredKWp > 0 && r.arrayKWp < minKwp - 1e-9) {
      r = size(math.max(s.oversize, minKwp / r.requiredKWp));
      warnings.add('solar_array_motor');
    }
    warnings.addAll(r.warnings);
    final gen = [for (final m in r.months) r.arrayKWp * m.peakSunHours * m.performanceRatio * m.days];
    return SolarDesign(
      mode: s.mode,
      modules: r.modules,
      moduleWp: wp,
      arrayKWp: r.arrayKWp,
      areaM2: r.modules * s.moduleAreaM2,
      inverterKw: motor > 0 ? motor : r.arrayKWp,
      tiltDeg: tilt,
      headM: head,
      efficiency: eta,
      yieldKWhPerKWp: yieldPerKWp,
      generationKWh: gen.fold(0.0, (a, b) => a + b),
      consumptionKWh: r.annualHydraulicKWh / eta,
      gridCost: cost,
      netCost: 0,
      fioBPaidPct: 0,
      selfConsumedKWh: 0,
      compensatedKWh: 0,
      excessKWh: 0,
      months: [
        for (var i = 0; i < r.months.length; i++)
          SolarMonthRow(month: r.months[i].month, peakSunHours: r.months[i].peakSunHours, demandM3Day: r.months[i].demandM3Day, pumpedM3Day: r.months[i].pumpedM3Day, generationKWh: gen[i]),
      ],
      criticalMonth: r.criticalMonth,
      warnings: warnings,
    );
  }
  // ---- grid-tied
  final consumption = designPumpingEnergyKWh(p, results);
  if (consumption <= 0) warnings.add('solar_no_demand');
  if (tariff <= 0) warnings.add('solar_no_tariff');
  final need = yieldPerKWp > 0 ? consumption * math.max(s.oversize, 0.1) / yieldPerKWp : 0.0;
  final modules = need > 0 ? (need * 1000 / wp - 1e-9).ceil() : 0;
  final kwp = modules * wp / 1000;
  final generation = kwp * yieldPerKWp;
  final simul = s.simultaneity.clamp(0.0, 1.0).toDouble();
  final self = simul * math.min(generation, consumption);
  final injected = generation - self;
  final fromGrid = consumption - self;
  final credits = math.min(injected, fromGrid);
  final excess = math.max(0.0, injected - credits);
  if (excess > 0.05 * math.max(generation, 1e-9)) warnings.add('solar_excess');
  final paid = fioBSharePaid(s.billingYear, grandfathered: s.grandfathered);
  final fioB = s.fioBSharePct.clamp(0.0, 100.0) / 100;
  // the design's own cost over its energy prices the kWh; without results,
  // the tariff
  final perKWh = consumption > 0 && cost > 0 ? cost / consumption : tariff;
  final net = (fromGrid - credits) * perKWh + credits * perKWh * fioB * paid;
  return SolarDesign(
    mode: s.mode,
    modules: modules,
    moduleWp: wp,
    arrayKWp: kwp,
    areaM2: modules * s.moduleAreaM2,
    inverterKw: s.dcAcRatio > 0 ? kwp / s.dcAcRatio : kwp,
    tiltDeg: tilt,
    headM: head,
    efficiency: eta,
    yieldKWhPerKWp: yieldPerKWp,
    generationKWh: generation,
    consumptionKWh: consumption,
    gridCost: consumption * perKWh,
    netCost: math.max(0.0, net),
    fioBPaidPct: 100 * paid,
    selfConsumedKWh: self,
    compensatedKWh: credits,
    excessKWh: excess,
    months: [for (var m = 1; m <= 12; m++) SolarMonthRow(month: m, peakSunHours: ht[m - 1], demandM3Day: 0, pumpedM3Day: 0, generationKWh: kwp * ht[m - 1] * pr * days(m))],
    warnings: warnings,
  );
}
