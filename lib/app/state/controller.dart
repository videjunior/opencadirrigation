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
import '../../core/model/scenario.dart';
import '../../core/model/site_climate.dart';
import '../../core/model/slope_map.dart';
import '../../core/design/design_check.dart';
import '../../core/design/network_builder.dart';
import '../../core/design/report_tables.dart';
import '../../core/design/results.dart';
import '../../core/hydraulics/lateral.dart';
import '../../core/io/cad_drawing.dart' show aciRgb;
import '../../core/io/climate_online.dart';
import '../../core/io/codepages.dart' show decodeTextBytes;
import '../../core/io/dem_online.dart';
import '../../core/io/dem_tiff.dart';
import '../../core/io/dgn.dart';
import '../../core/io/dwg.dart';
import '../../core/io/dxf.dart';
import '../../core/io/epanet_inp.dart';
import '../../core/io/geo.dart';
import '../../core/io/geoimage.dart';
import '../../core/io/geojson_reader.dart';
import '../../core/io/gpx.dart';
import '../../core/io/kml.dart';
import '../../core/io/landxml.dart';
import '../../core/io/las.dart';
import '../../core/io/points_csv.dart';
import '../../core/io/project_export.dart';
import '../../core/io/shp.dart';
import '../../core/io/pdf_import.dart';
import '../../core/io/pdf_reader.dart';
import '../../core/io/shp_writer.dart' show ShapefileParts;
import '../../core/io/work_slicer.dart';
import '../../core/model/catalog.dart';
import '../../core/model/currency.dart';
import '../../core/model/regional.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/model/spatial_index.dart';
import '../../core/model/split.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../canvas/basemap.dart' show BaseMapLayer;
import '../canvas/camera.dart';
import '../i18n.dart';
import '../io/document.dart';
import '../io/gps.dart';
import '../io/http.dart';
import '../io/prefs.dart';
import '../io/project_store.dart';
import '../io/storage_info.dart';
import '../io/wake_lock.dart';
import '../io/window_locks.dart';
import '../keys/canvas_keys.dart';
import 'ai_marks.dart';
import 'design_runner.dart';
import 'outline_check.dart';

/// Language of the interface: the app lays itself out right to left for
/// the languages written that way (see [rtlLanguages]).
final ValueNotifier<String> uiLanguage = ValueNotifier<String>('en');

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
  breakline,
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
  comment,
  revisionCloud,
  insertBlock,
  // the user's marks for the AI assistant (ai_marks.dart): no project items
  aiMarkPoint,
  aiMarkLine,
  // 1.6.0 EDT: move and copy by base point, lasso and fence selection,
  // stretch, fillet, chamfer and break at two points (edit_tools.dart)
  move,
  copy,
  lasso,
  fence,
  stretch,
  fillet,
  chamfer,
  breakTwo,
  // 1.6.0 AUT: the outline of a field traced on the satellite image (trace_image_tool.dart)
  traceImage;

  /// One of the tools that mark the drawing for the AI assistant.
  bool get isAiMark => this == aiMarkPoint || this == aiMarkLine;
}

enum OverlayMode { none, velocity, pressure, sizes, minMax, densogram, slope, aspect }

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

  /// Polar tracking step (degrees; 0 = off): from the previous point the
  /// cursor locks onto multiples of it when close (F10 cycles the steps).
  double polarStepDeg = 0;

  /// The steps F10 and the status bar cycle through (0 = off).
  static const polarSteps = [0.0, 15.0, 30.0, 45.0, 90.0];

  void nextPolarStep() {
    final i = polarSteps.indexOf(polarStepDeg);
    polarStepDeg = polarSteps[(i + 1) % polarSteps.length];
  }
}

/// Current defaults used by the creation tools.
class ToolSettings {
  /// Author written on new review comments (the last one typed).
  String commentAuthor = '';

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
  ArrayOptions({
    this.polar = false,
    this.rows = 2,
    this.cols = 2,
    this.dx = 5,
    this.dy = 5,
    this.angleDeg = 0,
    this.count = 6,
    this.center = Pt.zero,
    this.totalAngleDeg = 360,
    this.rotateItems = true,
  });
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
  _UndoState(this.entities, this.rest, this.label, this.time, {this.results, this.unconnected = const {}, this.advice, this.vertices = 0, this.restChars = 0});
  final List<Entity> entities;
  final Map<String, dynamic> rest;

  /// Label of the action that follows this state (`hist.*` key, optional
  /// `|argument` for the entity kind or a count).
  final String label;
  final DateTime time;

  /// The results on screen in this state, the items they found unconnected
  /// and the design assistant's messages (replaced by every design, never
  /// changed in place): undo and redo bring them back with the drawing.
  /// The oldest states let them go (see [ProjectController.undoResultsKept]).
  DesignResults? results;
  final Set<String> unconnected;
  List<Advice>? advice;

  /// Vertices of the entities kept and characters of the rest of the
  /// project (settings, catalogue, scenarios): what the undo budget counts.
  final int vertices;
  final int restChars;
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

  Map<String, int>? _byId;
  SpatialIndex? _byIdIndex;
  final Set<String> _notById = {};

  /// Position of the entity with [id] in the project's list (drawing
  /// order), through a map kept with the spatial index (the project's own
  /// lookup scans every entity).
  int? entityIndex(String id) {
    final idx = index;
    if (!identical(idx, _byIdIndex)) {
      final ents = idx.entities;
      _byId = {for (var i = 0; i < ents.length; i++) ents[i].id: i};
      _byIdIndex = idx;
      _notById.clear();
    }
    final i = _byId![id];
    if (i != null && i < idx.entities.length && idx.entities[i].id == id) return i;
    // an entity replaced in place without an edit: look it up the slow way
    // (once: an id that is not there is remembered until the next edit)
    if (_notById.contains(id)) return null;
    final j = idx.entities.indexWhere((e) => e.id == id);
    if (j < 0) {
      _notById.add(id);
      return null;
    }
    _byId![id] = j;
    return j;
  }

  /// The entity with [id] (see [entityIndex]).
  Entity? entityById(String id) {
    final i = entityIndex(id);
    return i == null ? null : index.entities[i];
  }

  /// Marks the entity geometry as changed outside [mutate] (the spatial
  /// index is rebuilt on the next query).
  void entitiesChanged() => _editSeq++;

  Map<String, int>? _layerCounts;
  SpatialIndex? _layerCountsIndex;

  /// Number of entities on each layer (kept with the spatial index, so the
  /// layer list does not count the whole project on every rebuild).
  Map<String, int> get layerCounts {
    final idx = index;
    if (_layerCounts == null || !identical(idx, _layerCountsIndex)) {
      final counts = <String, int>{};
      for (final e in idx.entities) {
        counts[e.layer] = (counts[e.layer] ?? 0) + 1;
      }
      _layerCounts = counts;
      _layerCountsIndex = idx;
    }
    return _layerCounts!;
  }

  /// Bumped by every [notifyListeners]: the canvas records its drawing again
  /// when it changed (see SceneCache).
  int get notifySeq => _notifySeq;
  int _notifySeq = 0;

  @override
  void notifyListeners() {
    // a closed tab: what still completes (a copy, a design, a picture) tells nobody
    if (_disposed) return;
    _notifySeq++;
    super.notifyListeners();
  }

  /// Tells the listeners about a change the drawing does not show (the
  /// progress of a design): the canvas keeps its scene.
  void _notifyQuiet() {
    if (!_disposed) super.notifyListeners();
  }

  /// Set by [dispose] (the tab was closed).
  bool _disposed = false;
  bool get disposed => _disposed;
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

  /// The base map of the current view for the plot sheet, set by the
  /// canvas that draws it: PNG bytes and world corners (bottom-left first);
  /// completes with null without a map on screen.
  Future<(Uint8List, List<Pt>)?> Function()? baseMapSnapshot;

  /// Credit line of the base map on screen (set by the canvas).
  String Function()? baseMapAttribution;

  /// The user's Google Maps Platform API key (Map Tiles API), kept in the
  /// browser only (or, when the user chose so, in this page only, gone at
  /// the next visit); null until the user enters one.
  String? googleMapsKey = _sessionGoogleKey ?? _savedPref('basemap.googleKey');

  /// A key kept for this visit only (shared by the tabs).
  static String? _sessionGoogleKey;

  /// Whether the Google key is kept in the browser between visits.
  bool get googleKeyRemembered => getPref('basemap.googleKey') != null;

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

  /// Sets the Google key; [remember] keeps it in the browser for the next
  /// visits (any script of the site can read what the browser keeps), else
  /// it lasts as long as the page.
  void setGoogleMapsKey(String? key, {bool remember = true}) {
    final k = key?.trim();
    googleMapsKey = k == null || k.isEmpty ? null : k;
    baseMapEpoch++;
    if (googleMapsKey == null || !remember) {
      removePref('basemap.googleKey');
    } else {
      setPref('basemap.googleKey', googleMapsKey!);
    }
    _sessionGoogleKey = remember ? null : googleMapsKey;
    notifyListeners();
  }

  /// The tile server of the street map (empty: the OpenStreetMap
  /// Foundation's, see [BaseMapLayer.streetsTemplate]), kept in the browser.
  String get streetsTileUrl => getPref('basemap.osmUrl') ?? '';

