/// Defaults of a new project that depend on where the user is: the mains
/// frequency and the display units, from the region of the system locale
/// (the same way the currency is chosen, see `currencyForLocale`).
library;

import '../units.dart';

/// Countries and territories (ISO 3166-1 alpha-2) whose public mains run at
/// 60 Hz; the rest of the world uses 50 Hz. Japan is split (50 Hz in the
/// east, 60 Hz in the west) and taken at 60 Hz.
const mains60HzRegions = {
  // North and Central America and the Caribbean
  'US', 'CA', 'MX', 'GT', 'BZ', 'SV', 'HN', 'NI', 'CR', 'PA', 'CU', 'DO', 'HT', 'PR', 'BS', 'BM', 'KY', 'VI', 'VG', 'TT', 'AW', 'MS', 'KN', 'LC',
  // South America
  'BR', 'CO', 'VE', 'EC', 'PE', 'GY', 'SR',
  // Asia and the Pacific
  'SA', 'KR', 'TW', 'PH', 'JP', 'GU', 'AS', 'MP', 'FM', 'MH', 'PW',
  // Africa
  'LR',
};

/// Mains frequency of a language when the locale gives no region: where
/// most of its speakers using the app are (Portuguese: Brazil; English:
/// the United States, as its default currency; Spanish: Mexico and most of
/// Latin America; Japanese: see [mains60HzRegions]); 50 Hz otherwise.
const _languageHz = {'pt': 60.0, 'en': 60.0, 'es': 60.0, 'ja': 60.0};

/// Countries that measure in US customary units.
const usCustomaryRegions = {'US', 'LR', 'MM'};

/// The region (upper-case ISO 3166 code) of the first locale tag in [tags]
/// that speaks [lang] (`pt-BR` → BR, `zh-Hans-CN` → CN); null when none
/// gives one. Tags come as the browser or the system report them.
String? regionForLocale(String lang, Iterable<String> tags) {
  for (final tag in tags) {
    final parts = tag.trim().split(RegExp(r'[-_]'));
    if (parts.isEmpty || parts.first.toLowerCase() != lang) continue;
    for (final p in parts.skip(1)) {
      if (p.length == 2) return p.toUpperCase();
    }
  }
  return null;
}

/// Mains frequency (Hz) of [region] (ISO 3166 alpha-2).
double mainsHzForRegion(String region) => mains60HzRegions.contains(region.toUpperCase()) ? 60 : 50;

/// Mains frequency (Hz) for a new project: from the region of the locale
/// of [lang] in [tags], else the language default.
double mainsHzForLocale(String lang, Iterable<String> tags) {
  final r = regionForLocale(lang, tags);
  return r != null ? mainsHzForRegion(r) : (_languageHz[lang] ?? 50);
}

/// Display units for a new project: US customary in the United States,
/// Liberia and Myanmar (by the region of the locale of [lang] in [tags]),
/// metric elsewhere and when the locale gives no region.
Units unitsForLocale(String lang, Iterable<String> tags) {
  final r = regionForLocale(lang, tags);
  return r != null && usCustomaryRegions.contains(r) ? Units.us : Units.metric;
}
