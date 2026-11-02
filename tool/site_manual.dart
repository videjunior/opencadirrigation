/// The user guide as pages of the site: the chapters of docs/manual (English, the canonical text) at `/manual/` and
/// `/manual/<chapter>/`, and their Portuguese translation (docs/manual/pt-BR) at `/pt/manual/` and
/// `/pt/manual/<chapter>/`, in the dark look of the other pages of the site, each with the list of chapters, a
/// table of contents of its sections, the previous and next chapter, the footer of the site and its consent notice.
///
/// The Markdown is converted here, for the subset the manual uses: CommonMark headings, paragraphs, emphasis, code,
/// links, images, lists, block quotes, rules and fenced code, plus the tables of GitHub; raw HTML is shown as text.
/// Headings get the anchors GitHub gives them, so that the links between chapters keep working on the site; a link
/// to a chapter goes to its page (in the same language, or in the other one), and a link to any other file of the
/// repository goes to that file on GitHub.
///
/// tool/site.dart imports this library: `dart run tool/gen_site.dart` writes the pages; `test/site_manual_test.dart`
/// checks the converter and every page.
library;

import 'dart:convert';
import 'dart:io';

import 'package:opencadirrigation/app/i18n.dart' show languageNames;
import 'package:opencadirrigation/app/version.dart' show appRepositoryUrl, appVersion;

import 'site.dart' show consentNotice, contentSecurityPolicy, hreflangsOf, landingLogo, landingLogoWidths, legalLinks, legalText, siteLang, siteLastMod, siteScriptTag, siteText, siteUrl;

/// Languages of the user guide: code → folder of its Markdown chapters.
const manualSources = {'en': 'docs/manual', 'pt': 'docs/manual/pt-BR'};

/// Address of the guide of [code] (its index, or [chapter] = file stem such as 'getting-started');
/// languages without a guide of their own get the English one.
String manualUrl(String code, [String chapter = '']) {
  final base = '${siteLang(manualSources.containsKey(code) ? code : 'en').url}manual/';
  return chapter.isEmpty || chapter == _index ? base : '$base$chapter/';
}

/// Every page of the guide: path inside web/ (e.g. 'manual/index.html', 'manual/calculation/index.html',
/// 'pt/manual/index.html') → HTML.
Map<String, String> renderManualPages() {
  final guides = _guides();
  return {
    for (final guide in guides.values)
      for (final chapter in guide.chapters) chapter.file: _page(chapter, guides),
  };
}

/// One sitemap entry per page: its address and the addresses of the same chapter in every guide language, the page
/// itself included, by hreflang tag (`en`, `pt-BR`, `pt` and `x-default`, the English page) → url.
List<(String url, Map<String, String> alternates)> manualSitemapEntries() {
  final guides = _guides();
  return [
    for (final guide in guides.values)
      for (final chapter in guide.chapters) (chapter.url, _alternates(chapter.stem, guides)),
  ];
}

/// Markdown → HTML for the subset the manual uses (public for the tests). [link] rewrites every link target.
String markdownToHtml(String markdown, {String Function(String href)? link}) => _Doc(link ?? _keep).blocks(_parseBlocks(_lines(markdown)));

// ---------------------------------------------------------------------------------------------------------------
// The guides: chapters in the order of their index, link targets, pages.

/// File stem of the index of a guide (its README.md): the page at `manual/`.
const _index = 'README';

class _Guide {
  _Guide(this.code, this.chapters);
  final String code;
  final List<_Chapter> chapters;

  bool has(String stem) => chapters.any((c) => c.stem == stem);
}

class _Chapter {
  _Chapter({required this.code, required this.stem, required this.title, required this.description, required this.blocks, required this.titleAt, required this.sections});
  final String code;
  final String stem;

  /// Text of the first `#` heading.
  final String title;
  final String description;

  /// The rendered blocks of the chapter, its `#` heading at [titleAt] (-1 when it has none).
  final List<String> blocks;
  final int titleAt;

  /// Anchor and text of each `##` heading.
  final List<(String, String)> sections;

  bool get isIndex => stem == _index;
  String get url => manualUrl(code, stem);

  /// Output file of the page inside `web/`.
  String get file => '${siteLang(code).path}manual/${isIndex ? '' : '$stem/'}index.html';
}

/// The words of a guide page that do not come from the Markdown.
class _GuideText {
  const _GuideText({required this.name, required this.title, required this.short, required this.chapters, required this.onThisPage, required this.previous, required this.next, required this.pager});

  /// The guide at the end of the title of a chapter page.
  final String name;

  /// Title of the index page.
  final String title;

  /// The guide in the breadcrumb and above the list of chapters.
  final String short;

  /// Label of the list of chapters.
  final String chapters;

  /// Heading of the table of contents of a chapter.
  final String onThisPage;
  final String previous;
  final String next;

  /// Label of the links to the previous and next chapter.
  final String pager;
}

const _texts = {
  'en': _GuideText(
    name: 'OpenCADIrrigation user guide',
    title: 'OpenCADIrrigation user guide',
    short: 'User guide',
    chapters: 'Chapters of the user guide',
    onThisPage: 'On this page',
    previous: 'Previous',
    next: 'Next',
    pager: 'Previous and next chapter',
  ),
  'pt': _GuideText(
    name: 'guia do usuário do OpenCADIrrigation',
    title: 'Guia do usuário do OpenCADIrrigation',
    short: 'Guia do usuário',
    chapters: 'Capítulos do guia do usuário',
    onThisPage: 'Nesta página',
    previous: 'Anterior',
    next: 'Próximo',
    pager: 'Capítulo anterior e próximo',
  ),
};

Map<String, _Guide> _guides() => {for (final e in manualSources.entries) e.key: _guide(e.key, e.value)};

final _chapterLink = RegExp(r'^([A-Za-z0-9_.\-]+)\.md$');

String _stemOf(File file) {
  final name = file.uri.pathSegments.last;
  return name.substring(0, name.length - 3);
}

/// The chapters of the guide in [folder]: the index first, then the chapters in the order of its list (each with the
/// line of the list that sums it up), then any chapter the list leaves out.
_Guide _guide(String code, String folder) {
  final stems = [
    for (final f in Directory(folder).listSync().whereType<File>())
      if (f.path.endsWith('.md')) _stemOf(f),
  ]..sort();
  final order = <String>[];
  final summaries = <String, String>{};
  if (stems.contains(_index)) {
    order.add(_index);
    for (final block in _parseBlocks(_lines(File('$folder/$_index.md').readAsStringSync()))) {
      if (block is! _ListBlock) continue;
      for (final item in block.items) {
        final first = item.isEmpty ? null : item.first;
        if (first is! _Para) continue;
        final nodes = _Inline(first.text, _keep).parse();
        final links = nodes.where((n) => n.kind == _Kind.link);
        final stem = links.isEmpty ? null : _chapterLink.firstMatch(links.first.href)?[1];
        if (stem != null && stems.contains(stem) && !order.contains(stem)) {
          order.add(stem);
          summaries[stem] = _flat(_plain(nodes));
        }
      }
    }
  }
  order.addAll([
    for (final stem in stems)
      if (!order.contains(stem)) stem,
  ]);
  return _Guide(code, [for (final stem in order) _chapter(code, folder, stem, summaries[stem])]);
}

