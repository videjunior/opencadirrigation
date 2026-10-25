import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The informative licensing category of Brazilian Resolution CONAMA
/// 284/2001: irrigated area by method, a machine on a drawn field counted
/// once.
void main() {
  test('category limits by method', () {
    expect(conamaCategory('sprinkler', 99.9), 'A');
    expect(conamaCategory('sprinkler', 100), 'B');
    expect(conamaCategory('sprinkler', 1000), 'B');
    expect(conamaCategory('sprinkler', 1000.1), 'C');
    expect(conamaCategory('localized', 499), 'A');
    expect(conamaCategory('localized', 800), 'B');
    expect(conamaCategory('surface', 49), 'A');
    expect(conamaCategory('surface', 100), 'B');
    expect(conamaCategory('surface', 101), 'C');
  });

  test('areas by method; a pivot inside a drawn field is not counted twice', () {
    final p = Project();
    List<Pt> square(double side, [Pt o = Pt.zero]) => [o, o + Pt(side, 0), o + Pt(side, side), o + Pt(0, side)];
    p.entities.add(AreaEntity(id: 'a1', points: square(1000), irrigationMethod: 'localized')); // 100 ha
    p.entities.add(AreaEntity(id: 'a2', points: square(800, const Pt(2000, 0)))); // 64 ha sprinkler
    p.entities.add(PivotEntity(id: 'pv1', center: const Pt(2400, 400), radiusM: 300, endThrowM: 0)); // inside a2
    p.entities.add(PivotEntity(id: 'pv2', center: const Pt(5000, 0), radiusM: 600, endThrowM: 0)); // ≈ 113 ha alone
    final rows = licensingRows(p);
    final byMethod = {for (final (m, ha, cat) in rows) m: (ha, cat)};
    expect(byMethod['localized']!.$1, closeTo(100, 1e-6));
    expect(byMethod['localized']!.$2, 'A');
    expect(byMethod['sprinkler']!.$1, closeTo(64 + 113.1, 0.5));
    expect(byMethod['sprinkler']!.$2, 'B');
    expect(byMethod.containsKey('surface'), isFalse);
  });
}
