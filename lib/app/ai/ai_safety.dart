/// What keeps content from the project and from outside — item names and
/// texts, attached files, imported drawings, the project's notes, web pages
/// — from passing for instructions to the AI assistant: the wrappers the
/// app puts around it (`<attachment>`, `<project_data>`, `<project_notes>`…)
/// cannot be closed or forged from inside, the project's notes say where
/// they came from, and the addresses the assistant may fetch without asking
/// even when changes apply automatically.
library;

/// The tags the app wraps content in, in the messages to the model.
const aiWrapperTags = ['attachment', 'project_data', 'project_notes', 'user_marks', 'photo_place', 'user_instructions', 'attachment_page', 'second_opinion', 'question', 'answer'];

final _tagLike = RegExp('<(/?)\\s*(${aiWrapperTags.join('|')})\\b', caseSensitive: false);

/// [s] as the content of a wrapper: anything in it that would open or close
/// one of [aiWrapperTags] is written `‹tag` instead, so the content cannot
/// end its wrapper and pass what follows for the app's own words.
String aiData(String s) => s.replaceAllMapped(_tagLike, (m) => '‹${m.group(1)}${m.group(2)}');

/// [s] as the value of an attribute of a wrapper (`name="…"`).
String aiAttr(String s) => s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll(RegExp(r'[\r\n]+'), ' ');

/// The host of [url], or the URL itself when it has none.
String aiHost(String url) {
  final u = Uri.tryParse(url.trim());
  return u == null || u.host.isEmpty ? url.trim() : u.host;
}

/// Addresses of catalogue packs the assistant fetches without asking when
/// changes apply automatically: the program's own site and repository.
/// Any other address is confirmed by the user, whatever the mode (it could
/// carry data out in its query, or bring in instructions).
bool aiKnownPackUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || u.scheme != 'https') return false;
  final h = u.host.toLowerCase();
  if (h == 'opencadirrigation.com' || h.endsWith('.opencadirrigation.com')) return true;
  if (h == 'raw.githubusercontent.com' || h == 'github.com') return u.path.toLowerCase().startsWith('/videjunior/opencadirrigation/');
  return false;
}

/// A short, stable fingerprint of [text] (two polynomial hashes modulo
/// primes, the same on the web and elsewhere: every product stays within
/// the 53 bits a web number holds exactly), for remembering which notes the
/// user wrote or accepted on this device without keeping their text twice.
String aiFingerprint(String text) {
  var a = 7, b = 11;
  for (final c in text.trim().codeUnits) {
    a = (a * 31 + c) % 2147483647;
    b = (b * 131 + c) % 2147483629;
  }
  return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
}
