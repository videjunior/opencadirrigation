/// Thermoplastic pressure pipes by standard: the dimension tables of
/// ISO 1452-2 (PVC-U), EN 12201-2 (PE 100), IS 4985 (PVC-U, India) and
/// IS 4984 (PE 100 and PE 80, India), the check of a pipe's wall against its
/// pressure class, and the generic catalogue packs built from them with
/// reference prices (catalogs/iso1452.oci.cat, en12201, is4985 and is4984),
/// plus the inch PVC pipes of ASTM D2241 / D1785 (catalogs/astm.oci.cat).
/// tool/gen_catalogs.dart writes the packs from here; catalogs/README.md
/// describes the sources.
library;

import 'dart:math' as math;

import '../hydraulics/water_hammer.dart';
import '../io/catalog_io.dart';
import '../units.dart';
import 'catalog.dart';

/// Date of the data of the packs built here (`updated`).
const standardPacksUpdated = '2026-11-02';

/// One pressure class of a pipe standard: the wall of each size and the
/// stress the standard sizes that wall for.
class PipeSeries {
  const PipeSeries({required this.key, required this.name, required this.pnBar, required this.walls, required this.designStressMpa, this.largeDesignStressMpa, this.largeAboveDn = 0});

  /// Id part of its items (`pn10`, `sdr11`, `class3`, `pe100_pn6`).
  final String key;

  /// Name of its items before the size (`PVC-U ISO 1452 PN 10`).
  final String name;

  /// Pressure class (bar) at the reference temperature of the standard.
  final double pnBar;

  /// Wall (mm) by nominal outside diameter (mm) as the table of the standard
  /// gives them: the nominal wall e_n of ISO 1452-2 and EN 12201-2 (equal to
  /// the least wall at any point), the least wall e_min of IS 4985 and
  /// IS 4984.
  final Map<int, double> walls;

  /// Hoop stress (MPa) the walls of the class are sized for at [pnBar]: the
  /// minimum required strength of the material over the design coefficient.
  final double designStressMpa;

  /// The design stress above [largeAboveDn] mm when it differs (ISO 1452-2:
  /// design coefficient 2.0 instead of 2.5 above dn 90).
  final double? largeDesignStressMpa;
  final int largeAboveDn;

  /// Design stress (MPa) of the wall of size [dn].
  double designStressAt(int dn) {
    final large = largeDesignStressMpa;
    return large != null && dn > largeAboveDn ? large : designStressMpa;
  }
}

/// Reference prices of the pipes of a standard: the rows a public price
/// document gives and how the other pipes are priced ([pipePriceFit]).
class PipePriceBook {
  const PipePriceBook({
    required this.currency,
    required this.date,
    required this.document,
    required this.rows,
    required this.decimals,
    this.fitOnly = const [],
    this.fitOnlyText = '',
    this.misprints = const {},
    this.misprintText = '',
    this.note = '',
  });

  /// ISO 4217 code of the prices.
  final String currency;

  /// Date of the price document (`YYYY-MM-DD`).
  final String date;

  /// Which document, which of its items and what their price includes.
  final String document;

  /// Published price per metre by class ([PipeSeries.key]) and nominal
  /// outside diameter (mm).
  final Map<String, Map<int, double>> rows;

  /// Decimals of the prices (2 for EUR, 0 for INR).
  final int decimals;

  /// Published rows of classes the pack leaves out, used only to fit the
  /// price line: (nominal outside diameter mm, wall mm, price).
  final List<(int, double, double)> fitOnly;
  final String fitOnlyText;

  /// Published rows taken as misprints: neither used nor fitted.
  final Map<String, Set<int>> misprints;
  final String misprintText;

  /// What else the prices need said (rows of the document not used, why).
  final String note;
}

/// A pipe standard: its classes, its material and how its pack is described.
class PipeStandard {
  const PipeStandard({
    required this.id,
    required this.code,
    required this.material,
    required this.polymer,
    required this.densityKgM3,
    required this.series,
    required this.brand,
    required this.title,
    required this.description,
    required this.url,
    required this.sources,
    this.prices,
  });

  /// Id of the pack and prefix of the ids of its items (`iso1452`).
  final String id;

  /// The standard as the supplier of its items (`ISO 1452`).
  final String code;
  final PipeMaterial material;

  /// Name of the material in the price note (`PVC-U`, `PE`).
  final String polymer;

  /// Density (kg/m³) of the mass per metre the prices are fitted to.
  final int densityKgM3;
  final List<PipeSeries> series;

  /// Pack metadata: manufacturer field, pack name, description, URL of the
  /// standard and the documents the data come from.
  final String brand, title, description, url;
  final List<String> sources;
  final PipePriceBook? prices;

  /// The class of key [key].
  PipeSeries seriesOf(String key) => series.firstWhere((s) => s.key == key, orElse: () => throw StateError('$id: no class $key'));
}

// ---------------------------------------------------------------- tables

// ISO 1452-2:2009 Table 2, nominal walls e_n (the ISO 4065 values, at least
// 1.5 mm): S 16 / 12.5 / 10 / 8 / 6.3 for PN 6 / 8 / 10 / 12.5 / 16 up to
// dn 90 (design coefficient 2.5) and S 20 / 16 / 12.5 / 10 / 8 above (2.0).
const _isoPn6 = <int, double>{40: 1.5, 50: 1.6, 63: 2.0, 75: 2.3, 90: 2.8, 110: 2.7, 125: 3.1, 140: 3.5, 160: 4.0, 180: 4.4, 200: 4.9, 225: 5.5, 250: 6.2, 280: 6.9, 315: 7.7};

const _isoPn8 = <int, double>{32: 1.5, 40: 1.6, 50: 2.0, 63: 2.5, 75: 2.9, 90: 3.5, 110: 3.4, 125: 3.9, 140: 4.3, 160: 4.9, 180: 5.5, 200: 6.2, 225: 6.9, 250: 7.7, 280: 8.6, 315: 9.7};

