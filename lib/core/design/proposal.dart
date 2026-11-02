/// Commercial quote built from the bill of materials of a design: sale
/// prices with the margin, labour, trench excavation, extra lines, discount,
/// taxes and freight; plus the trench volumes of the buried pipes.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/proposal_settings.dart';
import 'results.dart';

/// Trench of the buried pipes of one use and diameter.
class TrenchRow {
  TrenchRow({required this.scope, required this.nominalMm, required this.length, required this.width, required this.depth});
  final HydraulicScope scope;
  final double nominalMm;

  /// Length (m), width (m) and depth from the surface to the bottom (m).
  double length;
  final double width;
  final double depth;

  double get volume => length * width * depth;
}

/// Trenches of every buried pipe (depth > 0) of [project], grouped by use,
/// diameter, width and depth: width [ProposalSettings.trenchWidthM] or the
/// outside diameter plus 0.2 m (at least 0.3 m); depth = burial depth of the
/// pipe axis + half the diameter + the bedding.
List<TrenchRow> trenchRows(Project project, ProposalSettings s) {
  final rows = <String, TrenchRow>{};
  for (final e in project.entities.whereType<PipeEntity>()) {
    if (e.depth <= 0 || e.points.length < 2) continue;
    final spec = project.catalog.pipe(e.pipeSpecId);
    final od = (spec?.nominalMm ?? 50) / 1000;
    final width = s.trenchWidthM > 0 ? s.trenchWidthM : math.max(0.3, od + 0.2);
    final depth = e.depth + od / 2 + math.max(0.0, s.beddingM);
    final key = '${e.scope.name}|${spec?.nominalMm ?? 0}|$width|$depth';
    final row = rows.putIfAbsent(key, () => TrenchRow(scope: e.scope, nominalMm: spec?.nominalMm ?? 0, length: 0, width: width, depth: depth));
    row.length += polylineLength(e.points);
  }
  final out = rows.values.toList()..sort((a, b) => a.scope != b.scope ? a.scope.index.compareTo(b.scope.index) : b.nominalMm.compareTo(a.nominalMm));
  return out;
}

/// A priced line of the quote.
class ProposalLine {
  ProposalLine({required this.category, required this.description, required this.unit, required this.quantity, required this.unitPrice, this.code = '', this.finame = ''});
  final String category;
  final String description;
  final String unit;
  final double quantity;
  final double unitPrice;
  final String code;

  /// BNDES FINAME code of the item ('' = not credentialed).
  final String finame;
  double get total => quantity * unitPrice;
}

class Proposal {
  Proposal({
    required this.lines,
    required this.materialsCost,
    required this.materialsSale,
    required this.labour,
    required this.trenchVolume,
    required this.trenchCost,
    required this.extras,
    required this.discount,
    required this.taxes,
    required this.freight,
    required this.unpriced,
  });

  /// Materials at sale price (BOM lines with the margin), then the extra lines.
  final List<ProposalLine> lines;
  final double materialsCost;
  final double materialsSale;
  final double labour;
  final double trenchVolume;
  final double trenchCost;
  final double extras;
  final double discount;
  final double taxes;
  final double freight;

  /// BOM lines without a price (left out of the totals).
  final int unpriced;

  double get subtotal => materialsSale + labour + trenchCost + extras;
  double get total => subtotal - discount + taxes + freight;

  /// Gross margin of the materials (sale − cost).
  double get materialsMargin => materialsSale - materialsCost;
}

/// Economics of the investment [total] that returns [annualBenefit] a year
/// while it costs [annualCost] (energy) to run, over [years] at the
/// discount [rate] (fraction): simple payback, net present value and
/// internal rate of return (bisection on NPV = 0; null when the yearly net
/// is not positive).
class Payback {
  Payback({required this.total, required this.annualBenefit, required this.annualCost, required this.years, required this.rate});
  final double total;
  final double annualBenefit;
  final double annualCost;
  final int years;
  final double rate;

  double get annualNet => annualBenefit - annualCost;

  /// Years to recover the investment from the yearly net (∞ when none).
  double get simpleYears => annualNet > 0 ? total / annualNet : double.infinity;

  double npvAt(double r) {
    var v = -total;
    for (var y = 1; y <= years; y++) {
      v += annualNet / math.pow(1 + r, y);
    }
    return v;
  }

  double get npv => npvAt(rate);

