/// The layer a new item goes to when none is given: the one the app's
/// drawing tools use for its type. The assistant of the app
/// (lib/app/ai/agent_tools_edit.dart) and the MCP server's edit_entities
/// (lib/core/mcp/oci_mcp_tools.dart) both take it from here.
library;

import 'entities.dart';

/// The default layer of an item like [e] (a pipe by its scope).
String defaultLayerFor(Entity e) => switch (e) {
  PipeEntity p => p.scope == HydraulicScope.zone ? Layers.zonePipes : Layers.mainlinePipes,
  SpraylineEntity _ => Layers.spraylines,
  TapeEntity _ => Layers.tapes,
  OutletEntity _ => Layers.outlets,
  ControlValveEntity _ => Layers.controlValves,
  WaterSupplyEntity _ => Layers.waterSupply,
  PumpEntity _ => Layers.pumps,
  MiscHydraulicEntity _ => Layers.misc,
  JunctionEntity _ => Layers.junctions,
  PivotEntity _ => Layers.pivots,
  // 1.6.0 AGB
  TravellerEntity _ => Layers.travellers,
  FurrowEntity _ => Layers.surface,
  AreaEntity _ => Layers.areas,
  ControllerEntity _ => Layers.controllers,
  WireEntity _ => Layers.wires,
  ContourEntity _ => Layers.contours,
  SpotHeightEntity _ => Layers.spotHeights,
  BreaklineEntity _ => Layers.breaklines,
  TextEntity _ => Layers.text,
  LeaderEntity _ => Layers.dimensions,
  SymbolEntity _ => Layers.symbols,
  HatchEntity _ => Layers.hatches,
  CommentEntity _ => Layers.comments,
  _ => Layers.drawing,
};
