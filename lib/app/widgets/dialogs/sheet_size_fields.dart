/// The width and height of a sheet of custom size in the plot dialog (a
/// plotter roll, an elongated sheet for a long field): two fields in
/// millimetres, kept within what a PDF page holds.
library;

import 'package:flutter/material.dart';

import '../../../core/io/pdf_sheet.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';

/// The fields of [o]'s custom size; [onChanged] gets the options with the
/// size typed.
List<Widget> customSheetFields(ProjectController c, SheetOptions o, ValueChanged<SheetOptions> onChanged) {
  final t = c.t;
  double clamp(double v) => v.clamp(PageSize.minCustomMm, PageSize.maxCustomMm).toDouble();
  return [
    const SizedBox(height: 6),
    Row(
      children: [
        Expanded(
          child: NumField(
            key: const Key('plot_custom_w'),
            label: t('plot.customWidth'),
            value: o.customWidthMm,
            decimals: 0,
            signed: false,
            onChanged: (v) => onChanged(o.copyWith(customWidthMm: clamp(v))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NumField(
            key: const Key('plot_custom_h'),
            label: t('plot.customHeight'),
            value: o.customHeightMm,
            decimals: 0,
            signed: false,
            onChanged: (v) => onChanged(o.copyWith(customHeightMm: clamp(v))),
          ),
        ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Text(
        t('plot.customHint', {'min': fmtUi(PageSize.minCustomMm, 0), 'max': fmtUi(PageSize.maxCustomMm, 0)}),
        key: const Key('plot_custom_hint'),
        style: TextStyle(fontSize: 11, color: Cad.fg54),
      ),
    ),
  ];
}
