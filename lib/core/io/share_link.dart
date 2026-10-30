/// Projects shared by a link with no server: the project travels inside the
/// address itself, gzipped and base64url-encoded in the fragment (`#p=…`),
/// the part of an address browsers never send to any server. The receiver
/// opens the link and gets the project in a new tab; nothing is uploaded.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

/// The page that opens shared links.
const shareLinkBase = 'https://opencadirrigation.com/';

/// Links above this length (characters) may be cut by e-mail and chat apps;
/// the share dialog warns about them.
const shareLinkWarnLength = 60000;

/// Links above this length are refused (browsers cap addresses at about
/// two million characters).
const shareLinkMaxLength = 1800000;

/// Project JSON made fit for a link: embedded pictures, the photos of
/// comments and design results left out (the receiver designs again).
String shareableProjectJson(Map<String, dynamic> project) {
  final j = Map<String, dynamic>.of(project)..remove('results');
  j['entities'] = [
    for (final e in (j['entities'] as List? ?? const []).cast<Map<String, dynamic>>())
      if (e['type'] == 'image') (Map<String, dynamic>.of(e)..remove('data')) else if (e['type'] == 'comment' && e.containsKey('photo')) (Map<String, dynamic>.of(e)..remove('photo')) else e,
  ];
  return jsonEncode(j);
}

/// The link that carries [projectJson].
String shareLinkFor(String projectJson, {String base = shareLinkBase}) {
  final packed = base64Url.encode(const GZipEncoder().encodeBytes(utf8.encode(projectJson))).replaceAll('=', '');
  return '$base#p=$packed';
}

/// The project JSON a link (or its fragment) carries; null when it has
/// none or it is damaged.
String? projectJsonFromLink(String linkOrFragment) {
  final i = linkOrFragment.indexOf('p=');
  if (i < 0 || (i > 0 && !'#&'.contains(linkOrFragment[i - 1]))) return null;
  var data = linkOrFragment.substring(i + 2);
  final end = data.indexOf('&');
  if (end >= 0) data = data.substring(0, end);
  try {
    final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
    return utf8.decode(const GZipDecoder().decodeBytes(base64Url.decode(padded)));
  } catch (_) {
    return null;
  }
}
