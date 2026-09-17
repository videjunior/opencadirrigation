/// Spatial index over the bounding boxes of the project's entities: a
/// static R-tree packed with the Sort-Tile-Recursive (STR) algorithm.
///
/// The index is built once after each edit (O(n log n)) and answers window
/// queries in O(log n + k): the painter asks for the entities in the
/// visible area every frame, the pointer asks for the entities under the
/// cursor on every move (hit test, snapping) and window selection asks for
/// the entities in the dragged rectangle. Entity bounds are computed once at
/// build time and cached, so polylines with thousands of vertices are not
/// measured again on every repaint.
///
/// Query results are entity indices into [entities] in ascending order, so
/// the caller keeps the drawing order (later entities are painted on top).
/// Entities whose bounds are empty or not finite are left out of the tree.
library;

import 'dart:math' as math;

import 'entities.dart';
import 'geometry.dart';

class SpatialIndex {
  /// Builds the index over [entities] (the list is kept, not copied).
  /// [leafSize] is the node capacity (items per leaf, children per node).
  SpatialIndex.build(this.entities, {int leafSize = 12}) : leafSize = leafSize < 2 ? 2 : leafSize {
    final n = entities.length;
    _bounds = List<Bounds>.generate(n, (i) => entities[i].bounds, growable: false);
    final valid = <int>[];
    for (var i = 0; i < n; i++) {
      if (_finite(_bounds[i])) valid.add(i);
    }
    indexed = valid.length;
    if (valid.isEmpty) {
      _root = -1;
      bounds = Bounds.empty;
      return;
    }
    _root = _packLeaves(valid);
    bounds = Bounds(_minX[_root], _minY[_root], _maxX[_root], _maxY[_root]);
  }

  final List<Entity> entities;
  final int leafSize;

  /// Number of entities that made it into the tree (finite bounds).
  late final int indexed;

  /// Extent of everything indexed (empty when nothing is).
  late final Bounds bounds;

  late final List<Bounds> _bounds;

  // Nodes: bounds, first/count into _items (leaves) or _children (inner).
  final List<double> _minX = [], _minY = [], _maxX = [], _maxY = [];
  final List<int> _first = [], _count = [];
  final List<bool> _leaf = [];
  final List<int> _items = [];
  final List<int> _children = [];
  int _root = -1;

  int get length => entities.length;

  /// Number of tree nodes (diagnostics).
  int get nodeCount => _leaf.length;

  /// Cached bounds of the entity at [index].
  Bounds boundsAt(int index) => _bounds[index];

  static bool _finite(Bounds b) => !b.isEmpty && b.minX.isFinite && b.minY.isFinite && b.maxX.isFinite && b.maxY.isFinite;

  int _addNode(int first, int count, bool leaf, double minX, double minY, double maxX, double maxY) {
    _minX.add(minX);
    _minY.add(minY);
    _maxX.add(maxX);
    _maxY.add(maxY);
    _first.add(first);
    _count.add(count);
    _leaf.add(leaf);
    return _leaf.length - 1;
  }

  /// STR packing of entity indices into leaves, then of leaves into the tree.
  int _packLeaves(List<int> ids) {
    double cx(int i) => (_bounds[i].minX + _bounds[i].maxX) / 2;
    double cy(int i) => (_bounds[i].minY + _bounds[i].maxY) / 2;
    ids.sort((a, b) => cx(a).compareTo(cx(b)));
    final leaves = (ids.length / leafSize).ceil();
    final slabSize = math.sqrt(leaves).ceil() * leafSize;
    final leafNodes = <int>[];
    for (var s = 0; s < ids.length; s += slabSize) {
      final slab = ids.sublist(s, math.min(s + slabSize, ids.length))..sort((a, b) => cy(a).compareTo(cy(b)));
      for (var k = 0; k < slab.length; k += leafSize) {
        final first = _items.length;
        var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
        for (var j = k; j < math.min(k + leafSize, slab.length); j++) {
          final b = _bounds[slab[j]];
          _items.add(slab[j]);
          if (b.minX < minX) minX = b.minX;
          if (b.minY < minY) minY = b.minY;
          if (b.maxX > maxX) maxX = b.maxX;
          if (b.maxY > maxY) maxY = b.maxY;
        }
        leafNodes.add(_addNode(first, _items.length - first, true, minX, minY, maxX, maxY));
      }
    }
    return _packNodes(leafNodes);
  }

  int _packNodes(List<int> nodes) {
    if (nodes.length == 1) return nodes.first;
    double cx(int n) => (_minX[n] + _maxX[n]) / 2;
    double cy(int n) => (_minY[n] + _maxY[n]) / 2;
    nodes.sort((a, b) => cx(a).compareTo(cx(b)));
    final parents = (nodes.length / leafSize).ceil();
    final slabSize = math.sqrt(parents).ceil() * leafSize;
    final level = <int>[];
    for (var s = 0; s < nodes.length; s += slabSize) {
      final slab = nodes.sublist(s, math.min(s + slabSize, nodes.length))..sort((a, b) => cy(a).compareTo(cy(b)));
      for (var k = 0; k < slab.length; k += leafSize) {
        final first = _children.length;
        var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
        for (var j = k; j < math.min(k + leafSize, slab.length); j++) {
          final c = slab[j];
          _children.add(c);
          if (_minX[c] < minX) minX = _minX[c];
          if (_minY[c] < minY) minY = _minY[c];
          if (_maxX[c] > maxX) maxX = _maxX[c];
          if (_maxY[c] > maxY) maxY = _maxY[c];
        }
        level.add(_addNode(first, _children.length - first, false, minX, minY, maxX, maxY));
      }
    }
    return _packNodes(level);
  }

  /// Calls [visit] with the index of every entity whose bounds intersect
  /// [q], in tree order (not drawing order).
  void visit(Bounds q, void Function(int index) visit) {
    if (_root < 0 || q.isEmpty) return;
    final stack = <int>[_root];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (q.minX > _maxX[n] || q.maxX < _minX[n] || q.minY > _maxY[n] || q.maxY < _minY[n]) continue;
      final first = _first[n], count = _count[n];
      if (_leaf[n]) {
        for (var k = first; k < first + count; k++) {
          final i = _items[k];
          if (_bounds[i].intersects(q)) visit(i);
        }
      } else {
        for (var k = first; k < first + count; k++) {
          stack.add(_children[k]);
        }
      }
    }
  }

  /// Indices of the entities whose bounds intersect [q], ascending (drawing
  /// order).
  List<int> query(Bounds q) {
    final out = <int>[];
    visit(q, out.add);
    out.sort();
    return out;
  }

  /// Entities whose bounds intersect [q], in drawing order.
  List<Entity> entitiesIn(Bounds q) => [for (final i in query(q)) entities[i]];

  /// Entities whose bounds lie within [tolerance] of [p], in drawing order.
  List<Entity> entitiesNear(Pt p, double tolerance) => entitiesIn(Bounds(p.x - tolerance, p.y - tolerance, p.x + tolerance, p.y + tolerance));
}
