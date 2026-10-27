/// Markdown as the AI models write it in the chat: headings, paragraphs,
/// bullet and numbered lists (nested by indentation), block quotes, fenced
/// code, tables, rules, and inline **bold**, *italic*, `code`, [links](url)
/// and bare web addresses. The answer selects as one text; wide tables and
/// code scroll sideways inside the narrow panel. Syntax that is not closed
/// yet (an answer still streaming in) shows as typed until it closes.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../io/links.dart';
import '../../theme.dart';

/// A block of the answer.
sealed class MdBlock {
  const MdBlock();
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

/// A list item: [depth] 0 for the outer list; [marker] "•", "–" or the
/// number the model wrote ("3.").
class MdListItem extends MdBlock {
  const MdListItem(this.depth, this.marker, this.text);
  final int depth;
  final String marker;
  final String text;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdCode extends MdBlock {
  const MdCode(this.code);
  final String code;
}

class MdTable extends MdBlock {
  const MdTable(this.header, this.align, this.rows);
  final List<String> header;
  final List<TextAlign> align;
  final List<List<String>> rows;
}

class MdRule extends MdBlock {
  const MdRule();
}

final _fence = RegExp(r'^\s*(```|~~~)');
final _heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
final _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
final _bullet = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final _number = RegExp(r'^(\s*)(\d{1,3}[.)])\s+(.*)$');
final _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
final _tableSep = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$');
final _continuation = RegExp(r'^\s+\S');

List<String> _cells(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|') && !s.endsWith(r'\|')) s = s.substring(0, s.length - 1);
  return [for (final c in s.split(RegExp(r'(?<!\\)\|'))) c.trim().replaceAll(r'\|', '|')];
}

/// The blocks of [text].
List<MdBlock> parseAiMarkdown(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final out = <MdBlock>[];
  final para = <String>[];
  // indents of the open list levels (a deeper indent opens a level)
  final indents = <int>[];
  void flush() {
    if (para.isEmpty) return;
    out.add(MdParagraph(para.join('\n')));
    para.clear();
  }

  void block(MdBlock b) {
    flush();
    indents.clear();
    out.add(b);
  }

  var i = 0;
  while (i < lines.length) {
    final l = lines[i];
    final fence = _fence.firstMatch(l);
    if (fence != null) {
      final mark = fence.group(1)!;
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith(mark)) {
        code.add(lines[i]);
        i++;
      }
      i++;
      block(MdCode(code.join('\n')));
      continue;
    }
    if (l.contains('|') && i + 1 < lines.length && lines[i + 1].contains('-') && _tableSep.hasMatch(lines[i + 1])) {
      final header = _cells(l);
      final align = [
        for (final c in _cells(lines[i + 1]))
          c.startsWith(':') && c.endsWith(':')
              ? TextAlign.center
              : c.endsWith(':')
              ? TextAlign.end
              : TextAlign.start,
      ];
      final rows = <List<String>>[];
      i += 2;
      while (i < lines.length && lines[i].contains('|') && lines[i].trim().isNotEmpty) {
        rows.add(_cells(lines[i]));
        i++;
      }
      block(MdTable(header, align, rows));
      continue;
    }
    if (l.trim().isEmpty) {
      flush();
      i++;
      continue;
    }
    final h = _heading.firstMatch(l);
    if (h != null) {
      block(MdHeading(h.group(1)!.length, h.group(2)!));
      i++;
      continue;
    }
    if (_rule.hasMatch(l)) {
      block(const MdRule());
      i++;
      continue;
    }
    final q = _quote.firstMatch(l);
    if (q != null) {
      final quoted = [q.group(1)!];
      i++;
      while (i < lines.length) {
        final m = _quote.firstMatch(lines[i]);
        if (m == null) break;
        quoted.add(m.group(1)!);
        i++;
      }
      block(MdQuote(quoted.join('\n')));
      continue;
    }
    final b = _bullet.firstMatch(l);
    final n = b == null ? _number.firstMatch(l) : null;
    if (b != null || n != null) {
      flush();
      final indent = (b ?? n)!.group(1)!.replaceAll('\t', '    ').length;
      while (indents.isNotEmpty && indent < indents.last) {
        indents.removeLast();
      }
      if (indents.isEmpty || indent > indents.last) indents.add(indent);
      final depth = indents.length - 1;
      out.add(MdListItem(depth, b != null ? (depth == 0 ? '•' : '–') : n!.group(2)!, b != null ? b.group(2)! : n!.group(3)!));
      i++;
      continue;
    }
    // an indented line right under a list item continues it
    if (para.isEmpty && out.isNotEmpty && out.last is MdListItem && _continuation.hasMatch(l)) {
      final last = out.removeLast() as MdListItem;
      out.add(MdListItem(last.depth, last.marker, '${last.text}\n${l.trim()}'));
      i++;
      continue;
    }
    if (para.isEmpty) indents.clear();
    para.add(l.trimRight());
    i++;
  }
  flush();
  return out;
}

final _inlineRe = RegExp(
  r'`([^`]+)`'
  r'|\*\*\*(.+?)\*\*\*'
  r'|\*\*(.+?)\*\*'
  r'|__(.+?)__'
  r'|(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])'
  r'|(?<![\w_])_(?![\s_])(.+?)(?<![\s_])_(?![\w_])'
  r'|\[([^\]\n]+)\]\((https?://[^\s)]+)\)'
  r'''|(https?://[^\s<>()\[\]]*[^\s<>()\[\].,;:!?"'])''',
);

/// Direction of a paragraph from its first strong letter (an answer in
/// English under an Arabic interface reads left to right, and the reverse);
/// null when it has none, to follow the interface.
TextDirection? aiTextDirection(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) return TextDirection.rtl;
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F) || (r >= 0x370 && r <= 0x58F) || (r >= 0x900 && r <= 0x1FFF) || (r >= 0x3040 && r <= 0x9FFF) || (r >= 0xAC00 && r <= 0xD7AF)) {
      return TextDirection.ltr;
    }
  }
  return null;
}

