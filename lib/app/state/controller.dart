import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../../core/design/advisor.dart';
import '../../core/design/auto_fix.dart';
import '../../core/design/block_generator.dart';
import '../../core/design/densogram.dart';
import '../../core/design/design_check.dart';
import '../../core/design/network_builder.dart';
import '../../core/design/report_tables.dart';
import '../../core/design/results.dart';
import '../../core/hydraulics/lateral.dart';
import '../../core/io/dem_online.dart';
import '../../core/io/dem_tiff.dart';
import '../../core/io/dwg.dart';
import '../../core/io/dxf.dart';
import '../../core/io/geo.dart';
import '../../core/io/geoimage.dart';
import '../../core/io/kml.dart';
import '../../core/io/points_csv.dart';
import '../../core/io/project_export.dart';
import '../../core/io/shp.dart';
import '../../core/model/catalog.dart';
import '../../core/model/currency.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/model/spatial_index.dart';
import '../../core/model/split.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../canvas/camera.dart';
import '../i18n.dart';
import '../io/document.dart';
import '../io/http.dart';
import '../io/prefs.dart';
import '../io/project_store.dart';
import '../keys/canvas_keys.dart';
import 'design_runner.dart';

enum ToolId {
  select,
  pan,
  line,
  polyline,
  rect,
  circle,
  arc,
  spline,
  hatch,
  symbol,
  text,
  dimension,
  dimAngular,
  dimRadial,
  leader,
  contour,
  spot,
  area,
  zonePipe,
  mainPipe,
  sprayline,
  tape,
  outlet,
  valve,
  supply,
  pump,
  misc,
  junction,
  block,
  autohead,
  measure,
  rotate,
  mirror,
  scale,
  offset,
  trim,
  extend,
  cutPipe,
  profile,
  pivot,
  alignImage,
  controller,
  wire,
  dimOrdinate,
}

enum OverlayMode { none, velocity, pressure, sizes, minMax, densogram }

/// Background map tiles (needs a georeference): free tile services, the
/// Google Map Tiles API (with the user's own key) and a custom XYZ template.
enum BaseMap {
  none,
  streets,
  topo,
  carto,
  satellite,
  esriStreets,
  esriTopo,
  googleRoads,
  googleSatellite,
  googleHybrid,
  googleTerrain,
  custom;

  /// Served by the Google Map Tiles API: needs [ProjectController.googleMapsKey].
  bool get isGoogle => name.startsWith('google');
}

class SnapSettings {
  bool enabled = true;
  bool grid = false;
  double gridSize = 1;
  bool ortho = false;
  double tolerancePx = 10;
}

/// Current defaults used by the creation tools.
class ToolSettings {
  String? zonePipeSpecId;
  String? mainPipeSpecId;
  String? lateralPipeSpecId;
  String outletSpecId = 'micro';
  String? nozzleId = 'm50';
  double headM = 15;
  double spacing = 4;
  double offset = 0;
  double arcDeg = 360;
  String tapeSpecId = 'drip16_16_50';
  double tapeInletHeadM = 10;
  String valveSpecId = 'ev50';
  String pumpSpecId = 'pump_mid';
  String miscSpecId = 'gate50';
  double miscSettingM = 25;
  HydraulicScope pointScope = HydraulicScope.zone;
  double contourElevation = 100;
  double spotElevation = 100;

  /// Contours: interval added after each contour, and whether the elevation
  /// is asked for when a contour / spot height is finished.
  double contourInterval = 1;
  bool askElevation = true;
  bool contourAutoIncrement = true;

  /// Replace the clicked vertices by a smooth spline through them.
  bool contourSmooth = false;

  // pivots / linear moves
  PivotKind pivotKind = PivotKind.pivot;
  double pivotSpan = 50;
  double pivotDepthMm = 8;
  double pivotHours = 24;
  double pivotEndPressureM = 14;
  double pivotTravelM = 400;

  // align by two points
  bool alignKeepScale = false;
  double textHeight = 1;
  String text = 'Text';
  double dimensionOffset = 2;
  bool outletOffsetHalf = true;

  // editing tools
  bool copyOnTransform = false;
  bool mirrorKeepSource = true;
  double offsetDistance = 2;
  bool splitPipesOnInsert = true;

  /// Dragging the node of a pipe / lateral drags along every pipe end and
  /// hydraulic item that shared that point, so the junction is not broken.
  bool keepConnections = true;

  // drawing tools
  double hatchAngle = 45;
  double hatchSpacing = 1;
  bool hatchSolid = false;
  SymbolKind symbolKind = SymbolKind.tree;
  double symbolSize = 2;
  bool splineClosed = false;
  String leaderText = 'Note';
  double angularDimRadius = 3;

  /// Radial dimension tool writes the diameter (Ø) instead of the radius.
  bool radialDiameter = false;

  // electrical
  int controllerStations = 12;
  double controllerVolts = 24;
}

/// Rectangular / polar array options (Edit → Array).
class ArrayOptions {
  ArrayOptions({this.polar = false, this.rows = 2, this.cols = 2, this.dx = 5, this.dy = 5, this.angleDeg = 0, this.count = 6, this.center = Pt.zero, this.totalAngleDeg = 360, this.rotateItems = true});
  bool polar;
  int rows;
  int cols;
  double dx;
  double dy;
  double angleDeg;
  int count;
  Pt center;
  double totalAngleDeg;
  bool rotateItems;
}

class _UndoState {
  _UndoState(this.entities, this.rest, this.label, this.time);
  final List<Entity> entities;
  final Map<String, dynamic> rest;

  /// Label of the action that follows this state (`hist.*` key, optional
  /// `|argument` for the entity kind or a count).
  final String label;
  final DateTime time;
}

/// One row of the history panel (Photoshop-style states).
class HistoryEntry {
  const HistoryEntry({required this.index, required this.label, required this.time, required this.current, required this.future});

  /// Position in the timeline (0 = initial state).
  final int index;

  /// `hist.*` key, optionally followed by `|argument`.
  final String label;
  final DateTime time;

  /// The state the drawing is in now.
  final bool current;

  /// An undone action (available through redo).
  final bool future;
}

class ProjectController extends ChangeNotifier {
  ProjectController({LocalProjectStore? store}) : store = store ?? LocalProjectStore() {
    _init();
  }

  Project _project = Project();
  Project get project => _project;
  set project(Project p) {
    _project = p;
    _editSeq++;
  }

  /// Bumped by every edit (snapshot, undo/redo, project replaced); a running
  /// design compares it to discard results that no longer match the project
  /// and the spatial index is rebuilt when it changes.
  int _editSeq = 0;
  int get editSeq => _editSeq;

  SpatialIndex? _index;
  int _indexSeq = -1;
  int _indexCount = -1;
  Project? _indexProject;

  /// R-tree over the entity bounds, rebuilt lazily after each edit (or when
  /// the project or the number of entities changed behind our back). Used
  /// by the painter (viewport culling), the hit test, snapping and window
  /// selection instead of scanning every entity.
  SpatialIndex get index {
    final idx = _index;
    if (idx != null && _indexSeq == _editSeq && _indexCount == _project.entities.length && identical(_indexProject, _project)) return idx;
    final built = SpatialIndex.build(_project.entities);
    _index = built;
    _indexSeq = _editSeq;
    _indexCount = _project.entities.length;
    _indexProject = _project;
    return built;
  }

  /// Marks the entity geometry as changed outside [mutate] (the spatial
  /// index is rebuilt on the next query).
  void entitiesChanged() => _editSeq++;
  DesignResults? results;
  final Set<String> selection = {};
  String? hoverId;
  final Camera camera = Camera();
  ToolId activeTool = ToolId.select;
  final SnapSettings snap = SnapSettings();
  final ToolSettings toolSettings = ToolSettings();
  OverlayMode overlay = OverlayMode.velocity;
  BaseMap baseMap = BaseMap.none;
  double baseMapOpacity = 0.8;

  /// The user's Google Maps Platform API key (Map Tiles API), kept in the
  /// browser only; null until the user enters one.
  String? googleMapsKey = _savedPref('basemap.googleKey');

  /// XYZ tile URL template of the custom base map (`{z}`, `{x}`, `{y}`,
  /// optional `{s}` subdomain and `{-y}` TMS row).
  String customTileUrl = _savedPref('basemap.customUrl') ?? '';

  /// Bumped whenever the key or the template is saved: the map layer
  /// then drops its sessions, cached tiles and last error and retries.
  int baseMapEpoch = 0;

