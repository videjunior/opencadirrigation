/// Currencies of the project prices.
///
/// Every price in a project (catalogue costs, energy tariff, pivot machine
/// costs) is in one currency, identified by its ISO 4217 code
/// ([DesignParameters.currencyCode]) and shown with a symbol
/// ([DesignParameters.currency]). A new project takes the currency of the
/// user's region when the system locale names one (`pt-PT` → EUR,
/// `en-IN` → INR), else the currency of the most populous country of the
/// interface language ([currencyForLanguage]).
///
/// The illustrative prices of the built-in catalogue are written in
/// [catalogPriceCurrency] and converted with the reference rates below
/// ([exchangeRatesDate]); they only order the options for the economic
/// sizing and never replace a local price list. The user can convert all
/// the prices of a project to another currency with an edited rate.
///
/// Pure Dart.
library;

import 'dart:math' as math;

import '../units.dart';
import 'catalog.dart';

/// A currency: ISO 4217 code, the symbol shown next to prices and the
/// number of decimals prices usually have.
class Currency {
  const Currency(this.code, this.symbol, {this.decimals = 2});
  final String code;
  final String symbol;
  final int decimals;
}

/// Currency of the prices written in the built-in catalogue.
const catalogPriceCurrency = 'BRL';

/// Date of [unitsPerBrl] (`YYYY-MM-DD`).
const exchangeRatesDate = '2026-09-21';

/// Where [unitsPerBrl] came from.
const exchangeRatesSource = 'European Central Bank reference rates and exchangerate-api.com, $exchangeRatesDate';

/// Known currencies, in the order of the currency menu (the ones of the
/// interface languages first).
const currencies = <Currency>[
  Currency('BRL', r'R$'),
  Currency('USD', r'US$'),
  Currency('EUR', '€'),
  Currency('MXN', r'MX$'),
  Currency('INR', '₹'),
  Currency('CNY', 'CN¥'),
  Currency('JPY', '¥', decimals: 0),
  Currency('IDR', 'Rp', decimals: 0),
  Currency('NGN', '₦'),
  Currency('TZS', 'TSh', decimals: 0),
  Currency('KES', 'KSh'),
  Currency('VND', '₫', decimals: 0),
  Currency('TRY', '₺'),
  Currency('RUB', '₽'),
  Currency('EGP', 'E£'),
  Currency('SAR', 'SAR'),
  Currency('PKR', 'Rs'),
  Currency('BDT', '৳'),
  Currency('GBP', '£'),
  Currency('ARS', r'AR$'),
  Currency('COP', r'CO$', decimals: 0),
  Currency('CLP', r'CL$', decimals: 0),
  Currency('PEN', 'S/'),
  Currency('UYU', r'$U'),
  Currency('PYG', '₲', decimals: 0),
  Currency('BOB', 'Bs'),
  Currency('GTQ', 'Q'),
  Currency('CRC', '₡'),
  Currency('DOP', r'RD$'),
  Currency('CAD', r'CA$'),
  Currency('AUD', r'A$'),
  Currency('NZD', r'NZ$'),
  Currency('ZAR', 'R'),
  Currency('CHF', 'CHF'),
  Currency('SEK', 'kr'),
  Currency('NOK', 'kr'),
  Currency('DKK', 'kr'),
  Currency('PLN', 'zł'),
  Currency('CZK', 'Kč'),
  Currency('HUF', 'Ft', decimals: 0),
  Currency('RON', 'lei'),
  Currency('UAH', '₴'),
  Currency('KZT', '₸'),
  Currency('BYN', 'Br'),
  Currency('ILS', '₪'),
  Currency('AED', 'AED'),
  Currency('QAR', 'QAR'),
  Currency('KWD', 'KWD', decimals: 3),
  Currency('OMR', 'OMR', decimals: 3),
  Currency('BHD', 'BHD', decimals: 3),
  Currency('JOD', 'JOD', decimals: 3),
  Currency('IQD', 'IQD', decimals: 0),
  Currency('LBP', 'LBP', decimals: 0),
  Currency('MAD', 'MAD'),
  Currency('DZD', 'DZD'),
  Currency('TND', 'TND', decimals: 3),
  Currency('IRR', 'IRR', decimals: 0),
  Currency('AFN', '؋'),
  Currency('KRW', '₩', decimals: 0),
  Currency('TWD', r'NT$'),
  Currency('HKD', r'HK$'),
  Currency('SGD', r'S$'),
  Currency('MYR', 'RM'),
  Currency('THB', '฿'),
  Currency('PHP', '₱'),
  Currency('NPR', 'NRs'),
  Currency('LKR', 'LKR'),
  Currency('UZS', 'soʻm', decimals: 0),
  Currency('AZN', '₼'),
  Currency('UGX', 'USh', decimals: 0),
  Currency('ETB', 'Br'),
  Currency('GHS', 'GH₵'),
  Currency('XOF', 'CFA', decimals: 0),
  Currency('XAF', 'FCFA', decimals: 0),
  Currency('AOA', 'Kz'),
  Currency('MZN', 'MT'),
  Currency('CVE', 'Esc'),
];

