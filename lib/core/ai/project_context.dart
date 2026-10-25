/// Project data for the optional AI assistant: a compact, readable text of
/// the open project that the user reads before anything is sent, and the
/// read-only lookups the model may call when the user allows them.
///
/// Every number comes from what the program already computed — the report
/// tables, the advisor messages, the design results — so the assistant reads
/// exactly what the reports show, in the project units. The text is
/// deterministic for a given project state (the preview is what is sent)
/// and bounded, so a large drawing does not turn into a large bill.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../design/advisor.dart';
import '../design/report_tables.dart';
import '../design/results.dart';
import '../hydraulics/friction.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';

/// What the user may include, in the order the text presents it (the
/// selection first: when there is one, the question is usually about it).
enum ContextPart { project, selection, messages, results, materials, parameters, catalog }

/// Size of the context (characters): about four to six thousand tokens.
const defaultContextChars = 18000;

/// Share of the size each part may take when everything does not fit; a
/// part that needs less leaves the rest to the others.
const _weights = {
  ContextPart.project: 0.07,
  ContextPart.selection: 0.15,
  ContextPart.messages: 0.2,
  ContextPart.results: 0.3,
  ContextPart.materials: 0.1,
  ContextPart.parameters: 0.07,
  ContextPart.catalog: 0.11,
};

/// Everything the builder reads. The app fills it from the controller (the
/// cached report tables, the advisor list, its own message titles), so no
/// number is derived twice.
class ContextSource {
  ContextSource({required this.project, required this.labels, this.results, this.tables = const [], this.advice = const [], this.adviceTitle, this.selection = const [], this.siteLatLon, this.kindOf});
  final Project project;
  final ReportLabels labels;
  final DesignResults? results;

  /// The report tables of [results] (those that need no results otherwise).
  final List<ReportTable> tables;
  final List<Advice> advice;

  /// Title of a message as the Messages tab shows it (a plain default
  /// otherwise).
  final String Function(Advice a)? adviceTitle;

  /// Ids of the selected entities.
  final List<String> selection;

  /// Site position (latitude, longitude); rounded to about a kilometre.
  final (double, double)? siteLatLon;

  /// Translated kind of an entity ("Valve", "Zone pipe"…).
  final String Function(Entity e)? kindOf;

  Translate get t => labels.t;
  bool has(String key) => labels.has(key);
  Units get units => project.params.units;
  String kind(Entity e) => kindOf?.call(e) ?? e.type.name;

  ReportTable? table(String key) {
    for (final tb in tables) {
      if (tb.key == key) return tb;
    }
    return null;
  }

  String title(Advice a) {
    final custom = adviceTitle;
    if (custom != null) return custom(a);
    final base = has('check.${a.raw}') ? t('check.${a.raw}') : (has('warn.${a.raw}') ? t('warn.${a.raw}') : (has('adv.${a.code}.title') ? t('adv.${a.code}.title') : a.raw));
    final names = [for (final id in a.entityIds.take(3)) labels.name(id)];
    if (a.entityIds.length > 3) names.add('+${a.entityIds.length - 3}');
    final extra = [if (a.value.isNotEmpty) a.value, if (names.isNotEmpty) names.join(', ')].join(' · ');
    final head = a.context.isEmpty ? base : '${a.context}: $base';
    return extra.isEmpty ? head : '$head ($extra)';
  }
}

/// The text attached to a question.
class ProjectContext {
  const ProjectContext({required this.text, required this.parts, required this.truncated});
  static const empty = ProjectContext(text: '', parts: [], truncated: false);
  final String text;

  /// Parts that contributed text.
  final List<ContextPart> parts;

  /// A part was shortened to keep the size.
  final bool truncated;

  bool get isEmpty => text.isEmpty;
  int get approxTokens => estimateTokens(text);
}

/// Rough token count of [text] (no tokenizer offline): about four Latin
/// characters per token, fewer for other scripts. Shown with "≈".
int estimateTokens(String text) {
  var ascii = 0, other = 0, wide = 0;
  for (final r in text.runes) {
    if (r < 0x80) {
      ascii++;
    } else if (r < 0x2E80) {
      other++;
    } else {
      wide++;
    }
  }
  return (ascii / 4 + other / 2.5 + wide / 1.2).ceil();
}

