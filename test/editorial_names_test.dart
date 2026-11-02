import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sw_manifest.dart' show sha256Hex;

/// The editorial rule of the repository (CONTRIBUTING.md): competing
/// irrigation-design products and their makers are never named, anywhere;
/// CAD products and their makers are not named in what people read (the
/// interface texts, language packs, tutorial, site pages and documentation),
/// where a format goes by the name of the format (DXF, DWG R2000).
///
/// The names are kept here only as SHA-256 digests of the lower-case words
/// (and of two or three words, joined by a space or written together), so
/// that this test does not name them either: a failure gives the file, not
/// the word.
void main() {
  // one pass over the repository for both lists
  late Map<String, List<String>> found;
  setUpAll(() => found = _scan(_repositoryFiles(), {..._competitors, ..._cadProducts}));

  Map<String, List<String>> where(Set<String> digests, bool Function(String path) inScope) => {
    for (final e in found.entries)
      if (digests.contains(e.key))
        if (e.value.where(inScope).toList() case final files when files.isNotEmpty) e.key.substring(0, 12): files,
  };

  test('no competing irrigation-design product or maker is named in the repository', () {
    expect(where(_competitors, (_) => true), isEmpty, reason: 'names the editorial rule forbids (digest → files)');
  });

  test('no CAD product or maker is named in the interface, the site or the documentation', () {
    expect(where(_cadProducts, _userFacing), isEmpty, reason: 'names the editorial rule forbids in what users read (digest → files)');
  });

  test('the digests catch a name however it is written, and nothing else', () {
    // a stand-in name with its digest (the real ones are not written anywhere)
    final probe = {sha256Hex(utf8.encode('quuxcad'))};
    for (final text in ['QuuxCAD 2.0', 'the quuxcad file', 'Quux CAD plug-in', '(quux-cad)', 'QUUX_CAD']) {
      expect(_matches(text, probe), isNotEmpty, reason: text);
    }
    for (final text in ['quux', 'cad quux', 'quuxcadence', 'a quuxcadd']) {
      expect(_matches(text, probe), isEmpty, reason: text);
    }
  });
}

/// Competing irrigation-design products and their makers.
const _competitors = {
  '50ff6c11a1aa77e39ac50d9a340388a5680699cc8cf32700d163469cabd9ff02',
  '15c39416e31fdcae99363e59e0565f44c49f2c5da3561019364700124efe7deb',
  '6cfa77a6549c2c78b30492bcf466e955c715f2956f168a1a58123873523b86d2',
  '2b3ecf74c74afc0a7876de52aea2e64add71faa69d5c5863d6b5cc9f60822a57',
  'ced4445f437b535c4a59538fae40302f9c105c7141ff68acf34977eab446137b',
  '334276d68b46a2ebe41be2caa9fabd9d4f25f64fa94fff480604f8423a84c9e5',
  'a330e32b94672c61a92d73de6f863aa5bd85cc6d3e012d9e4456e89b4581962f',
  '41c9afdb542c09f30626b886ab19fc13d43a87222ed9fc7de71d5191da31c0c2',
  'bd8a0eefaa45f2b6e28e390a02c50f560f31dcd5ef6cdee90f0c660e9f3b7d79',
  'd38e366f7c412b7d99dc6818152f37936d511e3e83ca80220877111a4813511d',
  '62cfc917c13eda7b31202f66f8378344d69f601bab9c89e043807dc763f1e0bc',
  '3803143de59bed449b1fb0d4fb8e2c36cc42bc9bcbdfdfcd8bd3c4d7c214b371',
  '47097c75d3247ec40dc7787744dafdb099561de837274a01f4670e10abb20514',
  'c6c6d146e6c18e37a2afa6e426782c7fbbf5c6efc271d964cba4f495d4002bbf',
  '2e988bd1eb17c8a0b5b23c8fe0198ab7d7b448def72ab41f4f9c69b3c3a6f848',
  'b8ef57e516cc04c0547970ff38a61eca00bfe9bff6d044b31ba2949f7086d0af',
  'd2a8112bb57b398bdbe57fac1a13bc47ad0b480d5b2e820fdf4834fe3172f906',
  '56eaec0426813b9369ef401e24247ff9d46002f83b3f003e25405c338b88c111',
  '0ea202e3b286f6bd9de905796bbd210526d617c1ae8bc268065751cbdfa2fe3b',
  '89084e17ea8923e765867a848349b8389c0aa584c7b2dc8f0329be24620f1d78',
  '003aee44d9a98f2aae07be9cb680c742cbf6aa5cab9d97d647038650787704d2',
  '86c24c42d8e3060c23d692de495a721f22d602f1448acef48638f86ad742aa65',
};

