/// Translation review files for native speakers: every text of a language in
/// a spreadsheet beside its English source, with notes from the glossary and
/// from the checks of the tests, and the import of the reviewed file back
/// into the language pack.
///
/// ```
/// dart run tool/i18n_review.dart export <code>|all [--out <dir>] [--format csv|xlsx] [--packs <dir>]
/// dart run tool/i18n_review.dart import <file> [--lang <code>] [--dry-run] [--force-partial] [--packs <dir>]
/// ```
///
/// The export writes `i18n-review-<code>.csv` (RFC 4180, UTF-8 with a byte
/// order mark) or `.xlsx` into `build/i18n_review/` for one language, or for
/// every language but English (the source) with `all`. The import checks each
/// review (placeholders, texts the glossary keeps in English, words it
/// avoids, unknown keys) and writes the accepted ones into
/// `assets/i18n/<code>.json` in place: the rest of the file stays byte for
/// byte. Portuguese and Spanish are compiled into the app, so their changes
/// are listed to apply by hand. The workflow is described in
/// docs/manual/languages-and-site.md.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:opencadirrigation/app/i18n.dart' show I18n, baseLanguages, languageNames, supportedLanguages;
import 'package:opencadirrigation/core/io/safe_archive.dart' show openZip, zipEntryBytes;
import 'package:opencadirrigation/core/io/xlsx.dart' show XlsxReader, XlsxSheet, XlsxWriter;

/// The sections of a language pack, in the order of the file.
const reviewSections = ['strings', 'tutorial', 'catalog'];

/// The columns of a review file; the header names `current` as `current (<code>)`.
const reviewColumns = ['status', 'section', 'key', 'english', 'current', 'review', 'comment', 'notes', 'context', 'order'];

/// Where the export writes when no `--out` is given.
const defaultReviewDir = 'build/i18n_review';

/// The terminology rules, and the sources of the tutorial and catalogue texts.
const glossaryPath = 'tool/i18n/glossary.json', tutorialSource = 'lib/app/tutorial/tutorial.dart', catalogSource = 'lib/core/model/catalog.dart';

/// The languages a review is for: all but English, the source.
final reviewLanguages = [
  for (final l in supportedLanguages)
    if (l != 'en') l,
];

/// The name of the file the export writes for [lang].
String reviewFileName(String lang, {String format = 'csv'}) => 'i18n-review-$lang.$format';

/// What the second sheet of a review workbook tells the reviewer.
const reviewInstructions = [
  'Write a text in the review column only where the current translation is missing, wrong or can be better; leave the other rows empty.',
  'Do not change the section, key and english columns: the import finds each row by its section and key. Sorting and filtering are fine.',
  'Keep every placeholder in braces, such as {n}, exactly as in English: the program replaces it with a number or a name.',
  'status: missing (no translation yet: the program shows English), fix (breaks a rule, see the notes), provisional (the English text changed), '
      'same-as-english, translated, may-stay-english (an acronym or a method name), keep-english (a name or a symbol that must stay as in English).',
  'notes: the glossary term to use and the words to avoid, why a text may or must stay in English, the placeholders to keep. '
      'context: where the text appears. order: sort by it to read the texts in the order of the program.',
  'comment: anything for the maintainers (a doubt, a question about the meaning).',
  'Save the file as XLSX (or as CSV UTF-8) and send it back.',
];

/// The help of the command line.
const reviewUsage = '''usage:
  dart run tool/i18n_review.dart export <code>|all [--out <dir>] [--format csv|xlsx] [--packs <dir>]
  dart run tool/i18n_review.dart import <file> [--lang <code>] [--dry-run] [--force-partial] [--packs <dir>]

export  writes i18n-review-<code>.csv (or .xlsx) into build/i18n_review (or --out) for one
        language, or for every language but English (the source) with "all"
import  checks a reviewed CSV or XLSX file and writes its reviews into assets/i18n/<code>.json
        (or --packs); nothing is written when a review is refused, unless --force-partial;
        --dry-run only reports. Portuguese and Spanish are compiled into the app: their
        changes are listed to apply by hand.
exit status: 0 done, 1 a review was refused, 2 a usage or file error''';

// ---------------------------------------------------------------- glossary

/// [word] as a whole word in any case, as test/core/i18n_glossary_test.dart
/// looks for the avoided words; with [plural], also followed by "s" or "es".
RegExp wholeWord(String word, {bool plural = false}) => RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(word)}${plural ? '(?:e?s)?' : ''}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);

/// One name per concept in a language (the `terms` of the glossary).
class GlossaryTerm {
  GlossaryTerm({required this.concept, required this.use, this.avoid = const []}) : _concept = wholeWord(concept, plural: true), _avoid = [for (final w in avoid) wholeWord(w)];

  /// The English word of the concept ("submain").
  final String concept;

  /// The term the language uses for it.
  final String use;

  /// Words a text of the language must not use.
  final List<String> avoid;

  final RegExp _concept;
  final List<RegExp> _avoid;

  /// Whether the English text [english] names the concept (also in the plural).
  bool namedIn(String english) => _concept.hasMatch(english);

  /// The avoided words that [text] uses.
  List<String> avoidedIn(String text) => [
    for (var i = 0; i < avoid.length; i++)
      if (_avoid[i].hasMatch(text)) avoid[i],
  ];
}

/// The terminology rules of `tool/i18n/glossary.json`, which
/// test/core/i18n_glossary_test.dart applies to every language.
class Glossary {
  Glossary({
    this.untranslatable = const {},
    this.sameAsEnglishAllowed = const {},
    this.provisionalEnglish = const {},
    this.perLanguageAllowed = const {},
    this.maxSameAsEnglish = const {},
    this.terms = const {},
  });