  static String? _savedPref(String key) {
    final v = getPref(key)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  void setGoogleMapsKey(String? key) {
    final k = key?.trim();
    googleMapsKey = k == null || k.isEmpty ? null : k;
    baseMapEpoch++;
    if (googleMapsKey == null) {
      removePref('basemap.googleKey');
    } else {
      setPref('basemap.googleKey', googleMapsKey!);
    }
    notifyListeners();
  }

  void setCustomTileUrl(String url) {
    customTileUrl = url.trim();
    baseMapEpoch++;
    if (customTileUrl.isEmpty) {
      removePref('basemap.customUrl');
    } else {
      setPref('basemap.customUrl', customTileUrl);
    }
    notifyListeners();
  }
  bool showGrid = true;
  bool showLabels = true;
  bool showWettedRadii = true;
  bool showGrips = true;
  bool dirty = false;
  String lang = initialLanguage();
  late I18n t = I18n(lang);

  /// Browser store used by autosave, recent projects and versions.
  final LocalProjectStore store;
  bool autosaveEnabled = true;
  DateTime _lastAutosave = DateTime.fromMillisecondsSinceEpoch(0);

  /// The language chosen explicitly by the user (View → Language, saved in
  /// the browser), else the first of the system's preferred languages the
  /// app speaks, else English.
  static String initialLanguage() {
    final saved = getPref('lang');
    if (saved != null && supportedLanguages.contains(saved)) return saved;
    return languageFromTags(systemLanguageTags());
  }

  /// The machine's preferred languages, most preferred first (the browser's
  /// `navigator.languages`, the OS language list on desktop).
  static Iterable<String> systemLanguageTags() {
    final d = PlatformDispatcher.instance;
    final list = d.locales.isEmpty ? [d.locale] : d.locales;
    return list.map((l) => l.toLanguageTag());
  }

  final List<_UndoState> _undo = [];
  final List<_UndoState> _redo = [];
  static const maxUndo = 50;
  String? lastMessage;
  int messageSeq = 0;
  bool busy = false;

  /// Progress of the running design (null when idle or before the first step).
  DesignProgress? progress;

  /// Where the running design executes: `worker` (browser), `isolate`
  /// (desktop) or `thread` (fallback on the UI thread). Empty when idle.
  String designMode = '';

  /// Runs design jobs off the UI thread; tests may replace it.
  DesignRunner designRunner = createDesignRunner();
  Set<String> unconnected = {};
  String? hglEntityId;
  int reportTab = 0;
  bool showReports = false;

  /// Workspace tab holding this project (0 = standalone).
  int tabId = 0;

  /// Last drawing tool, reactivated with Enter while selecting (AutoCAD-style repeat).
  ToolId lastTool = ToolId.line;

  /// Command typed on the canvas (AutoCAD-style aliases), shown in the status bar.
  String command = '';

  /// Shift is locking the segment being drawn to 0°/45°/90° (status bar chip).
  bool angleLockActive = false;

  /// Canvas hooks for the keyboard dispatcher (set while a canvas is mounted).
  CanvasKeyTarget? keyTarget;

  /// Gives the keyboard focus back to the canvas (set by the app shell);
  /// called after tool and menu choices so typed commands keep working.
  VoidCallback? focusCanvas;

  /// Counters of user actions ('zoom', 'pan', 'undo', 'edit', 'command'…),
  /// read by the tutorial to detect that a step was performed.
  final Map<String, int> events = {};

  void track(String name) => events[name] = (events[name] ?? 0) + 1;

  int eventCount(String name) => events[name] ?? 0;

  /// Allowable submain (feed) positions computed for laterals (entity id → results).
  final Map<String, List<FeedPositionResult>> feedEnvelope = {};

  /// Path of the last elevation profile (Reports → Profile), drawn on the
  /// canvas until cleared.
  List<Pt>? profilePath;

  /// Last design check (Design → Design check…).
  DesignCheckReport? checkReport;

  /// Decoded raster images by entity id.
  final Map<String, ui.Image> images = {};
  final Set<String> _decoding = {};

  /// Called after the language changes so a workspace can propagate it to other tabs.
  void Function(String lang)? onLanguageChanged;

  Units get units => project.params.units;

  void _init() {
    camera.center = const Pt(60, 30);
    camera.scale = 5;
    setDocumentLanguage(lang);
  }

  // ------------------------------------------------------------ notifications
  void notify(String message) {
    lastMessage = message;
    messageSeq++;
    notifyListeners();
  }

  /// Switches the interface language. A choice made by the user is saved
  /// ([persist]); a language taken from the page address (`?lang=`, `/pt/`)
  /// applies to this visit only, so the next plain visit follows the machine
  /// language again. A language that is not compiled in shows English until
  /// its table has been loaded (see [ensureLanguageLoaded]); the returned
  /// future completes when the strings are in place.
  Future<void> setLanguage(String l, {bool persist = true}) async {
    if (!supportedLanguages.contains(l)) return;
    lang = l;
    t = I18n(l);
    _followLanguageCurrency();
    if (persist) setPref('lang', l);
    setDocumentLanguage(l);
    notifyListeners();
    onLanguageChanged?.call(l);
    if (isLanguageLoaded(l)) return;
    await ensureLanguageLoaded(l);
    if (lang != l) return;
    t = I18n(l);
    notifyListeners();
  }

  /// Human-readable text for an exception raised by an import.
  String describeError(Object e) {
    if (e is DwgUnsupportedException) return t.has('dwg.${e.code}') ? t('dwg.${e.code}') : e.message;
    if (e is FormatException) {
      if (e.message == 'kmz_no_kml') return t('kmz.noKml');
      if (t.has('imp.err.${e.message}')) return t('imp.err.${e.message}');
      return e.message;
    }
    if (e is GeoReferenceMissing) return t('geo.none');
    return '$e';
  }

  void refresh() => notifyListeners();

  // ------------------------------------------------------------ undo / redo
  _UndoState _capture(String label) => _UndoState([for (final e in project.entities) e.clone()], project.toJson(includeEntities: false), label, DateTime.now());

  /// Time of the last state change (history panel).
  DateTime historyTouched = DateTime.now();

  /// The timeline: the initial state, every action applied since the file
  /// was opened (oldest first, the current state marked) and the undone
  /// actions still available for redo.
  List<HistoryEntry> get historyEntries {
    final out = <HistoryEntry>[];
    final n = _undo.length;
    final startTime = _undo.isNotEmpty ? _undo.first.time : historyTouched;
    out.add(HistoryEntry(index: 0, label: 'hist.start', time: startTime, current: n == 0, future: false));
    for (var k = 1; k <= n; k++) {
      final st = _undo[k - 1];
      out.add(HistoryEntry(index: k, label: st.label, time: k < n ? _undo[k].time : historyTouched, current: k == n, future: false));
    }
    for (var i = _redo.length - 1; i >= 0; i--) {
      out.add(HistoryEntry(index: n + (_redo.length - i), label: _redo[i].label, time: _redo[i].time, current: false, future: true));
    }
    return out;
  }

  /// Number of actions applied (position of the current state).
  int get historyIndex => _undo.length;

  /// Goes back (or forward) to the state at [index] of [historyEntries].
  void jumpToHistory(int index) {
    var guard = 0;
    while (_undo.length > index && _undo.isNotEmpty && guard++ < 500) {
      _undoOnce();
    }
    while (_undo.length < index && _redo.isNotEmpty && guard++ < 500) {
      _redoOnce();
    }
    track('history');
    notifyListeners();
  }

  /// Tool key (`tool.*`) describing an entity, for history labels.
  static String toolKeyOf(Entity e) => switch (e) {
    LineEntity _ => 'line',
    PolylineEntity _ => 'polyline',
    CircleEntity _ => 'circle',
    ArcEntity _ => 'arc',
    SplineEntity _ => 'spline',
    HatchEntity _ => 'hatch',
    SymbolEntity _ => 'symbol',
    TextEntity _ => 'text',
    DimensionEntity _ => 'dimension',
    AngularDimensionEntity _ => 'dimAngular',
    RadialDimensionEntity _ => 'dimRadial',
    LeaderEntity _ => 'leader',
    ImageEntity _ => 'image',
    ContourEntity _ => 'contour',
    SpotHeightEntity _ => 'spot',
    PipeEntity p => p.scope == HydraulicScope.zone ? 'zonePipe' : 'mainPipe',
    SpraylineEntity _ => 'sprayline',
    TapeEntity _ => 'tape',
    OutletEntity _ => 'outlet',
    ControlValveEntity _ => 'valve',
    WaterSupplyEntity _ => 'supply',
    PumpEntity _ => 'pump',
    MiscHydraulicEntity _ => 'misc',
    JunctionEntity _ => 'junction',
    PivotEntity _ => 'pivot',
    AreaEntity _ => 'area',
    ControllerEntity _ => 'controller',
    WireEntity _ => 'wire',
    OrdinateDimensionEntity _ => 'dimOrdinate',
    _ => 'select',
  };

  Project _restore(_UndoState s) {
    final p = Project.fromJson({...s.rest, 'entities': const []});
    p.entities.addAll(s.entities.map((e) => e.clone()));
    return p;
  }

  void _snapshot([String label = 'hist.edit']) {
    _editSeq++;
    _undo.add(_capture(label));
    if (_undo.length > maxUndo) _undo.removeAt(0);
    _redo.clear();
    historyTouched = DateTime.now();
  }

  /// Runs a mutation with an undo snapshot; [label] names the action in the
  /// history panel (`hist.*` key, optional `|argument`). Refused (returns
  /// null, tells the user) while a design runs: its result replaces the
  /// hydraulic entities, so an edit made meanwhile would be lost.
  T? mutate<T>(T Function() fn, {bool invalidateResults = true, String? label}) {
    if (!editAllowed()) return null;
    track('edit');
    _snapshot(label ?? 'hist.edit');
    final r = fn();
    _editSeq++; // geometry changed: the spatial index is stale
    dirty = true;
    project.meta.modified = DateTime.now();
    if (invalidateResults) {
      results = null;
      feedEnvelope.clear();
    }
    notifyListeners();
    _autosaveMaybe();
    return r;
  }

  /// Starts an in-place edit of the project settings (details, parameters,
  /// catalogue, layers, system flows) by a dialog; hand the returned token
  /// to [commitSettingsEdit] when the dialog closes, however it is closed.
  SettingsEdit beginSettingsEdit([String label = 'hist.settings']) => SettingsEdit._(_capture(label), project);

  /// Ends an edit started with [beginSettingsEdit]: when anything changed,
  /// the whole dialog session becomes one undo step (edits made through
  /// [mutate] meanwhile are folded into it), the project is marked as
  /// modified and, when the parameters, the catalogue or the system flows
  /// changed, the results (computed with the old settings) are discarded.
  /// Returns whether anything changed.
  bool commitSettingsEdit(SettingsEdit edit) {
    if (!identical(edit._project, project)) return false; // another project was opened meanwhile
    final before = edit._state.rest, now = project.toJson(includeEntities: false);
    String part(Map<String, dynamic> j, String k) => switch (k) {
      // the display units do not change any result
      'units' => jsonEncode((j['params'] as Map<String, dynamic>)['units']),
      'params' => jsonEncode({...(j['params'] as Map<String, dynamic>)}..remove('units')),
      'meta' => jsonEncode({...(j['meta'] as Map<String, dynamic>)}..remove('modified')),
      _ => jsonEncode(j[k]),
    };
    const sections = ['meta', 'units', 'params', 'catalog', 'layers', 'systemFlows', 'currentLayer'];
    final changed = [for (final k in sections) if (part(before, k) != part(now, k)) k];
    // undo steps recorded while the dialog was open (currency conversion…)
    var mutated = 0;
    while (_undo.isNotEmpty && !_undo.last.time.isBefore(edit._state.time)) {
      _undo.removeLast();
      mutated++;
    }
    if (changed.isEmpty && mutated == 0) return false;
    _editSeq++;
    _undo.add(edit._state);
    if (_undo.length > maxUndo) _undo.removeAt(0);
    _redo.clear();
    historyTouched = DateTime.now();
    dirty = true;
    project.meta.modified = DateTime.now();
    if (changed.any((k) => k == 'params' || k == 'catalog' || k == 'systemFlows')) {
      results = null;
      feedEnvelope.clear();
    }
    notifyListeners();
    _autosaveMaybe();
    return true;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Whether the project may be edited now; when not (a design is running)
  /// the user is told why.
  bool editAllowed() {
    if (!busy) return true;
    notify(t('msg.designBusy'));
    return false;
  }

  void _undoOnce() {
    _editSeq++;
    final st = _undo.removeLast();
    _redo.add(_capture(st.label));
    project = _restore(st);
    selection.clear();
    results = null;
    feedEnvelope.clear();
    dirty = true;
    historyTouched = DateTime.now();
  }

  void _redoOnce() {
    _editSeq++;
    final st = _redo.removeLast();
    _undo.add(_capture(st.label));
    project = _restore(st);
    selection.clear();
    results = null;
    feedEnvelope.clear();
    dirty = true;
    historyTouched = DateTime.now();
  }

  void undo() {
    track('undo');
    if (_undo.isNotEmpty && editAllowed()) _undoOnce();
    // listeners (the tutorial) see the tracked command even with nothing to undo
    notifyListeners();
  }

  void redo() {
    track('redo');
    if (_redo.isNotEmpty && editAllowed()) _redoOnce();
    notifyListeners();
  }

  // ------------------------------------------------------------ autosave
  /// Autosaves at most every few seconds of activity (no timers, so it is
  /// deterministic and test friendly); also called when a tab is closed.
  void _autosaveMaybe({bool force = false}) {
    if (!autosaveEnabled) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastAutosave).inMilliseconds < 3000) return;
    autosaveNow();
  }

