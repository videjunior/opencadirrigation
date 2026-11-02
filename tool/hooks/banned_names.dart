/// The names the public repository must not carry (CONTRIBUTING.md,
/// "Editorial rule"), kept in one list, tool/hooks/banned-names.sha256, as
/// SHA-256 digests so that the list does not name them either. Two users:
///
/// - the pre-commit hook (tool/hooks/pre-commit) checks the lines a commit
///   adds, a unified diff on stdin as `git diff --cached -U0` writes it,
///   against every name of the list (and of the local plain list
///   `<git dir>/info/banned-words`), prints where they are and exits with
///   code 1:
///     git diff --cached -U0 --no-color | dart tool/hooks/banned_names.dart
/// - test/editorial_names_test.dart checks every file of the repository:
///   the `[everywhere]` names in all of them, the `[user-facing]` names in
///   what people read ([isUserFacing]).
///
/// A name matches a word of the text, or two or three consecutive words
/// joined by a space or written together ("Quux CAD", "quux-cad" and
/// "QuuxCAD" are one name), compared in lower case, ASCII letters and
/// digits only ([namesIn]).
library;

import 'dart:convert';
import 'dart:io';

import '../sw_manifest.dart' show sha256Hex;

/// The committed list, relative to the repository root.
const bannedNamesFile = 'tool/hooks/banned-names.sha256';

/// The names of the list, by scope.
class BannedNames {
  BannedNames({Set<String> everywhere = const {}, Set<String> userFacing = const {}}) : everywhere = Set.unmodifiable(everywhere), userFacing = Set.unmodifiable(userFacing);

  /// Competing irrigation-design products and their makers: never named,
  /// anywhere.
  final Set<String> everywhere;

  /// CAD products and their makers: never named in what people read (the
  /// interface, the site, the documentation); a format goes by its own name.
  final Set<String> userFacing;

  /// Every digest of the list.
  Set<String> get all => {...everywhere, ...userFacing};

  bool get isEmpty => everywhere.isEmpty && userFacing.isEmpty;

  /// The digests that apply to the file at [path] (relative to the root).
  Set<String> forPath(String path) => isUserFacing(path) ? all : everywhere;

  /// Reads the list text [text]: one digest per line under a `[everywhere]`
  /// or `[user-facing]` header; `#` starts a comment. A line that is not a
  /// digest, a digest before any header and an unknown header are errors,
  /// so that a mistyped list never checks less than it says.
  static BannedNames parse(String text) {
    final everywhere = <String>{}, userFacing = <String>{};
    Set<String>? into;
    var n = 0;
    for (final raw in const LineSplitter().convert(text)) {
      n++;
      final l = raw.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      if (l.startsWith('[')) {
        into = switch (l) {
          '[everywhere]' => everywhere,
          '[user-facing]' => userFacing,
          _ => throw FormatException('$bannedNamesFile:$n: unknown section $l (use [everywhere] or [user-facing])'),
        };
      } else if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(l)) {
        throw FormatException('$bannedNamesFile:$n: not a lower-case SHA-256 digest');
      } else if (into == null) {
        throw FormatException('$bannedNamesFile:$n: a digest before the first section');
      } else {
        into.add(l);
      }
    }
    return BannedNames(everywhere: everywhere, userFacing: userFacing);
  }

  /// The committed list of the repository at [root].
  static BannedNames load([String root = '.']) => parse(File('$root/$bannedNamesFile').readAsStringSync());

  /// The committed list plus the names of the local plain list
  /// `<git dir>/info/banned-words` (one name per line, `#` comments; never
  /// committed, so it names them in clear), which count everywhere.
  static BannedNames loadWithLocal([String root = '.']) {
    final list = load(root);
    final local = localListFile(root);
    if (local == null || !local.existsSync()) return list;
    final extra = <String>{
      for (final l in local.readAsLinesSync())
        if (l.trim().toLowerCase() case final t when t.isNotEmpty && !t.startsWith('#')) sha256Hex(utf8.encode(_tokens(t).join())),
    };
    return BannedNames(everywhere: {...list.everywhere, ...extra}, userFacing: list.userFacing);
  }
}

