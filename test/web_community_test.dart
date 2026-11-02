import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The community files of the repository (1.6.0): the Discussions forms, found by the slug of their category, the
/// social preview image the owner uploads, and the suggested description and topics (docs/GITHUB.md).
void main() {
  test('a Discussions form for every category docs/GITHUB.md names, each with a title and fields', () {
    final forms = Directory('.github/DISCUSSION_TEMPLATE').listSync().whereType<File>().where((f) => f.path.endsWith('.yml')).toList();
    final slugs = {for (final f in forms) f.uri.pathSegments.last.replaceAll('.yml', '')};
    expect(slugs, {'ideas', 'q-a', 'show-and-tell', 'translations', 'catalogues'});
    final guide = File('docs/GITHUB.md').readAsStringSync();
    for (final f in forms) {
      final text = f.readAsStringSync();
      final slug = f.uri.pathSegments.last.replaceAll('.yml', '');
      expect(text, contains(RegExp(r'^title: ".+"$', multiLine: true)), reason: slug);
      expect(text, contains(RegExp(r'^body:$', multiLine: true)), reason: slug);
      expect(RegExp(r'^  - type: (textarea|input|dropdown)$', multiLine: true).allMatches(text), isNotEmpty, reason: '$slug asks something');
      expect(text, isNot(contains('\t')), reason: '$slug: YAML takes no tabs');
      expect(guide, contains('`$slug`'), reason: '$slug: docs/GITHUB.md tells the owner to create the category');
    }
  });

  test('the social preview: 1280 × 640, the size GitHub asks for', () {
    final png = img.decodePng(Uint8List.fromList(File('docs/github/social-preview.png').readAsBytesSync()));
    expect(png, isNotNull, reason: 'node tool/og/render_social.js');
    expect((png!.width, png.height), (1280, 640));
    expect(File('tool/og/render_social.js').readAsStringSync(), contains("'docs/github/social-preview.png'"));
  });

  test('the suggested description and topics fit GitHub: at most 20 topics, lower case with hyphens, a description under 350 characters', () {
    final guide = File('docs/GITHUB.md').readAsStringSync();
    final topicsLine = RegExp(r'\*\*Topics\*\*[^\n]*(\n  [^\n]+)*').firstMatch(guide)!.group(0)!;
    final topics = [for (final m in RegExp(r'`([^`]+)`').allMatches(topicsLine)) m.group(1)!];
    expect(topics.length, inInclusiveRange(10, 20));
    expect(topics.toSet().length, topics.length, reason: 'no topic twice');
    for (final t in topics) {
      expect(RegExp(r'^[a-z0-9][a-z0-9-]{0,49}$').hasMatch(t), isTrue, reason: t);
    }
    final description = [for (final m in RegExp(r'^  > (.*)$', multiLine: true).allMatches(guide)) m.group(1)!].join(' ');
    expect(description.length, inInclusiveRange(80, 350));
    expect(File('docs/GITHUB.pt-BR.md').readAsStringSync(), contains(description.substring(0, 60)), reason: 'the same text in both');
    // the issue chooser sends questions and ideas to the Discussions
    expect(File('.github/ISSUE_TEMPLATE/config.yml').readAsStringSync(), contains('/discussions'));
  });
}