  void autosaveNow() {
    if (!autosaveEnabled || project.entities.isEmpty) return;
    _lastAutosave = DateTime.now();
    try {
      store.save(project.meta.uid, project.meta.name, _storeJson(), kind: 'autosave');
    } catch (_) {
      // storage unavailable: ignore
    }
  }

  /// Project JSON for the browser store (results included; embedded images
  /// dropped when the file would exceed the store limit).
  String _storeJson() {
    var s = saveJson(pretty: false, markClean: false);
    if (s.length > store.maxBytes) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      for (final e in (j['entities'] as List).cast<Map<String, dynamic>>()) {
        e.remove('data');
      }
      s = encodeJson(j);
    }
    return s;
  }

  // ------------------------------------------------------------ entities
  void addEntity(Entity e) => mutate(() => project.entities.add(e), label: 'hist.add|${toolKeyOf(e)}');
  void addEntities(Iterable<Entity> es, {String? label}) {
    final list = es.toList();
    mutate(() => project.entities.addAll(list), label: label ?? 'hist.addMany|${list.length}');
  }

  /// Adds a point hydraulic item and, when enabled, splits the pipe under it
  /// so the item sits at a pipe end (insertion in the middle of a pipe).
  void addPointItem(Entity e, Pt position, {Iterable<HydraulicScope>? scopes}) {
    mutate(() {
      project.entities.add(e);
      if (toolSettings.splitPipesOnInsert) _splitPipesUnder(position, scopes ?? HydraulicScope.values);
    }, label: 'hist.add|${toolKeyOf(e)}');
  }

  bool _locked(Entity e) => project.isLocked(e.layer);

  /// Selected entities that are not on a locked layer.
  List<Entity> get editableSelection => project.entities.where((e) => selection.contains(e.id) && !_locked(e)).toList();

  void deleteSelected() {
    track('delete');
    if (selection.isEmpty) return;
    final ids = editableSelection.map((e) => e.id).toSet();
    if (ids.isEmpty) {
      notify(t('msg.layerLocked'));
      return;
    }
    mutate(() => project.entities.removeWhere((e) => ids.contains(e.id)), label: 'hist.delete|${ids.length}');
    selection.removeAll(ids);
    notify(t('msg.deleted', {'n': '${ids.length}'}));
  }

  void moveSelected(Pt delta) {
    if (selection.isEmpty || (delta.x == 0 && delta.y == 0)) return;
    transformSelected(Affine.translation(delta), label: 'hist.move');
  }

  /// Applies [t] to the selection (or to copies when [copy]).
  int transformSelected(Affine t, {bool copy = false, String? label}) {
    final targets = editableSelection;
    if (targets.isEmpty) {
      if (selection.isNotEmpty) notify(t == Affine.identity ? '' : this.t('msg.layerLocked'));
      return 0;
    }
    final newIds = <String>[];
    mutate(() {
      if (copy) {
        for (final e in targets) {
          final c = _transformed(e.clone(newId: project.newId()), t);
          project.entities.add(c);
          newIds.add(c.id);
        }
      } else {
        final ids = targets.map((e) => e.id).toSet();
        for (var i = 0; i < project.entities.length; i++) {
          final e = project.entities[i];
          if (ids.contains(e.id)) project.entities[i] = _transformed(e, t);
        }
      }
    }, invalidateResults: !copy || targets.any((e) => e.isHydraulic), label: label ?? (copy ? 'hist.copy|${targets.length}' : 'hist.transform|${targets.length}'));
    if (copy) select(newIds);
    return targets.length;
  }

  /// [e] through [t]. A head left at a full circle with a part-circle
  /// nozzle waters the nozzle's arc: a mirror needs that arc to turn the
  /// sector to the mirrored side.
  Entity _transformed(Entity e, Affine t) {
    if (t.isMirror && e is OutletEntity && e.arcDeg >= 360) {
      final nz = project.catalog.outlet(e.outletSpecId)?.nozzle(e.nozzleId);
      if (nz != null && nz.arcDeg < 360) return (e.clone()..arcDeg = nz.arcDeg).transformed(t);
    }
    return e.transformed(t);
  }

  int rotateSelected(Pt center, double rad, {bool copy = false}) => transformSelected(Affine.rotation(rad, center), copy: copy, label: copy ? null : 'hist.rotate');
  int scaleSelected(Pt center, double factor, {bool copy = false}) => factor > 0 ? transformSelected(Affine.scaling(factor, center), copy: copy, label: copy ? null : 'hist.scale') : 0;
  int mirrorSelected(Pt a, Pt b, {bool keepSource = true}) => transformSelected(Affine.mirror(a, b), copy: keepSource, label: 'hist.mirror');

  /// Rectangular or polar array of the selection. Returns the number of
  /// entities created.
  int arraySelected(ArrayOptions o) {
    final targets = editableSelection;
    if (targets.isEmpty) return 0;
    final created = <Entity>[];
    mutate(() {
      if (o.polar) {
        final n = math.max(2, o.count);
        final full = (o.totalAngleDeg.abs() - 360).abs() < 1e-6;
        for (var i = 1; i < n; i++) {
          final ang = degToRad(o.totalAngleDeg) * i / (full ? n : n - 1);
          final rot = Affine.rotation(ang, o.center);
          for (final e in targets) {
            var c = e.clone(newId: project.newId()).transformed(rot);
            if (!o.rotateItems) {
              // keep orientation: rotate back about the copy's own centre
              final cen = c.bounds.center;
              c = c.transformed(Affine.rotation(-ang, cen));
            }
            created.add(c);
          }
        }
      } else {
        final ang = degToRad(o.angleDeg);
        final ux = Pt.polar(1, ang), uy = Pt.polar(1, ang + math.pi / 2);
        for (var r = 0; r < math.max(1, o.rows); r++) {
          for (var c = 0; c < math.max(1, o.cols); c++) {
            if (r == 0 && c == 0) continue;
            final d = ux * (o.dx * c) + uy * (o.dy * r);
            for (final e in targets) {
              created.add(e.clone(newId: project.newId()).translated(d));
            }
          }
        }
      }
      project.entities.addAll(created);
    }, label: 'hist.array');
    select(created.map((e) => e.id));
    return created.length;
  }

  /// Offsets an entity by [distance] towards [side] (new entity).
  Entity? offsetEntityTo(String id, double distance, Pt side) {
    final e = project.byId(id);
    if (e == null || _locked(e) || distance == 0) return null;
    double sign;
    if (e is CircleEntity) {
      sign = side.distanceTo(e.center) > e.radius ? 1 : -1;
    } else if (e is ArcEntity) {
      sign = side.distanceTo(e.center) > e.radius ? 1 : -1;
    } else {
      final pts = e.linearPoints;
      if (pts == null || pts.length < 2) return null;
      var best = double.infinity;
      var s = 1.0;
      final n = pts.length + (e.isClosedShape ? 1 : 0);
      for (var i = 1; i < n; i++) {
        final a = pts[i - 1], b = pts[i % pts.length];
        final d = distanceToSegment(side, a, b);
        if (d < best) {
          best = d;
          s = (b - a).cross(side - a) >= 0 ? 1 : -1;
        }
      }
      sign = s;
    }
    final out = offsetEntity(e, sign * distance.abs(), project.newId());
    if (out == null) return null;
    mutate(() => project.entities.add(out), invalidateResults: out.isHydraulic);
    select([out.id]);
    return out;
  }

  /// Linear entities used as cutting/boundary edges: the selection when it
  /// holds any (other than [exclude]), else every visible linear entity.
  List<Entity> _boundaries(String exclude) {
    final sel = project.entities.where((e) => selection.contains(e.id) && e.id != exclude && e.linearPoints != null).toList();
    if (sel.isNotEmpty) return sel;
    return visibleEntities().where((e) => e.id != exclude && e.linearPoints != null).toList();
  }

  List<double> _cutStations(Entity target, List<Entity> boundaries) {
    final pts = target.linearPoints!;
    final cuts = <double>[];
    for (final b in boundaries) {
      final bp = b.linearPoints!;
      for (final p in polylineIntersections(pts, bp, closedA: target.isClosedShape, closedB: b.isClosedShape)) {
        cuts.add(polylineStationOf(pts, p).$1);
      }
    }
    return cuts;
  }

  /// Trims the part of the linear entity [id] around [world] between the
  /// nearest intersections with the boundaries. Returns true when trimmed.
  bool trimAt(String id, Pt world) {
    final e = project.byId(id);
    if (e == null || _locked(e) || e.linearPoints == null || e.isClosedShape) return false;
    final cuts = _cutStations(e, _boundaries(id));
    if (cuts.isEmpty) return false;
    final (at, _) = polylineStationOf(e.linearPoints!, world);
    final pieces = trimLinearEntity(e, at, cuts, () => project.newId());
    if (pieces.length == 1 && identical(pieces.first, e)) return false;
    mutate(() {
      final idx = project.entities.indexOf(e);
      project.entities.removeAt(idx);
      project.entities.insertAll(idx, pieces);
    });
    selection.remove(id);
    return true;
  }

  /// Extends the end of [id] nearest to [world] to the boundaries.
  bool extendAt(String id, Pt world) {
    final e = project.byId(id);
    if (e == null || _locked(e) || e.linearPoints == null || e.isClosedShape) return false;
    final b = _boundaries(id).map((x) => x.linearPoints!).toList();
    final copy = e.clone();
    if (!extendLinearEntity(copy, world, b)) return false;
    mutate(() {
      final idx = project.entities.indexOf(e);
      project.entities[idx] = copy;
    });
    return true;
  }

  /// Cuts a pipe / lateral / line at the point closest to [world].
  bool cutAt(String id, Pt world) {
    final e = project.byId(id);
    if (e == null || _locked(e) || e.linearPoints == null) return false;
    final (at, _) = polylineStationOf(e.linearPoints!, world);
    return _splitEntityAt(e, at);
  }

  bool _splitEntityAt(Entity e, double station) {
    final pieces = splitLinearEntity(e, [station], () => project.newId());
    if (pieces.length < 2) return false;
    mutate(() {
      final idx = project.entities.indexOf(e);
      project.entities.removeAt(idx);
      project.entities.insertAll(idx, pieces);
    });
    select(pieces.map((p) => p.id));
    return true;
  }

  /// Splits pipes passing under [p] (within the connection tolerance) so the
  /// point becomes a vertex shared by two pipes. Called inside [mutate].
  int _splitPipesUnder(Pt p, Iterable<HydraulicScope> scopes) {
    final tol = math.max(project.params.connectTolerance, snap.tolerancePx / camera.scale * 0.5);
    var n = 0;
    for (final e in project.entities.whereType<PipeEntity>().toList()) {
      if (!scopes.contains(e.scope) || _locked(e)) continue;
      final pts = e.points;
      if (pts.length < 2 || e.distanceTo(p) > tol) continue;
      if (pts.any((v) => v.distanceTo(p) <= tol)) continue; // already a vertex
      final (at, cp) = polylineStationOf(pts, p);
      final pieces = splitLinearEntity(e, [at], () => project.newId());
      if (pieces.length < 2) continue;
      // snap the cut exactly to the item position
      for (final piece in pieces) {
        final pp = (piece as PipeEntity).points;
        for (var i = 0; i < pp.length; i++) {
          if (pp[i].distanceTo(cp) < 1e-9) pp[i] = p;
        }
      }
      final idx = project.entities.indexOf(e);
      project.entities.removeAt(idx);
      project.entities.insertAll(idx, pieces);
      n++;
    }
    return n;
  }

  // ---- grips
  /// Moves the [index]th grip of [id] to [p]. With [keepConnections], every
  /// hydraulic vertex / item that sat on the old point goes with it, so the
  /// joint between two pipes (or a pipe and a valve) survives the edit.
  void setGrip(String id, int index, Pt p, {bool keepConnections = false}) {
    final e = project.byId(id);
    if (e == null || _locked(e)) return;
    final grips = e.grips;
    final from = index >= 0 && index < grips.length ? grips[index] : null;
    final joined = keepConnections && from != null && from.distanceTo(p) > 1e-12 ? _joinedAt(from, e.id) : const <Entity>[];
    mutate(() {
      e.setGrip(index, p);
      final tol = _junctionTolerance;
      for (final other in joined) {
        if (other is PointEntity) {
          other.position = p;
        } else if (other is PolyEntity) {
          final pts = other.points;
          for (var i = 0; i < pts.length; i++) {
            if (pts[i].distanceTo(from!) <= tol) pts[i] = p;
          }
        }
      }
    }, invalidateResults: e.isHydraulic || joined.isNotEmpty);
  }

  double get _junctionTolerance => math.max(project.params.connectTolerance, 1e-6);

  /// Entities other than [exceptId] with a vertex / position on [at]: the
  /// ones that share the junction and must go with it. A pipe node takes the
  /// hydraulic items and the wire routes ending there with it; a wire
  /// vertex only the other wires (a valve does not follow its wire).
  List<Entity> _joinedAt(Pt at, String exceptId) {
    final tol = _junctionTolerance;
    final out = <Entity>[];
    final wireOnly = project.byId(exceptId) is WireEntity;
    for (final e in entitiesIn(Bounds(at.x - tol, at.y - tol, at.x + tol, at.y + tol))) {
      final joins = wireOnly ? e is WireEntity : (e.isHydraulic || e is WireEntity);
      if (e.id == exceptId || !joins || _locked(e)) continue;
      if (e is PointEntity) {
        if (e.position.distanceTo(at) <= tol) out.add(e);
      } else if (e is PolyEntity) {
        if (e.points.any((v) => v.distanceTo(at) <= tol)) out.add(e);
      }
    }
    return out;
  }

  /// Adds a vertex at [p]; false when the edit was refused (locked layer,
  /// design running) so the caller does not act on a vertex that is not there.
  bool insertVertex(String id, int index, Pt p) {
    final e = project.byId(id);
    if (e is! PolyEntity || _locked(e)) return false;
    return mutate(() {
      e.insertVertex(index, p);
      return true;
    }, invalidateResults: e.isHydraulic) ?? false;
  }

  void removeVertex(String id, int index) {
    final e = project.byId(id);
    if (e is! PolyEntity || _locked(e)) return;
    if (e.points.length <= 2) return;
    mutate(() => e.removeVertex(index), invalidateResults: e.isHydraulic);
  }

  /// Applies [fn] to every selected entity of type [T] (batch properties).
  int mutateSelected<T extends Entity>(void Function(T e) fn, {bool invalidateResults = true}) {
    final targets = editableSelection.whereType<T>().toList();
    if (targets.isEmpty) return 0;
    mutate(() {
      for (final e in targets) {
        fn(e);
      }
    }, invalidateResults: invalidateResults, label: 'hist.props');
    return targets.length;
  }

  void duplicateSelected() {
    track('duplicate');
    if (selection.isEmpty) return;
    final copies = <Entity>[];
    mutate(() {
      for (final e in editableSelection) {
        copies.add(e.clone(newId: project.newId()).translated(const Pt(2, -2)));
      }
      project.entities.addAll(copies);
    }, label: 'hist.copy|${editableSelection.length}');
    // refused (a design is running) or nothing editable: keep the selection
    if (copies.isEmpty) return;
    selection
      ..clear()
      ..addAll(copies.map((e) => e.id));
    notifyListeners();
  }

  void selectAll() {
    track('selectAll');
    selection
      ..clear()
      ..addAll(project.entities.where((e) => project.layerNamed(e.layer).visible && !_locked(e)).map((e) => e.id));
    notifyListeners();
  }

  void select(Iterable<String> ids, {bool add = false}) {
    if (!add) selection.clear();
    selection.addAll(ids);
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (!selection.remove(id)) selection.add(id);
    notifyListeners();
  }

  Entity? get selectedEntity => selection.length == 1 ? project.byId(selection.first) : null;

  List<Entity> visibleEntities() => project.entities.where((e) => project.layerNamed(e.layer).visible).toList();

  /// Entities on visible layers whose bounds intersect [b], in drawing
  /// order (spatial index query).
  List<Entity> entitiesIn(Bounds b) {
    final idx = index;
    final visible = {for (final l in project.layers) l.name: l.visible};
    return [for (final i in idx.query(b)) if (visible[idx.entities[i].layer] ?? true) idx.entities[i]];
  }

  /// Hit test in world units (entities on locked layers are skipped unless [includeLocked]).
  Entity? pick(Pt world, double tolerance, {bool includeLocked = false}) {
    Entity? best;
    var bestD = double.infinity;
    for (final e in entitiesIn(Bounds(world.x - tolerance, world.y - tolerance, world.x + tolerance, world.y + tolerance))) {
      if (!includeLocked && _locked(e)) continue;
      final d = e.distanceTo(world);
      // prefer point entities — a sprinkler sitting on a pipe is the smaller
      // target and is what the click meant; images are backgrounds and lose
      // to everything
      final w = e is PointEntity ? d * 0.5 - tolerance * 0.25 : (e is ImageEntity || e is HatchEntity ? d + tolerance * 0.9 : d);
      if (d <= tolerance && w < bestD) {
        best = e;
        bestD = w;
      }
    }
    return best;
  }

  List<Entity> pickWindow(Bounds b, {bool crossing = false}) {
    final idx = index;
    final visible = {for (final l in project.layers) l.name: l.visible};
    final out = <Entity>[];
    for (final i in idx.query(b)) {
      final e = idx.entities[i];
      if (!(visible[e.layer] ?? true) || _locked(e)) continue;
      if (crossing) {
        out.add(e);
        continue;
      }
      final eb = idx.boundsAt(i);
      if (eb.minX >= b.minX && eb.maxX <= b.maxX && eb.minY >= b.minY && eb.maxY <= b.maxY) out.add(e);
    }
    return out;
  }

  // ------------------------------------------------------------ view
  void setTool(ToolId id) {
    if (id != ToolId.select && id != ToolId.pan) lastTool = id;
    activeTool = id;
    track('tool');
    focusCanvas?.call();
    notifyListeners();
  }

  void zoomAll() {
    track('zoomAll');
    var b = project.bounds;
    if (b.isEmpty) b = const Bounds(-10, -10, 130, 70);
    camera.fit(b.inflate(mathMax(b.width, b.height) * 0.05 + 1));
    notifyListeners();
  }

  void zoomBy(double f) {
    track('zoom');
    camera.zoomAt(Offset(camera.size.width / 2, camera.size.height / 2), f);
    notifyListeners();
  }

  void zoomToEntity(String id) {
    final e = project.byId(id);
    if (e == null) return;
    camera.fit(e.bounds.inflate(5));
    notifyListeners();
  }

  // ------------------------------------------------------------ layers
  void toggleLayer(String name) {
    final l = project.layerNamed(name);
    l.visible = !l.visible;
    notifyListeners();
  }

  void setLayerLocked(String name, bool locked) {
    project.layerNamed(name).locked = locked;
    if (locked) selection.removeWhere((id) => project.byId(id)?.layer == name);
    notifyListeners();
  }

  void setLayerColor(String name, int argb) {
    mutate(() => project.layerNamed(name).color = argb, invalidateResults: false);
  }

  void setCurrentLayer(String name) {
    project.layerNamed(name);
    project.currentLayer = name;
    notifyListeners();
  }

  bool addLayer(String name, {int color = 0xFFB0BEC5}) {
    final n = name.trim();
    if (n.isEmpty || project.findLayer(n) != null) return false;
    return mutate(() {
          project.layers.add(Layer(name: n, color: color));
          return true;
        }, invalidateResults: false) ??
        false;
  }

  bool renameLayer(String from, String to) {
    var ok = false;
    mutate(() => ok = project.renameLayer(from, to), invalidateResults: false);
    return ok;
  }

  void removeLayer(String name) {
    if (Layers.all.contains(name)) return;
    mutate(() => project.removeLayer(name), invalidateResults: false);
  }

  /// Layer for a new drawing entity: the current layer, unless it is locked.
  String get drawingLayer => project.isLocked(project.currentLayer) ? Layers.drawing : project.currentLayer;

  // ------------------------------------------------------------ design
  Future<void> runDesign({bool sizeZones = true, bool sizeMain = true}) async {
    if (!_canDesign) {
      notify(t('msg.noValves'));
      return;
    }
    if (busy) return;
    _snapshot('hist.design');
    final r = await _design(sizeZones: sizeZones, sizeMain: sizeMain);
    if (r != null) _designNotice(r);
  }

  bool get _canDesign => project.entities.any((e) => e is ControlValveEntity || e is WaterSupplyEntity);

  /// Runs the design (in the worker when there is one) and applies it to the
  /// project. No undo snapshot and no message; null when the design cannot
  /// run, fails or goes stale.
  Future<DesignResults?> _design({bool sizeZones = true, bool sizeMain = true}) async {
    if (!_canDesign || busy) return null;
    busy = true;
    progress = null;
    track('design');
    notifyListeners();
    await _yieldFrame();
    try {
      final gen = _editSeq;
      final request = DesignRequest.of(project, lang: lang, sizeZones: sizeZones, sizeMain: sizeMain);
      final response = await designRunner.run(
        request,
        yieldControl: _yieldFrame,
        onMode: (m) {
          designMode = m;
          notifyListeners();
        },
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      if (gen != _editSeq) {
        // the project was replaced or edited meanwhile (mutate refuses while
        // busy, but opening a file or the example still swaps the project)
        notify(t('msg.designStale'));
        return null;
      }
      applyDesignResponse(project, response);
      _editSeq++; // pipes were resized / split: rebuild the spatial index
      final r = response.results;
      results = r;
      unconnected = r.unconnected;
      dirty = true;
      showReports = true;
      feedEnvelope.clear();
      _autosaveMaybe(force: true);
      return r;
    } catch (e, st) {
      debugPrint('$e\n$st');
      notify(t('msg.error', {'e': '$e'}));
      return null;
    } finally {
      busy = false;
      progress = null;
      designMode = '';
      notifyListeners();
    }
  }

  /// After a design: the usual summary, or, when there are errors, a pointer
  /// to the Messages tab (opened), where each one is explained.
  void _designNotice(DesignResults r) {
    final errors = advice.where((a) => a.level == AdviceLevel.error).length;
    if (errors > 0) {
      reportTab = messagesReportTab;
      notify(t('adv.problemsAfterDesign', {'n': '$errors'}));
    } else {
      notify(t('msg.designDone', {'z': '${r.zones.length}', 'f': '${r.systemFlows.length}'}));
    }
  }

  // ------------------------------------------------------------ advisor
  List<Advice>? _advice;
  String _adviceSig = '';

  /// Problems of the project, each explained and with its corrections: the
  /// design check, the settings and the latest results. Recomputed when the
  /// drawing, the settings, the system flows or the results change.
  List<Advice> get advice {
    final sig = '$_editSeq|${identityHashCode(project)}|${identityHashCode(results)}|${jsonEncode(project.params.toJson())}|${jsonEncode([for (final f in project.systemFlows) f.toJson()])}';
    if (_advice == null || sig != _adviceSig) {
      _advice = buildAdvice(project, results: results);
      _adviceSig = sig;
    }
    return _advice!;
  }

  /// Applies one correction (one undo step). With results on screen the
  /// design runs again, so the message list shows what is left.
  Future<FixResult?> applyAdviceFix(Advice a, FixKind kind) async {
    if (!editAllowed()) return null;
    track('fix');
    final before = results;
    _snapshot('hist.fix|${kind.name}');
    final res = applyFix(project, a, kind, results: before, label: t.call, lang: lang);
    if (!res.ok) {
      _undo.removeLast(); // a correction that fails changes nothing
      notify(t('adv.fixFailed', {'m': t(res.key, res.args)}));
      return res;
    }
    _editSeq++;
    dirty = true;
    project.meta.modified = DateTime.now();
    results = null;
    feedEnvelope.clear();
    notifyListeners();
    final msg = t('adv.fixed', {'m': t(res.key, res.args)});
    if (before != null && _canDesign) {
      final r = await _design();
      if (r != null) _designNotice(r);
    }
    notify(msg);
    _autosaveMaybe();
    return res;
  }

  /// Text of the progress of [autoFixAll] / [optimizeDesign] ('' = idle).
  String assistantProgress = '';

  /// "Fix automatically": safe corrections and designs in rounds until
  /// nothing more can be fixed. One undo step.
  Future<AutoFixReport?> autoFixAll() async {
    if (!editAllowed()) return null;
    track('autofix');
    _snapshot('hist.autofix');
    assistantProgress = t('adv.working', {'n': '1'});
    notifyListeners();
    try {
      final report = await runAutoFix(project, () async {
        _editSeq++;
        return _design();
      }, label: t.call, lang: lang, onRound: (n) {
        assistantProgress = t('adv.working', {'n': '$n'});
        notifyListeners();
      });
      _editSeq++;
      dirty = true;
      showReports = true;
      reportTab = messagesReportTab;
      notify(report.applied.isEmpty ? t('adv.summaryNone') : t('adv.summaryApplied', {'n': '${report.applied.length}'}).replaceAll(RegExp(r'\s*[:：]\s*$'), ''));
      return report;
    } finally {
      assistantProgress = '';
      notifyListeners();
    }
  }

  /// Optimises the design (see [runOptimize]); keeps the result when it is
  /// better, otherwise restores the project as it was. One undo step.
  Future<OptimizeReport?> optimizeDesign(OptimizeOptions options) async {
    if (!editAllowed()) return null;
    track('optimize');
    final base = results;
    _snapshot('hist.optimize');
    assistantProgress = t('opt.working');
    notifyListeners();
    try {
      final report = await runOptimize(project, () async {
        _editSeq++;
        return _design();
      }, options: options, baseline: base, label: t.call);
      if (!report.improved) {
        // nothing gained: back to the project as it was
        final st = _undo.removeLast();
        project = _restore(st);
        results = base;
        unconnected = base?.unconnected ?? unconnected;
        _editSeq++;
      } else {
        dirty = true;
        _editSeq++;
      }
      showReports = true;
      notify(report.improved ? t('opt.kept') : t('opt.reverted'));
      return report;
    } finally {
      assistantProgress = '';
      notifyListeners();
    }
  }

  /// Lets the UI paint before the next heavy step: waits for the next frame
  /// (scheduling one if needed) or 16 ms when no frame is produced (tests,
  /// headless use), then returns to the event loop once more so the browser
  /// can present it.
  static Future<void> _yieldFrame() async {
    final frame = Completer<void>();
    try {
      final b = SchedulerBinding.instance;
      b.addPostFrameCallback((_) {
        if (!frame.isCompleted) frame.complete();
      });
      b.scheduleFrame();
    } catch (_) {
      // no binding (pure Dart tests): fall back to the timer below
    }
    await Future.any<void>([frame.future, Future<void>.delayed(const Duration(milliseconds: 16))]);
    await Future<void>.delayed(Duration.zero);
  }

  void checkConnectivity() {
    track('check');
    final m = NetworkBuilder(project).build();
    unconnected = m.unconnectedEntities;
    if (unconnected.isEmpty) {
      notify(t('msg.allConnected'));
    } else {
      notify(t('msg.unconnected', {'n': '${unconnected.length}'}));
    }
  }

  void clearResults() {
    results = null;
    unconnected = {};
    notifyListeners();
  }

  void addBlock(BlockOptions o) {
    track('block');
    final r = mutate(() {
      final res = generateBlock(project, o);
      project.entities.addAll(res.all);
      return res;
    }, label: 'hist.block');
    if (r == null) return;
    select(r.all.map((e) => e.id));
  }

  void addSprinklerGrid(SprinklerGridOptions o) {
    track('grid');
    final r = mutate(() {
      final res = generateSprinklerGrid(project, o);
      project.entities.addAll(res);
      return res;
    }, label: 'hist.grid');
    if (r == null) return;
    select(r.map((e) => e.id));
  }

  /// Allowable submain positions of the selected laterals (or all laterals of
  /// the zone containing the selection). Returns the number analysed.
  int computeFeedEnvelope({Iterable<String>? ids}) {
    track('feed');
    final targets = (ids ?? selection).map(project.byId).whereType<Entity>().where((e) => e is SpraylineEntity || e is TapeEntity).toList();
    if (targets.isEmpty) return 0;
    final terrain = project.buildTerrain();
    final p = project.params;
    var n = 0;
    for (final e in targets) {
      final res = _feedPositionsFor(e, terrain, p);
      if (res != null) {
        feedEnvelope[e.id] = res;
        n++;
      }
    }
    notifyListeners();
    return n;
  }

  List<FeedPositionResult>? _feedPositionsFor(Entity e, Terrain terrain, DesignParameters p) {
    final cat = project.catalog;
    final pts = e.linearPoints ?? const <Pt>[];
    if (pts.length < 2) return null;
    LateralSpec spec;
    double nominal, lo, hi;
    if (e is SpraylineEntity) {
      final o = cat.outlet(e.outletSpecId);
      final nz = o?.nozzle(e.nozzleId);
      final pipe = cat.pipe(e.pipeSpecId) ?? cat.pipesFor(PipeUsage.lateral).firstOrNull;
      if (nz == null || pipe == null) return null;
      spec = LateralSpec(length: e.length, diameter: pipe.innerDiameter, spacing: e.spacing, emitter: nz.curve, firstOffset: e.firstOutletDistance, method: p.frictionMethod, hazenC: p.adjustedC(pipe.hazenC), roughness: pipe.roughness, kinematicViscosity: p.kinematicViscosity);
      nominal = e.headM;
      final (l, h) = nz.curve.headWindow(nominal, below: nz.flowTolBelow, above: nz.flowTolAbove);
      lo = math.max(l, nz.minHeadM);
      hi = math.min(h, nz.maxHeadM);
    } else if (e is TapeEntity) {
      final tp = cat.tape(e.tapeSpecId);
      if (tp == null) return null;
      spec = LateralSpec(length: e.length, diameter: tp.innerDiameter, spacing: tp.emitterSpacingM, emitter: tp.emitter, barbK: tp.barbK, method: p.frictionMethod, hazenC: p.adjustedC(tp.hazenC), roughness: tp.roughnessMm / 1000, kinematicViscosity: p.kinematicViscosity);
      nominal = e.inletHeadM;
      lo = math.max(tp.minHeadM, nominal * (1 - tp.tolBelowPct / 100));
      hi = math.min(tp.maxHeadM, nominal * (1 + tp.tolAbovePct / 100));
    } else {
      return null;
    }
    final z0 = terrain.isEmpty ? 0.0 : terrain.elevationAt(pts.first);
    double zAt(double d) => terrain.isEmpty ? 0.0 : terrain.elevationAt(pointAlongPolyline(pts, d)) - z0;
    return allowableFeedPositions(spec, nominalPressure: nominal, minPressure: lo, maxPressure: hi, elevationAt: zAt, steps: 21);
  }

  /// Terrain profile along [path]: (station, ground elevation) samples.
  List<(double, double)> profileAlong(List<Pt> path, {double? step}) {
    if (path.length < 2) return const [];
    final terrain = project.buildTerrain();
    final total = polylineLength(path);
    final s = math.max(0.5, step ?? math.min(project.params.terrainDensify, total / 50));
    final out = <(double, double)>[];
    for (var d = 0.0; d <= total + 1e-9; d += s) {
      final dd = math.min(d, total);
      out.add((dd, terrain.elevationAt(pointAlongPolyline(path, dd))));
      if (dd >= total) break;
    }
    if (out.last.$1 < total - 1e-9) out.add((total, terrain.elevationAt(path.last)));
    return out;
  }

  void setProfilePath(List<Pt> path) {
    profilePath = List.of(path);
    reportTab = profileReportTab;
    showReports = true;
    track('profile');
    notifyListeners();
  }

  /// Index of the Profile tab in the reports panel.
  static const profileReportTab = 8;

  /// Index of the Messages tab in the reports panel.
  static const messagesReportTab = 7;

  /// Removes the profile path from the drawing.
  void clearProfile() {
    if (profilePath == null) return;
    profilePath = null;
    track('profileClear');
    notify(t('msg.profileCleared'));
  }

  /// True when no contour / spot height gives the terrain an elevation.
  bool get terrainIsEmpty => !project.entities.any((e) => (e is ContourEntity && !e.derived) || e is SpotHeightEntity);

  // ------------------------------------------------------------ terrain tools
  /// Generates contours every [interval] metres from the terrain model as
  /// derived contour entities (they do not feed back into the model).
  int generateContours(double interval, {bool replacePrevious = true}) {
    track('contoursGen');
    final terrain = project.buildTerrain();
    if (terrain.isEmpty || interval <= 0) return 0;
    final lines = terrain.generateContours(interval);
    if (lines.isEmpty) return 0;
    final created = <Entity>[];
    mutate(() {
      if (replacePrevious) project.entities.removeWhere((e) => e is ContourEntity && e.derived);
      for (final (z, pts) in lines) {
        if (pts.length < 2 || polylineLength(pts) < interval) continue;
        final e = ContourEntity(id: project.newId(), points: pts, elevation: z, derived: true, name: 'DTM');
        project.entities.add(e);
        created.add(e);
      }
    }, invalidateResults: false, label: 'hist.contours');
    return created.length;
  }

  /// Fetches a DEM request (GET url → body): the app's HTTP helper by
  /// default, overridable by tests.
  static Future<String> Function(String url) demUrlLoader = (url) => httpRequest('GET', url);

  /// Fetches a DEM tile (GET url → bytes); overridable by tests.
  static Future<List<int>> Function(String url) demTileLoader = httpBytes;

  /// Elevation data the user put in the project (survey contours, typed
  /// spot heights, example data): everything but downloaded DEM points and
  /// generated contours.
  OwnTerrainData ownTerrainData() {
    var spots = 0, contours = 0;
    var lo = double.infinity, hi = -double.infinity;
    for (final e in project.entities) {
      if (e is SpotHeightEntity && !e.isDem) {
        spots++;
        lo = math.min(lo, e.elevation);
        hi = math.max(hi, e.elevation);
      } else if (e is ContourEntity && !e.derived) {
        contours++;
        lo = math.min(lo, e.elevation);
        hi = math.max(hi, e.elevation);
      }
    }
    return OwnTerrainData(spots, contours, lo, hi);
  }

  /// Removes the user's own elevation data (see [ownTerrainData]); the
  /// downloaded DEM and the generated contours stay. Returns the number of
  /// entities removed.
  int removeOwnTerrainData() {
    var n = 0;
    mutate(() {
      project.entities.removeWhere((e) {
        final own = (e is SpotHeightEntity && !e.isDem) || (e is ContourEntity && !e.derived);
        if (own) n++;
        return own;
      });
    }, label: 'hist.demClear');
    return n;
  }

  /// Downloads a grid of elevations over the project (or the visible area)
  /// from a public DEM and adds them as spot heights on the DEM layer.
  /// [replacePrevious] drops the points of an earlier download,
  /// [replaceExisting] also drops the user's own contours and spot heights
  /// (they usually sit on another datum, e.g. example data at 100 m, and
  /// would turn the model into spikes). [onProgress] gets (done, total)
  /// requests.
  Future<DemImportResult> importOnlineDem(DemSource source, {double spacing = 25, bool useView = false, bool replacePrevious = true, bool replaceExisting = false, int maxPoints = 5000, void Function(int done, int total)? onProgress, void Function(Duration wait)? onWait, bool Function()? cancelled}) async {
    final geo = project.meta.georef;
    if (geo == null) throw const GeoReferenceMissing();
    var b = useView ? camera.visible : project.bounds;
    if (b.isEmpty) b = camera.visible;
    if (b.isEmpty) return const DemImportResult(0, 0, (0, 0), (0, 0));
    final pts = demGrid(b, spacing, geo, maxPoints: maxPoints);
    // 5xx and network errors are retried; 429 waits for the server's minute
    bool retryable(Object e) => e is HttpStatusException ? e.status >= 500 : e is! FormatException;
    final zs = source.kind == DemKind.tiles
        ? await demDownloadTiles(pts, demGridStep(pts, spacing), demTileLoader, onProgress: onProgress, cancelled: cancelled, retryable: retryable)
        : await demDownload(
            source,
            pts,
            demUrlLoader,
            onProgress: onProgress,
            onWait: onWait,
            cancelled: cancelled,
            retryable: retryable,
            rateLimited: (e) => e is HttpStatusException && e.status == 429,
          );
    final name = 'DEM ${source.name}';
    var n = 0, noData = 0;
    var lo = double.infinity, hi = -double.infinity;
    mutate(() {
      if (replacePrevious) project.entities.removeWhere((e) => e is SpotHeightEntity && e.isDem);
      if (replaceExisting) project.entities.removeWhere((e) => (e is SpotHeightEntity && !e.isDem) || (e is ContourEntity && !e.derived));
      if (project.findLayer(Layers.dem) == null) project.layers.add(Layer(name: Layers.dem, color: Layers.defaultColors[Layers.dem]!));
      for (var i = 0; i < pts.length && i < zs.length; i++) {
        final z = zs[i];
        if (z == null) {
          noData++;
          continue;
        }
        project.entities.add(SpotHeightEntity(id: project.newId(), layer: Layers.dem, position: pts[i].local, elevation: z, name: name));
        lo = math.min(lo, z);
        hi = math.max(hi, z);
        n++;
      }
    }, label: 'hist.dem');
    track('dem');
    final own = ownTerrainData();
    final demRange = n == 0 ? (0.0, 0.0) : (lo, hi);
    return DemImportResult(n, noData, demRange, own.range, datumMismatch: own.isNotEmpty && n > 0 && demDatumMismatch(own.range, demRange));
  }

  /// Georeferences the project with the drawing origin (0, 0) at the given
  /// WGS84 position. When the drawing is still empty the view frames a
  /// square of [viewSizeM] around the origin, so an online DEM download
  /// covers that area ("type a coordinate, get the terrain").
  void setGeoreferenceAt(double lat, double lon, {double viewSizeM = 500}) {
    final ref = GeoReference.fromLatLonOrigin(lat, lon);
    project.meta.georef = ref;
    dirty = true;
    if (project.bounds.isEmpty && viewSizeM > 0 && !camera.size.isEmpty) {
      camera.fit(Bounds(-viewSizeM / 2, -viewSizeM / 2, viewSizeM / 2, viewSizeM / 2), padding: 24);
    }
    track('georef');
    notify(t('msg.georefAt', {'lat': lat.toStringAsFixed(5), 'lon': lon.toStringAsFixed(5), 'crs': ref.crsName}));
  }

  /// A round contour interval for the current terrain model (about 20
  /// contours at most).
  double autoContourInterval() {
    final terrain = project.buildTerrain();
    if (terrain.isEmpty) return 1;
    final (lo, hi) = terrain.elevationRange;
    return niceContourInterval(hi - lo);
  }

  /// Adds a centre pivot / linear move whose inlet is at [center]; the span
  /// runs towards [end]. The mainline pipe under the inlet is split so the
  /// pivot sits on a node.
  PivotEntity addPivot(Pt center, Pt end) {
    final s = toolSettings;
    final d = end - center;
    final n = project.entities.whereType<PivotEntity>().length + 1;
    final e = PivotEntity(
      id: project.newId(),
      center: center,
      radiusM: math.max(d.length, 1),
      angleDeg: radToDeg(d.angle),
      kind: s.pivotKind,
      travelM: s.pivotKind == PivotKind.linear ? s.pivotTravelM : 0,
      spanLengthM: s.pivotSpan,
      grossDepthMm: s.pivotDepthMm,
      hoursPerCycle: s.pivotHours,
      endPressureM: s.pivotEndPressureM,
      name: '${t('tool.pivot').split('/').first.trim()} $n',
    );
    track('pivot');
    addPointItem(e, center, scopes: const [HydraulicScope.mainline]);
    select([e.id]);
    return e;
  }

  /// Runs the design check and marks the unconnected items on the canvas.
  DesignCheckReport runDesignCheckReport() {
    track('check');
    final r = runDesignCheck(project);
    checkReport = r;
    unconnected = {for (final i in r.issues) if (i.code == 'unconnected') ...i.entityIds};
    notifyListeners();
    return r;
  }

  // ------------------------------------------------------------ densogram
  /// Options of the densogram (Zone → Densogram).
  final DensogramOptions densogramOptions = DensogramOptions();
  Densogram? _densogram;
  String _densogramSig = '';

  /// Picture of the densogram grid (one pixel per cell), decoded after each
  /// computation; null while decoding or when there is nothing to show.
  ui.Image? densogramImage;
  int _densogramImageGen = 0;

  String get _densogramKey => '$_editSeq|${identityHashCode(project)}|${identityHashCode(results)}|${densogramOptions.cellSize}|${densogramOptions.profile.name}|${densogramOptions.useResults}|${densogramOptions.valveIds?.join(',')}';

  /// Water applied by the sprinklers as laid out (recomputed when the
  /// drawing, the results or the options changed).
  Densogram get densogram {
    final sig = _densogramKey;
    final cached = _densogram;
    if (cached != null && sig == _densogramSig) return cached;
    final d = computeDensogram(project, results: results, options: densogramOptions);
    _densogram = d;
    _densogramSig = sig;
    _buildDensogramImage(d);
    return d;
  }

  /// Shows the densogram on the drawing (and computes it).
  Densogram showDensogram() {
    overlay = OverlayMode.densogram;
    track('densogram');
    final d = densogram;
    notifyListeners();
    return d;
  }

  void _buildDensogramImage(Densogram d) {
    final gen = ++_densogramImageGen;
    densogramImage = null;
    if (d.isEmpty) return;
    final px = densogramPixels(d);
    try {
      ui.decodeImageFromPixels(px, d.nx, d.ny, ui.PixelFormat.rgba8888, (img) {
        if (gen != _densogramImageGen) {
          img.dispose();
          return;
        }
        densogramImage = img;
        notifyListeners();
      });
    } catch (_) {
      // no engine (pure Dart tests): the painter falls back to cells
    }
  }

  // ------------------------------------------------------------ images
  /// Decoded image for an image entity (starts decoding on first request).
  ui.Image? imageFor(ImageEntity e) {
    final cached = images[e.id];
    if (cached != null) return cached;
    final data = e.data;
    if (data == null || _decoding.contains(e.id)) return null;
    _decoding.add(e.id);
    ui.instantiateImageCodec(data).then((codec) => codec.getNextFrame()).then((frame) {
      images[e.id] = frame.image;
      _decoding.remove(e.id);
      notifyListeners();
    }).catchError((Object err) {
      _decoding.remove(e.id);
    });
    return null;
  }

  /// Places an imported raster (georeferenced when possible) as an image entity.
  ImageEntity importImage(GeoImage g) {
    ImageEntity e;
    if (g.georeferenced) {
      final (bl, w, h, rot, ref) = placeGeoImage(g, project.meta.georef);
      project.meta.georef ??= ref;
      e = ImageEntity(id: project.newId(), origin: bl, width: w, height: h, rotationDeg: rot, mime: g.mime, data: g.bytes, source: g.source, name: g.source);
    } else {
      // fit into the current view, centred
      final vis = camera.visible;
      final w = math.max(1.0, vis.width * 0.8);
      final h = w * g.heightPx / math.max(1, g.widthPx);
      e = ImageEntity(id: project.newId(), origin: Pt(vis.center.x - w / 2, vis.center.y - h / 2), width: w, height: h, mime: g.mime, data: g.bytes, source: g.source, name: g.source);
    }
    mutate(() => project.entities.insert(0, e), invalidateResults: false, label: 'hist.import|image');
    return e;
  }

  // ------------------------------------------------------------ files
  void newProject() {
    final code = defaultCurrency();
    project = Project(catalog: defaultCatalog(code));
    _applyNewProjectCurrency(code);
    project.meta.name = t('name.newProject');
    results = null;
    selection.clear();
    unconnected = {};
    _forgetProjectViews();
    images.clear();
    _undo.clear();
    _redo.clear();
    dirty = false;
    zoomAll();
  }

  /// Drops what the screen shows about the previous project (profile line,
  /// design check, grade-line pick, densogram, envelopes) when another one
  /// is opened or created.
  void _forgetProjectViews() {
    feedEnvelope.clear();
    profilePath = null;
    checkReport = null;
    hglEntityId = null;
    hoverId = null;
  }

  /// Default catalog in currency [code] (ISO 4217): the user's saved one
  /// (Catalog → "Use as default", converted from the currency it was saved
  /// in) or the built-in generic database.
  Catalog defaultCatalog([String? code]) {
    final cur = code ?? project.params.currencyCode;
    final saved = getPref('catalog.default');
    if (saved != null) {
      try {
        final c = Catalog.fromJson(jsonDecode(saved) as Map<String, dynamic>);
        if (c.pipes.isNotEmpty) {
          // catalogues saved before the currency was recorded were in reais
          final rate = exchangeRate(getPref('catalog.default.currency') ?? catalogPriceCurrency, cur);
          if (rate != null) scaleCatalogPrices(c, rate);
          return c;
        }
      } catch (_) {}
    }
    return Catalog.defaultCatalog(lang: lang, currency: cur);
  }

  /// Saves the project catalogue as the default of new projects (with its
  /// currency, so a project in another currency gets it converted).
  void saveDefaultCatalog() {
    setPref('catalog.default', jsonEncode(project.catalog.toJson()));
    setPref('catalog.default.currency', project.params.currencyCode);
  }

  /// Forgets the saved default catalogue.
  void clearDefaultCatalog() {
    removePref('catalog.default');
    removePref('catalog.default.currency');
  }

  /// Currency of new projects: the user's choice (Parameters → currency,
  /// saved in the browser), else the currency of the machine's region for
  /// the interface language, else the language default.
  String defaultCurrency() {
    final saved = getPref('currency');
    if (saved != null && currencyByCode(saved) != null) return saved;
    return currencyForLocale(lang, systemLanguageTags());
  }

  /// True while the currency of the project is the automatic one of a new,
  /// untouched project (switching the language may then change it).
  bool _autoCurrency = false;

  void _applyNewProjectCurrency(String code) {
    final defaults = DesignParameters();
    final rate = exchangeRate(defaults.currencyCode, code);
    project.params.powerCostPerKwh = defaults.powerCostPerKwh * (rate ?? 1);
    project.params.currencyCode = code;
    project.params.currency = currencySymbol(code);
    _autoCurrency = getPref('currency') == null;
  }

  /// Converts every price of the project to currency [code] with [rate]
  /// (units of [code] per unit of the current currency); without a rate only
  /// the currency changes. [symbol] overrides the symbol shown.
  void setProjectCurrency(String code, {double? rate, String? symbol}) {
    mutate(() => project.setCurrency(code, rate: rate, symbol: symbol), label: 'hist.currency');
    _autoCurrency = false;
  }

  /// A new project nobody has touched follows the interface language: its
  /// automatic currency (and the illustrative prices) move to the default
  /// currency of the new language.
  void _followLanguageCurrency() {
    if (!_autoCurrency || dirty || project.entities.isNotEmpty || _undo.isNotEmpty) return;
    final code = currencyForLocale(lang, systemLanguageTags());
    final from = project.params.currencyCode;
    if (code == from) return;
    final rate = exchangeRate(from, code);
    if (rate == null) return;
    project.setCurrency(code, rate: rate);
    results = null;
  }

  /// Project JSON including the design results (so a reopened project keeps
  /// its report). Marks the project clean and records a version.
  String saveJson({bool pretty = true, bool markClean = true}) {
    final j = project.toJson();
    final r = results;
    if (r != null) j['results'] = r.toJson();
    final s = encodeJson(j, pretty: pretty);
    if (markClean) {
      dirty = false;
      try {
        store.save(project.meta.uid, project.meta.name, pretty ? encodeJson(j) : s, kind: 'saved');
      } catch (_) {}
    }
    return s;
  }

  void loadJson(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final p = Project.fromJson(j);
    DesignResults? r;
    final rj = j['results'];
    if (rj is Map<String, dynamic>) {
      try {
        r = DesignResults.fromJson(rj);
      } catch (e) {
        debugPrint('results: $e');
      }
    }
    openProject(p, results: r);
  }

  /// Shows [p] in place of the current project (a file, a version, an
  /// example): selection, marks, history and cached images of the previous
  /// project are dropped. [dirty] marks it as not saved yet.
  void openProject(Project p, {DesignResults? results, bool dirty = false}) {
    project = p;
    this.results = results;
    selection.clear();
    unconnected = results?.unconnected ?? {};
    _forgetProjectViews();
    _autoCurrency = false;
    images.clear();
    _undo.clear();
    _redo.clear();
    this.dirty = dirty;
    zoomAll();
    notify(t('msg.loaded'));
  }

  int importDxf(String content, {String? layerPrefix}) => importDrawing(DxfReader.parse(content));

  /// Imports any supported drawing/GIS/raster file by extension.
  /// Returns a short description of what was imported.
  String importFile(String name, Uint8List bytes) {
    try {
      return _importFile(name, bytes);
    } on Error catch (e, st) {
      // a damaged file trips the readers' bounds (index, type, state
      // errors): tell the user so instead of the raw error
      debugPrint('$e\n$st');
      throw const FormatException('file_corrupt');
    }
  }

  String _importFile(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dwg')) {
      final r = DwgReader.parse(bytes);
      final n = importDrawing(r.document);
      final skipped = r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof')).length;
      return t('imp.dwg', {'v': r.version.toUpperCase(), 'n': '$n', 'l': '${r.document.layers.length}'}) + (skipped > 0 ? t('imp.skipped', {'n': '$skipped'}) : '');
    }
    if (lower.endsWith('.kmz')) {
      final r = KmlReader.parseKmz(bytes, georef: project.meta.georef);
      project.meta.georef ??= r.georef;
      final n = importDrawing(r.document);
      return t('imp.kml', {'k': 'KMZ', 'p': '${r.placemarkCount}', 'n': '$n', 'crs': r.georef.crsName});
    }
    if (lower.endsWith('.kml')) {
      final r = KmlReader.parse(_decodeText(bytes), georef: project.meta.georef);
      project.meta.georef ??= r.georef;
      final n = importDrawing(r.document);
      return t('imp.kml', {'k': 'KML', 'p': '${r.placemarkCount}', 'n': '$n', 'crs': r.georef.crsName});
    }
    if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.xyz') || lower.endsWith('.pnezd') || lower.endsWith('.pts')) {
      final r = PointsCsvReader.parse(_decodeText(bytes), georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document, asSpots: true);
      return t('imp.points', {'n': '$n', 'geo': r.geographic ? ' (${project.meta.georef?.crsName ?? 'WGS84'})' : ''});
    }
    if (lower.endsWith('.shp') || (lower.endsWith('.zip') && _zipHas(bytes, '.shp'))) {
      final r = ShpReader.parseAny(name, bytes, georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document);
      return t('imp.shp', {'r': '${r.recordCount}', 'n': '$n', 'crs': r.crs.isEmpty ? (project.meta.georef?.crsName ?? '-') : r.crs});
    }
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
      // an elevation raster (one band of heights) becomes terrain, not a picture
      final dem = GeoTiffDemReader.read(bytes, georef: project.meta.georef);
      if (dem != null) {
        project.meta.georef ??= dem.georef;
        final label = 'DEM $name';
        mutate(() {
          project.entities.removeWhere((e) => e is SpotHeightEntity && e.name == label);
          for (final s in dem.samples) {
            project.entities.add(SpotHeightEntity(id: project.newId(), position: s.p, elevation: s.z, name: label));
          }
        }, label: 'hist.dem');
        track('dem');
        zoomAll();
        return t('imp.demTiff', {'n': '${dem.samples.length}', 'w': '${dem.widthPx}', 'h': '${dem.heightPx}', 'crs': dem.crsName});
      }
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.tif') || lower.endsWith('.tiff') || lower.endsWith('.zip')) {
      final g = GeoImageReader.read(name, bytes);
      final e = importImage(g);
      zoomToEntity(e.id);
      return t(g.georeferenced ? 'imp.imageGeo' : 'imp.image', {'w': '${g.widthPx}', 'h': '${g.heightPx}', 'crs': project.meta.georef?.crsName ?? '-'});
    }
    final n = importDrawing(DxfReader.parse(_decodeText(bytes)));
    return t('imp.dxf', {'n': '$n'});
  }

  static bool _zipHas(Uint8List bytes, String ext) {
    // cheap check of the central directory names
    final s = latin1.decode(bytes.length > 200000 ? bytes.sublist(bytes.length - 200000) : bytes, allowInvalid: true).toLowerCase();
    return s.contains(ext);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  /// Converts an imported drawing into project entities (contours and spot
  /// heights when elevations are present).
  int importDrawing(DxfDocument doc, {bool asSpots = false}) {
    final s = doc.unitScale;
    final list = <Entity>[];
    mutate(() {
      for (final l in doc.layers) {
        if (project.layers.every((x) => x.name != l.name)) {
          project.layers.add(Layer(name: l.name, color: _aciToArgb(l.color)));
        }
      }
      for (final e in doc.entities) {
        // a damaged file may hold "nan" or huge exponents: such geometry is
        // left out (it could neither be drawn nor saved)
        if (!_finiteGeometry(e)) continue;
        final layer = e.layer;
        final elev = e.elevation != null && e.elevation!.isFinite ? e.elevation : null;
        switch (e.type) {
          case 'LINE':
            list.add(LineEntity(id: project.newId(), layer: layer, name: e.name, a: e.points[0] * s, b: e.points[1] * s));
          case 'POLYLINE':
            if (e.points.length < 2) break;
            final pts = e.points.map((p) => p * s).toList();
            if (elev != null && elev != 0 && !e.closed && _looksLikeContourLayer(layer)) {
              list.add(ContourEntity(id: project.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
            } else if (elev != null && elev != 0 && !e.closed && pts.length >= 3) {
              list.add(ContourEntity(id: project.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
            } else {
              list.add(PolylineEntity(id: project.newId(), layer: layer, name: e.name, points: pts, closed: e.closed));
            }
          case 'SPLINE':
            if (e.points.length >= 2) list.add(SplineEntity(id: project.newId(), layer: layer, name: e.name, points: e.points.map((p) => p * s).toList(), closed: e.closed));
          case 'HATCH':
            if (e.points.length >= 3) list.add(HatchEntity(id: project.newId(), layer: layer, name: e.name, points: e.points.map((p) => p * s).toList(), angleDeg: e.rotation, spacing: e.height > 0 ? e.height * s : 1, solid: e.solid));
          case 'CIRCLE':
            list.add(CircleEntity(id: project.newId(), layer: layer, name: e.name, center: e.center! * s, radius: e.radius * s));
          case 'ARC':
            var sweep = (e.endAngle - e.startAngle);
            if (sweep <= 0) sweep += 360;
            list.add(ArcEntity(id: project.newId(), layer: layer, name: e.name, center: e.center! * s, radius: e.radius * s, startRad: degToRad(e.startAngle), sweepRad: degToRad(sweep)));
          case 'TEXT':
            list.add(TextEntity(id: project.newId(), layer: layer, name: e.name, position: e.points[0] * s, text: e.text, height: e.height * s, rotationDeg: e.rotation));
          case 'POINT':
            list.add(SpotHeightEntity(id: project.newId(), layer: elev != null || asSpots ? Layers.spotHeights : layer, name: e.name, position: e.points[0] * s, elevation: (elev ?? 0) * s));
        }
      }
      project.entities.addAll(list);
    }, label: 'hist.import');
    zoomAll();
    return list.length;
  }

  static bool _finiteGeometry(DxfEntity e) {
    bool ok(Pt p) => p.x.isFinite && p.y.isFinite;
    return e.points.every(ok) && (e.center == null || ok(e.center!)) && e.radius.isFinite && e.startAngle.isFinite && e.endAngle.isFinite && e.rotation.isFinite && e.height.isFinite;
  }

  static bool _looksLikeContourLayer(String layer) {
    final l = layer.toLowerCase();
    return l.contains('cont') || l.contains('curva') || l.contains('nivel') || l.contains('nível') || l.contains('topo') || l.contains('elev');
  }

  // ------------------------------------------------------------ export
  /// Display names of the layers (legend, KML folders).
  Map<String, String> layerNames() => {for (final l in project.layers) l.name: t.has('layer.${l.name}') ? t('layer.${l.name}') : l.name};

  String entityName(String id) {
    final n = project.byId(id)?.name ?? '';
    return n.isEmpty ? id : n;
  }

  /// Exporter bound to the current project, results and language.
  ProjectExporter exporter() => ProjectExporter(
    project: project,
    results: results,
    unconnected: unconnected,
    layerNames: layerNames(),
    labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w, entityName: entityName), entityName: entityName),
  );

  String exportDxf() => exporter().dxf();

  List<ReportTable>? _tablesCache;
  DesignResults? _tablesFor;
  String _tablesLang = '';
  int _tablesUnconnected = -1;

  /// Report tables for the current results (cached while results and
  /// language are unchanged; cheap to rebuild without results).
  List<ReportTable> reportTables() {
    final r = results;
    if (r == null) return exporter().reportTables();
    if (_tablesCache == null || !identical(_tablesFor, r) || _tablesLang != lang || _tablesUnconnected != unconnected.length) {
      _tablesCache = exporter().reportTables();
      _tablesFor = r;
      _tablesLang = lang;
      _tablesUnconnected = unconnected.length;
    }
    return _tablesCache!;
  }

  String reportCsv() => exporter().reportCsv();

  Map<String, dynamic> debugState() => {'entities': project.entities.length, 'selection': selection.length, 'results': results != null};

  static int _aciToArgb(int aci) {
    const table = <int, int>{1: 0xFFFF5252, 2: 0xFFFFEB3B, 3: 0xFF69F0AE, 4: 0xFF40C4FF, 5: 0xFF448AFF, 6: 0xFFE040FB, 7: 0xFFECEFF1, 8: 0xFF9E9E9E, 9: 0xFFBDBDBD};
    return table[aci] ?? 0xFFB0BEC5;
  }
}

double mathMax(double a, double b) => a > b ? a : b;

String prettyJson(Object o) => const JsonEncoder.withIndent('  ').convert(o);

/// An in-place edit of the project settings by a dialog (see
/// [ProjectController.beginSettingsEdit]).
class SettingsEdit {
  SettingsEdit._(this._state, this._project);
  final _UndoState _state;
  final Project _project;
}

/// Outcome of an online DEM download.
class DemImportResult {
  const DemImportResult(this.count, this.noData, this.range, this.ownRange, {this.datumMismatch = false});

  /// Spot heights created.
  final int count;

  /// Grid points the source had no data for.
  final int noData;

  /// Elevation range of the downloaded points (m).
  final (double, double) range;

  /// Elevation range of the user's own terrain data kept in the project.
  final (double, double) ownRange;

  /// The kept data cannot share a datum with the download (see
  /// [demDatumMismatch]).
  final bool datumMismatch;
}

/// Summary of the user's own elevation data (see
/// [ProjectController.ownTerrainData]).
class OwnTerrainData {
  const OwnTerrainData(this.spots, this.contours, this.lo, this.hi);
  final int spots;
  final int contours;
  final double lo, hi;
  int get count => spots + contours;
  bool get isNotEmpty => count > 0;
  (double, double) get range => (lo, hi);
}