/// Units of each currency bought by one Brazilian real on [exchangeRatesDate].
const unitsPerBrl = <String, double>{
  'BRL': 1, 'USD': 0.194498, 'EUR': 0.169492, 'GBP': 0.14543, 'JPY': 30.6062, 'CNY': 1.3088, 'INR': 18.6598, 'IDR': 3451.74,
  'NGN': 262.864, 'KES': 25.2459, 'TZS': 516.716, 'UGX': 745.134, 'VND': 5050.14, 'TRY': 9.48874, 'RUB': 16.495, 'EGP': 10.1227,
  'SAR': 0.729374, 'AED': 0.7143, 'MAD': 1.85499, 'DZD': 26.0744, 'TND': 0.569235, 'IQD': 254.226, 'JOD': 0.1379, 'QAR': 0.707979,
  'KWD': 0.060022, 'OMR': 0.074785, 'BHD': 0.073132, 'LBP': 17407.7, 'PKR': 54.0161, 'BDT': 23.9342, 'MXN': 3.34495, 'ARS': 294.148,
  'COP': 617.19, 'CLP': 187.238, 'PEN': 0.657038, 'UYU': 7.83241, 'PYG': 1160.73, 'BOB': 2.19297, 'GTQ': 1.48678, 'CRC': 87.1606,
  'DOP': 11.4422, 'CAD': 0.272264, 'AUD': 0.27313, 'NZD': 0.34017, 'ZAR': 3.16636, 'CHF': 0.1602, 'SEK': 1.91301, 'NOK': 1.83189,
  'DKK': 1.26869, 'PLN': 0.739874, 'CZK': 4.12219, 'HUF': 61.7788, 'RON': 0.8934, 'UAH': 8.7116, 'KZT': 86.927, 'BYN': 0.58924,
  'ILS': 0.589802, 'KRW': 269.659, 'TWD': 6.1751, 'HKD': 1.52685, 'SGD': 0.248332, 'MYR': 0.793666, 'THB': 6.48381, 'PHP': 12.216,
  'XOF': 111.137, 'XAF': 111.137, 'AOA': 183.852, 'MZN': 12.4413, 'ETB': 31.3447, 'GHS': 2.22843, 'NPR': 29.8503, 'LKR': 64.2754,
  'IRR': 267526, 'AFN': 12.6304, 'UZS': 2299.29, 'AZN': 0.331254, 'CVE': 18.6819,
};

/// The currency with ISO code [code], if known.
Currency? currencyByCode(String code) {
  final c = code.trim().toUpperCase();
  for (final x in currencies) {
    if (x.code == c) return x;
  }
  return null;
}

/// Symbol shown for [code] (the code itself when unknown).
String currencySymbol(String code) => currencyByCode(code)?.symbol ?? code;

/// Units of [to] bought by one unit of [from] with the reference rates;
/// null when either currency is unknown. 1 for the same currency.
double? exchangeRate(String from, String to) {
  final f = from.trim().toUpperCase(), t = to.trim().toUpperCase();
  if (f == t && f.isNotEmpty) return 1;
  final a = unitsPerBrl[f], b = unitsPerBrl[t];
  if (a == null || b == null || a <= 0) return null;
  return b / a;
}

/// Default currency of each interface language: the currency of the most
/// populous country where the language is spoken as a first language.
const languageCurrencies = <String, String>{
  'pt': 'BRL', 'en': 'USD', 'es': 'MXN', 'de': 'EUR', 'fr': 'EUR', 'id': 'IDR', 'ha': 'NGN', 'sw': 'TZS', 'vi': 'VND', 'tr': 'TRY',
  'ru': 'RUB', 'ar': 'EGP', 'ur': 'PKR', 'hi': 'INR', 'mr': 'INR', 'bn': 'BDT', 'pa': 'INR', 'te': 'INR', 'zh': 'CNY', 'ja': 'JPY',
};

