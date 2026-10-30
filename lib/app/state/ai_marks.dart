/// Points and lines the user marks on the drawing for the AI assistant —
/// "the pump goes here", "the mainline along here" — labelled A, B, C…:
/// drawn over the canvas and in the assistant's pictures, and sent with the
/// next message with their coordinates, so the user points instead of
/// describing a place in words. They belong to the project tab, not to the
/// project: nothing is saved with it and no undo step is made.
library;

import 'package:flutter/foundation.dart';

import '../../core/model/geometry.dart';
import '../../core/units.dart';

/// One mark: a point, or a line of two or more points.
class AiMark {
  AiMark(this.label, this.points, {this.note = ''});

  /// "A", "B"… (see [AiMarks.nextLabel]).
  final String label;
  final List<Pt> points;

  /// What the user wrote about it ("pump", "well"), may be empty.
  String note;

  bool get isPoint => points.length == 1;

  /// The text for the model: label, kind, coordinates, length and note.
  String describe() {
    String p(Pt q) => '[${fmt(q.x, 2)}, ${fmt(q.y, 2)}]';
    final what = isPoint ? 'point ${p(points.first)}' : 'line [${points.map(p).join(', ')}], ${fmt(polylineLength(points), 1)} m long';
    return '$label: $what${note.trim().isEmpty ? '' : ' — "${note.trim()}"'}';
  }
}

/// The marks of a project tab.
class AiMarks extends ChangeNotifier {
  final List<AiMark> _marks = [];

  List<AiMark> get marks => List.unmodifiable(_marks);
  bool get isEmpty => _marks.isEmpty;

  /// Bumped on every change: the assistant sends the marks again only when
  /// they changed since the last message.
  int get version => _version;
  int _version = 0;

  /// The next free label: A … Z, then A2 … Z2, and so on.
  String nextLabel() {
    final used = {for (final m in _marks) m.label};
    for (var round = 1; ; round++) {
      for (var k = 0; k < 26; k++) {
        final l = '${String.fromCharCode(65 + k)}${round == 1 ? '' : round}';
        if (!used.contains(l)) return l;
      }
    }
  }

  /// Adds a mark of [points] (one: a point; more: a line) and returns it.
  AiMark add(List<Pt> points, {String note = ''}) {
    if (points.isEmpty) throw ArgumentError('a mark needs a point');
    final m = AiMark(nextLabel(), List.unmodifiable(points), note: note);
    _marks.add(m);
    _changed();
    return m;
  }

  void setNote(String label, String note) {
    final m = byLabel(label);
    if (m == null || m.note == note) return;
    m.note = note;
    _changed();
  }

  AiMark? byLabel(String label) {
    for (final m in _marks) {
      if (m.label == label) return m;
    }
    return null;
  }

  void remove(String label) {
    final n = _marks.length;
    _marks.removeWhere((m) => m.label == label);
    if (_marks.length != n) _changed();
  }

  void clear() {
    if (_marks.isEmpty) return;
    _marks.clear();
    _changed();
  }

  void _changed() {
    _version++;
    notifyListeners();
  }

  /// The marks as the model reads them, one a line.
  String describe() => [for (final m in _marks) m.describe()].join('\n');
}