/// A chapter: its blocks rendered with the links rewritten, its title, and as description the line of the index that
/// sums it up (several chapters open with a table or a list), else its first paragraph.
_Chapter _chapter(String code, String folder, String stem, String? summary) {
  final parsed = _parseBlocks(_lines(File('$folder/$stem.md').readAsStringSync()));
  final doc = _Doc((href) => _rewrite(href, folder));
  final blocks = [for (final b in parsed) doc.block(b)];
  final titleAt = parsed.indexWhere((b) => b is _Heading && b.level == 1);
  final heading = titleAt < 0 ? null : parsed[titleAt] as _Heading;
  final title = heading == null ? stem : _flat(_plain(_Inline(heading.text, _keep).parse()));
  final paragraph = _firstParagraph(parsed.sublist(titleAt + 1));
  final description = summary ?? (paragraph == null ? title : _flat(_plain(_Inline(paragraph.text, _keep).parse())));
  return _Chapter(
    code: code,
    stem: stem,
    title: title,
    description: _clip(description),
    blocks: blocks,
    titleAt: titleAt,
    sections: [
      for (final (level, id, text) in doc.headings)
        if (level == 2) (id, _flat(text)),
    ],
  );
}

_Para? _firstParagraph(List<_Block> blocks) {
  for (final b in blocks) {
    if (b is _Para) return b;
  }
  for (final b in blocks) {
    final inner = b is _Quote
        ? b.children
        : b is _ListBlock
        ? [for (final item in b.items) ...item]
        : const <_Block>[];
    final paragraph = _firstParagraph(inner);
    if (paragraph != null) return paragraph;
  }
  return null;
}

final _spaces = RegExp(r'\s+');
final _clipTail = RegExp(r'[ ,;:(—–-]+$');

String _flat(String text) => text.replaceAll(_spaces, ' ').trim();

/// [text] cut on a word to the 160 characters a search result shows.
String _clip(String text) {
  const limit = 160;
  if (text.length <= limit) return text;
  var cut = text.substring(0, limit - 1);
  final space = cut.lastIndexOf(' ');
  if (space > 0) cut = cut.substring(0, space);
  cut = cut.replaceFirst(_clipTail, '');
  return cut.endsWith('.') ? cut : '$cut…';
}

final _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*:');

/// Target of a link of a chapter in [folder]: a chapter of a guide → its page (with the anchor); any other file or
/// folder of the repository → it on GitHub; addresses with a scheme and anchors of the page itself stay.
String _rewrite(String href, String folder) {
  if (href.isEmpty || href.startsWith('#') || _scheme.hasMatch(href)) return href;
  final hash = href.indexOf('#');
  final path = hash < 0 ? href : href.substring(0, hash);
  final fragment = hash < 0 ? '' : href.substring(hash);
  final parts = [
    for (final part in folder.split('/'))
      if (part.isNotEmpty) part,
  ];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isEmpty) return href;
      parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  final resolved = parts.join('/');
  final isFolder = path.endsWith('/');
  if (!isFolder && resolved.endsWith('.md')) {
    for (final e in manualSources.entries) {
      final prefix = '${e.value}/';
      if (resolved.startsWith(prefix) && !resolved.substring(prefix.length).contains('/')) {
        return '${manualUrl(e.key, resolved.substring(prefix.length, resolved.length - 3))}$fragment';
      }
    }
  }
  return '$appRepositoryUrl/${isFolder ? 'tree' : 'blob'}/main/$resolved$fragment';
}

/// The address of the chapter [stem] in every guide language that has it, by hreflang tag, plus `x-default`: the
/// English page.
Map<String, String> _alternates(String stem, Map<String, _Guide> guides) {
  final out = <String, String>{
    for (final guide in guides.values)
      if (guide.has(stem))
        for (final tag in hreflangsOf(siteLang(guide.code))) tag: manualUrl(guide.code, stem),
  };
  out['x-default'] = (guides['en']?.has(stem) ?? false) ? manualUrl('en', stem) : out.values.first;
  return out;
}

