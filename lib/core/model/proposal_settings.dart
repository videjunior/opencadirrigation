/// Commercial settings of the quote (proposal) built from the bill of
/// materials: sale margin, labour, trenches, extra lines, discount, taxes,
/// freight, validity and terms. Stored in the project file (`proposal`).
library;

import 'dart:math' as math;

import 'read_report.dart' show KeyLog;

/// A free line of the quote (services, travel, commissioning…).
class ProposalExtra {
  ProposalExtra({this.description = '', this.unit = '', this.quantity = 1, this.unitPrice = 0});
  String description;
  String unit;
  double quantity;
  double unitPrice;

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {'desc': description, 'unit': unit, 'qty': quantity, 'price': unitPrice};
  static ProposalExtra fromJson(Map<String, dynamic> j) =>
      ProposalExtra(description: j['desc'] as String? ?? '', unit: j['unit'] as String? ?? '', quantity: (j['qty'] as num?)?.toDouble() ?? 1, unitPrice: (j['price'] as num?)?.toDouble() ?? 0);
}

class ProposalSettings {
  ProposalSettings({
    this.markupPct = 0,
    this.labourPct = 0,
    this.trenchCostPerM3 = 0,
    this.trenchWidthM = 0,
    this.beddingM = 0.1,
    this.discountPct = 0,
    this.taxPct = 0,
    this.freight = 0,
    this.validityDays = 15,
    this.paymentTerms = '',
    this.notes = '',
    this.annualBenefit = 0,
    List<ProposalExtra>? extras,
    this.crews = 1,
    Map<String, double>? productivity,
    this.mainlineDepthM = 0.6,
    this.zoneDepthM = 0,
    this.extra,
  }) : extras = extras ?? [],
       productivity = productivity ?? {};

  // 1.6.0 AUT (AUT-25)
  /// Burial depth (m, to the pipe axis) of the mainline pipes drawn without
  /// one of their own (the routing draws them buried): their trenches and
  /// the works schedule count them buried this deep (0.6 m by default, as
  /// `defaultMainlineDepthM`; 0 = on the surface).
  double mainlineDepthM;

  /// Burial depth (m) of the zone pipes and submains drawn without one of
  /// their own (0 = on the surface, the default); laterals and tapes stay
  /// on the surface. The automatic tools bury the zone pipes they draw this
  /// deep (0.4 m when 0).
  double zoneDepthM;

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  /// Margin over the cost of the materials (%), applied to every BOM line.
  double markupPct;

  /// Labour (installation) as a percentage of the material cost.
  double labourPct;

  /// Excavation and backfill per cubic metre of trench (project currency).
  double trenchCostPerM3;

  /// Trench width (m); 0 = from the pipe: outside diameter + 0.2 m, at
  /// least 0.3 m.
  double trenchWidthM;

  /// Bedding under the pipe (m), added to the trench depth.
  double beddingM;

  /// Discount over the subtotal (%).
  double discountPct;

  /// Taxes over the discounted subtotal (%).
  double taxPct;

  /// Freight and delivery (project currency), outside the taxes.
  double freight;

  /// Days the prices hold.
  int validityDays;
  String paymentTerms;
  String notes;

  /// Benefit the system brings every year (more or better harvest, saved
  /// labour or water; project currency), for the payback of the quote.
  double annualBenefit;
  final List<ProposalExtra> extras;

  /// Crews working at the same time, and the output of a crew per day by
  /// task of the construction schedule (task key → units per day) where it
  /// differs from the defaults (see `scheduleTasks`).
  int crews;
  final Map<String, double> productivity;

  /// Whether anything beyond the plain bill of materials was set.
  bool get isDefault =>
      markupPct == 0 &&
      labourPct == 0 &&
      trenchCostPerM3 == 0 &&
      discountPct == 0 &&
      taxPct == 0 &&
      freight == 0 &&
      extras.isEmpty &&
      paymentTerms.isEmpty &&
      notes.isEmpty &&
      validityDays == 15 &&
      trenchWidthM == 0 &&
      beddingM == 0.1 &&
      annualBenefit == 0 &&
      crews == 1 &&
      productivity.isEmpty &&
      mainlineDepthM == 0.6 &&
      zoneDepthM == 0 &&
      (extra?.isEmpty ?? true);

  /// Multiplies every amount of money by [factor] (currency conversion).
  void scalePrices(double factor) {
    trenchCostPerM3 *= factor;
    freight *= factor;
    annualBenefit *= factor;
    for (final x in extras) {
      x.unitPrice *= factor;
    }
  }

  Map<String, dynamic> toJson() => {
    'markup': markupPct,
    'labour': labourPct,
    'trenchM3': trenchCostPerM3,
    'trenchW': trenchWidthM,
    'bed': beddingM,
    'discount': discountPct,
    'tax': taxPct,
    'freight': freight,
    'validity': validityDays,
    if (paymentTerms.isNotEmpty) 'terms': paymentTerms,
    if (notes.isNotEmpty) 'notes': notes,
    if (annualBenefit != 0) 'benefit': annualBenefit,
    if (extras.isNotEmpty) 'extras': [for (final x in extras) x.toJson()],
    if (crews != 1) 'crews': crews,
    if (productivity.isNotEmpty) 'prod': productivity,
    if (mainlineDepthM != 0.6) 'mainD': mainlineDepthM,
    if (zoneDepthM != 0) 'zoneD': zoneDepthM,
    ...?extra,
  };

  static ProposalSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProposalSettings();
    // the fields this version does not know are kept (written back as read)
    final j = KeyLog(json);
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    final s = ProposalSettings(
      markupPct: d('markup', 0),
      labourPct: d('labour', 0),
      trenchCostPerM3: d('trenchM3', 0),
      trenchWidthM: d('trenchW', 0),
      beddingM: d('bed', 0.1),
      discountPct: d('discount', 0),
      taxPct: d('tax', 0),
      freight: d('freight', 0),
      validityDays: (j['validity'] as num?)?.toInt() ?? 15,
      paymentTerms: j['terms'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      annualBenefit: d('benefit', 0),
      extras: [for (final x in (j['extras'] as List?) ?? const []) ProposalExtra.fromJson(x as Map<String, dynamic>)],
      crews: math.max(1, (j['crews'] as num?)?.toInt() ?? 1),
      productivity: {
        for (final e in ((j['prod'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is num && (e.value as num) > 0) e.key as String: (e.value as num).toDouble(),
      },
      mainlineDepthM: math.max(0.0, d('mainD', 0.6)),
      zoneDepthM: math.max(0.0, d('zoneD', 0)),
    );
    s.extra = j.unread;
    return s;
  }
}