const _isoPn10 = <int, double>{32: 1.6, 40: 1.9, 50: 2.4, 63: 3.0, 75: 3.6, 90: 4.3, 110: 4.2, 125: 4.8, 140: 5.4, 160: 6.2, 180: 6.9, 200: 7.7, 225: 8.6, 250: 9.6, 280: 10.7, 315: 12.1};

const _isoPn125 = <int, double>{25: 1.5, 32: 1.9, 40: 2.4, 50: 3.0, 63: 3.8, 75: 4.5, 90: 5.4, 110: 5.3, 125: 6.0, 140: 6.7, 160: 7.7, 180: 8.6, 200: 9.6, 225: 10.8, 250: 11.9, 280: 13.4, 315: 15.0};

const _isoPn16 = <int, double>{
  20: 1.5,
  25: 1.9,
  32: 2.4,
  40: 3.0,
  50: 3.7,
  63: 4.7,
  75: 5.6,
  90: 6.7,
  110: 6.6,
  125: 7.4,
  140: 8.3,
  160: 9.5,
  180: 10.7,
  200: 11.9,
  225: 13.4,
  250: 14.8,
  280: 16.6,
  315: 18.7,
};

// EN 12201-2 Table 2 (PE 100, the ISO 4065 values, at least 2.0 mm; 3.0 mm
// for 32 mm SDR 11, where the standard rounds the small sizes up to 2.0,
// 2.3 or 3.0 mm).
const _enSdr26 = <int, double>{50: 2.0, 63: 2.5, 75: 2.9, 90: 3.5, 110: 4.2, 125: 4.8, 140: 5.4, 160: 6.2, 180: 6.9, 200: 7.7, 225: 8.6, 250: 9.6, 280: 10.7, 315: 12.1};

const _enSdr21 = <int, double>{40: 2.0, 50: 2.4, 63: 3.0, 75: 3.6, 90: 4.3, 110: 5.3, 125: 6.0, 140: 6.7, 160: 7.7, 180: 8.6, 200: 9.6, 225: 10.8, 250: 11.9, 280: 13.4, 315: 15.0};

const _enSdr17 = <int, double>{32: 2.0, 40: 2.4, 50: 3.0, 63: 3.8, 75: 4.5, 90: 5.4, 110: 6.6, 125: 7.4, 140: 8.3, 160: 9.5, 180: 10.7, 200: 11.9, 225: 13.4, 250: 14.8, 280: 16.6, 315: 18.7};

const _enSdr136 = <int, double>{
  25: 2.0,
  32: 2.4,
  40: 3.0,
  50: 3.7,
  63: 4.7,
  75: 5.6,
  90: 6.7,
  110: 8.1,
  125: 9.2,
  140: 10.3,
  160: 11.8,
  180: 13.3,
  200: 14.7,
  225: 16.6,
  250: 18.4,
  280: 20.6,
  315: 23.2,
};

const _enSdr11 = <int, double>{
  20: 2.0,
  25: 2.3,
  32: 3.0,
  40: 3.7,
  50: 4.6,
  63: 5.8,
  75: 6.8,
  90: 8.2,
  110: 10.0,
  125: 11.4,
  140: 12.7,
  160: 14.6,
  180: 16.4,
  200: 18.2,
  225: 20.5,
  250: 22.7,
  280: 25.4,
  315: 28.6,
};

// IS 4985:2021 Table 1, minimum walls (design stress 8.6 MPa at 27 °C).
const _is4985Class1 = <int, double>{90: 1.3, 110: 1.6, 125: 1.8, 140: 2.0, 160: 2.3, 180: 2.6, 200: 2.9, 225: 3.3, 250: 3.6, 280: 4.1, 315: 4.6};

const _is4985Class2 = <int, double>{63: 1.5, 75: 1.8, 90: 2.1, 110: 2.5, 125: 2.9, 140: 3.2, 160: 3.7, 180: 4.2, 200: 4.6, 225: 5.2, 250: 5.7, 280: 6.4, 315: 7.2};

const _is4985Class3 = <int, double>{40: 1.4, 50: 1.7, 63: 2.2, 75: 2.6, 90: 3.1, 110: 3.7, 125: 4.3, 140: 4.8, 160: 5.4, 180: 6.1, 200: 6.8, 225: 7.6, 250: 8.5, 280: 9.5, 315: 10.7};

const _is4985Class4 = <int, double>{
  25: 1.2,
  32: 1.5,
  40: 1.8,
  50: 2.3,
  63: 2.8,
  75: 3.4,
  90: 4.0,
  110: 4.9,
  125: 5.6,
  140: 6.3,
  160: 7.2,
  180: 8.0,
  200: 8.9,
  225: 10.0,
  250: 11.2,
  280: 12.5,
  315: 14.0,
};

const _is4985Class5 = <int, double>{
  20: 1.1,
  25: 1.4,
  32: 1.8,
  40: 2.2,
  50: 2.8,
  63: 3.5,
  75: 4.2,
  90: 5.0,
  110: 6.1,
  125: 6.9,
  140: 7.7,
  160: 8.8,
  180: 9.9,
  200: 11.0,
  225: 12.4,
  250: 13.8,
  280: 15.4,
  315: 17.3,
};

const _is4985Class6 = <int, double>{
  20: 1.4,
  25: 1.7,
  32: 2.2,
  40: 2.8,
  50: 3.4,
  63: 4.3,
  75: 5.1,
  90: 6.1,
  110: 7.5,
  125: 8.5,
  140: 9.5,
  160: 10.9,
  180: 12.2,
  200: 13.6,
  225: 15.3,
  250: 17.0,
  280: 19.0,
  315: 21.4,
};

// IS 4984:2016 Table 4 as replaced by Amendment 2 (2022), minimum walls by
// SDR: dn/SDR rounded up to 0.1 mm, at least 2.0 mm.
const _is4984Sdr33 = <int, double>{75: 2.3, 90: 2.8, 110: 3.4, 125: 3.8, 140: 4.3, 160: 4.9, 180: 5.5, 200: 6.1, 225: 6.9, 250: 7.6, 280: 8.5, 315: 9.6};

