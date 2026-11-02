/// What reading a project file had to repair: the file opens item by item,
/// a damaged or unknown item is set aside (kept as it was, written back on
/// save) instead of the whole file failing, and the repairs are listed for
/// the user.
library;

import 'dart:collection';

/// One repair, translated by the app as `read.<code>` with [args].
class ReadNote {
  const ReadNote(this.code, [this.args = const {}]);
  final String code;
  final Map<String, String> args;

  @override
  String toString() => args.isEmpty ? code : '$code ${args.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
}

/// Counts of the repairs made while reading a project (see [notes]).
class ProjectReadReport {
  /// Format version of the file (null: not stated, a file written by hand
  /// or by another program).
  int? fileVersion;

  /// The file comes from a newer version of the app: what this one does not
  /// know is kept and written back, but not shown.
  bool newerVersion = false;

  /// Items set aside, by section (`entities`, `layers`, `systemFlows`,
  /// `catalog`, `scenarios`, `labelRules`, `blocks`).
  final Map<String, int> skipped = {};

  /// Entities whose id repeated an earlier one and got a new id.
  int renumbered = 0;

  /// Vertices without valid coordinates dropped from lines and outlines.
  int droppedVertices = 0;

  /// Values not understood (an option of a newer version): `key=value`;
  /// the default was used.
  final List<String> unknownValues = [];

  void skip(String section) => skipped[section] = (skipped[section] ?? 0) + 1;

  int get skippedCount => skipped.values.fold(0, (a, b) => a + b);

  /// Nothing was repaired.
  bool get clean => !newerVersion && skipped.isEmpty && renumbered == 0 && droppedVertices == 0 && unknownValues.isEmpty;

  /// The repairs, most important first.
  List<ReadNote> get notes => [
    if (newerVersion) ReadNote('newer', {'v': '${fileVersion ?? ''}'}),
    if (skipped.isNotEmpty) ReadNote('skipped', {'n': '$skippedCount'}),
    if (renumbered > 0) ReadNote('renumbered', {'n': '$renumbered'}),
    if (droppedVertices > 0) ReadNote('vertices', {'n': '$droppedVertices'}),
    if (unknownValues.isNotEmpty) ReadNote('values', {'n': '${unknownValues.length}', 'v': unknownValues.take(3).join(', ')}),
  ];

  @override
  String toString() => notes.join('; ');
}

/// A read-only view of a JSON object that records the keys read, so the
/// keys a reader never asked for (fields of a newer version) can be kept
/// and written back unchanged.
class KeyLog extends MapBase<String, dynamic> {
  KeyLog(this._map);
  final Map<String, dynamic> _map;
  final Set<String> _read = {};

  @override
  dynamic operator [](Object? key) {
    if (key is String) _read.add(key);
    return _map[key];
  }

  @override
  bool containsKey(Object? key) {
    if (key is String) _read.add(key);
    return _map.containsKey(key);
  }

  @override
  void operator []=(String key, dynamic value) => throw UnsupportedError('read-only');

  @override
  void clear() => throw UnsupportedError('read-only');

  @override
  Iterable<String> get keys => _map.keys;

  @override
  dynamic remove(Object? key) => throw UnsupportedError('read-only');

  /// The fields never read, as they were (null when there are none).
  Map<String, dynamic>? get unread {
    Map<String, dynamic>? out;
    for (final e in _map.entries) {
      if (_read.contains(e.key)) continue;
      (out ??= {})[e.key] = e.value;
    }
    return out;
  }
}

/// The value of enum [values] named [name], or [fallback] (the name noted
/// in [report] as not understood under [key]) when it is not one of them.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback, {ProjectReadReport? report, String key = ''}) => enumOrNull(values, name, report: report, key: key) ?? fallback;

/// The value of enum [values] named [name], or null (noted in [report] when
/// [name] is text that names none of them).
T? enumOrNull<T extends Enum>(List<T> values, Object? name, {ProjectReadReport? report, String key = ''}) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  report?.unknownValues.add(key.isEmpty ? name : '$key=$name');
  return null;
}
