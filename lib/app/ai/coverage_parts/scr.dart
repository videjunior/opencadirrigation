/// AI coverage of the functions added in 1.7.0 for the design scorecard
/// (keys and values as in lib/app/ai/ai_coverage.dart).
library;

const coverageScr = <String, String>{
  // ---- Design → Design scorecard (desktop menu and phone menu)
  'menu:scr.menu': 'op:design_scorecard',
  // ---- the dialog of lib/app/widgets/dialogs/scorecard_dialog.dart and its options
  'dialog:scorecard_dialog.scorecard': 'op:design_scorecard',
  'dialog:scorecard_dialog.scorecard.ageing': 'op:design_scorecard',
  'dialog:scorecard_dialog.scorecard.compare': 'op:design_scorecard',
  'dialog:scorecard_dialog.scorecard.remember': 'op:design_scorecard',
  'dialog:scorecard_dialog.scorecard.table': 'tool:get_report_table',
  'dialog:scorecard_dialog.scorecard.export': 'tool:export_file',
  'dialog:scorecard_dialog.scorecard.open': 'n/a:the buttons open the tool each improvement names; the operation names the same operation to run',
};