const _is4984Sdr26 = <int, double>{50: 2.0, 63: 2.5, 75: 2.9, 90: 3.5, 110: 4.3, 125: 4.9, 140: 5.4, 160: 6.2, 180: 7.0, 200: 7.7, 225: 8.7, 250: 9.7, 280: 10.8, 315: 12.2};

const _is4984Sdr21 = <int, double>{40: 2.0, 50: 2.4, 63: 3.0, 75: 3.6, 90: 4.3, 110: 5.3, 125: 6.0, 140: 6.7, 160: 7.7, 180: 8.6, 200: 9.6, 225: 10.8, 250: 12.0, 280: 13.4, 315: 15.0};

const _is4984Sdr17 = <int, double>{32: 2.0, 40: 2.4, 50: 3.0, 63: 3.8, 75: 4.5, 90: 5.3, 110: 6.5, 125: 7.4, 140: 8.3, 160: 9.5, 180: 10.6, 200: 11.8, 225: 13.3, 250: 14.8, 280: 16.5, 315: 18.6};

const _is4984Sdr136 = <int, double>{
  25: 2.0,
  32: 2.4,
  40: 3.0,
  50: 3.7,
  63: 4.7,
  75: 5.6,
  90: 6.7,
  110: 8.1,
  125: 9.2,
  140: 10.3,
  160: 11.8,
  180: 13.3,
  200: 14.8,
  225: 16.6,
  250: 18.4,
  280: 20.6,
  315: 23.2,
};

const _is4984Sdr11 = <int, double>{
  20: 2.0,
  25: 2.3,
  32: 3.0,
  40: 3.7,
  50: 4.6,
  63: 5.8,
  75: 6.9,
  90: 8.2,
  110: 10.0,
  125: 11.4,
  140: 12.8,
  160: 14.6,
  180: 16.4,
  200: 18.2,
  225: 20.5,
  250: 22.8,
  280: 25.5,
  315: 28.7,
};

const _is4984Sdr9 = <int, double>{
  20: 2.3,
  25: 2.8,
  32: 3.6,
  40: 4.5,
  50: 5.6,
  63: 7.0,
  75: 8.4,
  90: 10.0,
  110: 12.3,
  125: 13.9,
  140: 15.6,
  160: 17.8,
  180: 20.0,
  200: 22.3,
  225: 25.0,
  250: 27.8,
  280: 31.2,
  315: 35.0,
};

// ---------------------------------------------------------------- prices

const _sardinia = "Regione Autonoma della Sardegna, Prezzario regionale dell'agricoltura, aggiornamento 2024 (Decreto n. 36 prot. 4817 del 12.12.2024)";
const _sardiniaUrl =
    'https://files.regione.sardegna.it/squidex/api/assets/redazionaleras/bc8424d3-e3a4-402e-a0e2-4755218dde78/allegato-decreto-n-36-prot-4817-del-12.12.2024-prezzario-agricoltura.pdf';
const _mjp = 'Maharashtra Jeevan Pradhikaran, State Schedule of Rates 2023-24 (in force from 20 June 2023)';
const _mjpUrl = 'https://mjp.maharashtra.gov.in/wp-content/uploads/2023/01/MJP-SSR-2023-24_Final.pdf';

const _iso1452Prices = PipePriceBook(
  currency: 'EUR',
  date: '2024-12-12',
  decimals: 2,
  document:
      '$_sardinia, items F.001 to F.003: PVC-U pipes to UNI EN 1452-2 for irrigation, PN 6 / 10 / 16, '
      'supplied and laid with their joints and fittings (trench and bedding excluded), EUR per metre without VAT',
  rows: {
    'pn6': {40: 5.1, 50: 5.77, 63: 7.21, 75: 8.8, 90: 10.98, 110: 12.5, 125: 15.41, 140: 18.53, 160: 23.06, 250: 51.62, 315: 78.93},
    'pn10': {50: 6.91, 63: 9.0, 75: 11.57, 90: 14.2, 110: 16.55, 125: 20.4, 140: 24.92, 160: 31.71, 200: 47.34, 250: 72.09, 315: 113.18},
    'pn16': {63: 12.0, 75: 15.73, 90: 19.67, 110: 23.42, 125: 29.01, 140: 35.63, 160: 45.55, 200: 69.47},
  },
);

const _en12201Prices = PipePriceBook(
  currency: 'EUR',
  date: '2024-12-12',
  decimals: 2,
  document:
      '$_sardinia, items F.004 to F.006: PE 100 pipes to UNI EN 12201-2 for irrigation, PN 10 / 16 / 25 (SDR 17 / 11 / 7.4), '
      'supplied and laid with their joints and fittings (trench and bedding excluded), EUR per metre without VAT',
  rows: {
    'sdr17': {50: 6.99, 63: 8.99, 75: 10.67, 90: 18.69, 110: 18.9, 125: 23.24, 140: 27.1, 160: 34.34, 180: 42.46, 200: 51.58, 225: 64.5, 250: 78.3},
    'sdr11': {25: 4.83, 32: 5.6, 40: 6.83, 50: 8.61, 63: 11.62, 75: 13.94, 90: 18.69, 110: 26.0, 160: 49.01, 180: 61.05, 200: 74.51, 250: 114.07},
  },
  fitOnly: [
    (20, 3.0, 4.81),
    (25, 3.5, 5.47),
    (32, 4.4, 6.48),
    (40, 5.5, 8.23),
    (50, 6.9, 11.26),
    (63, 8.6, 15.31),
    (75, 10.3, 21.46),
    (90, 12.3, 29.82),
    (110, 15.1, 42.16),
    (125, 17.1, 45.09),
    (140, 19.2, 56.24),
    (160, 21.9, 71.15),
    (180, 24.6, 89.98),
    (200, 27.4, 112.06),
    (250, 34.2, 167.07),
  ],
  fitOnlyText: 'the SDR 7.4 rows F.006 included',
  misprints: {'sdr17': {90}},
  misprintText: 'but F.004.004, 90 × 5.4 mm, printed at the price of the SDR 11 pipe of that size and taken as a misprint',
);

