/// Entities copied from one project into another (or into the same one):
/// the catalogue items they use come along, an item whose id the target
/// already gives to something else is renamed instead of being confused
/// with it, prices follow the target's currency, references between the
/// pasted entities point to their copies and valve-in-head stations keep
/// to themselves.
library;

import 'dart:convert';

import 'catalog.dart';
import 'currency.dart';
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

/// What [pasteEntities] did.
class PasteResult {
  const PasteResult({required this.ids, this.renamedItems = const {}, this.rate, this.idMap = const {}, this.renamedStations = const {}});

  /// Ids of the new entities, in the order given.
  final List<String> ids;

  /// The id each pasted entity had → the id of its copy (1.6.0 MOD: what
  /// refers to the entities outside them, such as system flows, follows it).
  final Map<String, String> idMap;

  /// Valve-in-head stations given a free name because the target used
  /// theirs: old name → new name (1.6.0 MOD).
  final Map<String, String> renamedStations;

  /// Catalogue items given a new id because the target has another item
  /// under theirs: old id → new id.
  final Map<String, String> renamedItems;

  /// Exchange rate applied to the prices (null: same currency or unknown).
  final double? rate;
}

/// Pastes [entities] (entity JSON) into [p] with new ids, moved by
/// [offset]. [layers] (name → colour) and [catalog] (group name → item
/// JSON: `pipes`, `outlets`, `tapes`, `valves`, `pumps`) are what the
/// entities use; [currency] is the ISO code of the prices of the source
/// project. [sameProject] tells a paste back into the project copied from:
/// references to entities left behind still hold there, and its
/// valve-in-head stations stay as they are.
PasteResult pasteEntities(
  Project p,
  List<Map<String, dynamic>> entities, {
  Map<String, int> layers = const {},
  Map<String, List<Map<String, dynamic>>> catalog = const {},
  String currency = '',
  Pt offset = Pt.zero,
  Affine? place,
  bool sameProject = false,
}) {
  layers.forEach((name, color) {
    if (p.layers.every((l) => l.name != name)) p.layers.add(Layer(name: name, color: color));
  });
  final to = p.params.currencyCode;
  final rate = !sameProject && currency.isNotEmpty && to.isNotEmpty && currency != to ? exchangeRate(currency, to) : null;

  // ---- catalogue items: added, reused when the same, renamed when another
  final cat = p.catalog;
  final renamed = <String, String>{};
  final incoming = Catalog(
    pipes: [for (final j in catalog['pipes'] ?? const []) PipeSpec.fromJson(j)],
    outlets: [for (final j in catalog['outlets'] ?? const []) OutletSpec.fromJson(j)],
    tapes: [for (final j in catalog['tapes'] ?? const []) TapeSpec.fromJson(j)],
    valves: [for (final j in catalog['valves'] ?? const []) ValveSpec.fromJson(j)],
    pumps: [for (final j in catalog['pumps'] ?? const []) PumpSpec.fromJson(j)],
  );
  if (rate != null) scaleCatalogPrices(incoming, rate);
  // the same product whatever its price: the technical data compared
  String technical(Map<String, dynamic> j) => jsonEncode(Map<String, dynamic>.of(j)..removeWhere((k, _) => k == 'cost' || k == 'enabled'));
  void take<T>(List<T> mine, List<T> theirs, T? Function(String) find, Map<String, dynamic> Function(T) json, T Function(Map<String, dynamic>) read) {
    for (final t in theirs) {
      final j = json(t);
      final id = j['id'] as String;
      final have = find(id);
      if (have == null) {
        mine.add(t);
      } else if (technical(json(have)) != technical(j)) {
        var k = 2;
        while (_taken(cat, '$id~$k')) {
          k++;
        }
        final fresh = '$id~$k';
        renamed[id] = fresh;
        mine.add(read(Map<String, dynamic>.of(j)..['id'] = fresh));
      }
    }
  }

  take<PipeSpec>(cat.pipes, incoming.pipes, cat.pipe, (x) => x.toJson(), PipeSpec.fromJson);
  take<OutletSpec>(cat.outlets, incoming.outlets, cat.outlet, (x) => x.toJson(), OutletSpec.fromJson);
  take<TapeSpec>(cat.tapes, incoming.tapes, cat.tape, (x) => x.toJson(), TapeSpec.fromJson);
  take<ValveSpec>(cat.valves, incoming.valves, cat.valve, (x) => x.toJson(), ValveSpec.fromJson);
  take<PumpSpec>(cat.pumps, incoming.pumps, cat.pump, (x) => x.toJson(), PumpSpec.fromJson);
  String? item(String? id) => id == null ? null : (renamed[id] ?? id);

  // ---- the entities, with new ids
  final read = <Entity>[];
  for (final j in entities) {
    try {
      read.add(Entity.fromJson(j));
    } catch (_) {
      // an item this version cannot read stays out of the paste
    }
  }
  final newIds = {for (final e in read) e.id: p.newId()};
  // valve-in-head stations of another project: a name the target already
  // uses gets a free one (heads sharing a station keep sharing it)
  final stations = <String, String>{};
  final usedStations = sameProject
      ? <String>{}
      : {
          for (final o in p.entities.whereType<OutletEntity>())
            if (o.scope == HydraulicScope.mainline && o.zoneName.isNotEmpty) o.zoneName,
        };
  String station(String name) {
    if (sameProject || name.isEmpty || !usedStations.contains(name)) return name;
    return stations.putIfAbsent(name, () {
      final n = int.tryParse(name.trim());
      var k = n != null ? n + 1 : 2;
      String candidate(int i) => n != null ? '$i' : '$name ($i)';
      while (usedStations.contains(candidate(k)) || stations.containsValue(candidate(k))) {
        k++;
      }
      return candidate(k);
    });
  }

  final ids = <String>[];
  for (final src in read) {
    final copy = src.clone(newId: newIds[src.id]);
    final e = place == null ? copy.translated(offset) : copy.transformed(place);
    switch (e) {
      case PipeEntity x:
        x.pipeSpecId = item(x.pipeSpecId);
      case SpraylineEntity x:
        x
          ..pipeSpecId = item(x.pipeSpecId)
          ..outletSpecId = item(x.outletSpecId)!;
      case TapeEntity x:
        x.tapeSpecId = item(x.tapeSpecId)!;
      case OutletEntity x:
        x.outletSpecId = item(x.outletSpecId)!;
        if (x.scope == HydraulicScope.mainline) x.zoneName = station(x.zoneName);
      case ControlValveEntity x:
        x.valveSpecId = item(x.valveSpecId);
      case MiscHydraulicEntity x:
        x.valveSpecId = item(x.valveSpecId);
      case PumpEntity x:
        x.pumpSpecId = item(x.pumpSpecId);
        if (rate != null) x.hourMeterCost *= rate;
      case PivotEntity x:
        x
          ..pipeSpecId = item(x.pipeSpecId)
          ..sprinklerSpecId = item(x.sprinklerSpecId)
          ..regulatorSpecId = item(x.regulatorSpecId);
        final m = x.machine;
        m.endGunSpecId = item(m.endGunSpecId);
        // the guide of the corner arm and the variable-rate zones are other
        // entities: their copies when pasted with it, else (in another
        // project, where those ids mean other things) none
        final guide = m.guidePathId;
        if (guide != null) m.guidePathId = newIds[guide] ?? (sameProject ? guide : null);
        final zones = Map.of(m.vriZones);
        m.vriZones
          ..clear()
          ..addAll({
            for (final z in zones.entries)
              if (newIds[z.key] != null || sameProject) newIds[z.key] ?? z.key: z.value,
          });
        if (rate != null) {
          x
            ..machineCost *= rate
            ..towerCost *= rate;
        }
      case ControllerEntity x:
        if (rate != null) {
          x.cost *= rate;
          x.accessories.updateAll((_, v) => v * rate);
        }
      default:
        break;
    }
    p.entities.add(e);
    ids.add(e.id);
  }
  return PasteResult(ids: ids, renamedItems: renamed, rate: rate, idMap: newIds, renamedStations: stations);
}

