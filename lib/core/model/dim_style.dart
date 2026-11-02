/// The dimension style of a project (1.6.0 CAD): text height, arrowheads,
/// decimals and unit of every dimension, on the screen, on the sheet and in
/// the DXF/DWG export. The default draws dimensions as earlier versions
/// did (labels of the screen's size, no arrowheads on linear dimensions,
/// two decimals in the project's length unit), so an old file looks the
/// same. Kept in the project file under `dimStyle` (only when it is not
/// the default).
library;

import '../units.dart';
import 'project.dart';

/// The ends of the dimension lines.
enum DimArrow { none, arrow, tick, dot }

class DimStyle {
  const DimStyle({this.textHeightM = 0, this.arrow = DimArrow.none, this.arrowSizeM = 0, this.decimals = 2, this.unit, this.showUnit = true});

  /// Height of the dimension text in metres of the drawing; 0 keeps the
  /// size of the labels (the same on the screen at every zoom).
  final double textHeightM;
  final DimArrow arrow;

  /// Length of the arrowheads in metres; 0 makes them as long as the text
  /// is high (8 px on the screen with labels of the screen's size).
  final double arrowSizeM;

  /// Decimals of the lengths (0–6).
  final int decimals;

  /// The unit of the lengths; null follows the project's length unit.
  final LengthUnit? unit;

  /// Whether the unit is written after the value.
  final bool showUnit;

  static const standard = DimStyle();

  bool get isDefault => textHeightM == 0 && arrow == DimArrow.none && arrowSizeM == 0 && decimals == 2 && unit == null && showUnit;

  DimStyle copyWith({double? textHeightM, DimArrow? arrow, double? arrowSizeM, int? decimals, LengthUnit? unit, bool clearUnit = false, bool? showUnit}) => DimStyle(
    textHeightM: textHeightM ?? this.textHeightM,
    arrow: arrow ?? this.arrow,
    arrowSizeM: arrowSizeM ?? this.arrowSizeM,
    decimals: decimals ?? this.decimals,
    unit: clearUnit ? null : (unit ?? this.unit),
    showUnit: showUnit ?? this.showUnit,
  );

  /// The units the lengths are written in: [project]'s with this style's
  /// length unit.
  Units unitsFor(Units project) => unit == null ? project : project.copyWith(length: unit);

  /// [metres] as a dimension writes it in [project] units (`12.50 m`).
  String length(double metres, Units project) {
    final u = unitsFor(project);
    final v = fmt(u.lengthFromSi(metres), decimals.clamp(0, 6));
    return showUnit ? '$v ${u.lengthLabel}' : v;
  }

  /// The arrowhead length for text [textHeight] (both in metres).
  double arrowFor(double textHeight) => arrowSizeM > 0 ? arrowSizeM : textHeight;

  Map<String, dynamic> toJson() => {
    if (textHeightM != 0) 'h': textHeightM,
    if (arrow != DimArrow.none) 'arrow': arrow.name,
    if (arrowSizeM != 0) 'arrowSize': arrowSizeM,
    if (decimals != 2) 'dec': decimals,
    if (unit != null) 'unit': unit!.name,
    if (!showUnit) 'noUnit': true,
  };

  /// Reads a style; anything unreadable takes the default.
  static DimStyle fromJson(Object? json) {
    if (json is! Map) return standard;
    double d(String k) {
      final v = json[k];
      return v is num && v.isFinite && v > 0 ? v.toDouble() : 0;
    }

    final dec = json['dec'];
    return DimStyle(
      textHeightM: d('h'),
      arrow: DimArrow.values.asNameMap()[json['arrow']] ?? DimArrow.none,
      arrowSizeM: d('arrowSize'),
      decimals: dec is num && dec.isFinite ? dec.toInt().clamp(0, 6) : 2,
      unit: LengthUnit.values.asNameMap()[json['unit']],
      showUnit: json['noUnit'] != true,
    );
  }
}

/// The dimension style kept in the project file (top-level `dimStyle`,
/// read and written back by the project's own handling of the keys it
/// does not know).
extension ProjectDimStyle on Project {
  DimStyle get dimStyle {
    final raw = extra?['dimStyle'];
    if (raw is! Map) return DimStyle.standard;
    return _dimStyles[raw] ??= DimStyle.fromJson(raw);
  }

  set dimStyle(DimStyle s) {
    if (s.isDefault) {
      extra?.remove('dimStyle');
      if (extra?.isEmpty ?? false) extra = null;
      return;
    }
    (extra ??= {})['dimStyle'] = s.toJson();
  }
}

/// The style read from each stored map (the painter asks on every frame).
final _dimStyles = Expando<DimStyle>('dimStyle');
