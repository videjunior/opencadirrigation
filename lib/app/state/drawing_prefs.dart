/// The drawing and snap settings remembered between visits and tabs
/// (1.6.0 CAD): the object snaps, ortho, polar steps, grid and tolerance,
/// the defaults of the drawing and editing tools (catalogue items, heads,
/// spacings, text sizes, offset distance, fillet radius…). A new tab starts
/// with the settings last used; they are kept in this browser (in the
/// app's folder on the desktop) under one key. What belongs to a project
/// (the elevation of the next contour, the text being typed) is not kept.
library;

import 'dart:convert';

import '../../core/design/pivot.dart' show PivotKind;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/lengthen.dart';
import '../io/prefs.dart';
import '../tools/cad_plus_commands.dart';
import '../tools/edit_commands.dart';
import 'controller.dart';
import 'test_env.dart';

/// The key of the settings in the preferences.
const drawingPrefsKey = 'draw.settings';

/// Whether the settings are remembered. Off under `flutter test` (each test
/// starts from the program's defaults) unless a test turns it on.
bool rememberDrawingSettings = !underFlutterTest;

/// The settings of [c] as kept in the preferences.
Map<String, dynamic> drawingSettingsJson(ProjectController c) {
  final s = c.snap, t = c.toolSettings, e = c.editSettings, x = c.cadPlus;
  return {
    'snap': {
      'on': s.enabled,
      'grid': s.grid,
      'gridSize': s.gridSize,
      'ortho': s.ortho,
      'tol': s.tolerancePx,
      'polar': s.polarStepDeg,
      'modes': [for (final m in snapModes) if (s.modes.contains(m)) m],
    },
    'tool': {
      'author': t.commentAuthor,
      'zonePipe': t.zonePipeSpecId,
      'mainPipe': t.mainPipeSpecId,
      'lateralPipe': t.lateralPipeSpecId,
      'outlet': t.outletSpecId,
      'nozzle': t.nozzleId,
      'head': t.headM,
      'spacing': t.spacing,
      'offset': t.offset,
      'arc': t.arcDeg,
      'tape': t.tapeSpecId,
      'tapeInlet': t.tapeInletHeadM,
      'valve': t.valveSpecId,
      'pump': t.pumpSpecId,
      'misc': t.miscSpecId,
      'miscSetting': t.miscSettingM,
      'contourInterval': t.contourInterval,
      'askElevation': t.askElevation,
      'contourAuto': t.contourAutoIncrement,
      'contourSmooth': t.contourSmooth,
      'pivotKind': t.pivotKind.name,
      'pivotSpan': t.pivotSpan,
      'pivotDepth': t.pivotDepthMm,
      'pivotHours': t.pivotHours,
      'pivotEnd': t.pivotEndPressureM,
      'pivotTravel': t.pivotTravelM,
      'alignKeepScale': t.alignKeepScale,
      'textHeight': t.textHeight,
      'dimOffset': t.dimensionOffset,
      'outletHalf': t.outletOffsetHalf,
      'copyOnTransform': t.copyOnTransform,
      'mirrorKeep': t.mirrorKeepSource,
      'offsetDistance': t.offsetDistance,
      'splitOnInsert': t.splitPipesOnInsert,
      'keepConnections': t.keepConnections,
      'hatchAngle': t.hatchAngle,
      'hatchSpacing': t.hatchSpacing,
      'hatchSolid': t.hatchSolid,
      'symbol': t.symbolKind.name,
      'symbolSize': t.symbolSize,
      'splineClosed': t.splineClosed,
      'angularRadius': t.angularDimRadius,
      'radialDiameter': t.radialDiameter,
      'stations': t.controllerStations,
      'volts': t.controllerVolts,
    },
    'edit': {
      'lassoCrossing': e.lassoCrossing,
      'fillet': e.filletRadius,
      'chamfer1': e.chamferDistance1,
      'chamfer2': e.chamferDistance2,
      'measure': e.measureMode.name,
      'lengthenMode': x.lengthenMode.name,
      'lengthen': x.lengthenValue,
      'boundaryArea': x.boundaryAsArea,
      'dynamicInput': x.dynamicInput,
      'touchLoupe': x.touchLoupe,
      'editDuringDesign': c.editDuringDesign,
    },
  };
}