  /// Sets the street map server (empty for the default one).
  void setStreetsTileUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) {
      removePref('basemap.osmUrl');
    } else {
      setPref('basemap.osmUrl', u);
    }
    BaseMapLayer.streetsTemplate = u;
    baseMapEpoch++;
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

  /// Undo depth: up to [maxUndo] steps while the copies kept stay below
  /// [undoEntityBudget] entities, [undoVertexBudget] vertices and
  /// [undoRestBudget] characters of settings in all (a large drawing, or a
  /// survey of a few very dense contours, keeps fewer steps).
  static const maxUndo = 150;
  static const undoEntityBudget = 400000;
  static const undoVertexBudget = 4000000;
  static const undoRestBudget = 40 * 1000 * 1000;

  /// Undo states that keep their results (each design makes new ones): the
  /// older states keep the drawing only.
  static const undoResultsKept = 24;

  void _trimUndo() {
    var entities = 0, vertices = 0, rest = 0;
    for (final u in _undo) {
      entities += u.entities.length;
      vertices += u.vertices;
      rest += u.restChars;
    }
    while (_undo.length > 1 && (_undo.length > maxUndo || entities > undoEntityBudget || vertices > undoVertexBudget || rest > undoRestBudget)) {
      final u = _undo.removeAt(0);
      entities -= u.entities.length;
      vertices -= u.vertices;
      rest -= u.restChars;
    }
    // the results of the oldest states go first
    final kept = <DesignResults>{};
    for (final list in [_redo, _undo.reversed]) {
      for (final u in list) {
        final r = u.results;
        if (r == null) continue;
        if (kept.contains(r) || kept.length < undoResultsKept) {
          kept.add(r);
        } else {
          u
            ..results = null
            ..advice = null;
        }
      }
    }
  }

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

  /// Last drawing tool, reactivated with Enter while selecting (the usual CAD repeat).
  ToolId lastTool = ToolId.line;

  /// Command typed on the canvas (the usual CAD command aliases), shown in the status bar.
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

  /// Decoded raster images by entity id, at most [imageMaxSide] pixels on
  /// their longest side (the screen never needs more; the entity keeps the
  /// file's own bytes for the exports).
  final Map<String, ui.Image> images = {};
  final Set<String> _decoding = {};

  /// The bytes each decoded image came from: an entity whose bytes changed
  /// (another picture under the same id) is decoded again.
  final Map<String, Uint8List> _imageBytes = {};

  /// Longest side of a decoded picture: a drone orthophoto of 10 000 px
  /// takes about 400 MB decoded in full, and no screen shows it finer.
  static int imageMaxSide = 4096;

  /// Called after the language changes so a workspace can propagate it to other tabs.
  void Function(String lang)? onLanguageChanged;

  Units get units => project.params.units;

  void _init() {
    camera.center = const Pt(60, 30);
    camera.scale = 5;
    _claimUid();
    setDocumentLanguage(lang);
    // a controller is made while the shell builds: tell the app afterwards
    final l = lang;
    scheduleMicrotask(() => uiLanguage.value = l);
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
    uiLanguage.value = l;
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
      if (e.message.startsWith('pdf_') && t.has('pdfimp.err.${e.message.substring(4)}')) return t('pdfimp.err.${e.message.substring(4)}');
      if (t.has('imp.err.${e.message}')) return t('imp.err.${e.message}');
      // a code with a detail: `las_format_unsupported:7`
      final i = e.message.indexOf(':');
      if (i > 0 && t.has('imp.err.${e.message.substring(0, i)}')) return t('imp.err.${e.message.substring(0, i)}', {'v': e.message.substring(i + 1)});
      return e.message;
    }
    if (e is GeoReferenceMissing) return t('geo.none');
    if (e is ClimateException) {
      final base = t.has('msg.${e.code}') ? t('msg.${e.code}') : e.code;
      return (e.detail ?? '').isEmpty ? base : '$base (${e.detail})';
    }
    return '$e';
  }

  void refresh() => notifyListeners();

  // ------------------------------------------------------------ undo / redo
  _UndoState _capture(String label) {
    var vertices = 0;
    final copies = <Entity>[];
    for (final e in project.entities) {
      vertices += e is PolyEntity ? e.points.length : 1;
      copies.add(e.clone());
    }
    final rest = project.toJson(includeEntities: false);
    return _UndoState(copies, rest, label, DateTime.now(), results: results, unconnected: unconnected, advice: _advice, vertices: vertices, restChars: _restChars(rest));
  }

  /// Characters of the settings part of a state, roughly (the catalogue
  /// and the scenarios dominate it): what the undo budget counts.
  static int _restChars(Map<String, dynamic> rest) {
    try {
      return jsonEncode(rest).length;
    } catch (_) {
      return 0;
    }
  }

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

  /// Called before the history changes — a new undo step, an undo, a redo,
  /// a jump in the history, a settings dialog opening — so that whoever is
  /// grouping steps of their own meanwhile (the AI assistant's turn) can
  /// close the group first: the user's step then stays apart from theirs.
  final List<void Function()> beforeHistoryChange = [];

  void _beforeHistory() {
    for (final f in [...beforeHistoryChange]) {
      f();
    }
  }

  /// Goes back (or forward) to the state at [index] of [historyEntries].
  void jumpToHistory(int index) {
    _beforeHistory();
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
    // 1.6.0 AGB
    TravellerEntity _ => 'traveller',
    FurrowEntity _ => 'furrows',
    AreaEntity _ => 'area',
    ControllerEntity _ => 'controller',
    WireEntity _ => 'wire',
    OrdinateDimensionEntity _ => 'dimOrdinate',
    _ => 'select',
  };

  /// The project of state [s]. Its id counter never goes back: an id given
  /// after the state was captured is not given again (it may still name a
  /// cached picture, a grade-line pick or an item of another tab's paste).
  Project _restore(_UndoState s) {
    final p = Project.fromJson({...s.rest, 'entities': const []});
    p.entities.addAll(s.entities.map((e) => e.clone()));
    p.ensureNextId(math.max(project.nextIdValue, _highestId));
    _highestId = p.nextIdValue;
    return p;
  }

  /// The highest id counter any state of this project reached.
  int _highestId = 0;

  /// Puts back the results, unconnected items and messages of state [s].
  void _restoreResults(_UndoState s) {
    results = s.results;
    unconnected = s.unconnected;
    _advice = s.advice;
    if (_advice != null) _adviceSig = _adviceSignature();
  }

  void _snapshot([String label = 'hist.edit']) {
    _beforeHistory();
    _editSeq++;
    _undo.add(_capture(label));
    _trimUndo();
    _redo.clear();
    historyTouched = DateTime.now();
  }

  /// Takes back the snapshot [st] of an action that did not happen (failed,
  /// cancelled): the project as it was and the redo steps it cleared.
  void _dropSnapshot(_UndoState st, List<_UndoState> redo, {bool restore = false}) {
    final i = _undo.lastIndexOf(st);
    if (i >= 0) _undo.removeAt(i);
    if (restore) project = _restore(st);
    if (_redo.isEmpty) _redo.addAll(redo);
    _editSeq++;
  }

  /// Runs a mutation with an undo snapshot; [label] names the action in the
  /// history panel (`hist.*` key, optional `|argument`). Refused (returns
  /// null, tells the user) while a design runs: its result replaces the
  /// hydraulic entities, so an edit made meanwhile would be lost. A mutation
  /// that throws changes nothing: the project goes back to the snapshot (an
  /// edit half applied would leave it inconsistent) and the error goes on.
  T? mutate<T>(T Function() fn, {bool invalidateResults = true, String? label}) {
    if (!editAllowed()) return null;
    track('edit');
    final redo = List.of(_redo);
    _snapshot(label ?? 'hist.edit');
    final st = _undo.last;
    final T r;
    try {
      r = fn();
    } catch (_) {
      _dropSnapshot(st, redo, restore: true);
      notifyListeners();
      rethrow;
    }
    _editSeq++; // geometry changed: the spatial index is stale
    // the pictures of what was deleted or replaced are let go
    if (images.isNotEmpty) _pruneImages();
    dirty = true;
    project.meta.modified = DateTime.now();
    if (invalidateResults) {
      results = null;
      feedEnvelope.clear();
      _scheduleAutoAnalysis();
    }
    notifyListeners();
    _autosaveMaybe();
    return r;
  }

  /// Starts an in-place edit of the project settings (details, parameters,
  /// catalogue, layers, system flows) by a dialog; hand the returned token
  /// to [commitSettingsEdit] when the dialog closes, however it is closed.
  SettingsEdit beginSettingsEdit([String label = 'hist.settings']) {
    _beforeHistory();
    return SettingsEdit._(_capture(label), project, dirty, results);
  }

  /// Ends an edit started with [beginSettingsEdit] by putting back what the
  /// dialog changed (its Cancel, Esc, a tap outside): the project, the
  /// results and the "modified" mark as they were when it opened; the undo
  /// steps recorded meanwhile go away. Returns whether anything was put
  /// back.
  bool cancelSettingsEdit(SettingsEdit edit) {
    if (!identical(edit._project, project)) return false; // another project was opened meanwhile
    final before = edit._state;
    var mutated = false;
    while (_undo.isNotEmpty && !_undo.last.time.isBefore(before.time)) {
      _undo.removeLast();
      mutated = true;
    }
    final same = jsonEncode(before.rest) == jsonEncode(project.toJson(includeEntities: false)) && before.entities.length == project.entities.length;
    if (same && !mutated) return false;
    _editSeq++;
    project = _restore(before);
    results = edit._results;
    dirty = edit._dirty;
    feedEnvelope.clear();
    historyTouched = DateTime.now();
    notifyListeners();
    return true;
  }

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
    // 1.6.0 AGB: 'agb' (pump house, solar, water quality, two-wire settings); 1.6.0 PRB: 'deliverables'
    const sections = ['meta', 'units', 'params', 'catalog', 'layers', 'systemFlows', 'currentLayer', 'proposal', 'labelRules', 'agb', 'deliverables'];
    final changed = [
      for (final k in sections)
        if (part(before, k) != part(now, k)) k,
    ];
    // undo steps recorded while the dialog was open (currency conversion…)
    var mutated = 0;
    while (_undo.isNotEmpty && !_undo.last.time.isBefore(edit._state.time)) {
      _undo.removeLast();
      mutated++;
    }
    if (changed.isEmpty && mutated == 0) return false;
    _editSeq++;
    _undo.add(edit._state);
    _trimUndo();
    _redo.clear();
    historyTouched = DateTime.now();
    dirty = true;
    project.meta.modified = DateTime.now();
    if (changed.any((k) => k == 'params' || k == 'catalog' || k == 'systemFlows' || k == 'agb')) {
      results = null;
      feedEnvelope.clear();
      _scheduleAutoAnalysis();
    }
    notifyListeners();
    _autosaveMaybe();
    return true;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Whether the project may be edited now; when not (a design is running,
  /// or "fix automatically" / "optimise" between their rounds) the user is
  /// told why.
  bool editAllowed() {
    if (!busy && !_assistantRounds) return true;
    notify(t('msg.designBusy'));
    return false;
  }

  /// "Fix automatically" or "optimise" is working in rounds: the project
  /// stays as they leave it between two designs, so nothing else edits it.
  bool _assistantRounds = false;

  void _undoOnce() {
    _editSeq++;
    final st = _undo.removeLast();
    _redo.add(_capture(st.label));
    project = _restore(st);
    selection.clear();
    _restoreResults(st);
    feedEnvelope.clear();
    dirty = true;
    historyTouched = DateTime.now();
    _pruneImages();
  }

  void _redoOnce() {
    _editSeq++;
    final st = _redo.removeLast();
    _undo.add(_capture(st.label));
    project = _restore(st);
    selection.clear();
    _restoreResults(st);
    feedEnvelope.clear();
    dirty = true;
    historyTouched = DateTime.now();
    _pruneImages();
  }

  void undo() {
    track('undo');
    if (_undo.isNotEmpty && editAllowed()) {
      _beforeHistory();
      _undoOnce();
      _scheduleAutoAnalysis();
    }
    // listeners (the tutorial) see the tracked command even with nothing to undo
    notifyListeners();
  }

  void redo() {
    track('redo');
    if (_redo.isNotEmpty && editAllowed()) {
      _beforeHistory();
      _redoOnce();
      _scheduleAutoAnalysis();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ autosave
  /// Time between copies while the editing goes on: the first edit after a
  /// quiet moment is copied at once (in the background, see
  /// [_autosaveInBackground]), the edits that follow within this time once
  /// it has passed, so the last edits of a burst always reach the copy.
  static Duration autosaveInterval = const Duration(seconds: 3);

  /// Whether the last edits of a burst get their copy from a timer: in the
  /// browser, where the copy recovers the work after a crash (elsewhere the
  /// store is in memory, and the tests that check it turn it on).
  static bool trailingAutosave = kIsWeb;
  Timer? _autosaveTimer;

  /// [editSeq] of the project as the browser store last kept it.
  int _storedSeq = -1;

  /// Changes the browser store has not been given yet.
  bool get unsavedInBrowser => autosaveEnabled && project.entities.isNotEmpty && _editSeq != _storedSeq;

  /// Why the last copy or save of this project could not be kept in the
  /// browser (message key and its arguments), until a later one is kept:
  /// the status bar shows it until then.
  (String, Map<String, String>)? _storeProblem;

  /// The text of [_storeProblem]; null while the browser keeps the project.
  String? get storeProblem => _storeProblem == null ? null : t(_storeProblem!.$1, _storeProblem!.$2);

  void _autosaveMaybe() {
    if (!autosaveEnabled || _disposed) return;
    final wait = autosaveInterval - DateTime.now().difference(_lastAutosave);
    if (wait <= Duration.zero) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      unawaited(_autosaveInBackground());
    } else if (trailingAutosave && _autosaveTimer == null) {
      _autosaveTimer = Timer(wait, () {
        _autosaveTimer = null;
        if (!_disposed && unsavedInBrowser) unawaited(_autosaveInBackground());
      });
    }
  }

  /// Bumped by every copy started and every save: a copy still compressing
  /// in the background is stored only if nothing newer came meanwhile.
  int _autosaveRun = 0;

  /// The copy in the browser at once (a tab being closed, the page hidden,
  /// an error): written during the call when the store is synchronous
  /// (memory: desktop builds, tests), otherwise compressed by the browser
  /// and written in the background. Completes once it is kept or refused.
  Future<void> autosaveNow() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!autosaveEnabled || project.entities.isEmpty || _disposed) return Future<void>.value();
    if (!store.synchronous) return _autosaveInBackground();
    _lastAutosave = DateTime.now();
    _autosaveRun++;
    final seq = _editSeq, uid = project.meta.uid;
    try {
      final (json, stored, limit) = _storeJson();
      final done = store.save(uid, project.meta.name, json, kind: 'autosave', stored: stored, edited: project.meta.modified).then((o) => _stored(o, seq, uid));
      // the copy in the browser is what recovers the work after a crash:
      // say once per project when it is incomplete or impossible
      if (limit != null && _autosaveWarned != uid) {
        _autosaveWarned = uid;
        final mb = fmt(json.length / 1e6, 1);
        scheduleMicrotask(() => notify(t(limit, {'mb': mb})));
      }
      return done;
    } catch (_) {
      // storage unavailable: ignore
      return Future<void>.value();
    }
  }

  /// The copy at once only when the browser store lacks some changes (the
  /// page hidden, an error).
  Future<void> autosaveIfChanged() => unsavedInBrowser ? autosaveNow() : Future<void>.value();

  /// The changes the browser store lacks, kept at once in localStorage
  /// while the page is being closed (a database write started now may never
  /// finish); the next start makes them the copy of the project, which the
  /// recovery offers.
  void rescueNow() {
    if (!unsavedInBrowser || _disposed || store.synchronous) return;
    try {
      final (json, stored, limit) = _storeJson();
      if (limit == 'msg.autosaveTooLarge') return;
      store.rescue(project.meta.uid, project.meta.name, stored, bytes: json.length, edited: project.meta.modified);
    } catch (_) {
      // nothing more can be done while the page goes away
    }
  }

  /// The copy in the browser without holding the interface: the text of
  /// the project is taken now, the browser compresses it beside the app
  /// (compressing a large project in Dart held everything for seconds after
  /// each design) and the copy is stored when that is done; when it does
  /// not fit, again without the embedded pictures, as [autosaveNow] does.
  /// The store's answer is checked: a copy that could not be kept is shown
  /// in the status bar until one is ([storeProblem]).
  Future<void> _autosaveInBackground() async {
    if (!autosaveEnabled || project.entities.isEmpty || _disposed) return;
    // a project already found too large is not compressed again on every
    // edit, only once it has fewer entities
    final big = _tooLarge;
    if (big != null && big.$1 == project.meta.uid && project.entities.length >= big.$2) return;
    _lastAutosave = DateTime.now();
    final run = ++_autosaveRun;
    // a project open in another window gets a uid of its own first (a uid set from outside is claimed now)
    if (_claimedUid != project.meta.uid) _claimUid();
    await _claim;
    // (a tab closed meanwhile still writes its last copy: its project is intact)
    if (run != _autosaveRun) return;
    final uid = project.meta.uid, name = project.meta.name, count = project.entities.length, seq = _editSeq, edited = project.meta.modified;
    try {
      final j = _saveMap();
      var json = encodeJson(j, pretty: false);
      var stored = await LocalProjectStore.encodeAsync(json);
      String? limit;
      if (stored.length > store.maxBytes) {
        if (run != _autosaveRun) return;
        // as autosaveNow: the embedded pictures are left out of the copy
        var dropped = false;
        for (final e in (j['entities'] as List).cast<Map<String, dynamic>>()) {
          dropped = e.remove('data') != null || dropped;
        }
        if (dropped) {
          json = encodeJson(j);
          stored = await LocalProjectStore.encodeAsync(json);
        }
        limit = stored.length > store.maxBytes ? 'msg.autosaveTooLarge' : (dropped ? 'msg.autosaveNoImages' : null);
      }
      if (run != _autosaveRun) return;
      if (limit == 'msg.autosaveTooLarge') {
        _tooLarge = (uid, count);
        // the chip of the status bar; the message with the size follows
        _storeFailed(uid, 'store.err.tooLarge', quiet: true);
      } else {
        _stored(await store.save(uid, name, json, kind: 'autosave', stored: stored, edited: edited), seq, uid);
      }
      if (limit != null && _autosaveWarned != uid && uid == project.meta.uid && !_disposed) {
        _autosaveWarned = uid;
        notify(t(limit, {'mb': fmt(json.length / 1e6, 1)}));
      }
    } catch (_) {
      // storage unavailable: ignore
    }
  }

  /// After a write of project [uid] at [seq]: what the browser now keeps,
  /// or why it does not.
  void _stored(StoreOutcome o, int seq, String uid) {
    if (_disposed || uid != project.meta.uid) return;
    if (o.ok) {
      _storedSeq = seq;
      if (_storeProblem != null) {
        _storeProblem = null;
        notifyListeners();
      }
      // once per browser: these copies are no backup (Safari erases them after a week away)
      if (!store.synchronous && getPref('store.advised') == null) {
        setPref('store.advised', '1');
        notify(t(browserIsSafari ? 'store.adviceSafari' : 'store.advice'));
      }
      if (!o.versionKept && _versionWarned != uid) {
        _versionWarned = uid;
        notify(t('store.err.version'));
      }
      return;
    }
    _storeFailed(uid, switch (o.status) {
      StoreStatus.tooLarge => 'store.err.tooLarge',
      StoreStatus.unavailable => 'store.err.unavailable',
      _ => 'store.err.full',
    });
  }

  String? _versionWarned;

  void _storeFailed(String uid, String key, {Map<String, String> args = const {}, bool quiet = false}) {
    if (_disposed || uid != project.meta.uid) return;
    // a copy too large was told with its size already (msg.autosaveTooLarge)
    final first = _storeProblem?.$1 != key && !quiet && !(key == 'store.err.tooLarge' && _autosaveWarned == uid);
    _storeProblem = (key, args);
    if (first) {
      notify(t(key, args));
    } else {
      notifyListeners();
    }
  }

  /// The project (uid, entity count) whose copy did not fit the store even
  /// compressed and without its pictures.
  (String, int)? _tooLarge;

  String? _autosaveWarned;

  /// Once per project, a note (with a leading space) when the terrain has
  /// more samples than the TIN triangulates ([Terrain.maxTinPoints]): the
  /// surface is then built from a uniform subset, which the user should know
  /// before trusting a profile; '' otherwise.
  String _tinNote() {
    if (_tinWarned == project.meta.uid || project.params.terrainMethod != TerrainMethod.tin) return '';
    final n = project.buildTerrain().samples.length;
    if (n <= Terrain.maxTinPoints) return '';
    _tinWarned = project.meta.uid;
    final k = (n / Terrain.maxTinPoints).ceil();
    return ' ${t('msg.tinThinned', {'n': '$n', 'k': '$k', 'm': '${(n / k).round()}'})}';
  }

  String? _tinWarned;

  /// Project JSON for the browser store (results included; embedded images
  /// dropped when the file would exceed the store limit), its stored form
  /// (compressed once, see [LocalProjectStore.encode]) and the message key
  /// of what the copy leaves out (null = complete).
  (String, String, String?) _storeJson() {
    final j = _saveMap();
    var s = encodeJson(j, pretty: false);
    var stored = LocalProjectStore.encode(s);
    // large projects are stored compressed; drop the embedded pictures only
    // when even that does not fit
    if (stored.length > store.maxBytes) {
      var dropped = false;
      for (final e in (j['entities'] as List).cast<Map<String, dynamic>>()) {
        dropped = e.remove('data') != null || dropped;
      }
      if (dropped) {
        s = encodeJson(j);
        stored = LocalProjectStore.encode(s);
      }
      if (stored.length > store.maxBytes) return (s, stored, 'msg.autosaveTooLarge');
      return (s, stored, dropped ? 'msg.autosaveNoImages' : null);
    }
    return (s, stored, null);
  }

  // ------------------------------------------------------------ entities
  /// Whether a change of [e] can change the design results: the network
  /// (pipes, laterals, emitters, valves, pumps, pivots), the terrain they
  /// are computed over (contours other than those generated from the model,
  /// spot heights, breaklines), the irrigated areas, the valve wiring and
  /// the closed outlines a pivot follows (corner arm, variable rate).
  /// Annotations, dimensions, pictures and plain drawing keep the results.
  bool affectsResults(Entity e) {
    if (e.isHydraulic || e is SpotHeightEntity || e is BreaklineEntity || e is AreaEntity || e is WireEntity || e is ControllerEntity) return true;
    if (e is ContourEntity) return !e.derived;
    if (e is PolylineEntity || e is SplineEntity) return _pivotOutlines().contains(e.id);
    return false;
  }

  /// [affectsResults] for any of [es].
  bool anyAffectsResults(Iterable<Entity> es) => es.any(affectsResults);

  Set<String>? _pivotOutlineIds;
  int _pivotOutlineSeq = -1;

  /// Ids of the outlines the pivots of the project follow.
  Set<String> _pivotOutlines() {
    if (_pivotOutlineIds != null && _pivotOutlineSeq == _editSeq) return _pivotOutlineIds!;
    final ids = <String>{};
    for (final e in project.entities) {
      if (e is! PivotEntity) continue;
      final m = e.machine;
      if (m.guidePathId != null) ids.add(m.guidePathId!);
      ids.addAll(m.vriZones.keys);
    }
    _pivotOutlineSeq = _editSeq;
    return _pivotOutlineIds = ids;
  }

  void addEntity(Entity e) {
    mutate(() => project.entities.add(e), invalidateResults: affectsResults(e), label: 'hist.add|${toolKeyOf(e)}');
    // 1.6.0 AUT: an area drawn crossing itself is said at once (AUT-05)
    warnSelfCrossingAreas(this, [e]);
  }

  void addEntities(Iterable<Entity> es, {String? label}) {
    final list = es.toList();
    mutate(() => project.entities.addAll(list), invalidateResults: anyAffectsResults(list), label: label ?? 'hist.addMany|${list.length}');
    // 1.6.0 AUT
    warnSelfCrossingAreas(this, list);
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

  /// Names of the locked layers and of the hidden ones (one pass over the
  /// layers per call, instead of a search of the layer list per entity).
  Set<String> get _lockedLayers => {
    for (final l in project.layers)
      if (l.locked) l.name,
  };
  Set<String> get _hiddenLayers => {
    for (final l in project.layers)
      if (!l.visible) l.name,
  };

  /// Selected entities that are not on a locked layer.
  List<Entity> get editableSelection {
    if (selection.isEmpty) return const [];
    final locked = _lockedLayers;
    return project.entities.where((e) => selection.contains(e.id) && !locked.contains(e.layer)).toList();
  }

  /// Deletes the editable selection; the number deleted (0 when nothing
  /// could be: a locked layer, a design running).
  int deleteSelected() {
    track('delete');
    if (selection.isEmpty) return 0;
    final targets = editableSelection;
    final ids = targets.map((e) => e.id).toSet();
    if (ids.isEmpty) {
      notify(t('msg.layerLocked'));
      return 0;
    }
    final done = mutate(
      () {
        project.entities.removeWhere((e) => ids.contains(e.id));
        return true;
      },
      invalidateResults: anyAffectsResults(targets),
      label: 'hist.delete|${ids.length}',
    );
    // refused (a design is running): nothing was deleted, the selection stays
    if (done != true) return 0;
    selection.removeAll(ids);
    notify(t('msg.deleted', {'n': '${ids.length}'}));
    return ids.length;
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
    mutate(
      () {
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
      },
      invalidateResults: anyAffectsResults(targets),
      label: label ?? (copy ? 'hist.copy|${targets.length}' : 'hist.transform|${targets.length}'),
    );
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
    mutate(
      () {
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
      },
      invalidateResults: anyAffectsResults(targets),
      label: 'hist.array',
    );
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
    final done = mutate(
      () {
        project.entities.add(out);
        return true;
      },
      invalidateResults: affectsResults(out),
      label: 'hist.offset',
    );
    if (done != true) return null;
    select([out.id]);
    return out;
  }

  /// Entities used as cutting/boundary edges (lines, polylines with their
  /// closing side, circles, arcs, splines along their curve): the selection
  /// when it holds any (other than [exclude]), else the visible ones [near]
  /// gives (the spatial index around the edited entity), else every visible
  /// one.
  List<Entity> _boundaries(String exclude, {Iterable<Entity> Function()? near}) {
    final sel = selection.isEmpty ? const <Entity>[] : project.entities.where((e) => selection.contains(e.id) && e.id != exclude && CutEdge.supports(e)).toList();
    if (sel.isNotEmpty) return sel;
    final candidates = near == null ? visibleEntities() : near();
    return candidates.where((e) => e.id != exclude && CutEdge.supports(e)).toList();
  }

  /// Visible entities along the ray from [from] towards [dir] across the
  /// drawing: the boxes of a corridor of the spatial index, so an extension
  /// in a dense survey looks only at what lies ahead.
  List<Entity> _alongRay(Pt from, Pt dir) {
    final b = project.bounds;
    if (b.isEmpty || dir.length < 1e-12) return visibleEntities();
    final u = dir * (1 / dir.length);
    final reach = math.sqrt(b.width * b.width + b.height * b.height) + from.distanceTo(b.center);
    const steps = 32;
    final step = reach / steps;
    final half = math.max(step / 2, 1e-3);
    final seen = <String>{};
    final out = <Entity>[];
    for (var k = 0; k <= steps; k++) {
      final c = from + u * (step * k);
      for (final e in entitiesIn(Bounds(c.x - half, c.y - half, c.x + half, c.y + half))) {
        if (seen.add(e.id)) out.add(e);
      }
    }
    return out;
  }

  List<double> _cutStations(Entity target, List<Entity> boundaries) {
    final pts = target.linearPoints!;
    final cuts = <double>[];
    for (final b in boundaries) {
      for (final p in CutEdge.of(b)?.crossings(pts, closedPts: target.isClosedShape) ?? const <Pt>[]) {
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
    final cuts = _cutStations(e, _boundaries(id, near: () => entitiesIn(e.bounds.inflate(1e-6))));
    if (cuts.isEmpty) return false;
    final (at, _) = polylineStationOf(e.linearPoints!, world);
    final pieces = trimLinearEntity(e, at, cuts, () => project.newId());
    if (pieces.length == 1 && identical(pieces.first, e)) return false;
    final done = mutate(
      () {
        final idx = project.entities.indexOf(e);
        project.entities.removeAt(idx);
        project.entities.insertAll(idx, pieces);
        return true;
      },
      invalidateResults: affectsResults(e),
      label: 'hist.trim',
    );
    if (done != true) return false;
    selection.remove(id);
    return true;
  }

  /// Extends the end of [id] nearest to [world] to the boundaries.
  bool extendAt(String id, Pt world) {
    final e = project.byId(id);
    if (e == null || _locked(e) || e.linearPoints == null || e.isClosedShape) return false;
    final pts = e.linearPoints!;
    // the end nearest to the click, and the direction it extends in
    final atEnd = pts.last.distanceTo(world) <= pts.first.distanceTo(world);
    final tip = atEnd ? pts.last : pts.first, before = atEnd ? pts[pts.length - 2] : pts[1];
    final edges = [for (final x in _boundaries(id, near: () => _alongRay(tip, tip - before))) ?CutEdge.of(x)];
    final copy = e.clone();
    if (!extendLinearEntity(copy, world, const [], edges: edges)) return false;
    final done = mutate(
      () {
        final idx = project.entities.indexOf(e);
        project.entities[idx] = copy;
        return true;
      },
      invalidateResults: affectsResults(e),
      label: 'hist.extend',
    );
    return done == true;
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
    final done = mutate(
      () {
        final idx = project.entities.indexOf(e);
        project.entities.removeAt(idx);
        project.entities.insertAll(idx, pieces);
        return true;
      },
      invalidateResults: affectsResults(e),
      label: 'hist.cut',
    );
    // refused (a design is running): the pieces are not in the project
    if (done != true) return false;
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
    mutate(
      () {
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
      },
      invalidateResults: affectsResults(e) || anyAffectsResults(joined),
      label: 'hist.grip',
    );
    // 1.6.0 AUT: a vertex dragged across another side of an area (AUT-05)
    warnSelfCrossingAreas(this, [e]);
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
    return mutate(
          () {
            e.insertVertex(index, p);
            return true;
          },
          invalidateResults: affectsResults(e),
          label: 'hist.vertexAdd',
        ) ??
        false;
  }

  void removeVertex(String id, int index) {
    final e = project.byId(id);
    if (e is! PolyEntity || _locked(e)) return;
    if (e.points.length <= 2) return;
    mutate(() => e.removeVertex(index), invalidateResults: affectsResults(e), label: 'hist.vertexRemove');
    // 1.6.0 AUT (AUT-05)
    warnSelfCrossingAreas(this, [e]);
  }

  /// Applies [fn] to every selected entity of type [T] (batch properties).
  int mutateSelected<T extends Entity>(void Function(T e) fn, {bool invalidateResults = true}) {
    final targets = editableSelection.whereType<T>().toList();
    if (targets.isEmpty) return 0;
    mutate(
      () {
        for (final e in targets) {
          fn(e);
        }
      },
      invalidateResults: invalidateResults,
      label: 'hist.props',
    );
    return targets.length;
  }

  void duplicateSelected() {
    track('duplicate');
    if (selection.isEmpty) return;
    final copies = <Entity>[];
    mutate(
      () {
        for (final e in editableSelection) {
          copies.add(e.clone(newId: project.newId()).translated(const Pt(2, -2)));
        }
        project.entities.addAll(copies);
      },
      invalidateResults: anyAffectsResults(editableSelection),
      label: 'hist.copy|${editableSelection.length}',
    );
    // refused (a design is running) or nothing editable: keep the selection
    if (copies.isEmpty) return;
    selection
      ..clear()
      ..addAll(copies.map((e) => e.id));
    notifyListeners();
  }

  /// Turns the selected laterals and tapes into plain zone pipes (blank
  /// tubing without emitters, e.g. the head of a line before the crop
  /// starts), keeping their geometry, name and depth; a tape becomes the
  /// smallest enabled lateral pipe whose bore holds it. Returns how many
  /// were converted.
  int convertSelectedToPipe() {
    track('toPipe');
    final targets = editableSelection.where((e) => e is SpraylineEntity || e is TapeEntity).toList();
    if (targets.isEmpty) return 0;
    final cat = project.catalog;
    final made = <String>[];
    mutate(() {
      for (final e in targets) {
        String? spec;
        if (e is SpraylineEntity) spec = e.pipeSpecId;
        if (e is TapeEntity) {
          final bore = cat.tape(e.tapeSpecId)?.innerDiameterMm ?? 0;
          final pipes = cat.pipesFor(PipeUsage.lateral);
          spec = (pipes.where((p) => p.innerDiameterMm >= bore - 0.5).firstOrNull ?? pipes.lastOrNull)?.id;
        }
        final pipe = PipeEntity(
          id: project.newId(),
          layer: Layers.zonePipes,
          name: e.name,
          points: List.of((e as PolyEntity).points),
          scope: HydraulicScope.zone,
          pipeSpecId: spec,
          computerSized: spec == null || (e is SpraylineEntity && e.computerSized),
          depth: e is SpraylineEntity ? e.depth : (e as TapeEntity).depth,
        );
        final i = project.entities.indexOf(e);
        project.entities[i] = pipe;
        made.add(pipe.id);
      }
    }, label: 'hist.toPipe|${targets.length}');
    selection
      ..clear()
      ..addAll(made);
    notifyListeners();
    return made.length;
  }

  /// Puts a device of catalogue item [valveSpecId] (pressure regulator,
  /// on/off valve…) on every selected lateral and tape, [distanceM] from
  /// its inlet (the end that touches another pipe; the first vertex when
  /// neither or both do); the network splits the line there. Returns how
  /// many were placed.
  int insertDeviceOnSelectedLaterals(String valveSpecId, {double distanceM = 0.3}) {
    track('deviceOnLaterals');
    final lines = editableSelection.where((e) => e is SpraylineEntity || e is TapeEntity).cast<PolyEntity>().toList();
    if (lines.isEmpty || project.catalog.valve(valveSpecId) == null) return 0;
    final others = project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.zone).toList();
    final tol = math.max(project.params.connectTolerance, 1e-3);
    bool touches(Pt q) => others.any((p) => p.distanceTo(q) <= tol);
    final added = <Entity>[];
    mutate(() {
      for (final e in lines) {
        final pts = e.points;
        if (pts.length < 2) continue;
        final total = polylineLength(pts);
        final fromEnd = touches(pts.last) && !touches(pts.first);
        final d = math.min(math.max(distanceM, 0.05), total / 2);
        final at = pointAlongPolyline(pts, fromEnd ? total - d : d);
        added.add(MiscHydraulicEntity(id: project.newId(), position: at, valveSpecId: valveSpecId, scope: HydraulicScope.zone));
      }
      project.entities.addAll(added);
    }, label: 'hist.deviceOnLaterals|${lines.length}');
    return added.length;
  }

  /// Saves the designed project as alternative [name] (with its results) for
  /// comparison; null when there are no results to compare.
  Scenario? saveScenario(String name) {
    final r = results;
    if (r == null) return null;
    // without the pictures of images and comments (they stay in the project)
    final snap = scenarioSnapshot(project, r);
    final sc = Scenario(
      id: 'scn${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? t('scn.default', {'n': '${project.scenarios.length + 1}'}) : name.trim(),
      created: DateTime.now(),
      metrics: scenarioMetrics(project, r),
      snapshot: snap,
    );
    mutate(() => project.scenarios.add(sc), invalidateResults: false, label: 'hist.scenarioSave');
    return sc;
  }

  /// Brings alternative [id] back (one undo step): its drawing, settings and
  /// results; the list of alternatives stays as it is.
  bool restoreScenario(String id) {
    final sc = project.scenarios.where((x) => x.id == id).firstOrNull;
    if (sc == null) return false;
    // the pictures of images and comments come back from the current project
    final restored = sc.restoredInto(project);
    if (restored == null) return false;
    final res = sc.snapshot['results'] is Map ? DesignResults.fromJson((sc.snapshot['results'] as Map).cast<String, dynamic>()) : null;
    final done = mutate(() {
      project
        ..meta = restored.meta
        ..params = restored.params
        ..catalog = restored.catalog
        ..layers = restored.layers
        ..proposal = restored.proposal
        ..currentLayer = restored.currentLayer;
      project.entities
        ..clear()
        ..addAll(restored.entities);
      project.systemFlows
        ..clear()
        ..addAll(restored.systemFlows);
      project.ensureNextId(restored.nextIdValue);
      return true;
    }, label: 'hist.scenarioRestore');
    if (done != true) return false;
    selection.clear();
    results = res;
    notifyListeners();
    return true;
  }

  void deleteScenario(String id) => mutate(() => project.scenarios.removeWhere((x) => x.id == id), invalidateResults: false, label: 'hist.scenarioDelete');

  /// Loads climate requests (tests swap it for canned answers).
  static Future<String> Function(String url) climateUrlLoader = (url) => httpRequest('GET', url);

  /// Where the site is (latitude, longitude): the centre of the drawing on
  /// the georeference; null without a georeference.
  (double, double)? get siteLatLon {
    final g = project.meta.georef;
    if (g == null) return null;
    final b = project.bounds;
    final cx = b.isEmpty ? 0.0 : (b.minX + b.maxX) / 2, cy = b.isEmpty ? 0.0 : (b.minY + b.maxY) / 2;
    return g.toLatLon(cx, cy);
  }

  /// Downloads [years] whole years of daily climate at the site from
  /// [source] and stores their monthly normals in the project (one undo
  /// step). Throws [ClimateException] (codes `climate_*`); `climate_no_site`
  /// without a georeference.
  Future<SiteClimate> downloadClimate(ClimateSource source, {int years = 10, void Function(int done, int total)? onProgress, void Function(Duration wait)? onWait, bool Function()? cancelled}) async {
    final ll = siteLatLon;
    if (ll == null) throw const ClimateException('climate_no_site', '');
    final now = DateTime.now().toUtc();
    final series = await climateDownload(
      source,
      latitudeDeg: ll.$1,
      longitudeDeg: ll.$2,
      firstYear: now.year - years,
      lastYear: now.year - 1,
      fetch: climateUrlLoader,
      onProgress: onProgress,
      onWait: onWait,
      cancelled: cancelled,
    );
    final normals = climateMonthlyNormals(series);
    final req = climateNormalsForRequirement(normals);
    if (req == null) throw const ClimateException('climate_no_data', '');
    final rs = [for (final n in normals) n.solarKWhM2Day];
    String two(int v) => v.toString().padLeft(2, '0');
    final sc = SiteClimate(
      etoMmDay: req.etoMmDay,
      rainMm: req.rainMm,
      dependableRainMm: req.dependableRainMm,
      solarKWhM2Day: rs.every((x) => x != null) ? [for (final x in rs) x!] : null,
      // 1.6.0 AGR: RHmin and u2 for the Kc adjustment of FAO-56 eqs. 62 and 65
      rhMinPct: SiteClimate.monthlyRhMin([for (final n in normals) (n.rhMinPct, n.tMaxC, n.tDewC, n.tMinC)]),
      windSpeed2mMs: SiteClimate.monthlyOrNull([for (final n in normals) n.windSpeed2mMs]),
      source: source.name,
      firstYear: now.year - years,
      lastYear: now.year - 1,
      latitudeDeg: ll.$1,
      longitudeDeg: ll.$2,
      retrieved: '${now.year}-${two(now.month)}-${two(now.day)}',
      attribution: source.attribution,
    );
    mutate(() => project.climate = sc, invalidateResults: false, label: 'hist.climate');
    return sc;
  }

  /// Sets the climate typed or edited by hand (null removes it).
  void setClimate(SiteClimate? sc) => mutate(() => project.climate = sc, invalidateResults: false, label: 'hist.climate');

  void selectAll() {
    track('selectAll');
    final hidden = _hiddenLayers, locked = _lockedLayers;
    selection
      ..clear()
      ..addAll([
        for (final e in project.entities)
          if (!hidden.contains(e.layer) && !locked.contains(e.layer)) e.id,
      ]);
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

  List<Entity> visibleEntities() {
    final hidden = _hiddenLayers;
    return hidden.isEmpty ? List.of(project.entities) : project.entities.where((e) => !hidden.contains(e.layer)).toList();
  }

  /// Entities on visible layers whose bounds intersect [b], in drawing
  /// order (spatial index query).
  List<Entity> entitiesIn(Bounds b) {
    final idx = index;
    final visible = {for (final l in project.layers) l.name: l.visible};
    return [
      for (final i in idx.query(b))
        if (visible[idx.entities[i].layer] ?? true) idx.entities[i],
    ];
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
    // marking for the AI draws nothing: Enter keeps repeating the drawing tool
    if (id != ToolId.select && id != ToolId.pan && !id.isAiMark) lastTool = id;
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
    // the lookup by id of the spatial index (the project's own scans every entity)
    if (locked) selection.removeWhere((id) => entityById(id)?.layer == name);
    notifyListeners();
  }

  void setLayerColor(String name, int argb) {
    mutate(() => project.layerNamed(name).color = argb, invalidateResults: false, label: 'hist.layerColor');
  }

  void setCurrentLayer(String name) {
    project.layerNamed(name);
    project.currentLayer = name;
    notifyListeners();
  }

  bool addLayer(String name, {int color = 0xFFB0BEC5}) {
    final n = name.trim();
    if (n.isEmpty || project.findLayer(n) != null) return false;
    return mutate(
          () {
            project.layers.add(Layer(name: n, color: color));
            return true;
          },
          invalidateResults: false,
          label: 'hist.layerAdd',
        ) ??
        false;
  }

  bool renameLayer(String from, String to) {
    var ok = false;
    mutate(() => ok = project.renameLayer(from, to), invalidateResults: false, label: 'hist.layerRename');
    return ok;
  }

  void removeLayer(String name) {
    if (Layers.all.contains(name)) return;
    mutate(() => project.removeLayer(name), invalidateResults: false, label: 'hist.layerRemove');
  }

  /// Layer for a new drawing entity: the current layer, unless it is locked.
  String get drawingLayer => project.isLocked(project.currentLayer) ? Layers.drawing : project.currentLayer;

  // ------------------------------------------------------------ automatic analysis

  /// Analyses the design again a moment after every edit (analysis only:
  /// nothing is sized and the drawing does not change, so editing goes on
  /// meanwhile), so pressures, flows and messages follow the drawing. Kept
  /// in this browser.
  bool get autoAnalyze => _autoAnalyze;
  bool _autoAnalyze = getPref('design.auto') == '1';
  set autoAnalyze(bool v) {
    _autoAnalyze = v;
    v ? setPref('design.auto', '1') : removePref('design.auto');
    if (v) {
      _scheduleAutoAnalysis();
    } else {
      _autoTimer?.cancel();
    }
    notifyListeners();
  }

  /// Quiet time after the last edit before the analysis starts.
  static Duration autoAnalysisDelay = const Duration(milliseconds: 1200);
  Timer? _autoTimer;

  /// Whether an automatic analysis is running (editing stays allowed).
  bool autoRunning = false;
  Future<void>? _autoJob;

  /// Closes the tab's work: the GPS (and the screen kept on for a walk),
  /// the timers of the copy and of the automatic analysis, the design job
  /// and its worker, the decoded pictures and the window lock of the
  /// project. A copy already being written still completes.
  @override
  void dispose() {
    if (_disposed) return;
    _autoTimer?.cancel();
    _autosaveTimer?.cancel();
    _gpsStop?.call();
    _gpsStop = null;
    _releaseWakeLock();
    if (busy || autoRunning) designRunner.cancel();
    designRunner.dispose();
    _releaseUid();
    _disposeImages();
    _disposed = true;
    super.dispose();
  }

  void _scheduleAutoAnalysis() {
    if (!_autoAnalyze) return;
    _autoTimer?.cancel();
    _autoTimer = Timer(autoAnalysisDelay, () => _autoJob = _autoAnalysis());
  }

  Future<void> _autoAnalysis() async {
    if (!_autoAnalyze || !_canDesign) return;
    if (busy || autoRunning) {
      _scheduleAutoAnalysis();
      return;
    }
    autoRunning = true;
    _notifyQuiet();
    final gen = _editSeq;
    try {
      final response = await designRunner.run(DesignRequest.of(project, lang: lang, sizeZones: false, sizeMain: false), yieldControl: _yieldFrame);
      if (gen == _editSeq && _autoAnalyze) {
        results = response.results;
        unconnected = response.results.unconnected;
        final adv = response.advice;
        if (adv != null) {
          _advice = adv;
          _adviceSig = _adviceSignature();
        }
      } else if (gen != _editSeq) {
        // edited while it ran: the next quiet moment analyses again
        _scheduleAutoAnalysis();
      }
    } on DesignCancelled {
      // stopped (a tab closed, Cancel): the next quiet moment analyses again
    } catch (e, st) {
      debugPrint('$e\n$st');
    } finally {
      autoRunning = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ design
  Future<void> runDesign({bool sizeZones = true, bool sizeMain = true}) async {
    if (!_canDesign) {
      notify(t('msg.noValves'));
      return;
    }
    if (busy || _assistantRounds) return;
    final redo = List.of(_redo);
    _snapshot('hist.design');
    final st = _undo.last;
    final r = await _design(sizeZones: sizeZones, sizeMain: sizeMain);
    if (r != null) {
      _designNotice(r);
    } else if (_undo.isNotEmpty && identical(_undo.last, st)) {
      // a design that failed, was cancelled or went stale changed nothing:
      // no undo step, and the redo steps stay
      _dropSnapshot(st, redo);
    }
  }

  /// Set by [cancelDesign] until the next design starts.
  bool _cancelRequested = false;

  /// Stops the running design (the Cancel button of the progress card):
  /// the worker is stopped, nothing of the design is applied and editing
  /// is allowed again at once. "Fix automatically" and "optimise" stop too
  /// and put the project back as it was before them.
  void cancelDesign() {
    if (!busy && !autoRunning && !_assistantRounds) return;
    _cancelRequested = true;
    track('designCancel');
    designRunner.cancel();
  }

  bool get _canDesign => project.entities.any((e) => e is ControlValveEntity || e is WaterSupplyEntity);

  /// Runs the design (in the worker when there is one) and applies it to the
  /// project. No undo snapshot and no message; null when the design cannot
  /// run, fails or goes stale.
  Future<DesignResults?> _design({bool sizeZones = true, bool sizeMain = true}) async {
    if (!_canDesign || busy) return null;
    _autoTimer?.cancel();
    // one job at a time in the worker: let an automatic analysis finish
    final pending = _autoJob;
    if (autoRunning && pending != null) await pending;
    busy = true;
    progress = null;
    if (!_assistantRounds) _cancelRequested = false;
    track('design');
    notifyListeners();
    await _yieldFrame();
    try {
      if (_cancelRequested) throw const DesignCancelled();
      final gen = _editSeq;
      final request = DesignRequest.of(project, lang: lang, sizeZones: sizeZones, sizeMain: sizeMain);
      final response = await designRunner.run(
        request,
        yieldControl: _yieldFrame,
        onMode: (m) {
          designMode = m;
          _notifyQuiet();
        },
        onProgress: (p) {
          progress = p;
          _notifyQuiet();
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
      // the messages came built with the design (see DesignResponse.advice)
      final adv = response.advice;
      if (adv != null) {
        _advice = adv;
        _adviceSig = _adviceSignature();
      }
      dirty = true;
      showReports = true;
      feedEnvelope.clear();
      // the copy in the browser once the results are on screen
      if (autosaveEnabled) unawaited(_yieldFrame().then((_) => _autosaveInBackground()));
      return r;
    } on DesignCancelled {
      _cancelRequested = true;
      notify(t('msg.designCancelled'));
      return null;
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
    final sig = _adviceSignature();
    if (_advice == null || sig != _adviceSig) {
      _advice = buildAdvice(project, results: results);
      _adviceSig = sig;
    }
    return _advice!;
  }

  String _adviceSignature() =>
      '$_editSeq|${identityHashCode(project)}|${identityHashCode(results)}|${jsonEncode(project.params.toJson())}|${jsonEncode([for (final f in project.systemFlows) f.toJson()])}';

  /// Applies one correction (one undo step). With results on screen the
  /// design runs again, so the message list shows what is left.
  Future<FixResult?> applyAdviceFix(Advice a, FixKind kind) async {
    if (!editAllowed()) return null;
    track('fix');
    final before = results;
    final redo = List.of(_redo);
    _snapshot('hist.fix|${kind.name}');
    final st = _undo.last;
    final FixResult res;
    try {
      res = applyFix(project, a, kind, results: before, label: t.call, lang: lang);
    } catch (_) {
      _dropSnapshot(st, redo, restore: true);
      notifyListeners();
      rethrow;
    }
    if (!res.ok) {
      // a correction that fails changes nothing: no undo step, and the redo steps stay
      _dropSnapshot(st, redo);
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
  /// nothing more can be fixed. One undo step. [skip] leaves corrections
  /// out (the AI assistant keeps a booster pump on a mains connection for
  /// the user to decide).
  Future<AutoFixReport?> autoFixAll({FixFilter? skip}) async {
    if (!editAllowed()) return null;
    track('autofix');
    final redo = List.of(_redo);
    _snapshot('hist.autofix');
    final st = _undo.last;
    final base = results;
    assistantProgress = t('adv.working', {'n': '1'});
    _assistantRounds = true;
    _cancelRequested = false;
    notifyListeners();
    try {
      final report = await runAutoFix(
        project,
        () async {
          _editSeq++;
          final r = await _design();
          if (_cancelRequested) throw const DesignCancelled();
          return r;
        },
        label: t.call,
        lang: lang,
        skip: skip,
        onRound: (n) {
          assistantProgress = t('adv.working', {'n': '$n'});
          notifyListeners();
        },
      );
      _editSeq++;
      dirty = true;
      showReports = true;
      reportTab = messagesReportTab;
      notify(report.applied.isEmpty ? t('adv.summaryNone') : t('adv.summaryApplied', {'n': '${report.applied.length}'}).replaceAll(RegExp(r'\s*[:：]\s*$'), ''));
      return report;
    } on DesignCancelled {
      _backTo(st, redo, base);
      notify(t('msg.designCancelled'));
      return null;
    } finally {
      _assistantRounds = false;
      assistantProgress = '';
      notifyListeners();
    }
  }

  /// Puts the project back to its own snapshot [st] (taken out of the undo
  /// steps by identity, wherever it is) with the results [base] it had:
  /// "optimise" that gained nothing, a cancelled "fix automatically".
  void _backTo(_UndoState st, List<_UndoState> redo, DesignResults? base) {
    _dropSnapshot(st, redo, restore: true);
    results = base;
    unconnected = base?.unconnected ?? unconnected;
    _advice = st.advice;
    if (_advice != null) _adviceSig = _adviceSignature();
  }

  /// Optimises the design (see [runOptimize]); keeps the result when it is
  /// better, otherwise restores the project as it was. One undo step.
  Future<OptimizeReport?> optimizeDesign(OptimizeOptions options) async {
    if (!editAllowed()) return null;
    track('optimize');
    final base = results;
    final redo = List.of(_redo);
    _snapshot('hist.optimize');
    // its own snapshot, put back by identity (nothing else edits meanwhile)
    final st = _undo.last;
    assistantProgress = t('opt.working');
    _assistantRounds = true;
    _cancelRequested = false;
    notifyListeners();
    try {
      final report = await runOptimize(
        project,
        () async {
          _editSeq++;
          final r = await _design();
          if (_cancelRequested) throw const DesignCancelled();
          return r;
        },
        options: options,
        baseline: base,
        label: t.call,
      );
      // 1.6.0 AUT: the changes the user kept in the review stay as they are
      final kept = report.improved || options.replay != null;
      if (!kept) {
        // nothing gained: back to the project as it was
        _backTo(st, redo, base);
      } else {
        dirty = true;
        _editSeq++;
      }
      showReports = true;
      notify(kept ? t('opt.kept') : t('opt.reverted'));
      return report;
    } on DesignCancelled {
      _backTo(st, redo, base);
      notify(t('msg.designCancelled'));
      return null;
    } finally {
      _assistantRounds = false;
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
    // 1.6.0 AUT: a guided block that leaves part of the polygon dry says so
    if (r.messages.isNotEmpty) notify(r.messages.map(t.warning).join(' · '));
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
      spec = LateralSpec(
        length: e.length,
        diameter: pipe.innerDiameter,
        spacing: e.spacing,
        emitter: nz.curve,
        firstOffset: e.firstOutletDistance,
        method: p.frictionMethod,
        hazenC: p.adjustedC(pipe.hazenC),
        roughness: pipe.roughness,
        kinematicViscosity: p.kinematicViscosity,
        scobeyKs: pipe.scobeyKs,
        manningN: pipe.manningN,
      );
      nominal = e.headM;
      final (l, h) = nz.curve.headWindow(nominal, below: nz.flowTolBelow, above: nz.flowTolAbove);
      lo = math.max(l, nz.minHeadM);
      hi = math.min(h, nz.maxHeadM);
    } else if (e is TapeEntity) {
      final tp = cat.tape(e.tapeSpecId);
      if (tp == null) return null;
      spec = LateralSpec(
        length: e.length,
        diameter: tp.innerDiameter,
        spacing: tp.emitterSpacingM,
        emitter: tp.emitter,
        barbK: tp.barbK,
        method: p.frictionMethod,
        hazenC: p.adjustedC(tp.hazenC),
        roughness: tp.roughnessMm / 1000,
        kinematicViscosity: p.kinematicViscosity,
      );
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
  bool get terrainIsEmpty => !project.entities.any((e) => (e is ContourEntity && !e.derived) || e is SpotHeightEntity || (e is BreaklineEntity && e.elevations.any((z) => z.isFinite)));

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
    mutate(
      () {
        if (replacePrevious) project.entities.removeWhere((e) => e is ContourEntity && e.derived);
        for (final (z, pts) in lines) {
          if (pts.length < 2 || polylineLength(pts) < interval) continue;
          final e = ContourEntity(id: project.newId(), points: pts, elevation: z, derived: true, name: 'DTM');
          project.entities.add(e);
          created.add(e);
        }
      },
      invalidateResults: false,
      label: 'hist.contours',
    );
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
  Future<DemImportResult> importOnlineDem(
    DemSource source, {
    double spacing = 25,
    bool useView = false,
    bool replacePrevious = true,
    bool replaceExisting = false,
    int maxPoints = 5000,
    void Function(int done, int total)? onProgress,
    void Function(Duration wait)? onWait,
    bool Function()? cancelled,
  }) async {
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
    final note = _tinNote();
    if (note.isNotEmpty) scheduleMicrotask(() => notify(note.trim()));
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
    if (!setGeoreference(ref)) return;
    if (project.bounds.isEmpty && viewSizeM > 0 && !camera.size.isEmpty) {
      camera.fit(Bounds(-viewSizeM / 2, -viewSizeM / 2, viewSizeM / 2, viewSizeM / 2), padding: 24);
    }
    track('georef');
    notify(t('msg.georefAt', {'lat': lat.toStringAsFixed(5), 'lon': lon.toStringAsFixed(5), 'crs': ref.crsName}));
  }

  /// Sets the georeference of the project, or removes it ([ref] null), as
  /// one undo step (the base map, the online DEM and the geographic exports
  /// follow it; the drawing coordinates and the results stay). False when
  /// refused (a design running).
  bool setGeoreference(GeoReference? ref) =>
      mutate(
        () {
          project.meta.georef = ref;
          return true;
        },
        invalidateResults: false,
        label: ref == null ? 'hist.georefRemove' : 'hist.georef',
      ) ==
      true;

  /// An import that georeferences the project sets the georeference before
  /// the import's undo step is taken (the readers place the drawing with
  /// it): the first step the import took gets the georeference the project
  /// had before, [before], so undoing the import takes it away too; an
  /// import that failed after setting it puts it back at once. [mark] is
  /// the last undo step before the import.
  void _georefWithImport(GeoReference? before, _UndoState? mark) {
    if (identical(project.meta.georef, before)) return;
    final i = mark == null ? 0 : _undo.indexOf(mark) + 1;
    if (mark != null && i == 0) return; // the mark was trimmed away: nothing to fix safely
    if (i >= _undo.length) {
      project.meta.georef = before;
      return;
    }
    final meta = _undo[i].rest['meta'];
    if (meta is! Map<String, dynamic>) return;
    if (before == null) {
      meta.remove('georef');
    } else {
      meta['georef'] = before.toJson();
    }
  }

  // ------------------------------------------------------------ device GPS

  /// Watches the device position (tests swap it for canned fixes).
  static void Function() Function(void Function(GpsFix fix), void Function(String code)) gpsWatcher = watchGps;

  /// Last position of the device while the GPS is on.
  GpsFix? gpsFix;

  /// Points and lines the user marked on the drawing for the AI assistant
  /// (of this tab, not saved with the project).
  final AiMarks aiMarks = AiMarks();
  void Function()? _gpsStop;
  bool get gpsActive => _gpsStop != null;

  /// Points walked so far (drawing coordinates) while a walk is recorded.
  List<Pt>? gpsTrack;

  /// Fixes less precise than this (m) are not recorded in a walk, and a
  /// walked point is kept every [gpsStepM] metres.
  double gpsMaxAccuracyM = 10;
  double gpsStepM = 2;

  /// The device's position in drawing coordinates (needs a georeference;
  /// the first fix of a project without one creates it there).
  Pt? get gpsPoint {
    final f = gpsFix, g = project.meta.georef;
    if (f == null || g == null) return null;
    final (x, y) = g.fromLatLon(f.lat, f.lon);
    return Pt(x, y);
  }

  void startGps() {
    if (gpsActive) return;
    _gpsStop = gpsWatcher(_onGpsFix, (code) {
      notify(t('gps.err.$code'));
      stopGps();
    });
    track('gps');
    notifyListeners();
  }

  /// Stops the GPS. A walk being recorded stays kept in this browser and
  /// goes on from where it was at the next "start walk".
  void stopGps() {
    _gpsStop?.call();
    _gpsStop = null;
    gpsFix = null;
    _saveWalk();
    gpsTrack = null;
    _releaseWakeLock();
    notifyListeners();
  }

  // ---- the walk kept in the browser
  /// Where the points of the walk being recorded are kept, every few
  /// points, so a page the phone discarded in the background, a stopped
  /// GPS or a crash does not lose the walk: `gps.walk.<uid>`.
  String get _walkKey => 'gps.walk.${project.meta.uid}';

  DateTime _walkSaved = DateTime.fromMillisecondsSinceEpoch(0);

  void _saveWalk({bool force = true}) {
    final w = gpsTrack;
    if (w == null || w.isEmpty) return;
    final now = DateTime.now();
    if (!force && now.difference(_walkSaved) < const Duration(seconds: 5)) return;
    _walkSaved = now;
    setPref(
      _walkKey,
      jsonEncode({
        'at': now.toIso8601String(),
        'p': [
          for (final q in w) [q.x, q.y],
        ],
      }),
    );
  }

  /// The walk kept for this project (a week at most), if any.
  List<Pt>? _keptWalk() {
    final raw = getPref(_walkKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(j['at'] as String? ?? '');
      if (at == null || DateTime.now().difference(at) > const Duration(days: 7)) return null;
      final pts = [for (final q in (j['p'] as List).cast<List>()) Pt((q[0] as num).toDouble(), (q[1] as num).toDouble())];
      return pts.isEmpty ? null : pts;
    } catch (_) {
      return null;
    }
  }

  /// Whether a walk of this project is kept in this browser.
  bool get hasKeptWalk => gpsTrack == null && _keptWalk() != null;

  /// Drops the walk being recorded (and the one kept): the next walk
  /// starts afresh.
  void discardGpsTrack() {
    gpsTrack = null;
    removePref(_walkKey);
    _releaseWakeLock();
    notify(t('gps.walkDiscarded'));
  }

  bool _wakeLockHeld = false;

  void _releaseWakeLock() {
    if (!_wakeLockHeld) return;
    _wakeLockHeld = false;
    releaseScreenWakeLock();
  }

  void _onGpsFix(GpsFix f) {
    final first = gpsFix == null;
    gpsFix = f;
    // (not while a design runs: the next fix sets it)
    if (project.meta.georef == null && !busy && !_assistantRounds) setGeoreferenceAt(f.lat, f.lon);
    final p = gpsPoint;
    if (p == null) return;
    // the first fix brings the view to the device
    if (first && !camera.visible.contains(p)) camera.center = p;
    final walk = gpsTrack;
    if (walk != null && f.accuracyM <= gpsMaxAccuracyM && (walk.isEmpty || walk.last.distanceTo(p) >= gpsStepM)) {
      walk.add(p);
      _saveWalk(force: false);
    }
    notifyListeners();
  }

  /// Starts recording a walk (the outline of a field, a lawn, a pipe route),
  /// or goes on with the walk of this project kept in the browser (the GPS
  /// was stopped, the page reloaded). The screen is kept on while it lasts:
  /// with the screen off the browser gives no positions.
  void startGpsTrack() {
    if (!gpsActive) startGps();
    final kept = _keptWalk();
    gpsTrack = kept ?? [if (gpsPoint case final p? when (gpsFix?.accuracyM ?? 1e9) <= gpsMaxAccuracyM) p];
    _wakeLockHeld = true;
    final granted = keepScreenOn();
    if (kept != null) {
      notify(t('gps.walkResumed', {'n': '${kept.length}'}));
    } else {
      unawaited(
        granted.then((on) {
          if (!on && !_disposed && gpsTrack != null) notify(t('gps.keepScreenOn'));
        }),
      );
      notifyListeners();
    }
  }

  /// Ends the walk as one undo step: an irrigated area ([asArea]), a closed
  /// outline or an open polyline; null (and nothing added) with too few
  /// points.
  Entity? finishGpsTrack({bool closed = true, bool asArea = false}) {
    // refused (a design is running): the walk goes on, nothing is lost
    if (!editAllowed()) return null;
    final pts = gpsTrack;
    if (pts == null || pts.length < (closed || asArea ? 3 : 2)) {
      notify(t('gps.trackShort'));
      notifyListeners();
      return null;
    }
    final name = t('gps.trackName', {'t': _hhmm(DateTime.now())});
    final Entity e = asArea ? AreaEntity(id: project.newId(), points: List.of(pts), name: name) : PolylineEntity(id: project.newId(), points: List.of(pts), closed: closed, name: name);
    final added = mutate(() {
      project.entities.add(e);
      return true;
    }, label: 'hist.gpsTrack');
    if (added != true) return null;
    gpsTrack = null;
    removePref(_walkKey);
    _releaseWakeLock();
    notify(
      t('gps.trackDone', {
        'n': '${pts.length}',
        'l': fmt(polylineLength([...pts, if (closed || asArea) pts.first]), 0),
      }),
    );
    return e;
  }

  /// A marker at the device's position (the satellite height is not an
  /// elevation of the terrain model: it is left out).
  Entity? markGpsPoint() {
    final p = gpsPoint;
    if (p == null) return null;
    final e = CircleEntity(id: project.newId(), center: p, radius: math.max(0.3, math.min(gpsFix!.accuracyM, 2)), name: t('gps.pointName', {'t': _hhmm(DateTime.now())}));
    mutate(() => project.entities.add(e), label: 'hist.gpsPoint');
    return e;
  }

  /// Distance (m) and bearing (degrees clockwise from grid north) from the
  /// device to [target]: staking out what was designed.
  (double, double)? gpsTo(Pt target) {
    final p = gpsPoint;
    if (p == null) return null;
    final d = target - p;
    var bearing = 90 - radToDeg(math.atan2(d.y, d.x));
    bearing %= 360;
    if (bearing < 0) bearing += 360;
    return (d.length, bearing);
  }

  static String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
    unconnected = {
      for (final i in r.issues)
        if (i.code == 'unconnected') ...i.entityIds,
    };
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

  String get _densogramKey =>
      '$_editSeq|${identityHashCode(project)}|${identityHashCode(results)}|${densogramOptions.cellSize}|${densogramOptions.profile.name}|${densogramOptions.useResults}|${densogramOptions.useMeasured}|${densogramOptions.windSpeed}|${densogramOptions.windTowardsDeg}|${densogramOptions.windDrift}|${densogramOptions.valveIds?.join(',')}';

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

  // ------------------------------------------------------------ slope map
  SlopeMap? _slopeMap;
  String _slopeSig = '';
  final Map<bool, ui.Image> _slopeImages = {};
  final Set<bool> _slopeDecoding = {};
  int _slopeImageGen = 0;

  /// Slope and aspect of the terrain over the extent of its samples (View →
  /// Overlay → slope / aspect map), recomputed when the drawing changes.
  SlopeMap get slopeMap {
    final sig = '$_editSeq|${identityHashCode(project)}|${project.params.terrainMethod.name}|${project.params.terrainDensify}';
    final cached = _slopeMap;
    if (cached != null && sig == _slopeSig) return cached;
    final terrain = project.buildTerrain();
    var m = SlopeMap.empty;
    if (!terrain.isEmpty) {
      var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
      for (final s in terrain.samples) {
        minX = math.min(minX, s.p.x);
        minY = math.min(minY, s.p.y);
        maxX = math.max(maxX, s.p.x);
        maxY = math.max(maxY, s.p.y);
      }
      m = SlopeMap.compute(terrain, Bounds(minX, minY, maxX, maxY));
    }
    _slopeMap = m;
    _slopeSig = sig;
    _slopeImageGen++;
    for (final img in _slopeImages.values) {
      img.dispose();
    }
    _slopeImages.clear();
    _slopeDecoding.clear();
    return m;
  }

  /// Picture of [slopeMap] coloured by slope class or by [aspect] (one pixel
  /// per cell), decoded on first request; null while decoding.
  ui.Image? slopeImage({required bool aspect}) {
    final m = slopeMap;
    final img = _slopeImages[aspect];
    if (img != null || m.isEmpty || _slopeDecoding.contains(aspect)) return img;
    _slopeDecoding.add(aspect);
    final gen = _slopeImageGen;
    try {
      ui.decodeImageFromPixels(slopeMapPixels(m, aspect: aspect), m.nx, m.ny, ui.PixelFormat.rgba8888, (decoded) {
        if (gen != _slopeImageGen) {
          decoded.dispose();
          return;
        }
        _slopeImages[aspect] = decoded;
        _slopeDecoding.remove(aspect);
        notifyListeners();
      });
    } catch (_) {
      // no engine (pure Dart tests): the painter draws nothing
    }
    return null;
  }

  // ------------------------------------------------------------ images
  /// Decoded image for an image entity (starts decoding on first request),
  /// scaled down to [imageMaxSide] pixels on its longest side.
  ui.Image? imageFor(ImageEntity e) {
    final data = e.data;
    final cached = images[e.id];
    if (cached != null) {
      final known = _imageBytes[e.id];
      if (known == null || data == null || identical(known, data)) {
        // (a picture put in the cache from outside is taken with these bytes)
        if (known == null && data != null) _imageBytes[e.id] = data;
        return cached;
      }
      // another picture under this id (an undo, a paste): decoded again
      images.remove(e.id)?.dispose();
      _imageBytes.remove(e.id);
    }
    if (data == null || _decoding.contains(e.id)) return null;
    _decoding.add(e.id);
    final id = e.id;
    _decodeCapped(data)
        .then((img) {
          _decoding.remove(id);
          if (_disposed) {
            img.dispose();
            return;
          }
          images.remove(id)?.dispose();
          images[id] = img;
          _imageBytes[id] = data;
          notifyListeners();
        })
        .catchError((Object err) {
          _decoding.remove(id);
        });
    return null;
  }

  /// [data] decoded at most [imageMaxSide] pixels on its longest side.
  static Future<ui.Image> _decodeCapped(Uint8List data) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(data);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final w = desc.width, h = desc.height;
    final scale = math.min(1.0, imageMaxSide / math.max(1, math.max(w, h)));
    final codec = await desc.instantiateCodec(targetWidth: scale < 1 ? math.max(1, (w * scale).round()) : null, targetHeight: scale < 1 ? math.max(1, (h * scale).round()) : null);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
      desc.dispose();
      buffer.dispose();
    }
  }

  /// Lets go of the decoded pictures of entities no longer in the project
  /// (deleted, undone) or whose bytes changed.
  void _pruneImages() {
    if (images.isEmpty) return;
    final live = <String, Uint8List?>{
      for (final e in project.entities)
        if (e is ImageEntity) e.id: e.data,
    };
    for (final id in images.keys.toList()) {
      final known = _imageBytes[id];
      if (!live.containsKey(id) || (known != null && !identical(live[id], known))) {
        images.remove(id)?.dispose();
        _imageBytes.remove(id);
      }
    }
  }

  /// Lets go of every decoded picture (another project opened, the tab closed).
  void _disposeImages() {
    for (final img in images.values) {
      img.dispose();
    }
    images.clear();
    _imageBytes.clear();
  }

  /// Places an imported raster (georeferenced when possible) as an image entity.
  ImageEntity importImage(GeoImage g) {
    ImageEntity e;
    GeoReference? georef;
    if (g.georeferenced) {
      final (bl, w, h, rot, ref) = placeGeoImage(g, project.meta.georef);
      georef = ref;
      e = ImageEntity(id: project.newId(), origin: bl, width: w, height: h, rotationDeg: rot, mime: g.mime, data: g.bytes, source: g.source, name: g.source);
    } else {
      // fit into the current view, centred
      final vis = camera.visible;
      final w = math.max(1.0, vis.width * 0.8);
      final h = w * g.heightPx / math.max(1, g.widthPx);
      e = ImageEntity(id: project.newId(), origin: Pt(vis.center.x - w / 2, vis.center.y - h / 2), width: w, height: h, mime: g.mime, data: g.bytes, source: g.source, name: g.source);
    }
    mutate(
      () {
        // inside the step: undoing the picture takes its georeference away too
        if (georef != null) project.meta.georef ??= georef;
        project.entities.insert(0, e);
      },
      invalidateResults: false,
      label: 'hist.import|image',
    );
    return e;
  }

  // ------------------------------------------------------------ files
  void newProject() {
    final code = defaultCurrency();
    project = Project(catalog: defaultCatalog(code));
    _applyNewProjectCurrency(code);
    // 1.6.0 MOD: mains frequency and units of the user's region (or choice)
    project.params
      ..mainsHz = defaultMainsHz()
      ..units = defaultUnits();
    // 1.6.0 UI: no name of its own (the tab says "New project" in the language of the moment)
    project.meta.name = '';
    results = null;
    selection.clear();
    unconnected = {};
    _forgetProjectViews();
    _disposeImages();
    _undo.clear();
    _redo.clear();
    _highestId = 0;
    _storedSeq = _editSeq;
    _storeProblem = null;
    fileHandle = null;
    dirty = false;
    _claimUid();
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
    // the marks for the AI point at places of the drawing that was here
    aiMarks.clear();
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

  /// Mains frequency of new projects (1.6.0 MOD): the user's choice
  /// (Parameters, saved in the browser), else that of the machine's region
  /// for the interface language ([mainsHzForLocale]).
  double defaultMainsHz() {
    final saved = double.tryParse(getPref('mainsHz') ?? '');
    if (saved == 50 || saved == 60) return saved!;
    return mainsHzForLocale(lang, systemLanguageTags());
  }

  /// Display units of new projects (1.6.0 MOD): the user's last choice in
  /// the units dialog, else metric. ([unitsForLocale] tells the units of
  /// the region; taking them without asking would change what every
  /// English-speaking user in the United States sees on first use, a choice
  /// left to the units dialog.)
  Units defaultUnits() {
    final saved = getPref('units');
    if (saved != null) {
      try {
        return Units.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {}
    }
    return Units.metric;
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
    mutate(
      () => project.setCurrency(code, rate: rate, symbol: symbol),
      label: 'hist.currency',
    );
    _autoCurrency = false;
  }

  /// A new project nobody has touched follows the interface language: its
  /// automatic currency (and the illustrative prices) move to the default
  /// currency of the new language.
  void _followLanguageCurrency() {
    if (!_autoCurrency || dirty || project.entities.isNotEmpty || _undo.isNotEmpty) return;
    // 1.6.0 MOD: the mains frequency and the units follow too
    project.params
      ..mainsHz = defaultMainsHz()
      ..units = defaultUnits();
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
    final j = _saveMap();
    final s = encodeJson(j, pretty: pretty);
    if (markClean) markSaved(compact: pretty ? encodeJson(j) : s);
    return s;
  }

  /// The project file as Save writes it (pretty JSON with the results)
  /// and its form for the browser store, without marking anything. A large
  /// project is encoded once (the store compresses the pretty text just as
  /// well), so saving holds the window half as long.
  (String, String) fileJson() {
    final j = _saveMap();
    final pretty = encodeJson(j, pretty: true);
    return (pretty, pretty.length > LocalProjectStore.compressAbove ? pretty : encodeJson(j));
  }

  /// The project was written to a file: clean, and a version in the
  /// browser history. [compact] is the JSON of the file without indentation
  /// (taken now when not given); the browser compresses it beside the app
  /// when it is large, then the store says whether it kept it.
  void markSaved({String? compact}) {
    dirty = false;
    final run = ++_autosaveRun;
    final json = compact ?? encodeJson(_saveMap());
    final uid = project.meta.uid, name = project.meta.name, seq = _editSeq, edited = project.meta.modified;
    if (store.synchronous) {
      try {
        unawaited(store.save(uid, name, json, kind: 'saved', edited: edited).then((o) => _stored(o, seq, uid)));
      } catch (_) {}
      return;
    }
    unawaited(() async {
      try {
        final stored = await LocalProjectStore.encodeAsync(json);
        // a copy started after this save goes on its own; this one still records the version
        _stored(await store.save(uid, name, json, kind: 'saved', stored: stored, edited: edited), seq, uid);
        if (run == _autosaveRun) _storedSeq = seq;
      } catch (_) {}
    }());
  }

  /// The file this tab's project was last saved to or opened from (a file
  /// handle of the browser's file system access, in Chromium browsers):
  /// Save writes it again. Null otherwise (each save is a download).
  Object? fileHandle;

  /// The project as a file holds it: the drawing and the last results.
  Map<String, dynamic> _saveMap() {
    final j = project.toJson();
    final r = results;
    if (r != null) j['results'] = r.toJson();
    return j;
  }

  /// Opens project JSON [s] in this tab, item by item (what could not be
  /// read is set aside and reported). [fromStore]: the browser store's own
  /// copy (recovery, recent projects), whose uid is kept; a file or a link
  /// whose project is open in another tab or window, or whose copy in this
  /// browser holds changes not saved to a file, opens as a copy (a uid of
  /// its own, see [openProject]); [asCopy] always does (a shared link).
  void loadJson(String s, {bool fromStore = false, bool asCopy = false}) {
    final f = readProjectFile(s);
    final p = f.project;
    if (asCopy) p.meta.uid = ProjectMeta.newUid();
    DesignResults? r;
    final rj = f.results;
    if (rj != null) {
      try {
        r = DesignResults.fromJson(rj);
      } catch (e) {
        debugPrint('results: $e');
      }
    }
    openProject(p, results: r, fromStore: fromStore);
    if (!f.report.clean) notify([t('msg.loaded'), for (final n in f.report.notes) t('read.${n.code}', n.args)].join('. '));
  }

  /// Shows [p] in place of the current project (a file, a version, an
  /// example): selection, marks, history and cached images of the previous
  /// project are dropped. [dirty] marks it as not saved yet.
  ///
  /// Two tabs or windows never work on the same uid, which names the copy
  /// in the browser, the versions, the recent entry and the AI conversation:
  /// [p] gets a uid of its own when another tab of this window has its uid,
  /// when another window holds it (found out right after opening, see
  /// [_claimUid]), when it is a gallery file of the site (`example-…`) or,
  /// unless it comes [fromStore], when the browser keeps a copy of it with
  /// changes not saved to a file (the recovery keeps offering that one).
  void openProject(Project p, {DesignResults? results, bool dirty = false, bool fromStore = false}) {
    final why = _uidConflict(p, fromStore: fromStore);
    if (why != null) p.meta.uid = ProjectMeta.newUid();
    project = p;
    this.results = results;
    selection.clear();
    unconnected = results?.unconnected ?? {};
    _forgetProjectViews();
    _autoCurrency = false;
    _disposeImages();
    _undo.clear();
    _redo.clear();
    _highestId = p.nextIdValue;
    // nothing for the browser to copy until it is edited (a file only looked at is not offered by the recovery)
    _storedSeq = _editSeq;
    _storeProblem = null;
    fileHandle = null;
    this.dirty = dirty;
    _claimUid();
    zoomAll();
    notify(why == null || why.isEmpty ? t('msg.loaded') : '${t('msg.loaded')} ${t(why)}');
  }

  /// Another tab of this window with project [uid] (set by the workspace).
  bool Function(String uid)? uidTaken;

  /// Why [p] cannot keep its uid (a message key, '' to say nothing); null
  /// when it can.
  String? _uidConflict(Project p, {bool fromStore = false}) {
    final uid = p.meta.uid;
    if (uidTaken?.call(uid) ?? false) return 'msg.openedAsCopyTab';
    // the files of the site's gallery all carry the same uid
    if (uid.startsWith('example-')) return '';
    if (!fromStore && store.entry(uid)?.kind == 'autosave') return 'msg.openedAsCopyKept';
    return null;
  }

  // ------------------------------------------------------------ windows

  /// The check, across the windows of this browser, of the uid of the
  /// project on screen ([WindowLocks.claim]); the copies wait for it.
  Future<void> _claim = Future<void>.value();
  String? _claimedUid;

  /// Holds the lock of the project's uid for this window; when another
  /// window holds it, this tab's project takes a uid of its own (a copy),
  /// so the two never overwrite each other's copy and versions.
  void _claimUid() {
    final uid = project.meta.uid;
    if (_claimedUid == uid) return;
    _releaseUid();
    _claimedUid = uid;
    final locks = windowLocks;
    _claim = locks.claim(uid).then((held) {
      if (held != false || _disposed || project.meta.uid != uid) return;
      if (_claimedUid == uid) _claimedUid = null;
      renewUid();
      notify(t('msg.openedAsCopyWindow'));
    });
  }

  void _releaseUid() {
    final old = _claimedUid;
    if (old == null) return;
    _claimedUid = null;
    windowLocks.release(old);
  }

  /// Gives the project a uid of its own (a copy that no longer shares the
  /// copy in the browser, the versions and the recent entry of the one it
  /// came from): Save as copy, a project open in another window.
  void renewUid() {
    project.meta.uid = ProjectMeta.newUid();
    _tooLarge = null;
    _claimUid();
    dirty = true;
    notifyListeners();
  }

  /// Brings back saved version [version] of this project from its JSON [s]
  /// as one undo step (Ctrl+Z goes back to the work as it was): the
  /// drawing, the settings and the results the version was saved with; the
  /// uid, the version history and the recent entry stay. False when the
  /// JSON cannot be read or the edit is refused (a design running).
  bool restoreVersionJson(String s, {int? version}) {
    final Project p;
    DesignResults? r;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      p = Project.fromJson(j);
      final rj = j['results'];
      if (rj is Map<String, dynamic>) r = DesignResults.fromJson(rj);
    } catch (_) {
      return false;
    }
    final uid = project.meta.uid;
    final done = mutate(() {
      p.meta.uid = uid;
      p.ensureNextId(math.max(project.nextIdValue, _highestId));
      project = p;
      return true;
    }, label: 'hist.versionRestore|${version ?? ''}');
    if (done != true) return false;
    selection.clear();
    results = r;
    unconnected = r?.unconnected ?? {};
    _forgetProjectViews();
    _pruneImages();
    notifyListeners();
    return true;
  }

  int importDxf(String content, {String? layerPrefix}) => importDrawing(DxfReader.parse(content));

  /// Imports any supported drawing/GIS/raster file by extension.
  /// Returns a short description of what was imported.
  String importFile(String name, Uint8List bytes) {
    final geo = project.meta.georef, mark = _undo.isEmpty ? null : _undo.last;
    try {
      _drawingNotes.clear();
      return _withNotes(_importFile(name, bytes), _drawingNotes) + _tinNote();
    } on Error catch (e, st) {
      // a damaged file trips the readers' bounds (index, type, state
      // errors): tell the user so instead of the raw error
      debugPrint('$e\n$st');
      throw const FormatException('file_corrupt');
    } finally {
      // the georeference the import brought goes with its undo step
      _georefWithImport(geo, mark);
    }
  }

  /// [importFile] with the heavy readers (DXF, DWG, LAS) working in slices
  /// of [slicer]: the interface stays responsive while a large file is read,
  /// [WorkSlicer.onProgress] tells how far it got and [WorkSlicer.cancel]
  /// stops it with [ImportCancelled], before anything changed in the project.
  Future<String> importFileAsync(String name, Uint8List bytes, WorkSlicer slicer) async {
    final lower = name.toLowerCase();
    Object? read;
    try {
      if (lower.endsWith('.dwg')) {
        read = await DwgReader.parseAsync(bytes, slicer);
      } else if (lower.endsWith('.dxf')) {
        read = await DxfReader.parseBytesAsync(bytes, slicer);
      } else if (lower.endsWith('.las')) {
        read = await LasReader.readAsync(bytes, slicer, georef: project.meta.georef);
      }
    } on Error catch (e, st) {
      debugPrint('$e\n$st');
      throw const FormatException('file_corrupt');
    }
    // the last moment to cancel: the drawing goes in next
    await slicer.pause(1);
    _read = read;
    try {
      return importFile(name, bytes);
    } finally {
      _read = null;
    }
  }

  /// What [importFileAsync] read already (taken by the branch of its format).
  Object? _read;

  /// Notes of [importDrawing] (placement of the drawing) for the summary.
  final List<String> _drawingNotes = [];

  /// [summary] followed by the notes [codes] (after its own, if any).
  String _withNotes(String summary, Iterable<String> codes) {
    final list = {for (final w in codes) t.warning(w)}.toList();
    if (list.isEmpty) return summary;
    return summary.contains(' — ') ? '$summary; ${list.join('; ')}' : '$summary — ${list.join('; ')}';
  }

  String _importFile(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      // without the dialog (drag and drop, scripts): page 1 at 1:100
      final page = PdfReader.open(bytes).readPage(0);
      final r = mutate(
        () => addPdfPage(project, page, PdfImportOptions(layer: pdfLayerName(name), source: name)),
        invalidateResults: false,
        label: 'hist.importPdf',
      );
      zoomAll();
      return t('pdfimp.done', {'n': '${r?.entities.length ?? 0}', 'l': '${r?.layers.length ?? 0}'}) + _importWarnings([...page.warnings, ...?r?.warnings]);
    }
    if (lower.endsWith('.dwg')) {
      final pre = _read;
      final r = pre is DwgResult ? pre : DwgReader.parse(bytes);
      final n = importDrawing(r.document);
      final skipped = r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof')).length;
      // units not given, unsupported entities, blocks cut short…
      return t('imp.dwg', {'v': r.version.toUpperCase(), 'n': '$n', 'l': '${r.document.layers.length}'}) +
          (skipped > 0 ? t('imp.skipped', {'n': '$skipped'}) : '') +
          _importWarnings(r.document.warnings);
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
      return t('imp.points', {'n': '$n', 'geo': r.geographic ? ' (${project.meta.georef?.crsName ?? 'WGS84'})' : ''}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.zip') && _zipHas(bytes, '.shp')) {
      // every shapefile of the zip, each on the layer of its name
      final parts = ShapefileParts.unzip(bytes);
      if (parts.length > 1) {
        var records = 0, n = 0;
        final warnings = <String>{};
        var crs = '';
        for (final f in parts) {
          final r = ShpReader.parse(f.shp, dbf: f.dbf, prj: f.prj, cpg: f.cpg, shx: f.shx.isEmpty ? null : f.shx, georef: project.meta.georef, layer: f.name);
          if (r.georef != null) project.meta.georef ??= r.georef;
          n += importDrawing(r.document, markers: true);
          records += r.recordCount;
          warnings.addAll(r.warnings);
          if (crs.isEmpty) crs = r.crs;
        }
        return t('imp.shp', {'r': '$records', 'n': '$n', 'crs': crs.isEmpty ? (project.meta.georef?.crsName ?? '-') : crs}) + _importWarnings(warnings);
      }
    }
    if (lower.endsWith('.shp') || (lower.endsWith('.zip') && _zipHas(bytes, '.shp'))) {
      final r = ShpReader.parseAny(name, bytes, georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document);
      return t('imp.shp', {'r': '${r.recordCount}', 'n': '$n', 'crs': r.crs.isEmpty ? (project.meta.georef?.crsName ?? '-') : r.crs}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.geojson') || lower.endsWith('.json')) {
      final r = GeoJsonReader.parse(_decodeText(bytes), georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document, markers: true);
      return t('imp.geojson', {'f': '${r.featureCount}', 'n': '$n', 'crs': r.crs.recognised ? r.crs.name : (project.meta.georef?.crsName ?? '-')}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.gpx')) {
      final r = GpxReader.parse(_decodeText(bytes), georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document, markers: true);
      return t('imp.gpx', {'w': '${r.waypointCount}', 'r': '${r.routeCount}', 't': '${r.trackCount}', 'n': '$n'}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.xml') || lower.endsWith('.landxml')) {
      final r = LandXmlReader.parse(_decodeText(bytes), georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final n = importDrawing(r.document, markers: true);
      return t('imp.landxml', {'s': '${r.surfaces.length}', 'p': '${r.cgPointCount}', 'n': '$n'}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.las') || lower.endsWith('.laz')) {
      // a point cloud: its ground points, thinned to a grid, become terrain
      final pre = _read;
      final r = pre is LasImportResult ? pre : LasReader.read(bytes, georef: project.meta.georef);
      if (r.georef != null) project.meta.georef ??= r.georef;
      final label = 'DEM $name';
      mutate(() {
        project.entities.removeWhere((e) => e is SpotHeightEntity && e.name == label);
        for (final sp in r.samples) {
          project.entities.add(SpotHeightEntity(id: project.newId(), position: sp.p, elevation: sp.z, name: label));
        }
      }, label: 'hist.dem');
      track('dem');
      zoomAll();
      return t('imp.las', {'n': '${r.samples.length}', 'p': '${r.pointsRead}', 'c': fmt(r.cellSize, 1)}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.dgn')) {
      final r = DgnReader.parse(bytes);
      final n = importDrawing(r.document);
      return t('imp.dgn', {'n': '$n', 'u': r.masterUnit}) + _importWarnings(r.warnings);
    }
    if (lower.endsWith('.inp')) {
      final m = EpanetInpReader.parse(_decodeText(bytes));
      final (doc, placement) = m.toDocument(georef: project.meta.georef);
      if (placement.georef != null) project.meta.georef ??= placement.georef;
      final n = importDrawing(doc, markers: true);
      return t('imp.inp', {'j': '${m.junctions.length}', 'l': '${m.pipes.length + m.pumps.length + m.valves.length}', 'n': '$n'}) + _importWarnings({...m.warnings, ...placement.warnings});
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
        return t('imp.demTiff', {'n': '${dem.samples.length}', 'w': '${dem.widthPx}', 'h': '${dem.heightPx}', 'crs': dem.crsName}) + _importWarnings(dem.warnings);
      }
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.tif') || lower.endsWith('.tiff') || lower.endsWith('.zip')) {
      final g = GeoImageReader.read(name, bytes);
      final e = importImage(g);
      zoomToEntity(e.id);
      return t(g.georeferenced ? 'imp.imageGeo' : 'imp.image', {'w': '${g.widthPx}', 'h': '${g.heightPx}', 'crs': project.meta.georef?.crsName ?? '-'}) + _importWarnings(g.warnings);
    }
    // the text in the file's code page ($DWGCODEPAGE) or UTF-8
    final pre = _read;
    final doc = pre is DxfDocument ? pre : DxfReader.parseBytes(bytes);
    final n = importDrawing(doc);
    return t('imp.dxf', {'n': '$n'}) + _importWarnings(doc.warnings);
  }

  /// The import's notes (coordinate system, unsupported parts) after its summary.
  String _importWarnings(Iterable<String> codes) {
    final list = {for (final w in codes) t.warning(w)}.toList();
    return list.isEmpty ? '' : ' — ${list.join('; ')}';
  }

  static bool _zipHas(Uint8List bytes, String ext) {
    // cheap check of the central directory names
    final s = latin1.decode(bytes.length > 200000 ? bytes.sublist(bytes.length - 200000) : bytes, allowInvalid: true).toLowerCase();
    return s.contains(ext);
  }

  /// Text of a file: a byte order mark (UTF-8, UTF-16 — "Unicode text" of
  /// spreadsheet programs) or UTF-16 told by its zero bytes, else UTF-8,
  /// else code page 1252.
  static String _decodeText(Uint8List bytes) => decodeTextBytes(bytes);

  /// Converts an imported drawing into project entities (contours and spot
  /// heights when elevations are present).
  ///
  /// Points without an elevation (GPS waypoints, the markers of a KML, the
  /// points of a 2D drawing, a list of points without Z) become small
  /// circles: a spot height at zero would pull the terrain down. ([asSpots]
  /// and [markers] are kept for the callers that pass them.) Layers are
  /// matched without regard to case, as CAD programs do ("Text" and "TEXT"
  /// are one layer), and new ones take the colour (index or true colour)
  /// and the off or frozen state of the file. A drawing in UTM coordinates
  /// imported into a georeferenced project is moved by the project origin
  /// (with a note); into a project without one, the note says so.
  int importDrawing(DxfDocument doc, {bool asSpots = false, bool markers = true}) {
    final s = doc.unitScale;
    final shift = _utmShift(doc);
    Pt at(Pt p) => Pt(p.x * s - shift.x, p.y * s - shift.y);
    final list = <Entity>[];
    mutate(() {
      final byKey = {for (final l in project.layers) l.name.toLowerCase(): l.name};
      for (final l in doc.layers) {
        final key = l.name.toLowerCase();
        if (byKey.containsKey(key)) continue;
        project.layers.add(Layer(name: l.name, color: 0xFF000000 | (l.rgb ?? aciRgb(l.color)), visible: l.visible));
        byKey[key] = l.name;
      }
      for (final e in doc.entities) {
        // a damaged file may hold "nan" or huge exponents: such geometry is
        // left out (it could neither be drawn nor saved)
        if (!_finiteGeometry(e)) continue;
        final layer = byKey[e.layer.toLowerCase()] ?? e.layer;
        final elev = e.elevation != null && e.elevation!.isFinite ? e.elevation : null;
        switch (e.type) {
          case 'LINE':
            list.add(LineEntity(id: project.newId(), layer: layer, name: e.name, a: at(e.points[0]), b: at(e.points[1])));
          case 'POLYLINE':
            if (e.points.length < 2) break;
            final pts = e.points.map(at).toList();
            if (!e.closed && _looksLikeBreaklineLayer(layer)) {
              list.add(BreaklineEntity(id: project.newId(), layer: Layers.breaklines, name: e.name, points: pts, elevations: elev == null ? null : List.filled(pts.length, elev * s)));
            } else if (elev != null && elev != 0 && !e.closed && _looksLikeContourLayer(layer)) {
              list.add(ContourEntity(id: project.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
            } else if (elev != null && elev != 0 && !e.closed && pts.length >= 3) {
              list.add(ContourEntity(id: project.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
            } else {
              list.add(PolylineEntity(id: project.newId(), layer: layer, name: e.name, points: pts, closed: e.closed));
            }
          case 'SPLINE':
            if (e.points.length >= 2) list.add(SplineEntity(id: project.newId(), layer: layer, name: e.name, points: e.points.map(at).toList(), closed: e.closed));
          case 'HATCH':
            if (e.points.length >= 3) {
              list.add(HatchEntity(id: project.newId(), layer: layer, name: e.name, points: e.points.map(at).toList(), angleDeg: e.rotation, spacing: e.height > 0 ? e.height * s : 1, solid: e.solid));
            }
          case 'CIRCLE':
            list.add(CircleEntity(id: project.newId(), layer: layer, name: e.name, center: at(e.center!), radius: e.radius * s));
          case 'ARC':
            // one turn at most, whatever the angles of the file
            final sweep = radToDeg(cadSweepRad(degToRad(e.startAngle), degToRad(e.endAngle)));
            list.add(
              ArcEntity(id: project.newId(), layer: layer, name: e.name, center: at(e.center!), radius: e.radius * s, startRad: degToRad(cadNormalizeDeg(e.startAngle)), sweepRad: degToRad(sweep)),
            );
          case 'TEXT':
            list.add(TextEntity(id: project.newId(), layer: layer, name: e.name, position: at(e.points[0]), text: e.text, height: e.height * s, rotationDeg: e.rotation));
          case 'POINT':
            if (elev == null) {
              // a place without an elevation: a marker, never a spot height at zero
              list.add(CircleEntity(id: project.newId(), layer: layer, name: e.name, center: at(e.points[0]), radius: 0.5));
            } else {
              list.add(SpotHeightEntity(id: project.newId(), layer: Layers.spotHeights, name: e.name, position: at(e.points[0]), elevation: elev * s));
            }
        }
      }
      project.entities.addAll(list);
    }, label: 'hist.import');
    zoomAll();
    return list.length;
  }

  /// Offset of a drawing whose coordinates are UTM ones (eastings of 100 to
  /// 900 km, northings up to 10 000 km) for a georeferenced project: its
  /// origin, when the drawing lands within 100 km of it (a note says the
  /// drawing was moved, or that it lies far away and was kept). Raw CAD
  /// coordinates only reach here that large: the GIS readers place theirs.
  Pt _utmShift(DxfDocument doc) {
    final b = doc.bounds;
    if (b.isEmpty) return Pt.zero;
    final s = doc.unitScale;
    final cx = (b.minX + b.maxX) / 2 * s, cy = (b.minY + b.maxY) / 2 * s;
    if (!cx.isFinite || !cy.isFinite || (cx.abs() <= 100000 && cy.abs() <= 100000)) return Pt.zero;
    final utm = cx >= 100000 && cx <= 900000 && cy >= 0 && cy <= 10000000;
    if (!utm) return Pt.zero;
    final g = project.meta.georef;
    if (g == null) {
      _drawingNotes.add('cad_utm_no_georef');
      return Pt.zero;
    }
    if ((cx - g.originEasting).abs() > 100000 || (cy - g.originNorthing).abs() > 100000) {
      _drawingNotes.add('cad_far_from_georef');
      return Pt.zero;
    }
    _drawingNotes.add('cad_moved_to_georef');
    return Pt(g.originEasting, g.originNorthing);
  }

  static bool _finiteGeometry(DxfEntity e) {
    bool ok(Pt p) => p.x.isFinite && p.y.isFinite;
    return e.points.every(ok) && (e.center == null || ok(e.center!)) && e.radius.isFinite && e.startAngle.isFinite && e.endAngle.isFinite && e.rotation.isFinite && e.height.isFinite;
  }

  /// Layers of breaklines in survey drawings ("BREAKLINES", "linha de
  /// quebra", "quiebre", "ruptura").
  static bool _looksLikeBreaklineLayer(String layer) {
    final l = layer.toLowerCase();
    return l.contains('break') || l.contains('quebra') || l.contains('quiebre') || l.contains('ruptura');
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
    labels: ReportLabels(
      t: t.call,
      has: t.has,
      warning: (w) => t.warning(w, entityName: entityName),
      entityName: entityName,
    ),
  );

  String exportDxf() => exporter().dxf();

  List<ReportTable>? _tablesCache;
  DesignResults? _tablesFor;
  String _tablesLang = '';
  int _tablesUnconnected = -1;
  int _tablesSeq = -1;

  /// Report tables for the current results (cached while results and
  /// language are unchanged; cheap to rebuild without results).
  List<ReportTable> reportTables() {
    final r = results;
    if (r == null) return exporter().reportTables();
    if (_tablesCache == null || !identical(_tablesFor, r) || _tablesLang != lang || _tablesUnconnected != unconnected.length || _tablesSeq != _editSeq) {
      _tablesCache = exporter().reportTables();
      _tablesFor = r;
      _tablesLang = lang;
      _tablesUnconnected = unconnected.length;
      // settings that keep the results (units, quote) still change the tables
      _tablesSeq = _editSeq;
    }
    return _tablesCache!;
  }

  String reportCsv() => exporter().reportCsv();

  Map<String, dynamic> debugState() => {'entities': project.entities.length, 'selection': selection.length, 'results': results != null};
}

double mathMax(double a, double b) => a > b ? a : b;

String prettyJson(Object o) => const JsonEncoder.withIndent('  ').convert(o);

/// An in-place edit of the project settings by a dialog (see
/// [ProjectController.beginSettingsEdit]).
class SettingsEdit {
  SettingsEdit._(this._state, this._project, this._dirty, this._results);
  final _UndoState _state;
  final Project _project;

  /// The "modified" mark and the results when the dialog opened (put back
  /// by [ProjectController.cancelSettingsEdit]).
  final bool _dirty;
  final DesignResults? _results;
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