  factory Glossary.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(String name) => j[name] is Map ? (j[name] as Map).cast<String, dynamic>() : const {};
    Map<String, String> reasons(String name) => {for (final e in map(name).entries) e.key: '${e.value}'};
    return Glossary(
      untranslatable: reasons('untranslatable'),
      sameAsEnglishAllowed: reasons('sameAsEnglishAllowed'),
      provisionalEnglish: reasons('provisionalEnglish'),
      perLanguageAllowed: {
        for (final e in map('perLanguageAllowed').entries) e.key: {for (final k in e.value as List) '$k'},
      },
      maxSameAsEnglish: {for (final e in map('maxSameAsEnglish').entries) e.key: (e.value as num).toInt()},
      terms: {
        for (final e in map('terms').entries)
          e.key: [
            for (final t in (e.value as List).cast<Map<String, dynamic>>())
              GlossaryTerm(
                concept: '${t['concept']}',
                use: '${t['use']}',
                avoid: [for (final w in (t['avoid'] as List?) ?? const []) '$w'],
              ),
          ],
      },
    );
  }

  /// String keys whose text is the same in every language, with the reason.
  final Map<String, String> untranslatable;

  /// String keys a pack may leave in English, with the reason.
  final Map<String, String> sameAsEnglishAllowed;

  /// String keys whose English text changed and whose packs show English until the next pass.
  final Map<String, String> provisionalEnglish;

  /// Language → string keys that stay as in English there on purpose.
  final Map<String, Set<String>> perLanguageAllowed;

  /// The Latin-script packs → how many strings may read as in English; a language without a
  /// limit (a non-Latin script) shows no English text but those the lists allow.
  final Map<String, int> maxSameAsEnglish;

  /// Language → one name per concept.
  final Map<String, List<GlossaryTerm>> terms;

  /// Whether the string [key] may read as in English in [lang] (the lists the glossary test accepts).
  bool mayStayEnglish(String lang, String key) =>
      untranslatable.containsKey(key) || sameAsEnglishAllowed.containsKey(key) || provisionalEnglish.containsKey(key) || (perLanguageAllowed[lang]?.contains(key) ?? false);

  /// Why the string [key] may stay in English in [lang], or null when a translation is expected.
  String? englishAllowed(String lang, String key) => sameAsEnglishAllowed[key] ?? ((perLanguageAllowed[lang]?.contains(key) ?? false) ? 'kept in English in this language' : null);

  /// The terms of [lang] whose concept the English text [english] names.
  List<GlossaryTerm> termsIn(String lang, String english) => [
    for (final t in terms[lang] ?? const <GlossaryTerm>[])
      if (t.namedIn(english)) t,
  ];
}

// ---------------------------------------------------------------- sources

/// What a review needs from the repository: the glossary, the English source
/// of every entry of a pack and the texts compiled into the app.
class ReviewContext {
  ReviewContext({required this.glossary, required this.english, this.compiled = const {}, this.definedIn = const {}, this.usedIn = const {}});

  /// Reads the glossary, the string table and the tutorial and catalogue
  /// sources of the repository at [root].
  factory ReviewContext.load({String root = '.'}) {
    String read(String path) => File('$root/$path').readAsStringSync();
    final keys = I18n.keys.toList();
    final en = I18n('en'), pt = I18n('pt'), es = I18n('es');
    final tutorial = dartTextCalls(read(tutorialSource), 't|_T');
    final catalog = dartTextCalls(read(catalogSource), 'n');
    // English source → the text of one column, the first call of each source winning
    Map<String, String> column(List<(String, String, String)> calls, String Function((String, String, String) c) pick) {
      final out = <String, String>{};
      for (final c in calls) {
        out.putIfAbsent(c.$2, () => pick(c));
      }
      return out;
    }

    final definedIn = <String, String>{};
    final tuple = RegExp(r"^\s*'([^'\\]+)'\s*:\s*\(", multiLine: true);
    for (final path in ['lib/app/i18n.dart', ..._dartFiles(root, 'lib/app/i18n_parts')]) {
      for (final m in tuple.allMatches(read(path))) {
        definedIn.putIfAbsent(m.group(1)!, () => path);
      }
    }
    final known = keys.toSet();
    final literal = RegExp(r"'([A-Za-z0-9_.]+)'");
    final usedIn = <String, List<String>>{};
    for (final path in _dartFiles(root, 'lib')) {
      if (path == 'lib/app/i18n.dart' || path.startsWith('lib/app/i18n_parts/')) continue;
      for (final k in {for (final m in literal.allMatches(read(path))) m.group(1)!}) {
        if (known.contains(k)) (usedIn[k] ??= []).add(path);
      }
    }
    return ReviewContext(
      glossary: Glossary.fromJson(jsonDecode(read(glossaryPath)) as Map<String, dynamic>),
      english: {
        'strings': {for (final k in keys) k: en(k)},
        'tutorial': column(tutorial, (c) => c.$2),
        'catalog': column(catalog, (c) => c.$2),
      },
      compiled: {
        'pt': {'strings': {for (final k in keys) k: pt(k)}, 'tutorial': column(tutorial, (c) => c.$1), 'catalog': column(catalog, (c) => c.$1)},
        'es': {'strings': {for (final k in keys) k: es(k)}, 'tutorial': column(tutorial, (c) => c.$3), 'catalog': column(catalog, (c) => c.$3)},
      },
      definedIn: definedIn,
      usedIn: usedIn,
    );
  }

  final Glossary glossary;

  /// Section → key → English text, in the order of the program: the string
  /// table, then the tutorial and catalogue texts (keyed by their English
  /// text) in the order of their sources.
  final Map<String, Map<String, String>> english;

  /// The compiled languages (pt, es) → section → key → text.
  final Map<String, Map<String, Map<String, String>>> compiled;

  /// String key → the Dart file of the table that defines it.
  final Map<String, String> definedIn;

  /// String key → the files of lib/ that name it (the context column).
  final Map<String, List<String>> usedIn;

  /// The same sources with another glossary (tests).
  ReviewContext withGlossary(Glossary g) => ReviewContext(glossary: g, english: english, compiled: compiled, definedIn: definedIn, usedIn: usedIn);
}

