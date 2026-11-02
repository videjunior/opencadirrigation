/// One project inserted into another (1.6.0 MOD): File → Insert project…,
/// the command line and the assistant. The entities come in with new ids
/// through the paste of the core ([pasteEntities]: references between them
/// kept, catalogue items renamed when the target has another item under
/// their id, prices in the target's currency, valve-in-head stations kept
/// apart), with the layers, the system flows and the blocks of the other
/// project, placed by the two georeferences.
library;

import 'dart:convert';

import '../design/valve_in_head.dart' show vihPrefix;
import 'blocks.dart';
import 'geometry.dart';
import 'paste.dart';
import 'project.dart';

/// How the inserted drawing was placed.
enum InsertPlacement {
  /// As drawn (moved by the offset asked for, if any).
  asDrawn,

  /// Moved from the other project's georeference to the target's (the same
  /// place on the ground).
  georeferenced,

  /// The target had none and nothing drawn yet: it took the other project's.
  georeferenceTaken,
}

/// What [insertProject] did.
class InsertProjectResult {
  const InsertProjectResult({required this.paste, required this.placement, this.layers = 0, this.flows = 0, this.blocks = 0});

  /// The entities inserted (their new ids), the catalogue items renamed and
  /// the exchange rate of the prices.
  final PasteResult paste;
  final InsertPlacement placement;

  /// Layers, system flows and blocks added.
  final int layers, flows, blocks;

  /// Ids of the inserted entities.
  List<String> get ids => paste.ids;
}

/// Inserts [src] into [p]:
/// - every entity of [src] with a new id; the catalogue items they use come
///   along (renamed when [p] has another item under the same id, prices
///   converted to the currency of [p]);
/// - the layers [p] lacks, with their colour and state;
/// - the system flows of [src] that run inserted items (their valves,
///   pivots and valve-in-head stations remapped; ids and names made unique);
/// - the blocks of [src] (one of the same name and other content renamed);
/// - placed by the georeferences: when both projects have one, the drawing
///   moves to the same place on the ground in [p]'s coordinates; when only
///   [src] has one and [p] holds nothing yet, [p] takes it; otherwise it
///   comes in as drawn, moved by [offset].
/// The design parameters, details, quote and alternatives of [p] stay.
InsertProjectResult insertProject(Project p, Project src, {Pt offset = Pt.zero}) {
  // ---- layers the target lacks, as they are in the other project
  var layers = 0;
  for (final l in src.layers) {
    if (p.findLayer(l.name) != null) continue;
    p.layers.add(Layer.fromJson(l.toJson()));
    layers++;
  }
  // ---- placement
  final from = src.meta.georef, to = p.meta.georef;
  var placement = InsertPlacement.asDrawn;
  Affine? place;
  if (from != null && to != null) {
    placement = InsertPlacement.georeferenced;
    if (from.zone == to.zone && from.north == to.north) {
      place = Affine.translation(Pt(from.originEasting - to.originEasting, from.originNorthing - to.originNorthing));
    } else {
      // another UTM zone: the rigid motion that takes two points of the
      // drawing to where their latitude and longitude fall in the target
      Pt there(Pt q) {
        final (lat, lon) = from.toLatLon(q.x, q.y);
        final (x, y) = to.fromLatLon(lat, lon);
        return Pt(x, y);
      }

      final b = src.bounds;
      final a0 = b.isEmpty ? Pt.zero : Pt(b.minX, b.minY);
      final a1 = b.isEmpty || (b.maxX - b.minX) + (b.maxY - b.minY) < 1 ? a0 + const Pt(1000, 1000) : Pt(b.maxX, b.maxY);
      place = similarityFromPairs(a0, a1, there(a0), there(a1), keepScale: true);
    }
  } else if (from != null && to == null && p.entities.isEmpty) {
    p.meta.georef = from;
    placement = InsertPlacement.georeferenceTaken;
  }
  // ---- the entities, through the paste
  final paste = pasteEntities(p, [for (final e in src.entities) e.toJson()], catalog: catalogSubset(src.catalog, src.entities), currency: src.params.currencyCode, offset: offset, place: place);
  for (final id in paste.ids) {
    final e = p.byId(id);
    if (e != null) p.layerNamed(e.layer);
  }
  // ---- system flows of the inserted items
  var flows = 0;
  final takenIds = {for (final f in p.systemFlows) f.id};
  final takenNames = {for (final f in p.systemFlows) f.name};
  for (final f in src.systemFlows) {
    final runs = <String>{
      for (final v in f.valveIds)
        if (paste.idMap[v] case final mapped?) mapped else if (v.startsWith(vihPrefix)) '$vihPrefix${paste.renamedStations[v.substring(vihPrefix.length)] ?? v.substring(vihPrefix.length)}',
    };
    if (runs.isEmpty) continue;
    var id = f.id;
    for (var k = 2; takenIds.contains(id); k++) {
      id = '${f.id}_$k';
    }
    var name = f.name;
    for (var k = 2; takenNames.contains(name); k++) {
      name = '${f.name} ($k)';
    }
    takenIds.add(id);
    takenNames.add(name);
    p.systemFlows.add(SystemFlow(id: id, name: name, valveIds: runs, startHour: f.startHour, durationHours: f.durationHours)..extra = f.extra);
    flows++;
  }
  // ---- blocks: the same block once, another one under a free name
  var blocks = 0;
  String body(BlockDefinition b) => jsonEncode(b.toJson()['entities']);
  for (final b in src.blocks.blocks) {
    final have = p.blocks.byName(b.name);
    if (have != null && body(have) == body(b)) continue;
    var name = b.name;
    for (var k = 2; p.blocks.byName(name) != null; k++) {
      name = '${b.name} ($k)';
    }
    p.blocks.put(b.copyWith(name: name));
    blocks++;
  }
  return InsertProjectResult(paste: paste, placement: placement, layers: layers, flows: flows, blocks: blocks);
}