  double? get irr {
    if (annualNet <= 0 || years <= 0 || npvAt(0) <= 0) return null;
    var lo = 0.0, hi = 1.0;
    while (npvAt(hi) > 0 && hi < 1e3) {
      hi *= 2;
    }
    for (var i = 0; i < 100; i++) {
      final mid = (lo + hi) / 2;
      if (npvAt(mid) > 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

/// The quote of [results] under [s].
Proposal buildProposal(Project project, DesignResults results, ProposalSettings s) {
  final markup = 1 + s.markupPct / 100;
  final lines = <ProposalLine>[];
  var cost = 0.0, sale = 0.0;
  var unpriced = 0;
  for (final l in results.bom) {
    if (l.unitCost <= 0) unpriced++;
    final price = l.unitCost * markup;
    cost += l.total;
    sale += l.quantity * price;
    lines.add(ProposalLine(category: l.category, description: l.description, unit: l.unit, quantity: l.quantity, unitPrice: price, code: l.code, finame: l.finame));
  }
  var extras = 0.0;
  for (final x in s.extras) {
    if (x.description.trim().isEmpty && x.total == 0) continue;
    extras += x.total;
    lines.add(ProposalLine(category: 'proposal.extra', description: x.description, unit: x.unit, quantity: x.quantity, unitPrice: x.unitPrice));
  }
  final labour = cost * s.labourPct / 100;
  final volume = trenchRows(project, s).fold(0.0, (a, r) => a + r.volume);
  final trenchCost = volume * s.trenchCostPerM3;
  final subtotal = sale + labour + trenchCost + extras;
  final discount = subtotal * s.discountPct / 100;
  final taxes = (subtotal - discount) * s.taxPct / 100;
  return Proposal(
    lines: lines,
    materialsCost: cost,
    materialsSale: sale,
    labour: labour,
    trenchVolume: volume,
    trenchCost: trenchCost,
    extras: extras,
    discount: discount,
    taxes: taxes,
    freight: s.freight,
    unpriced: unpriced,
  );
}

// ---------------------------------------------------------------- construction schedule

/// One task of the construction schedule: the quantity of work, the output
/// of a crew per day, the working days and when it starts and ends (working
/// days from the start of the works).
class ScheduleTask {
  ScheduleTask({required this.key, required this.quantity, required this.unit, required this.perDay, required this.days, required this.start});
  final String key;
  final double quantity;
  final String unit;
  final double perDay;
  final int days;
  int start;
  int get end => start + days;
}

/// Output of a crew per working day by task (units of the task's
/// quantity): staking out (ha), trench excavation and backfill (m³), buried
/// pipe laying (m), valves and devices (units), laterals and tapes (m),
/// emitters on risers (units), valve wiring (m), pump and filter station
/// (units) and the pressure test and flushing (zones). Typical figures for
/// a small crew with a trencher; the project may set its own.
const defaultProductivity = <String, double>{'staking': 20, 'trench': 40, 'pipe': 300, 'backfill': 80, 'valves': 6, 'laterals': 3000, 'emitters': 200, 'wiring': 800, 'station': 1, 'testing': 4};

/// The construction schedule of the project: the tasks with work to do, in
/// working days, each starting when the work it follows has started (and
/// ending after it): staking out first; trenches, pipes and backfill
/// following each other a day apart; valves, wiring, laterals and emitters
/// once the buried pipes are laid; the pumping station in parallel; the
/// test and flushing at the end. [crews] crews share every task.
List<ScheduleTask> scheduleTasks(Project p, ProposalSettings s) {
  double rate(String k) => s.productivity[k] ?? defaultProductivity[k]!;
  final crews = math.max(1, s.crews);
  int days(String k, double qty) => qty <= 0 ? 0 : math.max(1, (qty / (rate(k) * crews)).ceil());
  var areaHa = 0.0, buried = 0.0, laterals = 0.0, wire = 0.0;
  var valves = 0, emitters = 0, station = 0;
  final zones = p.entities.whereType<ControlValveEntity>().length;
  for (final e in p.entities) {
    switch (e) {
      case AreaEntity a when a.points.length >= 3:
        areaHa += a.area / 10000;
      case PipeEntity pe:
        if (pe.depth > 0 || pe.scope == HydraulicScope.mainline) {
          buried += pe.length;
        } else {
          laterals += pe.length;
        }
      case TapeEntity t:
        laterals += t.length;
      case SpraylineEntity sl:
        laterals += sl.length;
        emitters += sl.outletCount;
      case OutletEntity _:
        emitters++;
      case ControlValveEntity _:
        valves++;
      case MiscHydraulicEntity _:
        valves++;
      case PumpEntity _:
        station++;
      case WaterSupplyEntity _:
        station++;
      case WireEntity w:
        wire += w.length;
      default:
        break;
    }
  }
  final trench = trenchRows(p, s).fold(0.0, (a, r) => a + r.volume);
  if (areaHa <= 0) areaHa = p.bounds.isEmpty ? 0 : p.bounds.width * p.bounds.height / 10000;
  final tasks = <ScheduleTask>[];
  ScheduleTask? add(String k, double qty, String unit, {ScheduleTask? after, int lag = -1}) {
    final d = days(k, qty);
    if (d == 0) return null;
    // start: [lag] days after the start of [after] (-1: when it ends), and
    // never ending before it
    var start = after == null ? 0 : (lag < 0 ? after.end : after.start + lag);
    if (after != null && start + d < after.end + (lag < 0 ? 0 : 1)) start = after.end + (lag < 0 ? 0 : 1) - d;
    final t = ScheduleTask(key: k, quantity: qty, unit: unit, perDay: rate(k), days: d, start: math.max(0, start));
    tasks.add(t);
    return t;
  }

  final staking = add('staking', areaHa, 'ha');
  final dig = add('trench', trench, 'm³', after: staking);
  final pipes = add('pipe', buried, 'm', after: dig ?? staking, lag: dig == null ? -1 : 1) ?? dig;
  add('backfill', trench, 'm³', after: pipes, lag: 1);
  final v = add('valves', valves.toDouble(), 'un', after: pipes ?? staking);
  add('wiring', wire, 'm', after: v ?? pipes ?? staking, lag: 0);
  final lat = add('laterals', laterals, 'm', after: v ?? pipes ?? staking, lag: 0);
  add('emitters', emitters.toDouble(), 'un', after: lat ?? v ?? pipes ?? staking, lag: 1);
  add('station', station.toDouble(), 'un', after: staking);
  final last = tasks.fold(0, (m, t) => math.max(m, t.end));
  final test = add('testing', math.max(1, zones).toDouble(), 'un');
  test?.start = last;
  return tasks;
}

// ---------------------------------------------------------------- materials of a selection

/// The materials of the entities [ids] only (a stretch of the works, one
/// order): pipes and tapes by the metre, emitters, valves, devices, pumps
/// and controllers by the unit, at the catalogue prices. Fittings, which
/// belong to the joints between items, are left out, and so are pipes not
/// sized yet ([unsizedPipeLength]).
List<BomLine> selectionBom(Project p, Set<String> ids) {
  final cat = p.catalog;
  final lines = <String, BomLine>{};
  void add(String category, String description, String unit, double qty, double cost, String? specId, {String code = '', String supplier = ''}) {
    if (qty <= 0) return;
    final key = '$category|$description';
    final l = lines[key];
    if (l != null) {
      l.quantity += qty;
    } else {
      lines[key] = BomLine(
        category: category,
        description: description,
        unit: unit,
        quantity: qty,
        unitCost: cost,
        specId: specId,
        code: code,
        supplier: supplier,
        finame: specId == null ? '' : (cat.finame[specId] ?? ''),
      );
    }
  }

  for (final e in p.entities) {
    if (!ids.contains(e.id)) continue;
    switch (e) {
      case PipeEntity pe:
        final s = cat.pipe(pe.pipeSpecId);
        if (s != null) add('bom.pipes', s.name, 'm', pe.length, s.costPerM, s.id, code: s.code, supplier: s.supplier);
      case TapeEntity te:
        final s = cat.tape(te.tapeSpecId);
        if (s != null) add('bom.tapes', s.name, 'm', te.length, s.costPerM, s.id, code: s.code, supplier: s.supplier);
      case SpraylineEntity sl:
        final pipe = cat.pipe(sl.pipeSpecId);
        if (pipe != null) add('bom.pipes', pipe.name, 'm', sl.length, pipe.costPerM, pipe.id, code: pipe.code, supplier: pipe.supplier);
        final o = cat.outlet(sl.outletSpecId);
        if (o != null) add('bom.outlets', '${o.name} — ${o.nozzle(sl.nozzleId)?.name ?? ''}', 'un', sl.outletCount.toDouble(), o.cost, o.id, code: o.code, supplier: o.supplier);
      case OutletEntity oe:
        final o = cat.outlet(oe.outletSpecId);
        if (o != null) add('bom.outlets', '${o.name} — ${o.nozzle(oe.nozzleId)?.name ?? ''}', 'un', 1, o.cost, o.id, code: o.code, supplier: o.supplier);
      case ControlValveEntity v:
        final s = cat.valve(v.valveSpecId);
        if (s != null) add('bom.valves', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
      case MiscHydraulicEntity m:
        final s = cat.valve(m.valveSpecId);
        if (s != null) add('bom.devices', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
      case PumpEntity pu:
        final s = cat.pump(pu.pumpSpecId);
        if (s != null) add('bom.pumps', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
      default:
        break;
    }
  }
  return lines.values.toList()..sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
}

/// Length (m) of the pipes among [ids] that have no catalogue size yet.
double unsizedPipeLength(Project p, Set<String> ids) {
  var m = 0.0;
  for (final e in p.entities) {
    if (!ids.contains(e.id)) continue;
    if (e is PipeEntity && p.catalog.pipe(e.pipeSpecId) == null) m += e.length;
    if (e is SpraylineEntity && p.catalog.pipe(e.pipeSpecId) == null) m += e.length;
  }
  return m;
}