/// The Dart files under [dir] of the repository at [root], as '/'-separated
/// paths from the root, sorted.
List<String> _dartFiles(String root, String dir) {
  final d = Directory('$root/$dir');
  if (!d.existsSync()) return const [];
  final skip = d.path.length + 1;
  return [
    for (final f in d.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart')) '$dir/${f.path.substring(skip).replaceAll(r'\', '/')}',
  ]..sort();
}

/// The `fn('pt', 'en', 'es')` calls of a Dart [source] as the tests find them
/// (a trailing comma allowed; [fn] is a pattern such as `t|_T`), with their
/// strings unescaped, as (pt, en, es) in the order of the source.
List<(String, String, String)> dartTextCalls(String source, String fn) {
  const str = r"'((?:[^'\\]|\\.)*)'";
  final re = RegExp('(?<![\\w.])(?:$fn)\\(\\s*$str\\s*,\\s*$str\\s*,\\s*$str\\s*,?\\s*\\)', dotAll: true);
  return [for (final m in re.allMatches(source)) (unescapeDart(m.group(1)!), unescapeDart(m.group(2)!), unescapeDart(m.group(3)!))];
}

/// The value of [body], the inside of a single-quoted Dart string literal.
String unescapeDart(String body) {
  if (!body.contains(r'\')) return body;
  final b = StringBuffer();
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c != r'\' || i + 1 == body.length) {
      b.write(c);
      continue;
    }
    i++;
    switch (body[i]) {
      case 'n':
        b.write('\n');
      case 'r':
        b.write('\r');
      case 't':
        b.write('\t');
      case 'x' when i + 2 < body.length:
        b.writeCharCode(int.parse(body.substring(i + 1, i + 3), radix: 16));
        i += 2;
      case 'u' when i + 1 < body.length && body[i + 1] == '{':
        final end = body.indexOf('}', i);
        b.writeCharCode(int.parse(body.substring(i + 2, end), radix: 16));
        i = end;
      case 'u' when i + 4 < body.length:
        b.writeCharCode(int.parse(body.substring(i + 1, i + 5), radix: 16));
        i += 4;
      default:
        b.write(body[i]);
    }
  }
  return b.toString();
}

/// The sections of the pack JSON [text] (`assets/i18n/<code>.json`); a
/// section the file lacks is empty.
Map<String, Map<String, String>> packSections(String text) {
  final j = jsonDecode(text) as Map<String, dynamic>;
  Map<String, String> section(Object? s) => {
    if (s is Map)
      for (final e in s.entries)
        if (e.value is String) '${e.key}': e.value as String,
  };
  return {for (final s in reviewSections) s: section(j[s])};
}

// ---------------------------------------------------------------- export

/// What a row needs, most urgent first (the order of the exported rows).
enum ReviewStatus {
  /// No translation: the program shows the English text.
  missing('missing'),

  /// The translation breaks a rule: a placeholder, a word the glossary avoids, a text that must stay in English.
  fix('fix'),

  /// The English text changed, and the translation waits for the next pass.
  provisional('provisional'),

  /// The same as English where a translation is expected.
  sameAsEnglish('same-as-english'),

  /// Translated: read it and correct it if needed.
  translated('translated'),

  /// The same as English, which the glossary allows (an acronym, a method name…).
  mayStayEnglish('may-stay-english'),

  /// A name, a symbol or a formula that reads the same in every language.
  keepEnglish('keep-english');

  const ReviewStatus(this.label);

  /// The word in the status column.
  final String label;
}

/// One text to review.
class ReviewRow {
  ReviewRow({required this.status, required this.section, required this.key, required this.english, required this.current, required this.notes, this.context = '', this.order = 0});

  final ReviewStatus status;
  final String section;

  /// The string key, or the English text for the tutorial and the catalogue.
  final String key;
  final String english;

  /// The translation the language has, or null when it has none.
  final String? current;

  /// What the glossary and the checks say about this text, as sentences.
  final List<String> notes;

  /// Where the text appears.
  final String context;

  /// The position in the program (1: the first string of the table), to sort the rows back.
  final int order;

  /// The cells of the row, in the order of [reviewColumns] (review and comment empty).
  List<String> get cells => [status.label, section, key, english, current ?? '', '', '', notes.join(' '), context, '$order'];
}

/// The rows of the review of [lang]: one per entry of the English source,
/// with the current translation from [pack] (the sections of
/// `assets/i18n/<lang>.json`) or, for Portuguese and Spanish, from the
/// compiled texts; the most urgent first, then in the order of the program.
List<ReviewRow> reviewRows(String lang, ReviewContext ctx, {Map<String, Map<String, String>>? pack}) {
  final have = pack ?? ctx.compiled[lang] ?? const <String, Map<String, String>>{};
  final rows = <ReviewRow>[];
  var order = 0;
  for (final section in reviewSections) {
    final source = ctx.english[section] ?? const <String, String>{};
    final current = have[section] ?? const <String, String>{};
    // entries whose English source is gone: the old translation of a changed text helps the new one
    final obsolete = {
      for (final e in current.entries)
        if (!source.containsKey(e.key)) e.key: e.value,
    };
    for (final e in source.entries) {
      rows.add(_row(lang, section, e.key, e.value, current[e.key], ++order, ctx, obsolete));
    }
  }
  rows.sort((a, b) => a.status != b.status ? a.status.index - b.status.index : a.order - b.order);
  return rows;
}

ReviewRow _row(String lang, String section, String key, String english, String? current, int order, ReviewContext ctx, Map<String, String> obsolete) {
  final g = ctx.glossary;
  final strings = section == 'strings';
  final fixed = strings ? g.untranslatable[key] : null;
  final allowed = strings ? g.englishAllowed(lang, key) : null;
  final provisional = strings ? g.provisionalEnglish[key] : null;
  final translation = current == null || current.trim().isEmpty ? null : current;
  final problems = translation == null ? const <String>[] : reviewProblems(lang, section, key, english, translation, g);
  final ReviewStatus status;
  if (translation == null) {
    status = ReviewStatus.missing;
  } else if (problems.isNotEmpty) {
    status = ReviewStatus.fix;
  } else if (provisional != null) {
    status = ReviewStatus.provisional;
  } else if (fixed != null) {
    status = ReviewStatus.keepEnglish;
  } else if (translation == english) {
    status = allowed == null ? ReviewStatus.sameAsEnglish : ReviewStatus.mayStayEnglish;
  } else {
    status = ReviewStatus.translated;
  }
  final marks = placeholders(english);
  final previous = translation == null && !strings ? _closest(key, obsolete.keys) : null;
  final latin = g.maxSameAsEnglish.containsKey(lang) || baseLanguages.contains(lang);
  final notes = [
    if (status == ReviewStatus.missing) 'Missing: the program shows the English text.',
    ...problems,
    if (status == ReviewStatus.sameAsEnglish) 'Same as English: translate it${latin ? ', unless the English word is the usual one in this language' : ''}.',
    if (fixed != null && status == ReviewStatus.keepEnglish) 'Keep it exactly as in English ($fixed): leave the review empty.',
    if (allowed != null) 'May stay in English ($allowed).',
    if (provisional != null) 'Provisional: the English text changed, and the program shows it in English until the translation is updated ($provisional).',
    for (final t in g.termsIn(lang, english)) 'Glossary: “${t.concept}” is “${t.use}”${t.avoid.isEmpty ? '' : ', never ${t.avoid.map((w) => '“$w”').join(', ')}'}.',
    if (marks.isNotEmpty) 'Keep ${marks.join(', ')} as in English: the program fills ${marks.length == 1 ? 'it' : 'them'} in.',
    if (english.contains('\n')) 'Keep the line breaks.',
    if (previous != null) 'The English text changed; the previous translation was “${obsolete[previous]}”.',
  ];
  return ReviewRow(status: status, section: section, key: key, english: english, current: current, notes: notes, context: _context(section, ctx.usedIn[key]), order: order);
}

/// Where a text appears: the tutorial, the catalogue, or the files that show
/// a string (the widgets first, the assistant's last).
String _context(String section, List<String>? files) {
  if (section == 'tutorial') return 'interactive tutorial';
  if (section == 'catalog') return 'default catalogue';
  if (files == null || files.isEmpty) return '';
  int rank(String f) => f.startsWith('lib/app/widgets/') ? 0 : (f.startsWith('lib/app/ai/') ? 2 : 1);
  final sorted = [...files]..sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.compareTo(b));
  final names = {for (final f in sorted) f.split('/').last.replaceAll('.dart', '').replaceAll('_', ' ')}.toList();
  final more = names.length > 3 ? ' (+${names.length - 3} more)' : '';
  return 'shown in: ${names.take(3).join(', ')}$more';
}

/// The candidate most like [text] (the same beginning and end), when at
/// least 60 % of it is alike.
String? _closest(String text, Iterable<String> candidates) {
  String? best;
  var score = 0.0;
  for (final c in candidates) {
    final n = math.min(text.length, c.length);
    var head = 0, tail = 0;
    while (head < n && text.codeUnitAt(head) == c.codeUnitAt(head)) {
      head++;
    }
    while (tail < n - head && text.codeUnitAt(text.length - 1 - tail) == c.codeUnitAt(c.length - 1 - tail)) {
      tail++;
    }
    final s = (head + tail) / math.max(text.length, c.length);
    if (s > score) {
      best = c;
      score = s;
    }
  }
  return score >= 0.6 ? best : null;
}

/// What breaks the rules in [text], a translation into [lang] of [english]
/// (empty when nothing does): the placeholders must be those of English, a
/// text the glossary keeps in English must read as in English, and no word
/// the glossary avoids in that language may appear.
List<String> reviewProblems(String lang, String section, String key, String english, String text, Glossary glossary) {
  final fixed = section == 'strings' ? glossary.untranslatable[key] : null;
  final want = placeholders(english), got = placeholders(text);
  final lost = want.difference(got), extra = got.difference(want);
  final differ = [if (lost.isNotEmpty) 'missing ${lost.join(' ')}', if (extra.isNotEmpty) 'not in English ${extra.join(' ')}'];
  return [
    if (fixed != null && text != english) 'Must read exactly as in English ($fixed).',
    if (differ.isNotEmpty) 'Placeholders differ from English (${differ.join('; ')}).',
    for (final t in glossary.terms[lang] ?? const <GlossaryTerm>[])
      for (final w in t.avoidedIn(text)) 'Uses “$w”, which the glossary avoids in this language: write “${t.use}”.',
  ];
}

/// The placeholders of [text] (`{n}`, `{name}`…), which the program replaces.
Set<String> placeholders(String text) => {for (final m in _placeholder.allMatches(text)) m.group(0)!};

final _placeholder = RegExp(r'\{[^}]+\}');

/// The header of the review file of [lang].
List<String> reviewHeader(String lang) => [for (final c in reviewColumns) c == 'current' ? 'current ($lang)' : c];

/// The review file of [lang] as a table: the header, then [rows].
List<List<String>> reviewTable(String lang, List<ReviewRow> rows) => [reviewHeader(lang), for (final r in rows) r.cells];

/// The review file of [lang] as an XLSX workbook: the rows on the first
/// sheet (the order as numbers), and a sheet that explains the columns.
Uint8List reviewXlsx(String lang, List<ReviewRow> rows) => XlsxWriter.write([
  XlsxSheet(
    name: lang,
    headers: reviewHeader(lang),
    rows: [
      for (final r in rows) [...r.cells.take(reviewColumns.length - 1), r.order],
    ],
  ),
  XlsxSheet(
    name: 'how to review',
    headers: const ['How to review'],
    rows: [
      for (final line in reviewInstructions) [line],
    ],
  ),
]);

// ---------------------------------------------------------------- CSV and XLSX

/// [table] as RFC 4180 CSV: comma-separated, CRLF between records, a field
/// quoted when it holds a comma, a quote (doubled), a line break or spaces at
/// either end, after the UTF-8 byte order mark that tells spreadsheet
/// programs the encoding (when [bom]).
String toCsv(List<List<String>> table, {bool bom = true}) {
  final b = StringBuffer(bom ? '\uFEFF' : '');
  for (final row in table) {
    b.write(row.map(_csvField).join(','));
    b.write('\r\n');
  }
  return b.toString();
}

String _csvField(String v) => v.contains(_csvSpecial) || v.trim() != v ? '"${v.replaceAll('"', '""')}"' : v;

final _csvSpecial = RegExp('[",\r\n]');

/// The records of the CSV [text], read leniently: a leading byte order mark is
/// skipped, records end with CRLF, LF or CR, and quoted fields may hold
/// separators, doubled quotes and line breaks. The separator is [separator]
/// or the one of the first line: a comma, a semicolon (as spreadsheet
/// programs write in languages with a decimal comma) or a tab.
List<List<String>> parseCsv(String text, {String? separator}) {
  final s = text.startsWith('\uFEFF') ? text.substring(1) : text;
  final sep = (separator ?? _guessSeparator(s)).codeUnitAt(0);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false; // inside the quotes of a field
  var started = false; // the field has begun
  void endField() {
    row.add(field.toString());
    field.clear();
    started = false;
  }

  void endRecord() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (quoted) {
      if (c != 0x22) {
        field.writeCharCode(c);
      } else if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x22) {
        field.writeCharCode(0x22);
        i++;
      } else {
        quoted = false;
      }
    } else if (c == 0x22 && !started) {
      quoted = true;
      started = true;
    } else if (c == sep) {
      endField();
    } else if (c == 0x0D || c == 0x0A) {
      endRecord();
      if (c == 0x0D && i + 1 < s.length && s.codeUnitAt(i + 1) == 0x0A) i++;
    } else {
      field.writeCharCode(c);
      started = true;
    }
  }
  if (quoted) throw const FormatException('a quoted field of the CSV is not closed');
  if (started || row.isNotEmpty) endRecord();
  return rows;
}

