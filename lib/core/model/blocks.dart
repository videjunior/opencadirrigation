/// User blocks: a named set of entities with a base point, kept in the
/// project and inserted as copies, moved, turned and scaled about the base
/// point with [Entity.transformed] (a valve manifold, a standard head
/// layout, a title or a symbol drawn once and placed many times).
///
/// The entities of a block are stored in block coordinates (the base point
/// at the origin) and keep the catalogue references and layers they had;
/// inserting one gives new ids from the project and creates the layers it
/// lacks. The library is saved in the project file under `blocks`.
library;

import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

class BlockDefinition {
  BlockDefinition({required this.name, this.description = '', required List<Entity> entities, Map<String, int>? layers, DateTime? created})
    : entities = List.unmodifiable(entities),
      layers = Map.unmodifiable(layers ?? const <String, int>{}),
      created = created ?? DateTime.now();

  /// Name, unique in the library.
  final String name;
  final String description;

  /// The entities in block coordinates (the base point at the origin).
  final List<Entity> entities;

  /// Colour of every layer the entities use, to recreate missing layers.
  final Map<String, int> layers;
  final DateTime created;

  /// A block of copies of [selection] with its base point at [base] (the
  /// drawing keeps its entities); layer colours from [project].
  factory BlockDefinition.fromEntities(String name, Iterable<Entity> selection, Pt base, {String description = '', Project? project}) {
    final t = Affine.translation(-base);
    final ents = [for (final e in selection) e.transformed(t)];
    return BlockDefinition(
      name: name,
      description: description,
      entities: ents,
      layers: {for (final e in ents) e.layer: project?.findLayer(e.layer)?.color ?? Layers.defaultColors[e.layer] ?? 0xFFB0BEC5},
    );
  }

  bool get isEmpty => entities.isEmpty;

  /// Extent in block coordinates.
  Bounds get bounds => entities.fold(Bounds.empty, (b, e) => b.union(e.bounds));

  /// Transform that places a block with its base point at [at], turned
  /// [rotationDeg] counter-clockwise and scaled [scale] times about it.
  static Affine placement(Pt at, {double rotationDeg = 0, double scale = 1}) => Affine.scaling(scale).then(Affine.rotation(degToRad(rotationDeg))).then(Affine.translation(at));

  /// Copies placed at [at] with new ids of [project] (not added to it);
  /// layers the project lacks are created. [scale] must be positive.
  List<Entity> instantiate(Project project, {required Pt at, double rotationDeg = 0, double scale = 1}) {
    if (!(scale > 0) || !scale.isFinite || !rotationDeg.isFinite) throw ArgumentError('scale $scale, rotation $rotationDeg');
    final t = placement(at, rotationDeg: rotationDeg, scale: scale);
    layers.forEach((name, color) {
      if (project.findLayer(name) == null) project.layers.add(Layer(name: name, color: color));
    });
    return [for (final e in entities) e.transformed(t).clone(newId: project.newId())];
  }

  BlockDefinition copyWith({String? name, String? description}) =>
      BlockDefinition(name: name ?? this.name, description: description ?? this.description, entities: entities, layers: layers, created: created);

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description.isNotEmpty) 'desc': description,
    'created': created.toIso8601String(),
    'layers': layers,
    'entities': [for (final e in entities) e.toJson()],
  };

  static BlockDefinition fromJson(Map<String, dynamic> j) => BlockDefinition(
    name: j['name'] as String? ?? '',
    description: j['desc'] as String? ?? '',
    created: DateTime.tryParse(j['created'] as String? ?? ''),
    layers: {
      for (final e in ((j['layers'] as Map?) ?? const {}).entries)
        if (e.value is num) e.key as String: (e.value as num).toInt(),
    },
    entities: [for (final e in (j['entities'] as List?) ?? const []) Entity.fromJson(e as Map<String, dynamic>)],
  );
}

/// The blocks of a project.
class BlockLibrary {
  BlockLibrary([List<BlockDefinition>? blocks]) : blocks = blocks ?? [];
  final List<BlockDefinition> blocks;

  bool get isEmpty => blocks.isEmpty;
  bool get isNotEmpty => blocks.isNotEmpty;
  int get length => blocks.length;

  /// The block called [name] (spaces around it ignored), or null.
  BlockDefinition? byName(String name) {
    final n = name.trim();
    for (final b in blocks) {
      if (b.name == n) return b;
    }
    return null;
  }

  /// Adds [b], replacing the block of the same name in its place; returns
  /// whether one was replaced.
  bool put(BlockDefinition b) {
    final i = blocks.indexWhere((x) => x.name == b.name);
    if (i < 0) {
      blocks.add(b);
      return false;
    }
    blocks[i] = b;
    return true;
  }

  bool remove(String name) {
    final i = blocks.indexWhere((x) => x.name == name);
    if (i < 0) return false;
    blocks.removeAt(i);
    return true;
  }

  /// Renames block [from]; false when [to] is empty or taken.
  bool rename(String from, String to) {
    final n = to.trim();
    final i = blocks.indexWhere((x) => x.name == from);
    if (i < 0 || n.isEmpty || (n != from && byName(n) != null)) return false;
    blocks[i] = blocks[i].copyWith(name: n);
    return true;
  }

  /// "[prefix] 1", "[prefix] 2"… the first name not in use.
  String uniqueName(String prefix) {
    var i = 1;
    while (byName('$prefix $i') != null) {
      i++;
    }
    return '$prefix $i';
  }

  List<Map<String, dynamic>> toJson() => [for (final b in blocks) b.toJson()];

  /// Reads a saved library; a damaged block is skipped, not the project.
  static BlockLibrary fromJson(List? j) {
    final out = <BlockDefinition>[];
    for (final x in j ?? const []) {
      try {
        final b = BlockDefinition.fromJson(x as Map<String, dynamic>);
        if (b.name.isNotEmpty && out.every((o) => o.name != b.name)) out.add(b);
      } on Object {
        continue;
      }
    }
    return BlockLibrary(out);
  }
}
