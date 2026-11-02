/// "Subtract from area" and "Remove the islands of the area" in the editor
/// (1.6.0 MOD): one undo step each, with its label in the history; the
/// shape becomes the island and leaves the drawing.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/area_hole_commands.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

void main() {
  late ProjectController c;
  setUp(() {
    setPref('lang', 'en');
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    c.camera.center = const Pt(20, 15);
    c.camera.scale = 10;
  });

  String lastLabel() => c.historyEntries.where((h) => h.current).single.label;

  test('a closed polyline inside the lawn becomes its island; undo brings both back', () {
    c.addEntities([
      AreaEntity(id: 'lawn', name: 'Lawn', points: _rect(0, 0, 40, 30)),
      PolylineEntity(id: 'pond', points: _rect(10, 10, 20, 20), closed: true),
    ]);
    // only the shape selected: the area it lies in is cut
    c.select(['pond']);
    expect(c.subtractSelectedFromAreas(), 1);
    expect(lastLabel(), 'hist.subtractArea|1');
    final lawn = c.project.byId('lawn') as AreaEntity;
    expect(lawn.holes.length, 1);
    expect(lawn.area, closeTo(1100, 1e-9));
    expect(c.project.byId('pond'), isNull, reason: 'the shape is the island now');
    expect(c.selection, {'lawn'});
    c.undo();
    expect((c.project.byId('lawn') as AreaEntity).holes, isEmpty);
    expect(c.project.byId('pond'), isNotNull);
    // the islands taken away again
    c.select(['pond', 'lawn']);
    expect(c.subtractSelectedFromAreas(), 1);
    c.select(['lawn']);
    expect(c.clearSelectedAreaHoles(), 1);
    expect(lastLabel(), 'hist.clearAreaHoles|1');
    expect((c.project.byId('lawn') as AreaEntity).area, closeTo(1200, 1e-9));
  });

  test('a shape that misses the area is no undo step; nothing closed selected says so', () {
    c.addEntities([
      AreaEntity(id: 'lawn', points: _rect(0, 0, 40, 30)),
      PolylineEntity(id: 'far', points: _rect(50, 50, 60, 60), closed: true),
      LineEntity(id: 'line', a: Pt.zero, b: const Pt(5, 5)),
    ]);
    final steps = c.historyEntries.length;
    c.select(['far', 'lawn']);
    expect(c.subtractSelectedFromAreas(), 0);
    expect(c.historyEntries.length, steps);
    c.select(['line']);
    expect(c.subtractSelectedFromAreas(), 0);
    expect(c.lastMessage, c.t('area.subtract.noShape'));
    c.select(['lawn']);
    expect(c.clearSelectedAreaHoles(), 0);
    expect(c.lastMessage, c.t('area.holes.none'));
  });

  test('a strip across the field splits it in two areas', () {
    c.addEntities([
      AreaEntity(id: 'field', name: 'Field', points: _rect(0, 0, 40, 30)),
      PolylineEntity(id: 'road', points: _rect(18, -5, 22, 35), closed: true),
    ]);
    c.select(['road', 'field']);
    expect(c.subtractSelectedFromAreas(), 1);
    final areas = c.project.entities.whereType<AreaEntity>().toList();
    expect(areas.length, 2);
    expect(areas.map((a) => a.id), contains('field'));
    expect(areas.fold(0.0, (s, a) => s + a.area), closeTo(1080, 1e-6));
  });
}
