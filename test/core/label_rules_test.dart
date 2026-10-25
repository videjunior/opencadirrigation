import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/label_rules.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Conditional labels: values of the results by rule, display units, and
/// the rules kept in the project file.
void main() {
  test('values and conditions of the rules on a designed example', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.orchard);
    final r = Designer(c.project).designAll();
    final pipes = r.pipesByEntity.values.where((s) => s.isNotEmpty).toList();
    expect(pipes, isNotEmpty);
    final segs = pipes.first;
    final v = LabelRule.ofPipe('velocity', segs)!;
    expect(v, closeTo(segs.map((s) => s.velocity).reduce((a, b) => a > b ? a : b), 1e-12));
    expect(LabelRule.ofPipe('pressure', segs)!, lessThanOrEqualTo(segs.first.pressureStart));
    final rule = LabelRule(field: 'velocity', op: '>', value: v - 0.01);
    expect(rule.holds(v), isTrue);
    expect(LabelRule(field: 'velocity', op: '<', value: v - 0.01).holds(v), isFalse);
    expect(LabelRule(op: 'any').holds(-5), isTrue);
    final z = r.zones.values.first;
    expect(LabelRule.ofValve('flow', z), z.totalFlow);
    expect(LabelRule.ofOutlet('pressure', const []), isNull);
  });

  test('thresholds are kept in SI and shown in the display units', () {
    final u = Units(pressure: PressureUnit.kPa);
    final si = LabelRule.toSi('pressure', 98.0665, u);
    expect(si, closeTo(10, 1e-6));
    final (shown, unit) = LabelRule.display('pressure', si, u);
    expect(shown, closeTo(98.0665, 1e-6));
    expect(unit, 'kPa');
  });

  test('rules travel with the project', () {
    final p = Project()..labelRules.add(LabelRule(target: 'outlets', field: 'pressure', op: '<', value: 15, color: 0xFFFFEB3B, enabled: false));
    final back = Project.fromJson(jsonDecode(p.toJsonString()) as Map<String, dynamic>);
    final r = back.labelRules.single;
    expect((r.target, r.field, r.op, r.value, r.color, r.enabled), ('outlets', 'pressure', '<', 15.0, 0xFFFFEB3B, false));
  });
}