const _is4985Prices = PipePriceBook(
  currency: 'INR',
  date: '2023-06-20',
  decimals: 0,
  document:
      '$_mjp, section I(II) item 1: ISI-marked rigid PVC pipes to IS 4985 with solvent-cement couplers, '
      'working pressure 4 / 6 / 8 / 10 / 12.5 kg/cm² (classes 2 to 6), 63 to 315 mm, supplied to the departmental stores, '
      'INR per metre without GST',
  rows: {
    'class2': {63: 81.0, 75: 115.0, 90: 160.0, 110: 219.0, 140: 367.0, 160: 480.0, 180: 658.0, 200: 811.0, 225: 1037.0, 250: 1267.0, 280: 1684.0, 315: 2143.0},
    'class3': {63: 115.0, 75: 163.0, 90: 238.0, 110: 325.0, 140: 542.0, 160: 700.0, 180: 931.0, 200: 1192.0, 225: 1502.0, 250: 1875.0, 280: 2473.0, 315: 3154.0},
    'class4': {63: 159.0, 75: 227.0, 90: 322.0, 110: 454.0, 140: 753.0, 160: 988.0, 180: 1307.0, 200: 1643.0, 225: 2086.0, 250: 2609.0, 280: 3437.0, 315: 4352.0},
    'class5': {63: 193.0, 75: 273.0, 90: 393.0, 110: 554.0, 140: 897.0, 160: 1173.0, 180: 1617.0, 200: 1999.0, 225: 2549.0, 250: 3222.0, 280: 4051.0, 315: 5145.0},
    'class6': {63: 245.0, 75: 344.0, 90: 497.0, 110: 703.0, 140: 1144.0, 160: 1505.0, 180: 2057.0, 200: 2551.0, 225: 3242.0, 250: 4100.0, 280: 5160.0, 315: 6577.0},
  },
);

const _is4984Prices = PipePriceBook(
  currency: 'INR',
  date: '2023-06-20',
  decimals: 0,
  document:
      '$_mjp, section I(IX) item 1: PE 100 pipes to IS 4984, 6 / 8 / 10 / 12.5 / 16 kg/cm², 63 to 315 mm, '
      'supplied to the departmental stores without couplers, INR per metre without GST',
  rows: {
    'pe100_pn6': {63: 112.0, 75: 155.0, 90: 220.0, 110: 319.0, 125: 437.0, 140: 549.0, 160: 711.0, 180: 895.0, 200: 1049.0, 225: 1351.0, 250: 1662.0, 280: 2081.0, 315: 2636.0},
    'pe100_pn8': {63: 140.0, 75: 187.0, 90: 266.0, 110: 391.0, 125: 507.0, 140: 693.0, 160: 897.0, 180: 1133.0, 200: 1333.0, 225: 1712.0, 250: 2110.0, 280: 2644.0, 315: 3350.0},
    'pe100_pn10': {63: 172.0, 75: 243.0, 90: 350.0, 110: 515.0, 125: 661.0, 140: 826.0, 160: 1075.0, 180: 1360.0, 200: 1597.0, 225: 2043.0, 250: 2549.0, 280: 3149.0, 315: 4043.0},
    'pe100_pn12_5': {63: 204.0, 75: 287.0, 90: 414.0, 110: 609.0, 125: 787.0, 140: 987.0, 160: 1283.0, 180: 1621.0, 200: 1905.0, 225: 2458.0, 250: 3023.0, 280: 3792.0, 315: 4801.0},
    'pe100_pn16': {63: 232.0, 75: 330.0, 90: 473.0, 110: 698.0, 125: 904.0, 140: 1127.0, 160: 1479.0, 180: 1859.0, 200: 2921.0, 225: 3690.0, 250: 4552.0, 280: 5709.0, 315: 7216.0},
  },
  note:
      'the PE 80 pipes priced by the same line; the PE 100 PN 4 rows of Corrigendum 1 (4 September 2023) '
      'are stated with GST included and are not used',
);

// ------------------------------------------------------------- standards

/// ISO 1452-2:2009 (EN ISO 1452-2), PVC-U pressure pipes, MRS 25 MPa: design
/// coefficient 2.5 up to dn 90 (10 MPa) and 2.0 above (12.5 MPa), PN 6 to 16,
/// dn 20 to 315 mm.
const iso1452Standard = PipeStandard(
  id: 'iso1452',
  code: 'ISO 1452',
  material: PipeMaterial.pvc,
  polymer: 'PVC-U',
  densityKgM3: 1400,
  series: [
    PipeSeries(key: 'pn6', name: 'PVC-U ISO 1452 PN 6', pnBar: 6, walls: _isoPn6, designStressMpa: 10, largeDesignStressMpa: 12.5, largeAboveDn: 90),
    PipeSeries(key: 'pn8', name: 'PVC-U ISO 1452 PN 8', pnBar: 8, walls: _isoPn8, designStressMpa: 10, largeDesignStressMpa: 12.5, largeAboveDn: 90),
    PipeSeries(key: 'pn10', name: 'PVC-U ISO 1452 PN 10', pnBar: 10, walls: _isoPn10, designStressMpa: 10, largeDesignStressMpa: 12.5, largeAboveDn: 90),
    PipeSeries(key: 'pn12_5', name: 'PVC-U ISO 1452 PN 12.5', pnBar: 12.5, walls: _isoPn125, designStressMpa: 10, largeDesignStressMpa: 12.5, largeAboveDn: 90),
    PipeSeries(key: 'pn16', name: 'PVC-U ISO 1452 PN 16', pnBar: 16, walls: _isoPn16, designStressMpa: 10, largeDesignStressMpa: 12.5, largeAboveDn: 90),
  ],
  brand: 'Generic (ISO)',
  title: 'PVC-U pipes by ISO 1452',
  description:
      'PVC-U pressure pipes of ISO 1452-2 (EN ISO 1452-2), PN 6 / 8 / 10 / 12.5 / 16 at 25 °C, dn 20 to 315 mm: '
      'nominal walls of its Table 2 (MRS 25 MPa, design coefficient 2.5 up to dn 90 and 2.0 above); installed reference prices in EUR',
  url: 'https://www.iso.org/standard/50362.html',
  sources: [
    'ISO 1452-2:2009 - Plastics piping systems for water supply and for buried and above-ground drainage and sewerage under pressure - '
        'Unplasticized poly(vinyl chloride) (PVC-U) - Part 2: Pipes',
    'ISO 4065 - Thermoplastics pipes - Universal wall thickness table',
    '$_sardinia: $_sardiniaUrl',
  ],
  prices: _iso1452Prices,
);

