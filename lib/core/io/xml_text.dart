/// Text written into XML (KML, GPX, LandXML, SVG, the parts of XLSX).
library;

/// [s] for XML 1.0 content and attribute values: `&`, `<`, `>` and `"`
/// escaped, and the characters XML does not allow dropped (control
/// characters other than tab, line feed and carriage return, surrogates
/// without their pair, U+FFFE and U+FFFF). One such character, pasted with
/// a name or read from another file, would make viewers and spreadsheet
/// programs refuse the whole file.
String xmlText(String s) {
  final b = StringBuffer();
  final n = s.length;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      // a high surrogate is kept with its low one, else dropped
      if (i + 1 < n) {
        final d = s.codeUnitAt(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) {
          b
            ..writeCharCode(c)
            ..writeCharCode(d);
          i++;
        }
      }
      continue;
    }
    if (c >= 0xDC00 && c <= 0xDFFF) continue;
    if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) continue;
    if (c == 0xFFFE || c == 0xFFFF) continue;
    switch (c) {
      case 0x26:
        b.write('&amp;');
      case 0x3C:
        b.write('&lt;');
      case 0x3E:
        b.write('&gt;');
      case 0x22:
        b.write('&quot;');
      default:
        b.writeCharCode(c);
    }
  }
  return b.toString();
}