/// Builds the context with the [parts] the user ticked, at most [maxChars]
/// characters (sections are shortened with a note when needed).
ProjectContext buildProjectContext(ContextSource s, {Set<ContextPart> parts = const {...ContextPart.values}, int maxChars = defaultContextChars}) {
  final sections = <(ContextPart, List<String>)>[];
  for (final p in ContextPart.values) {
    if (!parts.contains(p)) continue;
    final lines = switch (p) {
      ContextPart.project => _projectLines(s),
      ContextPart.selection => _selectionLines(s),
      ContextPart.messages => _messageLines(s),
      ContextPart.results => _resultLines(s),
      ContextPart.materials => _materialLines(s),
      ContextPart.parameters => _parameterLines(s),
      ContextPart.catalog => _catalogLines(s),
    };
    if (lines.isNotEmpty) sections.add((p, lines));
  }
  if (sections.isEmpty) return ProjectContext.empty;
  final header = [s.t('ai.ctx.header'), _unitsLine(s)];
  final budget = math.max(0, maxChars - _size(header) - 2 * sections.length);
  final caps = _allocate([for (final x in sections) _size(x.$2)], [for (final x in sections) _weights[x.$1]!], budget);
  var truncated = false;
  final out = <String>[...header];
  for (var i = 0; i < sections.length; i++) {
    final (lines, cut) = _clip(s, sections[i].$2, caps[i]);
    truncated |= cut;
    out
      ..add('')
      ..addAll(lines);
  }
  return ProjectContext(text: out.join('\n'), parts: [for (final x in sections) x.$1], truncated: truncated);
}

int _size(List<String> lines) => lines.fold(0, (a, l) => a + l.length + 1);

/// Splits [budget] among sections of [sizes] by [weights]; a section that
/// fits its share keeps everything and leaves the rest to the others.
List<int> _allocate(List<int> sizes, List<double> weights, int budget) {
  final caps = List.filled(sizes.length, 0);
  final open = <int>{for (var i = 0; i < sizes.length; i++) i};
  var left = budget.toDouble();
  while (open.isNotEmpty) {
    final total = open.fold(0.0, (a, i) => a + weights[i]);
    final fits = [
      for (final i in open)
        if (sizes[i] <= left * weights[i] / total) i,
    ];
    if (fits.isEmpty) {
      for (final i in open) {
        caps[i] = (left * weights[i] / total).floor();
      }
      break;
    }
    for (final i in fits) {
      caps[i] = sizes[i];
      left -= sizes[i];
      open.remove(i);
    }
  }
  return caps;
}

/// The first lines of [lines] that fit in [cap] characters, with a note of
/// what was left out.
(List<String>, bool) _clip(ContextSource s, List<String> lines, int cap) {
  if (_size(lines) <= cap) return (lines, false);
  final out = <String>[];
  var used = 0;
  const reserve = 80;
  for (final l in lines) {
    if (used + l.length + 1 > cap - reserve) break;
    out.add(l);
    used += l.length + 1;
  }
  out.add(s.t('ai.ctx.cut', {'n': '${lines.length - out.length}'}));
  return (out, true);
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _short(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1)}…';

String _two(int v) => v.toString().padLeft(2, '0');

