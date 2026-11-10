/// AI coverage of the digitiser of 1.7.0 (Design → Digitise a curve from a
/// picture) (keys and values as in lib/app/ai/ai_coverage.dart). The
/// assistant reads the chart of an attached picture with its own vision, so
/// the calibration, the clicks and the trace of the dialog are its reading,
/// and it hands the points to the same fits and catalogue entries.
library;

const coverageDgz = <String, String>{
  // ---- Design menu (desktop and phone)
  'menu:dgz.menu': 'op:fit_curve_points',
  // ---- the dialog of lib/app/widgets/dialogs/curve_digitiser_dialog.dart and its options
  'dialog:curve_digitiser_dialog.curveDigitiser': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.picture': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.kind': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.curve': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.swap': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.axisX': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.axisY': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.units': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.log': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.points': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.trace': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.fit': 'op:fit_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.target': 'op:apply_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.apply': 'op:apply_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.csv': 'op:export_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.copy': 'op:export_curve_points',
  'dialog:curve_digitiser_dialog.curveDigitiser.undo': 'n/a:the undo of the clicks inside the dialog; the assistant gives its points at once, and Edit → Undo takes back its change',
  'dialog:curve_digitiser_dialog.curveDigitiser.magnifier': 'n/a:the magnifier, zoom and pan of the picture help the user\'s hand; the assistant sees the picture itself',
};
