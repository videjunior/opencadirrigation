/// Mechanised-machine dialog of a centre pivot or linear move: the
/// sprinkler package, the drive train and timer, the corner arm, the
/// variable-rate prescription and the electrical supply, with every
/// analysis of `core/design/mechanised.dart` worked out again on each change
/// so the designer sees the nozzle chart, the timer chart and the messages
/// while typing. The machine data are edited on a copy; OK stores them as one
/// step of the history, Cancel leaves the pivot as it was.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/corner_arm.dart' show guidancePathFromBoundary;
import '../../../core/design/mechanised.dart';
import '../../../core/design/pivot.dart' show PivotKind;
import '../../../core/design/pivot_package.dart' show TowerDrive;
import '../../../core/design/vri.dart' show VriResult;
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/terrain.dart' show Terrain;
import '../../../core/units.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Writes a file the dialog produces (the prescription CSV): the browser
/// download or the desktop file dialog. A test replaces it to read the text.
Future<void> Function(String filename, String content, {String mime}) mechanisedFileSaver = saveTextFile;

/// Rolling diameter (m) of a farm tyre from the size printed on its
/// sidewall: section width and rim in inches ("11.2-38", "14.9x24",
/// "11.2R38") or the metric width/aspect and rim ("320/85R38"), with the
/// factors of [TowerDrive.tyreRollingDiameter]; null when the text is no tyre
/// size. The tyre maker's rolling circumference is better when known.
double? tyreRollingDiameterFromSize(String size) {
  final s = size.trim().replaceAll(',', '.').toUpperCase();
  final metric = RegExp(r'^(\d{3})\s*/\s*(\d{2,3})\s*(?:R|-|\s)?\s*(\d{2}(?:\.\d)?)$').firstMatch(s);
  if (metric != null) {
    final width = double.parse(metric[1]!), aspect = double.parse(metric[2]!), rim = double.parse(metric[3]!);
    return TowerDrive.tyreRollingDiameter(sectionWidthInch: width / 25.4, rimDiameterInch: rim, aspectRatio: aspect / 100);
  }
  final inch = RegExp(r'^(\d{1,2}(?:\.\d{1,2})?)\s*(?:-|X|×|R)\s*(\d{2}(?:\.\d)?)$').firstMatch(s);
  if (inch == null) return null;
  return TowerDrive.tyreRollingDiameter(sectionWidthInch: double.parse(inch[1]!), rimDiameterInch: double.parse(inch[2]!));
}

/// Opens the package, drive, corner arm, variable-rate and electrical data
/// of pivot [p]. OK commits the edited machine with one undo step
/// (`hist.pivotMachine`) when anything changed; Cancel discards the edits.
Future<void> showPivotMachineDialog(BuildContext context, ProjectController c, PivotEntity p) => showDialog<void>(
  context: context,
  builder: (_) => _PivotMachineDialog(c: c, pivot: p),
);

enum _Tab { package, drive, arm, vri, electrical }

const _tabKeys = {_Tab.package: 'mech.tab.package', _Tab.drive: 'mech.tab.drive', _Tab.arm: 'mech.cornerArm', _Tab.vri: 'mech.tab.vri', _Tab.electrical: 'mech.tab.electrical'};

/// The tab whose data cause message [code] (`pivot_pkg_*`, `corner_arm_*`, …).
_Tab _tabOf(String code) {
  if (code.startsWith('corner_arm_')) return _Tab.arm;
  if (code.startsWith('vri_')) return _Tab.vri;
  if (code.startsWith('pivot_elec_')) return _Tab.electrical;
  if (code == 'pivot_pkg_no_drive') return _Tab.drive;
  return _Tab.package;
}

/// Shapes [closedOutlineOf] accepts as a guide path or a prescription zone.
bool _closedShape(Entity e) => e is CircleEntity || (e is! PivotEntity && e.isClosedShape && (e.linearPoints?.length ?? 0) >= 3);

TextStyle get _hint => TextStyle(fontSize: 11.5, color: Cad.fg60);
TextStyle get _warnStyle => TextStyle(fontSize: 11.5, color: Cad.warning);

/// An explanation above a group of fields, with room for their floating labels.
Widget _hintText(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(s, style: _hint),
);

Widget _cell(String s, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(
    s,
    style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null, color: color),
  ),
);

/// A results table of a machine or field dialog that scrolls sideways when
/// it is wider than the dialog; [warn] rows in the warning colour, [bold]
/// rows emphasised. Every row needs as many cells as [headers].
Widget resultTable(List<String> headers, List<List<String>> rows, {List<bool>? warn, List<bool>? bold, Key? key}) => SingleChildScrollView(
  key: key,
  scrollDirection: Axis.horizontal,
  child: Table(
    defaultColumnWidth: const IntrinsicColumnWidth(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Cad.fg24)),
        ),
        children: [for (final h in headers) _cell(h, bold: true)],
      ),
      for (var i = 0; i < rows.length; i++)
        TableRow(
          children: [for (final s in rows[i]) _cell(s, bold: bold != null && bold[i], color: warn != null && warn[i] ? Cad.warning : null)],
        ),
    ],
  ),
);

/// Fields side by side, as many on a line as fit [minWidth] each, so the
/// same dialog works on a desktop and on a phone.
Widget fieldGrid(List<Widget> children, {double minWidth = 280}) => LayoutBuilder(
  builder: (context, box) {
    final per = math.max(1, math.min(children.length, (box.maxWidth / minWidth).floor()));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i += per)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + per; j++) ...[if (j > i) const SizedBox(width: 8), Expanded(child: j < children.length ? children[j] : const SizedBox.shrink())],
            ],
          ),
      ],
    );
  },
);

/// Translated lines of engine message codes (`traveller_lane_wide`,
/// `pivot_pkg_no_drive:e7`…), each once and without the entity id (the
/// dialog is about that entity); a quiet line when there is none.
List<Widget> messageLines(ProjectController c, Iterable<String> codes) {
  final seen = <String>{for (final w in codes) w.split(':').first};
  if (seen.isEmpty) return [Text(c.t('mech.noWarnings'), style: _hint)];
  return [
    for (final w in seen)
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('• ${c.t.warning(w)}', style: _warnStyle),
      ),
  ];
}