/// Currency of each country (ISO 3166-1 alpha-2), for the region part of a
/// locale tag (`pt-PT`, `es-AR`, `en-KE`).
const regionCurrencies = <String, String>{
  'BR': 'BRL', 'PT': 'EUR', 'AO': 'AOA', 'MZ': 'MZN', 'CV': 'CVE',
  'US': 'USD', 'GB': 'GBP', 'IE': 'EUR', 'CA': 'CAD', 'AU': 'AUD', 'NZ': 'NZD', 'ZA': 'ZAR', 'IN': 'INR', 'PK': 'PKR', 'BD': 'BDT',
  'NG': 'NGN', 'GH': 'GHS', 'KE': 'KES', 'TZ': 'TZS', 'UG': 'UGX', 'ET': 'ETB', 'PH': 'PHP', 'SG': 'SGD', 'MY': 'MYR', 'HK': 'HKD',
  'MX': 'MXN', 'ES': 'EUR', 'AR': 'ARS', 'CO': 'COP', 'CL': 'CLP', 'PE': 'PEN', 'UY': 'UYU', 'PY': 'PYG', 'BO': 'BOB', 'EC': 'USD',
  'GT': 'GTQ', 'CR': 'CRC', 'DO': 'DOP', 'PA': 'USD', 'SV': 'USD', 'PR': 'USD', 'VE': 'USD', 'HN': 'USD', 'NI': 'USD', 'CU': 'USD',
  'DE': 'EUR', 'AT': 'EUR', 'CH': 'CHF', 'LI': 'CHF', 'LU': 'EUR', 'BE': 'EUR', 'NL': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'GR': 'EUR',
  'FI': 'EUR', 'SK': 'EUR', 'SI': 'EUR', 'EE': 'EUR', 'LV': 'EUR', 'LT': 'EUR', 'HR': 'EUR', 'MT': 'EUR', 'CY': 'EUR',
  'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK', 'PL': 'PLN', 'CZ': 'CZK', 'HU': 'HUF', 'RO': 'RON', 'UA': 'UAH', 'KZ': 'KZT', 'BY': 'BYN',
  'RU': 'RUB', 'TR': 'TRY', 'IL': 'ILS', 'AZ': 'AZN', 'UZ': 'UZS',
  'EG': 'EGP', 'SA': 'SAR', 'AE': 'AED', 'QA': 'QAR', 'KW': 'KWD', 'OM': 'OMR', 'BH': 'BHD', 'JO': 'JOD', 'IQ': 'IQD', 'LB': 'LBP',
  'MA': 'MAD', 'DZ': 'DZD', 'TN': 'TND', 'IR': 'IRR', 'AF': 'AFN',
  'SN': 'XOF', 'CI': 'XOF', 'ML': 'XOF', 'BF': 'XOF', 'NE': 'XOF', 'BJ': 'XOF', 'TG': 'XOF', 'CM': 'XAF', 'GA': 'XAF', 'TD': 'XAF',
  'CN': 'CNY', 'TW': 'TWD', 'JP': 'JPY', 'KR': 'KRW', 'ID': 'IDR', 'VN': 'VND', 'TH': 'THB', 'NP': 'NPR', 'LK': 'LKR',
};

/// Default currency for the interface language [lang].
String currencyForLanguage(String lang) => languageCurrencies[lang] ?? 'USD';

/// Default currency for a new project: the region of the first locale tag
/// in [tags] that speaks [lang] (`de-CH` → CHF when the interface is in
/// German), else the language default. Tags come as the browser or the OS
/// report them (`pt-BR`, `en_US`, `zh-Hans-CN`).
String currencyForLocale(String lang, Iterable<String> tags) {
  for (final tag in tags) {
    final parts = tag.trim().split(RegExp(r'[-_]'));
    if (parts.isEmpty || parts.first.toLowerCase() != lang) continue;
    for (final p in parts.skip(1)) {
      if (p.length == 2) {
        final c = regionCurrencies[p.toUpperCase()];
        if (c != null) return c;
      }
    }
  }
  return currencyForLanguage(lang);
}

/// ISO code of a currency written as a symbol or a code in older files
/// (`R$` → BRL, `€` → EUR, `usd` → USD); null when it cannot be told.
String? currencyCodeForSymbol(String symbol) {
  final s = symbol.trim();
  if (s.isEmpty) return null;
  final byCode = currencyByCode(s);
  if (byCode != null) return byCode.code;
  for (final c in currencies) {
    if (c.symbol == s) return c.code;
  }
  return switch (s) {
    r'$' => 'USD',
    '¥' || '円' => 'JPY',
    '元' || '￥' => 'CNY',
    'Rs.' || '₨' => 'PKR',
    'S/.' => 'PEN',
    'ر.س' || '﷼' => 'SAR',
    'ج.م' => 'EGP',
    _ => null,
  };
}

/// Multiplies every price of [c] by [factor] (a currency conversion).
void scaleCatalogPrices(Catalog c, double factor) {
  if (factor == 1) return;
  for (final p in c.pipes) {
    p.costPerM *= factor;
  }
  for (final o in c.outlets) {
    o.cost *= factor;
  }
  for (final t in c.tapes) {
    t.costPerM *= factor;
  }
  for (final v in c.valves) {
    v.cost *= factor;
  }
  for (final p in c.pumps) {
    p.cost *= factor;
  }
  for (final f in c.fittings) {
    f.cost *= factor;
  }
}

/// Whether any item of [c] has a price.
bool catalogHasPrices(Catalog c) =>
    c.pipes.any((p) => p.costPerM > 0) ||
    c.outlets.any((o) => o.cost > 0) ||
    c.tapes.any((t) => t.costPerM > 0) ||
    c.valves.any((v) => v.cost > 0) ||
    c.pumps.any((p) => p.cost > 0) ||
    c.fittings.any((f) => f.cost > 0);

/// An exchange rate with four significant digits, in plain notation
/// (`0.1695`, `30.61`, `3452`, `267526`).
String fmtRate(double r) {
  if (!(r > 0) || !r.isFinite) return fmt(r, 4);
  final mag = (math.log(r) / math.ln10).floor();
  return fmt(r, (3 - mag).clamp(0, 8));
}
