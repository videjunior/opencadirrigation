import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart' show appReleaseDate, appVersion;

import '../tool/site.dart' show renderSecurityTxt, siteLastMod;

/// The documentation (SIT-14, SIT-15): a short README in each language with
/// the manual in docs/manual/ (English) and docs/manual/pt-BR/, the
/// community files, and every link between them pointing to a file and a
/// heading that exist.
void main() {
  /// GitHub's anchor of a heading.
  String slug(String heading) => heading.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}_\- ]', unicode: true), '').replaceAll(' ', '-');

  final docs = [
    for (final f in ['README.md', 'README.pt-BR.md', 'CONTRIBUTING.md', 'CHANGELOG.md', 'CHANGELOG.pt-BR.md', 'SECURITY.md', 'CODE_OF_CONDUCT.md', 'hosting/README.md']) File(f),
    ...Directory('docs/manual').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.md')),
  ];

  test('every relative link of the documentation reaches a file, and its heading', () {
    final broken = <String>[];
    for (final doc in docs) {
      final text = doc.readAsStringSync();
      final links = [for (final m in RegExp(r'\]\(([^)\s]+)\)').allMatches(text)) m.group(1)!, for (final m in RegExp(r'src="([^"]+)"').allMatches(text)) m.group(1)!];
      for (final link in links) {
        if (RegExp(r'^(https?:|mailto:)').hasMatch(link)) continue;
        final hash = link.indexOf('#');
        final path = hash < 0 ? link : link.substring(0, hash);
        final anchor = hash < 0 ? null : link.substring(hash + 1);
        final target = path.isEmpty ? doc : File(doc.parent.uri.resolve(path).toFilePath());
        if (path.isNotEmpty && !target.existsSync() && !Directory(target.path).existsSync()) {
          broken.add('${doc.path}: $link');
          continue;
        }
        if (anchor != null && target.path.endsWith('.md')) {
          final headings = {for (final m in RegExp(r'^#+ (.+)$', multiLine: true).allMatches(target.readAsStringSync())) slug(m.group(1)!)};
          if (!headings.contains(anchor)) broken.add('${doc.path}: $link (no such heading)');
        }
      }
    }
    expect(broken, isEmpty);
  });

  test('a short README, the manual in English and in Portuguese chapter for chapter', () {
    expect(File('README.md').readAsLinesSync().length, lessThan(200), reason: 'the manual lives in docs/manual/');
    expect(File('README.pt-BR.md').readAsLinesSync().length, lessThan(200));
    List<String> chapters(String dir) => [
      for (final f in Directory(dir).listSync().whereType<File>())
        if (f.path.endsWith('.md')) f.uri.pathSegments.last,
    ]..sort();
    final en = chapters('docs/manual');
    expect(en, containsAll(['README.md', 'getting-started.md', 'ai-assistant.md', 'privacy-and-network.md', 'limitations.md', 'development.md']));
    expect(chapters('docs/manual/pt-BR'), en, reason: 'every chapter has its Portuguese translation');
    for (final f in en.where((f) => f != 'README.md')) {
      expect(File('docs/manual/README.md').readAsStringSync(), contains('($f)'), reason: 'the index lists $f');
      expect(File('docs/manual/pt-BR/README.md').readAsStringSync(), contains('($f)'), reason: 'the Portuguese index lists $f');
    }
  });

  test('the documentation says what the app does with conversations and the network (SIT-02, SIT-03)', () {
    final en = File('docs/manual/limitations.md').readAsStringSync() + File('docs/manual/privacy-and-network.md').readAsStringSync();
    expect(en, isNot(contains('conversations are not saved')));
    expect(en, contains('Keep conversations in this browser'));
    expect(en, isNot(contains('only when you ask')));
    final pt = File('docs/manual/pt-BR/limitations.md').readAsStringSync() + File('docs/manual/pt-BR/privacy-and-network.md').readAsStringSync();
    expect(pt, isNot(contains('as conversas não são salvas')));
    expect(pt, isNot(contains('só quando você pede')));
  });

  test('community files: changelog of the current version, citation, security contact', () {
    expect(File('CHANGELOG.md').readAsStringSync(), contains('\n## $appVersion ('), reason: 'the release checklist adds the version');
    expect(File('CHANGELOG.pt-BR.md').readAsStringSync(), contains('\n## $appVersion ('));
    final cff = File('CITATION.cff').readAsStringSync();
    expect(cff, contains('cff-version: 1.2.0'));
    expect(cff, contains('version: "$appVersion"'), reason: 'CITATION.cff follows pubspec.yaml');
    expect(cff, contains('date-released: "$appReleaseDate"'));
    for (final f in ['CONTRIBUTING.md', 'CODE_OF_CONDUCT.md', 'SECURITY.md', '.github/PULL_REQUEST_TEMPLATE.md', '.github/ISSUE_TEMPLATE/bug_report.md', '.github/ISSUE_TEMPLATE/feature_request.md']) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    expect(File('SECURITY.md').readAsStringSync(), contains('/security/advisories/new'));
    // RFC 9116, renewed with every release of the site
    final txt = renderSecurityTxt();
    expect(File('web/.well-known/security.txt').readAsStringSync(), txt);
    final expires = DateTime.parse(RegExp(r'^Expires: (\S+)$', multiLine: true).firstMatch(txt)!.group(1)!);
    expect(expires.isAfter(DateTime.parse(siteLastMod)), isTrue);
    expect(expires.difference(DateTime.parse(siteLastMod)).inDays, lessThanOrEqualTo(366));
    expect(txt, contains('Contact: https://'));
    expect(txt, contains('Canonical: https://opencadirrigation.com/.well-known/security.txt'));
  });

  test('what the documents say the AI assistant reaches are the counts of docs/AI_TOOLS.md', () {
    // docs/AI_TOOLS.md is generated from the coverage map (widget_ai_coverage_test keeps it current);
    // the technical study (section 27.6), the manual and the site's reference quote its numbers
    final table = File('docs/AI_TOOLS.md').readAsStringSync();
    final counts = RegExp(r'^(\d+) tools, (\d+) operations, (\d+) settings\.$', multiLine: true).firstMatch(table)!;
    final tools = counts.group(1)!, operations = counts.group(2)!, settings = counts.group(3)!;
    int row(String source) => int.parse(RegExp('^\\| ${RegExp.escape(source)} \\| (\\d+) \\|', multiLine: true).firstMatch(table)!.group(1)!);
    final all = RegExp(r'^\| \*\*All\*\* \| \*\*(\d+)\*\* \| \*\*(\d+)\*\* \| \*\*(\d+)\*\* \| \*\*0\*\* \|$', multiLine: true).firstMatch(table)!;
    final total = all.group(1)!, covered = all.group(2)!, notApplicable = all.group(3)!;
    // (the documents wrap their lines: one space for every run of white space)
    String text(String path) => File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    final study = text('docs/TECHNICAL_STUDY.md');
    for (final needle in [
      '$tools tools are sent with every request',
      'cover $operations operations that are not sent',
      'cover $settings settings',
      '${row('Command actions')} command actions, ${row('Drawing tools')} drawing tools, ${row('Command aliases')} command aliases, ${row('Menu items (desktop and phone)')} items of the desktop and phone menus, '
          '${row('Dialogs')} dialogs and ${row('Dialog options')} of their options, ${row('Panel fields')} panel fields, ${row('Status bar')} status-bar controls and ${row('View options')} view options, '
          '$total in all, of which $covered are covered and $notApplicable have no meaning for the model',
    ]) {
      expect(study, contains(needle), reason: 'docs/TECHNICAL_STUDY.md, section 27.6');
    }
    final estudo = text('docs/PESQUISA.pt-BR.md');
    for (final needle in [
      '$tools ferramentas vão com cada requisição',
      'cobrem $operations operações que não são enviadas',
      'cobrem $settings configurações',
      '${row('Command actions')} ações de comando, ${row('Drawing tools')} ferramentas de desenho, ${row('Command aliases')} apelidos de comando, ${row('Menu items (desktop and phone)')} itens dos menus do desktop e do celular, '
          '${row('Dialogs')} diálogos e ${row('Dialog options')} das suas opções, ${row('Panel fields')} campos de painéis, ${row('Status bar')} controles da barra de status e ${row('View options')} opções de vista, '
          '$total ao todo, das quais $covered são cobertas e $notApplicable não fazem sentido para o modelo',
    ]) {
      expect(estudo, contains(needle), reason: 'docs/PESQUISA.pt-BR.md, seção 27.6');
    }
    expect(text('docs/manual/ai-assistant.md'), contains('$tools tools sent with every request, $operations more operations'));
    expect(text('docs/manual/pt-BR/ai-assistant.md'), contains('$tools ferramentas enviadas em todo pedido, mais $operations operações'));
    expect(text('docs/manual/architecture.md'), contains('$tools tools and $operations operations'));
    expect(text('docs/manual/pt-BR/architecture.md'), contains('$tools ferramentas e $operations operações'));
    expect(text('web/llms-full.txt'), contains('($tools tools, $operations more operations,'), reason: 'tool/site/llms.dart, then dart run tool/gen_site.dart');
  });
}
