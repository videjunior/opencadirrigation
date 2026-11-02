import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart' show appRepositoryUrl, appVersion;

import '../tool/site.dart' show contentSecurityPolicy, privacyUrl, siteLang, siteLastMod, siteUrl, termsUrl;
import '../tool/site_manual.dart';

/// The user guide as pages of the site (tool/site_manual.dart): the Markdown converter construct by construct, then
/// every chapter of docs/manual and of its Portuguese translation as a page: anchors, links, text, metadata, sitemap.
void main() {
  /// GitHub's anchor of a heading, as test/web_docs_test.dart computes it.
  String slug(String heading) => heading.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}_\- ]', unicode: true), '').replaceAll(' ', '-');

  String mark(String href) => 'L:$href';

  String unescape(String html) => html.replaceAll('&quot;', '"').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');

  void same(String markdown, String html, {String Function(String href)? link}) => expect(markdownToHtml(markdown, link: link), html, reason: markdown);

  group('markdownToHtml', () {
    test('headings carry the anchor GitHub gives them, repeated ones numbered as on GitHub', () {
      same(
        '# Title\n\n## Prices and currency\n\n## Prices and currency\n\n### Prices and currency',
        '<h1 id="title">Title</h1>\n<h2 id="prices-and-currency">Prices and currency</h2>\n<h2 id="prices-and-currency-1">Prices and currency</h2>\n'
            '<h3 id="prices-and-currency-2">Prices and currency</h3>',
      );
      same('## Revisão das traduções (por falantes) → nativos', '<h2 id="revisão-das-traduções-por-falantes--nativos">Revisão das traduções (por falantes) → nativos</h2>');
      same('#### Project (`.oci.json`) ##', '<h4 id="project-ocijson">Project (<code>.oci.json</code>)</h4>');
      same('#hashtag\n\nSetext\n======', '<p>#hashtag</p>\n<h1 id="setext">Setext</h1>');
    });

    test('paragraphs: emphasis, underscores inside words, code without formatting, everything else escaped', () {
      same(
        'Some **bold**, *em* and _em_; SPOT_HEIGHTS, snake_case_name and 2 * 3 * 4 stay as they are.',
        '<p>Some <strong>bold</strong>, <em>em</em> and <em>em</em>; SPOT_HEIGHTS, snake_case_name and 2 * 3 * 4 stay as they are.</p>',
      );
      same(
        'Code `a **b** <c> & d` and `` `x` `` stays code; 5 < 6 & "q"; \\*not em\\*.',
        '<p>Code <code>a **b** &lt;c&gt; &amp; d</code> and <code>`x`</code> stays code; 5 &lt; 6 &amp; &quot;q&quot;; *not em*.</p>',
      );
      same(
        '*Keep\nconversations in this browser* is on; ***both*** and **a *b* c**',
        '<p><em>Keep\nconversations in this browser</em> is on; <em><strong>both</strong></em> and <strong>a <em>b</em> c</strong></p>',
      );
      same('<script>alert(1)</script> and <b>x</b>', '<p>&lt;script&gt;alert(1)&lt;/script&gt; and &lt;b&gt;x&lt;/b&gt;</p>');
      same('line one  \nline two\\\nline three', '<p>line one<br>\nline two<br>\nline three</p>');
    });

    test('links, autolinks and images, the text over two lines, every target through the rewriting', () {
      same(
        '[A](a.md#x), [section\n12](b.md), [**AI** notes](c.md), <https://example.com/?a=1&b=2>, ![logo](l.png "Logo") and [plain](https://e.org).',
        '<p><a href="L:a.md#x">A</a>, <a href="L:b.md">section\n12</a>, <a href="L:c.md"><strong>AI</strong> notes</a>, '
            '<a href="L:https://example.com/?a=1&amp;b=2">https://example.com/?a=1&amp;b=2</a>, <img src="L:l.png" alt="logo" title="Logo"> and '
            '<a href="L:https://e.org">plain</a>.</p>',
        link: mark,
      );
      same('[no link] here, [x] (y) and [[a](b)](c)', '<p>[no link] here, [x] (y) and [<a href="b">a</a>](c)</p>');
    });

    test('lists: ordered and bullet, nested by indentation, lazy continuation lines, tight and loose', () {
      same(
        '1. **Graph**: one\n   two\n2. **Zones**:\n   - first;\n   - **LP**: a\n     b\nlazy\n3. end',
        '<ol>\n<li><strong>Graph</strong>: one\ntwo</li>\n<li><strong>Zones</strong>:\n<ul>\n<li>first;</li>\n<li><strong>LP</strong>: a\nb\nlazy</li>\n</ul>\n</li>\n'
            '<li>end</li>\n</ol>',
      );
      same('- a\n\n- b', '<ul>\n<li>\n<p>a</p>\n</li>\n<li>\n<p>b</p>\n</li>\n</ul>');
      same('3. three\n4. four', '<ol start="3">\n<li>three</li>\n<li>four</li>\n</ol>');
      same('text\n- item\n\ntext\n2. not a list', '<p>text</p>\n<ul>\n<li>item</li>\n</ul>\n<p>text\n2. not a list</p>');
      same('- a\n+ b', '<ul>\n<li>a</li>\n</ul>\n<ul>\n<li>b</li>\n</ul>');
    });

    test('tables: alignment, escaped pipes (in code too), short and long rows, rows until a blank line', () {
      same(
        '| Key | Value | N |\n|:---|:---:|---:|\n| `a\\|b` | x \\| y | **1** |\n| short |\n| 1 | 2 | 3 | 4 |',
        '<div class="table"><table>\n<thead>\n<tr>\n<th style="text-align: left">Key</th>\n<th style="text-align: center">Value</th>\n'
            '<th style="text-align: right">N</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td style="text-align: left"><code>a|b</code></td>\n'
            '<td style="text-align: center">x | y</td>\n<td style="text-align: right"><strong>1</strong></td>\n</tr>\n<tr>\n'
            '<td style="text-align: left">short</td>\n<td style="text-align: center"></td>\n<td style="text-align: right"></td>\n</tr>\n<tr>\n'
            '<td style="text-align: left">1</td>\n<td style="text-align: center">2</td>\n<td style="text-align: right">3</td>\n</tr>\n</tbody>\n</table></div>',
      );
      same(
        '| a |\n|---|\n| 1 |\nnext row\n\nafter',
        '<div class="table"><table>\n<thead>\n<tr>\n<th>a</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>1</td>\n</tr>\n<tr>\n<td>next row</td>\n</tr>\n</tbody>\n'
            '</table></div>\n<p>after</p>',
      );
    });

    test('code blocks keep their text, escaped, with the language as a class', () {
      same(
        '```bash\nflutter test   # **all** <tests> & `more`\n\n  indented\n```',
        '<pre><code class="language-bash">flutter test   # **all** &lt;tests&gt; &amp; `more`\n\n  indented\n</code></pre>',
      );
      same('```\nplain\n```\n\n    indented code', '<pre><code>plain\n</code></pre>\n<pre><code>indented code\n</code></pre>');
    });

    test('block quotes and rules', () {
      same('> quoted\nlazy\n\n---\n\n***', '<blockquote>\n<p>quoted\nlazy</p>\n</blockquote>\n<hr>\n<hr>');
    });
  });

  group('the guide pages', () {
    late Map<String, String> pages;
    setUpAll(() => pages = renderManualPages());

    List<String> stems(String folder) => [
      for (final f in Directory(folder).listSync().whereType<File>())
        if (f.path.endsWith('.md')) f.uri.pathSegments.last.replaceFirst('.md', ''),
    ]..sort();
    String pathOf(String code, String stem) => '${code == 'en' ? '' : '$code/'}manual/${stem == 'README' ? '' : '$stem/'}index.html';
    String urlOf(String path) => '$siteUrl${path.substring(0, path.length - 'index.html'.length)}';
    String codeOf(String path) => path.startsWith('pt/') ? 'pt' : 'en';

    test('every chapter of both languages is a page: English under /manual/, Portuguese under /pt/manual/', () {
      expect(manualSources, {'en': 'docs/manual', 'pt': 'docs/manual/pt-BR'});
      final en = stems('docs/manual');
      expect(stems('docs/manual/pt-BR'), en, reason: 'the same chapters in both languages');
      expect(pages.keys.toSet(), {
        for (final code in manualSources.keys)
          for (final stem in en) pathOf(code, stem),
      });
      expect(manualUrl('en'), '${siteUrl}manual/');
      expect(manualUrl('pt', 'getting-started'), '${siteUrl}pt/manual/getting-started/');
      expect(manualUrl('pt', 'README'), '${siteUrl}pt/manual/');
      expect(manualUrl('es', 'calculation'), '${siteUrl}manual/calculation/', reason: 'a language without a guide gets the English one');
    });

    test('every page has a title, a description, its language, canonical address and alternates, and JSON-LD', () {
      for (final e in pages.entries) {
        final html = e.value;
        final code = codeOf(e.key);
        final url = urlOf(e.key);
        final h1 = RegExp(r'<h1 id="[^"]+">(.+?)</h1>').firstMatch(html)!.group(1)!.replaceAll(RegExp('<[^>]+>'), '');
        final title = RegExp('<title>(.+?)</title>').firstMatch(html)!.group(1)!;
        expect(title.toLowerCase(), contains(code == 'pt' ? 'guia do usuário do opencadirrigation' : 'opencadirrigation user guide'), reason: e.key);
        if (!e.key.endsWith('manual/index.html')) expect(title, startsWith(h1), reason: e.key);
        final description = unescape(RegExp(r'<meta name="description" content="([^"]+)">').firstMatch(html)!.group(1)!);
        expect(description.length, inInclusiveRange(20, 160), reason: '${e.key}: $description');
        expect(html, contains('<html lang="${siteLang(code).tag}">'), reason: e.key);
        expect(html, contains('<meta name="robots" content="index, follow">'), reason: e.key);
        expect(html, contains('<link rel="canonical" href="$url">'), reason: e.key);
        final english = url.replaceFirst('${siteUrl}pt/', siteUrl);
        final portuguese = url.replaceFirst('${siteUrl}manual/', '${siteUrl}pt/manual/');
        for (final (tag, href) in [('en', english), ('pt-BR', portuguese), ('pt', portuguese), ('x-default', english)]) {
          expect(html, contains('<link rel="alternate" hreflang="$tag" href="$href">'), reason: '${e.key}: $tag');
        }
        final ld = jsonDecode(RegExp(r'<script type="application/ld\+json">([\s\S]*?)</script>').firstMatch(html)!.group(1)!) as Map<String, dynamic>;
        final graph = (ld['@graph'] as List).cast<Map<String, dynamic>>();
        final article = graph.firstWhere((n) => n['@type'] == 'TechArticle');
        expect(article['headline'], unescape(h1), reason: e.key);
        expect(article['inLanguage'], siteLang(code).tag, reason: e.key);
        expect(article['dateModified'], siteLastMod, reason: e.key);
        expect(article['publisher'], {'@id': '$siteUrl#org'}, reason: e.key);
        expect((article['isPartOf'] as Map)['url'], manualUrl(code), reason: e.key);
        final crumbs = graph.firstWhere((n) => n['@type'] == 'BreadcrumbList')['itemListElement'] as List;
        expect([for (final c in crumbs) (c as Map)['item']], [siteLang(code).url, manualUrl(code), if (url != manualUrl(code)) url], reason: e.key);
      }
    });

    test('no Markdown is left in the text of any page (code aside)', () {
      for (final e in pages.entries) {
        final body = e.value.substring(e.value.indexOf('<body>')).replaceAll(RegExp(r'<pre>[\s\S]*?</pre>|<code>[\s\S]*?</code>|<script[\s\S]*?</script>'), ' ');
        final text = body.replaceAll(RegExp('<[^>]+>'), '');
        for (final needle in ['**', '`', '](', '|---', '\\|']) {
          expect(text, isNot(contains(needle)), reason: '${e.key}: $needle');
        }
        expect(RegExp(r'^\s*#', multiLine: true).hasMatch(text), isFalse, reason: '${e.key}: a heading left as text');
        expect(RegExp('&lt;[A-Za-z/!]').firstMatch(text)?.group(0), isNull, reason: '${e.key}: raw HTML (not converted) shown as text');
        expect(RegExp(r'(^|\s)[*_][^\s*_]', multiLine: true).firstMatch(text)?.group(0), isNull, reason: '${e.key}: emphasis left as text');
      }
    });

    test('every link between the pages reaches a page and its heading; every other link leaves the site', () {
      final ids = {for (final e in pages.entries) urlOf(e.key): RegExp(r' id="([^"]+)"').allMatches(e.value).map((m) => m.group(1)!).toSet()};
      for (final e in pages.entries) {
        final self = urlOf(e.key);
        expect(ids[self]!.length, RegExp(r' id="').allMatches(e.value).length, reason: '${e.key}: every anchor once');
        for (final m in RegExp(r'<a href="([^"]*)"').allMatches(e.value)) {
          final href = m.group(1)!.replaceAll('&amp;', '&');
          final hash = href.indexOf('#');
          final page = hash < 0 ? href : href.substring(0, hash);
          final anchor = hash < 0 ? null : href.substring(hash + 1);
          if (page.isEmpty) {
            expect(ids[self], contains(anchor), reason: '${e.key}: $href');
          } else if (page.startsWith('${siteUrl}manual/') || page.startsWith('${siteUrl}pt/manual/')) {
            expect(ids.keys, contains(page), reason: '${e.key}: $href');
            if (anchor != null) expect(ids[page], contains(anchor), reason: '${e.key}: $href');
          } else if (page.startsWith('$appRepositoryUrl/blob/main/')) {
            expect(File(page.substring('$appRepositoryUrl/blob/main/'.length)).existsSync(), isTrue, reason: '${e.key}: $href');
          } else if (page.startsWith('$appRepositoryUrl/tree/main/')) {
            expect(Directory(page.substring('$appRepositoryUrl/tree/main/'.length)).existsSync(), isTrue, reason: '${e.key}: $href');
          } else {
            expect(page, anyOf(startsWith('https://'), startsWith('mailto:')), reason: '${e.key}: a relative link left ($href)');
          }
        }
      }
    });

    test('links are rewritten: chapters to their pages, the other language, other files to GitHub', () {
      final en = pages['manual/index.html']!;
      final pt = pages['pt/manual/index.html']!;
      expect(en, contains('<a href="${siteUrl}manual/getting-started/">'));
      expect(en, contains('<a href="${siteUrl}pt/manual/">'), reason: 'pt-BR/README.md from the English guide');
      expect(pt, contains('<a href="${siteUrl}manual/">'), reason: '../README.md from the Portuguese guide');
      expect(pt, contains('<a href="${siteUrl}pt/manual/getting-started/">'));
      expect(en, contains('<a href="$appRepositoryUrl/blob/main/README.md">'), reason: '../../README.md');
      expect(en, contains('<a href="$appRepositoryUrl/blob/main/docs/TECHNICAL_STUDY.md">'), reason: '../TECHNICAL_STUDY.md');
      expect(pt, contains('<a href="$appRepositoryUrl/blob/main/README.pt-BR.md">'), reason: '../../../README.pt-BR.md');
      expect(pages['manual/getting-started/index.html'], contains('<a href="$appRepositoryUrl/tree/main/examples">'), reason: '../../examples/');
    });

    test('every heading of the Markdown has its GitHub anchor on the page', () {
      for (final e in manualSources.entries) {
        for (final stem in stems(e.value)) {
          final html = pages[pathOf(e.key, stem)]!;
          var fence = false;
          for (final line in File('${e.value}/$stem.md').readAsLinesSync()) {
            if (line.startsWith('```')) fence = !fence;
            final m = RegExp(r'^#+ (.+)$').firstMatch(line);
            if (!fence && m != null) expect(html, contains(' id="${slug(m.group(1)!)}"'), reason: '${e.key}/$stem: ${m.group(1)}');
          }
        }
      }
    });

    test('each page lists every chapter in the order of the index, marks its own and links the previous and next', () {
      for (final code in manualSources.keys) {
        final index = File('${manualSources[code]}/README.md').readAsStringSync();
        final order = ['README', for (final m in RegExp(r'^\d+\. \[[^\]]+\]\(([a-z-]+)\.md\)', multiLine: true).allMatches(index)) m.group(1)!];
        expect(order.toSet(), stems(manualSources[code]!).toSet(), reason: '$code: the index lists every chapter');
        final urls = [for (final stem in order) urlOf(pathOf(code, stem))];
        for (final (i, stem) in order.indexed) {
          final html = pages[pathOf(code, stem)]!;
          final nav = RegExp(r'<nav class="chapters"[\s\S]*?</nav>').firstMatch(html)!.group(0)!;
          expect([for (final m in RegExp(r'<a href="([^"]+)"').allMatches(nav)) m.group(1)], urls, reason: '$code/$stem');
          expect(nav, contains('<a href="${urls[i]}" aria-current="page">'), reason: '$code/$stem');
          expect('aria-current'.allMatches(nav).length, 1, reason: '$code/$stem');
          expect(html.contains('<a rel="prev"'), i > 0, reason: '$code/$stem');
          expect(html.contains('<a rel="next"'), i + 1 < urls.length, reason: '$code/$stem');
          if (i > 0) expect(html, contains('<a rel="prev" href="${urls[i - 1]}">'), reason: '$code/$stem');
          if (i + 1 < urls.length) expect(html, contains('<a rel="next" href="${urls[i + 1]}">'), reason: '$code/$stem');
        }
      }
    });

    test('chapters with three sections or more open with a table of contents of them', () {
      for (final e in pages.entries) {
        final sections = [for (final m in RegExp(r'<h2 id="([^"]+)">').allMatches(e.value)) m.group(1)];
        final toc = RegExp(r'<nav class="toc"[\s\S]*?</nav>').firstMatch(e.value)?.group(0);
        if (sections.length < 3) {
          expect(toc, isNull, reason: e.key);
          continue;
        }
        expect(toc, isNotNull, reason: e.key);
        expect([for (final m in RegExp(r'href="#([^"]+)"').allMatches(toc!)) m.group(1)], sections, reason: e.key);
        expect(e.value.indexOf('<nav class="toc"'), greaterThan(e.value.indexOf('</h1>')), reason: '${e.key}: under the title');
      }
    });

    test('header and footer: the app, the other language, version, source code, legal pages, date, consent', () {
      for (final e in pages.entries) {
        final html = e.value;
        final code = codeOf(e.key);
        final lang = siteLang(code);
        final other = code == 'en' ? urlOf(e.key).replaceFirst('${siteUrl}manual/', '${siteUrl}pt/manual/') : urlOf(e.key).replaceFirst('${siteUrl}pt/', siteUrl);
        expect(html, contains('<a class="home" href="${lang.url}"><img src="/brand/logo-horizontal-'), reason: e.key);
        expect(html, contains('alt="OpenCADIrrigation"'), reason: e.key);
        expect(html, contains('<a class="app" href="${lang.url}">${code == 'pt' ? 'Abrir o app' : 'Open the app'}</a>'), reason: e.key);
        expect(html, contains('<a href="$other" hreflang="${code == 'en' ? 'pt-BR' : 'en'}"'), reason: '${e.key}: the other language');
        expect(html, contains('OpenCADIrrigation $appVersion'), reason: e.key);
        expect(html, contains('<a href="$appRepositoryUrl">'), reason: e.key);
        expect(html, contains('<a href="${privacyUrl(lang)}">'), reason: e.key);
        expect(html, contains('<a href="${termsUrl(lang)}">'), reason: e.key);
        expect(html, contains('<time datetime="$siteLastMod">'), reason: e.key);
        expect(html, contains('id="oci-consent"'), reason: e.key);
        for (final m in RegExp(r' src="([^"]+)"').allMatches(html)) {
          expect(m.group(1), startsWith('/'), reason: '${e.key}: only files of the site');
        }
      }
    });

    test('every page carries the Content Security Policy before any script, and no inline script runs', () {
      final meta = '<meta http-equiv="Content-Security-Policy" content="$contentSecurityPolicy">';
      for (final e in pages.entries) {
        expect(e.value, contains(meta), reason: e.key);
        expect(e.value.indexOf(meta), lessThan(e.value.indexOf('<script')), reason: '${e.key}: before every script');
        for (final m in RegExp(r'<script([^>]*)>').allMatches(e.value)) {
          final attrs = m.group(1)!;
          expect(attrs.contains(' src=') || attrs.contains('type="application/ld+json"'), isTrue, reason: '${e.key}: inline script <script$attrs>');
        }
        expect(e.value, contains('<script src="/site.js?v='), reason: '${e.key}: the consent notice is site.js');
      }
    });

    test('the sitemap lists every page once, with the page in each language and x-default', () {
      final entries = manualSitemapEntries();
      final urls = [for (final (url, _) in entries) url];
      expect(urls.toSet().length, urls.length, reason: 'each page once');
      expect(urls.toSet(), {for (final path in pages.keys) urlOf(path)});
      for (final (url, alternates) in entries) {
        final english = url.replaceFirst('${siteUrl}pt/', siteUrl);
        final portuguese = url.replaceFirst('${siteUrl}manual/', '${siteUrl}pt/manual/');
        expect(alternates, {'en': english, 'pt-BR': portuguese, 'pt': portuguese, 'x-default': english}, reason: url);
      }
    });
  });
}
