/// Operations (find_operations / run_operation) added in 1.6.0 for the site and the web app:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/io/data_credits.dart';
import '../../i18n.dart';
import '../../io/field_map.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart';
import '../vision_tiles.dart' show mapSourceName;

final I18n _en = I18n('en');

List<AgentTool> opsSit(AgentToolbox b) {
  final c = b.c;
  return [
    // ---- Help → Terms of the data (PRD-06)
    cadOp(
      b,
      group: 'help',
      name: 'read_data_terms',
      description: 'Reads the terms of the third-party data in professional work, as Help → Terms of the data shows them: the data of this project that came from other sources (online elevation, the downloaded climate, base map pictures kept for the field) with the credit each asks for and what its free use allows, then every source of elevation, climate and address search the app reaches, with its credit, terms and link, and what the base map on screen allows for a map kept for the field. The free Open-Meteo services are for non-commercial use: for professional work NASA POWER (climate) and Terrain Tiles (elevation) are free for any use. The base maps have their own terms (View → Base map → Terms of the maps); the sheets and the report print the credits. Read-only.',
      schema: obj({}),
      run: (a, i) async {
        final out = StringBuffer('# Third-party data and their terms\n');
        final used = projectDataCredits(c.project);
        out.writeln(used.isEmpty ? 'This project carries no third-party data (no online elevation, downloaded climate or kept base map picture).' : 'In this project:');
        for (final u in used) {
          out.writeln('- ${_en('src.kind.${u.kind.name}')}: ${u.source}. Credit: ${u.credit}. Free use: ${_en('src.use.${u.use.name}')}.');
        }
        out.writeln('\nSources the app reaches:');
        for (final s in dataSources) {
          out.writeln('- ${s.name} (${_en('src.kind.${s.kind.name}')}): ${_en('terms.src.${s.id}')} Credit: ${s.credit}. Terms: ${s.url}');
        }
        out.writeln('\nBase map on screen: ${mapSourceName(c.baseMap)}. Kept for the field: ${_en('fieldmap.policy.${fieldMapSource(c.baseMap).name}')}');
        return ToolOutput(out.toString());
      },
    ),
    // ---- View → Base map → Keep the map of the area for the field (PRD-09)
    cadOp(
      b,
      group: 'view',
      name: 'keep_field_map',
      description: 'Keeps the map of the area for the field, as View → Base map → Keep the map of the area for the field does: draws the base map under the drawing into one picture added to the project (IMAGES layer, one undo step) and saved with it, so the map is there with no network. Only what the provider allows: for OpenStreetMap, OpenTopoMap, CARTO and Esri only the tiles this page has already shown are used, and none is downloaded (the user zooms and pans over the area at the detail wanted first; places never shown stay white); the user\'s own tile server (the custom template) is downloaded for the area; the Google maps are refused (their terms forbid keeping them). Needs a georeference and a base map on screen.',
      schema: obj({}),
      effect: ToolEffect.write,
      effectFor: (i) => fieldMapSource(c.baseMap) == FieldMapSource.download ? ToolEffect.network : ToolEffect.write,
      run: (a, i) async {
        try {
          final r = await keepFieldMap(c);
          final left = r.missing > 0 ? ', ${r.missing} places never shown left white' : '';
          return ToolOutput(
            'Kept the ${mapSourceName(c.baseMap)} map of the area as picture ${r.image.id} (${cadN(r.image.width, 0)} × ${cadN(r.image.height, 0)} m, ${r.tiles} tiles at zoom ${r.zoom}$left); credit: ${baseMapPictureCredit(r.image)}.',
          );
        } on FieldMapError catch (e) {
          throw ToolInputError(_en(e.key));
        }
      },
    ),
  ];
}
