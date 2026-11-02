/// Commercial settings of the quote (proposal) built from the bill of
/// materials: sale margin, labour, trenches, extra lines, discount, taxes,
/// freight, validity and terms. Stored in the project file (`proposal`).
library;

import 'dart:math' as math;

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
  }) : extras = extras ?? [],
       productivity = productivity ?? {};

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
      productivity.isEmpty;

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
  };

  static ProposalSettings fromJson(Map<String, dynamic>? j) {
    if (j == null) return ProposalSettings();
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return ProposalSettings(
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
    );
  }
}
