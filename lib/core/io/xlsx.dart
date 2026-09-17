/// Minimal XLSX (Office Open XML SpreadsheetML) writer: one worksheet per
/// table, bold header row, numeric cells kept as numbers, inline strings.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxSheet {
  XlsxSheet({required this.name, required this.headers, required this.rows});
  final String name;
  final List<String> headers;

  /// Cells: `num` values become numeric cells, anything else a string.
  final List<List<Object?>> rows;
}

class XlsxWriter {
  static Uint8List write(List<XlsxSheet> sheets, {String creator = 'OpenCADIrrigation'}) {
    final archive = Archive();
    void add(String path, String content) => archive.addFile(ArchiveFile.string(path, content));
    final names = <String>[];
    for (var i = 0; i < sheets.length; i++) {
      names.add(_uniqueSheetName(sheets[i].name, names, i));
    }
    add('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
${[for (var i = 1; i <= sheets.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
</Types>''');
    add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''');
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    add('docProps/core.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:creator>${_esc(creator)}</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created>
</cp:coreProperties>''');
    add('docProps/app.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>${_esc(creator)}</Application></Properties>''');
    add('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join('\n')}
</sheets>
</workbook>''');
    add('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${[for (var i = 1; i <= sheets.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join('\n')}
<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');
    add('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="10"/><name val="Calibri"/></font><font><b/><sz val="10"/><name val="Calibri"/></font></fonts>
<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE3E8EE"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''');
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String _sheetXml(XlsxSheet s) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    // column widths from content
    final widths = List<double>.filled(s.headers.length, 8);
    for (var c = 0; c < s.headers.length; c++) {
      widths[c] = (s.headers[c].length + 2).clamp(8, 60).toDouble();
    }
    for (final r in s.rows) {
      for (var c = 0; c < r.length && c < widths.length; c++) {
        final len = '${r[c] ?? ''}'.length + 2;
        if (len > widths[c]) widths[c] = len.clamp(8, 60).toDouble();
      }
    }
    if (widths.isNotEmpty) {
      b.write('<cols>');
      for (var c = 0; c < widths.length; c++) {
        b.write('<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>');
      }
      b.writeln('</cols>');
    }
    b.writeln('<sheetData>');
    b.write('<row r="1">');
    for (var c = 0; c < s.headers.length; c++) {
      b.write('<c r="${_col(c)}1" t="inlineStr" s="1"><is><t>${_esc(s.headers[c])}</t></is></c>');
    }
    b.writeln('</row>');
    for (var r = 0; r < s.rows.length; r++) {
      final rowNum = r + 2;
      b.write('<row r="$rowNum">');
      final row = s.rows[r];
      for (var c = 0; c < row.length; c++) {
        final v = row[c];
        final ref = '${_col(c)}$rowNum';
        if (v == null || (v is String && v.isEmpty)) continue;
        if (v is num && v.isFinite) {
          b.write('<c r="$ref"><v>$v</v></c>');
        } else {
          b.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
        }
      }
      b.writeln('</row>');
    }
    b.writeln('</sheetData>');
    b.writeln('</worksheet>');
    return b.toString();
  }

  static String _col(int index) {
    var i = index;
    var s = '';
    do {
      s = String.fromCharCode(65 + i % 26) + s;
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return s;
  }

  static String _uniqueSheetName(String raw, List<String> used, int index) {
    var n = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (n.isEmpty) n = 'Sheet${index + 1}';
    if (n.length > 31) n = n.substring(0, 31);
    var candidate = n;
    var k = 2;
    while (used.contains(candidate)) {
      final suffix = ' ($k)';
      candidate = n.length + suffix.length > 31 ? n.substring(0, 31 - suffix.length) + suffix : n + suffix;
      k++;
    }
    return candidate;
  }

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

/// Minimal XLSX reader: worksheets with shared, inline or numeric cells
/// (what spreadsheet programs write for a price list). Formulas keep their
/// cached value.
class XlsxReader {
  /// Every worksheet, first row as headers and the rest as rows.
  static List<XlsxSheet> read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String? textOf(String name) {
      for (final f in archive.files) {
        if (f.name == name || f.name == '/$name') return utf8.decode(f.content as List<int>, allowMalformed: true);
      }
      return null;
    }

    // shared strings
    final shared = <String>[];
    final ss = textOf('xl/sharedStrings.xml');
    if (ss != null) {
      final doc = XmlDocument.parse(ss);
      for (final si in doc.findAllElements('si')) {
        shared.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }
    // sheet names → part names
    final names = <String, String>{}; // rId → name
    final wb = textOf('xl/workbook.xml');
    if (wb != null) {
      for (final s in XmlDocument.parse(wb).findAllElements('sheet')) {
        final rid = s.attributes.where((a) => a.name.local == 'id').map((a) => a.value).firstOrNull ?? '';
        names[rid] = s.getAttribute('name') ?? 'Sheet';
      }
    }
    final targets = <String, String>{}; // rId → path
    final rels = textOf('xl/_rels/workbook.xml.rels');
    if (rels != null) {
      for (final r in XmlDocument.parse(rels).findAllElements('Relationship')) {
        var target = r.getAttribute('Target') ?? '';
        if (target.startsWith('/')) target = target.substring(1);
        if (!target.startsWith('xl/')) target = 'xl/$target';
        targets[r.getAttribute('Id') ?? ''] = target;
      }
    }
    final out = <XlsxSheet>[];
    final ordered = names.keys.toList();
    if (ordered.isEmpty) {
      // no workbook part: take every worksheet file
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          ordered.add(f.name);
          targets[f.name] = f.name;
          names[f.name] = f.name.split('/').last.replaceAll('.xml', '');
        }
      }
    }
    for (final rid in ordered) {
      final path = targets[rid];
      if (path == null) continue;
      final xml = textOf(path);
      if (xml == null) continue;
      final rows = <List<Object?>>[];
      for (final row in XmlDocument.parse(xml).findAllElements('row')) {
        final cells = <Object?>[];
        for (final c in row.findElements('c')) {
          final ref = c.getAttribute('r') ?? '';
          final col = _columnIndex(ref);
          while (cells.length < col) {
            cells.add(null);
          }
          final type = c.getAttribute('t') ?? 'n';
          Object? value;
          if (type == 's') {
            final i = int.tryParse(c.findElements('v').firstOrNull?.innerText ?? '');
            value = i != null && i < shared.length ? shared[i] : '';
          } else if (type == 'inlineStr') {
            value = c.findAllElements('t').map((t) => t.innerText).join();
          } else if (type == 'str' || type == 'b') {
            value = c.findElements('v').firstOrNull?.innerText ?? '';
          } else {
            final v = c.findElements('v').firstOrNull?.innerText;
            value = v == null ? null : (double.tryParse(v) ?? v);
          }
          if (col == cells.length) {
            cells.add(value);
          } else {
            cells[col] = value;
          }
        }
        rows.add(cells);
      }
      if (rows.isEmpty) continue;
      final headers = rows.first.map((v) => v == null ? '' : (v is double && v == v.roundToDouble() ? '${v.round()}' : '$v')).toList();
      out.add(XlsxSheet(name: names[rid] ?? 'Sheet', headers: headers, rows: rows.skip(1).toList()));
    }
    return out;
  }

  /// 0-based column of a cell reference such as `C12` (or the position when empty).
  static int _columnIndex(String ref) {
    var col = 0;
    var any = false;
    for (final ch in ref.codeUnits) {
      if (ch >= 65 && ch <= 90) {
        col = col * 26 + (ch - 64);
        any = true;
      } else if (ch >= 97 && ch <= 122) {
        col = col * 26 + (ch - 96);
        any = true;
      } else {
        break;
      }
    }
    return any ? col - 1 : 0;
  }
}
