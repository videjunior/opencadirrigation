/// The text of the files the user attaches to the AI assistant's
/// conversation, whole or in parts: the text read from a PDF on this device
/// (page by page) and the lines of a text file — for the message itself,
/// and for read_attachment, which reads a long file a part at a time.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../core/io/pdf_reader.dart';

/// The text of a PDF, page by page from page [first] (0-based), its runs
/// ordered top to bottom and left to right, one line per baseline (cells
/// joined by tabs); at most [maxPages] pages and [maxChars] characters.
/// Null when nothing readable.
String? pdfToText(Uint8List bytes, {int first = 0, int maxPages = 40, int maxChars = 80000}) {
  try {
    final r = PdfReader.open(bytes);
    final out = StringBuffer();
    for (var i = first < 0 ? 0 : first; i < r.pageCount && i < first + maxPages && out.length < maxChars; i++) {
      final runs = [
        for (final t in r.readPage(i, vectors: false, images: false).texts)
          if (!t.hidden && t.text.trim().isNotEmpty) t,
      ]..sort((a, b) => a.origin.y != b.origin.y ? b.origin.y.compareTo(a.origin.y) : a.origin.x.compareTo(b.origin.x));
      if (runs.isEmpty) continue;
      out.writeln('--- page ${i + 1}');
      final line = <PdfTextItem>[];
      void flush() {
        line.sort((a, b) => a.origin.x.compareTo(b.origin.x));
        out.writeln(line.map((t) => t.text.trim()).join('\t'));
        line.clear();
      }

      for (final t in runs) {
        if (line.isNotEmpty && (line.first.origin.y - t.origin.y).abs() > 0.5 * (line.first.height > 0 ? line.first.height : 1)) flush();
        line.add(t);
      }
      if (line.isNotEmpty) flush();
    }
    final s = out.toString().trim();
    if (s.isEmpty) return null;
    return s.length <= maxChars ? s : '${s.substring(0, maxChars)}\n… (cut at $maxChars characters)';
  } catch (_) {
    return null;
  }
}

/// Pages of the PDF [bytes] (0 when it cannot be read).
int pdfPageCount(Uint8List bytes) {
  try {
    return PdfReader.open(bytes).pageCount;
  } catch (_) {
    return 0;
  }
}

/// Most lines, pages and characters one read_attachment call returns.
const attachmentMaxLines = 600, attachmentMaxPages = 20, attachmentMaxChars = 40000;

/// Part of an attached file for read_attachment: lines [from]…[to] of a text
/// file, or pages [from]…[to] of a PDF as text (1-based, both included),
/// within [attachmentMaxLines] lines or [attachmentMaxPages] pages and
/// [attachmentMaxChars] characters; with where it ends and what is left.
String attachmentPart(String name, Uint8List bytes, int from, int to) {
  final pdf = name.toLowerCase().endsWith('.pdf') || (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46);
  if (pdf) {
    final pages = pdfPageCount(bytes);
    if (pages == 0) return 'The PDF "$name" cannot be read on this device (a scan, or encrypted): ask the user for the figures you need.';
    final a = from.clamp(1, pages), b = to.clamp(a, a + attachmentMaxPages - 1).clamp(a, pages);
    final text = pdfToText(bytes, first: a - 1, maxPages: b - a + 1, maxChars: attachmentMaxChars);
    final more = b < pages ? ' Next: from ${b + 1} (of $pages pages).' : ' That is the last page.';
    return 'Pages $a–$b of $pages of "$name" (text read on this device; tables lose their layout).$more\n${text ?? '(no text on these pages: scanned pages, or pictures only)'}';
  }
  final lines = const LineSplitter().convert(utf8.decode(bytes, allowMalformed: true));
  if (lines.isEmpty) return '"$name" is empty.';
  final a = from.clamp(1, lines.length);
  var b = to.clamp(a, a + attachmentMaxLines - 1).clamp(a, lines.length);
  final out = StringBuffer();
  for (var k = a; k <= b; k++) {
    final l = lines[k - 1];
    if (out.length + l.length > attachmentMaxChars && k > a) {
      b = k - 1;
      break;
    }
    out.writeln(l);
  }
  final more = b < lines.length ? ' Next: from ${b + 1} (of ${lines.length} lines).' : ' That is the last line.';
  return 'Lines $a–$b of ${lines.length} of "$name".$more\n$out';
}

/// Most pages, lines and characters summarize_attachment hands the reading
/// model at once: well under the price step of the cheapest models
/// (100 000 input tokens), at about four characters a token.
const subagentMaxPages = 200, subagentMaxLines = 20000, subagentMaxChars = 320000;

/// A larger part of an attached file than [attachmentPart] gives, for the
/// model that reads it for the main one (summarize_attachment): pages
/// [from]…[to] of a PDF as text, or lines [from]…[to] of a text file, within
/// [subagentMaxPages] pages or [subagentMaxLines] lines and [maxChars]
/// characters. Returns the text, the range read ("pages 1–80 of 120") and
/// where the next part starts (null at the end); a null text when nothing
/// can be read.
({String? text, String range, int? next}) attachmentRange(String name, Uint8List bytes, {int from = 1, int? to, int maxChars = subagentMaxChars}) {
  final pdf = name.toLowerCase().endsWith('.pdf') || (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46);
  if (pdf) {
    final pages = pdfPageCount(bytes);
    if (pages == 0) return (text: null, range: 'no page readable', next: null);
    final a = from.clamp(1, pages);
    final b = (to ?? pages).clamp(a, a + subagentMaxPages - 1).clamp(a, pages);
    final text = pdfToText(bytes, first: a - 1, maxPages: b - a + 1, maxChars: maxChars);
    return (text: text, range: 'pages $a–$b of $pages', next: b < pages ? b + 1 : null);
  }
  final lines = const LineSplitter().convert(utf8.decode(bytes, allowMalformed: true));
  if (lines.isEmpty) return (text: null, range: 'empty', next: null);
  final a = from.clamp(1, lines.length);
  var b = (to ?? lines.length).clamp(a, a + subagentMaxLines - 1).clamp(a, lines.length);
  final out = StringBuffer();
  for (var k = a; k <= b; k++) {
    final l = lines[k - 1];
    if (out.length + l.length > maxChars && k > a) {
      b = k - 1;
      break;
    }
    out.writeln(l);
  }
  return (text: out.toString(), range: 'lines $a–$b of ${lines.length}', next: b < lines.length ? b + 1 : null);
}
