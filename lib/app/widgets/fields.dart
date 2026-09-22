import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/units.dart';

/// Numeric text field that commits on submit / focus loss.
class NumField extends StatefulWidget {
  const NumField({super.key, required this.label, required this.value, required this.onChanged, this.suffix, this.decimals = 2, this.enabled = true, this.width});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final int decimals;
  final bool enabled;
  final double? width;

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));
  final _focus = FocusNode();

  String _fmt(double v) => v.isFinite ? (v == v.roundToDouble() && widget.decimals <= 2 ? v.toStringAsFixed(v.abs() < 1e-9 ? 0 : (widget.decimals == 0 ? 0 : 1)) : v.toStringAsFixed(widget.decimals)) : '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant NumField old) {
    super.didUpdateWidget(old);
    if (_focus.hasFocus) return;
    final text = _fmt(widget.value);
    if (_c.text == text) return;
    // a new value, or the one typed was not taken (clamped, rejected): show
    // what the model holds instead of the number typed
    final shown = parseNumber(_c.text);
    final tolerance = 0.5 * math.pow(10, -widget.decimals) + 1e-12;
    if (old.value != widget.value || shown == null || (shown - widget.value).abs() > tolerance) _c.text = text;
  }

  void _commit() {
    final v = parseNumber(_c.text);
    if (v == null) {
      // not a number: back to the value in force
      _c.text = _fmt(widget.value);
      return;
    }
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = TextField(
      controller: _c,
      focusNode: _focus,
      enabled: widget.enabled,
      decoration: InputDecoration(labelText: widget.label, suffixText: widget.suffix, isDense: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onSubmitted: (_) => _commit(),
      style: const TextStyle(fontSize: 12),
    );
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: widget.width != null ? SizedBox(width: widget.width, child: f) : f);
  }
}

class TextFieldRow extends StatefulWidget {
  const TextFieldRow({super.key, required this.label, required this.value, required this.onChanged, this.maxLines = 1});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<TextFieldRow> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _c.text != widget.value) widget.onChanged(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant TextFieldRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextField(
      controller: _c,
      focusNode: _focus,
      maxLines: widget.maxLines,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      onSubmitted: widget.onChanged,
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class SpecDropdown<T> extends StatelessWidget {
  const SpecDropdown({super.key, required this.label, required this.value, required this.items, required this.labelOf, required this.idOf, required this.onChanged, this.allowNull = false, this.nullLabel = '—'});
  final String label;
  final String? value;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T) idOf;
  final ValueChanged<String?> onChanged;
  final bool allowNull;
  final String nullLabel;

  @override
  Widget build(BuildContext context) {
    final ids = items.map(idOf).toSet();
    final v = value != null && ids.contains(value) ? value : (allowNull ? null : (items.isEmpty ? null : idOf(items.first)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String?>(
        isExpanded: true,
        initialValue: v,
        decoration: InputDecoration(labelText: label, isDense: true),
        style: const TextStyle(fontSize: 12, color: Colors.white),
        items: [
          if (allowNull) DropdownMenuItem<String?>(value: null, child: Text(nullLabel, style: const TextStyle(fontSize: 12))),
          for (final i in items) DropdownMenuItem<String?>(value: idOf(i), child: Text(labelOf(i), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1, color: Colors.white54, fontWeight: FontWeight.bold)),
  );
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.color});
  final String k;
  final String v;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: LayoutBuilder(
      builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 11.5, color: Colors.white60))),
        const SizedBox(width: 6),
        // a long value ("15.2 m³/h @ 31.4 m.c.a. (surplus 2.0)") wraps
        // instead of running off a narrow panel
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
          child: Text(v, textAlign: TextAlign.end, style: TextStyle(fontSize: 11.5, color: color ?? Colors.white, fontFamily: 'monospace')),
        ),
      ]),
    ),
  );
}

/// Vertical scroll view with an always-visible scrollbar, for dialogs whose
/// content may not fit the window.
class ScrollBody extends StatefulWidget {
  const ScrollBody({super.key, required this.child});
  final Widget child;

  @override
  State<ScrollBody> createState() => _ScrollBodyState();
}

class _ScrollBodyState extends State<ScrollBody> {
  final _ctl = ScrollController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(controller: _ctl, thumbVisibility: true, child: SingleChildScrollView(controller: _ctl, padding: const EdgeInsets.only(right: 12), child: widget.child));
}
