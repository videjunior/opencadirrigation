/// Keyboard shortcuts: one dispatcher fed by the platform layer (a native
/// `keydown` listener in the browser, `HardwareKeyboard` elsewhere, see
/// `native_keys.dart`). It does not depend on which widget has focus, so
/// shortcuts keep working after clicking a palette button or a menu; it
/// steps aside for text fields, dialogs and open menus.
///
/// Key names follow the DOM `KeyboardEvent.key` convention ('F5', 'Escape',
/// 'Enter', 'ArrowLeft', ' ', 'a', '+').
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/model/entities.dart';
import '../shortcuts.dart';
import '../state/controller.dart';

export 'canvas_keys.dart';

/// One key press or release.
class HotkeyEvent {
  const HotkeyEvent(this.key, {this.code = '', this.ctrl = false, this.shift = false, this.alt = false, this.meta = false, this.repeat = false, this.down = true});

  /// DOM-style key name.
  final String key;

  /// Physical key code ('KeyN'), used to match a release with its press.
  final String code;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;
  final bool repeat;
  final bool down;

  /// Ctrl on Windows/Linux, Cmd on macOS: both count.
  bool get primary => ctrl || meta;
  bool get isModifier => key == 'Shift' || key == 'Control' || key == 'Alt' || key == 'Meta';

  /// The key as a single lower-case letter or digit, or null.
  String? get char => key.length == 1 && RegExp(r'[A-Za-z0-9]').hasMatch(key) ? key.toLowerCase() : null;

  static final _names = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.space: ' ',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
    LogicalKeyboardKey.add: '+',
    LogicalKeyboardKey.numpadAdd: '+',
    LogicalKeyboardKey.equal: '=',
    LogicalKeyboardKey.minus: '-',
    LogicalKeyboardKey.numpadSubtract: '-',
    LogicalKeyboardKey.shiftLeft: 'Shift',
    LogicalKeyboardKey.shiftRight: 'Shift',
    LogicalKeyboardKey.shift: 'Shift',
    LogicalKeyboardKey.controlLeft: 'Control',
    LogicalKeyboardKey.controlRight: 'Control',
    LogicalKeyboardKey.control: 'Control',
    LogicalKeyboardKey.altLeft: 'Alt',
    LogicalKeyboardKey.altRight: 'Alt',
    LogicalKeyboardKey.alt: 'Alt',
    LogicalKeyboardKey.metaLeft: 'Meta',
    LogicalKeyboardKey.metaRight: 'Meta',
    LogicalKeyboardKey.meta: 'Meta',
  };

  /// Converts a Flutter key event (desktop, tests).
  static HotkeyEvent fromKeyEvent(KeyEvent e) {
    final hk = HardwareKeyboard.instance;
    final k = e.logicalKey;
    var name = _names[k];
    if (name == null) {
      final ch = e.character;
      name = ch != null && ch.isNotEmpty && ch.trim().isNotEmpty ? ch : k.keyLabel;
      if (name.length == 1) name = hk.isShiftPressed ? name.toUpperCase() : name.toLowerCase();
    }
    final label = k.keyLabel;
    final code = label.length == 1 && RegExp(r'[A-Za-z]').hasMatch(label) ? 'Key${label.toUpperCase()}' : name;
    return HotkeyEvent(name, code: code, ctrl: hk.isControlPressed, shift: hk.isShiftPressed, alt: hk.isAltPressed, meta: hk.isMetaPressed, repeat: e is KeyRepeatEvent, down: e is! KeyUpEvent);
  }

  @override
  String toString() => 'HotkeyEvent(${down ? 'down' : 'up'} $key${ctrl ? ' ctrl' : ''}${meta ? ' meta' : ''}${shift ? ' shift' : ''}${alt ? ' alt' : ''})';
}

/// What the app shell offers the dispatcher.
abstract class HotkeyActions {
  ProjectController get controller;

  /// A dialog (or any route above the shell) is open.
  bool get modalOpen;

  /// A menu of the menu bar is open.
  bool get menuOpen;

  /// Closes the topmost dialog when it can be dismissed; false otherwise.
  bool dismissModal();
  void runDesign();
  void save();
  void open();
  void import();
  void exportPdf();
  void newTab();
  void closeTab();
  void nextTab();
  void prevTab();
  void toggleReports();
  void array();

  /// Opens the design check dialog (CHK command).
  void designCheck();
  void clipboard(CadAction action);
}