/// The separator of the first line of [s]: the most frequent of comma,
/// semicolon and tab outside quotes (a comma when none appears).
String _guessSeparator(String s) {
  final counts = {',': 0, ';': 0, '\t': 0};
  var quoted = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '"') {
      quoted = !quoted;
    } else if (!quoted && (c == '\n' || c == '\r')) {
      break;
    } else if (!quoted && counts.containsKey(c)) {
      counts[c] = counts[c]! + 1;
    }
  }
  var best = ',';
  for (final e in counts.entries) {
    if (e.value > counts[best]!) best = e.key;
  }
  return best;
}

/// The text of a review file: UTF-8, with or without its byte order mark, or
/// UTF-16 with its byte order mark (the "Unicode text" of spreadsheet
/// programs). Any other encoding is refused: guessing a code page would
/// garble the reviews.
String decodeReviewText(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) return _utf16(bytes, littleEndian: true);
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) return _utf16(bytes, littleEndian: false);
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('the file is not UTF-8 text: save it as "CSV UTF-8" (or as XLSX) and import it again');
  }
  return text.startsWith('\uFEFF') ? text.substring(1) : text;
}

/// UTF-16 [bytes] after their byte order mark.
String _utf16(List<int> bytes, {required bool littleEndian}) => String.fromCharCodes([
  for (var i = 2; i + 1 < bytes.length; i += 2) littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1],
]);