/// The answer as plain text, for a text item in the drawing: no Markdown
/// marks, list markers kept, tables as tab-separated lines.
String aiPlainText(String md) {
  String inline(String s) {
    // twice: emphasis may hold code or a link
    for (var i = 0; i < 2; i++) {
      s = s.replaceAllMapped(_inlineRe, (m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? m.group(5) ?? m.group(6) ?? m.group(7) ?? m.group(9) ?? '');
    }
    return s;
  }

  return [
    for (final b in parseAiMarkdown(md))
      switch (b) {
        MdParagraph(:final text) || MdHeading(:final text) || MdQuote(:final text) => inline(text),
        MdListItem(:final depth, :final marker, :final text) => '${'  ' * depth}$marker ${inline(text)}',
        MdCode(:final code) => code,
        MdTable(:final header, :final rows) => [for (final r in [header, ...rows]) r.map(inline).join('\t')].join('\n'),
        MdRule() => '',
      },
  ].join('\n');
}

/// Sideways scrolling with a visible bar (a mouse cannot drag text sideways:
/// it selects).
class _SideScroll extends StatefulWidget {
  const _SideScroll({required this.child});
  final Widget child;

  @override
  State<_SideScroll> createState() => _SideScrollState();
}

class _SideScrollState extends State<_SideScroll> {
  final ctrl = ScrollController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: ctrl,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: ctrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: widget.child,
    ),
  );
}

/// The answer of the assistant, rendered.
class AiMarkdown extends StatefulWidget {
  const AiMarkdown(this.text, {super.key, this.size = 12.5});
  final String text;
  final double size;

  @override
  State<AiMarkdown> createState() => _AiMarkdownState();
}

class _AiMarkdownState extends State<AiMarkdown> {
  final List<TapGestureRecognizer> _taps = [];