/// EN 12201-2 (ISO 4427-2), PE 100 pressure pipes, MRS 10 MPa with the
/// design coefficient 1.25 (8 MPa), SDR 26 to 11 (PN 6 to 16), dn 20 to
/// 315 mm.
const en12201Standard = PipeStandard(
  id: 'en12201',
  code: 'EN 12201',
  material: PipeMaterial.pehd,
  polymer: 'PE',
  densityKgM3: 960,
  series: [
    PipeSeries(key: 'sdr26', name: 'PE 100 SDR 26 (PN 6)', pnBar: 6, walls: _enSdr26, designStressMpa: 8),
    PipeSeries(key: 'sdr21', name: 'PE 100 SDR 21 (PN 8)', pnBar: 8, walls: _enSdr21, designStressMpa: 8),
    PipeSeries(key: 'sdr17', name: 'PE 100 SDR 17 (PN 10)', pnBar: 10, walls: _enSdr17, designStressMpa: 8),
    PipeSeries(key: 'sdr13_6', name: 'PE 100 SDR 13.6 (PN 12.5)', pnBar: 12.5, walls: _enSdr136, designStressMpa: 8),
    PipeSeries(key: 'sdr11', name: 'PE 100 SDR 11 (PN 16)', pnBar: 16, walls: _enSdr11, designStressMpa: 8),
  ],
  brand: 'Generic (EN)',
  title: 'PE 100 pipes by EN 12201',
  description:
      'PE 100 pressure pipes of EN 12201-2 / ISO 4427-2, SDR 26 / 21 / 17 / 13.6 / 11 (PN 6 / 8 / 10 / 12.5 / 16 at 20 °C), '
      'dn 20 to 315 mm: nominal walls of its Table 2 (MRS 10 MPa, design coefficient 1.25); installed reference prices in EUR',
  url: 'https://www.cencenelec.eu',
  sources: [
    'EN 12201-2 - Plastics piping systems for water supply, and for drains and sewers under pressure - Polyethylene (PE) - Part 2: Pipes',
    'ISO 4427-2 - Plastics piping systems for water supply and for drainage and sewerage under pressure - Polyethylene (PE) - Part 2: Pipes',
    'ISO 4065 - Thermoplastics pipes - Universal wall thickness table',
    '$_sardinia: $_sardiniaUrl',
  ],
  prices: _en12201Prices,
);

/// IS 4985:2021, unplasticized PVC pipes for water supplies (India): classes
/// 1 to 6 (0.25 to 1.25 MPa at 27 °C), design stress 8.6 MPa, dn 20 to
/// 315 mm.
const is4985Standard = PipeStandard(
  id: 'is4985',
  code: 'IS 4985',
  material: PipeMaterial.pvc,
  polymer: 'PVC-U',
  densityKgM3: 1400,
  series: [
    PipeSeries(key: 'class1', name: 'PVC-U IS 4985 Class 1 (0.25 MPa)', pnBar: 2.5, walls: _is4985Class1, designStressMpa: 8.6),
    PipeSeries(key: 'class2', name: 'PVC-U IS 4985 Class 2 (0.4 MPa)', pnBar: 4, walls: _is4985Class2, designStressMpa: 8.6),
    PipeSeries(key: 'class3', name: 'PVC-U IS 4985 Class 3 (0.6 MPa)', pnBar: 6, walls: _is4985Class3, designStressMpa: 8.6),
    PipeSeries(key: 'class4', name: 'PVC-U IS 4985 Class 4 (0.8 MPa)', pnBar: 8, walls: _is4985Class4, designStressMpa: 8.6),
    PipeSeries(key: 'class5', name: 'PVC-U IS 4985 Class 5 (1.0 MPa)', pnBar: 10, walls: _is4985Class5, designStressMpa: 8.6),
    PipeSeries(key: 'class6', name: 'PVC-U IS 4985 Class 6 (1.25 MPa)', pnBar: 12.5, walls: _is4985Class6, designStressMpa: 8.6),
  ],
  brand: 'Generic (IS)',
  title: 'PVC-U pipes by IS 4985',
  description:
      'Unplasticized PVC pipes for water supplies of IS 4985:2021, class 1 to 6 (0.25 / 0.4 / 0.6 / 0.8 / 1.0 / 1.25 MPa at 27 °C), '
      'dn 20 to 315 mm: minimum walls of its Table 1 (design stress 8.6 MPa); supply reference prices in INR',
  url: 'https://archive.org/details/gov.in.is.4985.2021',
  sources: ['IS 4985:2021 - Unplasticized PVC pipes for water supplies - Specification (fourth revision), with Amendment 1 (2023)', '$_mjp: $_mjpUrl'],
  prices: _is4985Prices,
);

