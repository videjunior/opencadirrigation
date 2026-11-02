/// User blocks: a named set of entities with a base point, kept in the
/// project and inserted as copies, moved, turned and scaled about the base
/// point with [Entity.transformed] (a valve manifold, a standard head
/// layout, a title or a symbol drawn once and placed many times).
///
/// The entities of a block are stored in block coordinates (the base point
/// at the origin) and keep the catalogue references and layers they had;
/// inserting one gives new ids from the project and creates the layers it
/// lacks. The library is saved in the project file under `blocks`.
///
/// 1.6.0 CAD: a block of drawing items is inserted as a reference
/// ([BlockRefEntity]) that draws the block where it is placed, so that
/// redefining the block changes every reference; a block has attributes
/// ([BlockAttributeDef]: a code, a flow…) whose values each reference keeps,
/// and one marked [BlockDefinition.inBom] counts its references in the
/// bill of materials. A library saves to and reads from a file of its own
/// ([blockLibraryToJson], [blockLibraryFromJson]).
library;

import '../design/results.dart' show BomLine, DesignResults;
import '../units.dart' show parseNumber;
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

/// 1.6.0 CAD: an attribute of a block — its [tag] (upper case, no spaces),
/// what it asks, its default value and where its value is written in block
/// coordinates (text [height], turned [rotationDeg]; not drawn unless
/// [visible]).
class BlockAttributeDef {
  const BlockAttributeDef({required this.tag, this.prompt = '', this.defaultValue = '', this.position = Pt.zero, this.height = 0.5, this.rotationDeg = 0, this.visible = true});
  final String tag;
  final String prompt;
  final String defaultValue;
  final Pt position;
  final double height;
  final double rotationDeg;
  final bool visible;

  /// [s] as a tag: trimmed, upper case, spaces as `_`.
  static String tagOf(String s) => s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');

  BlockAttributeDef copyWith({String? tag, String? prompt, String? defaultValue, Pt? position, double? height, double? rotationDeg, bool? visible}) => BlockAttributeDef(
    tag: tag ?? this.tag,
    prompt: prompt ?? this.prompt,
    defaultValue: defaultValue ?? this.defaultValue,
    position: position ?? this.position,
    height: height ?? this.height,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    visible: visible ?? this.visible,
  );

  Map<String, dynamic> toJson() => {
    'tag': tag,
    if (prompt.isNotEmpty) 'prompt': prompt,
    if (defaultValue.isNotEmpty) 'def': defaultValue,
    'p': position.toList(),
    'h': height,
    if (rotationDeg != 0) 'rot': rotationDeg,
    if (!visible) 'hidden': true,
  };

  /// Reads an attribute; null when it is none (no tag).
  static BlockAttributeDef? fromJson(Object? json) {
    if (json is! Map) return null;
    final tag = tagOf('${json['tag'] ?? ''}');
    if (tag.isEmpty) return null;
    final h = json['h'];
    final r = json['rot'];
    return BlockAttributeDef(
      tag: tag,
      prompt: json['prompt'] is String ? json['prompt'] as String : '',
      defaultValue: json['def'] is String ? json['def'] as String : '',
      position: Pt.tryFromList(json['p']) ?? Pt.zero,
      height: h is num && h.isFinite && h > 0 ? h.toDouble() : 0.5,
      rotationDeg: r is num && r.isFinite ? r.toDouble() : 0,
      visible: json['hidden'] != true,
    );
  }
}

/// 1.6.0 CAD: a text `{TAG}` or `{TAG=default}` in a selection saved as a
/// block becomes the attribute TAG at its place.
final attributeTextPattern = RegExp(r'^\{\s*([A-Za-z0-9_\-]+)\s*(?:=(.*))?\}$', dotAll: true);

/// 1.6.0 CAD: whether [e] may go into a block reference (a drawing item:
/// the design never sees what a reference draws).
bool isReferenceable(Entity e) => switch (e) {
  LineEntity _ ||
  PolylineEntity _ ||
  CircleEntity _ ||
  ArcEntity _ ||
  SplineEntity _ ||
  HatchEntity _ ||
  SymbolEntity _ ||
  TextEntity _ ||
  DimensionEntity _ ||
  AngularDimensionEntity _ ||
  RadialDimensionEntity _ ||
  OrdinateDimensionEntity _ ||
  LeaderEntity _ => true,
  _ => false,
};

/// 1.6.0 CAD: points every block reference of [p] at its block in
/// [Project.blocks] (null when the library has none of its name).
void resolveBlockRefs(Project p) {
  final lib = p.blocks;
  for (final e in p.entities) {
    if (e is BlockRefEntity) {
      final d = lib.byName(e.blockName);
      if (!identical(d, e.definition)) e.definition = d;
    }
  }
}

/// 1.6.0 CAD: the entities of [p] with every block reference replaced by
/// what it draws (new ids from [newId] when given, else the reference's
/// `<id>#<n>`): for the formats that have no blocks.
List<Entity> flattenBlockRefs(Project p, {String Function()? newId}) {
  resolveBlockRefs(p);
  return [
    for (final e in p.entities)
      if (e is BlockRefEntity) ...[for (final x in e.expanded()) newId == null ? x : x.clone(newId: newId())] else e,
  ];
}

