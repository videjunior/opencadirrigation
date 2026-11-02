/// Conditional labels: rules that show a result of the design next to the
/// pipes, outlets or valves where it meets a condition (velocity above a
/// limit, pressure below the minimum…), in a colour of their own.
library;

import 'dart:math' as math;

import '../design/results.dart';
import '../units.dart';

class LabelRule {
  LabelRule({this.target = 'pipes', this.field = 'velocity', this.op = '>', this.value = 1.5, this.color = 0xFFFF5252, this.enabled = true});

  /// `pipes`, `outlets` or `valves`.
  String target;

  /// What is labelled: see [fieldsOf].
  String field;

  /// `>`, `<` or `any` (always), against [value] in SI (m/s, m³/s, m of
  /// head, m).
  String op;
  double value;
  int color;
  bool enabled;

  static const targets = ['pipes', 'outlets', 'valves'];

  /// The results each target can be labelled with.
  static List<String> fieldsOf(String target) => switch (target) {
    'outlets' => const ['pressure', 'flow'],
    'valves' => const ['flow', 'pressure', 'downstream'],
    _ => const ['velocity', 'flow', 'pressure', 'headLoss', 'diameter'],
  };

  bool holds(double v) => switch (op) {
    '>' => v > value,
    '<' => v < value,
    _ => true,
  };

  /// [v] (SI) in the display units, and the unit label.
  static (double, String) display(String field, double v, Units u) => switch (field) {
    'velocity' => (u.velocityFromSi(v), u.velocityLabel),
    'flow' => (u.flowFromSi(v), u.flowLabel),
    'diameter' => (u.diameterFromSi(v), u.diameterLabel),
    _ => (u.pressureFromHead(v), u.pressureLabel),
  };

  /// A value typed in the display units, in SI.
  static double toSi(String field, double v, Units u) => switch (field) {
    'velocity' => u.velocityToSi(v),
    'flow' => u.flowToSi(v),
    'diameter' => u.diameterToSi(v),
    _ => u.pressureToHead(v),
  };

  /// The value of [field] for the segments of a pipe: the largest velocity,
  /// flow, loss (summed) and bore, the lowest pressure.
  static double? ofPipe(String field, List<PipeSegmentResult> segs) {
    if (segs.isEmpty) return null;
    return switch (field) {
      'velocity' => segs.fold<double>(0, (m, s) => math.max(m, s.velocity)),
      'flow' => segs.fold<double>(0, (m, s) => math.max(m, s.flow.abs())),
      'headLoss' => segs.fold<double>(0, (m, s) => m + s.headLoss.abs()),
      'diameter' => segs.fold<double>(0, (m, s) => math.max(m, s.diameter)),
      _ => segs.fold<double>(double.infinity, (m, s) => math.min(m, math.min(s.pressureStart, s.pressureEnd))),
    };
  }

  /// The value of [field] for the emitters of an outlet entity (the lowest
  /// pressure, the total flow).
  static double? ofOutlet(String field, List<OutletResult> res) {
    if (res.isEmpty) return null;
    return field == 'flow' ? res.fold<double>(0, (m, r) => m + r.flow * r.count) : res.fold<double>(double.infinity, (m, r) => math.min(m, r.pressure));
  }

  /// The value of [field] for a zone valve.
  static double? ofValve(String field, ZoneResult? z) => z == null
      ? null
      : switch (field) {
          'flow' => z.totalFlow,
          'downstream' => z.downstreamHead,
          _ => z.requiredUpstreamHead,
        };

  Map<String, dynamic> toJson() => {'target': target, 'field': field, 'op': op, 'value': value, 'color': color, if (!enabled) 'off': true};
  static LabelRule fromJson(Map<String, dynamic> j) => LabelRule(
    target: j['target'] as String? ?? 'pipes',
    field: j['field'] as String? ?? 'velocity',
    op: j['op'] as String? ?? '>',
    value: (j['value'] as num?)?.toDouble() ?? 0,
    color: (j['color'] as num?)?.toInt() ?? 0xFFFF5252,
    enabled: j['off'] != true,
  );
}