/// IS 4984:2016 with Amendment 2 (2022), polyethylene pipes for water supply
/// (India): the PN at 27 °C is 2σ/(SDR − 1) times 0.85 with σ the design
/// stress of its Table 1 (PE 100: 8 MPa, PE 80: 6.3 MPa), so PE 100 PN 4 to
/// 16 are SDR 33 / 21 / 17 / 13.6 / 11 / 9 and PE 80 PN 4 to 10 SDR 26 / 17 /
/// 13.6 / 11; dn 20 to 315 mm.
const is4984Standard = PipeStandard(
  id: 'is4984',
  code: 'IS 4984',
  material: PipeMaterial.pehd,
  polymer: 'PE',
  densityKgM3: 960,
  series: [
    PipeSeries(key: 'pe100_pn4', name: 'PE 100 IS 4984 PN 4 (SDR 33)', pnBar: 4, walls: _is4984Sdr33, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe100_pn6', name: 'PE 100 IS 4984 PN 6 (SDR 21)', pnBar: 6, walls: _is4984Sdr21, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe100_pn8', name: 'PE 100 IS 4984 PN 8 (SDR 17)', pnBar: 8, walls: _is4984Sdr17, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe100_pn10', name: 'PE 100 IS 4984 PN 10 (SDR 13.6)', pnBar: 10, walls: _is4984Sdr136, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe100_pn12_5', name: 'PE 100 IS 4984 PN 12.5 (SDR 11)', pnBar: 12.5, walls: _is4984Sdr11, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe100_pn16', name: 'PE 100 IS 4984 PN 16 (SDR 9)', pnBar: 16, walls: _is4984Sdr9, designStressMpa: 8 * 0.85),
    PipeSeries(key: 'pe80_pn4', name: 'PE 80 IS 4984 PN 4 (SDR 26)', pnBar: 4, walls: _is4984Sdr26, designStressMpa: 6.3 * 0.85),
    PipeSeries(key: 'pe80_pn6', name: 'PE 80 IS 4984 PN 6 (SDR 17)', pnBar: 6, walls: _is4984Sdr17, designStressMpa: 6.3 * 0.85),
    PipeSeries(key: 'pe80_pn8', name: 'PE 80 IS 4984 PN 8 (SDR 13.6)', pnBar: 8, walls: _is4984Sdr136, designStressMpa: 6.3 * 0.85),
    PipeSeries(key: 'pe80_pn10', name: 'PE 80 IS 4984 PN 10 (SDR 11)', pnBar: 10, walls: _is4984Sdr11, designStressMpa: 6.3 * 0.85),
  ],
  brand: 'Generic (IS)',
  title: 'PE pipes by IS 4984',
  description:
      'Polyethylene pipes for water supply of IS 4984:2016, PE 100 PN 4 / 6 / 8 / 10 / 12.5 / 16 (SDR 33 / 21 / 17 / 13.6 / 11 / 9) '
      'and PE 80 PN 4 / 6 / 8 / 10 (SDR 26 / 17 / 13.6 / 11) at 27 °C, dn 20 to 315 mm: minimum walls of its Table 4 '
      '(Amendment 2, 2022); supply reference prices in INR',
  url: 'https://archive.org/details/gov.in.is.4984.2016',
  sources: ['IS 4984:2016 - Polyethylene pipes for water supply - Specification (fifth revision), with Amendment 1 (2018) and Amendment 2 (2022)', '$_mjp: $_mjpUrl'],
  prices: _is4984Prices,
);

/// The standards of the generic pipe packs.
const pipeStandards = [iso1452Standard, en12201Standard, is4985Standard, is4984Standard];

// ----------------------------------------------------------------- rules

/// Nominal wall (mm) of ISO 4065 for the outside diameter [dn] (mm) and the
/// pipe series [s] = (SDR − 1)/2 of the R 10 series (20, 16, 12.5, 10, 8,
/// 6.3, 5, 4, 3.2, 2.5): e = dn/(2S + 1) with the exact series value
/// 10^(k/10), worked to 0.01 mm and rounded up to 0.1 mm, at least
/// [minimum] (1.5 mm in ISO 1452-2, 2.0 mm in EN 12201-2).
double iso4065Wall(int dn, double s, {double minimum = 0}) {
  final exact = math.pow(10, (math.log(s) / math.ln10 * 10).round() / 10).toDouble();
  final hundredths = (dn / (2 * exact + 1) * 100).round();
  return math.max((hundredths + 9) ~/ 10 / 10, minimum);
}

/// Pressure (MPa) of the rating of [p] (1 bar = 0.1 MPa).
double pipeRatingMpa(PipeSpec p) => p.pressureRatingM * barPerMeterHead / 10;

/// Hoop stress (MPa) in the wall of [p] at its rating (ISO 4065):
/// σ = P·(SDR − 1)/2 with SDR = outside diameter / wall; null without a
/// wall, a bore or a rating.
double? pipeRatingHoopStressMpa(PipeSpec p) {
  final e = p.wallThicknessMm;
  if (!(e > 0) || !(p.pressureRatingM > 0) || !(p.innerDiameterMm > 0)) return null;
  final sdr = (p.innerDiameterMm + 2 * e) / e;
  return pipeRatingMpa(p) * (sdr - 1) / 2;
}

/// What is wrong with [p] as the pipe of size [dn] (mm) of the class
/// [series], one line each (`code:item:value`); empty when it is right:
/// - `size_not_in_table`: the standard has no such size in that class;
/// - `outside_diameter`: bore + 2 walls is not [dn];
/// - `wall_below_table`: the wall is thinner than the table's;
/// - `class_above_wall`: at its rating the wall works above the design
///   stress of the standard (σ = P·(SDR − 1)/2, [tolerance] for the
///   rounding of the published classes and walls);
/// - `no_rating`: no wall or no pressure rating to check.
List<String> pipeStandardIssues(PipeSpec p, PipeSeries series, int dn, {double tolerance = 0.03}) {
  String f(double v) => v.toStringAsFixed(2);
  final table = series.walls[dn];
  if (table == null) return ['size_not_in_table:${p.id}:$dn'];
  final out = <String>[];
  final od = p.innerDiameterMm + 2 * p.wallThicknessMm;
  if ((od - dn).abs() > 0.05) out.add('outside_diameter:${p.id}:${f(od)}');
  if (p.wallThicknessMm < table - 0.005) out.add('wall_below_table:${p.id}:${f(p.wallThicknessMm)}<${f(table)}');
  final s = pipeRatingHoopStressMpa(p), limit = series.designStressAt(dn);
  if (s == null) {
    out.add('no_rating:${p.id}');
  } else if (s > limit * (1 + tolerance)) {
    out.add('class_above_wall:${p.id}:${f(s)}>${f(limit)}');
  }
  return out;
}

/// The standard, class and size of a pipe of the packs built here, from its
/// id (`iso1452_pn10_110`), or null for any other pipe.
({PipeStandard standard, PipeSeries series, int dn})? standardPipeOf(String id) {
  for (final st in pipeStandards) {
    for (final s in st.series) {
      final prefix = '${st.id}_${s.key}_';
      if (!id.startsWith(prefix)) continue;
      final dn = int.tryParse(id.substring(prefix.length));
      if (dn != null) return (standard: st, series: s, dn: dn);
    }
  }
  return null;
}

/// [pipeStandardIssues] of every pipe of [c] that is a pipe of a standard
/// of [pipeStandards] (by its id); the other pipes are not looked at.
List<String> standardCatalogIssues(Catalog c, {double tolerance = 0.03}) {
  final out = <String>[];
  for (final p in c.pipes) {
    final ref = standardPipeOf(p.id);
    if (ref != null) out.addAll(pipeStandardIssues(p, ref.series, ref.dn, tolerance: tolerance));
  }
  return out;
}

// ---------------------------------------------------------------- prices

/// Mass per metre (kg/m) of a pipe of outside diameter [dn] and wall [e]
/// (mm) of a material of density [densityKgM3]: π·(dn − e)·e·ρ.
double pipeMassKgPerM(double dn, double e, double densityKgM3) => math.pi * (dn - e) * e * densityKgM3 / 1e6;

/// The least-squares line price = a + b·m through (mass per metre, price)
/// pairs, weighted by 1/price² (relative errors). The fixed part a (laying,
/// joints) is never negative: when the free line crosses below the origin,
/// the price is fitted in proportion to the mass (a = 0).
(double, double) fitPipePrices(Iterable<(double, double)> massPrice) {
  var sw = 0.0, swm = 0.0, swmm = 0.0, swp = 0.0, swmp = 0.0;
  for (final (m, p) in massPrice) {
    final w = 1 / (p * p);
    sw += w;
    swm += w * m;
    swmm += w * m * m;
    swp += w * p;
    swmp += w * m * p;
  }
  final det = sw * swmm - swm * swm;
  final a = (swp * swmm - swm * swmp) / det;
  if (a >= 0) return (a, (sw * swmp - swm * swp) / det);
  return (0.0, swmp / swmm);
}

/// The published prices of [standard] as (mass per metre, price): its rows
/// (misprints left out), then the fit-only rows; empty without prices.
List<(double, double)> pipePriceRows(PipeStandard standard) {
  final book = standard.prices;
  final out = <(double, double)>[];
  if (book == null) return out;
  final density = standard.densityKgM3.toDouble();
  for (final row in book.rows.entries) {
    final walls = standard.seriesOf(row.key).walls;
    for (final price in row.value.entries) {
      if (book.misprints[row.key]?.contains(price.key) ?? false) continue;
      final e = walls[price.key];
      if (e == null) throw StateError('${standard.id}: no ${row.key} pipe of ${price.key} mm to price');
      out.add((pipeMassKgPerM(price.key.toDouble(), e, density), price.value));
    }
  }
  for (final (dn, e, price) in book.fitOnly) {
    out.add((pipeMassKgPerM(dn.toDouble(), e, density), price));
  }
  return out;
}

/// The price line (a, b) of [standard] ([fitPipePrices] of
/// [pipePriceRows]); (0, 0) without prices.
(double, double) pipePriceFit(PipeStandard standard) => standard.prices == null ? (0.0, 0.0) : fitPipePrices(pipePriceRows(standard));

/// Price per metre of the pipe of class [series] and size [dn] of
/// [standard]: the published row when there is one (and it is no misprint),
/// else the price line at the mass of the pipe, rounded to the decimals of
/// the document; 0 without prices.
double standardPipePrice(PipeStandard standard, PipeSeries series, int dn, {(double, double)? fit}) {
  final book = standard.prices;
  final e = series.walls[dn];
  if (book == null || e == null) return 0;
  final published = book.rows[series.key]?[dn];
  if (published != null && !(book.misprints[series.key]?.contains(dn) ?? false)) return published;
  final (a, b) = fit ?? pipePriceFit(standard);
  return _round(a + b * pipeMassKgPerM(dn.toDouble(), e, standard.densityKgM3.toDouble()), book.decimals);
}

/// Where the prices of [standard] come from and how the unpublished ones
/// were estimated (the `pricesSource` of its pack).
String pipePricesSource(PipeStandard standard) {
  final book = standard.prices;
  if (book == null) return '';
  final (a, b) = pipePriceFit(standard);
  final cur = book.currency;
  final fixed = a > 0 ? '${a.toStringAsFixed(2)} $cur/m + ' : '';
  final misprints = book.misprintText.isEmpty ? '' : ' (${book.misprintText})';
  final fitOnly = book.fitOnlyText.isEmpty ? '' : ' (${book.fitOnlyText})';
  final note = book.note.isEmpty ? '' : '; ${book.note}';
  return '${book.document}. Published rows used as printed$misprints; '
      'the other sizes and classes from a least-squares fit to the published rows$fitOnly: '
      'price = $fixed${b.toStringAsFixed(2)} $cur/kg × mass per metre (${standard.polymer} ${standard.densityKgM3} kg/m³)$note.';
}

double _round(double v, int decimals) => double.parse(v.toStringAsFixed(decimals));

// ----------------------------------------------------------------- packs

/// Where a pipe of [dn] mm serves: laterals and submains up to 32 mm,
/// submains and mains up to 110 mm, mains above (as the default catalogue).
Set<PipeUsage> _usage(int dn) => dn <= 32 ? {PipeUsage.lateral, PipeUsage.zone} : (dn <= 110 ? {PipeUsage.zone, PipeUsage.mainline} : {PipeUsage.mainline});

/// The pack of [standard]: one pipe per class and size of its tables, the
/// bore from the nominal outside diameter and the wall of the table, the
/// Hazen-Williams C and roughness the default catalogue gives the material
/// (PE up to 50 mm as its laterals), the class in metres of water, the
/// prices of [standardPipePrice].
CatalogPackFile standardPack(PipeStandard standard) {
  final book = standard.prices;
  final fit = pipePriceFit(standard);
  final pe = standard.material != PipeMaterial.pvc;
  final pipes = <PipeSpec>[];
  for (final s in standard.series) {
    for (final dn in s.walls.keys.toList()..sort()) {
      final e = s.walls[dn]!;
      final small = pe && dn <= 50;
      pipes.add(
        PipeSpec(
          id: '${standard.id}_${s.key}_$dn',
          name: '${s.name} $dn × ${e.toStringAsFixed(1)} mm',
          nominalMm: dn.toDouble(),
          innerDiameterMm: _round(dn.toDouble() - 2 * e, 2),
          material: standard.material,
          hazenC: small ? 145.0 : 150.0,
          roughnessMm: !pe ? 0.0015 : (small ? 0.003 : 0.002),
          pressureRatingM: _round(s.pnBar / barPerMeterHead, 2),
          wallThicknessMm: e,
          costPerM: standardPipePrice(standard, s, dn, fit: fit),
          usage: _usage(dn),
          supplier: standard.code,
        ),
      );
    }
  }
  final meta = CatalogPackMeta(
    id: standard.id,
    brand: standard.brand,
    name: standard.title,
    description: standard.description,
    source: standard.url,
    license: 'CC0-1.0',
    updated: standardPacksUpdated,
    author: 'OpenCADIrrigation',
    currency: book?.currency ?? '',
    pricesSource: pipePricesSource(standard),
    pricesDate: book?.date ?? '',
    sources: standard.sources,
  );
  return CatalogPackFile(meta, Catalog(pipes: pipes));
}

/// The PVC 1120 pressure pipes in inches of ASTM D2241 (SDR 21, 200 psi, and
/// SDR 26, 160 psi, 1 to 8 in; walls OD/SDR, at least 0.060 in) and ASTM
/// D1785 (Schedule 40, 1/2 to 8 in, and Schedule 80, 1/2 to 4 in): IPS
/// outside diameters, minimum walls and pressure ratings at 73 °F, without
/// prices.
CatalogPackFile astmPack() {
  // nominal size (in), DN, outside diameter (in)
  const sizes = [
    ('1/2', 15, 0.840),
    ('3/4', 20, 1.050),
    ('1', 25, 1.315),
    ('1-1/4', 32, 1.660),
    ('1-1/2', 40, 1.900),
    ('2', 50, 2.375),
    ('2-1/2', 65, 2.875),
    ('3', 80, 3.500),
    ('4', 100, 4.500),
    ('6', 150, 6.625),
    ('8', 200, 8.625),
  ];
  // Schedule 40 and 80 minimum walls (in) and ratings (psi), ASTM D1785
  const sch40 = {
    '1/2': (0.109, 600),
    '3/4': (0.113, 480),
    '1': (0.133, 450),
    '1-1/4': (0.140, 370),
    '1-1/2': (0.145, 330),
    '2': (0.154, 280),
    '2-1/2': (0.203, 300),
    '3': (0.216, 260),
    '4': (0.237, 220),
    '6': (0.280, 180),
    '8': (0.322, 160),
  };
  const sch80 = {
    '1/2': (0.147, 850),
    '3/4': (0.154, 690),
    '1': (0.179, 630),
    '1-1/4': (0.191, 520),
    '1-1/2': (0.200, 470),
    '2': (0.218, 400),
    '2-1/2': (0.276, 420),
    '3': (0.300, 370),
    '4': (0.337, 320),
  };
  String slug(String s) => s.replaceAll('-', '_').replaceAll('/', 'o');
  PipeSpec pipe(String id, String name, int dn, double od, double wall, double psi, Set<PipeUsage> usage) => PipeSpec(
    id: id,
    name: name,
    nominalMm: dn.toDouble(),
    innerDiameterMm: _round((od - 2 * wall) * 25.4, 1),
    wallThicknessMm: _round(wall * 25.4, 2),
    pressureRatingM: _round(psi / psiPerMeterHead, 1),
    hazenC: 150,
    roughnessMm: 0.0015,
    usage: usage,
    supplier: 'ASTM',
  );
  final pipes = <PipeSpec>[];
  for (final (sdr, psi) in [(21, 200), (26, 160)]) {
    for (final (nom, dn, od) in sizes) {
      if (dn < 25) continue;
      // ASTM D2241: wall = OD / SDR, at least 0.060 in
      final wall = (od / sdr) < 0.060 ? 0.060 : (od / sdr);
      pipes.add(pipe('astm_sdr${sdr}_${slug(nom)}', 'PVC SDR $sdr ($psi psi) $nom in IPS', dn, od, _round(wall, 3), psi.toDouble(), {PipeUsage.zone, PipeUsage.mainline}));
    }
  }
  for (final (label, table) in [('40', sch40), ('80', sch80)]) {
    for (final (nom, dn, od) in sizes) {
      final w = table[nom];
      if (w == null) continue;
      pipes.add(pipe('astm_sch${label}_${slug(nom)}', 'PVC Schedule $label ${w.$2} psi $nom in', dn, od, w.$1, w.$2.toDouble(), {if (dn <= 25) PipeUsage.lateral, PipeUsage.zone, PipeUsage.mainline}));
    }
  }
  const meta = CatalogPackMeta(
    id: 'astm',
    brand: 'Generic (ASTM)',
    name: 'PVC pipes by ASTM standard',
    description:
        'PVC 1120 pressure pipes in inches (IPS): ASTM D2241 SDR 21 (200 psi) and SDR 26 (160 psi), 1 to 8 in; '
        'ASTM D1785 Schedule 40 (1/2 to 8 in) and Schedule 80 (1/2 to 4 in); minimum walls and ratings at 73 °F',
    source: 'https://www.astm.org',
    license: 'CC0-1.0',
    updated: standardPacksUpdated,
    author: 'OpenCADIrrigation',
    sources: [
      'ASTM D2241 - Standard Specification for Poly(Vinyl Chloride) (PVC) Pressure-Rated Pipe (SDR Series)',
      'ASTM D1785 - Standard Specification for Poly(Vinyl Chloride) (PVC) Plastic Pipe, Schedules 40, 80, and 120',
    ],
  );
  return CatalogPackFile(meta, Catalog(pipes: pipes));
}

/// Every pack built here, as tool/gen_catalogs.dart writes them: the ASTM
/// inch pipes and the pack of each of [pipeStandards].
List<CatalogPackFile> standardCatalogPacks() => [astmPack(), for (final s in pipeStandards) standardPack(s)];