String _page(_Chapter c, Map<String, _Guide> guides) {
  final guide = guides[c.code]!;
  final t = _texts[c.code] ?? _texts['en']!;
  final site = siteText(c.code);
  final legal = legalText(c.code);
  final lang = siteLang(c.code);
  final at = guide.chapters.indexOf(c);
  final previous = at > 0 ? guide.chapters[at - 1] : null;
  final next = at + 1 < guide.chapters.length ? guide.chapters[at + 1] : null;
  final article = [...c.blocks];
  if (c.titleAt < 0) article.insert(0, '<h1>${_esc(c.title)}</h1>');
  if (c.sections.length >= 3) {
    final toc = [
      '<nav class="toc" aria-labelledby="oci-toc">',
      '<p class="label" id="oci-toc">${_esc(t.onThisPage)}</p>',
      '<ol>',
      for (final (id, text) in c.sections) '<li><a href="#${_esc(id)}">${_esc(text)}</a></li>',
      '</ol>',
      '</nav>',
    ];
    article.insert(c.titleAt < 0 ? 1 : c.titleAt + 1, toc.join('\n'));
  }
  final versions = [
    for (final g in guides.values)
      if (g.has(c.stem))
        g.code == c.code
            ? '<strong lang="${siteLang(g.code).tag}">${languageNames[g.code] ?? g.code}</strong>'
            : '<a href="${manualUrl(g.code, c.stem)}" hreflang="${siteLang(g.code).tag}" lang="${siteLang(g.code).tag}" dir="${siteLang(g.code).dir}">${languageNames[g.code] ?? g.code}</a>',
  ];
  final source = '<a href="$appRepositoryUrl">${_esc(site.sourceCode)}</a>';
  final updated = '${_esc(legal.updated)} <time datetime="$siteLastMod">$siteLastMod</time>';
  final b = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="${lang.tag}"${lang.dirAttr}>')
    ..writeln('<head>')
    ..writeln('  <!-- Generated by tool/gen_site.dart from tool/site_manual.dart and docs/manual; do not edit by hand. -->')
    ..writeln('  <meta charset="UTF-8">')
    ..writeln('  <meta http-equiv="Content-Security-Policy" content="$contentSecurityPolicy">')
    ..writeln('  <meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('  <title>${_esc(c.isIndex ? t.title : '${c.title} — ${t.name}')}</title>')
    ..writeln('  <meta name="description" content="${_esc(c.description)}">')
    ..writeln('  <meta name="robots" content="index, follow">')
    ..writeln('  <link rel="canonical" href="${c.url}">');
  for (final e in _alternates(c.stem, guides).entries) {
    b.writeln('  <link rel="alternate" hreflang="${e.key}" href="${e.value}">');
  }
  b
    ..writeln('  <link rel="icon" href="/favicon.ico" sizes="any">')
    ..writeln('  <meta name="theme-color" content="#0D47A1">')
    ..writeln('  <meta name="color-scheme" content="dark">')
    ..writeln('  <script type="application/ld+json">')
    ..writeln(_jsonLd(c, t))
    ..writeln('  </script>')
    ..write('  <style>\n$_style$_consentStyle  </style>\n')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('  <header class="top">')
    ..writeln('    <a class="home" href="${lang.url}"><img src="/${landingLogo(landingLogoWidths.first)}" alt="OpenCADIrrigation" width="1040" height="349"></a>')
    ..writeln('    <a class="app" href="${lang.url}">${_esc(site.openApp)}</a>')
    ..writeln('  </header>')
    ..writeln('  <div class="layout">')
    ..writeln('    <main>')
    ..writeln('      <article>')
    ..writeln(article.join('\n'))
    ..writeln('      </article>');
  if (previous != null || next != null) {
    b.writeln('      <nav class="pager" aria-label="${_esc(t.pager)}">');
    if (previous != null) {
      b.writeln('        <a rel="prev" href="${previous.url}"><span>${_esc(t.previous)}</span>${_esc(previous.title)}</a>');
    }
    if (next != null) {
      b.writeln('        <a rel="next" href="${next.url}"><span>${_esc(t.next)}</span>${_esc(next.title)}</a>');
    }
    b.writeln('      </nav>');
  }
  b
    ..writeln('    </main>')
    ..writeln('    <nav class="chapters" aria-label="${_esc(t.chapters)}">')
    ..writeln('      <p class="label">${_esc(t.short)}</p>')
    ..writeln('      <ol>');
  for (final x in guide.chapters) {
    b.writeln('        <li><a href="${x.url}"${identical(x, c) ? ' aria-current="page"' : ''}>${_esc(x.title)}</a></li>');
  }
  b
    ..writeln('      </ol>')
    ..writeln('    </nav>')
    ..writeln('  </div>')
    ..writeln('  <footer class="foot">')
    ..writeln('    <p>${_esc(site.otherLanguages)}: ${versions.join(' · ')}</p>')
    ..writeln('    <p>OpenCADIrrigation $appVersion · $source · ${legalLinks(lang)} · $updated</p>')
    ..writeln('  </footer>')
    ..writeln(consentNotice(lang, legal))
    ..writeln('  ${siteScriptTag()}')
    ..writeln('</body>')
    ..write('</html>');
  return b.toString();
}

/// JSON-LD of a page: the chapter as a TechArticle of the guide, and its breadcrumb (site → guide → chapter).
String _jsonLd(_Chapter c, _GuideText t) {
  final home = siteLang(c.code);
  final guide = manualUrl(c.code);
  final graph = [
    {
      '@type': 'TechArticle',
      '@id': '${c.url}#article',
      'url': c.url,
      'headline': c.title,
      'description': c.description,
      'inLanguage': home.tag,
      'isPartOf': {'@type': 'CreativeWork', '@id': '$guide#guide', 'name': t.title, 'url': guide, 'inLanguage': home.tag},
      'dateModified': siteLastMod,
      'publisher': {'@id': '$siteUrl#org'},
    },
    {
      '@type': 'BreadcrumbList',
      '@id': '${c.url}#breadcrumb',
      'itemListElement': [
        {'@type': 'ListItem', 'position': 1, 'name': 'OpenCADIrrigation', 'item': home.url},
        {'@type': 'ListItem', 'position': 2, 'name': t.short, 'item': guide},
        if (!c.isIndex) {'@type': 'ListItem', 'position': 3, 'name': c.title, 'item': c.url},
      ],
    },
  ];
  // `<` escaped, so that no text of the guide can end the script element
  return const JsonEncoder.withIndent('  ').convert({'@context': 'https://schema.org', '@graph': graph}).replaceAll('<', '\\u003c');
}

const _style = '''
    html, body { margin: 0; min-height: 100%; background: #14171B; color: #CFD8DC; font: 16px/1.6 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    a { color: #64B5F6; }
    a:focus-visible { outline: 2px solid #90CAF9; outline-offset: 2px; }
    .top { max-width: 1180px; margin: 0 auto; padding: 18px 20px 4px; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px 20px; }
    .top .home img { display: block; width: min(260px, 62vw); height: auto; }
    .top .app { display: inline-block; padding: 12px 18px; border-radius: 8px; text-decoration: none; font-weight: 600; color: #fff; border: 1px solid #1976D2; }
    .top .app { background: linear-gradient(90deg, #0D47A1, #1976D2); }
    .layout { max-width: 1180px; margin: 0 auto; padding: 0 20px; display: grid; grid-template-columns: 240px minmax(0, 1fr); gap: 40px; align-items: start; }
    .layout > main { grid-column: 2; grid-row: 1; min-width: 0; }
    .chapters { grid-column: 1; grid-row: 1; position: sticky; top: 0; max-height: 100vh; box-sizing: border-box; overflow-y: auto; padding: 22px 0; font-size: .93rem; line-height: 1.4; }
    .chapters .label, .toc .label { margin: 0 0 8px; font-weight: 600; color: #ECEFF1; }
    .chapters ol, .toc ol { list-style: none; margin: 0; padding: 0; }
    .chapters a { display: block; padding: 6px 10px; border-radius: 6px; color: #B0BEC5; text-decoration: none; border-inline-start: 3px solid transparent; }
    .chapters a:hover { background: #1B1F24; color: #E3F2FD; }
    .chapters a[aria-current="page"] { background: #1E2A38; color: #E3F2FD; border-inline-start-color: #64B5F6; font-weight: 600; }
    article h1 { color: #ECEFF1; font-size: clamp(1.6rem, 3.4vw, 2.1rem); line-height: 1.25; margin: 22px 0 14px; }
    article h2 { color: #ECEFF1; font-size: 1.3rem; line-height: 1.3; margin: 40px 0 10px; padding-top: 14px; border-top: 1px solid #263238; }
    article h3 { color: #ECEFF1; font-size: 1.08rem; margin: 28px 0 8px; }
    article h4 { color: #ECEFF1; font-size: 1rem; margin: 22px 0 6px; }
    article h1, article h2, article h3, article h4 { scroll-margin-top: 16px; }
    article p, article li { overflow-wrap: break-word; }
    article ul, article ol { padding-inline-start: 1.5em; }
    article li { margin: 5px 0; }
    article code { font: .88em/1.4 ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
    article code { background: #1B1F24; border: 1px solid #263238; border-radius: 4px; padding: .05em .35em; }
    article pre { margin: 14px 0; padding: 12px 14px; overflow-x: auto; background: #1B1F24; border: 1px solid #263238; border-radius: 8px; }
    article pre code { display: block; padding: 0; border: 0; background: none; font-size: .84rem; line-height: 1.5; white-space: pre; }
    article .table { margin: 14px 0; overflow-x: auto; border: 1px solid #263238; border-radius: 8px; }
    article table { width: 100%; border-collapse: collapse; font-size: .93rem; }
    article th, article td { min-width: 7em; padding: 8px 12px; text-align: start; vertical-align: top; border-bottom: 1px solid #263238; }
    article th { color: #ECEFF1; background: #1B1F24; }
    article tbody tr:last-child td { border-bottom: 0; }
    article blockquote { margin: 14px 0; padding: 2px 16px; border-inline-start: 3px solid #2E4053; color: #B0BEC5; }
    article hr { border: 0; border-top: 1px solid #263238; margin: 32px 0; }
    article img { max-width: 100%; height: auto; }
    .toc { margin: 0 0 8px; padding: 12px 16px; background: #1B1F24; border: 1px solid #263238; border-radius: 10px; }
    .toc li { margin: 4px 0; }
    .pager { display: flex; flex-wrap: wrap; gap: 12px; margin: 44px 0 0; }
    .pager a { flex: 1 1 220px; padding: 10px 16px; border: 1px solid #2E4053; border-radius: 8px; background: #1E2A38; color: #E3F2FD; text-decoration: none; }
    .pager a[rel="next"] { text-align: end; }
    .pager span { display: block; font-size: .85rem; color: #90A4AE; }
    .foot { max-width: 1180px; margin: 48px auto 0; padding: 16px 20px 40px; border-top: 1px solid #263238; color: #90A4AE; font-size: .92rem; line-height: 1.9; }
    .foot p { margin: 4px 0; }
    .foot time { white-space: nowrap; }
    @media (max-width: 900px) {
      .layout { grid-template-columns: minmax(0, 1fr); gap: 0; }
      .layout > main, .chapters { grid-column: 1; grid-row: auto; }
      .chapters { position: static; max-height: none; overflow: visible; margin-top: 40px; padding: 20px 0 0; border-top: 1px solid #263238; }
      .chapters a { padding: 14px 12px; }
      .toc a { display: block; padding: 12px 0; }
    }
''';

/// The consent notice and the button that opens it again (the same style as on the other pages of the site).
const _consentStyle = '''
    .oci-consent { position: fixed; z-index: 2147483001; inset-inline: 16px; bottom: 16px; max-width: 560px; margin-inline: auto; font-size: .95rem; }
    .oci-consent { background: #1E2A38; color: #E3F2FD; border: 1px solid #2E4053; border-radius: 10px; padding: 14px 16px; box-shadow: 0 10px 30px rgba(0,0,0,.45); }
    .oci-consent[hidden] { display: none; }
    .oci-consent p { margin: 0 0 10px; }
    .oci-consent a { color: #90CAF9; }
    .oci-consent .actions { display: flex; flex-wrap: wrap; gap: 10px; justify-content: flex-end; }
    .oci-consent button { font: inherit; font-weight: 600; min-width: 110px; padding: 8px 16px; border-radius: 8px; cursor: pointer; border: 1px solid #64B5F6; background: #14171B; color: #E3F2FD; }
    .oci-consent button:focus-visible, .oci-linkish:focus-visible { outline: 2px solid #90CAF9; outline-offset: 2px; }
    .oci-linkish { font: inherit; color: #64B5F6; background: none; border: 0; padding: 0; cursor: pointer; text-decoration: underline; }
''';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _keep(String href) => href;

// ---------------------------------------------------------------------------------------------------------------
// Blocks: a line-by-line parser of the CommonMark blocks the manual uses, plus the tables of GitHub.

abstract class _Block {
  /// Whether a blank line separates the block from the one before it in its container (which makes a list loose).
  bool afterBlank = false;
}

class _Heading extends _Block {
  _Heading(this.level, this.text);
  final int level;
  final String text;
}

class _Para extends _Block {
  _Para(this.text);
  final String text;
}

class _Code extends _Block {
  _Code(this.lang, this.text);
  final String lang;
  final String text;
}

class _Table extends _Block {
  _Table(this.head, this.align, this.rows);
  final List<String> head;
  final List<String?> align;
  final List<List<String>> rows;
}

class _ListBlock extends _Block {
  _ListBlock(this.ordered, this.start, this.tight, this.items);
  final bool ordered;
  final int start;
  final bool tight;
  final List<List<_Block>> items;
}

class _Quote extends _Block {
  _Quote(this.children);
  final List<_Block> children;
}

class _Rule extends _Block {}

final _atx = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+|$)(.*)$');
final _atxClose = RegExp(r'(?:^|[ \t]+)#+$');
final _fence = RegExp(r'^( {0,3})(`{3,}|~{3,})(.*)$');
final _fenceClose = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
final _rule = RegExp(r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
final _quote = RegExp(r'^ {0,3}> ?(.*)$');
final _listItem = RegExp(r'^( {0,3})([-+*]|[0-9]{1,9}[.)])([ \t]+|$)');
final _setext = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');
final _delimiterCell = RegExp(r'^:?-+:?$');
final _blank = RegExp(r'^[ \t]*$');

/// The lines of [markdown], tabs of the indentation expanded to 4 columns.
List<String> _lines(String markdown) {
  final text = markdown.startsWith('\u{FEFF}') ? markdown.substring(1) : markdown;
  return [for (final line in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) _expandTabs(line)];
}

String _expandTabs(String line) {
  final out = StringBuffer();
  var column = 0;
  for (var k = 0; k < line.length; k++) {
    final c = line[k];
    if (c == ' ') {
      out.write(' ');
      column++;
    } else if (c == '\t') {
      final width = 4 - column % 4;
      out.write(' ' * width);
      column += width;
    } else {
      out.write(line.substring(k));
      return out.toString();
    }
  }
  return out.toString();
}

bool _isBlank(String line) => _blank.hasMatch(line);

int _indent(String line) {
  var n = 0;
  while (n < line.length && line[n] == ' ') {
    n++;
  }
  return n;
}

/// [s] without the spaces and tabs at its start (CommonMark whitespace, not Unicode's).
String _trimLeft(String s) {
  var a = 0;
  while (a < s.length && (s[a] == ' ' || s[a] == '\t')) {
    a++;
  }
  return s.substring(a);
}

String _trimRight(String s) {
  var b = s.length;
  while (b > 0 && (s[b - 1] == ' ' || s[b - 1] == '\t')) {
    b--;
  }
  return s.substring(0, b);
}

String _trim(String s) => _trimRight(_trimLeft(s));

_Heading? _headingOf(String line) {
  final m = _atx.firstMatch(line);
  if (m == null) return null;
  return _Heading(m[1]!.length, _trim(_trimRight(m[2]!).replaceFirst(_atxClose, '')));
}

RegExpMatch? _fenceOf(String line) {
  final m = _fence.firstMatch(line);
  if (m == null || (m[2]!.startsWith('`') && m[3]!.contains('`'))) return null;
  return m;
}

/// The cells of a table row: split on the pipes that are not escaped, `\|` read as a pipe (in code too, as on GitHub).
List<String> _cells(String line) {
  var s = _trim(line);
  if (s.startsWith('|')) s = s.substring(1);
  final cells = <String>[];
  final cell = StringBuffer();
  var trailing = false;
  var k = 0;
  while (k < s.length) {
    final c = s[k];
    trailing = false;
    if (c == '\\' && k + 1 < s.length) {
      cell.write(s[k + 1] == '|' ? '|' : s.substring(k, k + 2));
      k += 2;
      continue;
    }
    if (c == '|') {
      cells.add(_trim(cell.toString()));
      cell.clear();
      trailing = true;
      k++;
      continue;
    }
    cell.write(c);
    k++;
  }
  if (!trailing) cells.add(_trim(cell.toString()));
  return cells;
}

/// Whether [line] and [next] are the header and the delimiter row of a table.
bool _tableStart(String line, String? next) {
  if (next == null || !line.contains('|') || !next.contains('|') || _indent(line) >= 4 || _indent(next) >= 4) return false;
  final delimiters = _cells(next);
  if (delimiters.isEmpty || !delimiters.every(_delimiterCell.hasMatch)) return false;
  return _cells(line).length == delimiters.length;
}

/// Whether [line] ends the paragraph above it ([next] is the line after it).
bool _interrupts(String line, String? next) {
  if (_headingOf(line) != null || _fenceOf(line) != null || _quote.hasMatch(line) || _rule.hasMatch(line)) return true;
  final m = _listItem.firstMatch(line);
  if (m != null && !_isBlank(line.substring(m[1]!.length + m[2]!.length))) {
    final marker = m[2]!;
    final ordered = marker.endsWith('.') || marker.endsWith(')');
    // an ordered list interrupts a paragraph only when it starts at 1
    return !ordered || int.parse(marker.substring(0, marker.length - 1)) == 1;
  }
  return _tableStart(line, next);
}

/// Whether [line], indented less than the content of a list item, starts a block instead of continuing its paragraph.
bool _breaksLazy(String line) => _headingOf(line) != null || _fenceOf(line) != null || _quote.hasMatch(line) || _rule.hasMatch(line) || _listItem.hasMatch(line);

/// Whether the last, innermost block of [blocks] is a paragraph (which a lazy line continues).
bool _endsInParagraph(List<_Block> blocks) {
  if (blocks.isEmpty) return false;
  final last = blocks.last;
  if (last is _Para) return true;
  if (last is _ListBlock) return _endsInParagraph(last.items.last);
  if (last is _Quote) return _endsInParagraph(last.children);
  return false;
}

List<_Block> _parseBlocks(List<String> lines) {
  final blocks = <_Block>[];
  var blank = false;
  void add(_Block block) {
    block.afterBlank = blank;
    blank = false;
    blocks.add(block);
  }

  final n = lines.length;
  var i = 0;
  while (i < n) {
    final line = lines[i];
    if (_isBlank(line)) {
      blank = true;
      i++;
      continue;
    }
    final next = i + 1 < n ? lines[i + 1] : null;
    // indented code
    if (_indent(line) >= 4) {
      final code = <String>[];
      while (i < n && (_isBlank(lines[i]) || _indent(lines[i]) >= 4)) {
        code.add(lines[i].length > 4 ? lines[i].substring(4) : '');
        i++;
      }
      while (_isBlank(code.last)) {
        code.removeLast();
        i--;
      }
      add(_Code('', code.join('\n')));
      continue;
    }
    final fence = _fenceOf(line);
    if (fence != null) {
      final indent = fence[1]!.length;
      final marks = fence[2]!;
      final info = _trim(fence[3]!);
      final body = <String>[];
      i++;
      while (i < n) {
        final close = _fenceClose.firstMatch(lines[i]);
        if (close != null && close[1]![0] == marks[0] && close[1]!.length >= marks.length) {
          i++;
          break;
        }
        final strip = _indent(lines[i]);
        body.add(lines[i].substring(strip < indent ? strip : indent));
        i++;
      }
      add(_Code(info.isEmpty ? '' : info.split(_spaces).first, body.join('\n')));
      continue;
    }
    final heading = _headingOf(line);
    if (heading != null) {
      add(heading);
      i++;
      continue;
    }
    if (_rule.hasMatch(line)) {
      add(_Rule());
      i++;
      continue;
    }
    if (_quote.hasMatch(line)) {
      final inner = <String>[];
      while (i < n) {
        final q = _quote.firstMatch(lines[i]);
        if (q != null) {
          inner.add(q[1]!);
        } else if (!_isBlank(lines[i]) && inner.isNotEmpty && !_isBlank(inner.last) && _endsInParagraph(_parseBlocks(inner)) && !_breaksLazy(lines[i])) {
          inner.add(lines[i]);
        } else {
          break;
        }
        i++;
      }
      add(_Quote(_parseBlocks(inner)));
      continue;
    }
    if (_listItem.hasMatch(line)) {
      final (list, end) = _parseList(lines, i);
      add(list);
      i = end;
      continue;
    }
    if (_tableStart(line, next)) {
      final head = _cells(line);
      final align = [
        for (final c in _cells(next!))
          c.startsWith(':') && c.endsWith(':')
              ? 'center'
              : c.endsWith(':')
              ? 'right'
              : c.startsWith(':')
              ? 'left'
              : null,
      ];
      final rows = <List<String>>[];
      i += 2;
      while (i < n && !_isBlank(lines[i]) && !_breaksLazy(lines[i])) {
        final cells = _cells(lines[i]);
        rows.add([for (var k = 0; k < head.length; k++) k < cells.length ? cells[k] : '']);
        i++;
      }
      add(_Table(head, align, rows));
      continue;
    }
    // a paragraph, or a setext heading when underlined
    final paragraph = [line];
    var level = 0;
    i++;
    while (i < n && !_isBlank(lines[i])) {
      final setext = _setext.firstMatch(lines[i]);
      if (setext != null) {
        level = setext[1]!.startsWith('=') ? 1 : 2;
        i++;
        break;
      }
      if (_interrupts(lines[i], i + 1 < n ? lines[i + 1] : null)) break;
      paragraph.add(lines[i]);
      i++;
    }
    final text = _trimRight(paragraph.map(_trimLeft).join('\n'));
    add(level > 0 ? _Heading(level, text) : _Para(text));
  }
  return blocks;
}

/// The list that starts at line [start]: its items, each parsed as blocks, and the line after it.
(_ListBlock, int) _parseList(List<String> lines, int start) {
  final n = lines.length;
  var i = start;
  final first = _listItem.firstMatch(lines[i])![2]!;
  // the bullet character, or the delimiter of an ordered list: a different one starts a new list
  final kind = first.substring(first.length - 1);
  final ordered = kind == '.' || kind == ')';
  final number = ordered ? int.parse(first.substring(0, first.length - 1)) : 1;
  final items = <List<_Block>>[];
  var loose = false;
  while (true) {
    final m = _listItem.firstMatch(lines[i])!;
    final after = m[1]!.length + m[2]!.length;
    final empty = _isBlank(lines[i].substring(after));
    // the column of the content: after the marker and its spaces (one, when the item starts empty or with code)
    final offset = empty || m[3]!.length >= 5 ? after + 1 : after + m[3]!.length;
    final item = [empty ? '' : lines[i].substring(offset)];
    i++;
    while (i < n) {
      final line = lines[i];
      if (_isBlank(line)) {
        if (empty && item.length == 1) break;
        item.add('');
        i++;
        continue;
      }
      if (_indent(line) >= offset) {
        item.add(line.substring(offset));
        i++;
        continue;
      }
      // a lazy continuation line of the paragraph the item ends with
      if (_isBlank(item.last) || _breaksLazy(line) || !_endsInParagraph(_parseBlocks(item))) break;
      item.add(_trimLeft(line));
      i++;
    }
    // trailing blank lines belong to what follows the item
    while (item.length > 1 && _isBlank(item.last)) {
      item.removeLast();
      i--;
    }
    final children = _parseBlocks(item);
    items.add(children);
    if (children.skip(1).any((b) => b.afterBlank)) loose = true;
    var j = i;
    while (j < n && _isBlank(lines[j])) {
      j++;
    }
    if (j < n && !_rule.hasMatch(lines[j])) {
      final sibling = _listItem.firstMatch(lines[j]);
      if (sibling != null && sibling[2]!.endsWith(kind)) {
        if (j > i) loose = true;
        i = j;
        continue;
      }
    }
    break;
  }
  return (_ListBlock(ordered, number, !loose, items), i);
}

// ---------------------------------------------------------------------------------------------------------------
// Inlines: code spans, escapes, autolinks, links and images, emphasis by the delimiter algorithm of CommonMark.

enum _Kind { text, code, br, em, strong, link, image }

class _Node {
  _Node(this.kind, {this.text = '', List<_Node>? children, this.href = '', this.title}) : children = children ?? [];
  final _Kind kind;
  String text;
  final List<_Node> children;
  final String href;
  final String? title;
}

/// A run of `*` or `_` that may open or close emphasis.
class _Delim {
  _Delim(this.node, this.char, this.count, this.canOpen, this.canClose) : orig = count;
  final _Node node;
  final String char;
  int count;
  final int orig;
  final bool canOpen;
  final bool canClose;
}

/// A `[` or `![` that may open a link or an image.
class _Bracket {
  _Bracket(this.node, {required this.image, required this.bottom});
  final _Node node;
  final bool image;

  /// The delimiters below this index were there before the bracket.
  final int bottom;
  bool active = true;
}

const _asciiPunct = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

/// The characters at which plain text stops.
const _specialChars = '`\\<*_[]!\n';

final _unicodeSpace = RegExp(r'^\p{Zs}$', unicode: true);
final _unicodePunct = RegExp(r'^\p{P}$', unicode: true);
final _autolinkUri = RegExp(r'<([A-Za-z][A-Za-z0-9+.\-]{1,31}:[^\s<>]*)>');
final _autolinkEmail = RegExp(r"<([A-Za-z0-9.!#$%&'*+/=?^_`{|}~\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)*)>");
final _finalSpaces = RegExp(r' +$');

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || _unicodeSpace.hasMatch(c);

/// ASCII punctuation and the punctuation of Unicode (as GitHub tells it, without the symbols).
bool _isPunct(String c) => _asciiPunct.contains(c) || _unicodePunct.hasMatch(c);

class _Inline {
  _Inline(this.s, this.link);
  final String s;
  final String Function(String href) link;
  final nodes = <_Node>[];
  final delims = <_Delim>[];
  final brackets = <_Bracket>[];

  List<_Node> parse() {
    var p = 0;
    while (p < s.length) {
      final c = s[p];
      if (c == '`') {
        p = _code(p);
      } else if (c == '\\') {
        if (p + 1 < s.length && s[p + 1] == '\n') {
          nodes.add(_Node(_Kind.br));
          p = _skipSpaces(p + 2);
        } else if (p + 1 < s.length && _asciiPunct.contains(s[p + 1])) {
          nodes.add(_Node(_Kind.text, text: s[p + 1]));
          p += 2;
        } else {
          nodes.add(_Node(_Kind.text, text: '\\'));
          p++;
        }
      } else if (c == '<') {
        p = _autolink(p);
      } else if (c == '*' || c == '_') {
        p = _delim(p);
      } else if (c == '[') {
        final node = _Node(_Kind.text, text: '[');
        nodes.add(node);
        brackets.add(_Bracket(node, image: false, bottom: delims.length));
        p++;
      } else if (c == '!' && p + 1 < s.length && s[p + 1] == '[') {
        final node = _Node(_Kind.text, text: '![');
        nodes.add(node);
        brackets.add(_Bracket(node, image: true, bottom: delims.length));
        p += 2;
      } else if (c == ']') {
        p = _closeBracket(p);
      } else if (c == '\n') {
        // two spaces or more before the line break make it a hard one
        var hard = false;
        if (nodes.isNotEmpty && nodes.last.kind == _Kind.text) {
          final text = nodes.last.text;
          final stripped = text.replaceFirst(_finalSpaces, '');
          hard = text.length - stripped.length >= 2;
          nodes.last.text = stripped;
        }
        nodes.add(hard ? _Node(_Kind.br) : _Node(_Kind.text, text: '\n'));
        p = _skipSpaces(p + 1);
      } else {
        var end = p + 1;
        while (end < s.length && !_specialChars.contains(s[end])) {
          end++;
        }
        nodes.add(_Node(_Kind.text, text: s.substring(p, end)));
        p = end;
      }
    }
    _emphasis(0);
    return nodes;
  }

  int _skipSpaces(int start) {
    var p = start;
    while (p < s.length && s[p] == ' ') {
      p++;
    }
    return p;
  }

  /// A code span from the backticks at [start] to the next run of as many, else the backticks as text.
  int _code(int start) {
    var q = start;
    while (q < s.length && s[q] == '`') {
      q++;
    }
    final n = q - start;
    var k = q;
    while (true) {
      k = s.indexOf('`', k);
      if (k < 0) {
        nodes.add(_Node(_Kind.text, text: s.substring(start, q)));
        return q;
      }
      var e = k;
      while (e < s.length && s[e] == '`') {
        e++;
      }
      if (e - k == n) {
        var body = s.substring(q, k).replaceAll('\n', ' ');
        if (body.length >= 2 && body.startsWith(' ') && body.endsWith(' ') && body.replaceAll(' ', '').isNotEmpty) {
          body = body.substring(1, body.length - 1);
        }
        nodes.add(_Node(_Kind.code, text: body));
        return e;
      }
      k = e;
    }
  }

  int _autolink(int start) {
    final uri = _autolinkUri.matchAsPrefix(s, start);
    if (uri != null) {
      nodes.add(_Node(_Kind.link, children: [_Node(_Kind.text, text: uri[1]!)], href: link(uri[1]!)));
      return uri.end;
    }
    final email = _autolinkEmail.matchAsPrefix(s, start);
    if (email != null) {
      nodes.add(_Node(_Kind.link, children: [_Node(_Kind.text, text: email[1]!)], href: link('mailto:${email[1]}')));
      return email.end;
    }
    nodes.add(_Node(_Kind.text, text: '<'));
    return start + 1;
  }

  /// A run of `*` or `_`, with whether it may open and close emphasis (the flanking rules of CommonMark).
  int _delim(int start) {
    final c = s[start];
    var q = start;
    while (q < s.length && s[q] == c) {
      q++;
    }
    final before = start > 0 ? s[start - 1] : '\n';
    final after = q < s.length ? s[q] : '\n';
    final left = !_isSpace(after) && (!_isPunct(after) || _isSpace(before) || _isPunct(before));
    final right = !_isSpace(before) && (!_isPunct(before) || _isSpace(after) || _isPunct(after));
    // an underscore inside a word (SPOT_HEIGHTS, snake_case) neither opens nor closes
    final canOpen = c == '*' ? left : left && (!right || _isPunct(before));
    final canClose = c == '*' ? right : right && (!left || _isPunct(after));
    final node = _Node(_Kind.text, text: s.substring(start, q));
    nodes.add(node);
    delims.add(_Delim(node, c, q - start, canOpen, canClose));
    return q;
  }

  int _closeBracket(int start) {
    if (brackets.isEmpty) {
      nodes.add(_Node(_Kind.text, text: ']'));
      return start + 1;
    }
    final opener = brackets.last;
    final tail = opener.active ? _linkTail(start + 1) : null;
    if (tail == null) {
      brackets.removeLast();
      nodes.add(_Node(_Kind.text, text: ']'));
      return start + 1;
    }
    final (href, title, end) = tail;
    _emphasis(opener.bottom);
    final k = nodes.indexOf(opener.node);
    final node = _Node(opener.image ? _Kind.image : _Kind.link, children: nodes.sublist(k + 1), href: link(href), title: title);
    nodes.removeRange(k, nodes.length);
    nodes.add(node);
    brackets.removeLast();
    // no link inside a link
    if (!opener.image) {
      for (final b in brackets) {
        if (!b.image) b.active = false;
      }
    }
    return end;
  }

  /// `(destination "optional title")` right after a closing bracket: the destination, the title and the end, or null.
  (String, String?, int)? _linkTail(int start) {
    if (start >= s.length || s[start] != '(') return null;
    var p = _skipWhitespace(start + 1);
    final destination = StringBuffer();
    if (p < s.length && s[p] == '<') {
      p++;
      while (p < s.length && s[p] != '>') {
        if (s[p] == '\n' || s[p] == '<') return null;
        if (s[p] == '\\' && p + 1 < s.length && _asciiPunct.contains(s[p + 1])) p++;
        destination.write(s[p]);
        p++;
      }
      if (p >= s.length) return null;
      p++;
    } else {
      final from = p;
      var depth = 0;
      while (p < s.length) {
        final c = s[p];
        if (c == '\\' && p + 1 < s.length && _asciiPunct.contains(s[p + 1])) {
          destination.write(s[p + 1]);
          p += 2;
          continue;
        }
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          if (depth == 0) break;
          depth--;
        } else if (_isSpace(c) || c.codeUnitAt(0) < 32 || c.codeUnitAt(0) == 127) {
          break;
        }
        destination.write(c);
        p++;
      }
      if (depth != 0 || (p == from && (p >= s.length || s[p] != ')'))) return null;
    }
    var q = _skipWhitespace(p);
    String? title;
    if (q > p && q < s.length && (s[q] == '"' || s[q] == "'" || s[q] == '(')) {
      final close = s[q] == '(' ? ')' : s[q];
      final text = StringBuffer();
      var r = q + 1;
      while (r < s.length && s[r] != close) {
        if (s[r] == '\\' && r + 1 < s.length && _asciiPunct.contains(s[r + 1])) {
          r++;
        } else if (close == ')' && s[r] == '(') {
          return null;
        }
        text.write(s[r]);
        r++;
      }
      if (r >= s.length) return null;
      title = text.toString();
      q = _skipWhitespace(r + 1);
    }
    if (q >= s.length || s[q] != ')') return null;
    return (destination.toString(), title, q + 1);
  }

  /// Past spaces and tabs and at most one line break.
  int _skipWhitespace(int start) {
    var p = start;
    var newline = false;
    while (p < s.length && (s[p] == ' ' || s[p] == '\t' || s[p] == '\n')) {
      if (s[p] == '\n') {
        if (newline) break;
        newline = true;
      }
      p++;
    }
    return p;
  }

  /// The emphasis of the delimiters above [bottom] ("process emphasis" of the CommonMark specification).
  void _emphasis(int bottom) {
    // per kind of closer, the delimiter below which no opener is looked for again (null: [bottom])
    final floors = <String, _Delim?>{};
    var current = bottom;
    while (current < delims.length) {
      final closer = delims[current];
      if (!closer.canClose) {
        current++;
        continue;
      }
      final key = '${closer.char}${closer.canOpen}${closer.orig % 3}';
      final floor = floors[key];
      var found = -1;
      for (var k = current - 1; k >= bottom && !identical(delims[k], floor); k--) {
        final candidate = delims[k];
        if (candidate.char != closer.char || !candidate.canOpen) continue;
        // the rule of 3: a run that can both open and close does not match one whose length makes a multiple of 3
        final odd = (candidate.canClose || closer.canOpen) && closer.orig % 3 != 0 && (candidate.orig + closer.orig) % 3 == 0;
        if (!odd) {
          found = k;
          break;
        }
      }
      if (found < 0) {
        floors[key] = current - 1 >= bottom ? delims[current - 1] : null;
        if (closer.canOpen) {
          current++;
        } else {
          delims.removeAt(current);
        }
        continue;
      }
      final opener = delims[found];
      final use = opener.count >= 2 && closer.count >= 2 ? 2 : 1;
      opener.count -= use;
      closer.count -= use;
      opener.node.text = opener.char * opener.count;
      closer.node.text = closer.char * closer.count;
      final a = nodes.indexOf(opener.node);
      final b = nodes.indexOf(closer.node);
      nodes.replaceRange(a + 1, b, [_Node(use == 2 ? _Kind.strong : _Kind.em, children: nodes.sublist(a + 1, b))]);
      delims.removeRange(found + 1, current);
      current = found + 1;
      if (opener.count == 0) {
        nodes.remove(opener.node);
        delims.removeAt(found);
        current--;
      }
      if (closer.count == 0) {
        nodes.remove(closer.node);
        delims.removeAt(current);
      }
    }
    delims.removeRange(bottom, delims.length);
  }
}

