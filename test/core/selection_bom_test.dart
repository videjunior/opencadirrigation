import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/model/entities.dart';

/// Materials of a selection (a stretch of the works, one order): pipes by
/// their drawn length, emitters and valves by the unit, at the catalogue
/// prices, and nothing for what is not selected.
void main() {
  test('pipes by the metre, emitters and valves by the unit, only what is selected', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.garden);
    final p = c.project;
    final drawn = p.entities.whereType<PipeEntity>().take(3).map((e) => e.id).toSet();
    expect(selectionBom(p, drawn).where((l) => l.category == 'bom.pipes'), isEmpty, reason: 'not sized yet');
    expect(unsizedPipeLength(p, drawn), greaterThan(0));
    c.results = Designer(p).designAll();
    final pipes = p.entities.whereType<PipeEntity>().take(3).toList();
    final outlets = p.entities.whereType<OutletEntity>().take(4).toList();
    final valve = p.entities.whereType<ControlValveEntity>().first;
    final ids = {for (final e in [...pipes, ...outlets, valve]) e.id};
    final lines = selectionBom(p, ids);

    final metres = lines.where((l) => l.category == 'bom.pipes').fold(0.0, (a, l) => a + l.quantity);
    expect(metres, closeTo(pipes.fold(0.0, (a, e) => a + e.length), 1e-9));
    expect(unsizedPipeLength(p, ids), 0);
    for (final l in lines.where((l) => l.category == 'bom.pipes')) {
      expect(l.unit, 'm');
      expect(l.unitCost, p.catalog.pipe(l.specId!)!.costPerM);
    }
    expect(lines.where((l) => l.category == 'bom.outlets').fold(0.0, (a, l) => a + l.quantity), outlets.length);
    final v = lines.singleWhere((l) => l.category == 'bom.valves');
    expect((v.quantity, v.unit, v.specId), (1.0, 'un', valve.valveSpecId));
    expect(lines.any((l) => l.category == 'bom.fittings'), isFalse, reason: 'fittings belong to the joints');
    for (final l in lines) {
      expect(l.total, closeTo(l.quantity * l.unitCost, 1e-9));
    }

    expect(selectionBom(p, {}), isEmpty);
    final drawing = p.entities.where((e) => e is LineEntity || e is PolylineEntity || e is TextEntity || e is AreaEntity).map((e) => e.id).toSet();
    expect(drawing, isNotEmpty);
    expect(selectionBom(p, drawing), isEmpty, reason: 'drawing items carry no materials');
  });
}