bool _taken(Catalog c, String id) => c.pipe(id) != null || c.outlet(id) != null || c.tape(id) != null || c.valve(id) != null || c.pump(id) != null || c.fitting(id) != null || c.wire(id) != null;

/// The catalogue items [entities] use, by group (`pipes`, `outlets`,
/// `tapes`, `valves`, `pumps`), as JSON: what a copy carries along.
Map<String, List<Map<String, dynamic>>> catalogSubset(Catalog cat, Iterable<Entity> entities) {
  final pipes = <String>{}, outlets = <String>{}, tapes = <String>{}, valves = <String>{}, pumps = <String>{};
  for (final e in entities) {
    switch (e) {
      case PipeEntity x:
        if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
      case SpraylineEntity x:
        if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
        outlets.add(x.outletSpecId);
      case TapeEntity x:
        tapes.add(x.tapeSpecId);
      case OutletEntity x:
        outlets.add(x.outletSpecId);
      case ControlValveEntity x:
        if (x.valveSpecId != null) valves.add(x.valveSpecId!);
      case MiscHydraulicEntity x:
        if (x.valveSpecId != null) valves.add(x.valveSpecId!);
      case PumpEntity x:
        if (x.pumpSpecId != null) pumps.add(x.pumpSpecId!);
      case PivotEntity x:
        if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
        if (x.sprinklerSpecId != null) outlets.add(x.sprinklerSpecId!);
        if (x.regulatorSpecId != null) valves.add(x.regulatorSpecId!);
        if (x.machine.endGunSpecId != null) outlets.add(x.machine.endGunSpecId!);
      default:
        break;
    }
  }
  return {
    'pipes': [for (final id in pipes) ?cat.pipe(id)?.toJson()],
    'outlets': [for (final id in outlets) ?cat.outlet(id)?.toJson()],
    'tapes': [for (final id in tapes) ?cat.tape(id)?.toJson()],
    'valves': [for (final id in valves) ?cat.valve(id)?.toJson()],
    'pumps': [for (final id in pumps) ?cat.pump(id)?.toJson()],
  };
}
