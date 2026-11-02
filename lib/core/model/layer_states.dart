/// Named states of the layers (1.6.0 CAD): which layers are shown and
/// which are locked, kept in the project ("hydraulic sheet", "electrical
/// sheet") and put back with one choice. Saved in the project file under
/// `layerStates` (only when there is one).
library;

import 'project.dart';

class LayerState {
  LayerState(this.name, Map<String, (bool, bool)> layers) : layers = Map.unmodifiable(layers);

  final String name;

  /// (visible, locked) of each layer, by name.
  final Map<String, (bool, bool)> layers;

  /// The state the layers of [p] are in now.
  factory LayerState.of(String name, Project p) => LayerState(name, {for (final l in p.layers) l.name: (l.visible, l.locked)});

  /// Puts the layers of [p] as this state has them; a layer the state does
  /// not know is shown and unlocked when [others] is true (as when it was
  /// saved it did not exist yet), else left alone. Returns how many layers
  /// changed.
  int applyTo(Project p, {bool others = false}) {
    var n = 0;
    for (final l in p.layers) {
      final s = layers[l.name] ?? (others ? (true, false) : null);
      if (s == null) continue;
      if (l.visible != s.$1 || l.locked != s.$2) n++;
      l
        ..visible = s.$1
        ..locked = s.$2;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'layers': {
      for (final e in layers.entries) e.key: [e.value.$1, e.value.$2],
    },
  };

  /// Reads a state; null when it is none.
  static LayerState? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final raw = json['layers'];
    if (name is! String || name.trim().isEmpty || raw is! Map) return null;
    return LayerState(name.trim(), {
      for (final e in raw.entries)
        if (e.value is List && (e.value as List).length >= 2) '${e.key}': ((e.value as List)[0] != false, (e.value as List)[1] == true),
    });
  }
}

/// The named layer states of a project (top-level `layerStates`, read and
/// written back by the project's own handling of the keys it does not
/// know).
extension ProjectLayerStates on Project {
  List<LayerState> get layerStates {
    final raw = extra?['layerStates'];
    if (raw is! List) return const [];
    return _states[raw] ??= List.unmodifiable([
      for (final x in raw) ?LayerState.fromJson(x),
    ]);
  }

  set layerStates(List<LayerState> v) {
    if (v.isEmpty) {
      extra?.remove('layerStates');
      if (extra?.isEmpty ?? false) extra = null;
      return;
    }
    (extra ??= {})['layerStates'] = [for (final s in v) s.toJson()];
  }

  /// The state called [name], or null.
  LayerState? layerStateNamed(String name) {
    for (final s in layerStates) {
      if (s.name == name.trim()) return s;
    }
    return null;
  }
}

/// The states read from each stored list (asked on every rebuild).
final _states = Expando<List<LayerState>>('layerStates');