String _when(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String _hours(double h) {
  final hh = h.floor(), mm = ((h - hh) * 60).round();
  return mm == 60 ? '${hh + 1}:00' : '$hh:${_two(mm)}';
}

String _unitsLine(ContextSource s) {
  final u = s.units;
  final t = s.t;
  return '${t('ai.ctx.units')}: ${t('ai.ctx.flow')} ${u.flowLabel} · ${t('ai.ctx.pressure')} ${u.pressureLabel} · ${t('ai.ctx.length')} ${u.lengthLabel} · ${t('ai.ctx.diameter')} ${u.diameterLabel} · ${t('ai.ctx.velocity')} ${u.velocityLabel} · ${t('ai.ctx.area')} ${u.areaLabel} · ${t('ai.ctx.currency')} ${s.project.params.currency}';
}

// ---------------------------------------------------------------- tables

/// A report cell as text.
String cellText(Object? c) => switch (c) {
  null => '',
  String v => _oneLine(v),
  RNum v => v.toString(),
  double v => fmt(v, 2),
  _ => '$c',
};

/// A report table as text: the header row, one line per row (`⚠` marks the
/// rows the reports highlight), columns empty in every row left out. Over
/// [maxRows] the highlighted rows are kept first, in table order.
List<String> tableLines(ContextSource s, ReportTable tb, {int maxRows = 40, bool flaggedOnly = false, bool Function(List<Object> row)? where, bool heading = true}) {
  var idx = [
    for (var i = 0; i < tb.rows.length; i++)
      if ((!flaggedOnly || tb.warn[i]) && (where == null || where(tb.rows[i]))) i,
  ];
  final total = idx.length;
  if (total == 0) return const [];
  if (idx.length > maxRows) {
    final keep = <int>{...idx.where((i) => tb.warn[i]).take(maxRows)};
    for (final i in idx) {
      if (keep.length >= maxRows) break;
      keep.add(i);
    }
    idx = [
      for (final i in idx)
        if (keep.contains(i)) i,
    ];
  }
  String at(int row, int col) => col < tb.rows[row].length ? cellText(tb.rows[row][col]) : '';
  final cols = [
    for (var c = 0; c < tb.headers.length; c++)
      if (idx.any((i) {
        final v = at(i, c);
        return v.isNotEmpty && v != '-';
      }))
        c,
  ];
  final out = <String>[
    if (heading) '### ${tb.title}',
    [for (final c in cols) _oneLine(tb.headers[c])].join(' | '),
    for (final i in idx) '${tb.warn[i] ? '⚠ ' : ''}${[for (final c in cols) at(i, c)].join(' | ')}',
  ];
  if (total > idx.length) out.add(s.t('ai.ctx.moreRows', {'n': '${total - idx.length}'}));
  return out;
}

// ---------------------------------------------------------------- project

/// Kinds counted in the project summary (the drawing aids are left out).
bool _counted(Entity e) => switch (e) {
  PipeEntity _ ||
  SpraylineEntity _ ||
  TapeEntity _ ||
  OutletEntity _ ||
  ControlValveEntity _ ||
  WaterSupplyEntity _ ||
  PumpEntity _ ||
  MiscHydraulicEntity _ ||
  PivotEntity _ ||
  AreaEntity _ ||
  ControllerEntity _ ||
  WireEntity _ ||
  ContourEntity _ ||
  SpotHeightEntity _ => true,
  _ => false,
};

List<String> _projectLines(ContextSource s) {
  final t = s.t;
  final m = s.project.meta;
  final out = ['## ${t('ai.ctx.project')}'];
  void kv(String key, String v) {
    final x = _oneLine(v);
    if (x.isNotEmpty) out.add('${t(key)}: ${_short(x, 200)}');
  }

  kv('ai.ctx.name', m.name);
  kv('ai.ctx.client', m.client);
  kv('ai.ctx.site', m.site);
  kv('ai.ctx.designer', m.designer);
  final ll = s.siteLatLon;
  if (ll != null) out.add('${t('ai.ctx.location')}: ${fmt(ll.$1, 2)}, ${fmt(ll.$2, 2)}');
  if (m.notes.trim().isNotEmpty) out.add('${t('ai.ctx.notes')}: ${_short(_oneLine(m.notes), 600)}');
  final counts = <String, int>{};
  for (final e in s.project.entities) {
    if (!_counted(e)) continue;
    final k = s.kind(e);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  if (counts.isNotEmpty) out.add('${t('ai.ctx.drawing')}: ${[for (final e in counts.entries) '${e.value} × ${e.key}'].join(' · ')}');
  final flows = s.project.systemFlows;
  if (flows.isNotEmpty) {
    out.add('${t('ai.ctx.flows')}:');
    for (final f in flows.take(20)) {
      final zones = <String>[];
      for (final id in f.valveIds) {
        final e = s.project.byId(id);
        zones.add(switch (e) {
          ControlValveEntity v when v.zoneName.isNotEmpty => v.zoneName,
          null => id,
          _ => s.labels.name(id),
        });
      }
      final list = zones.length > 12 ? '${zones.take(12).join(', ')}, +${zones.length - 12}' : zones.join(', ');
      out.add('- ${t('ai.ctx.flowLine', {'n': _oneLine(f.name), 'z': list, 's': _hours(f.startHour), 'd': fmt(f.durationHours, 2)})}');
    }
    if (flows.length > 20) out.add(t('ai.ctx.moreRows', {'n': '${flows.length - 20}'}));
  }
  final r = s.results;
  out.add('${t('ai.ctx.results')}: ${r == null ? t('ai.ctx.notDesigned') : t('ai.ctx.designedAt', {'d': _when(r.timestamp), 'm': r.method.isEmpty ? '-' : r.method})}');
  return out;
}

// ---------------------------------------------------------------- parameters

List<String> _parameterLines(ContextSource s) {
  final t = s.t;
  final p = s.project.params;
  String yes(bool v) => t(v ? 'ai.ctx.yes' : 'ai.ctx.no');
  String n(double v, [int d = 2]) => fmt(v, d);
  final friction = t(switch (p.frictionMethod) {
    FrictionMethod.hazenWilliams => 'dlg.hw',
    FrictionMethod.darcyWeisbach => 'dlg.dw',
    FrictionMethod.scobey => 'dlg.scobey',
    FrictionMethod.manning => 'dlg.manning',
  });
  final minor = p.minorLossMethod == MinorLossMethod.percent ? '${t('dlg.minorByPct')} (${t('dlg.minorPct')}: ${n(p.minorLossPct, 1)})' : t('dlg.minorByFittings');
  return [
    '## ${t('ai.ctx.parameters')}',
    '${t('dlg.frictionFormula')}: $friction · ${t('dlg.waterTemp')}: ${n(p.waterTempC, 1)}',
    '${t('dlg.applyMinor')}: ${yes(p.applyMinorLosses)} · ${t('dlg.minorMethod')}: $minor',
    '${t('dlg.vLateral')}: ${n(p.maxLateralVelocity)} · ${t('dlg.vZone')}: ${n(p.maxZoneVelocity)} · ${t('dlg.vMain')}: ${n(p.maxMainlineVelocity)}',
    '${t('dlg.zoneVar')}: ${n(p.maxZoneVariationPct, 1)}',
    '${t('dlg.sizingMethod')}: ${t(p.sizingMethod == SizingMethod.lp ? 'dlg.lp' : 'dlg.greedy')}',
    '${t('dlg.maxLateralSizes')}: ${p.maxLateralSizes} · ${t('dlg.maxSubmainSizes')}: ${p.maxSubmainSizes} · ${t('dlg.maxMainlineSizes')}: ${p.maxMainlineSizes}',
    '${t('dlg.interest')}: ${n(p.interestRate, 3)} · ${t('dlg.term')}: ${p.termYears} · ${t('dlg.energyCost', {'c': p.currency})}: ${n(p.powerCostPerKwh, 3)} · ${t('dlg.pumpEff')}: ${n(p.pumpEfficiency)}',
    '${t('dlg.hoursMain')}: ${n(p.hoursPerYear, 0)} · ${t('dlg.hoursZone')}: ${n(p.zoneHoursPerYear, 0)} · ${t('dlg.tradeCapital')}: ${yes(p.tradeCapitalVsRunning)}',
    '${t('dlg.flushV')}: ${n(p.flushingVelocity)} · ${t('dlg.flushH')}: ${n(p.flushingMinEndHeadM, 1)}',
    '${t('dlg.checkSurge')}: ${yes(p.checkSurge)} · ${t('dlg.closure')}: ${n(p.valveClosureTimeS, 1)}',
    '${t('dlg.connectTol')}: ${n(p.connectTolerance, 3)}',
  ];
}

// ---------------------------------------------------------------- catalogue

List<String> _catalogLines(ContextSource s) {
  final t = s.t;
  final u = s.units;
  final cat = s.project.catalog;
  final pipes = <String>{}, outlets = <(String, String?)>{}, tapes = <String>{}, valves = <String>{}, pumps = <String>{};
  for (final e in s.project.entities) {
    switch (e) {
      case PipeEntity p when p.pipeSpecId != null:
        pipes.add(p.pipeSpecId!);
      case SpraylineEntity l:
        if (l.pipeSpecId != null) pipes.add(l.pipeSpecId!);
        outlets.add((l.outletSpecId, l.nozzleId));
      case OutletEntity o:
        outlets.add((o.outletSpecId, o.nozzleId));
      case TapeEntity tp:
        tapes.add(tp.tapeSpecId);
      case ControlValveEntity v when v.valveSpecId != null:
        valves.add(v.valveSpecId!);
      case MiscHydraulicEntity m when m.valveSpecId != null:
        valves.add(m.valveSpecId!);
      case PumpEntity p when p.pumpSpecId != null:
        pumps.add(p.pumpSpecId!);
      default:
        break;
    }
  }
  // the sizes the design chose for computer-sized pipes
  final r = s.results;
  if (r != null) {
    for (final z in r.zones.values) {
      for (final p in z.pipes) {
        if (p.pipeSpecId != null) pipes.add(p.pipeSpecId!);
      }
    }
    for (final f in r.systemFlows) {
      for (final p in f.pipes) {
        if (p.pipeSpecId != null) pipes.add(p.pipeSpecId!);
      }
    }
  }
  const maxItems = 15;
  final cur = s.project.params.currency;
  final out = <String>[];
  void group(String key, List<String> items) {
    if (items.isEmpty) return;
    out.add('${t(key)}:');
    out.addAll([for (final i in items.take(maxItems)) '- $i']);
    if (items.length > maxItems) out.add(t('ai.ctx.moreRows', {'n': '${items.length - maxItems}'}));
  }

  String p(double head) => '${fmt(u.pressureFromHead(head), 1)} ${u.pressureLabel}';
  group('ai.ctx.cat.pipes', [
    for (final id in pipes)
      if (cat.pipe(id) case final x?)
        '${x.name}: ${t('rep.innerDiam')} ${fmt(u.diameterFromSi(x.innerDiameterMm / 1000), 1)} ${u.diameterLabel}, ${t('rep.pn')} ${p(x.pressureRatingM)}, ${x.material.label}, C ${fmt(x.hazenC, 0)}, ${fmt(x.costPerM, 2)} $cur/m',
  ]);
  group('ai.ctx.cat.emitters', [
    for (final (id, nz) in outlets)
      if (cat.outlet(id) case final o?)
        if (o.nozzle(nz) case final n?)
          '${o.name} · ${n.name} (${o.kind.name}): ${p(n.minHeadM)} – ${p(n.maxHeadM)}, ${t('ai.ctx.nominal')} ${p(n.defaultHeadM)} → ${fmt(u.flowFromSi(n.curve.flow(n.defaultHeadM)), 2)} ${u.flowLabel}${n.curve.isPressureCompensating ? ', PC' : ''}'
        else
          '${o.name} (${o.kind.name})',
  ]);
  group('ai.ctx.cat.tapes', [
    for (final id in tapes)
      if (cat.tape(id) case final x?)
        '${x.name}: ${t('rep.innerDiam')} ${fmt(u.diameterFromSi(x.innerDiameterMm / 1000), 1)} ${u.diameterLabel}, ${t('ai.ctx.spacing')} ${fmt(u.lengthFromSi(x.emitterSpacingM), 2)} ${u.lengthLabel}, ${p(x.minHeadM)} – ${p(x.maxHeadM)}, ${t('ai.ctx.nominal')} ${fmt(u.flowFromSi(x.emitter.flow(x.defaultInletHeadM)), 2)} ${u.flowLabel}${x.emitter.isPressureCompensating ? ', PC' : ''}',
  ]);
  group('ai.ctx.cat.valves', [
    for (final id in valves)
      if (cat.valve(id) case final x?)
        '${x.name} (${x.kind.name}, ${fmt(x.sizeMm, 0)} mm): ${fmt(u.flowFromSi(x.minFlow), 1)} – ${fmt(u.flowFromSi(x.maxFlow), 1)} ${u.flowLabel}, ${fmt(x.cost, 2)} $cur',
  ]);
  group('ai.ctx.cat.pumps', [
    for (final id in pumps)
      if (cat.pump(id) case final x?)
        '${x.name}: ${fmt(u.flowFromSi(x.minFlow), 1)} – ${fmt(u.flowFromSi(x.maxFlow), 1)} ${u.flowLabel}, η ${fmt(x.efficiency, 2)}${x.powerKw > 0 ? ', ${fmt(x.powerKw, 1)} kW' : ''}${x.submersible ? ', ${t('rep.submersible')}' : ''}, ${fmt(x.cost, 2)} $cur',
  ]);
  return out.isEmpty ? const [] : ['## ${t('ai.ctx.catalog')}', ...out];
}

// ---------------------------------------------------------------- results

List<String> _resultLines(ContextSource s) {
  final r = s.results;
  if (r == null) return const [];
  final t = s.t;
  final out = ['## ${t('ai.ctx.resultsTitle')}'];
  for (final key in ['zones', 'mainline', 'devices', 'pivots']) {
    final tb = s.table(key);
    if (tb != null) out.addAll(tableLines(s, tb, maxRows: key == 'zones' ? 60 : 30));
  }
  final pipes = s.table('pipes');
  if (pipes != null) {
    final flagged = pipes.warn.where((w) => w).length;
    out.add('### ${pipes.title}');
    out.add(t('ai.ctx.pipesFlagged', {'n': '$flagged', 'm': '${pipes.rows.length}'}));
    if (flagged > 0) out.addAll(tableLines(s, pipes, maxRows: 20, flaggedOnly: true, heading: false));
  }
  // checks that only matter when something fails
  for (final key in ['flushing', 'surge', 'electrical']) {
    final tb = s.table(key);
    if (tb != null) out.addAll(tableLines(s, tb, maxRows: 15, flaggedOnly: true));
  }
  return out;
}

// ---------------------------------------------------------------- messages

List<String> _messageLines(ContextSource s) {
  final t = s.t;
  final advice = s.advice;
  final out = ['## ${t('ai.ctx.messages')}'];
  if (advice.isEmpty) {
    out.add(s.results == null ? t('adv.noneYet') : t('adv.none'));
    return out;
  }
  int count(AdviceLevel l) => advice.where((a) => a.level == l).length;
  out.add(t('ai.ctx.msgCounts', {'e': '${count(AdviceLevel.error)}', 'w': '${count(AdviceLevel.warning)}', 'i': '${count(AdviceLevel.info)}'}));
  if (s.results == null) out.add(t('adv.runHint'));
  const maxMessages = 30;
  final reach = fmt(connectReach(s.project), 1);
  final explained = <String>{};
  for (final a in advice.take(maxMessages)) {
    out.add('- ${t('ai.ctx.lvl.${a.level.name}')} [${a.code}] ${_oneLine(s.title(a))}');
    // the explanation once per kind of problem, as the Messages tab does
    if (explained.add(a.code)) {
      if (s.has('adv.${a.code}.why')) out.add('  ${t('adv.why')}: ${_oneLine(t('adv.${a.code}.why'))}');
      if (s.has('adv.${a.code}.how')) out.add('  ${t('adv.how')}: ${_oneLine(t('adv.${a.code}.how'))}');
    }
    final fixes = [
      for (final k in a.fixes)
        if (s.has('fix.${k.name}')) t('fix.${k.name}', {'d': reach}),
    ];
    if (fixes.isNotEmpty) out.add('  ${t('ai.ctx.fixes')}: ${fixes.join('; ')}');
  }
  if (advice.length > maxMessages) out.add(t('ai.ctx.moreRows', {'n': '${advice.length - maxMessages}'}));
  return out;
}

// ---------------------------------------------------------------- materials

List<String> _materialLines(ContextSource s) {
  final r = s.results;
  if (r == null || r.bom.isEmpty) return const [];
  final t = s.t;
  final cur = s.project.params.currency;
  String money(double v) => '${fmt(v, 2)} $cur';
  final out = [
    '## ${t('ai.ctx.materials')}',
    '${t('rep.totalRow')}: ${money(r.capitalCost)} · ${t('rep.annualCapital')}: ${money(r.annualCapitalCost)} · ${t('rep.annualEnergy')}: ${money(r.annualEnergyCost)} · ${t('rep.annualTotal')}: ${money(r.annualCapitalCost + r.annualEnergyCost)}',
  ];
  final byCat = <String, (double, int)>{};
  for (final l in r.bom) {
    final c = s.labels.category(l.category);
    final (sum, n) = byCat[c] ?? (0.0, 0);
    byCat[c] = (sum + l.total, n + 1);
  }
  out.add('${t('ai.ctx.byCategory')}: ${[for (final e in byCat.entries) '${e.key} ${money(e.value.$1)} (${e.value.$2})'].join(' · ')}');
  final top = [...r.bom]..sort((a, b) => b.total != a.total ? b.total.compareTo(a.total) : a.description.compareTo(b.description));
  final priced = top.where((l) => l.total > 0).take(12).toList();
  if (priced.isNotEmpty) {
    out.add('${t('ai.ctx.topItems')}:');
    for (final l in priced) {
      out.add('- ${_oneLine(l.description)}: ${fmt(l.quantity, 1)} ${l.unit} × ${fmt(l.unitCost, 2)} = ${money(l.total)}');
    }
  }
  final unpriced = r.bom.where((l) => l.unitCost <= 0).length;
  if (unpriced > 0) out.add(t('ai.ctx.unpriced', {'n': '$unpriced'}));
  return out;
}

// ---------------------------------------------------------------- items

const _maxSelection = 8;

List<String> _selectionLines(ContextSource s) {
  final ents = [for (final id in s.selection) ?s.project.byId(id)];
  if (ents.isEmpty) return const [];
  final out = [
    '## ${s.t('ai.ctx.selection', {'n': '${ents.length}'})}',
  ];
  for (final e in ents.take(_maxSelection)) {
    out.addAll(itemLines(s, e, maxRows: 12));
  }
  if (ents.length > _maxSelection) out.add(s.t('ai.ctx.moreRows', {'n': '${ents.length - _maxSelection}'}));
  return out;
}

/// Numbers of the raw properties kept short (four significant digits below
/// one, three decimals above).
Object? _round(Object? v) => switch (v) {
  double d when d.isFinite => d.abs() >= 1 ? double.parse(d.toStringAsFixed(3)) : double.parse(d.toStringAsPrecision(4)),
  Map m => {for (final e in m.entries) e.key: _round(e.value)},
  List l => [for (final x in l) _round(x)],
  _ => v,
};

/// Properties of [e] as stored in the project file (SI units), without the
/// geometry: point lists become a count and a length.
Map<String, Object?> _props(Entity e) {
  final j = Map<String, Object?>.of(e.toJson())..removeWhere((k, _) => const {'type', 'id', 'layer', 'name', 'data'}.contains(k));
  final pts = e.linearPoints;
  if (j['pts'] is List && pts != null) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).length;
    }
    j['pts'] = '${pts.length} vertices, ${fmt(len, 1)} m';
  }
  for (final k in const ['p', 'a', 'b', 'c', 'v']) {
    if (j[k] is List) j.remove(k);
  }
  return {for (final e in j.entries) e.key: _round(e.value)};
}