/// Puts the settings [j] (as [drawingSettingsJson] writes them) into [c];
/// a value that is missing, of another type or out of range — or a
/// catalogue item [catalog] does not have — leaves the setting as it is.
void applyDrawingSettings(ProjectController c, Map<String, dynamic> j, {Catalog? catalog}) {
  final cat = catalog ?? c.project.catalog;
  Map<String, dynamic> part(String k) => j[k] is Map ? (j[k] as Map).cast<String, dynamic>() : const {};
  final sn = part('snap'), tl = part('tool'), ed = part('edit');
  bool? b(Map<String, dynamic> m, String k) => m[k] is bool ? m[k] as bool : null;
  double? d(Map<String, dynamic> m, String k, {double min = -1e12, double max = 1e12}) {
    final v = m[k];
    return v is num && v.isFinite && v >= min && v <= max ? v.toDouble() : null;
  }

  int? i(Map<String, dynamic> m, String k, {int min = 0, int max = 1 << 30}) {
    final v = m[k];
    return v is num && v.isFinite && v >= min && v <= max ? v.toInt() : null;
  }

  String? str(Map<String, dynamic> m, String k) => m[k] is String ? m[k] as String : null;
  // a catalogue item: kept only when the catalogue has it (null = sized by the design)
  String? pipe(String k, String? now) => tl.containsKey(k) && (tl[k] == null || cat.pipe('${tl[k]}') != null) ? tl[k] as String? : now;
  T? named<T extends Enum>(List<T> values, Object? v) => v is String ? values.asNameMap()[v] : null;

  final s = c.snap;
  s
    ..enabled = b(sn, 'on') ?? s.enabled
    ..grid = b(sn, 'grid') ?? s.grid
    ..gridSize = d(sn, 'gridSize', min: 0.001, max: 10000) ?? s.gridSize
    ..ortho = b(sn, 'ortho') ?? s.ortho
    ..tolerancePx = d(sn, 'tol', min: 1, max: 50) ?? s.tolerancePx
    ..polarStepDeg = d(sn, 'polar', min: 0, max: 90) ?? s.polarStepDeg;
  if (sn['modes'] is List) {
    s.modes
      ..clear()
      ..addAll([
        for (final m in sn['modes'] as List)
          if (snapModes.contains(m)) m as String,
      ]);
  }
  final t = c.toolSettings;
  t
    ..commentAuthor = str(tl, 'author') ?? t.commentAuthor
    ..zonePipeSpecId = pipe('zonePipe', t.zonePipeSpecId)
    ..mainPipeSpecId = pipe('mainPipe', t.mainPipeSpecId)
    ..lateralPipeSpecId = pipe('lateralPipe', t.lateralPipeSpecId)
    ..headM = d(tl, 'head', min: 0.5, max: 120) ?? t.headM
    ..spacing = d(tl, 'spacing', min: 0.05, max: 100) ?? t.spacing
    ..offset = d(tl, 'offset', min: 0, max: 100) ?? t.offset
    ..arcDeg = d(tl, 'arc', min: 1, max: 360) ?? t.arcDeg
    ..tapeInletHeadM = d(tl, 'tapeInlet', min: 0.1, max: 100) ?? t.tapeInletHeadM
    ..miscSettingM = d(tl, 'miscSetting', min: 0, max: 200) ?? t.miscSettingM
    ..contourInterval = d(tl, 'contourInterval', min: 0.001, max: 1000) ?? t.contourInterval
    ..askElevation = b(tl, 'askElevation') ?? t.askElevation
    ..contourAutoIncrement = b(tl, 'contourAuto') ?? t.contourAutoIncrement
    ..contourSmooth = b(tl, 'contourSmooth') ?? t.contourSmooth
    ..pivotKind = named(PivotKind.values, tl['pivotKind']) ?? t.pivotKind
    ..pivotSpan = d(tl, 'pivotSpan', min: 1, max: 200) ?? t.pivotSpan
    ..pivotDepthMm = d(tl, 'pivotDepth', min: 0.1, max: 100) ?? t.pivotDepthMm
    ..pivotHours = d(tl, 'pivotHours', min: 0.1, max: 400) ?? t.pivotHours
    ..pivotEndPressureM = d(tl, 'pivotEnd', min: 0, max: 100) ?? t.pivotEndPressureM
    ..pivotTravelM = d(tl, 'pivotTravel', min: 1, max: 100000) ?? t.pivotTravelM
    ..alignKeepScale = b(tl, 'alignKeepScale') ?? t.alignKeepScale
    ..textHeight = d(tl, 'textHeight', min: 0.001, max: 1000) ?? t.textHeight
    ..dimensionOffset = d(tl, 'dimOffset', min: -1000, max: 1000) ?? t.dimensionOffset
    ..outletOffsetHalf = b(tl, 'outletHalf') ?? t.outletOffsetHalf
    ..copyOnTransform = b(tl, 'copyOnTransform') ?? t.copyOnTransform
    ..mirrorKeepSource = b(tl, 'mirrorKeep') ?? t.mirrorKeepSource
    ..offsetDistance = d(tl, 'offsetDistance', min: 0.0001, max: 100000) ?? t.offsetDistance
    ..splitPipesOnInsert = b(tl, 'splitOnInsert') ?? t.splitPipesOnInsert
    ..keepConnections = b(tl, 'keepConnections') ?? t.keepConnections
    ..hatchAngle = d(tl, 'hatchAngle', min: -360, max: 360) ?? t.hatchAngle
    ..hatchSpacing = d(tl, 'hatchSpacing', min: 0.001, max: 1000) ?? t.hatchSpacing
    ..hatchSolid = b(tl, 'hatchSolid') ?? t.hatchSolid
    ..symbolKind = named(SymbolKind.values, tl['symbol']) ?? t.symbolKind
    ..symbolSize = d(tl, 'symbolSize', min: 0.01, max: 1000) ?? t.symbolSize
    ..splineClosed = b(tl, 'splineClosed') ?? t.splineClosed
    ..angularDimRadius = d(tl, 'angularRadius', min: 0.01, max: 1000) ?? t.angularDimRadius
    ..radialDiameter = b(tl, 'radialDiameter') ?? t.radialDiameter
    ..controllerStations = i(tl, 'stations', min: 1, max: 999) ?? t.controllerStations
    ..controllerVolts = d(tl, 'volts', min: 1, max: 1000) ?? t.controllerVolts;
  final outlet = str(tl, 'outlet');
  if (outlet != null && cat.outlet(outlet) != null) {
    t.outletSpecId = outlet;
    final nz = tl['nozzle'];
    if (nz == null || (nz is String && cat.outlet(outlet)!.nozzles.any((n) => n.id == nz))) t.nozzleId = nz as String?;
  }
  final tape = str(tl, 'tape');
  if (tape != null && cat.tape(tape) != null) t.tapeSpecId = tape;
  final valve = str(tl, 'valve'), misc = str(tl, 'misc');
  if (valve != null && cat.valve(valve) != null) t.valveSpecId = valve;
  if (misc != null && cat.valve(misc) != null) t.miscSpecId = misc;
  final pump = str(tl, 'pump');
  if (pump != null && cat.pump(pump) != null) t.pumpSpecId = pump;
  final e = c.editSettings;
  e
    ..lassoCrossing = b(ed, 'lassoCrossing') ?? e.lassoCrossing
    ..filletRadius = d(ed, 'fillet', min: 0, max: 100000) ?? e.filletRadius
    ..chamferDistance1 = d(ed, 'chamfer1', min: 0.0001, max: 100000) ?? e.chamferDistance1
    ..chamferDistance2 = d(ed, 'chamfer2', min: 0.0001, max: 100000) ?? e.chamferDistance2
    ..measureMode = named(MeasureMode.values, ed['measure']) ?? e.measureMode;
  final x = c.cadPlus;
  x
    ..lengthenMode = named(LengthenMode.values, ed['lengthenMode']) ?? x.lengthenMode
    ..lengthenValue = d(ed, 'lengthen', min: -1e6, max: 1e6) ?? x.lengthenValue
    ..boundaryAsArea = b(ed, 'boundaryArea') ?? x.boundaryAsArea
    ..dynamicInput = b(ed, 'dynamicInput') ?? x.dynamicInput
    ..touchLoupe = b(ed, 'touchLoupe') ?? x.touchLoupe;
  c.editDuringDesign = b(ed, 'editDuringDesign') ?? c.editDuringDesign;
}

/// The last settings written, by controller (only what changed is written).
final _written = Expando<String>('drawingPrefs');

/// Starts [c] with the settings kept and keeps them as they change (read
/// again after every change the controller announces; written only when
/// they differ). Does nothing while [rememberDrawingSettings] is off.
void attachDrawingPrefs(ProjectController c) {
  if (!rememberDrawingSettings) return;
  final raw = getPref(drawingPrefsKey);
  if (raw != null) {
    try {
      final j = jsonDecode(raw);
      if (j is Map) applyDrawingSettings(c, j.cast<String, dynamic>());
    } on Object {
      // a damaged value: the defaults
    }
  }
  _written[c] = jsonEncode(drawingSettingsJson(c));
  c.addListener(() => saveDrawingPrefs(c));
}

/// Writes the settings of [c] when they changed since the last write.
void saveDrawingPrefs(ProjectController c) {
  if (!rememberDrawingSettings || c.disposed) return;
  final now = jsonEncode(drawingSettingsJson(c));
  if (_written[c] == now) return;
  _written[c] = now;
  setPref(drawingPrefsKey, now);
}
