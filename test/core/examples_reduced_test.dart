import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/project.dart';

import '../support/language_packs.dart';

/// The shipped examples stored small (MOD-29): a compact file whose
/// catalogue keeps only what differs from the default one, read back into
/// the same project.
void main() {
  setUpAll(installLanguagePacksFromDisk);

  /// What tool/gen_examples.dart writes for [id] in [lang].
  (String, Project) shipped(ExampleId id, String lang) {
    final p = buildExample(id, I18n(lang).call, lang: lang);
    final j = p.toJson();
    (j['meta'] as Map<String, dynamic>).remove('uid');
    j['catalog'] = p.catalog.toReducedJson(lang: lang, currency: p.params.currencyCode, keep: p.catalogIdsInUse);
    return (jsonEncode(j), p);
  }

  test('a reduced, compact example reads back into the same project, at a fraction of the size', () {
    for (final (id, lang) in [(ExampleId.orchard, 'en'), (ExampleId.garden, 'pt'), (ExampleId.pivot, 'de'), (ExampleId.golf, 'ja')]) {
      final (text, built) = shipped(id, lang);
      final full = const JsonEncoder.withIndent('  ').convert(built.toJson());
      expect(text.length, lessThan(full.length / 3), reason: '$id $lang: ${text.length} against ${full.length}');
      final back = Project.fromJsonString(text);
      final a = back.toJson(), b = built.toJson();
      for (final j in [a, b]) {
        (j['meta'] as Map<String, dynamic>).remove('uid');
      }
      expect(jsonEncode(a), jsonEncode(b), reason: '$id $lang');
      expect(back.catalog.itemCount, built.catalog.itemCount);
      expect(jsonEncode(back.catalog.toJson()), isNot(contains('defaults')), reason: 'the marker is used up on reading');
    }
  });

  test('every copy opened gets its own identifier', () {
    final (text, _) = shipped(ExampleId.garden, 'en');
    expect(Project.fromJsonString(text).meta.uid, isNot(Project.fromJsonString(text).meta.uid));
  });

  test('items that differ from the default catalogue are kept whole', () {
    final c = Catalog.defaultCatalog();
    c.pipe('pvc75')!.enabled = false;
    c.pipe('pvc100')!.costPerM = 1;
    final r = c.toReducedJson(lang: 'en', currency: 'BRL');
    expect([for (final p in r['pipes'] as List) p['id']], ['pvc75', 'pvc100']);
    final back = Catalog.fromJson(jsonDecode(jsonEncode(r)) as Map<String, dynamic>);
    expect(back.pipe('pvc75')!.enabled, isFalse);
    expect(back.pipe('pvc100')!.costPerM, 1);
    expect([for (final p in back.pipes) p.id], [for (final p in c.pipes) p.id], reason: 'in their places');
  });
}