/// The table of a review file: the sheet of an XLSX workbook that has the
/// section, key and review columns, or CSV text ([decodeReviewText], [parseCsv]).
List<List<String>> readReviewTable(Uint8List bytes) {
  if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) return _readXlsx(bytes);
  return parseCsv(decodeReviewText(bytes));
}

List<List<String>> _readXlsx(Uint8List bytes) {
  final List<XlsxSheet> sheets;
  try {
    sheets = XlsxReader.read(withoutPhoneticReadings(bytes));
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('not a readable XLSX workbook ($e)');
  }
  // numbers come back as doubles: 12.0 is the 12 the cell shows
  String cell(Object? v) => switch (v) {
    null => '',
    double d when d.isFinite && d == d.roundToDouble() => '${d.round()}',
    _ => '$v',
  };
  for (final s in sheets) {
    final header = [for (final h in s.headers) h.trim().toLowerCase()];
    if (header.contains('section') && header.contains('key') && header.contains('review')) {
      return [
        s.headers,
        for (final r in s.rows) [for (final v in r) cell(v)],
      ];
    }
  }
  throw const FormatException('no sheet of the workbook has the section, key and review columns');
}

/// The workbook [bytes] without the phonetic readings (`rPh`) that a
/// spreadsheet program keeps beside texts typed in Japanese: the reader of
/// lib/core/io/xlsx.dart joins every text run of a shared string, so a
/// reading would be glued to the review.
Uint8List withoutPhoneticReadings(Uint8List bytes) {
  final zip = openZip(bytes);
  final shared = zip.files.where((f) => f.isFile && (f.name == 'xl/sharedStrings.xml' || f.name == '/xl/sharedStrings.xml')).firstOrNull;
  if (shared == null) return bytes;
  final xml = utf8.decode(zipEntryBytes(shared), allowMalformed: true);
  final clean = xml.replaceAll(_phonetic, '');
  if (clean == xml) return bytes;
  final out = Archive();
  for (final f in zip.files) {
    if (!f.isFile) continue;
    out.addFile(identical(f, shared) ? ArchiveFile.string(f.name, clean) : ArchiveFile.bytes(f.name, zipEntryBytes(f)));
  }
  return ZipEncoder().encodeBytes(out);
}

final _phonetic = RegExp(r'<(?:\w+:)?rPh\b[^>]*?(?:/>|>.*?</(?:\w+:)?rPh>)', dotAll: true);

// ---------------------------------------------------------------- import

/// One row of a reviewed file.
class ReviewEntry {
  const ReviewEntry({required this.section, required this.key, required this.review, this.english, this.current, this.comment = '', this.row = 0});

  final String section;
  final String key;

  /// The reviewer's text (empty: no review).
  final String review;

  /// The English and the current text as exported, when the file still has those columns.
  final String? english;
  final String? current;

  /// The reviewer's comment.
  final String comment;

  /// The row in the spreadsheet (1: the header).
  final int row;
}

/// A reviewed file: its rows and the language its header names, if any.
class ReviewInput {
  const ReviewInput(this.entries, {this.lang});

  final List<ReviewEntry> entries;

  /// The code of the `current (<code>)` column.
  final String? lang;
}

/// The rows of [table], a review file read by [readReviewTable]: the columns
/// are found by their header, so the reviewer may move them, and the line
/// breaks of a cell become LF.
ReviewInput reviewEntries(List<List<String>> table) {
  if (table.isEmpty) throw const FormatException('the file is empty');
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  final section = header.indexOf('section'), key = header.indexOf('key'), review = header.indexOf('review');
  if (section < 0 || key < 0 || review < 0) throw const FormatException('the first row does not name the section, key and review columns: export the file again');
  final english = header.indexOf('english'), comment = header.indexOf('comment');
  var current = -1;
  String? lang;
  for (final (i, h) in header.indexed) {
    final m = RegExp(r'^current\s*\(\s*([a-z]{2,3})\s*\)$').firstMatch(h);
    if (m != null) {
      current = i;
      lang = m.group(1);
    }
  }
  String cell(List<String> row, int i) => i >= 0 && i < row.length ? _lines(row[i]) : '';
  final entries = <ReviewEntry>[];
  for (final (i, row) in table.indexed.skip(1)) {
    if (row.every((c) => c.trim().isEmpty)) continue;
    entries.add(
      ReviewEntry(
        section: cell(row, section).trim(),
        key: cell(row, key).trim(),
        review: cell(row, review),
        english: english < 0 ? null : cell(row, english),
        current: current < 0 ? null : cell(row, current),
        comment: cell(row, comment).trim(),
        row: i + 1,
      ),
    );
  }
  return ReviewInput(entries, lang: lang);
}

/// A text a review changes.
class ReviewChange {
  const ReviewChange(this.section, this.key, this.from, this.to);

  final String section;
  final String key;

  /// The current text, or null when the language has none (the key is added).
  final String? from;
  final String to;
}

/// A review the import refuses, and why.
class ReviewRejection {
  const ReviewRejection(this.entry, this.reasons);

  final ReviewEntry entry;
  final List<String> reasons;
}

/// What the import of a review does: the changes to write, the rows refused
/// with their reasons, the warnings and the reviewer's comments.
class ImportResult {
  ImportResult(this.lang);

  final String lang;
  final changes = <ReviewChange>[];
  final rejected = <ReviewRejection>[];
  final warnings = <String>[];
  final comments = <ReviewEntry>[];

  /// Reviews equal to the current text.
  var unchanged = 0;

  /// Rows with an empty review.
  var withoutReview = 0;
}

