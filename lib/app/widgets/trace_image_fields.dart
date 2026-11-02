/// 1.6.0 AUT (PRD-05): the panel of the tool that traces an outline on the
/// satellite image: what the outline becomes, the colour tolerance, the
/// blur and the detail (each traces the outline on show again from the
/// same pixels), what is on show, and the buttons that make it, drop it or
/// trace every field of the view — on a phone the way to do what Enter and
/// Esc do.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../theme.dart';
import '../tools/trace_image_tool.dart';
import 'fields.dart';

List<Widget> traceImageFields(ProjectController c) {
  final t = c.t;
  final s = TraceImageSession.of(c);
  return [
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t('hint.traceImage'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
    ),
    // a list, not segments: the names stay whole with large text on a phone
    SpecDropdown<TraceOutput>(
      key: const Key('wand_output'),
      label: t('wand.output'),
      value: s.output.name,
      items: TraceOutput.values,
      labelOf: (o) => t('wand.output.${o.name}'),
      idOf: (o) => o.name,
      onChanged: (v) {
        s.output = TraceOutput.values.byName(v ?? s.output.name);
        c.refresh();
      },
    ),
    NumField(
      key: const Key('wand_tolerance'),
      label: t('wand.tolerance'),
      value: s.tolerance ?? 0,
      decimals: 1,
      signed: false,
      onChanged: (v) {
        s.tolerance = v <= 0 ? null : v.clamp(1, 80).toDouble();
        s.retrace(c);
      },
    ),
    NumField(
      key: const Key('wand_blur'),
      label: t('wand.blur'),
      value: s.blurM,
      decimals: 1,
      signed: false,
      onChanged: (v) {
        s.blurM = v.clamp(0.2, 10).toDouble();
        s.retrace(c);
      },
    ),
    NumField(
      key: const Key('wand_detail'),
      label: t('wand.detail'),
      value: s.detailM ?? 0,
      signed: false,
      onChanged: (v) {
        s.detailM = v <= 0 ? null : v.clamp(0.05, 20).toDouble();
        s.retrace(c);
      },
    ),
    if (s.busy) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: LinearProgressIndicator(minHeight: 2)),
    if (s.preview != null)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(localizeUi(s.describe(c)), key: const Key('wand_summary'), style: const TextStyle(fontSize: 11.5)),
      ),
    if (s.fields.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(t('wand.fieldsFound', {'n': '${s.fields.length}'}), style: const TextStyle(fontSize: 11.5)),
      ),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilledButton.icon(
          key: const Key('wand_commit'),
          onPressed: s.hasPreview && !s.busy ? () => s.commit(c) : null,
          icon: const Icon(Icons.check, size: 16),
          label: Text(t('wand.commit')),
        ),
        OutlinedButton(key: const Key('wand_discard'), onPressed: s.hasPreview || s.busy ? () => s.discard(c) : null, child: Text(t('wand.discard'))),
        OutlinedButton.icon(
          key: const Key('wand_view'),
          onPressed: s.busy ? null : () => unawaited(s.traceView(c)),
          icon: const Icon(Icons.select_all, size: 16),
          label: Text(t('wand.view')),
        ),
      ],
    ),
  ];
}
