/// Editing commands added in 1.6.0 on the controller, as an extension (the
/// way the block commands are kept in insert_block_tool.dart), and the
/// settings of the new tools. Each change is one undo step with its own
/// label in the history.
library;

import '../state/controller.dart';

/// Settings of the editing and selection tools of 1.6.0, one set per
/// project tab (see [EditCommands.editSettings]).
class EditSettings {
  /// Taps and clicks add to the selection (or take a selected item out of
  /// it) as Shift does: the touch screen has no Shift key.
  bool addToSelection = false;
}

final _editSettings = Expando<EditSettings>('editSettings');

/// The tools whose clicks Shift (or [EditSettings.addToSelection]) turns
/// into "add to the selection".
bool usesAddToSelection(ToolId t) => t == ToolId.select || t == ToolId.trim || t == ToolId.extend;

extension EditCommands on ProjectController {
  /// The settings of the 1.6.0 editing tools of this tab.
  EditSettings get editSettings => _editSettings[this] ??= EditSettings();

  /// Turns "add to the selection" on or off and says what taps do now.
  void setAddToSelection(bool on) {
    editSettings.addToSelection = on;
    notify(t(on ? 'sel.addModeOn' : 'sel.addModeOff'));
  }
}
