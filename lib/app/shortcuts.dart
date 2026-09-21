/// Keyboard shortcuts and AutoCAD-style command aliases.
///
/// With the drawing focused, letters typed on the canvas build a command
/// (shown in the status bar); Enter or Space runs it, Esc clears it. The
/// aliases follow AutoCAD where an equivalent exists (L, PL, C, A, SPL, H,
/// T, D, DAN, DRA, LE, ME, Z/ZE, E, CO, RO, MI, SC, O, TR, EX, AR, U…) and
/// add irrigation tools (ZP, MP, SL, DT, O, V, WS, PU, B, AH, CUT…).
/// Portuguese/Spanish spellings are accepted too.
library;

import 'i18n.dart';
import 'state/controller.dart';

/// Non-tool command identifiers.
enum CadAction { select, zoomAll, zoomIn, zoomOut, erase, copy, cut, paste, undo, redo, selectAll, duplicate, array, feedEnvelope, run, check, autoFix, optimize, snap, ortho, gridSnap, gridDisplay, reports, save, open }

/// Command alias → [ToolId] or [CadAction].
const commandAliases = <String, Object>{
  // selection / navigation
  'S': CadAction.select, 'SEL': CadAction.select, 'SELECT': CadAction.select,
  'P': ToolId.pan, 'PAN': ToolId.pan, 'H': ToolId.hatch,
  'Z': CadAction.zoomAll, 'ZE': CadAction.zoomAll, 'ZA': CadAction.zoomAll, 'ZOOM': CadAction.zoomAll,
  'ZI': CadAction.zoomIn, 'ZO': CadAction.zoomOut,
  // drawing
  'L': ToolId.line, 'LINE': ToolId.line, 'LINHA': ToolId.line, 'LINEA': ToolId.line,
  'PL': ToolId.polyline, 'PLINE': ToolId.polyline, 'POLYLINE': ToolId.polyline, 'POLI': ToolId.polyline,
  'REC': ToolId.rect, 'RECT': ToolId.rect, 'RECTANG': ToolId.rect, 'RECTANGLE': ToolId.rect, 'RET': ToolId.rect,
  'C': ToolId.circle, 'CIRCLE': ToolId.circle, 'CIRCULO': ToolId.circle,
  'A': ToolId.arc, 'ARC': ToolId.arc, 'ARCO': ToolId.arc,
  'SPL': ToolId.spline, 'SPLINE': ToolId.spline,
  'HATCH': ToolId.hatch, 'HACHURA': ToolId.hatch, 'SOMBREADO': ToolId.hatch,
  'SY': ToolId.symbol, 'SYMBOL': ToolId.symbol, 'SIMBOLO': ToolId.symbol, 'I': ToolId.symbol,
  'T': ToolId.text, 'MT': ToolId.text, 'TEXT': ToolId.text, 'MTEXT': ToolId.text, 'TEXTO': ToolId.text,
  'D': ToolId.dimension, 'DIM': ToolId.dimension, 'DLI': ToolId.dimension, 'COTA': ToolId.dimension,
  'DAN': ToolId.dimAngular, 'DIMANG': ToolId.dimAngular, 'ANG': ToolId.dimAngular,
  'DRA': ToolId.dimRadial, 'DIMRAD': ToolId.dimRadial, 'RAIO': ToolId.dimRadial,
  'LE': ToolId.leader, 'LEADER': ToolId.leader, 'LEAD': ToolId.leader, 'CHAMADA': ToolId.leader,
  'CT': ToolId.contour, 'CONTOUR': ToolId.contour, 'CURVA': ToolId.contour, 'NIVEL': ToolId.contour,
  'SP': ToolId.spot, 'SPOT': ToolId.spot, 'PONTO': ToolId.spot, 'ELEV': ToolId.spot,
  'AR': ToolId.area, 'AREA': ToolId.area,
  'ME': ToolId.measure, 'MEASURE': ToolId.measure, 'DI': ToolId.measure, 'DIST': ToolId.measure, 'MEDIR': ToolId.measure,
  'PR': ToolId.profile, 'PROFILE': ToolId.profile, 'PERFIL': ToolId.profile,
  'PV': ToolId.pivot, 'PIVOT': ToolId.pivot, 'PIVO': ToolId.pivot, 'PIVOTE': ToolId.pivot,
  'AL': ToolId.alignImage, 'ALIGN': ToolId.alignImage, 'ALINHAR': ToolId.alignImage, 'ALINEAR': ToolId.alignImage,
  // editing
  'RO': ToolId.rotate, 'ROTATE': ToolId.rotate, 'GIRAR': ToolId.rotate, 'ROTACIONAR': ToolId.rotate,
  'MI': ToolId.mirror, 'MIRROR': ToolId.mirror, 'ESPELHAR': ToolId.mirror, 'SIMETRIA': ToolId.mirror,
  'SC': ToolId.scale, 'SCALE': ToolId.scale, 'ESCALA': ToolId.scale,
  'O': ToolId.offset, 'OFFSET': ToolId.offset, 'DESLOCAR': ToolId.offset, 'DESFASE': ToolId.offset,
  'TR': ToolId.trim, 'TRIM': ToolId.trim, 'APARAR': ToolId.trim, 'RECORTA': ToolId.trim,
  'EX': ToolId.extend, 'EXTEND': ToolId.extend, 'ESTENDER': ToolId.extend, 'ALARGAR': ToolId.extend,
  'CUT': ToolId.cutPipe, 'CUTPIPE': ToolId.cutPipe, 'CORTAR': ToolId.cutPipe, 'BR': ToolId.cutPipe,
  'ARRAY': CadAction.array, 'ARR': CadAction.array, 'MATRIZ': CadAction.array,
  'E': CadAction.erase, 'ERASE': CadAction.erase, 'DEL': CadAction.erase, 'APAGAR': CadAction.erase,
  'CO': CadAction.copy, 'CP': CadAction.copy, 'COPY': CadAction.copy, 'COPIAR': CadAction.copy,
  'RECORTAR': CadAction.cut, 'CLIPCUT': CadAction.cut,
  'PA': CadAction.paste, 'PASTE': CadAction.paste, 'COLAR': CadAction.paste, 'PEGAR': CadAction.paste,
  'U': CadAction.undo, 'UNDO': CadAction.undo,
  'REDO': CadAction.redo,
  'ALL': CadAction.selectAll, 'SA': CadAction.selectAll,
  'DUP': CadAction.duplicate,
  // hydraulic
  'ZP': ToolId.zonePipe, 'ZONE': ToolId.zonePipe, 'ZONA': ToolId.zonePipe,
  'MP': ToolId.mainPipe, 'MAIN': ToolId.mainPipe, 'PRINCIPAL': ToolId.mainPipe,
  'SL': ToolId.sprayline, 'SPRAY': ToolId.sprayline, 'LAT': ToolId.sprayline, 'LATERAL': ToolId.sprayline,
  'DT': ToolId.tape, 'TAPE': ToolId.tape, 'FITA': ToolId.tape, 'GOTEJO': ToolId.tape, 'CINTA': ToolId.tape,
  'OUT': ToolId.outlet, 'OUTLET': ToolId.outlet, 'EMISSOR': ToolId.outlet, 'EMISOR': ToolId.outlet, 'EM': ToolId.outlet,
  'V': ToolId.valve, 'VALVE': ToolId.valve, 'VALVULA': ToolId.valve,
  'WS': ToolId.supply, 'SUPPLY': ToolId.supply, 'FONTE': ToolId.supply, 'FUENTE': ToolId.supply,
  'PU': ToolId.pump, 'PUMP': ToolId.pump, 'BOMBA': ToolId.pump,
  'F': ToolId.misc, 'FIT': ToolId.misc, 'MISC': ToolId.misc, 'ACESSORIO': ToolId.misc,
  'J': ToolId.junction, 'JUNCTION': ToolId.junction, 'NO': ToolId.junction,
  'B': ToolId.block, 'BL': ToolId.block, 'BLOCK': ToolId.block, 'BLOCO': ToolId.block, 'BLOQUE': ToolId.block,
  'AH': ToolId.autohead, 'AUTOHEAD': ToolId.autohead, 'GRADE': ToolId.autohead, 'ASPERSORES': ToolId.autohead,
  'FE': CadAction.feedEnvelope, 'FEED': CadAction.feedEnvelope, 'ENVELOPE': CadAction.feedEnvelope, 'SUBMAIN': CadAction.feedEnvelope,
  // design / toggles / files
  'RUN': CadAction.run, 'DESIGN': CadAction.run, 'PROJETAR': CadAction.run,
  'CHK': CadAction.check, 'CHECK': CadAction.check,
  'FIX': CadAction.autoFix, 'AUTOFIX': CadAction.autoFix, 'CORRIGIR': CadAction.autoFix, 'CORREGIR': CadAction.autoFix,
  'OPT': CadAction.optimize, 'OPTIMIZE': CadAction.optimize, 'OTIMIZAR': CadAction.optimize, 'OPTIMIZAR': CadAction.optimize,
  'OS': CadAction.snap, 'OSNAP': CadAction.snap, 'SNAP': CadAction.snap,
  'OR': CadAction.ortho, 'ORTHO': CadAction.ortho, 'ORTO': CadAction.ortho,
  'GS': CadAction.gridSnap, 'GRIDSNAP': CadAction.gridSnap,
  'GR': CadAction.gridDisplay, 'GRID': CadAction.gridDisplay,
  'REP': CadAction.reports, 'REPORTS': CadAction.reports, 'RELATORIOS': CadAction.reports,
  'SAVE': CadAction.save, 'QSAVE': CadAction.save, 'SALVAR': CadAction.save,
  'OPEN': CadAction.open, 'ABRIR': CadAction.open,
};

