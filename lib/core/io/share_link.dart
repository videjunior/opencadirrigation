/// Projects shared by a link with no server: the project travels inside the
/// address itself, gzipped and base64url-encoded in the fragment (`#p=…`),
/// the part of an address browsers never send to any server. The receiver
/// opens the link and gets the project in a new tab; nothing is uploaded.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'safe_archive.dart';

/// The page that opens shared links.
const shareLinkBase = 'https://opencadirrigation.com/';

/// Links above this length (characters) may be cut by e-mail and chat apps;
/// the share dialog warns about them.
const shareLinkWarnLength = 60000;

/// Links above this length are refused (browsers cap addresses at about
/// two million characters).
const shareLinkMaxLength = 1800000;

/// Project JSON made fit for a link: embedded pictures, the photos of
/// comments and design results left out (the receiver designs again), in
/// the project and in each of its alternatives.
String shareableProjectJson(Map<String, dynamic> project) {
  Map<String, dynamic> strip(Map<String, dynamic> p) {
    final j = Map<String, dynamic>.of(p)..remove('results');
    j['entities'] = [
      for (final e in (j['entities'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (e['type'] == 'image') (Map<String, dynamic>.of(e)..remove('data')) else if (e['type'] == 'comment' && e.containsKey('photo')) (Map<String, dynamic>.of(e)..remove('photo')) else e,
    ];
    return j;
  }

  final j = strip(project);
  // 1.6.0 MOD: the alternatives carry a copy of the project
  if (j['scenarios'] is List) {
    j['scenarios'] = [
      for (final s in j['scenarios'] as List)
        if (s is Map && s['project'] is Map) {...s.cast<String, dynamic>(), 'project': strip((s['project'] as Map).cast<String, dynamic>())} else s,
    ];
  }
  return jsonEncode(j);
}

/// The link that carries [projectJson].
String shareLinkFor(String projectJson, {String base = shareLinkBase}) {
  final packed = base64Url.encode(const GZipEncoder().encodeBytes(utf8.encode(projectJson))).replaceAll('=', '');
  return '$base#p=$packed';
}

/// Most bytes the project of a link may expand to: far above any project
/// that fits in a link (pictures and results are left out of them), far
/// below what would stop a browser tab. A link carrying more (a "gzip
/// bomb") is refused as damaged.
const shareLinkMaxProjectBytes = 20 * 1024 * 1024;

/// The project JSON a link (or its fragment) carries; null when it has
/// none, it is damaged or it expands beyond [shareLinkMaxProjectBytes].
String? projectJsonFromLink(String linkOrFragment, {int maxBytes = shareLinkMaxProjectBytes}) {
  final i = linkOrFragment.indexOf('p=');
  if (i < 0 || (i > 0 && !'#&'.contains(linkOrFragment[i - 1]))) return null;
  var data = linkOrFragment.substring(i + 2);
  final end = data.indexOf('&');
  if (end >= 0) data = data.substring(0, end);
  // no longer than the sender accepts
  if (data.length > shareLinkMaxLength) return null;
  try {
    final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
    return utf8.decode(gunzipCapped(base64Url.decode(padded), maxBytes: maxBytes));
  } catch (_) {
    return null;
  }
}
