/// String tables of the interface languages beyond the built-in Portuguese,
/// English and Spanish, installed at run time from `assets/i18n/<code>.json`
/// (the app loads the file of the chosen language on demand; the design
/// worker receives the table with the request).
///
/// A pack has three sections, all keyed by strings:
/// - `strings`: the keys of the main table (`menu.file` → text);
/// - `tutorial`: the tutorial texts, keyed by their English source text;
/// - `catalog`: the default catalogue names, keyed by their English name.
///
/// Every lookup returns null when the language or the entry is missing, and
/// the caller falls back to English, so a partial pack still works.
library;

class LanguagePack {
  const LanguagePack({this.strings = const {}, this.tutorial = const {}, this.catalog = const {}});

  final Map<String, String> strings;
  final Map<String, String> tutorial;
  final Map<String, String> catalog;

  static Map<String, String> _section(Map<String, dynamic> j, String name) {
    final s = j[name];
    if (s is! Map) return const {};
    return {for (final e in s.entries) if (e.value is String) '${e.key}': e.value as String};
  }

  /// Reads the JSON of an `assets/i18n/<code>.json` file.
  factory LanguagePack.fromJson(Map<String, dynamic> j) =>
      LanguagePack(strings: _section(j, 'strings'), tutorial: _section(j, 'tutorial'), catalog: _section(j, 'catalog'));

  Map<String, dynamic> toJson() => {'strings': strings, 'tutorial': tutorial, 'catalog': catalog};

  bool get isEmpty => strings.isEmpty && tutorial.isEmpty && catalog.isEmpty;
}

final Map<String, LanguagePack> _packs = {};

/// Makes [pack] the table of [code]; replaces a previous one.
void installLanguagePack(String code, LanguagePack pack) => _packs[code] = pack;

/// Forgets the table of [code] (tests).
void uninstallLanguagePack(String code) => _packs.remove(code);

/// The installed table of [code], if any.
LanguagePack? languagePack(String code) => _packs[code];

/// Whether a table for [code] has been installed.
bool isLanguagePackInstalled(String code) => _packs.containsKey(code);

/// Text of [key] in [code], or null when the pack or the entry is missing.
String? packString(String code, String key) => _packs[code]?.strings[key];

/// Tutorial text whose English source is [english], in [code].
String? packTutorialText(String code, String english) => _packs[code]?.tutorial[english];

/// Default catalogue name whose English source is [english], in [code].
String? packCatalogName(String code, String english) => _packs[code]?.catalog[english];