/// Two blocks beside each other on a wide dialog, one under the other on a narrow one.
Widget _sideBySide(Widget a, Widget b, {double breakWidth = 560}) => LayoutBuilder(
  builder: (context, box) => box.maxWidth < breakWidth
      ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 8), b])
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            b,
          ],
        ),
);

class _PivotMachineDialog extends StatefulWidget {
  const _PivotMachineDialog({required this.c, required this.pivot});
  final ProjectController c;
  final PivotEntity pivot;

  @override
  State<_PivotMachineDialog> createState() => _PivotMachineDialogState();
}

class _PivotMachineDialogState extends State<_PivotMachineDialog> {
  ProjectController get c => widget.c;
  PivotEntity get p => widget.pivot;
  Units get u => c.units;
  String t(String key, [Map<String, String>? args]) => c.t(key, args);

  /// The machine being edited: a copy, the pivot keeps its own until OK.
  late final PivotMachine m = p.machine.clone();

  /// The prescription comes from the zones (areas of the drawing) or from
  /// the sectors table; the other list is dropped on OK, so what the dialog
  /// shows is what the design computes. A machine without either starts
  /// with the zones when the drawing has shapes over the circle.
  late bool _zonesMode = m.vriZones.isNotEmpty || (m.vriSectors.isEmpty && _zoneShapes.isNotEmpty);

  /// The machine as the dialog opened it, to tell whether OK changes anything
  /// (taken in [initState], before the user can switch the prescription source).
  late final String _initial;

  @override
  void initState() {
    super.initState();
    _initial = jsonEncode(_effective(p.machine, _zonesMode).toJson());
  }

  /// Ground model for the worst ground rise around the circle, built once.
  late final Terrain? _terrain = () {
    final t = c.project.buildTerrain();
    return t.isEmpty ? null : t;
  }();

  /// Closed shapes of the drawing (guide paths) and those near the pivot (zones).
  late final List<Entity> _shapes = [
    for (final e in c.project.entities)
      if (_closedShape(e)) e,
  ];
  late final List<Entity> _zoneShapes = [
    for (final e in _shapes)
      if (e.bounds.intersects(p.bounds) || m.vriZones.containsKey(e.id)) e,
  ];

  /// Depths typed for zones that are unticked, kept for when they are ticked again.
  final Map<String, double> _zoneDepth = {};

  /// Stable keys of the sector rows (a deleted row does not hand its fields to the next).
  late final List<int> _sectorKeys = [for (var i = 0; i < m.vriSectors.length; i++) i];
  late int _nextSectorKey = m.vriSectors.length;

  var _tab = _Tab.package;
  final _tyre = TextEditingController();
  String? _tyreError;
  var _compass = false;

  @override
  void dispose() {
    _tyre.dispose();
    super.dispose();
  }

  static PivotMachine _effective(PivotMachine src, bool zonesMode) {
    final e = src.clone();
    if (zonesMode) {
      e.vriSectors.clear();
    } else {
      e.vriZones.clear();
    }
    return e;
  }

  /// Applies an edit; the dialog may be closing (a field committing on focus
  /// loss after OK), so the edit is kept even when nothing is redrawn.
  void _set(void Function() fn) {
    fn();
    if (mounted) setState(() {});
  }

  /// Switches tab after the field being typed in has committed its value
  /// (focus changes are applied in a microtask).
  void _goTab(_Tab tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.delayed(Duration.zero, () {
      if (mounted) setState(() => _tab = tab);
    });
  }

  void _ok() {
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.delayed(Duration.zero, () {
      final e = _effective(m, _zonesMode);
      if (jsonEncode(e.toJson()) == _initial) return;
      // the entity in the project now (the dialog may have been opened with an older copy)
      final live = c.project.byId(p.id);
      if (live is PivotEntity) c.mutate(() => live.machine = e, label: 'hist.pivotMachine');
    });
    Navigator.pop(context);
  }

  void _applyTyre() {
    final d = tyreRollingDiameterFromSize(_tyre.text);
    _set(() {
      _tyreError = d == null ? t('mech.tyreInvalid') : null;
      if (d != null) m.tyreRollingDiameterM = d;
    });
  }

  MechanisedResult _analyse() {
    final preview = p.clone()..machine = _effective(m, _zonesMode);
    final available = c.results?.pivots[p.id]?.availableHead ?? 0;
    return analyzeMechanised(c.project, preview, terrain: _terrain, availableInletHeadM: available > 0 ? available : 0);
  }

  // ---- formatting in the display units
  String _q(double q, {bool small = false}) => '${fmt(u.flowFromSi(q), flowDecimals(u, small: small))} ${u.flowLabel}';
  String _qn(double q, {bool small = false}) => fmt(u.flowFromSi(q), flowDecimals(u, small: small));
  String _p(double h) => '${fmt(u.pressureFromHead(h), _pressureDecimals(u))} ${u.pressureLabel}';
  String _pn(double h) => fmt(u.pressureFromHead(h), _pressureDecimals(u));
  String _len(double m, [int d = 1]) => '${fmt(u.lengthFromSi(m), d)} ${u.lengthLabel}';
  String _lenN(double m, [int d = 1]) => fmt(u.lengthFromSi(m), d);
  String _depth(double mm) => '${fmt(u.depthFromMm(mm), u.depthLabel == 'in' ? 2 : 1)} ${u.depthLabel}';
  String _depthN(double mm) => fmt(u.depthFromMm(mm), u.depthLabel == 'in' ? 2 : 1);
  String _area(double m2) => '${fmt(u.areaFromSi(m2), 2)} ${u.areaLabel}';
  String _withUnit(String key, String unit) => '${t(key)} ($unit)';

  String _shapeLabel(Entity e) {
    if (e.name.isNotEmpty) return e.name;
    final k = ProjectController.toolKeyOf(e);
    return k == 'select' ? e.id : '${t('tool.$k')} ${e.id}';
  }