/// 1.6.0 CAD: the attribute tags whose value is the item code of a block
/// in the bill of materials, and those whose value is its unit price.
const bomCodeTags = ['CODE', 'CODIGO', 'CÓDIGO', 'ITEM', 'REF'];
const bomPriceTags = ['PRICE', 'COST', 'PRECO', 'PREÇO', 'CUSTO', 'PRECIO', 'COSTO'];

/// 1.6.0 CAD: the bill of materials lines of the references of the blocks
/// marked [BlockDefinition.inBom]: one line per block, code and price, its
/// quantity the number of references, its price the value of a price
/// attribute (0 without one); in the order the blocks are met.
List<BomLine> blockBomLines(Project p) {
  resolveBlockRefs(p);
  final lines = <String, BomLine>{};
  for (final e in p.entities) {
    if (e is! BlockRefEntity) continue;
    final d = e.definition;
    if (d == null || !d.inBom) continue;
    String first(List<String> tags) {
      for (final t in tags) {
        final v = e.attribute(t).trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final code = first(bomCodeTags);
    final raw = parseNumber(first(bomPriceTags)) ?? 0;
    final price = raw.isFinite && raw > 0 ? raw : 0.0;
    final key = '${d.name}\u0001$code\u0001$price';
    final line = lines[key];
    if (line != null) {
      line.quantity += 1;
    } else {
      lines[key] = BomLine(category: 'block', description: d.description.isEmpty ? d.name : '${d.name} — ${d.description}', unit: 'un', quantity: 1, unitCost: price, code: code);
    }
  }
  return lines.values.toList();
}

/// 1.6.0 CAD: [r] with the lines of [blockBomLines] of [p] added to its
/// bill of materials (results of a design that never sees the references).
DesignResults appendBlockBom(Project p, DesignResults r) {
  final lines = blockBomLines(p);
  if (lines.isNotEmpty && !r.bom.any((l) => l.category == 'block')) r.bom.addAll(lines);
  return r;
}

class BlockDefinition {
  BlockDefinition({
    required this.name,
    this.description = '',
    required List<Entity> entities,
    Map<String, int>? layers,
    DateTime? created,
    List<BlockAttributeDef> attributes = const [],
    this.inBom = false,
  }) : entities = List.unmodifiable(entities),
       layers = Map.unmodifiable(layers ?? const <String, int>{}),
       attributes = List.unmodifiable(attributes),
       created = created ?? DateTime.now();

  /// Name, unique in the library.
  final String name;
  final String description;

  /// The entities in block coordinates (the base point at the origin).
  final List<Entity> entities;

  /// Colour of every layer the entities use, to recreate missing layers.
  final Map<String, int> layers;
  final DateTime created;

  /// 1.6.0 CAD: the attributes each reference fills in.
  final List<BlockAttributeDef> attributes;

  /// 1.6.0 CAD: the references of this block are items of the bill of
  /// materials (see [blockBomLines]).
  final bool inBom;

  /// 1.6.0 CAD: whether the block can be inserted as a reference (only
  /// drawing items, see [isReferenceable]); else it goes in as copies.
  bool get canBeReferenced => entities.isNotEmpty && entities.every(isReferenceable);

  /// The attribute tagged [tag], or null.
  BlockAttributeDef? attributeOf(String tag) {
    for (final a in attributes) {
      if (a.tag == tag) return a;
    }
    return null;
  }

  /// A block of copies of [selection] with its base point at [base] (the
  /// drawing keeps its entities); layer colours from [project].
  ///
  /// 1.6.0 CAD: a text `{TAG}` or `{TAG=default}` becomes the attribute
  /// TAG where it is (see [attributeTextPattern]), [attributes] are added
  /// after those, and a block reference in the selection goes in as what
  /// it draws.
  factory BlockDefinition.fromEntities(
    String name,
    Iterable<Entity> selection,
    Pt base, {
    String description = '',
    Project? project,
    List<BlockAttributeDef> attributes = const [],
    bool inBom = false,
  }) {
    final t = Affine.translation(-base);
    final ents = <Entity>[];
    final attrs = <BlockAttributeDef>[];
    for (final e in selection) {
      if (e is BlockRefEntity) {
        if (project != null) e.definition ??= project.blocks.byName(e.blockName);
        ents.addAll([for (final x in e.expanded()) x.transformed(t)]);
        continue;
      }
      final m = e is TextEntity ? attributeTextPattern.firstMatch(e.text.trim()) : null;
      if (e is TextEntity && m != null) {
        final tag = BlockAttributeDef.tagOf(m.group(1)!);
        if (attrs.every((a) => a.tag != tag)) {
          attrs.add(BlockAttributeDef(tag: tag, prompt: tag, defaultValue: (m.group(2) ?? '').trim(), position: e.position - base, height: e.height, rotationDeg: e.rotationDeg));
        }
        continue;
      }
      ents.add(e.transformed(t));
    }
    for (final a in attributes) {
      if (attrs.every((x) => x.tag != a.tag)) attrs.add(a);
    }
    return BlockDefinition(
      name: name,
      description: description,
      entities: ents,
      layers: {for (final e in ents) e.layer: project?.findLayer(e.layer)?.color ?? Layers.defaultColors[e.layer] ?? 0xFFB0BEC5},
      attributes: attrs,
      inBom: inBom,
    );
  }

  bool get isEmpty => entities.isEmpty;

  /// Extent in block coordinates.
  Bounds get bounds => entities.fold(Bounds.empty, (b, e) => b.union(e.bounds));

  /// 1.6.0 CAD: where attribute number [i] goes by default: one line under
  /// the other, right of the block.
  Pt defaultAttributePosition(int i, {double height = 0.5}) {
    final b = bounds;
    if (b.isEmpty) return Pt(height, -height * 1.6 * i);
    return Pt(b.maxX + height, b.maxY - height * (1.6 * i + 1));
  }

  /// Transform that places a block with its base point at [at], turned
  /// [rotationDeg] counter-clockwise and scaled [scale] times about it;
  /// [mirrored] (1.6.0 CAD) reflects it across its vertical axis first.
  static Affine placement(Pt at, {double rotationDeg = 0, double scale = 1, bool mirrored = false}) =>
      (mirrored ? Affine.mirror(Pt.zero, const Pt(0, 1)) : Affine.identity).then(Affine.scaling(scale)).then(Affine.rotation(degToRad(rotationDeg))).then(Affine.translation(at));

  /// Copies placed at [at] with new ids of [project] (not added to it);
  /// layers the project lacks are created. [scale] must be positive.
  /// 1.6.0 CAD: the visible attributes with a value ([values], else the
  /// defaults) come as texts.
  List<Entity> instantiate(Project project, {required Pt at, double rotationDeg = 0, double scale = 1, Map<String, String> values = const {}, bool mirrored = false}) {
    if (!(scale > 0) || !scale.isFinite || !rotationDeg.isFinite) throw ArgumentError('scale $scale, rotation $rotationDeg');
    final t = placement(at, rotationDeg: rotationDeg, scale: scale, mirrored: mirrored);
    addLayersTo(project);
    return [
      for (final e in entities) e.transformed(t).clone(newId: project.newId()),
      for (final a in attributes)
        if (a.visible && (values[a.tag] ?? a.defaultValue).trim().isNotEmpty)
          TextEntity(id: project.newId(), position: a.position, text: values[a.tag] ?? a.defaultValue, height: a.height, rotationDeg: a.rotationDeg).transformed(t),
    ];
  }

  /// 1.6.0 CAD: creates in [project] the layers the block uses and it lacks.
  void addLayersTo(Project project) {
    layers.forEach((name, color) {
      if (project.findLayer(name) == null) project.layers.add(Layer(name: name, color: color));
    });
  }

  BlockDefinition copyWith({String? name, String? description, List<BlockAttributeDef>? attributes, bool? inBom, List<Entity>? entities, Map<String, int>? layers}) => BlockDefinition(
    name: name ?? this.name,
    description: description ?? this.description,
    entities: entities ?? this.entities,
    layers: layers ?? this.layers,
    created: created,
    attributes: attributes ?? this.attributes,
    inBom: inBom ?? this.inBom,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description.isNotEmpty) 'desc': description,
    'created': created.toIso8601String(),
    'layers': layers,
    'entities': [for (final e in entities) e.toJson()],
    // 1.6.0 CAD
    if (attributes.isNotEmpty) 'attrs': [for (final a in attributes) a.toJson()],
    if (inBom) 'bom': true,
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
    // 1.6.0 CAD
    attributes: [for (final a in (j['attrs'] as List?) ?? const []) ?BlockAttributeDef.fromJson(a)],
    inBom: j['bom'] == true,
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

// ---------------------------------------------------------------- 1.6.0 CAD: the library as a file

/// Format name of a block library file (`.oci-blocks.json`).
const blockLibraryFormat = 'opencadirrigation-blocks';

/// [blocks] as a block library file: the blocks with their attributes and
/// the colours of the layers they use.
Map<String, dynamic> blockLibraryToJson(Iterable<BlockDefinition> blocks) => {
  'format': blockLibraryFormat,
  'version': 1,
  'blocks': [for (final b in blocks) b.toJson()],
};

/// The blocks of a block library file — or of a project file, whose
/// library is taken; throws a [FormatException] for anything else. A
/// damaged block is skipped.
List<BlockDefinition> blockLibraryFromJson(Object? json) {
  if (json is! Map) throw const FormatException('block_library');
  final f = json['format'];
  if (f != blockLibraryFormat && f != Project.formatName && f != Project.legacyFormatName) throw const FormatException('block_library');
  final list = json['blocks'];
  return BlockLibrary.fromJson(list is List ? list : null).blocks;
}