/// Preferred (shortest) alias of a tool, for tooltips and menus.
String? aliasOf(ToolId id) {
  for (final e in commandAliases.entries) {
    if (e.value == id) return e.key;
  }
  return null;
}

/// Tooltip / menu label with the command alias appended, e.g. "Linha  [L]".
String toolLabel(I18n t, ToolId id) {
  final name = t('tool.${id.name}');
  final a = id == ToolId.select ? 'Esc' : aliasOf(id);
  return a == null ? name : '$name  [$a]';
}

/// i18n key naming a [CadAction] (menu/status labels).
String actionLabelKey(CadAction a) => switch (a) {
  CadAction.select => 'tool.select',
  CadAction.zoomAll => 'view.zoomAll',
  CadAction.zoomIn => 'view.zoomIn',
  CadAction.zoomOut => 'view.zoomOut',
  CadAction.erase => 'edit.delete',
  CadAction.copy => 'edit.clipCopy',
  CadAction.cut => 'edit.clipCut',
  CadAction.paste => 'edit.paste',
  CadAction.undo => 'edit.undo',
  CadAction.redo => 'edit.redo',
  CadAction.selectAll => 'edit.selectAll',
  CadAction.duplicate => 'edit.copy',
  CadAction.array => 'edit.array',
  CadAction.feedEnvelope => 'zone.feedEnvelope',
  CadAction.run => 'design.all',
  CadAction.check => 'design.check',
  CadAction.autoFix => 'adv.fixAll',
  CadAction.optimize => 'adv.optimize',
  CadAction.snap => 'status.snap',
  CadAction.ortho => 'status.ortho',
  CadAction.gridSnap => 'status.grid',
  CadAction.gridDisplay => 'sc.gridDisplay',
  CadAction.reports => 'menu.reports',
  CadAction.save => 'file.save',
  CadAction.open => 'file.open',
};