String _inlineHtml(List<_Node> nodes) {
  final out = StringBuffer();
  for (final n in nodes) {
    switch (n.kind) {
      case _Kind.text:
        out.write(_esc(n.text));
      case _Kind.code:
        out.write('<code>${_esc(n.text)}</code>');
      case _Kind.br:
        out.write('<br>\n');
      case _Kind.em:
        out.write('<em>${_inlineHtml(n.children)}</em>');
      case _Kind.strong:
        out.write('<strong>${_inlineHtml(n.children)}</strong>');
      case _Kind.link:
        out.write('<a href="${_esc(n.href)}"${_titleOf(n)}>${_inlineHtml(n.children)}</a>');
      case _Kind.image:
        out.write('<img src="${_esc(n.href)}" alt="${_esc(_plain(n.children))}"${_titleOf(n)}>');
    }
  }
  return out.toString();
}

String _titleOf(_Node n) {
  final title = n.title;
  return title == null ? '' : ' title="${_esc(title)}"';
}

/// The text of [nodes] without markup.
String _plain(List<_Node> nodes) => nodes
    .map(
      (n) => switch (n.kind) {
        _Kind.text || _Kind.code => n.text,
        _Kind.br => '\n',
        _ => _plain(n.children),
      },
    )
    .join();

// ---------------------------------------------------------------------------------------------------------------
// Rendering, with the anchors GitHub gives the headings.

