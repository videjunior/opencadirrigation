/// Checks the lines a commit adds (a unified diff on stdin, as
/// `git diff --cached -U0` writes it) for words the repository must not
/// carry: the SHA-256 list of tool/hooks/banned-words.sha256 and the plain
/// list of .git/info/banned-words (local, never committed). Prints where
/// they are and exits with code 1. Run by tool/hooks/pre-commit:
///   git diff --cached -U0 --no-color | dart tool/hooks/banned_names.dart
library;

import 'dart:convert';
import 'dart:io';

import '../sw_manifest.dart' show sha256Hex;

Future<void> main() async {
  final hashes = <String>{};
  final hashFile = File('tool/hooks/banned-words.sha256');
  if (hashFile.existsSync()) {
    for (final l in hashFile.readAsLinesSync()) {
      final t = l.trim();
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(t)) hashes.add(t);
    }
  }
  final plain = File('.git/info/banned-words');
  if (plain.existsSync()) {
    for (final l in plain.readAsLinesSync()) {
      final t = l.trim().toLowerCase();
      if (t.isNotEmpty && !t.startsWith('#')) hashes.add(sha256Hex(utf8.encode(t)));
    }
  }
  if (hashes.isEmpty) return;
  final found = findBanned(await stdin.transform(utf8.decoder).join(), hashes);
  if (found.isEmpty) return;
  stderr.writeln('pre-commit: the commit adds words the public repository must not carry (tool/hooks/banned-words.sha256):');
  for (final f in found) {
    stderr.writeln('  $f');
  }
  exitCode = 1;
}

/// "file:line" of every added line of [diff] with a word whose SHA-256 is in [hashes].
List<String> findBanned(String diff, Set<String> hashes) {
  final out = <String>[];
  String? file;
  var line = 0;
  for (final l in const LineSplitter().convert(diff)) {
    if (l.startsWith('+++ ')) {
      file = l.startsWith('+++ b/') ? l.substring(6) : null;
    } else if (l.startsWith('@@')) {
      final m = RegExp(r'\+(\d+)').firstMatch(l);
      line = m == null ? 0 : int.parse(m.group(1)!);
    } else if (l.startsWith('+') && file != null) {
      if (file != 'tool/hooks/banned-words.sha256') {
        for (final w in RegExp(r'[a-z0-9]+').allMatches(l.substring(1).toLowerCase())) {
          if (hashes.contains(sha256Hex(utf8.encode(w.group(0)!)))) {
            out.add('$file:$line');
            break;
          }
        }
      }
      line++;
    }
  }
  return out;
}