/// " → Linha ⏎" for a typed alias that matches a command, else "".
String commandTargetLabel(I18n t, String typed) {
  final target = commandAliases[typed];
  if (target == null) return '';
  final name = target is ToolId ? t('tool.${target.name}') : t(actionLabelKey(target as CadAction));
  return '  → $name ⏎';
}

class ShortcutGroup {
  const ShortcutGroup(this.titleKey, this.items);
  final String titleKey;

  /// (keys, i18n label key)
  final List<(String, String)> items;
}

/// Reference shown by Help → Keyboard shortcuts.
const shortcutGroups = <ShortcutGroup>[
  ShortcutGroup('sc.file', [
    ('Ctrl+S', 'file.save'),
    ('Ctrl+O', 'file.open'),
    ('Ctrl+I', 'file.importDrawing'),
    ('Ctrl+P', 'exp.pdf'),
    ('Ctrl+Alt+N', 'file.newTab'),
    ('Ctrl+Alt+W', 'file.closeTab'),
    ('Ctrl+Alt+→  /  Ctrl+Alt+←', 'sc.switchTab'),
    ('F5', 'design.all'),
  ]),
  ShortcutGroup('sc.edit', [
    ('Ctrl+Z', 'edit.undo'),
    ('Ctrl+Y  /  Ctrl+Shift+Z', 'edit.redo'),
    ('Ctrl+A', 'edit.selectAll'),
    ('Ctrl+C', 'edit.clipCopy'),
    ('Ctrl+X', 'edit.clipCut'),
    ('Ctrl+V', 'edit.paste'),
    ('Ctrl+D', 'edit.copy'),
    ('Del', 'edit.delete'),
    ('Esc', 'sc.cancel'),
    ('Enter', 'sc.finish'),
    ('Backspace', 'sc.undoPoint'),
    ('Enter', 'sc.repeat'),
    ('Ctrl + alça', 'sc.gripRemove'),
    ('Alça do meio', 'sc.gripInsert'),
  ]),
  ShortcutGroup('sc.view', [
    ('Home', 'view.zoomAll'),
    ('+  /  −', 'sc.zoom'),
    ('← ↑ → ↓', 'sc.pan'),
    ('Space', 'sc.panHold'),
    ('F2', 'sc.reports'),
    ('F3', 'status.snap'),
    ('F7', 'sc.gridDisplay'),
    ('F8', 'status.ortho'),
    ('Shift (segurar)', 'sc.angleLock'),
    ('F9', 'status.grid'),
    ('Pinça / 2 dedos', 'sc.touch'),
  ]),
  ShortcutGroup('sc.commands', [
    ('L  (pausa ou ⏎)', 'sc.autoRun'),
    ('L · LINE', 'tool.line'),
    ('PL · PLINE', 'tool.polyline'),
    ('REC · RECT', 'tool.rect'),
    ('C · CIRCLE', 'tool.circle'),
    ('A · ARC', 'tool.arc'),
    ('SPL · SPLINE', 'tool.spline'),
    ('H · HATCH', 'tool.hatch'),
    ('SY · SYMBOL', 'tool.symbol'),
    ('T · MT · TEXT', 'tool.text'),
    ('D · DIM', 'tool.dimension'),
    ('DAN · DIMANG', 'tool.dimAngular'),
    ('DRA · DIMRAD', 'tool.dimRadial'),
    ('LE · LEADER', 'tool.leader'),
    ('CT · CONTOUR', 'tool.contour'),
    ('SP · SPOT', 'tool.spot'),
    ('AR · AREA', 'tool.area'),
    ('ME · DI · DIST', 'tool.measure'),
    ('PR · PROFILE', 'tool.profile'),
    ('P · PAN', 'tool.pan'),
    ('S · SEL', 'tool.select'),
    ('Z · ZE', 'view.zoomAll'),
    ('ZI · ZO', 'sc.zoom'),
  ]),
  ShortcutGroup('sc.editCmds', [
    ('RO · ROTATE', 'tool.rotate'),
    ('MI · MIRROR', 'tool.mirror'),
    ('SC · SCALE', 'tool.scale'),
    ('O · OFFSET', 'tool.offset'),
    ('TR · TRIM', 'tool.trim'),
    ('EX · EXTEND', 'tool.extend'),
    ('CUT · BR', 'tool.cutPipe'),
    ('ARRAY · ARR', 'edit.array'),
    ('E · ERASE', 'edit.delete'),
    ('CO · CP · COPY', 'edit.clipCopy'),
    ('CLIPCUT', 'edit.clipCut'),
    ('PA · PASTE', 'edit.paste'),
    ('U · UNDO  /  REDO', 'edit.undo'),
    ('ALL', 'edit.selectAll'),
    ('OS · OR · GR · GS', 'sc.toggles'),
    ('RUN · CHK · REP', 'sc.designCmds'),
    ('SAVE · OPEN', 'file.save'),
  ]),
  ShortcutGroup('sc.hydraulic', [
    ('ZP · ZONE', 'tool.zonePipe'),
    ('MP · MAIN', 'tool.mainPipe'),
    ('SL · SPRAY · LAT', 'tool.sprayline'),
    ('DT · TAPE', 'tool.tape'),
    ('EM · OUT', 'tool.outlet'),
    ('V · VALVE', 'tool.valve'),
    ('WS · SUPPLY', 'tool.supply'),
    ('PU · PUMP', 'tool.pump'),
    ('F · FIT · MISC', 'tool.misc'),
    ('J · JUNCTION', 'tool.junction'),
    ('B · BLOCK', 'tool.block'),
    ('AH · AUTOHEAD', 'tool.autohead'),
    ('FE · FEED', 'zone.feedEnvelope'),
  ]),
];