/// `<git dir>/info/banned-words` of the clone at [root] (the common git
/// folder, so that every worktree of a clone shares it), or null without git.
File? localListFile([String root = '.']) {
  try {
    final r = Process.runSync('git', ['rev-parse', '--git-common-dir'], workingDirectory: root);
    if (r.exitCode != 0) return null;
    final dir = (r.stdout as String).trim();
    final abs = dir.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(dir) ? dir : '$root/$dir';
    return File('$abs/info/banned-words');
  } on ProcessException {
    return null;
  }
}

final _token = RegExp(r'[a-z0-9]+');

List<String> _tokens(String text) => [for (final m in _token.allMatches(text.toLowerCase())) m.group(0)!];

/// Digests of [digests] that [text] names: a word, or two or three
/// consecutive words joined by a space or written together, 4 to 24
/// characters long. [memo] keeps the answer for every candidate already
/// hashed (the same word in many files is hashed once).
Set<String> namesIn(String text, Set<String> digests, [Map<String, String?>? memo]) {
  final found = <String>{};
  if (digests.isEmpty) return found;
  final words = _tokens(text);
  for (var i = 0; i < words.length; i++) {
    for (var n = 1; n <= 3 && i + n <= words.length; n++) {
      final g = words.sublist(i, i + n);
      for (final gram in {g.join(' '), if (n > 1) g.join()}) {
        if (gram.length < 4 || gram.length > 24) continue;
        final String? hit;
        if (memo != null && memo.containsKey(gram)) {
          hit = memo[gram];
        } else {
          final d = sha256Hex(utf8.encode(gram));
          hit = digests.contains(d) ? d : null;
          memo?[gram] = hit;
        }
        if (hit != null) found.add(hit);
      }
    }
  }
  return found;
}

/// What people read: the interface texts (string table and its parts, the
/// language packs, the tutorial), the site (its generator and the generated
/// pages and files) and the documentation. Generated artefacts rebuilt by
/// their own tools (the design worker, docs/AI_TOOLS.md, examples/) follow
/// the sources once rebuilt.
bool isUserFacing(String path) =>
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

/// "file:line" of every added line of [diff] that names one of [names]:
/// every name of the list, whatever the file (a commit adds no name the
/// rule forbids, in code and comments either). The list file is skipped.
List<String> findBanned(String diff, BannedNames names) {
  final out = <String>[];
  final digests = names.all;
  final memo = <String, String?>{};
  String? file;
  var line = 0;
  for (final l in const LineSplitter().convert(diff)) {
    if (l.startsWith('+++ ')) {
      file = l.startsWith('+++ b/') ? l.substring(6) : null;
    } else if (l.startsWith('@@')) {
      final m = RegExp(r'\+(\d+)').firstMatch(l);
      line = m == null ? 0 : int.parse(m.group(1)!);
    } else if (l.startsWith('+') && file != null) {
      if (file != bannedNamesFile && namesIn(l.substring(1), digests, memo).isNotEmpty) out.add('$file:$line');
      line++;
    }
  }
  return out;
}

/// The files of [paths] that name a digest of [names] where it applies
/// ([BannedNames.forPath]), as digest → files (sorted); files that are not
/// UTF-8 text are skipped.
Map<String, List<String>> scanFiles(Iterable<String> paths, BannedNames names, {String root = '.'}) {
  final found = <String, Set<String>>{};
  final memo = <String, String?>{};
  final all = names.all;
  for (final path in paths) {
    final String text;
    try {
      text = File('$root/$path').readAsStringSync();
    } on FileSystemException {
      continue; // not UTF-8 text
    }
    final scope = names.forPath(path);
    for (final d in namesIn(text, all, memo)) {
      if (scope.contains(d)) (found[d] ??= {}).add(path);
    }
  }
  return {for (final e in found.entries) e.key: e.value.toList()..sort()};
}

Future<void> main() async {
  final BannedNames names;
  try {
    names = BannedNames.loadWithLocal();
  } on Object catch (e) {
    stderr.writeln('pre-commit: cannot read the banned-name list: $e');
    exitCode = 1;
    return;
  }
  if (names.isEmpty) return;
  final found = findBanned(await stdin.transform(utf8.decoder).join(), names);
  if (found.isEmpty) return;
  stderr.writeln('pre-commit: the commit adds names the public repository must not carry ($bannedNamesFile):');
  for (final f in found) {
    stderr.writeln('  $f');
  }
  exitCode = 1;
}
