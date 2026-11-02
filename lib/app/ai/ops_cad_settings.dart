/// The settings registry of the AI assistant (get_setting / set_setting):
/// every option of the program by a dotted key, typed and range-checked —
/// the design parameters (`params.*`, the names of get_parameters), the
/// display units, the project details and the quote (project settings: one
/// undo step), the view, snapping, theme and interface language (`view.*`,
/// `snap.*`), the
/// defaults of the drawing tools (`tool.*`) and the program options
/// (`app.*`). View, tool and program settings are not project changes.
library;

import 'dart:math' as math;

import '../../core/ai/agent_loop.dart';
import '../../core/design/pivot.dart' show PivotKind;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/lengthen.dart' show LengthenMode;
import '../../core/units.dart';
import '../canvas/basemap.dart' show BaseMapLayer;
import '../i18n.dart' show languageNames, supportedLanguages;
import '../state/controller.dart';
import '../theme.dart';
import '../tools/cad_plus_commands.dart';
import '../widgets/reports_panel.dart' show reportTabKeys;
import 'agent_tools.dart';
import 'agent_tools_edit.dart' show parametersText;

/// Where a setting lives: in the project file (undoable, shared with the
/// project), on the screen, in the drawing tools, or in the program.
enum SettingScope { project, view, tool, app }

/// One setting: a typed value with its range, read and written through the
/// controller. A setting without [write] is read-only; one with [delegated]
/// is checked and written by set_parameters.
class AiSetting {
  AiSetting({
    required this.key,
    required this.type,
    required this.description,
    required this.read,
    this.write,
    this.scope = SettingScope.view,
    this.unit = '',
    this.min,
    this.max,
    this.options,
    this.nullable = false,
    this.validate,
    this.delegated = false,
  });
  final String key;

  /// `boolean`, `number`, `integer`, `string` or `enum`.
  final String type;
  final String description;
  final SettingScope scope;
  final String unit;
  final double? min, max;
  final List<String>? options;

  /// null is a value (e.g. "size by the design" for a pipe default).
  final bool nullable;
  final Object? Function() read;
  final void Function(Object? v)? write;

  /// A further check of a value (catalogue ids…): the problem, or null.
  final String? Function(Object? v)? validate;
  final bool delegated;

  bool get readOnly => write == null && !delegated;
  bool get isProject => scope == SettingScope.project;

  /// What the value may be, for the model.
  String get typeText {
    final parts = <String>[
      switch (type) {
        'enum' => 'one of ${options!.join(', ')}',
        'number' || 'integer' => '$type${min != null || max != null ? ' ${cadNum(min)} … ${cadNum(max)}' : ''}',
        _ => type,
      },
      if (unit.isNotEmpty) unit,
      if (nullable) 'or null',
      if (readOnly) 'read-only',
    ];
    return parts.join(', ');
  }

  /// The first problem of [v] for this setting, or null when it fits.
  String? problem(Object? v) {
    if (readOnly) return '$key is read-only.';
    if (delegated) return null;
    if (v == null) return nullable ? null : '$key must not be null.';
    switch (type) {
      case 'boolean':
        if (v is! bool) return '$key must be true or false.';
      case 'number' || 'integer':
        if (v is! num || !v.isFinite) return '$key must be a number.';
        if (type == 'integer' && v != v.roundToDouble()) return '$key must be a whole number.';
        if ((min != null && v < min!) || (max != null && v > max!)) return '$key = $v is outside ${cadNum(min)} … ${cadNum(max)}${unit.isEmpty ? '' : ' $unit'}.';
      case 'enum':
        if (v is! String || !options!.contains(v)) return '$key must be one of ${options!.join(', ')}.';
      default:
        if (v is! String) return '$key must be a text.';
    }
    return validate?.call(v);
  }

  /// `key = value (type) — description`.
  String line() => '$key = ${showValue(read())} ($typeText) — $description';
}

/// What setting [key] to [value] does beyond the screen, for the
/// permissions of set_setting: null for a toggle of the view, the snapping
/// or the defaults of the drawing tools of this page (a read: allowed in
/// every mode, as nothing leaves the page; since 1.6.0 this browser
/// remembers the snaps and the tool defaults for the next session, as it
/// does when the user sets them, and they change back the same way);
/// otherwise a
/// change — the project's settings, and what this browser keeps (the
/// interface language, the theme, the program options) — refused in
/// read-only and plan modes, and [confirm]ed whatever the mode when it
/// fetches from an address of the model's choosing (the custom base map:
/// its tiles would come from that host, every view of the user's screen
/// telling it where the project is, the pictures coming back into the
/// conversation) or changes how the program keeps the user's work
/// (`app.*`: the autosave).
({bool confirm})? settingImpact(String key, Object? value) {
  if (key.startsWith('params.') || key.startsWith('units.') || key.startsWith('project.') || key.startsWith('quote.')) return (confirm: false);
  if (key == 'view.custom_tile_url' || (key == 'view.base_map' && value == 'custom')) return (confirm: true);
  if (key.startsWith('app.')) return (confirm: true);
  if (key == 'view.language' || key == 'view.theme') return (confirm: false);
  return null;
}