/// Names under which the reports list [e] (its name, the zone of a valve).
Set<String> _namesOf(ContextSource s, Entity e) => {s.labels.name(e.id), if (e.name.isNotEmpty) e.name, if (e is ControlValveEntity && e.zoneName.isNotEmpty) e.zoneName};

/// One item: what it is, its properties and the report rows that name it.
List<String> itemLines(ContextSource s, Entity e, {int maxRows = 12}) {
  final t = s.t;
  final name = s.labels.name(e.id);
  final names = _namesOf(s, e);
  bool mentions(List<Object> row) => row.any((c) => c is String && (names.contains(c) || names.any((n) => c.endsWith(': $n'))));
  final out = <String>['### ${s.kind(e)} «$name» (id ${e.id}, ${e.layer})', '${t('ai.ctx.props')}: ${jsonEncode(_props(e))}'];
  var rows = 0;
  for (final key in const ['zones', 'mainline', 'devices', 'pivots', 'pivotSpans', 'pipes', 'outlets', 'surge', 'flushing', 'electrical']) {
    if (rows >= 3 * maxRows) break;
    final tb = s.table(key);
    if (tb == null) continue;
    final lines = tableLines(s, tb, maxRows: maxRows, where: mentions, heading: false);
    if (lines.isEmpty) continue;
    out.add('${tb.title}:');
    out.addAll(lines);
    rows += lines.length - 1;
  }
  return out;
}
