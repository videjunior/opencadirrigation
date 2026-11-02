/// tool/i18n_review.dart: the review files a native speaker fills in (the
/// rows, their notes, CSV and XLSX) and the import that checks the reviews and
/// writes them into a copy of a pack without disturbing the rest of the file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';

import '../tool/i18n_review.dart' hide main;

void main() {
  late ReviewContext ctx;
  setUpAll(() => ctx = ReviewContext.load());

  Map<String, Map<String, String>> pack(String lang, [String dir = 'assets/i18n']) => packSections(File('$dir/$lang.json').readAsStringSync());
  ReviewRow row(List<ReviewRow> rows, String key, [String section = 'strings']) => rows.firstWhere((r) => r.section == section && r.key == key);
  String notes(ReviewRow r) => r.notes.join(' ');

  group('export', () {
    test('a text kept in English, a glossary term and the placeholders are explained', () {
      final de = reviewRows('de', ctx, pack: pack('de'));
      final title = row(de, 'app.title');
      expect(title.status, ReviewStatus.keepEnglish);
      expect(notes(title), contains('product name'));
      expect(title.cells.sublist(0, 5), ['keep-english', 'strings', 'app.title', 'OpenCADIrrigation', 'OpenCADIrrigation']);
      final emitters = row(de, 'props.emittersPerPlant');
      expect(emitters.english, I18n('en')('props.emittersPerPlant'));
      expect(emitters.current, pack('de')['strings']!['props.emittersPerPlant']);
      expect(notes(emitters), allOf(contains('“Auslass”'), contains('never “Emitter”')));
      expect(notes(row(de, 'msg.copied')), contains('Keep {n}'));
      final pt = reviewRows('pt', ctx);
      final mainline = row(pt, 'reports.mainline');
      expect(mainline.current, 'Linha principal / ponto de trabalho');
      expect(notes(mainline), contains('“ponto de trabalho”'));
      expect(row(pt, 'Start tutorial', 'tutorial').current, 'Iniciar tutorial');
      expect(row(pt, 'Start tutorial', 'tutorial').context, 'interactive tutorial');
      expect(row(reviewRows('es', ctx), 'Coupler', 'catalog').current, 'Manguito');
      expect(ctx.usedIn['menu.file'], contains('lib/app/widgets/menu_bar.dart'));
      expect(row(pt, 'menu.file').context, startsWith('shown in: '));
    });

    test('a provisional text says that its English changed', () {
      final glossary = Glossary(provisionalEnglish: {'menu.file': 'a test reason'});
      final r = row(reviewRows('hi', ctx.withGlossary(glossary), pack: pack('hi')), 'menu.file');
      expect(r.status, ReviewStatus.provisional);
      expect(notes(r), allOf(contains('Provisional'), contains('a test reason')));
      final hi = reviewRows('hi', ctx, pack: pack('hi'));
      for (final key in ctx.glossary.provisionalEnglish.keys) {
        expect(notes(row(hi, key)), contains('Provisional'), reason: key);
      }
    });

    test('a tutorial text whose English changed shows the previous translation', () {
      final ha = pack('ha');
      final old = ha['tutorial']!.remove('Start tutorial')!;
      ha['tutorial']!['Start the tutorial'] = old;
      final r = row(reviewRows('ha', ctx, pack: ha), 'Start tutorial', 'tutorial');
      expect(r.status, ReviewStatus.missing);
      expect(notes(r), contains('the previous translation was “$old”'));
    });

    test('the rows come most urgent first, and the order column puts them back in the order of the program', () {
      final ha = pack('ha');
      final rows = reviewRows('ha', ctx, pack: ha);
      final statuses = [for (final r in rows) r.status.index];
      expect(statuses, [...statuses]..sort());
      final byOrder = [...rows]..sort((a, b) => a.order - b.order);
      expect([for (final r in byOrder) r.order], [for (var i = 1; i <= rows.length; i++) i]);
      expect(
        [
          for (final r in byOrder)
            if (r.section == 'strings') r.key,
        ],
        I18n.keys.toList(),
      );
      for (final r in rows.where((r) => r.status == ReviewStatus.missing)) {
        expect(ha[r.section]![r.key]?.trim() ?? '', isEmpty, reason: r.key);
      }
    });

    test('every language but English exports, as CSV and as XLSX', () {
      final total = [for (final s in reviewSections) ctx.english[s]!.length].reduce((a, b) => a + b);
      expect(reviewLanguages, hasLength(19));
      expect(reviewLanguages, isNot(contains('en')));
      for (final lang in reviewLanguages) {
        final rows = reviewRows(lang, ctx, pack: baseLanguages.contains(lang) ? null : pack(lang));
        expect(rows, hasLength(total), reason: lang);
        final table = reviewTable(lang, rows);
        expect(parseCsv(decodeReviewText(utf8.encode(toCsv(table)))), table, reason: lang);
        expect(reviewEntries(table).lang, lang);
        if (baseLanguages.contains(lang)) expect(rows.where((r) => r.status == ReviewStatus.missing), isEmpty, reason: '$lang is compiled in');
      }
      for (final lang in ['ar', 'ja', 'pt']) {
        final rows = reviewRows(lang, ctx, pack: lang == 'pt' ? null : pack(lang));
        expect(readReviewTable(reviewXlsx(lang, rows)), reviewTable(lang, rows), reason: lang);
      }
      final dir = Directory.systemTemp.createTempSync('oci_i18n_export_');
      try {
        final out = StringBuffer();
        expect(runReviewCli(['export', 'all', '--out', dir.path], out: out, err: out), 0, reason: '$out');
        expect(dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet(), {for (final l in reviewLanguages) reviewFileName(l)});
        expect(runReviewCli(['export', 'te', '--format', 'xlsx', '--out', dir.path], out: out, err: out), 0, reason: '$out');
        expect(reviewEntries(readReviewTable(File('${dir.path}/${reviewFileName('te', format: 'xlsx')}').readAsBytesSync())).lang, 'te');
        expect(runReviewCli(['export', 'en', '--out', dir.path], out: out, err: out), 2);
      } finally {
        dir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout.factor(3));
  });

  test('CSV: RFC 4180 quoting, the byte order mark, other separators and encodings', () {
    final table = [
      ['section', 'key', 'review'],
      ['strings', 'a,b', 'say "hi"'],
      ['tutorial', 'two\nlines', ' padded '],
      ['catalog', 'crlf\r\ninside', 'ação 中文 العربية'],
      ['', '', ''],
    ];
    final csv = toCsv(table);
    expect(csv, startsWith('\uFEFFsection,key,review\r\n'));
    expect(csv, contains('strings,"a,b","say ""hi"""\r\n'));
    expect(csv, contains('tutorial,"two\nlines"," padded "\r\n'));
    expect(utf8.encode(csv).take(3), [0xEF, 0xBB, 0xBF]);
    expect(parseCsv(csv), table);
    // as spreadsheet programs save it back: semicolons, tabs, LF or CR line ends, UTF-16
    expect(parseCsv('section;key;review\n"strings";"a;b";x\n'), [
      ['section', 'key', 'review'],
      ['strings', 'a;b', 'x'],
    ]);
    expect(parseCsv('a\tb\rc\td'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
    final utf16 = [
      0xFF,
      0xFE,
      for (final u in 'a\tb\nç\t中'.codeUnits) ...[u & 0xFF, u >> 8],
    ];
    expect(parseCsv(decodeReviewText(utf16)), [
      ['a', 'b'],
      ['ç', '中'],
    ]);
    expect(() => decodeReviewText([0x61, 0xE7, 0x0A]), throwsFormatException, reason: 'Latin-1 is not guessed');
    expect(() => parseCsv('a,"open'), throwsFormatException);
  });

  test('an XLSX saved by a spreadsheet program: shared strings, numbers, phonetic readings', () {
    const shared =
        '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<si><t>section</t></si><si><t>key</t></si><si><t>review</t></si><si><t>order</t></si><si><t>strings</t></si><si><t>menu.file</t></si>'
        '<si><t>翻訳</t><rPh sb="0" eb="2"><t>ホンヤク</t></rPh><phoneticPr fontId="1"/></si></sst>';
    const sheet =
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c></row>'
        '<row r="2"><c r="A2" t="s"><v>4</v></c><c r="B2" t="s"><v>5</v></c><c r="C2" t="s"><v>6</v></c><c r="D2"><v>12</v></c></row>'
        '</sheetData></worksheet>';
    final archive = Archive()
      ..addFile(ArchiveFile.string('xl/sharedStrings.xml', shared))
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet));
    expect(readReviewTable(ZipEncoder().encodeBytes(archive)), [
      ['section', 'key', 'review', 'order'],
      ['strings', 'menu.file', '翻訳', '12'],
    ]);
  });

  test('the pack editor keeps the layout: values replaced in place, missing keys inserted in the order of the program', () {
    const text = '{\n "language": "xx",\n "strings": {\n  "b": "B",\n  "d": "D"\n },\n "tutorial": {},\n "catalog": {\n  "Pipe": "P\\u00edpe"\n }\n}';
    final order = {
      'strings': {'a': '', 'b': '', 'c': '', 'd': '', 'e': ''},
      'tutorial': {'Next': ''},
      'catalog': {'Pipe': ''},
    };
    final out = applyChangesToPack(text, const [
      ReviewChange('strings', 'e', null, 'E'),
      ReviewChange('strings', 'c', null, 'C "quoted"'),
      ReviewChange('strings', 'a', null, 'A'),
      ReviewChange('strings', 'd', 'D', 'D2'),
      ReviewChange('tutorial', 'Next', null, 'Próximo'),
    ], order);
    expect(
      out,
      '{\n "language": "xx",\n "strings": {\n  "a": "A",\n  "b": "B",\n  "c": "C \\"quoted\\"",\n  "d": "D2",\n  "e": "E"\n },\n'
      ' "tutorial": {\n  "Next": "Próximo"\n },\n "catalog": {\n  "Pipe": "P\\u00edpe"\n }\n}',
    );
  });

  group('import', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('oci_i18n_review_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    // a copy of the pack of [lang] in the temporary folder, and its text
    String copyPack(String lang) {
      final text = File('assets/i18n/$lang.json').readAsStringSync();
      File('${tmp.path}/$lang.json').writeAsStringSync(text);
      return text;
    }

    // a reviewed file with only the columns the import needs
    File reviewFile(String name, List<List<String>> rows) => File('${tmp.path}/$name')
      ..writeAsStringSync(
        toCsv([
          ['section', 'key', 'review', 'comment'],
          ...rows,
        ]),
      );

    (int, String) cli(List<String> args) {
      final out = StringBuffer();
      final code = runReviewCli(args, out: out, err: out);
      return (code, '$out');
    }

    String line(String key, String value) => '"$key": ${jsonEncode(value)},';

    test('a review rewrites only the reviewed texts, and puts a missing key back where the table has it', () {
      final original = copyPack('ha');
      final strings = packSections(original)['strings']!;
      // the copy loses a key, which the review gives back
      final lost = '\n  ${line('menu.edit', strings['menu.edit']!)}';
      expect(original, contains(lost));
      File('${tmp.path}/ha.json').writeAsStringSync(original.replaceFirst(lost, ''));
      final rows = reviewRows('ha', ctx, pack: pack('ha', tmp.path));
      expect(row(rows, 'menu.edit').status, ReviewStatus.missing);
      // the file as the export writes it, filled in by the reviewer
      final table = reviewTable('ha', rows);
      final review = reviewColumns.indexOf('review'), comment = reviewColumns.indexOf('comment');
      for (final r in table.skip(1)) {
        if (r[1] != 'strings') continue;
        switch (r[2]) {
          case 'menu.file':
            r[review] = 'Fayil (sabo)';
            r[comment] = 'a test comment';
          case 'menu.edit' || 'menu.view':
            r[review] = strings[r[2]]!;
        }
      }
      final file = File('${tmp.path}/${reviewFileName('ha')}')..writeAsStringSync(toCsv(table));
      final (code, out) = cli(['import', file.path, '--packs', tmp.path]);
      expect(code, 0, reason: out);
      expect(out, allOf(contains('2 to change, 1 unchanged, 0 refused'), contains('a test comment')));
      expect(File('${tmp.path}/ha.json').readAsStringSync(), original.replaceFirst(line('menu.file', strings['menu.file']!), line('menu.file', 'Fayil (sabo)')));
    });

    test('a dry run reports the changes and writes nothing', () {
      final original = copyPack('hi');
      final file = reviewFile('i18n-review-hi.csv', [
        ['strings', 'menu.file', 'फ़ाइलें', ''],
      ]);
      final (code, out) = cli(['import', file.path, '--packs', tmp.path, '--dry-run']);
      expect(code, 0, reason: out);
      expect(out, allOf(contains('1 to change'), contains('Dry run')));
      expect(File('${tmp.path}/hi.json').readAsStringSync(), original);
    });

    test('the checks refuse a review, and nothing is written without --force-partial', () {
      final original = copyPack('de');
      final strings = packSections(original)['strings']!;
      final file = reviewFile('review.csv', [
        ['strings', 'msg.copied', 'Elemente kopiert', ''],
        ['strings', 'props.emittersPerPlant', 'Emitter je Pflanze (0 = Projektstandard)', ''],
        ['strings', 'app.title', 'OpenCAD Bewässerung', ''],
        ['strings', 'no.such.key', 'Text', ''],
        ['menus', 'menu.file', 'Datei', ''],
        ['strings', 'menu.file', 'Datei (neu)', ''],
      ]);
      final refused = cli(['import', file.path, '--lang', 'de', '--packs', tmp.path]);
      expect(refused.$1, 1, reason: refused.$2);
      expect(
        refused.$2,
        allOf([
          contains('1 to change, 0 unchanged, 5 refused'),
          contains('Placeholders differ from English (missing {n})'),
          contains('“Emitter”'),
          contains('“Auslass”'),
          contains('Must read exactly as in English (product name)'),
          contains('Unknown key'),
          contains('Unknown section “menus”'),
          contains('Nothing written'),
        ]),
      );
      expect(File('${tmp.path}/de.json').readAsStringSync(), original);
      final partial = cli(['import', file.path, '--lang', 'de', '--packs', tmp.path, '--force-partial']);
      expect(partial.$1, 1, reason: 'the refused rows are still reported');
      expect(File('${tmp.path}/de.json').readAsStringSync(), original.replaceFirst(line('menu.file', strings['menu.file']!), line('menu.file', 'Datei (neu)')));
    });

    test('a text left in English, a row reviewed twice, a stale export and the limit of a Latin-script pack', () {
      final r = applyReview('hi', [
        const ReviewEntry(section: 'strings', key: 'menu.file', review: 'File'),
        const ReviewEntry(section: 'strings', key: 'menu.edit', review: 'संपादन १'),
        const ReviewEntry(section: 'strings', key: 'menu.edit', review: 'संपादन २'),
        const ReviewEntry(section: 'strings', key: 'menu.view', review: '  दृश्य बदलें \n', english: 'Old view'),
        const ReviewEntry(section: 'strings', key: 'ok', review: 'OK'),
        const ReviewEntry(section: 'tutorial', key: 'Start tutorial', review: '', comment: 'fine as it is'),
      ], ctx, pack: pack('hi'));
      expect([for (final x in r.rejected) x.entry.key], ['menu.file', 'menu.edit', 'menu.edit']);
      expect(r.rejected.first.reasons.join(), contains('Same as English'));
      expect(r.rejected[1].reasons.join(), contains('more than once'));
      expect({for (final c in r.changes) c.key: c.to}, {'menu.view': 'दृश्य बदलें', 'ok': 'OK'});
      expect(r.warnings.join(), contains('the English text changed since the export'));
      expect(r.withoutReview, 1);
      expect(r.comments.single.comment, 'fine as it is');
      // a Latin-script pack keeps texts in English up to its limit
      const english = [ReviewEntry(section: 'strings', key: 'menu.file', review: 'File')];
      final de = pack('de');
      expect(applyReview('de', english, ctx.withGlossary(Glossary(maxSameAsEnglish: {'de': 100000})), pack: de).changes, hasLength(1));
      final over = applyReview('de', english, ctx.withGlossary(Glossary(maxSameAsEnglish: {'de': 0})), pack: de);
      expect(over.changes, isEmpty);
      expect(over.rejected.single.reasons.join(), contains('maxSameAsEnglish (0)'));
    });

    test('a reviewed XLSX imports like a CSV', () {
      final original = copyPack('sw');
      final strings = packSections(original)['strings']!;
      final bytes = XlsxWriter.write([
        XlsxSheet(
          name: 'sw',
          headers: reviewHeader('sw'),
          rows: [
            ['translated', 'strings', 'menu.file', 'File', strings['menu.file'], 'Faili (jaribio)', '', '', '', 12],
          ],
        ),
      ]);
      final file = File('${tmp.path}/review.xlsx')..writeAsBytesSync(bytes);
      final (code, out) = cli(['import', file.path, '--packs', tmp.path]);
      expect(code, 0, reason: out);
      expect(File('${tmp.path}/sw.json').readAsStringSync(), original.replaceFirst(line('menu.file', strings['menu.file']!), line('menu.file', 'Faili (jaribio)')));
    });

    test('Portuguese and Spanish are listed to apply by hand', () {
      final file = reviewFile('i18n-review-pt.csv', [
        ['strings', 'menu.file', 'Ficheiro', ''],
        ['catalog', 'Coupler', 'União', ''],
      ]);
      final (code, out) = cli(['import', file.path, '--packs', tmp.path]);
      expect(code, 0, reason: out);
      expect(out, contains('by hand'));
      final list = File('${tmp.path}/i18n-review-pt.pt-changes.txt').readAsStringSync();
      expect(list, contains('lib/app/i18n.dart, key menu.file'));
      expect(list, contains("'menu.file': ('Ficheiro', 'File', 'Archivo'),"));
      expect(list, contains("n('União', 'Coupler', 'Manguito')"));
      expect(tmp.listSync().whereType<File>().where((f) => f.path.endsWith('.json')), isEmpty, reason: 'no pack is written');
    });
  });
}