  void _clearTaps() {
    for (final r in _taps) {
      r.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _clearTaps();
    super.dispose();
  }

  List<InlineSpan> _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start), style: style));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: style.copyWith(fontFamily: 'monospace', color: Cad.codeText)));
      } else if (m.group(2) != null) {
        spans.addAll(_inline(m.group(2)!, style.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)));
      } else if ((m.group(3) ?? m.group(4)) != null) {
        spans.addAll(_inline((m.group(3) ?? m.group(4))!, style.copyWith(fontWeight: FontWeight.bold)));
      } else if ((m.group(5) ?? m.group(6)) != null) {
        spans.addAll(_inline((m.group(5) ?? m.group(6))!, style.copyWith(fontStyle: FontStyle.italic)));
      } else {
        final label = m.group(7) ?? m.group(9)!;
        final url = m.group(8) ?? m.group(9)!;
        final tap = TapGestureRecognizer()..onTap = () => openExternalLink(url);
        _taps.add(tap);
        spans.add(TextSpan(text: label, style: style.copyWith(color: Cad.accentText, decoration: TextDecoration.underline), recognizer: tap, mouseCursor: SystemMouseCursors.click));
      }
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i), style: style));
    return spans;
  }

  Widget _text(String s, TextStyle style, {TextAlign align = TextAlign.start}) => Text.rich(TextSpan(children: _inline(s, style)), style: style, textAlign: align, textDirection: aiTextDirection(s));

  Widget _table(MdTable t, TextStyle base) {
    var n = t.header.length;
    for (final r in t.rows) {
      if (r.length > n) n = r.length;
    }
    TextAlign align(int i) => i < t.align.length ? t.align[i] : TextAlign.start;
    Widget cell(List<String> row, int i, TextStyle style) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: _text(i < row.length ? row[i] : '', style, align: align(i)),
    );
    final head = base.copyWith(fontWeight: FontWeight.bold);
    return _SideScroll(
      child: Table(
        // as wide as the text, wrapping only very long cells
        defaultColumnWidth: const MinColumnWidth(IntrinsicColumnWidth(), FixedColumnWidth(240)),
        border: TableBorder.all(color: Cad.divider, width: 0.6),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(decoration: BoxDecoration(color: Cad.cardHigh), children: [for (var i = 0; i < n; i++) cell(t.header, i, head)]),
          for (final r in t.rows) TableRow(children: [for (var i = 0; i < n; i++) cell(r, i, base)]),
        ],
      ),
    );
  }

  Widget _block(MdBlock b, TextStyle base) => switch (b) {
    MdParagraph(:final text) => _text(text, base),
    MdHeading(:final level, :final text) => _text(text, base.copyWith(fontWeight: FontWeight.bold, fontSize: base.fontSize! + (level <= 1 ? 3 : (level == 2 ? 2 : 1)))),
    MdListItem(:final depth, :final marker, :final text) => Padding(
      padding: EdgeInsetsDirectional.only(start: 14.0 * depth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: marker.length > 2 ? 26 : 18, child: Text(marker, style: base)),
          Expanded(child: _text(text, base)),
        ],
      ),
    ),
    MdQuote(:final text) => Container(
      padding: const EdgeInsetsDirectional.only(start: 8),
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: Cad.divider, width: 3)),
      ),
      child: _text(text, base.copyWith(color: Cad.fg70)),
    ),
    MdCode(:final code) => Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Cad.cardHigh, borderRadius: BorderRadius.circular(4)),
      // code reads left to right in every interface language
      child: _SideScroll(
        child: Text(code, textDirection: TextDirection.ltr, style: base.copyWith(fontFamily: 'monospace', fontSize: base.fontSize! - 1, color: Cad.codeText)),
      ),
    ),
    MdTable() => _table(b, base),
    MdRule() => Divider(height: 10, color: Cad.divider),
  };

  @override
  Widget build(BuildContext context) {
    _clearTaps();
    final base = TextStyle(fontSize: widget.size, height: 1.35);
    final blocks = parseAiMarkdown(widget.text);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, b) in blocks.indexed)
            Padding(
              // list items stay together; other blocks get a paragraph gap
              padding: EdgeInsets.only(top: i == 0 ? 0 : (b is MdListItem && blocks[i - 1] is MdListItem ? 2 : 6)),
              child: _block(b, base),
            ),
        ],
      ),
    );
  }
}
