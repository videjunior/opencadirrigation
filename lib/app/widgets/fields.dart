import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/units.dart';
import '../i18n.dart';
import '../state/controller.dart' show uiLanguage;
import '../theme.dart';

/// [fmt] in the notation of the interface language (decimal comma in
/// Portuguese, Spanish, German, French…), for what the screen shows.
String fmtUi(double v, [int decimals = 2]) => fmtLocale(v, decimals, uiLanguage.value);

/// The numbers inside [text] in the notation of the interface language.
String localizeUi(String text) => localizeNumbers(text, uiLanguage.value);

/// A number typed by the user, read in the notation of the interface
/// language ("2.000" is two thousand in Portuguese, "1,500" one thousand
/// five hundred in English; see [parseNumber]).
double? parseUiNumber(String text) => parseNumber(text, decimalSeparator: decimalSeparatorOf(uiLanguage.value));

/// How a number field shows [v]: whole values with one decimal (or none),
/// otherwise [decimals] places, more for small values so they keep three
/// significant digits (0.004 is not "0.00"), in the notation of [lang].
String formatFieldNumber(double v, int decimals, String lang) {
  if (!v.isFinite) return '';
  String s;
  if (v == v.roundToDouble() && decimals <= 2) {
    s = v.toStringAsFixed(v.abs() < 1e-9 ? 0 : (decimals == 0 ? 0 : 1));
  } else {
    var d = decimals;
    final a = v.abs();
    if (a > 0 && a < 1) {
      // three significant digits, the extra zeros dropped
      final need = (-(math.log(a) / math.ln10).floor()) + 2;
      if (need > d) d = math.min(need, 8);
    }
    s = v.toStringAsFixed(d);
    if (d > decimals) {
      while (s.endsWith('0') && s.length - s.indexOf('.') - 1 > decimals) {
        s = s.substring(0, s.length - 1);
      }
    }
  }
  if (s.startsWith('-') && !s.contains(RegExp('[1-9]'))) s = s.substring(1);
  return decimalSeparatorOf(lang) == ',' ? s.replaceAll('.', ',') : s;
}

/// The keyboard of a number field: the numeric one, except on the iPhone
/// and iPad, whose numeric keyboard has no minus sign (the field then shows
/// a ± key of its own).
TextInputType numberKeyboard({bool signed = true}) => TextInputType.numberWithOptions(decimal: true, signed: signed);

/// Whether the numeric keyboard of this device lacks the minus sign.
bool get keyboardLacksMinus => defaultTargetPlatform == TargetPlatform.iOS;

/// The keyboard of a plain text field that takes a number with a sign
/// (coordinates, elevations): the numeric one, except on the iPhone and
/// iPad, whose numeric keyboard has no minus sign (UI-30).
TextInputType get signedNumberKeyboard => keyboardLacksMinus ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true, signed: true);

/// Numeric text field that commits on submit / focus loss — only when the
/// text was edited (reading a value never writes it back rounded), in the
/// notation of the interface language, with the other reading of an
/// ambiguous number ("2.000") offered under the field.
class NumField extends StatefulWidget {
  const NumField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.decimals = 2,
    this.enabled = true,
    this.width,
    this.mixed = false,
    this.signed = true,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final int decimals;
  final bool enabled;
  final double? width;

  /// Several selected objects hold different values (batch editing): the
  /// field starts empty with a hint, and whatever number is typed applies
  /// to all of them, also the value [value] stands for.
  final bool mixed;

  /// The value may be negative (on the iPhone a ± key is shown).
  final bool signed;

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late String _lang = uiLanguage.value;
  late final TextEditingController _c = TextEditingController(text: _show(widget.value));
  final _focus = FocusNode();

  /// The other reading of the ambiguous number just typed, offered under
  /// the field ("2.000" read as 2000 in Portuguese: was it 2?).
  double? _alternative;

  /// The text last written (Enter, then the focus leaving, write once).
  String? _committed;

  String get _sep => decimalSeparatorOf(_lang);