/// True when a text field has the keyboard focus (typing must not trigger
/// shortcuts).
bool editableTextFocused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText || ctx.findAncestorStateOfType<EditableTextState>() != null;
}

class Hotkeys {
  Hotkeys(this.actions);

  final HotkeyActions actions;

  /// A typed alias runs by itself after this pause (Enter or Space run it
  /// at once), so single-letter tools feel immediate without breaking
  /// multi-letter commands.
  static const autoRunDelay = Duration(milliseconds: 900);

  /// Keys the browser also binds (reload, save page, print…): consumed even
  /// when the app does nothing with them, so the page never reloads.
  static bool reservedByBrowser(HotkeyEvent e) {
    if (e.key == 'F5' || e.key == 'F2' || e.key == 'F3' || e.key == 'F7' || e.key == 'F8' || e.key == 'F9') return true;
    if (e.primary && !e.alt) return const {'s', 'o', 'p', 'i', 'd'}.contains(e.char);
    return false;
  }

  Timer? _autoRun;

  ProjectController get c => actions.controller;

  /// Handles one event; true when consumed (the platform layer then prevents
  /// the browser default and hides the key from Flutter).
  bool handle(HotkeyEvent e) {
    final target = c.keyTarget;
    if (e.isModifier) {
      if (e.key == 'Shift') target?.modifiersChanged();
      return false;
    }
    if (!e.down) {
      if (e.key == ' ') {
        target?.setSpaceHeld(false);
        return true;
      }
      return false;
    }
    final modal = actions.modalOpen;
    final menu = actions.menuOpen;
    final typing = editableTextFocused();
    // ---- application level: work from anywhere but a dialog
    if (_appKey(e, blocked: modal)) return true;
    if (modal && e.key == 'Escape' && actions.dismissModal()) return true;
    if (modal || menu) return reservedByBrowser(e);
    if (typing) return reservedByBrowser(e);
    if (_editKey(e)) return true;
    if (e.primary || e.alt) return false;
    return _canvasKey(e);
  }

  bool _appKey(HotkeyEvent e, {required bool blocked}) {
    if (e.primary && e.alt) {
      switch (e.code) {
        case 'KeyN':
          if (!blocked) actions.newTab();
          return true;
        case 'KeyW':
          if (!blocked) actions.closeTab();
          return true;
        case 'ArrowRight':
          if (!blocked) actions.nextTab();
          return true;
        case 'ArrowLeft':
          if (!blocked) actions.prevTab();
          return true;
      }
      return false;
    }
    if (e.primary) {
      switch (e.char) {
        case 's':
          if (!blocked) actions.save();
          return true;
        case 'o':
          if (!blocked) actions.open();
          return true;
        case 'i':
          if (!blocked) actions.import();
          return true;
        case 'p':
          if (!blocked) actions.exportPdf();
          return true;
      }
      return false;
    }
    if (e.alt) return false;
    switch (e.key) {
      case 'F5':
        if (!blocked) actions.runDesign();
        return true;
      case 'F2':
        if (!blocked) actions.toggleReports();
        return true;
    }
    return false;
  }

  /// Ctrl/Cmd editing shortcuts (never while typing in a field).
  bool _editKey(HotkeyEvent e) {
    if (!e.primary || e.alt) return false;
    switch (e.char) {
      case 'z':
        if (e.shift) {
          c.redo();
        } else {
          c.undo();
        }
        return true;
      case 'y':
        c.redo();
        return true;
      case 'a':
        c.selectAll();
        return true;
      case 'd':
        c.duplicateSelected();
        return true;
      case 'c':
        actions.clipboard(CadAction.copy);
        return true;
      case 'x':
        actions.clipboard(CadAction.cut);
        return true;
      case 'v':
        actions.clipboard(CadAction.paste);
        return true;
    }
    return false;
  }

