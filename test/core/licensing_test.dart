import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The informative licensing category of Brazilian Resolution CONAMA
/// 284/2001: irrigated area by method, a machine on a drawn field counted
/// once.
void main() {
  // The table of Art. 1º of the resolution: sprinkler A < 100 ha, B 100–500,
  // C > 500; localized A < 500, B 500–1000, C > 1000; surface A < 50,
  // B 50–500, C > 500.
  test('category limits by method (Art. 1º of the resolution)', () {
    expect(conamaCategory('sprinkler', 99.9), 'A');
    expect(conamaCategory('sprinkler', 100), 'B');
    expect(conamaCategory('sprinkler', 500), 'B');
    expect(conamaCategory('sprinkler', 500.1), 'C');
    // 600 ha of pivots: category C (studies of Annex II)
    expect(conamaCategory('sprinkler', 600), 'C');
    expect(conamaCategory('localized', 499), 'A');
    expect(conamaCategory('localized', 800), 'B');
    expect(conamaCategory('localized', 1000), 'B');
    expect(conamaCategory('localized', 1000.1), 'C');
    expect(conamaCategory('surface', 49), 'A');
    expect(conamaCategory('surface', 100), 'B');
    // 300 ha of furrows: category B, not C
    expect(conamaCategory('surface', 300), 'B');
    expect(conamaCategory('surface', 500), 'B');
    expect(conamaCategory('surface', 501), 'C');
  });

  test('the category limits shown in the report match the classification in every language', () {
    // "A < a ha; B a–b ha; C > b ha" in the compiled table and in the packs
    void check(String lang, String method, String text) {
      final n = RegExp(r'\d+').allMatches(text).map((m) => double.parse(m.group(0)!)).toList();
      expect(n, hasLength(4), reason: '$lang $method: $text');
      expect(conamaCategory(method, n[0] - 0.1), 'A', reason: '$lang $method: $text');
      expect(conamaCategory(method, n[1]), 'B', reason: '$lang $method: $text');
      expect(conamaCategory(method, n[2]), 'B', reason: '$lang $method: $text');
      expect(conamaCategory(method, n[3] + 0.1), 'C', reason: '$lang $method: $text');
    }

    const methods = ['sprinkler', 'localized', 'surface'];
    for (final lang in const ['pt', 'en', 'es']) {
      for (final m in methods) {
        check(lang, m, I18n(lang)('lic.limits.$m'));
      }
    }
    final packs = Directory('assets/i18n').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(packs, hasLength(17));
    for (final f in packs) {
      final json = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['strings'] as Map<String, dynamic>;
      for (final m in methods) {
        check(f.uri.pathSegments.last, m, json['lic.limits.$m'] as String);
      }
    }
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