  String _show(double v) => widget.mixed ? '' : formatFieldNumber(v, widget.decimals, _lang);

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
    final langChanged = _lang != uiLanguage.value;
    _lang = uiLanguage.value;
    final text = _show(widget.value);
    if (_c.text == text) return;
    // a new value, the language changed, or the one typed was not taken
    // (clamped, rejected): show what the model holds instead
    final shown = widget.mixed ? null : parseNumber(_c.text, decimalSeparator: _sep);
    final tolerance = 0.5 * math.pow(10, -widget.decimals) + 1e-12;
    if (langChanged || old.value != widget.value || old.mixed != widget.mixed || shown == null || (shown - widget.value).abs() > tolerance) _c.text = text;
  }

  void _commit() {
    final text = _c.text.trim();
    // not edited: nothing is written (a value converted to bar or psi shows
    // rounded, and writing it back would change it)
    if (text == _show(widget.value).trim() || text == _committed) return;
    final v = parseNumber(text, decimalSeparator: _sep);
    if (v == null) {
      // not a number: back to the value in force
      _c.text = _show(widget.value);
      return;
    }
    final other = numberIsAmbiguous(text, _sep) ? parseNumber(text) : null;
    if (other != _alternative) setState(() => _alternative = other);
    _committed = text;
    if (widget.mixed || v != widget.value) widget.onChanged(v);
  }

  void _useAlternative() {
    final v = _alternative;
    if (v == null) return;
    setState(() => _alternative = null);
    _c.text = formatFieldNumber(v, widget.decimals, _lang);
    _committed = _c.text;
    widget.onChanged(v);
  }

  void _negate() {
    final t = _c.text.trim();
    _c.text = t.startsWith('-') ? t.substring(1) : '-$t';
    _c.selection = TextSelection.collapsed(offset: _c.text.length);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n(_lang);
    final f = TextField(
      controller: _c,
      focusNode: _focus,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        hintText: widget.mixed ? t('props.mixed') : null,
        isDense: true,
        suffixIcon: widget.signed && keyboardLacksMinus && widget.enabled
            ? IconButton(
                tooltip: t('num.negate'),
                visualDensity: VisualDensity.compact,
                icon: const Text('±', style: TextStyle(fontSize: 15)),
                onPressed: _negate,
              )
            : null,
      ),
      keyboardType: numberKeyboard(signed: widget.signed),
      onSubmitted: (_) => _commit(),
      onChanged: (_) {
        _committed = null;
        if (_alternative != null) setState(() => _alternative = null);
      },
      // the field stays above the on-screen keyboard
      scrollPadding: const EdgeInsets.all(48),
      style: const TextStyle(fontSize: 12),
    );
    final alt = _alternative;
    final body = alt == null
        ? f
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              f,
              InkWell(
                key: const Key('num_alternative'),
                onTap: _useAlternative,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    t('num.readAs', {'v': formatFieldNumber(widget.value, widget.decimals, _lang), 'alt': formatFieldNumber(alt, widget.decimals, _lang)}),
                    style: TextStyle(fontSize: 11, color: Cad.accentText),
                  ),
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: widget.width != null ? SizedBox(width: widget.width, child: body) : body,
    );
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
      scrollPadding: const EdgeInsets.all(48),
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class SpecDropdown<T> extends StatelessWidget {
  const SpecDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.idOf,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel = '—',
    this.missingLabel,
  });
  final String label;
  final String? value;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T) idOf;
  final ValueChanged<String?> onChanged;
  final bool allowNull;
  final String nullLabel;

  /// The label of a [value] the list does not offer (an item switched off
  /// or removed from the catalogue, a layer that no longer exists): it is
  /// shown as it is — never another item in its place — with this text, by
  /// default the id followed by "(not in the list)".
  final String Function(String id)? missingLabel;

  @override
  Widget build(BuildContext context) {
    final ids = items.map(idOf).toSet();
    final missing = value != null && !ids.contains(value);
    final v = value ?? (allowNull ? null : (items.isEmpty ? null : idOf(items.first)));
    final t = I18n(uiLanguage.value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String?>(
        // a new entry when the value comes or goes from the list
        key: ValueKey('spec_${missing ? value : ''}'),
        isExpanded: true,
        initialValue: v,
        decoration: InputDecoration(labelText: label, isDense: true),
        style: TextStyle(fontSize: 12, color: Cad.fg),
        items: [
          if (allowNull) DropdownMenuItem<String?>(value: null, child: Text(nullLabel, style: const TextStyle(fontSize: 12))),
          if (missing)
            DropdownMenuItem<String?>(
              value: value,
              child: Text(
                missingLabel?.call(value!) ?? '${value!} ${t('props.notInList')}',
                key: const Key('spec_missing'),
                style: TextStyle(fontSize: 12, color: Cad.attention),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          for (final i in items)
            DropdownMenuItem<String?>(
              value: idOf(i),
              child: Text(labelOf(i), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
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
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: Cad.fg54, fontWeight: FontWeight.bold),
    ),
  );
}

/// A label and a value, the numbers of the value in the notation of the
/// interface language.
class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.color});
  final String k;
  final String v;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k, style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
          ),
          const SizedBox(width: 6),
          // a long value ("15.2 m³/h @ 31.4 m.c.a. (surplus 2.0)") wraps
          // instead of running off a narrow panel
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
            child: Text(
              localizeUi(v),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Vertical scroll view with an always-visible scrollbar, for dialogs whose
/// content may not fit the window (the room for the bar is on the side it
/// is drawn on: the right, the left in Arabic and Urdu).
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
  Widget build(BuildContext context) => Scrollbar(
    controller: _ctl,
    thumbVisibility: true,
    child: SingleChildScrollView(controller: _ctl, padding: const EdgeInsetsDirectional.only(end: 12), child: widget.child),
  );
}