  bool _canvasKey(HotkeyEvent e) {
    final k = c.keyTarget;
    switch (e.key) {
      case ' ':
        if (e.repeat) return true;
        if (c.command.isNotEmpty) {
          runCommand();
          return true;
        }
        k?.setSpaceHeld(true);
        return true;
      case 'Escape':
        if (c.command.isNotEmpty) {
          setCommand('');
          return true;
        }
        k?.toolKey('Escape');
        if (c.activeTool != ToolId.select && (k?.toolIdle ?? true)) c.setTool(ToolId.select);
        return true;
      case 'Enter':
        if (c.command.isNotEmpty) {
          runCommand();
          return true;
        }
        if (c.activeTool == ToolId.select) {
          // AutoCAD-style: Enter repeats the last drawing command
          c.setTool(c.lastTool);
          return true;
        }
        k?.toolKey('Enter');
        return true;
      case 'Backspace':
        if (c.command.isNotEmpty) {
          setCommand(c.command.substring(0, c.command.length - 1));
          return true;
        }
        k?.toolKey('Backspace');
        return true;
      case 'Delete':
        c.deleteSelected();
        return true;
      case 'F8':
        c.snap.ortho = !c.snap.ortho;
        c.track('ortho');
        c.refresh();
        return true;
      case 'F9':
        c.snap.grid = !c.snap.grid;
        c.refresh();
        return true;
      case 'F3':
        c.snap.enabled = !c.snap.enabled;
        c.track('snap');
        c.refresh();
        return true;
      case 'F7':
        c.showGrid = !c.showGrid;
        c.refresh();
        return true;
      case 'Home':
        c.zoomAll();
        return true;
      case 'ArrowLeft':
        c.camera.panPixels(const Offset(40, 0));
        c.track('pan');
        k?.redraw();
        return true;
      case 'ArrowRight':
        c.camera.panPixels(const Offset(-40, 0));
        c.track('pan');
        k?.redraw();
        return true;
      case 'ArrowUp':
        c.camera.panPixels(const Offset(0, 40));
        c.track('pan');
        k?.redraw();
        return true;
      case 'ArrowDown':
        c.camera.panPixels(const Offset(0, -40));
        c.track('pan');
        k?.redraw();
        return true;
      case '+':
      case '=':
        c.zoomBy(1.25);
        return true;
      case '-':
        c.zoomBy(0.8);
        return true;
    }
    final ch = e.char;
    if (ch != null) {
      // letters and digits build an AutoCAD-style command
      if (e.repeat) return true;
      setCommand(c.command + ch.toUpperCase());
      _scheduleAutoRun();
      return true;
    }
    return false;
  }

  void setCommand(String s) {
    _autoRun?.cancel();
    c.command = s;
    c.refresh();
  }

  void _scheduleAutoRun() {
    _autoRun?.cancel();
    final typed = c.command;
    if (!commandAliases.containsKey(typed)) return;
    _autoRun = Timer(autoRunDelay, () {
      if (c.command == typed) runCommand();
    });
  }

  /// Executes the typed command alias (see [commandAliases]).
  void runCommand() {
    final cmd = c.command;
    setCommand('');
    final target = commandAliases[cmd];
    if (target == null) {
      c.notify(c.t('msg.unknownCommand', {'cmd': cmd}));
      return;
    }
    c.track('command');
    if (target is ToolId) {
      if (target == ToolId.pump || target == ToolId.misc) c.toolSettings.pointScope = HydraulicScope.mainline;
      if (target == ToolId.outlet || target == ToolId.valve) c.toolSettings.pointScope = HydraulicScope.zone;
      c.setTool(target);
      return;
    }
    switch (target as CadAction) {
      case CadAction.select:
        c.setTool(ToolId.select);
      case CadAction.zoomAll:
        c.zoomAll();
      case CadAction.zoomIn:
        c.zoomBy(1.25);
      case CadAction.zoomOut:
        c.zoomBy(0.8);
      case CadAction.erase:
        c.deleteSelected();
      case CadAction.copy || CadAction.cut || CadAction.paste:
        actions.clipboard(target);
      case CadAction.undo:
        c.undo();
      case CadAction.redo:
        c.redo();
      case CadAction.selectAll:
        c.selectAll();
      case CadAction.duplicate:
        c.duplicateSelected();
      case CadAction.array:
        actions.array();
      case CadAction.feedEnvelope:
        final n = c.computeFeedEnvelope();
        c.notify(n == 0 ? c.t('msg.feedNone') : c.t('msg.feedDone', {'n': '$n'}));
      case CadAction.run:
        actions.runDesign();
      case CadAction.check:
        actions.designCheck();
      case CadAction.snap:
        c.snap.enabled = !c.snap.enabled;
        c.refresh();
      case CadAction.ortho:
        c.snap.ortho = !c.snap.ortho;
        c.refresh();
      case CadAction.gridSnap:
        c.snap.grid = !c.snap.grid;
        c.refresh();
      case CadAction.gridDisplay:
        c.showGrid = !c.showGrid;
        c.refresh();
      case CadAction.reports:
        actions.toggleReports();
      case CadAction.save:
        actions.save();
      case CadAction.open:
        actions.open();
    }
  }

  void dispose() => _autoRun?.cancel();
}
