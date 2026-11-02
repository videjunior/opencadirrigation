/// AI coverage (1.6.0 MOT+) of the ageing and clogging scenarios and the
/// network analyses that can be cancelled (UI-19), joined to [coverageMot].
library;

const coverageMotScenarios = <String, String>{
  'menu:life.menu': 'op:life_scenarios',
  'dialog:life_scenarios_dialog.lifeScenarios': 'op:life_scenarios',
  'dialog:life_scenarios_dialog.lifeScenarios.options': 'op:life_scenarios',
  // the Cancel buttons of the long analyses: the assistant waits for its own runs
  'dialog:network_ops_dialogs.criticality.cancel': 'n/a:the assistant waits for the analyses it runs; the button stops the one the user started',
};
