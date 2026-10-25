import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

void main() {
  final t = I18n('pt');

  // Supply → L-shaped mainline (one 90° bend, one 30° bend) → junction where
  // a straight run continues to valve A and a branch leaves at 90° to valve B.
  Project build(MinorLossMethod method) {
    final p = Project();
    p.params.minorLossMethod = method;
    p.entities.add(WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: 40, maxHeadM: 40));
    p.entities.add(PipeEntity(id: 'main', points: [Pt.zero, const Pt(100, 0), const Pt(100, 100), const Pt(150, 128.87)], scope: HydraulicScope.mainline));
    p.entities.add(PipeEntity(id: 'runA', points: [const Pt(150, 128.87), const Pt(200, 157.74)], scope: HydraulicScope.mainline));
    p.entities.add(PipeEntity(id: 'branchB', points: [const Pt(150, 128.87), const Pt(175, 85.57)], scope: HydraulicScope.mainline));
    for (final (id, pos) in [('vA', const Pt(200, 157.74)), ('vB', const Pt(175, 85.57))]) {
      p.entities.add(ControlValveEntity(id: id, position: pos, zoneName: id, valveSpecId: 'ev50'));
      p.entities.add(PipeEntity(id: '${id}z', points: [pos, pos + const Pt(0, 12)], scope: HydraulicScope.zone));
      for (var i = 0; i < 3; i++) {
        p.entities.add(SpraylineEntity(id: '$id$i', points: [pos + Pt(0, 2 + i * 4.0), pos + Pt(40, 2 + i * 4.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      }
    }
    return p;
  }

  double kOf(NetworkModel m, String entityId) => m.links.where((l) => l.entityId == entityId).fold(0.0, (s, l) => s + l.minorK);

  test('the fittings method gives bends and tees their K; the percent method none', () {
    final m = NetworkBuilder(build(MinorLossMethod.fittings)).build();
    // 90° bend (elbow) + 60° turn at the second vertex (45° elbow class) on the main
    // pipe, then half the run K at the tee
    expect(kOf(m, 'main'), closeTo(FittingK.elbow90Standard + FittingK.elbow45 + FittingK.teeRun / 2, 1e-9));
    expect(kOf(m, 'runA'), closeTo(FittingK.teeRun / 2, 1e-9));
    expect(kOf(m, 'branchB'), closeTo(FittingK.teeBranch, 1e-9));
    // laterals keep only their emitter barbs, which the percent method also has
    final pct = NetworkBuilder(build(MinorLossMethod.percent)).build();
    expect(kOf(pct, 'main'), 0);
    expect(kOf(pct, 'branchB'), 0);
    expect(kOf(m, 'vA0'), closeTo(kOf(pct, 'vA0'), 1e-12));
  });

  test('the design uses the fitting losses instead of the length percentage', () {
    double supplyLoss(MinorLossMethod method, {bool apply = true}) {
      final p = build(method);
      p.params.applyMinorLosses = apply;
      p.params.sizingMethod = SizingMethod.greedy;
      for (final e in p.entities.whereType<PipeEntity>()) {
        if (e.scope == HydraulicScope.mainline) {
          e.computerSized = false;
          e.pipeSpecId = 'pvc75';
        }
      }
      final r = Designer(p, label: (k) => t(k)).designAll();
      final f = r.systemFlows.single;
      return f.pipes.where((s) => s.entityId == 'main').fold(0.0, (a, s) => a + s.headLoss);
    }

    final none = supplyLoss(MinorLossMethod.percent, apply: false);
    final pct = supplyLoss(MinorLossMethod.percent);
    final fit = supplyLoss(MinorLossMethod.fittings);
    expect(pct, closeTo(none * 1.05, none * 0.02)); // 5 % of the length
    expect(fit, greaterThan(none));
    expect(fit, isNot(closeTo(pct, 1e-6)));
  });

  test('the method survives the project file', () {
    final p = build(MinorLossMethod.fittings);
    final back = DesignParameters.fromJson(p.params.toJson());
    expect(back.minorLossMethod, MinorLossMethod.fittings);
    expect(DesignParameters.fromJson({'minorMethod': 'nonsense'}).minorLossMethod, MinorLossMethod.percent);
    expect(DesignParameters.fromJson(const {}).minorLossMethod, MinorLossMethod.percent);
  });
}
