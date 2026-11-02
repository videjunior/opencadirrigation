part of 'entities.dart';

/// 1.6.0 CAD: a reference to a user block (the INSERT of CAD programs):
/// the block's entities are not copied into the drawing, the reference
/// draws its [definition] where it is placed — moved to [position], turned
/// [rotationDeg] counter-clockwise and scaled [scale] times about the base
/// point, after a reflection across the block's vertical axis when
/// [mirrored] — so redefining the block changes every reference at once.
/// [attributes] are this reference's values of the block's attributes (a
/// code, a flow, a name), drawn where the block puts them when visible and
/// counted in the bill of materials of a block that goes there.
///
/// Only drawing items go into a reference (lines, polylines, circles, arcs,
/// splines, hatches, symbols, texts, dimensions, leaders): a block with
/// hydraulic or terrain items is inserted as copies, which the design sees.
class BlockRefEntity extends Entity with PointEntity {
  BlockRefEntity({
    required super.id,
    super.layer = Layers.drawing,
    super.name,
    required this.position,
    required this.blockName,
    this.rotationDeg = 0,
    this.scale = 1,
    this.mirrored = false,
    Map<String, String>? attributes,
  }) : attributes = attributes ?? {};

  @override
  Pt position;

  /// Name of the block of the project's library ([BlockDefinition.name]).
  String blockName;
  double rotationDeg;
  double scale;
  bool mirrored;

  /// Value of each attribute (by tag) of this reference; a tag left out
  /// takes the block's default.
  final Map<String, String> attributes;

  /// The block drawn, found by name in the project's library (see
  /// `resolveBlockRefs` in blocks.dart); null when the library has none of
  /// that name (the reference is then drawn as a small marker).
  BlockDefinition? definition;

  @override
  EntityType get type => EntityType.blockRef;

  /// Block coordinates → world.
  Affine get placement => BlockDefinition.placement(position, rotationDeg: rotationDeg, scale: scale, mirrored: mirrored);

  /// The value of attribute [tag]: this reference's, else the block's default.
  String attribute(String tag) {
    final own = attributes[tag];
    if (own != null) return own;
    for (final a in definition?.attributes ?? const <BlockAttributeDef>[]) {
      if (a.tag == tag) return a.defaultValue;
    }
    return '';
  }

  List<Entity>? _expanded;
  Object? _expandedKey;

  /// The block's entities where this reference puts them (ids
  /// `<id>#<n>`), followed by the visible attributes as texts; empty
  /// without a definition. Kept until the placement, the values or the
  /// definition change.
  List<Entity> expanded() {
    final d = definition;
    if (d == null) return const [];
    final key = (identityHashCode(d), position, rotationDeg, scale, mirrored, [for (final a in d.attributes) attribute(a.tag)].join('\u0001'), layer);
    final cached = _expanded;
    if (cached != null && _expandedKey == key) return cached;
    final t = placement;
    final out = <Entity>[];
    for (var i = 0; i < d.entities.length; i++) {
      out.add(d.entities[i].transformed(t).clone(newId: '$id#$i'));
    }
    for (var i = 0; i < d.attributes.length; i++) {
      final a = d.attributes[i];
      final v = attribute(a.tag);
      if (!a.visible || v.trim().isEmpty) continue;
      out.add(TextEntity(id: '$id#a$i', layer: layer, position: a.position, text: v, height: a.height, rotationDeg: a.rotationDeg).transformed(t));
    }
    _expandedKey = key;
    return _expanded = out;
  }

  @override
  Bounds get bounds {
    final es = expanded();
    if (es.isEmpty) return Bounds(position.x - 0.5, position.y - 0.5, position.x + 0.5, position.y + 0.5);
    var b = Bounds(position.x, position.y, position.x, position.y);
    for (final e in es) {
      b = b.union(e.bounds);
    }
    return b;
  }

  @override
  double distanceTo(Pt p) {
    var best = math.max(0.0, position.distanceTo(p) - 0.5);
    for (final e in expanded()) {
      best = math.min(best, e.distanceTo(p));
    }
    return best;
  }

  @override
  BlockRefEntity clone({String? newId}) =>
      BlockRefEntity(id: newId ?? id, layer: layer, name: name, position: position, blockName: blockName, rotationDeg: rotationDeg, scale: scale, mirrored: mirrored, attributes: Map.of(attributes))
        ..definition = definition
        ..extra = extra;

  @override
  BlockRefEntity translated(Pt d) => clone()..position = position + d;

  /// A mirror reflects the block itself: the turn of a reflected block is
  /// the image of its direction less a half turn, and its reflection
  /// toggles (as a symbol's).
  @override
  BlockRefEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..rotationDeg = t.isMirror ? _norm360(_rotDeg(t, rotationDeg) - 180) : _norm360(_rotDeg(t, rotationDeg))
    ..scale = scale * t.scale
    ..mirrored = mirrored != t.isMirror;

  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'p': position.toList(),
    'block': blockName,
    if (rotationDeg != 0) 'rot': rotationDeg,
    if (scale != 1) 'sc': scale,
    if (mirrored) 'mir': true,
    if (attributes.isNotEmpty) 'attrs': Map.of(attributes),
  };
}
