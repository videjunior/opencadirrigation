/// AI coverage of the functions added in 1.6.0 for deliverables, second set (water permit tables, descriptive and calculation memorial, operation and maintenance plan, budget by compositions with BDI and schedule, life-cycle cost) (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coveragePrb = <String, String>{
  // ---- Reports → Technical documents (desktop menu and phone menu)
  'menu:prb.menu.permit': 'op:permit_table',
  'menu:prb.menu.memorial': 'op:export_document',
  'menu:prb.menu.om': 'op:export_document',
  'menu:prb.menu.budget': 'op:export_document',
  'menu:prb.menu.lcc': 'op:life_cycle_cost',
  // ---- the dialogs of lib/app/widgets/dialogs/deliverables_dialogs.dart and their options
  'dialog:deliverables_dialogs.permitTable': 'op:permit_table',
  'dialog:deliverables_dialogs.permitTable.source': 'op:set_permit_info',
  'dialog:deliverables_dialogs.permitTable.regime': 'op:set_permit_info',
  'dialog:deliverables_dialogs.permitTable.unit': 'op:set_permit_info',
  'dialog:deliverables_dialogs.permitTable.export': 'op:export_document',
  'dialog:deliverables_dialogs.memorial': 'op:document_text',
  'dialog:deliverables_dialogs.memorial.texts': 'op:set_memorial_texts',
  'dialog:deliverables_dialogs.memorial.export': 'op:export_document',
  'dialog:deliverables_dialogs.omPlan': 'op:document_text',
  'dialog:deliverables_dialogs.omPlan.settings': 'op:set_om_settings',
  'dialog:deliverables_dialogs.omPlan.export': 'op:export_document',
  'dialog:deliverables_dialogs.budget': 'op:document_text',
  'dialog:deliverables_dialogs.budget.bdi': 'op:set_budget_settings',
  'dialog:deliverables_dialogs.budget.rates': 'op:set_budget_settings',
  'dialog:deliverables_dialogs.budget.period': 'op:set_budget_settings',
  'dialog:deliverables_dialogs.budget.export': 'op:export_document',
  'dialog:deliverables_dialogs.lifeCycle': 'op:life_cycle_cost',
  'dialog:deliverables_dialogs.lifeCycle.settings': 'op:set_life_cycle_settings',
  'dialog:deliverables_dialogs.lifeCycle.categories': 'op:set_life_cycle_settings',
  'dialog:deliverables_dialogs.lifeCycle.export': 'op:export_document',
};