/// [v] for the model: numbers without scientific notation, lists of numbers
/// as `[a, b]`, null as `null`.
String showValue(Object? v) => switch (v) {
  null => 'null',
  double x => x.isFinite ? (x == x.roundToDouble() && x.abs() < 1e15 ? x.toStringAsFixed(0) : _trim(x.toStringAsFixed(6))) : '-',
  List l => '[${l.map(showValue).join(', ')}]',
  String s => '"$s"',
  _ => '$v',
};

String _trim(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;

/// A bound for the type text.
String cadNum(double? v) => v == null ? '…' : showValue(v);

double _d(Object? v) => (v as num).toDouble();

/// Every setting of the program for [b], fresh (the closures read the
/// controller when called). [pending] holds the other values of the same
/// set_setting call (a nozzle is checked against the emitter set with it).
List<AiSetting> aiSettings(AgentToolbox b, {Map<String, Object?> pending = const {}}) {
  final c = b.c;
  final cat = b.p.catalog;
  final s = c.toolSettings;
  String? pipe(Object? v) => v == null || cat.pipe('$v') != null ? null : 'Unknown pipe "$v" (search_catalog kind "pipe").';
  String? emitter(Object? v) => cat.outlet('$v') != null ? null : 'Unknown emitter "$v" (search_catalog kind "emitter").';
  String? tape(Object? v) => cat.tape('$v') != null ? null : 'Unknown tape "$v" (search_catalog kind "tape").';
  String? controlValve(Object? v) {
    final x = cat.valve('$v');
    return x != null && x.kind == ValveKind.control ? null : 'Unknown zone valve "$v" (search_catalog kind "valve": a control valve).';
  }

  String? device(Object? v) {
    final x = cat.valve('$v');
    return x != null && x.kind != ValveKind.control ? null : 'Unknown inline device "$v" (search_catalog kind "valve": not a control valve).';
  }

  String? pump(Object? v) => cat.pump('$v') != null ? null : 'Unknown pump "$v" (search_catalog kind "pump").';
  AiSetting tool(
    String key,
    String type,
    String description,
    Object? Function() read,
    void Function(Object? v) write, {
    String unit = '',
    double? min,
    double? max,
    List<String>? options,
    bool nullable = false,
    String? Function(Object? v)? validate,
  }) => AiSetting(
    key: 'tool.$key',
    type: type,
    description: description,
    read: read,
    write: write,
    scope: SettingScope.tool,
    unit: unit,
    min: min,
    max: max,
    options: options,
    nullable: nullable,
    validate: validate,
  );
  AiSetting view(
    String key,
    String type,
    String description,
    Object? Function() read,
    void Function(Object? v)? write, {
    String unit = '',
    double? min,
    double? max,
    List<String>? options,
    String? Function(Object? v)? validate,
  }) => AiSetting(key: key, type: type, description: description, read: read, write: write, unit: unit, min: min, max: max, options: options, validate: validate);
  AiSetting project(String key, String type, String description, Object? Function() read, void Function(Object? v) write, {String unit = '', double? min, double? max, List<String>? options}) =>
      AiSetting(key: key, type: type, description: description, read: read, write: write, scope: SettingScope.project, unit: unit, min: min, max: max, options: options);
  final u = b.p.params.units;
  final m = b.p.meta;
  final q = b.p.proposal;
  return [
    // ------------------------------------------------ design parameters
    for (final (name, rest) in designParameterLines(b))
      AiSetting(key: 'params.$name', type: 'parameter', description: rest, read: () => designParameterValue(b, name), scope: SettingScope.project, delegated: true),
    // ------------------------------------------------ units
    project(
      'units.system',
      'enum',
      'Display units at once: "metric" (m, L/h, m of water, mm) or "us" (ft, gpm, psi, in); "custom" when mixed. The project file stays SI.',
      () {
        if (u.toJson().toString() == Units.metric.toJson().toString()) return 'metric';
        if (u.toJson().toString() == Units.us.toJson().toString()) return 'us';
        return 'custom';
      },
      (v) {
        if (v == 'custom') throw ToolInputError('units.system "custom" is the result of mixed units: set units.length, units.flow, units.pressure and units.diameter instead.');
        b.p.params.units = v == 'us' ? Units.us : Units.metric;
      },
      options: const ['metric', 'us', 'custom'],
    ),
    project(
      'units.length',
      'enum',
      'Display unit of lengths in reports and fields.',
      () => u.length.name,
      (v) => b.p.params.units = b.p.params.units.copyWith(length: LengthUnit.values.byName('$v')),
      options: [for (final x in LengthUnit.values) x.name],
    ),
    project(
      'units.flow',
      'enum',
      'Display unit of flows (lph = L/h, lpm = L/min, lps = L/s).',
      () => u.flow.name,
      (v) => b.p.params.units = b.p.params.units.copyWith(flow: FlowUnit.values.byName('$v')),
      options: [for (final x in FlowUnit.values) x.name],
    ),
    project(
      'units.pressure',
      'enum',
      'Display unit of pressures (mH2O = metres of water).',
      () => u.pressure.name,
      (v) => b.p.params.units = b.p.params.units.copyWith(pressure: PressureUnit.values.byName('$v')),
      options: [for (final x in PressureUnit.values) x.name],
    ),
    project(
      'units.diameter',
      'enum',
      'Display unit of pipe diameters.',
      () => u.diameter.name,
      (v) => b.p.params.units = b.p.params.units.copyWith(diameter: DiameterUnit.values.byName('$v')),
      options: [for (final x in DiameterUnit.values) x.name],
    ),
    // ------------------------------------------------ project details (File → Details)
    project('project.name', 'string', 'Project name (title block, file name).', () => m.name, (v) => b.p.meta.name = '$v'),
    project('project.client', 'string', 'Client.', () => m.client, (v) => b.p.meta.client = '$v'),
    project('project.site', 'string', 'Site or farm.', () => m.site, (v) => b.p.meta.site = '$v'),
    project('project.designer', 'string', 'Designer.', () => m.designer, (v) => b.p.meta.designer = '$v'),
    project('project.notes', 'string', 'Notes of the project.', () => m.notes, (v) => b.p.meta.notes = '$v'),
    // ------------------------------------------------ quote (Design → Quote)
    project(
      'quote.markup_pct',
      'number',
      'Margin over the cost of the materials, applied to every bill-of-materials line.',
      () => q.markupPct,
      (v) => b.p.proposal.markupPct = _d(v),
      unit: '%',
      min: -100,
      max: 1000,
    ),
    project('quote.labour_pct', 'number', 'Labour (installation) as a share of the material cost.', () => q.labourPct, (v) => b.p.proposal.labourPct = _d(v), unit: '%', min: 0, max: 1000),
    project(
      'quote.trench_cost_per_m3',
      'number',
      'Excavation and backfill per cubic metre of trench (project currency).',
      () => q.trenchCostPerM3,
      (v) => b.p.proposal.trenchCostPerM3 = _d(v),
      min: 0,
      max: 1e9,
    ),
    project(
      'quote.trench_width_m',
      'number',
      'Trench width; 0 = from the pipe (outside diameter + 0.2 m, at least 0.3 m).',
      () => q.trenchWidthM,
      (v) => b.p.proposal.trenchWidthM = _d(v),
      unit: 'm',
      min: 0,
      max: 10,
    ),
    project('quote.bedding_m', 'number', 'Bedding under the pipe, added to the trench depth.', () => q.beddingM, (v) => b.p.proposal.beddingM = _d(v), unit: 'm', min: 0, max: 2),
    project('quote.discount_pct', 'number', 'Discount over the subtotal.', () => q.discountPct, (v) => b.p.proposal.discountPct = _d(v), unit: '%', min: 0, max: 100),
    project('quote.tax_pct', 'number', 'Taxes over the discounted subtotal.', () => q.taxPct, (v) => b.p.proposal.taxPct = _d(v), unit: '%', min: 0, max: 100),
    project('quote.freight', 'number', 'Freight and delivery (project currency), outside the taxes.', () => q.freight, (v) => b.p.proposal.freight = _d(v), min: 0, max: 1e9),
    project('quote.validity_days', 'integer', 'Days the prices hold.', () => q.validityDays, (v) => b.p.proposal.validityDays = (v as num).toInt(), unit: 'days', min: 1, max: 3650),
    project('quote.payment_terms', 'string', 'Payment terms printed on the quote.', () => q.paymentTerms, (v) => b.p.proposal.paymentTerms = '$v'),
    project('quote.notes', 'string', 'Notes printed on the quote.', () => q.notes, (v) => b.p.proposal.notes = '$v'),
    project('quote.annual_benefit', 'number', 'Yearly benefit of the system (project currency), for the payback.', () => q.annualBenefit, (v) => b.p.proposal.annualBenefit = _d(v), min: 0, max: 1e12),
    project('quote.crews', 'integer', 'Crews working at the same time (construction schedule).', () => q.crews, (v) => b.p.proposal.crews = (v as num).toInt(), min: 1, max: 50),
    // ------------------------------------------------ view (View menu, status bar)
    view('view.grid', 'boolean', 'Show the background grid (View → Grid, F7).', () => c.showGrid, (v) => c.showGrid = v as bool),
    view('view.labels', 'boolean', 'Show the result labels on the drawing (View → Labels).', () => c.showLabels, (v) => c.showLabels = v as bool),
    view('view.wetted_radii', 'boolean', 'Show the wetted circles of sprinklers (View → Wetted radii).', () => c.showWettedRadii, (v) => c.showWettedRadii = v as bool),
    view('view.grips', 'boolean', 'Show the editing grips of selected items (View → Grips).', () => c.showGrips, (v) => c.showGrips = v as bool),
    view(
      'view.overlay',
      'enum',
      'Colouring of the drawing (View → Overlay): velocity, pressure, sizes, minMax (zone pressure range), densogram (water applied), slope / aspect maps of the terrain, or none.',
      () => c.overlay.name,
      (v) {
        c.overlay = OverlayMode.values.byName('$v');
        if (c.overlay == OverlayMode.densogram) c.densogram;
      },
      options: [for (final x in OverlayMode.values) x.name],
    ),
    view(
      'view.base_map',
      'enum',
      'Base map under the drawing (needs a georeference). The google* maps need the user\'s own Map Tiles API key (View → Base map → Google key; the assistant never handles keys), custom needs view.custom_tile_url.',
      () => c.baseMap.name,
      (v) {
        final x = BaseMap.values.byName('$v');
        c.baseMap = x;
      },
      options: [for (final x in BaseMap.values) x.name],
      validate: (v) {
        final x = BaseMap.values.byName('$v');
        if (x.isGoogle && c.googleMapsKey == null) return 'The Google maps need the user\'s Map Tiles API key: ask the user to enter it under View → Base map → Google key.';
        if (x == BaseMap.custom && !BaseMapLayer.isValidTemplate(c.customTileUrl)) return 'Set view.custom_tile_url to an XYZ template first.';
        return null;
      },
    ),
    view('view.base_map_opacity', 'number', 'Opacity of the base map.', () => c.baseMapOpacity, (v) => c.baseMapOpacity = _d(v), min: 0.05, max: 1),
    view(
      'view.custom_tile_url',
      'string',
      'XYZ tile template of the custom base map, e.g. https://example.com/tiles/{z}/{x}/{y}.png ({z}, {x}, {y}, optional {s} and {-y}); "" removes it. Kept in this browser.',
      () => c.customTileUrl,
      (v) => c.setCustomTileUrl('$v'),
      validate: (v) => '$v'.trim().isEmpty || BaseMapLayer.isValidTemplate('$v') ? null : 'Not an XYZ template with {z}, {x} and {y}.',
    ),
    view(
      'view.theme',
      'enum',
      'Colour theme of the program (View → Theme), kept in this browser.',
      () => uiThemeMode.value.name,
      (v) => setThemeMode(CadThemeMode.values.byName('$v')),
      options: [for (final x in CadThemeMode.values) x.name],
    ),
    view(
      'view.language',
      'enum',
      'Language of the interface (View → Language), for every open tab, kept in this browser: ${[for (final l in supportedLanguages) '$l ${languageNames[l] ?? l}'].join(', ')}. The user\'s choice: change it when the user asks. Your answers follow the language the user writes in.',
      () => c.lang,
      (v) => c.setLanguage('$v'),
      options: supportedLanguages,
    ),
    view('view.reports_panel', 'boolean', 'Show the reports panel under the drawing (F2).', () => c.showReports, (v) => c.showReports = v as bool),
    view(
      'view.report_tab',
      'enum',
      'Tab of the reports panel (shown when the panel opens).',
      () => reportTabKeys[c.reportTab.clamp(0, reportTabKeys.length - 1)],
      (v) => c.reportTab = reportTabKeys.indexOf('$v'),
      options: reportTabKeys,
    ),
    view(
      'view.active_tool',
      'enum',
      'The user\'s active drawing tool (it waits for the user\'s clicks; the assistant draws with create_entities and the operations instead).',
      () => c.activeTool.name,
      (v) {
        final id = ToolId.values.byName('$v');
        if (id == ToolId.pump || id == ToolId.misc) c.toolSettings.pointScope = HydraulicScope.mainline;
        if (id == ToolId.outlet || id == ToolId.valve) c.toolSettings.pointScope = HydraulicScope.zone;
        c.setTool(id);
      },
      options: [for (final x in ToolId.values) x.name],
    ),
    view('view.visible_bbox', 'array', 'Part of the drawing on screen [minX, minY, maxX, maxY] in metres (move it with zoom_to or zoom_view).', () {
      final v = c.camera.visible;
      return v.isEmpty ? null : [roundTo(v.minX, 2), roundTo(v.minY, 2), roundTo(v.maxX, 2), roundTo(v.maxY, 2)];
    }, null),
    view('view.scale', 'number', 'Screen pixels per metre of the view (read-only; zoom_view changes it).', () => roundTo(c.camera.scale, 4), null, unit: 'px/m'),
    // ------------------------------------------------ snapping (status bar)
    view('snap.enabled', 'boolean', 'Object snap of the drawing tools (F3).', () => c.snap.enabled, (v) => c.snap.enabled = v as bool),
    view('snap.grid', 'boolean', 'Snap to the grid (F9).', () => c.snap.grid, (v) => c.snap.grid = v as bool),
    view('snap.grid_size_m', 'number', 'Grid spacing used by the grid snap.', () => c.snap.gridSize, (v) => c.snap.gridSize = _d(v), unit: 'm', min: 0.001, max: 10000),
    view('snap.ortho', 'boolean', 'Orthogonal mode: segments horizontal or vertical (F8).', () => c.snap.ortho, (v) => c.snap.ortho = v as bool),
    view(
      'snap.polar_step_deg',
      'number',
      'Polar tracking step (0 = off; the status bar cycles 0, 15, 30, 45, 90).',
      () => c.snap.polarStepDeg,
      (v) => c.snap.polarStepDeg = _d(v),
      unit: '°',
      min: 0,
      max: 90,
    ),
    view('snap.tolerance_px', 'number', 'Snap and pick distance on screen.', () => c.snap.tolerancePx, (v) => c.snap.tolerancePx = _d(v), unit: 'px', min: 1, max: 50),
    // 1.6.0 CAD: the object snaps one by one (View → Snaps), the dynamic input, the touch magnifier, Lengthen and the outline by a click
    for (final m in snapModes)
      view(
        'snap.mode_$m',
        'boolean',
        'Object snap "$m" on or off (View → Snaps; the others stay as they are).',
        () => c.snap.modes.contains(m),
        (v) => v == true ? c.snap.modes.add(m) : c.snap.modes.remove(m),
      ),
    view(
      'snap.dynamic_input',
      'boolean',
      'Length and angle of the segment beside the cursor, typed there (Tab goes from the length to the angle).',
      () => c.cadPlus.dynamicInput,
      (v) => c.cadPlus.dynamicInput = v as bool,
    ),
    view(
      'snap.touch_loupe',
      'boolean',
      'A magnifier over the finger while drawing on a touch screen; the point goes where the finger is lifted.',
      () => c.cadPlus.touchLoupe,
      (v) => c.cadPlus.touchLoupe = v as bool,
    ),
    tool(
      'lengthen_mode',
      'enum',
      'How Lengthen (LEN) reads its value: a difference, a total length or a percentage.',
      () => c.cadPlus.lengthenMode.name,
      (v) => c.cadPlus.lengthenMode = LengthenMode.values.byName('$v'),
      options: [for (final m in LengthenMode.values) m.name],
    ),
    tool(
      'lengthen_value',
      'number',
      'The value of Lengthen: metres for a difference or a total, percent for a percentage.',
      () => c.cadPlus.lengthenValue,
      (v) => c.cadPlus.lengthenValue = _d(v),
      min: -100000,
      max: 100000,
    ),
    tool(
      'boundary_as_area',
      'boolean',
      'The outline by a click inside (BO) makes an irrigated area instead of a closed polyline.',
      () => c.cadPlus.boundaryAsArea,
      (v) => c.cadPlus.boundaryAsArea = v as bool,
    ),
    AiSetting(
      key: 'app.edit_during_design',
      type: 'boolean',
      description: 'The user may go on editing while a design runs; its results, then out of date, are discarded when it ends (View → Snaps and drawing). The assistant itself still waits for a design to end.',
      read: () => c.editDuringDesign,
      write: (v) => c.editDuringDesign = v as bool,
      scope: SettingScope.app,
    ),
    // ------------------------------------------------ program
    AiSetting(
      key: 'app.autosave',
      type: 'boolean',
      description: 'Autosave to this browser every few seconds of work (File → Autosave).',
      read: () => c.autosaveEnabled,
      write: (v) => c.autosaveEnabled = v as bool,
      scope: SettingScope.app,
    ),
    AiSetting(
      key: 'app.auto_analyze',
      type: 'boolean',
      description: 'Analyse the design again a moment after every edit (Design → Auto analyse), kept in this browser.',
      read: () => c.autoAnalyze,
      write: (v) => c.autoAnalyze = v as bool,
      scope: SettingScope.app,
    ),
    // ------------------------------------------------ tool defaults (properties panel with nothing selected)
    tool(
      'point_scope',
      'enum',
      'Scope of new outlets, pumps, devices and junctions drawn by the user.',
      () => s.pointScope.name,
      (v) => s.pointScope = HydraulicScope.values.byName('$v'),
      options: [for (final x in HydraulicScope.values) x.name],
    ),
    tool('zone_pipe_spec', 'string', 'Pipe of new zone pipes (null = sized by the design).', () => s.zonePipeSpecId, (v) => s.zonePipeSpecId = v as String?, nullable: true, validate: pipe),
    tool('main_pipe_spec', 'string', 'Pipe of new mainline pipes (null = sized by the design).', () => s.mainPipeSpecId, (v) => s.mainPipeSpecId = v as String?, nullable: true, validate: pipe),
    tool(
      'lateral_pipe_spec',
      'string',
      'Pipe of new spray laterals and blocks (null = sized by the design).',
      () => s.lateralPipeSpecId,
      (v) => s.lateralPipeSpecId = v as String?,
      nullable: true,
      validate: pipe,
    ),
    tool(
      'outlet_spec',
      'string',
      'Emitter of new outlets and spray laterals; also sets tool.nozzle and tool.head_m to its first nozzle unless they are set in the same call.',
      () => s.outletSpecId,
      (v) => s.outletSpecId = '$v',
      validate: emitter,
    ),
    tool(
      'nozzle',
      'string',
      'Nozzle of tool.outlet_spec; also sets tool.head_m to its default head unless set in the same call.',
      () => s.nozzleId,
      (v) => s.nozzleId = v as String?,
      nullable: true,
      validate: (v) {
        final outlet = '${pending['tool.outlet_spec'] ?? s.outletSpecId}';
        return v == null || (cat.outlet(outlet)?.nozzles.any((n) => n.id == '$v') ?? false) ? null : 'Emitter "$outlet" has no nozzle "$v".';
      },
    ),
    tool('head_m', 'number', 'Head at new emitters and spray laterals.', () => s.headM, (v) => s.headM = _d(v), unit: 'm', min: 0.5, max: 120),
    tool('spacing_m', 'number', 'Emitter spacing along new spray laterals.', () => s.spacing, (v) => s.spacing = _d(v), unit: 'm', min: 0.05, max: 100),
    tool(
      'offset_m',
      'number',
      'Distance of the first emitter from the start of a new spray lateral (when tool.outlet_offset_half is false).',
      () => s.offset,
      (v) => s.offset = _d(v),
      unit: 'm',
      min: 0,
      max: 100,
    ),
    tool('outlet_offset_half', 'boolean', 'First emitter of new spray laterals at half the spacing.', () => s.outletOffsetHalf, (v) => s.outletOffsetHalf = v as bool),
    tool('arc_deg', 'number', 'Arc of new outlets.', () => s.arcDeg, (v) => s.arcDeg = _d(v), unit: '°', min: 1, max: 360),
    tool(
      'tape_spec',
      'string',
      'Drip tape of new tapes; also sets tool.tape_inlet_head_m to its default inlet head unless set in the same call.',
      () => s.tapeSpecId,
      (v) => s.tapeSpecId = '$v',
      validate: tape,
    ),
    tool('tape_inlet_head_m', 'number', 'Inlet head of new tapes.', () => s.tapeInletHeadM, (v) => s.tapeInletHeadM = _d(v), unit: 'm', min: 0.5, max: 60),
    tool('valve_spec', 'string', 'Zone valve of new valves and blocks.', () => s.valveSpecId, (v) => s.valveSpecId = '$v', validate: controlValve),
    tool('pump_spec', 'string', 'Pump of new pumps.', () => s.pumpSpecId, (v) => s.pumpSpecId = '$v', validate: pump),
    tool(
      'misc_spec',
      'string',
      'Inline device of new devices; also sets tool.misc_setting_m to its default setting unless set in the same call.',
      () => s.miscSpecId,
      (v) => s.miscSpecId = '$v',
      validate: device,
    ),
    tool('misc_setting_m', 'number', 'Setting of new pressure-regulating devices.', () => s.miscSettingM, (v) => s.miscSettingM = _d(v), unit: 'm', min: 0, max: 300),
    tool('split_pipes_on_insert', 'boolean', 'A point item drawn on a pipe splits it there.', () => s.splitPipesOnInsert, (v) => s.splitPipesOnInsert = v as bool),
    tool('keep_connections', 'boolean', 'Dragging a pipe node drags the items joined there (status bar "keep links").', () => s.keepConnections, (v) => s.keepConnections = v as bool),
    tool('contour_elevation_m', 'number', 'Elevation of the next contour drawn by the user.', () => s.contourElevation, (v) => s.contourElevation = _d(v), unit: 'm', min: -1000, max: 9000),
    tool(
      'contour_interval_m',
      'number',
      'Interval added after each contour drawn (with tool.contour_auto_increment).',
      () => s.contourInterval,
      (v) => s.contourInterval = _d(v),
      unit: 'm',
      min: 0.01,
      max: 1000,
    ),
    tool('contour_auto_increment', 'boolean', 'Raise the next contour by tool.contour_interval_m.', () => s.contourAutoIncrement, (v) => s.contourAutoIncrement = v as bool),
    tool('contour_smooth', 'boolean', 'Replace the clicked contour vertices by a smooth curve.', () => s.contourSmooth, (v) => s.contourSmooth = v as bool),
    tool('ask_elevation', 'boolean', 'Ask the elevation when the user finishes a contour or spot height.', () => s.askElevation, (v) => s.askElevation = v as bool),
    tool('spot_elevation_m', 'number', 'Elevation of the next spot height drawn by the user.', () => s.spotElevation, (v) => s.spotElevation = _d(v), unit: 'm', min: -1000, max: 9000),
    tool('pivot_kind', 'enum', 'Kind of new pivots.', () => s.pivotKind.name, (v) => s.pivotKind = PivotKind.values.byName('$v'), options: [for (final x in PivotKind.values) x.name]),
    tool('pivot_span_m', 'number', 'Span length of new pivots.', () => s.pivotSpan, (v) => s.pivotSpan = _d(v), unit: 'm', min: 1, max: 200),
    tool('pivot_depth_mm', 'number', 'Gross depth per cycle of new pivots.', () => s.pivotDepthMm, (v) => s.pivotDepthMm = _d(v), unit: 'mm', min: 0.1, max: 200),
    tool('pivot_hours', 'number', 'Hours per cycle of new pivots.', () => s.pivotHours, (v) => s.pivotHours = _d(v), unit: 'h', min: 0.5, max: 720),
    tool('pivot_end_pressure_m', 'number', 'End pressure of new pivots.', () => s.pivotEndPressureM, (v) => s.pivotEndPressureM = _d(v), unit: 'm', min: 0, max: 150),
    tool('pivot_travel_m', 'number', 'Travel of new linear moves.', () => s.pivotTravelM, (v) => s.pivotTravelM = _d(v), unit: 'm', min: 1, max: 20000),
    tool('align_keep_scale', 'boolean', 'The two-point alignment keeps the scale (rotation and move only).', () => s.alignKeepScale, (v) => s.alignKeepScale = v as bool),
    tool('text', 'string', 'Text of new texts.', () => s.text, (v) => s.text = '$v'),
    tool('text_height_m', 'number', 'Height of new texts and leaders.', () => s.textHeight, (v) => s.textHeight = _d(v), unit: 'm', min: 0.01, max: 1000),
    tool('leader_text', 'string', 'Text of new leaders.', () => s.leaderText, (v) => s.leaderText = '$v'),
    tool('dimension_offset_m', 'number', 'Default offset of linear dimensions added by add_dimension.', () => s.dimensionOffset, (v) => s.dimensionOffset = _d(v), unit: 'm', min: -1000, max: 1000),
    tool('angular_dim_radius_m', 'number', 'Arc radius of new angular dimensions.', () => s.angularDimRadius, (v) => s.angularDimRadius = _d(v), unit: 'm', min: 0.1, max: 1000),
    tool('radial_diameter', 'boolean', 'New radial dimensions write the diameter (Ø).', () => s.radialDiameter, (v) => s.radialDiameter = v as bool),
    tool('copy_on_transform', 'boolean', 'Rotate and scale tools of the user make copies.', () => s.copyOnTransform, (v) => s.copyOnTransform = v as bool),
    tool('mirror_keep_source', 'boolean', 'The mirror tool of the user keeps the originals.', () => s.mirrorKeepSource, (v) => s.mirrorKeepSource = v as bool),
    tool('offset_distance_m', 'number', 'Distance of the offset tool of the user.', () => s.offsetDistance, (v) => s.offsetDistance = _d(v), unit: 'm', min: 0.001, max: 10000),
    tool('hatch_angle_deg', 'number', 'Angle of new hatches.', () => s.hatchAngle, (v) => s.hatchAngle = _d(v), unit: '°', min: -360, max: 360),
    tool('hatch_spacing_m', 'number', 'Line spacing of new hatches.', () => s.hatchSpacing, (v) => s.hatchSpacing = _d(v), unit: 'm', min: 0.01, max: 1000),
    tool('hatch_solid', 'boolean', 'New hatches are solid fills.', () => s.hatchSolid, (v) => s.hatchSolid = v as bool),
    tool('symbol_kind', 'enum', 'Kind of new symbols.', () => s.symbolKind.name, (v) => s.symbolKind = SymbolKind.values.byName('$v'), options: [for (final x in SymbolKind.values) x.name]),
    tool('symbol_size_m', 'number', 'Size of new symbols.', () => s.symbolSize, (v) => s.symbolSize = _d(v), unit: 'm', min: 0.01, max: 1000),
    tool('spline_closed', 'boolean', 'New splines are closed.', () => s.splineClosed, (v) => s.splineClosed = v as bool),
    tool('controller_stations', 'integer', 'Stations of new controllers.', () => s.controllerStations, (v) => s.controllerStations = (v as num).toInt(), min: 1, max: 999),
    tool('controller_volts', 'number', 'Output voltage of new controllers.', () => s.controllerVolts, (v) => s.controllerVolts = _d(v), unit: 'V', min: 1, max: 480),
    tool('comment_author', 'string', 'Author written on new review comments.', () => s.commentAuthor, (v) => s.commentAuthor = '$v'),
  ];
}

/// The design parameters as get_parameters lists them: (name, the rest of
/// the line: value, unit, range and note).
List<(String, String)> designParameterLines(AgentToolbox b) {
  final out = <(String, String)>[];
  for (final line in parametersText(b).split('\n')) {
    final m = RegExp(r'^(\w+) = (.*)$').firstMatch(line);
    if (m != null) out.add((m.group(1)!, 'Design parameter (set_parameters): ${m.group(2)!}'));
  }
  return out;
}

/// The value of design parameter [name] as get_parameters shows it (a
/// number, true/false or the option), null when unknown.
Object? designParameterValue(AgentToolbox b, String name) {
  for (final line in parametersText(b).split('\n')) {
    final m = RegExp(r'^(\w+) = (\S+)').firstMatch(line);
    if (m == null || m.group(1) != name) continue;
    final v = m.group(2)!;
    if (v == 'true' || v == 'false') return v == 'true';
    return num.tryParse(v)?.toDouble() ?? v;
  }
  return null;
}

/// What setting tool.outlet_spec / nozzle / tape_spec / misc_spec change
/// with them, as the properties panel does (unless the call sets those
/// too): the keys and values added.
Map<String, Object?> settingFollowUps(AgentToolbox b, Map<String, Object?> values) {
  final cat = b.p.catalog;
  final out = <String, Object?>{};
  final outlet = values['tool.outlet_spec'];
  if (outlet != null && !values.containsKey('tool.nozzle')) {
    final nz = cat.outlet('$outlet')?.nozzles.firstOrNull;
    out['tool.nozzle'] = nz?.id;
    if (nz != null && !values.containsKey('tool.head_m')) out['tool.head_m'] = nz.defaultHeadM;
  } else if (values['tool.nozzle'] != null && !values.containsKey('tool.head_m')) {
    final o = cat.outlet('${outlet ?? b.c.toolSettings.outletSpecId}');
    final nz = o?.nozzles.where((n) => n.id == '${values['tool.nozzle']}').firstOrNull;
    if (nz != null) out['tool.head_m'] = nz.defaultHeadM;
  }
  final tp = values['tool.tape_spec'];
  if (tp != null && !values.containsKey('tool.tape_inlet_head_m')) {
    final x = cat.tape('$tp');
    if (x != null) out['tool.tape_inlet_head_m'] = x.defaultInletHeadM;
  }
  final misc = values['tool.misc_spec'];
  if (misc != null && !values.containsKey('tool.misc_setting_m')) {
    final x = cat.valve('$misc');
    if (x != null) out['tool.misc_setting_m'] = math.max(0.0, x.defaultSettingM);
  }
  return out;
}