  String get _pivotName => p.name.isNotEmpty ? p.name : (p.zoneName.isNotEmpty ? p.zoneName : t(p.kind == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'));

  @override
  Widget build(BuildContext context) {
    final r = _analyse();
    final byTab = <_Tab, List<String>>{};
    for (final w in r.warnings) {
      final code = w.split(':').first;
      final list = byTab.putIfAbsent(_tabOf(code), () => []);
      if (!list.contains(code)) list.add(code);
    }
    final width = dialogWidth(context, 940);
    final section = switch (_tab) {
      _Tab.package => _package(r),
      _Tab.drive => _drive(r),
      _Tab.arm => _arm(r),
      _Tab.vri => _vri(r),
      _Tab.electrical => _electrical(r),
    };
    final messages = byTab[_tab] ?? const <String>[];
    return AlertDialog(
      title: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('mech.dialogTitle', {'name': _pivotName}), style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tab in _Tab.values)
                  ChoiceChip(
                    key: Key('mech_tab_${tab.name}'),
                    avatar: (byTab[tab]?.isNotEmpty ?? false) && _tab != tab ? Icon(Icons.warning_amber_rounded, size: 16, color: Cad.warning) : null,
                    label: Text(t(_tabKeys[tab]!), style: const TextStyle(fontSize: 12)),
                    selected: _tab == tab,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _goTab(tab),
                  ),
              ],
            ),
          ],
        ),
      ),
      // the body scrolls by itself (ScrollBody): a scrollable AlertDialog asks its
      // content for intrinsic heights, which the LayoutBuilders of the fields and
      // of KV cannot give (an assertion on phones)
      scrollable: false,
      content: SizedBox(
        width: width,
        child: ScrollBody(
          key: ValueKey(_tab),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [...section, SectionTitle(t('rep.warnings')), ...messageLines(c, messages)]),
        ),
      ),
      actions: [
        TextButton(key: const Key('mech_cancel'), onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton(key: const Key('mech_ok'), onPressed: _ok, child: Text(t('ok'))),
      ],
    );
  }

  // ---------------------------------------------------------------- package

  List<Widget> _package(MechanisedResult r) {
    final pk = r.package;
    final cat = c.project.catalog;
    final pivot = p.kind == PivotKind.pivot;
    final sprinkler = cat.outlet(p.sprinklerSpecId);
    final catalogueNozzles = sprinkler != null && sprinkler.nozzles.isNotEmpty;
    final guns = cat.outlets.where((o) => o.enabled && o.kind == OutletKind.gun && o.nozzles.isNotEmpty).toList();
    final gunSpec = cat.outlet(m.endGunSpecId);
    final plugged = pk.outlets.length - pk.sprinklerCount;
    final available = c.results?.pivots[p.id]?.availableHead ?? 0;
    String nozzleOf(String id, int number, double mm) => id.isNotEmpty
        ? (sprinkler?.nozzles.where((n) => n.id == id).firstOrNull?.name ?? id)
        : (number > 0 ? '#$number (${fmt(u.diameterFromSi(mm / 1000), u.diameter == DiameterUnit.inch ? 3 : 2)} ${u.diameterLabel})' : '-');
    return [
      _hintText(t('mech.dialogHint')),
      SwitchListTile(
        key: const Key('mech_regulated'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('mech.regulated'), style: const TextStyle(fontSize: 12)),
        subtitle: Text(t('mech.regulatedHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
        value: m.regulated,
        onChanged: (v) => _set(() => m.regulated = v),
      ),
      fieldGrid([
        NumField(
          key: const Key('mech_nozzle_height'),
          label: _withUnit('mech.nozzleHeight', u.lengthLabel),
          value: u.lengthFromSi(m.nozzleHeightM),
          onChanged: (v) => _set(() => m.nozzleHeightM = math.max(0.0, u.lengthToSi(v))),
        ),
        NumField(
          key: const Key('mech_span_arch'),
          label: _withUnit('mech.spanArch', u.lengthLabel),
          value: u.lengthFromSi(m.spanArchM),
          onChanged: (v) => _set(() => m.spanArchM = math.max(0.0, u.lengthToSi(v))),
        ),
        NumField(
          key: const Key('mech_drop_bore'),
          label: _withUnit('mech.dropBore', u.diameterLabel),
          value: u.diameterFromSi(m.dropInnerMm / 1000),
          decimals: u.diameter == DiameterUnit.inch ? 3 : 1,
          onChanged: (v) => _set(() {
            final mm = u.diameterToSi(v) * 1000;
            if (mm > 0) m.dropInnerMm = mm;
          }),
        ),
      ]),
      fieldGrid([
        NumField(
          key: const Key('mech_nozzle_min'),
          label: t('mech.nozzleMin'),
          value: m.minNozzleNumber.toDouble(),
          decimals: 0,
          enabled: !catalogueNozzles,
          onChanged: (v) => _set(() => m.minNozzleNumber = v.round().clamp(1, 400)),
        ),
        NumField(
          key: const Key('mech_nozzle_max'),
          label: t('mech.nozzleMax'),
          value: m.maxNozzleNumber.toDouble(),
          decimals: 0,
          enabled: !catalogueNozzles,
          onChanged: (v) => _set(() => m.maxNozzleNumber = v.round().clamp(1, 400)),
        ),
      ]),
      Text(catalogueNozzles ? t('mech.catalogueNozzles', {'name': sprinkler.name}) : t('mech.nozzleSeriesHint'), style: _hint),
      SectionTitle(t('mech.endGun')),
      fieldGrid([
        SpecDropdown<String>(
          key: const Key('mech_gun'),
          label: t('mech.endGun'),
          value: m.endGun,
          items: const ['auto', 'none', 'fullCircle', 'corners'],
          labelOf: (k) => t('mech.gun.$k'),
          idOf: (k) => k,
          onChanged: (v) => _set(() => m.endGun = v ?? 'auto'),
        ),
        SpecDropdown<OutletSpec>(
          key: const Key('mech_gun_spec'),
          label: t('mech.gunSpec'),
          value: m.endGunSpecId,
          items: guns,
          labelOf: (o) => o.name,
          idOf: (o) => o.id,
          allowNull: true,
          onChanged: (v) => _set(() => m.endGunSpecId = v),
        ),
        NumField(
          key: const Key('mech_gun_radius'),
          label: _withUnit('mech.gunRadius', u.lengthLabel),
          value: u.lengthFromSi(m.endGunRadiusM),
          onChanged: (v) => _set(() => m.endGunRadiusM = math.max(0.0, u.lengthToSi(v))),
        ),
      ]),
      SwitchListTile(
        key: const Key('mech_booster'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('mech.gunBoosterOn'), style: const TextStyle(fontSize: 12)),
        value: m.endGunBooster,
        onChanged: (v) => _set(() => m.endGunBooster = v),
      ),
      KV(t('mech.gunFromPivot'), p.endGunFlow > 0 ? '${_q(p.endGunFlow)} · ${_p(p.endGunPressureM)}' : '-'),
      SectionTitle(t('mech.summary')),
      KV(t('rep.sprinklers'), '${pk.sprinklerCount}${plugged > 0 ? ' (${t('mech.pluggedCount', {'n': '$plugged'})})' : ''}'),
      KV(t('mech.systemFlow'), _q(pk.systemFlow)),
      KV(t('mech.qDesign'), _q(pk.designFlow)),
      KV(t('mech.qDeliveredTotal'), _q(pk.deliveredFlow), color: pk.designFlow > 0 && (pk.deliveredFlow / pk.designFlow - 1).abs() > 0.05 ? Cad.warning : null),
      KV(t(pivot ? 'mech.effectiveRadius' : 'mech.effectiveLength'), _len(pk.effectiveRadiusM)),
      KV(t('mech.lastTower'), _len(pk.lastTowerRadiusM)),
      KV(t('mech.inletRequired'), _p(pk.requiredInletHeadM)),
      if (available > 0) KV(t('mech.inletAvailable'), _p(available), color: available + 1e-6 >= pk.requiredInletHeadM ? Cad.ok : Cad.warning),
      KV(t('mech.frictionLoss'), _p(pk.frictionLossM)),
      KV(t('mech.endPressure'), _p(pk.endPressureM)),
      KV(t('mech.regulator'), pk.regulatorM > 0 ? '${_p(pk.regulatorM)}${pk.regulatorId.isNotEmpty ? ' · ${cat.valve(pk.regulatorId)?.name ?? pk.regulatorId}' : ''}' : t('mech.unregulated')),
      if (pk.endGunFlow > 0)
        KV(
          t('mech.gunFlow'),
          '${_q(pk.endGunFlow)}${pk.gunNozzle.isNotEmpty ? ' · ${gunSpec?.nozzles.where((n) => n.id == pk.gunNozzle).firstOrNull?.name ?? pk.gunNozzle}' : ''}${pk.gunRadiusM > 0 ? ' · R ${_len(pk.gunRadiusM)}' : ''}',
        ),
      if (pk.boosterHeadM > 0 || m.endGunBooster) KV(t('mech.booster'), '${_p(pk.boosterHeadM)} · ${fmt(pk.boosterPowerKw, 2)} kW'),
      if (pk.spans.isNotEmpty) ...[
        SectionTitle(t('reports.pivotSpans')),
        resultTable(
          [
            t('rep.span'),
            '${t('rep.rFrom')} (${u.lengthLabel})',
            '${t('rep.rTo')} (${u.lengthLabel})',
            t('rep.sprinklers'),
            '${t('mech.qRequired')} (${u.flowLabel})',
            '${t('mech.qDelivered')} (${u.flowLabel})',
            '${t('rep.innerDiam')} (${u.diameterLabel})',
            '${t('rep.pStart')} (${u.pressureLabel})',
            '${t('rep.pEnd')} (${u.pressureLabel})',
            '${t('rep.hf')} (${u.pressureLabel})',
          ],
          [
            for (final s in pk.spans)
              [
                s.overhang ? t('mech.overhang') : '${s.index}',
                _lenN(s.startM),
                _lenN(s.endM),
                '${s.outlets}',
                _qn(s.requiredFlow),
                _qn(s.deliveredFlow),
                fmt(u.diameterFromSi(s.pipeInnerMm / 1000), u.diameter == DiameterUnit.inch ? 2 : 0),
                _pn(s.pressureStartM),
                _pn(s.pressureEndM),
                fmt(u.pressureFromHead(s.frictionLossM), 2),
              ],
          ],
          key: const Key('mech_spans_table'),
        ),
      ],
      if (pk.outlets.isNotEmpty) ...[
        SectionTitle(t('reports.pivotPackageTable')),
        resultTable(
          [
            t('mech.outlet'),
            t('rep.span'),
            '${t('mech.distance')} (${u.lengthLabel})',
            '${t('mech.spacing')} (${u.lengthLabel})',
            '${t('mech.qRequired')} (${u.flowLabel})',
            '${t('mech.qDelivered')} (${u.flowLabel})',
            '${t('mech.pPipe')} (${u.pressureLabel})',
            '${t('mech.pNozzle')} (${u.pressureLabel})',
            '${t('mech.regulator')} (${u.pressureLabel})',
            t('mech.nozzle'),
            '${t('mech.drop')} (${u.lengthLabel})',
          ],
          [
            for (final o in pk.outlets)
              [
                '${o.number}',
                '${o.span}',
                _lenN(o.distanceM),
                o.plugged ? '-' : _lenN(o.spacingM, 2),
                o.plugged ? '-' : _qn(o.requiredFlow, small: true),
                o.plugged ? '-' : _qn(o.deliveredFlow, small: true),
                _pn(o.pipePressureM),
                o.plugged ? '-' : _pn(o.nozzlePressureM),
                o.regulatorM > 0 ? _pn(o.regulatorM) : '-',
                o.plugged ? t('mech.plugged') : nozzleOf(o.nozzle, o.nozzleNumber, o.nozzleDiameterMm),
                o.dropLengthM > 0 ? _lenN(o.dropLengthM, 2) : '-',
              ],
          ],
          warn: [for (final o in pk.outlets) !o.plugged && o.requiredFlow > 0 && (o.deliveredFlow / o.requiredFlow - 1).abs() > 0.05],
          key: const Key('mech_nozzle_chart'),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- drive and timer

  List<Widget> _drive(MechanisedResult r) {
    final pk = r.package;
    final hours = p.kind == PivotKind.pivot ? 'mech.hoursRev' : 'mech.hoursPass';
    final speedUnit = '${u.lengthLabel}/min';
    final setting = m.timerPct.clamp(1.0, 100.0).toDouble();
    return [
      _hintText(t('mech.driveHint')),
      fieldGrid([
        NumField(key: const Key('mech_rpm'), label: t('mech.motorRpm'), value: m.motorRpm, decimals: 0, onChanged: (v) => _set(() => m.motorRpm = math.max(0.0, v))),
        NumField(key: const Key('mech_gear_center'), label: t('mech.centerGear'), value: m.centerGearRatio, decimals: 1, onChanged: (v) => _set(() => m.centerGearRatio = math.max(0.0, v))),
        NumField(key: const Key('mech_gear_wheel'), label: t('mech.wheelGear'), value: m.wheelGearRatio, decimals: 1, onChanged: (v) => _set(() => m.wheelGearRatio = math.max(0.0, v))),
        NumField(
          key: const Key('mech_tyre_diameter'),
          label: _withUnit('mech.tyreDiameter', u.lengthLabel),
          value: u.lengthFromSi(m.tyreRollingDiameterM),
          decimals: 3,
          onChanged: (v) => _set(() => m.tyreRollingDiameterM = math.max(0.0, u.lengthToSi(v))),
        ),
      ], minWidth: 400),
      _sideBySide(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            key: const Key('mech_tyre_size'),
            controller: _tyre,
            decoration: InputDecoration(labelText: t('mech.tyreDesignation'), isDense: true, errorText: _tyreError),
            style: const TextStyle(fontSize: 12),
            onSubmitted: (_) => _applyTyre(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: OutlinedButton(key: const Key('mech_tyre_apply'), onPressed: _applyTyre, child: Text(t('mech.tyreApply'))),
        ),
        breakWidth: 460,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t('mech.tyreHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
      ),
      fieldGrid([
        NumField(
          key: const Key('mech_speed100'),
          label: '${t('mech.speed100Given')} ($speedUnit)',
          value: u.lengthFromSi(m.towerSpeedMPerMin),
          decimals: 2,
          onChanged: (v) => _set(() => m.towerSpeedMPerMin = math.max(0.0, u.lengthToSi(v))),
        ),
        NumField(key: const Key('mech_timer'), label: t('mech.timerSetting'), value: m.timerPct, decimals: 0, onChanged: (v) => _set(() => m.timerPct = v.clamp(1.0, 100.0).toDouble())),
        NumField(key: const Key('mech_timer_min'), label: t('mech.minTimer'), value: m.minTimerPct, decimals: 0, onChanged: (v) => _set(() => m.minTimerPct = v.clamp(1.0, 100.0).toDouble())),
      ]),
      SectionTitle(t('mech.summary')),
      KV(t('mech.speed100'), pk.speedAt100MPerMin > 0 ? '${fmt(u.lengthFromSi(pk.speedAt100MPerMin), 2)} $speedUnit' : '-', color: pk.speedAt100MPerMin > 0 ? null : Cad.warning),
      if (pk.speedAt100MPerMin > 0 && pk.hoursAt100 > 0) ...[
        KV('${t(hours)} (100 %)', '${fmt(pk.hoursAt100, 1)} h'),
        KV('${t('mech.depth')} (100 %)', _depth(pk.depthAt100Mm)),
        if (setting < 100) ...[
          KV('${t(hours)} (${fmt(setting, 0)} %)', '${fmt(pk.hoursAt100 * 100 / setting, 1)} h'),
          KV('${t('mech.depth')} (${fmt(setting, 0)} %)', _depth(pk.depthAtTimer(setting))),
        ],
        if (p.grossDepthMm > 0)
          KV(t('mech.timerForDepth', {'d': _depth(p.grossDepthMm)}), '${fmt(pk.timerForDepth(p.grossDepthMm), 0)} %', color: p.grossDepthMm < pk.depthAt100Mm - 1e-9 ? Cad.warning : null),
        SectionTitle(t('reports.pivotTimer')),
        resultTable(
          ['${t('mech.timer')} (%)', '${t(hours)} (h)', '${t('mech.depth')} (${u.depthLabel})', '${t('mech.speed')} ($speedUnit)'],
          [
            for (final row in pk.timer) [fmt(row.timerPct, 0), fmt(row.hours, 1), _depthN(row.depthMm), fmt(u.lengthFromSi(row.speedMPerMin), 2)],
          ],
          bold: [for (final row in pk.timer) (row.timerPct - setting).abs() < 1e-9],
          key: const Key('mech_timer_chart'),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- corner arm

  List<Widget> _arm(MechanisedResult r) {
    if (p.kind != PivotKind.pivot) return [Text(t('mech.armPivotOnly'), style: _hint)];
    final a = r.cornerArm;
    final boundary = closedOutlineOf(c.project, m.guidePathId);
    final guide = boundary == null ? null : (m.guideOffsetM.abs() > 1e-9 ? guidancePathFromBoundary(boundary, m.guideOffsetM) : boundary);
    final full = p.sectorDeg >= 360 - 1e-6;
    return [
      _hintText(t('mech.armHint')),
      fieldGrid([
        NumField(
          key: const Key('mech_arm_length'),
          label: _withUnit('mech.armLength', u.lengthLabel),
          value: u.lengthFromSi(m.cornerArmLengthM),
          onChanged: (v) => _set(() => m.cornerArmLengthM = math.max(0.0, u.lengthToSi(v))),
        ),
        NumField(
          key: const Key('mech_arm_overhang'),
          label: _withUnit('mech.armOverhang', u.lengthLabel),
          value: u.lengthFromSi(m.cornerArmOverhangM),
          onChanged: (v) => _set(() => m.cornerArmOverhangM = math.max(0.0, u.lengthToSi(v))),
        ),
        NumField(
          key: const Key('mech_arm_angle'),
          label: t('mech.armMaxAngle'),
          value: m.cornerArmMaxDeg,
          decimals: 0,
          onChanged: (v) => _set(() => m.cornerArmMaxDeg = v.clamp(0.0, 179.0).toDouble()),
        ),
        NumField(key: const Key('mech_arm_banks'), label: t('mech.armBanks'), value: m.cornerArmBanks.toDouble(), decimals: 0, onChanged: (v) => _set(() => m.cornerArmBanks = v.round().clamp(1, 30))),
      ], minWidth: 400),
      if (_shapes.isEmpty)
        Text(t('mech.noClosedShapes'), style: _warnStyle)
      else
        fieldGrid([
          SpecDropdown<Entity>(
            key: const Key('mech_guide'),
            label: t('mech.guidePath'),
            value: m.guidePathId,
            items: _shapes,
            labelOf: _shapeLabel,
            idOf: (e) => e.id,
            allowNull: true,
            onChanged: (v) => _set(() => m.guidePathId = v),
          ),
          NumField(
            key: const Key('mech_guide_offset'),
            label: _withUnit('mech.guideOffset', u.lengthLabel),
            value: u.lengthFromSi(m.guideOffsetM),
            onChanged: (v) => _set(() => m.guideOffsetM = u.lengthToSi(v)),
          ),
          SpecDropdown<bool>(
            key: const Key('mech_direction'),
            label: t('mech.direction'),
            value: '${m.clockwise}',
            items: const [false, true],
            labelOf: (v) => t(v ? 'mech.cw' : 'mech.ccw'),
            idOf: (v) => '$v',
            onChanged: (v) => _set(() => m.clockwise = v == 'true'),
          ),
        ]),
      if (a == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t('mech.armNeedsPath'), style: _hint),
        )
      else ...[
        SectionTitle(t('mech.summary')),
        _sideBySide(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KV(t('mech.totalArea'), _area(a.totalAreaM2)),
              KV(t('mech.armArea'), _area(a.armAreaM2)),
              KV(t('mech.addedArea'), _area(a.addedAreaM2)),
              KV(t('mech.mainFlow'), _q(a.mainFlow)),
              KV(t('mech.peakFlow'), _q(a.peakFlow)),
              KV(t('mech.peakPulsed'), _q(a.peakPulsedFlow)),
              KV(t('mech.minFlow'), _q(a.minFlow)),
              // a ratio of many times the tower speed is the tip jumping from one
              // stretch of the guide to another between two machine positions
              KV(t('mech.tipSpeed'), fmt(a.maxTipSpeedRatio, 2), color: a.maxTipSpeedRatio > 5 ? Cad.warning : null),
              KV(t('mech.shortfall'), _len(a.maxShortfallM), color: a.maxShortfallM > 0.5 ? Cad.warning : null),
              KV(t('mech.overrun'), _len(a.maxOverrunM), color: a.maxOverrunM > 0.5 ? Cad.warning : null),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('mech_arm_preview'),
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _ArmPainter(center: p.center, hingeRadius: r.package.lastTowerRadiusM, boundary: boundary ?? const [], guide: guide ?? const [], outline: a.outline, closedOutline: full),
                ),
              ),
              SizedBox(
                width: 220,
                child: Text(t('mech.armPreview'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
              ),
            ],
          ),
        ),
        SectionTitle(t('mech.banks')),
        resultTable(
          [t('mech.bank'), '${t('mech.bankStart')} (${u.lengthLabel})', '${t('mech.bankEnd')} (${u.lengthLabel})', '${t('mech.qDesign')} (${u.flowLabel})', '${t('mech.onTime')} (%)'],
          [
            for (final b in a.banks) ['${b.index + 1}', _lenN(b.startM), _lenN(b.endM), _qn(b.designFlow), fmt(b.onFraction * 100, 0)],
          ],
          key: const Key('mech_banks_table'),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- variable rate

  double _defaultDepth(double d100) => ((d100 > 0 ? d100 : p.grossDepthMm) * 10).round() / 10;

  String get _edgesText => m.vriBankEdgesM.map((e) => fmt(u.lengthFromSi(e), 1)).join('; ');

  List<Widget> _vri(MechanisedResult r) {
    if (p.kind != PivotKind.pivot) return [Text(t('mech.vriPivotOnly'), style: _hint)];
    final v = r.vri;
    final d100 = r.package.depthAt100Mm;
    return [
      _hintText(t('mech.vriHint')),
      fieldGrid([
        NumField(key: const Key('mech_vri_step'), label: t('mech.vriStep'), value: m.vriStepDeg, decimals: 1, onChanged: (x) => _set(() => m.vriStepDeg = x.clamp(0.5, 90.0).toDouble())),
        TextFieldRow(
          key: const Key('mech_vri_banks'),
          label: '${t('mech.vriBanks')} (${u.lengthLabel})',
          value: _edgesText,
          onChanged: (s) => _set(() {
            final edges = [
              for (final x in parseNumberRows(s).expand((row) => row))
                if (x > 0) u.lengthToSi(x),
            ]..sort();
            m.vriBankEdgesM
              ..clear()
              ..addAll(edges);
          }),
        ),
      ], minWidth: 300),
      const SizedBox(height: 4),
      SegmentedButton<bool>(
        key: const Key('mech_vri_mode'),
        segments: [
          ButtonSegment(value: true, label: Text(t('mech.vriZones'), style: const TextStyle(fontSize: 12))),
          ButtonSegment(value: false, label: Text(t('mech.vriSectors'), style: const TextStyle(fontSize: 12))),
        ],
        selected: {_zonesMode},
        onSelectionChanged: (s) => _set(() => _zonesMode = s.first),
      ),
      const SizedBox(height: 4),
      if (_zonesMode) ..._zones(d100) else ..._sectors(d100),
      SectionTitle(t('reports.vri')),
      if (d100 <= 0)
        Text(t('warn.vri_no_depth'), style: _warnStyle)
      else if (v == null)
        Text(t('mech.vriNone'), style: _hint)
      else ...[
        KV('${t('mech.depth')} (100 %)', _depth(v.depthAt100Mm)),
        KV(t('mech.maxDepth'), _depth(v.maxDepthMm)),
        KV(t('mech.vriControl'), v.bankEdgesM.length > 2 ? t('mech.zoneControl', {'n': '${v.bankEdgesM.length - 1}'}) : t('mech.speedControl')),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              key: const Key('mech_compass'),
              label: Text(t('mech.compass'), style: const TextStyle(fontSize: 11.5)),
              selected: _compass,
              onSelected: (on) => setState(() => _compass = on),
            ),
            OutlinedButton.icon(key: const Key('mech_csv'), onPressed: v.rows.isEmpty ? null : () => _saveCsv(v), icon: const Icon(Icons.download_outlined, size: 16), label: Text(t('mech.saveCsv'))),
          ],
        ),
        const SizedBox(height: 4),
        resultTable(
          [
            '${t('mech.start')} (°)',
            '${t('mech.end')} (°)',
            '${t('mech.timer')} (%)',
            '${t('mech.depth')} (${u.depthLabel})',
            '${t('mech.target')} (${u.depthLabel})',
            if (v.bankEdgesM.length > 2) '${t('mech.bankDuty')} (%)',
          ],
          [
            for (final row in v.rows)
              [
                fmt(row.startDeg, 1),
                fmt(row.endDeg, 1),
                fmt(row.timerPct, 0),
                _depthN(row.depthMm),
                _depthN(row.targetMm),
                if (v.bankEdgesM.length > 2) row.bankDutyPct.map((d) => fmt(d, 0)).join(' / '),
              ],
          ],
          warn: [for (final row in v.rows) row.limit != 0],
          key: const Key('mech_vri_table'),
        ),
      ],
    ];
  }

  List<Widget> _zones(double d100) {
    if (_zoneShapes.isEmpty) return [Text(t('mech.vriNoAreas'), style: _hint)];
    return [
      for (final e in _zoneShapes)
        Row(
          key: ValueKey('zone_${e.id}'),
          children: [
            Checkbox(
              key: Key('mech_zone_${e.id}'),
              value: m.vriZones.containsKey(e.id),
              onChanged: (on) => _set(() {
                if (on ?? false) {
                  m.vriZones[e.id] = _zoneDepth[e.id] ?? _defaultDepth(d100);
                } else {
                  final d = m.vriZones.remove(e.id);
                  if (d != null) _zoneDepth[e.id] = d;
                }
              }),
            ),
            Expanded(
              child: Text(_shapeLabel(e), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 170,
              child: NumField(
                key: Key('mech_zone_depth_${e.id}'),
                label: '${t('mech.target')} (${u.depthLabel})',
                value: u.depthFromMm(m.vriZones[e.id] ?? _zoneDepth[e.id] ?? _defaultDepth(d100)),
                enabled: m.vriZones.containsKey(e.id),
                onChanged: (x) => _set(() {
                  final mm = math.max(0.0, u.depthToMm(x));
                  if (m.vriZones.containsKey(e.id)) {
                    m.vriZones[e.id] = mm;
                  } else {
                    _zoneDepth[e.id] = mm;
                  }
                }),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _sectors(double d100) => [
    _hintText(t('mech.vriAnglesHint')),
    for (var i = 0; i < m.vriSectors.length; i++)
      Row(
        key: ValueKey('sector_${_sectorKeys[i]}'),
        children: [
          Expanded(
            child: NumField(
              key: Key('mech_sector_${_sectorKeys[i]}_start'),
              label: '${t('mech.start')} (°)',
              value: m.vriSectors[i].startDeg,
              decimals: 1,
              onChanged: (x) => _set(() => m.vriSectors[i] = VriSectorDepth(x, m.vriSectors[i].endDeg, m.vriSectors[i].depthMm)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumField(
              key: Key('mech_sector_${_sectorKeys[i]}_end'),
              label: '${t('mech.end')} (°)',
              value: m.vriSectors[i].endDeg,
              decimals: 1,
              onChanged: (x) => _set(() => m.vriSectors[i] = VriSectorDepth(m.vriSectors[i].startDeg, x, m.vriSectors[i].depthMm)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumField(
              key: Key('mech_sector_${_sectorKeys[i]}_depth'),
              label: '${t('mech.target')} (${u.depthLabel})',
              value: u.depthFromMm(m.vriSectors[i].depthMm),
              onChanged: (x) => _set(() => m.vriSectors[i] = VriSectorDepth(m.vriSectors[i].startDeg, m.vriSectors[i].endDeg, math.max(0.0, u.depthToMm(x)))),
            ),
          ),
          IconButton(
            tooltip: t('mech.removeSector'),
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: () => _set(() {
              m.vriSectors.removeAt(i);
              _sectorKeys.removeAt(i);
            }),
          ),
        ],
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('mech_sector_add'),
        onPressed: () => _set(() {
          // the next quarter after the last sector
          final start = m.vriSectors.isEmpty ? 0.0 : m.vriSectors.last.endDeg % 360;
          m.vriSectors.add(VriSectorDepth(start, math.min(start + 90, 360), _defaultDepth(d100)));
          _sectorKeys.add(_nextSectorKey++);
        }),
        icon: const Icon(Icons.add, size: 16),
        label: Text(t('mech.addSector')),
      ),
    ),
  ];

  Future<void> _saveCsv(VriResult v) {
    String safe(String s) => s.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return mechanisedFileSaver('${safe(c.project.meta.name)}_${safe(_pivotName)}_vri.csv', v.toCsv(compass: _compass), mime: 'text/csv');
  }

  // ---------------------------------------------------------------- electrical

  List<Widget> _electrical(MechanisedResult r) {
    final e = r.electrical;
    final runDrop = r.warnings.any((w) => w.startsWith('pivot_elec_drop')), startDrop = r.warnings.any((w) => w.startsWith('pivot_elec_start_drop'));
    return [
      _hintText(t('mech.elecHint')),
      fieldGrid([
        NumField(key: const Key('mech_volt'), label: t('mech.voltage'), value: m.voltage, decimals: 0, onChanged: (x) => _set(() => m.voltage = math.max(0.0, x))),
        NumField(key: const Key('mech_motor_kw'), label: t('mech.motorKw'), value: m.towerMotorKw, onChanged: (x) => _set(() => m.towerMotorKw = x > 0 ? x : m.towerMotorKw)),
        NumField(
          key: const Key('mech_supply_length'),
          label: _withUnit('mech.supplyLength', u.lengthLabel),
          value: u.lengthFromSi(m.supplyCableM),
          decimals: 0,
          onChanged: (x) => _set(() => m.supplyCableM = math.max(0.0, u.lengthToSi(x))),
        ),
        NumField(key: const Key('mech_supply_section'), label: t('mech.supplySection'), value: m.supplyCableMm2, decimals: 1, onChanged: (x) => _set(() => m.supplyCableMm2 = math.max(0.0, x))),
      ], minWidth: 400),
      if (e == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t('mech.elecOff'), style: _hint),
        )
      else ...[
        SectionTitle(t('mech.summary')),
        KV(t('mech.spanCable'), '${fmt(e.cableMm2, 1)} mm²'),
        if (m.supplyCableM > 0) KV(t('mech.supplyCable'), '${fmt(e.supplyCableMm2, 1)} mm² · ${_len(m.supplyCableM, 0)}'),
        KV(t('mech.motorCurrent'), '${fmt(e.motorCurrentA, 2)} A'),
        KV(t('mech.connected'), '${fmt(e.connectedKw, 2)} kW'),
        KV(t('mech.runningCurrent'), '${fmt(e.runningCurrentA, 1)} A · ${fmt(e.runningKva, 1)} kVA'),
        KV(t('mech.dropRun'), '${fmt(e.maxRunningDropPct, 2)} %', color: runDrop ? Cad.warning : Cad.ok),
        KV(t('mech.dropStart'), '${fmt(e.maxStartingDropPct, 2)} %', color: startDrop ? Cad.warning : Cad.ok),
        if (e.boosterMotorKw > 0) KV(t('mech.booster'), '${fmt(e.boosterShaftKw, 2)} → ${fmt(e.boosterMotorKw, 2)} kW · ${fmt(e.boosterCurrentA, 1)} A'),
        KV(t('mech.startingKva'), '${fmt(e.largestStartingKva, 1)} kVA'),
        KV(t('mech.generator'), '${fmt(e.generatorKva, 1)} kVA (≥ ${fmt(e.generatorKvaRequired, 1)} kVA)'),
        KV(t('mech.averagePower'), '${fmt(e.averagePowerKw, 2)} kW (${fmt(m.timerPct, 0)} %)'),
        SectionTitle(t('mech.towers')),
        resultTable(
          [
            t('mech.tower'),
            '${t('mech.distance')} (${u.lengthLabel})',
            '${t('mech.cableLength')} (${u.lengthLabel})',
            '${t('mech.current')} (A)',
            '${t('mech.volts')} (V)',
            '${t('mech.dropRun')} (%)',
            '${t('mech.dropStart')} (%)',
          ],
          [
            for (final tw in e.towers) ['${tw.index}', _lenN(tw.radiusM, 0), _lenN(tw.cableM, 0), fmt(tw.spanCurrentA, 1), fmt(tw.volts, 0), fmt(tw.runningDropPct, 2), fmt(tw.startingDropPct, 2)],
          ],
          key: const Key('mech_towers_table'),
        ),
      ],
    ];
  }
}

/// Decimals that keep a flow in the display unit readable: machine and
/// supply flows, or the [small] flows of single outlets and gates.
int flowDecimals(Units u, {bool small = false}) => switch (u.flow) {
  FlowUnit.lph => 0,
  FlowUnit.lpm => small ? 2 : 1,
  FlowUnit.lps => small ? 3 : 2,
  FlowUnit.m3h => small ? 3 : 1,
  FlowUnit.gpm => small ? 2 : 1,
};

int _pressureDecimals(Units u) => u.pressure == PressureUnit.bar ? 2 : 1;

/// Plan of the corner arm: the field outline, the guide path, the circle of
/// the last tower and the reach of the arm, fitted to the box (north up).
class _ArmPainter extends CustomPainter {
  _ArmPainter({required this.center, required this.hingeRadius, required this.boundary, required this.guide, required this.outline, required this.closedOutline});
  final Pt center;
  final double hingeRadius;
  final List<Pt> boundary, guide, outline;
  final bool closedOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final b = Bounds.ofPoints([...boundary, ...guide, ...outline, center + Pt(hingeRadius, hingeRadius), center - Pt(hingeRadius, hingeRadius)]);
    if (b.isEmpty || b.width <= 0 || b.height <= 0) return;
    final scale = math.min(size.width / b.width, size.height / b.height) * 0.94;
    final mid = b.center;
    Offset o(Pt q) => Offset(size.width / 2 + (q.x - mid.x) * scale, size.height / 2 - (q.y - mid.y) * scale);
    void poly(List<Pt> pts, Color color, double width, {bool close = true}) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(o(pts.first).dx, o(pts.first).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(o(q).dx, o(q).dy);
      }
      if (close) path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
    }

    poly(boundary, Cad.fg38, 1);
    poly(guide, Cad.warning, 1);
    canvas.drawCircle(
      o(center),
      hingeRadius * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Cad.fg24,
    );
    poly(outline, Cad.accent, 1.5, close: closedOutline);
    canvas.drawCircle(o(center), 2.5, Paint()..color = Cad.fg70);
  }

  @override
  bool shouldRepaint(_ArmPainter old) => true;
}