/// Checks the reviewed [entries] of [lang] against the English source and
/// the glossary, and works out the changes to the current texts: [pack] (the
/// sections of `assets/i18n/<lang>.json`) or, for Portuguese and Spanish, the
/// compiled ones. A review is refused when its placeholders are not those of
/// English, when it changes a text the glossary keeps in English, when it
/// uses a word the glossary avoids in that language, when it names a section
/// or a key the program does not have (nothing is ever added that the
/// English source lacks), when the same row is reviewed twice with different
/// texts, and, in a pack, when it leaves a text in English where the glossary
/// test expects a translation. Spaces around a review are dropped.
ImportResult applyReview(String lang, List<ReviewEntry> entries, ReviewContext ctx, {Map<String, Map<String, String>>? pack}) {
  final g = ctx.glossary;
  final have = pack ?? ctx.compiled[lang] ?? const <String, Map<String, String>>{};
  final result = ImportResult(lang);
  String id(ReviewEntry e) => '${e.section}\n${e.key}';
  final reviews = <String, Set<String>>{}; // the reviews of each row
  for (final e in entries) {
    final review = e.review.trim();
    if (review.isNotEmpty) (reviews[id(e)] ??= {}).add(review);
  }
  final keptEnglish = <(ReviewChange, ReviewEntry)>[]; // strings of a Latin-script pack set to their English text
  for (final e in entries) {
    if (e.comment.isNotEmpty) result.comments.add(e);
    if (e.review.trim().isEmpty) {
      result.withoutReview++;
      continue;
    }
    if (!reviewSections.contains(e.section)) {
      result.rejected.add(ReviewRejection(e, ['Unknown section “${e.section}”: the sections are ${reviewSections.join(', ')}.']));
      continue;
    }
    final english = ctx.english[e.section]?[e.key];
    if (english == null) {
      result.rejected.add(ReviewRejection(e, ['Unknown key: the program has no such text, and the import adds none.']));
      continue;
    }
    if (reviews[id(e)]!.length > 1) {
      result.rejected.add(ReviewRejection(e, ['The row is reviewed more than once, with different texts.']));
      continue;
    }
    final review = english == english.trim() ? e.review.trim() : e.review;
    final current = have[e.section]?[e.key];
    final exportedEnglish = e.english, exportedCurrent = e.current;
    if (exportedEnglish != null && exportedEnglish.isNotEmpty && _squash(exportedEnglish) != _squash(english)) {
      result.warnings.add('${_where(e)}: the English text changed since the export; it now reads “$english”.');
    }
    if (exportedCurrent != null && _squash(exportedCurrent) != _squash(current ?? '')) {
      result.warnings.add('${_where(e)}: the translation changed since the export; the review replaces “${current ?? ''}”.');
    }
    if (review == current) {
      result.unchanged++;
      continue;
    }
    final reasons = reviewProblems(lang, e.section, e.key, english, review, g);
    final change = ReviewChange(e.section, e.key, current, review);
    final strings = e.section == 'strings';
    if (reasons.isEmpty && pack != null && strings && review == english && !g.mayStayEnglish(lang, e.key)) {
      if (g.maxSameAsEnglish.containsKey(lang)) {
        keptEnglish.add((change, e));
      } else {
        reasons.add('Same as English: in this language the glossary keeps in English only the texts it lists (tool/i18n/glossary.json).');
      }
    }
    if (reasons.isNotEmpty) {
      result.rejected.add(ReviewRejection(e, reasons));
      continue;
    }
    result.changes.add(change);
    if (strings && g.provisionalEnglish.containsKey(e.key)) {
      result.warnings.add('${e.key} is provisional in tool/i18n/glossary.json: remove it there once every language has its translation.');
    }
  }
  if (keptEnglish.isNotEmpty) {
    // the glossary test counts the strings equal to English that no list allows
    final limit = g.maxSameAsEnglish[lang]!;
    final english = ctx.english['strings'] ?? const <String, String>{};
    final after = {...?have['strings']};
    for (final c in result.changes) {
      if (c.section == 'strings') after[c.key] = c.to;
    }
    final count = after.entries.where((e) => english[e.key] == e.value && !g.mayStayEnglish(lang, e.key)).length;
    if (count > limit) {
      for (final (change, entry) in keptEnglish) {
        result.changes.remove(change);
        result.rejected.add(
          ReviewRejection(entry, [
            'Same as English: the pack would have $count texts equal to English, more than its maxSameAsEnglish ($limit) in tool/i18n/glossary.json; '
                'translate it, or list the key under perLanguageAllowed.',
          ]),
        );
      }
    }
  }
  return result;
}

String _lines(String s) => s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _short(String s) {
  final one = s.replaceAll('\n', ' ');
  return one.length <= 60 ? one : '${one.substring(0, 57)}…';
}

String _where(ReviewEntry e) => 'row ${e.row} (${e.section} ${_short(e.key)})';

String _count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

// ---------------------------------------------------------------- the pack file

/// [text] (an `assets/i18n/<code>.json` file) with [changes] applied in
/// place: a changed text is replaced where it stands, and a key the pack
/// lacks is inserted after the closest key before it in the program ([order]:
/// section → keys in the order of the program), with the separators of its
/// neighbours. Everything else stays byte for byte (indentation, key order,
/// escapes, the end of the file), so a review is a minimal diff.
String applyChangesToPack(String text, List<ReviewChange> changes, Map<String, Map<String, String>> order) {
  final want = packSections(text);
  for (final c in changes) {
    (want[c.section] ??= {})[c.key] = c.to;
  }
  final scanner = _JsonScanner(text);
  final top = scanner.objectAt(scanner.space(0));
  final edits = <_Edit>[];
  for (final section in reviewSections) {
    final mine = [
      for (final c in changes)
        if (c.section == section) c,
    ];
    if (mine.isEmpty) continue;
    final holder = top.members.where((m) => m.key == section).firstOrNull;
    if (holder == null || text.codeUnitAt(holder.valueStart) != 0x7B) throw FormatException('the pack has no "$section" section');
    final object = scanner.objectAt(holder.valueStart);
    final members = object.members;
    final index = {for (final (i, m) in members.indexed) m.key: i};
    final program = order[section]?.keys.toList() ?? const <String>[];
    final position = {for (final (i, k) in program.indexed) k: i};
    int place(String key) => position[key] ?? program.length;
    final added = <int, List<ReviewChange>>{}; // the member they follow (-1: before the first) → new keys
    for (final c in mine) {
      final i = index[c.key];
      if (i != null) {
        edits.add(_Edit(members[i].valueStart, members[i].valueEnd, jsonEncode(c.to)));
        continue;
      }
      var after = -1;
      for (var p = place(c.key) - 1; p >= 0; p--) {
        final j = index[program[p]];
        if (j != null) {
          after = j;
          break;
        }
      }
      (added[after] ??= []).add(c);
    }
    if (added.isEmpty) continue;
    for (final list in added.values) {
      list.sort((a, b) => place(a.key) - place(b.key));
    }
    final colon = members.isEmpty ? ': ' : text.substring(members.first.keyEnd, members.first.valueStart);
    String entry(ReviewChange c) => '${jsonEncode(c.key)}$colon${jsonEncode(c.to)}';
    if (members.isEmpty) {
      // an empty section: its entries one level deeper than the section
      final indent = _indentBefore(text, holder.start);
      final entries = [for (final c in added[-1]!) entry(c)];
      edits.add(_Edit(holder.valueStart, object.end, indent == null ? '{${entries.join(',')}}' : '{\n$indent$indent${entries.join(',\n$indent$indent')}\n$indent}'));
      continue;
    }
    final between = members.length > 1 ? text.substring(members[0].valueEnd, members[1].start) : ',${text.substring(holder.valueStart + 1, members[0].start)}';
    for (final e in added.entries) {
      if (e.key < 0) {
        edits.add(_Edit(members.first.start, members.first.start, [for (final c in e.value) '${entry(c)}$between'].join()));
      } else {
        final end = members[e.key].valueEnd;
        edits.add(_Edit(end, end, [for (final c in e.value) '$between${entry(c)}'].join()));
      }
    }
  }
  edits.sort((a, b) => a.start - b.start);
  final out = StringBuffer();
  var at = 0;
  for (final e in edits) {
    out.write(text.substring(at, e.start));
    out.write(e.text);
    at = e.end;
  }
  out.write(text.substring(at));
  final result = out.toString();
  // the edited file must read back as the old one with the changes
  final got = packSections(result);
  for (final s in reviewSections) {
    final a = got[s]!, b = want[s] ?? const <String, String>{};
    if (a.length != b.length || a.entries.any((e) => b[e.key] != e.value)) throw StateError('the edited pack does not read back as expected ($s)');
  }
  return result;
}