/// CAD products and their makers.
const _cadProducts = {
  '50f08e64c5a6192c58961a72ca0b5fcb06f1a09d49e3d012619c2050b84c9b00',
  '320d597682ed208cdaa58f77d17df6037e29f3c48323d6d16b23e0ca18f97788',
  '8de6e95aa62a3cbda1f9b2b0e064fbe51248482476d651056e32db3067d35529',
  '0408a7b9986fcb7b48ceade1108206c46125e0102ab91bd033bd25b53fd99ac5',
  '258f9307382ca0fc5d1b4e522f2158c2b6b723727ca671ba8d5afe665d855533',
  'ff8934b2aac299dee7b686a6c453f8113e3b3f81c42944015c2f9b3e4cd41dfc',
  'b9d80abb69a9219054235f264374aaf3dbf8a2c194bd75d99ea908686df66159',
  '0f1a60a262855b912dc03511c041743d05320ca8a6be7c361aec83a22dc68dc1',
  '44dc5d8ec4db689fd8a2acb16fc4631625b6ad997688d45a1105551e3bb7a4f2',
  '02578f74509f8f60a7d36a527fd5fa5aea3c43d30b16a94d4d5307633d33228d',
  '46b64f53eaf054aff2560c09b665247e8340f985de4095aef8135d29dac734a1',
  '544582bc2aa10dec8d3a94d13c71cc464d9c20652a4b9d480511e6bad18a6beb',
  '4ec90cb5a1d1b69299b71a63c3453c4c1870629a9b11d189b40b805bb67d54ad',
  '5971b0dc06256600737ca8ba133808b5d8122016a777948e998535036594a95b',
  '063de0773639dd9f2b3047465a825bea1c752c53177f51acd573cf1e17accdbc',
  'bac8736b4055203b1e2fbbf131280979d0342920a5d1646e257a9a9e6727fcbd',
  'de4e9e60784006b242783eff92c8efc449ffb1ded63b3ba993acbe7af2800f49',
  '1a0e8f319003c17426c761dbde3c251e492f477fa4900f643f33b77bd7e46e15',
  'a7a067c45dafb115430482c1348384ab446d190d9ac12a57188b3e436e89a8e6',
  '531a1cfd2cf543cebbe2722a4731a7809c04e2b7e42435b5e86193ea9077f68c',
  '7d212a337f4f05555052bb6dc8989346aee1f69eb97d6b4d241dcc9cc2ff3cfe',
  'a5a66a7cab5a0debf265e6c28b76b7347adec2abbf8daf3f5a12b4817dd00e3a',
  '6f3ed4b2a3eec6f2a07e3e0cc0ae800e36feadea193c503ea0ab49bcff0c19e0',
  'af98c2d4d45cde636ab4ec20cbe131b145eacdb1b53c97f658a0b93d4e9ec8d4',
};

/// What people read: the interface texts (string table and its parts, the
/// language packs, the tutorial), the site (its generator and the generated
/// pages and files) and the documentation. Generated artefacts rebuilt by
/// their own tools (the design worker, docs/AI_TOOLS.md, examples/) follow
/// the sources once rebuilt.
bool _userFacing(String path) =>
    path == 'lib/app/i18n.dart' ||
    path.startsWith('lib/app/i18n_parts/') ||
    path.startsWith('lib/app/tutorial/') ||
    path.startsWith('assets/i18n/') ||
    path == 'tool/site.dart' ||
    path.startsWith('tool/site/') ||
    (path.startsWith('web/') && RegExp(r'\.(html|txt|json)$').hasMatch(path)) ||
    RegExp(r'^[A-Z][A-Za-z_]*(\.[A-Za-z-]+)?\.md$').hasMatch(path) ||
    path.startsWith('docs/manual/') ||
    path == 'docs/TECHNICAL_STUDY.md' ||
    path == 'docs/PESQUISA.pt-BR.md' ||
    path.startsWith('.github/');

/// Text files of the repository, relative to its root: everything but the
/// tools' caches, build output and binary files.
List<String> _repositoryFiles() {
  final out = <String>[];
  final skipDirs = {'.git', '.dart_tool', 'build', 'node_modules', '.idea', '.vscode', 'Pods', 'ephemeral'};
  final binary = RegExp(r'\.(png|webp|ico|jpe?g|gif|ttf|otf|woff2?|wasm|dwg|dgn|gz|zip|kmz|shp|shx|dbf|pdf|tiff?|las|laz|bin|xlsx|jar|keystore|icns|so|dylib)$', caseSensitive: false);
  void walk(Directory dir, String prefix) {
    for (final e in dir.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final path = '$prefix$name';
      if (e is Directory) {
        if (!skipDirs.contains(name)) walk(e, '$path/');
      } else if (e is File && !binary.hasMatch(name) && name != '.DS_Store') {
        out.add(path);
      }
    }
  }

  walk(Directory.current, '');
  return out;
}

final _token = RegExp(r'[a-z0-9]+');

/// Digests in [digests] matched by a word of [text], or by two or three
/// consecutive words joined by a space or written together.
Set<String> _matches(String text, Set<String> digests) {
  final words = _token.allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
  final grams = <String>{};
  for (var i = 0; i < words.length; i++) {
    for (var n = 1; n <= 3 && i + n <= words.length; n++) {
      final g = words.sublist(i, i + n);
      grams.add(g.join(' '));
      if (n > 1) grams.add(g.join());
    }
  }
  return {
    for (final g in grams)
      if (g.length >= 4 && g.length <= 24 && digests.contains(sha256Hex(utf8.encode(g)))) sha256Hex(utf8.encode(g)),
  };
}

/// Files of [paths] naming one of [digests], as digest → files.
Map<String, List<String>> _scan(Iterable<String> paths, Set<String> digests) {
  final found = <String, List<String>>{};
  // the same word in many files is hashed once
  final seen = <String, bool>{};
  for (final path in paths) {
    final String text;
    try {
      text = File(path).readAsStringSync();
    } on FileSystemException {
      continue; // not UTF-8 text
    }
    final words = _token.allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < words.length; i++) {
      for (var n = 1; n <= 3 && i + n <= words.length; n++) {
        final g = words.sublist(i, i + n);
        for (final gram in {g.join(' '), if (n > 1) g.join()}) {
          if (gram.length < 4 || gram.length > 24) continue;
          final hit = seen[gram] ??= digests.contains(sha256Hex(utf8.encode(gram)));
          if (hit) (found[sha256Hex(utf8.encode(gram))] ??= []).add(path);
        }
      }
    }
  }
  return {for (final e in found.entries) e.key: e.value.toSet().toList()..sort()};
}
