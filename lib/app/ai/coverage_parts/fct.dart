/// AI coverage of the functions added in 1.7.0 for the irrigation forecast (keys and values as in
/// lib/app/ai/ai_coverage.dart).
library;

const coverageFct = <String, String>{
  // ---- Design → Agronomy (desktop menu and phone menu)
  'menu:fct.menu': 'op:irrigation_forecast',
  // ---- the dialog of lib/app/widgets/dialogs/forecast_dialog.dart and its options
  'dialog:forecast_dialog.irrigationForecast': 'op:irrigation_forecast',
  'dialog:forecast_dialog.irrigationForecast.source': 'op:irrigation_forecast',
  'dialog:forecast_dialog.irrigationForecast.start': 'op:irrigation_forecast',
  'dialog:forecast_dialog.irrigationForecast.fetch': 'op:irrigation_forecast',
  'dialog:forecast_dialog.irrigationForecast.table': 'op:irrigation_forecast',
  'dialog:forecast_dialog.irrigationForecast.export': 'op:irrigation_forecast',
};
