/// Automatic selection of pipe fittings (couplers, elbows, tees, crosses,
/// reducers, end caps, adapters, lateral take-offs, line ends, risers) from
/// the connected network, for the bill of materials (costing step).
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'network_builder.dart';
import 'results.dart';

class FittingNeed {
  FittingNeed(this.kind, this.sizeMm, {this.size2Mm = 0});
  final FittingKind kind;
  final double sizeMm;
  final double size2Mm;
  String get key => '${kind.name}|${sizeMm.toStringAsFixed(1)}|${size2Mm.toStringAsFixed(1)}';
}

class FittingSelection {
  FittingSelection({required this.lines, required this.missing});
  final List<BomLine> lines;

  /// Needs with no matching catalog item (kind and size), for messages.
  final List<FittingNeed> missing;
}

/// Names for generic (catalog-less) fittings, per kind.
String genericFittingName(FittingKind k, double sizeMm, double size2Mm, String Function(String key) t) {
  String mm(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  final size = size2Mm > 0 && (size2Mm - sizeMm).abs() > 0.5 ? '${mm(sizeMm)} × ${mm(size2Mm)} mm' : (sizeMm > 0 ? '${mm(sizeMm)} mm' : '');
  return '${t('fit.${k.name}')} $size'.trim();
}

/// Selects the fittings of a built network. [specOf] gives the pipe spec of
/// a link (after sizing). Returns BOM lines grouped by catalog item.
FittingSelection selectFittings(Project project, NetworkModel model, PipeSpec? Function(GLink) specOf, {required String Function(String key) t}) {
  final cat = project.catalog;
  final params = project.params;
  final needs = <String, (FittingNeed, double)>{};
  void need(FittingKind k, double size, {double size2 = 0, double qty = 1}) {
    final n = FittingNeed(k, size, size2Mm: size2);
    final cur = needs[n.key];
    needs[n.key] = (n, (cur?.$2 ?? 0) + qty);
  }

  double sizeOf(GLink l) {
    final tape = cat.tape(l.tapeSpecId);
    if (tape != null) return tape.nominalMm;
    return specOf(l)?.nominalMm ?? 0;
  }

  Pt dirFrom(GLink l, String nodeId) {
    final a = l.a, b = l.b;
    return l.from == nodeId ? (b - a).normalized : (a - b).normalized;
  }

  final entityById = {for (final e in project.entities) e.id: e};
  final lateralEntities = <String>{for (final e in project.entities) if (e is SpraylineEntity || e is TapeEntity) e.id};

  for (final n in model.nodes.values) {
    final pipes = n.links.where((l) => l.kind == GLinkKind.pipe && sizeOf(l) > 0).toList();
    final mains = pipes.where((l) => !lateralEntities.contains(l.entityId)).toList();
    final laterals = pipes.where((l) => lateralEntities.contains(l.entityId)).toList();
    Entity? valve, device, supply, outlet;
    for (final id in n.entityIds) {
      final e = entityById[id];
      switch (e) {
        case ControlValveEntity _:
          valve = e;
        case MiscHydraulicEntity _ || PumpEntity _:
          device = e;
        case WaterSupplyEntity _:
          supply = e;
        case OutletEntity _:
          outlet = e;
        default:
          break;
      }
    }
    // in-line devices sit between an upstream and a downstream node: count
    // the adapters once, on the upstream node (the one holding the device link "from")
    final devLink = n.links.where((l) => l.kind != GLinkKind.pipe).toList();
    if (devLink.isNotEmpty && (valve != null || device != null)) {
      for (final l in devLink) {
        if (l.from != n.id) continue;
        double dsize = 0;
        if (valve != null) dsize = cat.valve((valve as ControlValveEntity).valveSpecId)?.sizeMm ?? 0;
        if (device is MiscHydraulicEntity) dsize = cat.valve(device.valveSpecId)?.sizeMm ?? 0;
        final pipeSize = mains.isNotEmpty ? mains.map(sizeOf).reduce(math.max) : (laterals.isNotEmpty ? sizeOf(laterals.first) : 0.0);
        if (dsize <= 0) dsize = pipeSize;
        if (dsize > 0) need(FittingKind.adapter, dsize, qty: 2);
        if (pipeSize > 0 && dsize > 0 && (pipeSize - dsize).abs() > 0.5) need(FittingKind.reducer, math.max(pipeSize, dsize), size2: math.min(pipeSize, dsize), qty: 2);
      }
    }
    if (mains.isEmpty) {
      // lateral-only node: handled per lateral entity below
      continue;
    }
    final sizes = mains.map(sizeOf).toList();
    final maxSize = sizes.reduce(math.max);
    final deg = mains.length;
    final hasPoint = valve != null || device != null || supply != null || outlet != null;
    if (deg == 1) {
      if (!hasPoint && laterals.isEmpty && devLink.isEmpty) need(FittingKind.endCap, sizes.first);
      if (outlet != null) {
        final s = cat.outlet((outlet as OutletEntity).outletSpecId);
        if (s != null) need(FittingKind.riser, s.inletMm);
      }
      continue;
    }
    if (deg == 2) {
      final l1 = mains[0], l2 = mains[1];
      final d1 = dirFrom(l1, n.id), d2 = dirFrom(l2, n.id);
      // deflection angle between the incoming and outgoing directions
      final cosDef = (-d1).dot(d2).clamp(-1.0, 1.0);
      final deflection = math.acos(cosDef) * 180 / math.pi;
      final s1 = sizeOf(l1), s2 = sizeOf(l2);
      final differ = (s1 - s2).abs() > 0.5;
      if (deflection > 60) {
        need(FittingKind.elbow90, maxSize);
      } else if (deflection > 15) {
        need(FittingKind.elbow45, maxSize);
      } else if (l1.entityId != l2.entityId && !differ && devLink.isEmpty) {
        need(FittingKind.coupler, maxSize);
      }
      if (differ) need(FittingKind.reducer, math.max(s1, s2), size2: math.min(s1, s2));
      if (outlet != null) {
        final s = cat.outlet((outlet as OutletEntity).outletSpecId);
        if (s != null) {
          need(FittingKind.tee, maxSize, size2: s.inletMm > 0 ? math.min(s.inletMm, maxSize) : 0);
          need(FittingKind.riser, s.inletMm);
        }
      }
      continue;
    }
    if (deg == 3) {
      // branch = the link whose direction is closest to perpendicular to the others
      var branch = 0;
      var bestScore = double.infinity;
      for (var i = 0; i < 3; i++) {
        final others = [for (var j = 0; j < 3; j++) if (j != i) dirFrom(mains[j], n.id)];
        final straight = (-others[0]).dot(others[1]);
        final score = -straight; // the more collinear the other two, the better
        if (score < bestScore) {
          bestScore = score;
          branch = i;
        }
      }
      final run = [for (var i = 0; i < 3; i++) if (i != branch) sizeOf(mains[i])];
      final runSize = run.reduce(math.max);
      final branchSize = sizeOf(mains[branch]);
      need(FittingKind.tee, math.max(runSize, branchSize), size2: branchSize < runSize - 0.5 ? branchSize : 0);
      if ((run[0] - run[1]).abs() > 0.5) need(FittingKind.reducer, run.reduce(math.max), size2: run.reduce(math.min));
      if (branchSize > runSize + 0.5) need(FittingKind.reducer, branchSize, size2: runSize);
      continue;
    }
    need(FittingKind.cross, maxSize);
    for (final s in sizes) {
      if (s < maxSize - 0.5) need(FittingKind.reducer, maxSize, size2: s);
    }
  }

  // lateral take-offs, line ends and risers per lateral entity
  final nodeOfPt = <String, GNode>{};
  for (final n in model.nodes.values) {
    nodeOfPt['${n.p.x.toStringAsFixed(3)}|${n.p.y.toStringAsFixed(3)}|${n.scope.name}'] = n;
  }
  GNode? nodeAt(Pt p, HydraulicScope s) => nodeOfPt['${p.x.toStringAsFixed(3)}|${p.y.toStringAsFixed(3)}|${s.name}'];
  bool connectsToMain(GNode? n, String self) => n != null && n.links.any((l) => l.kind == GLinkKind.pipe && l.entityId != self && !lateralEntities.contains(l.entityId));
  for (final e in project.entities) {
    if (model.unconnectedEntities.contains(e.id)) continue;
    switch (e) {
      case SpraylineEntity s:
        final links = model.links.where((l) => l.entityId == s.id);
        if (links.isEmpty) break;
        final size = cat.pipe(links.first.pipeSpecId ?? s.pipeSpecId)?.nominalMm ?? 16;
        final startMain = connectsToMain(nodeAt(s.points.first, HydraulicScope.zone), s.id);
        final endMain = connectsToMain(nodeAt(s.points.last, HydraulicScope.zone), s.id);
        if (startMain) need(FittingKind.takeOff, size);
        if (endMain) need(FittingKind.takeOff, size);
        if (!startMain) need(FittingKind.endCap, size);
        if (!endMain) need(FittingKind.endCap, size);
        final outlet = cat.outlet(s.outletSpecId);
        if (outlet != null && s.outletCount > 0) need(FittingKind.riser, outlet.inletMm, qty: s.outletCount.toDouble());
      case TapeEntity tp:
        final spec = cat.tape(tp.tapeSpecId);
        final size = spec?.nominalMm ?? 16;
        final startMain = connectsToMain(nodeAt(tp.points.first, HydraulicScope.zone), tp.id);
        final endMain = connectsToMain(nodeAt(tp.points.last, HydraulicScope.zone), tp.id);
        if (startMain) need(FittingKind.takeOff, size);
        if (endMain) need(FittingKind.takeOff, size);
        if (!startMain) need(FittingKind.tapeEnd, size);
        if (!endMain) need(FittingKind.tapeEnd, size);
      case PipeEntity p:
        if (params.pipeStickLengthM > 0) {
          final links = model.links.where((l) => l.entityId == p.id).toList();
          if (links.isEmpty) break;
          final size = specOf(links.first)?.nominalMm ?? 0;
          final n = (p.length / params.pipeStickLengthM).floor();
          if (size > 0 && n > 0) need(FittingKind.coupler, size, qty: n.toDouble());
        }
      default:
        break;
    }
  }

  // resolve against the catalog
  final byItem = <String, BomLine>{};
  final missing = <FittingNeed>[];
  String category(FittingKind k) => switch (k) {
    FittingKind.takeOff || FittingKind.tapeEnd => 'bom.takeoffs',
    FittingKind.riser => 'bom.risers',
    _ => 'bom.fittings',
  };
  for (final (n, qty) in needs.values) {
    final f = cat.findFitting(n.kind, n.sizeMm, size2Mm: n.size2Mm);
    if (f == null) {
      missing.add(n);
      final desc = '${genericFittingName(n.kind, n.sizeMm, n.size2Mm, t)} *';
      final key = 'generic|$desc';
      final cur = byItem[key];
      if (cur != null) {
        cur.quantity += qty;
      } else {
        byItem[key] = BomLine(category: category(n.kind), description: desc, unit: 'un', quantity: qty, unitCost: 0);
      }
      continue;
    }
    final cur = byItem[f.id];
    if (cur != null) {
      cur.quantity += qty;
    } else {
      byItem[f.id] = BomLine(category: category(n.kind), description: f.name, unit: 'un', quantity: qty, unitCost: f.cost, specId: f.id, code: f.code, supplier: f.supplier);
    }
  }
  for (final l in byItem.values) {
    l.quantity = l.quantity.ceilToDouble();
  }
  return FittingSelection(lines: byItem.values.toList(), missing: missing);
}