final _slugDrop = RegExp(r'[^\p{L}\p{N}_\- ]', unicode: true);

/// GitHub's anchor of a heading (as test/web_docs_test.dart computes it).
String _slug(String heading) => heading.trim().toLowerCase().replaceAll(_slugDrop, '').replaceAll(' ', '-');

class _Doc {
  _Doc(this.link);
  final String Function(String href) link;
  final _used = <String, int>{};

  /// Level, anchor and text of every heading rendered so far.
  final headings = <(int, String, String)>[];

  /// [slug] made unique in the page as GitHub does: the second `foo` is `foo-1`, the third `foo-2`.
  String unique(String slug) {
    var result = slug;
    while (_used.containsKey(result)) {
      _used[slug] = _used[slug]! + 1;
      result = '$slug-${_used[slug]}';
    }
    _used[result] = 0;
    return result;
  }

  String blocks(List<_Block> list, {bool tight = false}) => [for (final b in list) block(b, tight: tight)].join('\n');

  /// One block; in a tight list its paragraphs go without `<p>`.
  String block(_Block b, {bool tight = false}) {
    if (b is _Heading) {
      final nodes = _Inline(b.text, link).parse();
      final id = unique(_slug(b.text));
      headings.add((b.level, id, _plain(nodes)));
      return '<h${b.level} id="${_esc(id)}">${_inlineHtml(nodes)}</h${b.level}>';
    }
    if (b is _Para) {
      final html = _inlineHtml(_Inline(b.text, link).parse());
      return tight ? html : '<p>$html</p>';
    }
    if (b is _Code) {
      final language = b.lang.isEmpty ? '' : ' class="language-${_esc(b.lang)}"';
      return '<pre><code$language>${b.text.isEmpty ? '' : '${_esc(b.text)}\n'}</code></pre>';
    }
    if (b is _Table) {
      final out = ['<div class="table"><table>', '<thead>', '<tr>'];
      for (var k = 0; k < b.head.length; k++) {
        out.add('<th${_alignOf(b.align[k])}>${_inlineHtml(_Inline(b.head[k], link).parse())}</th>');
      }
      out.addAll(['</tr>', '</thead>']);
      if (b.rows.isNotEmpty) {
        out.add('<tbody>');
        for (final row in b.rows) {
          out.add('<tr>');
          for (var k = 0; k < row.length; k++) {
            out.add('<td${_alignOf(b.align[k])}>${_inlineHtml(_Inline(row[k], link).parse())}</td>');
          }
          out.add('</tr>');
        }
        out.add('</tbody>');
      }
      out.add('</table></div>');
      return out.join('\n');
    }
    if (b is _ListBlock) {
      final tag = b.ordered ? 'ol' : 'ul';
      final out = ['<$tag${b.ordered && b.start != 1 ? ' start="${b.start}"' : ''}>'];
      for (final item in b.items) {
        var body = blocks(item, tight: b.tight);
        if (item.isNotEmpty && (!b.tight || item.first is! _Para)) body = '\n$body';
        if (item.isNotEmpty && (!b.tight || item.last is! _Para)) body = '$body\n';
        out.add('<li>$body</li>');
      }
      out.add('</$tag>');
      return out.join('\n');
    }
    if (b is _Quote) return '<blockquote>\n${blocks(b.children)}\n</blockquote>';
    return '<hr>';
  }
}

String _alignOf(String? align) => align == null ? '' : ' style="text-align: $align"';