/// The spaces before [pos] on its line when only spaces precede it there, or
/// null when the text before it is on the same line (a compact file).
String? _indentBefore(String text, int pos) {
  var i = pos;
  while (i > 0 && (text[i - 1] == ' ' || text[i - 1] == '\t')) {
    i--;
  }
  return i > 0 && text[i - 1] == '\n' ? text.substring(i, pos) : null;
}

/// A replacement of `text[start, end)`.
class _Edit {
  _Edit(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

/// A member of a JSON object, by its place in the text.
class _JsonMember {
  _JsonMember(this.key, this.start, this.keyEnd, this.valueStart, this.valueEnd);

  final String key;

  /// The opening quote of the key.
  final int start;

  /// After the closing quote of the key.
  final int keyEnd;
  final int valueStart;

  /// After the value.
  final int valueEnd;
}

/// The members of a JSON object and the end of the object (after its brace).
class _JsonObject {
  _JsonObject(this.members, this.end);

  final List<_JsonMember> members;
  final int end;
}

/// Just enough of a JSON reader to know where each member of an object
/// stands in the text (the text is valid JSON: [packSections] read it first).
class _JsonScanner {
  _JsonScanner(this.text);

  final String text;

  /// The first position from [from] that is not white space.
  int space(int from) {
    var i = from;
    while (i < text.length && _isSpace(text.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09;

  /// After the string whose opening quote is at [from].
  int stringEnd(int from) {
    var i = from + 1;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 0x5C) {
        i += 2;
      } else if (c == 0x22) {
        return i + 1;
      } else {
        i++;
      }
    }
    throw FormatException('a string is not closed', text, from);
  }

  /// After the value that starts at [from].
  int valueEnd(int from) {
    final c = text.codeUnitAt(from);
    if (c == 0x22) return stringEnd(from);
    if (c == 0x7B) return objectAt(from).end;
    if (c == 0x5B) return _arrayEnd(from);
    var i = from;
    while (i < text.length && !_isSpace(text.codeUnitAt(i)) && !',]}'.contains(text[i])) {
      i++;
    }
    if (i == from) throw FormatException('a value was expected', text, from);
    return i;
  }

  int _arrayEnd(int from) {
    var i = space(from + 1);
    if (text.codeUnitAt(i) == 0x5D) return i + 1;
    while (true) {
      i = space(valueEnd(space(i)));
      final c = text.codeUnitAt(i);
      if (c == 0x5D) return i + 1;
      if (c != 0x2C) throw FormatException('a comma or ] was expected', text, i);
      i++;
    }
  }

  /// The object whose opening brace is at [from].
  _JsonObject objectAt(int from) {
    final members = <_JsonMember>[];
    var i = space(from + 1);
    if (text.codeUnitAt(i) == 0x7D) return _JsonObject(members, i + 1);
    while (true) {
      i = space(i);
      if (text.codeUnitAt(i) != 0x22) throw FormatException('a key was expected', text, i);
      final keyEnd = stringEnd(i);
      final colon = space(keyEnd);
      if (text.codeUnitAt(colon) != 0x3A) throw FormatException('a colon was expected', text, colon);
      final valueStart = space(colon + 1);
      final end = valueEnd(valueStart);
      members.add(_JsonMember(jsonDecode(text.substring(i, keyEnd)) as String, i, keyEnd, valueStart, end));
      i = space(end);
      final c = text.codeUnitAt(i);
      if (c == 0x7D) return _JsonObject(members, i + 1);
      if (c != 0x2C) throw FormatException('a comma or } was expected', text, i);
      i++;
    }
  }
}

// ---------------------------------------------------------------- Portuguese and Spanish

/// The [changes] of a compiled language ([lang], pt or es) as a list to apply
/// by hand: for each, the file, the key or the English text, the current and
/// the reviewed text, and the Dart entry or call to paste in its place.
String compiledChangeList(String lang, List<ReviewChange> changes, ReviewContext ctx) {
  final b = StringBuffer();
  for (final c in changes) {
    String text(String l) {
      if (l == lang) return c.to;
      if (l == 'en') return ctx.english[c.section]?[c.key] ?? c.key;
      return ctx.compiled[l]?[c.section]?[c.key] ?? '';
    }

    final tuple = '(${_dartLiteral(text('pt'))}, ${_dartLiteral(text('en'))}, ${_dartLiteral(text('es'))})';
    final (file, what, paste) = switch (c.section) {
      'strings' => (ctx.definedIn[c.key] ?? 'lib/app/i18n.dart', 'key ${c.key}', '${_dartLiteral(c.key)}: $tuple,'),
      'tutorial' => (tutorialSource, 'the t(…) or _T(…) call of “${_short(c.key)}”', 't$tuple'),
      _ => (catalogSource, 'the n(…) call of “${_short(c.key)}”', 'n$tuple'),
    };
    b.writeln('$file, $what');
    b.writeln('  was: ${c.from ?? '(missing)'}');
    b.writeln('  now: ${c.to}');
    b.writeln('  $paste');
    b.writeln();
  }
  return b.toString();
}

/// [s] as a single-quoted Dart string literal.
String _dartLiteral(String s) {
  final body = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\t', r'\t');
  return "'$body'";
}

// ---------------------------------------------------------------- command line

void main(List<String> args) {
  exitCode = runReviewCli(args);
}

const _valued = {'--out', '--format', '--lang', '--packs'};
const _flags = {'--dry-run', '--force-partial', '--help', '-h'};

/// Runs the command line [args] in the repository at [root] and returns the
/// exit status: 0 done, 1 a review was refused, 2 a usage or file error.
/// [out] and [err] are the standard output and error unless given.
int runReviewCli(List<String> args, {StringSink? out, StringSink? err, String root = '.'}) {
  final o = out ?? stdout, e = err ?? stderr;
  final words = <String>[], options = <String, String>{}, flags = <String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    final eq = a.indexOf('=');
    if (a.startsWith('--') && eq > 0 && _valued.contains(a.substring(0, eq))) {
      options[a.substring(0, eq)] = a.substring(eq + 1);
    } else if (_valued.contains(a)) {
      if (i + 1 == args.length) return _usage(e, '$a needs a value');
      options[a] = args[++i];
    } else if (a.startsWith('-')) {
      if (!_flags.contains(a)) return _usage(e, 'unknown option $a');
      flags.add(a);
    } else {
      words.add(a);
    }
  }
  if (flags.contains('--help') || flags.contains('-h')) {
    o.writeln(reviewUsage);
    return 0;
  }
  if (words.isEmpty) return _usage(e, 'export or import?');
  try {
    return switch (words.first) {
      'export' => _export(words, options, o, e, root),
      'import' => _import(words, options, flags, o, e, root),
      _ => _usage(e, 'unknown command "${words.first}"'),
    };
  } on FileSystemException catch (x) {
    e.writeln('${x.path ?? ''}: ${x.message}');
    return 2;
  } on FormatException catch (x) {
    e.writeln(x.message);
    return 2;
  }
}

int _usage(StringSink err, String problem) {
  err.writeln(problem);
  err.writeln(reviewUsage);
  return 2;
}

int _export(List<String> words, Map<String, String> options, StringSink out, StringSink err, String root) {
  if (words.length != 2) return _usage(err, 'export takes one language code, or all');
  final format = options['--format'] ?? 'csv';
  if (format != 'csv' && format != 'xlsx') return _usage(err, 'unknown format "$format": csv or xlsx');
  final langs = words[1] == 'all' ? reviewLanguages : [words[1]];
  for (final l in langs) {
    if (l == 'en') return _usage(err, 'English is the source of the translations: there is nothing to review it against');
    if (!reviewLanguages.contains(l)) return _usage(err, 'unknown language "$l": ${reviewLanguages.join(', ')} or all');
  }
  final ctx = ReviewContext.load(root: root);
  final packs = options['--packs'] ?? '$root/assets/i18n';
  final dir = Directory(options['--out'] ?? '$root/$defaultReviewDir')..createSync(recursive: true);
  for (final l in langs) {
    final pack = baseLanguages.contains(l) ? null : packSections(File('$packs/$l.json').readAsStringSync());
    final rows = reviewRows(l, ctx, pack: pack);
    final file = File('${dir.path}/${reviewFileName(l, format: format)}');
    file.writeAsBytesSync(format == 'xlsx' ? reviewXlsx(l, rows) : utf8.encode(toCsv(reviewTable(l, rows))));
    out.writeln('${file.path}: ${_count(rows.length, 'text')} (${_statusCounts(rows)})');
    if (pack == null) continue;
    final stale = [
      for (final s in reviewSections)
        for (final k in pack[s]!.keys)
          if (!(ctx.english[s]?.containsKey(k) ?? false)) k,
    ];
    if (stale.isNotEmpty) out.writeln('  no English source any more for ${_count(stale.length, 'text')} of $packs/$l.json: remove them');
  }
  return 0;
}

String _statusCounts(List<ReviewRow> rows) {
  final counts = <ReviewStatus, int>{};
  for (final r in rows) {
    counts[r.status] = (counts[r.status] ?? 0) + 1;
  }
  return [
    for (final s in ReviewStatus.values)
      if (counts[s] != null) '${counts[s]} ${s.label}',
  ].join(', ');
}

int _import(List<String> words, Map<String, String> options, Set<String> flags, StringSink out, StringSink err, String root) {
  if (words.length != 2) return _usage(err, 'import takes the reviewed file');
  final path = words[1];
  final input = reviewEntries(readReviewTable(File(path).readAsBytesSync()));
  final named = RegExp(r'(?:^|[^a-z])([a-z]{2})\.[a-z]+$').firstMatch(path.split(RegExp(r'[/\\]')).last.toLowerCase())?.group(1);
  final lang = options['--lang'] ?? input.lang ?? (named != null && reviewLanguages.contains(named) ? named : null);
  if (lang == null) return _usage(err, 'which language is $path? Name it with --lang');
  if (!reviewLanguages.contains(lang)) return _usage(err, 'unknown language "$lang": ${reviewLanguages.join(', ')}');
  if (input.lang != null && input.lang != lang) {
    err.writeln('$path is the review of ${input.lang}, not of $lang');
    return 2;
  }
  final ctx = ReviewContext.load(root: root);
  final packFile = File('${options['--packs'] ?? '$root/assets/i18n'}/$lang.json');
  final packText = baseLanguages.contains(lang) ? null : packFile.readAsStringSync();
  final result = applyReview(lang, input.entries, ctx, pack: packText == null ? null : packSections(packText));
  _report(out, path, result);
  final status = result.rejected.isEmpty ? 0 : 1;
  if (result.changes.isEmpty) {
    out.writeln('Nothing to write.');
    return status;
  }
  if (status != 0 && !flags.contains('--force-partial')) {
    out.writeln('Nothing written: correct the refused reviews, or run again with --force-partial to write the others.');
    return status;
  }
  final dryRun = flags.contains('--dry-run');
  if (packText == null) {
    final list = compiledChangeList(lang, result.changes, ctx);
    out.writeln();
    out.writeln('${languageNames[lang]} is compiled into the app, so the import cannot write it: apply these ${_count(result.changes.length, 'change')} by hand, then run dart format.');
    out.write(list);
    if (!dryRun) {
      final saved = File('${_withoutExtension(path)}.$lang-changes.txt')..writeAsStringSync(list);
      out.writeln('The list is saved in ${saved.path}.');
    }
    return status;
  }
  if (dryRun) {
    out.writeln('Dry run: ${_count(result.changes.length, 'text')} not written to ${packFile.path}.');
    return status;
  }
  packFile.writeAsStringSync(applyChangesToPack(packText, result.changes, ctx.english));
  out.writeln('${packFile.path}: ${_count(result.changes.length, 'text')} written.');
  return status;
}

void _report(StringSink out, String path, ImportResult r) {
  out.writeln('$path (${languageNames[r.lang] ?? r.lang}): ${r.changes.length} to change, ${r.unchanged} unchanged, ${r.rejected.length} refused, ${r.withoutReview} without review.');
  if (r.rejected.isNotEmpty) {
    out.writeln('\nRefused:');
    for (final x in r.rejected) {
      out.writeln('  ${_where(x.entry)}: ${x.reasons.join(' ')}');
      out.writeln('    review: ${x.entry.review}');
    }
  }
  if (r.warnings.isNotEmpty) {
    out.writeln('\nWarnings:');
    for (final w in r.warnings) {
      out.writeln('  $w');
    }
  }
  if (r.comments.isNotEmpty) {
    out.writeln("\nThe reviewer's comments:");
    for (final c in r.comments) {
      out.writeln('  ${_where(c)}: ${c.comment}');
    }
  }
  if (r.changes.isNotEmpty) {
    out.writeln('\nChanges:');
    for (final c in r.changes) {
      out.writeln('  ${c.section} ${_short(c.key)}: ${c.from == null ? '(missing)' : '“${c.from}”'} → “${c.to}”');
    }
  }
}

String _withoutExtension(String path) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  return dot > slash ? path.substring(0, dot) : path;
}
