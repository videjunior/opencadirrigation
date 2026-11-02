/// Operations (find_operations / run_operation) added in 1.6.0 for drawing state, storage and editing:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
///
/// CAD+ (wave 2): Lengthen, the outline by a click inside, the named layer
/// states and isolating layers, the drawing order, the dimension style, the
/// block references (attributes, explode, edit in place, the library as a
/// file), the comparison with another copy of the project and the comments
/// of a returned copy, the photo of a comment.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/results.dart' show DesignResults;
import '../../../core/model/blocks.dart';
import '../../../core/model/dim_style.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/layer_states.dart';
import '../../../core/model/lengthen.dart';
import '../../../core/model/project.dart';
import '../../../core/model/project_compare.dart';
import '../../../core/units.dart';
import '../../canvas/compare_overlay.dart';
import '../../tools/cad_plus_commands.dart';
import '../../tools/cad_plus_tools.dart';
import '../../tools/insert_block_tool.dart';
import '../../state/controller.dart';
import '../../widgets/dialogs/cad_plus_dialogs.dart' show BlockLibraryCommands, ReviewCommands, exportBlockLibraryAction;
import '../agent_tools.dart';
import '../ai_assistant.dart' show AiAssistant;
import '../ops_cad_common.dart';

List<AgentTool> opsCad(AgentToolbox b) {
  final c = b.c;
  Map<String, String> one(Map<String, dynamic> i, [String key = 'id']) => {'n': '${i[key] ?? ''}'};
  Map<String, String> many(Map<String, dynamic> i, [String key = 'ids']) => {'n': '${(i[key] as List?)?.length ?? 0}'};

  /// The attached file [name] (any case), or an error naming those attached.
  (String, Uint8List) attached(String name) {
    final files = b.host?.files ?? const {};
    final hit = files.entries.where((e) => e.key == name || e.key.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (hit == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
    return (hit.key, hit.value);
  }

  Project projectOf(String name) {
    final (_, bytes) = attached(name);
    try {
      return Project.fromJson((jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>());
    } on Object {
      throw ToolInputError('"$name" is not a project file (.oci.json).');
    }
  }

  String comparisonText(ProjectComparison cmp, String label) {
    final kinds = [for (final k in ChangeKind.values) '${cmp.count(k)} ${k.name}'].join(', ');
    final figs = [
      for (final f in cmp.figures)
        if (f.before != null || f.after != null) '${f.key}: ${f.before == null ? '-' : cadN(f.before!)} → ${f.after == null ? '-' : cadN(f.after!)}${f.unit.isEmpty ? '' : ' ${f.unit}'}',
    ].join('; ');
    String item(EntityChange ch) {
      final name = ch.name.isEmpty ? '' : ' "${ch.name}"';
      final fields = ch.keys.isEmpty ? '' : ' fields ${ch.keys.take(8).join(', ')}';
      return '${ch.kind.name} ${ch.id} (${ch.type}$name)$fields';
    }

    final items = [for (final ch in cmp.changes.take(80)) item(ch)].join('\n');
    final settings = cmp.settings.isEmpty ? '' : ' Settings that differ: ${cmp.settings.join(', ')}.';
    final more = cmp.changes.length > 80 ? '\n… ${cmp.changes.length - 80} more.' : '';
    return 'Compared with $label: $kinds.$settings\nFigures (before → now): $figs.${items.isEmpty ? '' : '\nItems:\n$items'}$more';
  }

  return [
    // ------------------------------------------------ lengthen and outline
    cadOp(
      b,
      group: 'edit',
      name: 'lengthen_entity',
      effect: ToolEffect.write,
      description: 'Edit → Lengthen (LEN): changes the length of a line, open polyline, pipe, lateral, tape, wire, contour or arc at its end nearest to "at": mode "delta" adds "value" metres (negative shortens), "total" makes it "value" metres long, "percent" makes it "value" % of its length. A longer item grows along its end segment (an arc along its circle); a lateral keeps its outlets where they were. One undo step.',
      schema: obj(
        {
          'id': str('Item (id or name).'),
          'at': pointWith('A point near the end to change (m).'),
          'mode': str('How "value" is read (default "delta").', [for (final m in LengthenMode.values) m.name]),
          'value': num_('Metres (delta, total) or percent.'),
        },
        required: ['id', 'at', 'value'],
      ),
      args: one,
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        if (!canLengthen(e)) throw ToolInputError('${e.id} (${b.kindOf(e)}) cannot be lengthened: lines, open polylines, pipes, laterals, tapes, wires, contours and arcs can.');
        final mode = LengthenMode.values.asNameMap()[a.str('mode') ?? 'delta'] ?? LengthenMode.delta;
        final before = lengthOfLengthenable(e)!;
        if (!c.lengthenAt(e.id, a.point('at', required: true)!, mode: mode, value: a.number('value', required: true)!)) {
          throw ToolInputError('Not lengthened: the new length would be zero or less (it is ${cadN(before)} m now), or a design is running.');
        }
        return ToolOutput('Lengthened ${e.id}: ${cadN(before)} m → ${cadN(lengthOfLengthenable(b.p.byId(e.id)!) ?? 0)} m.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'boundary_at',
      effect: ToolEffect.write,
      description: 'Edit → Outline by a click inside (BO): the smallest region around "at" that the visible lines, polylines, arcs, circles and outlines close becomes a closed polyline on the current layer ("as": "polyline", the default) or an irrigated area ("area"). Fails when the lines leave a gap there. One undo step; returns the new item and its area.',
      schema: obj(
        {
          'at': pointWith('A point inside the region (m).'),
          'as': str('What to make (default "polyline").', ['polyline', 'area']),
        },
        required: ['at'],
      ),
      args: (i) => {'n': '${i['as'] ?? 'polyline'}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = c.boundaryAt(a.point('at', required: true)!, asArea: a.str('as') == 'area');
        if (e == null) throw ToolInputError('No closed region around ${cadPt(a.point('at')!)}: the lines leave a gap there (or the point lies on a line).');
        final area = (e as PolyEntity).points;
        return ToolOutput('Made ${e.id} (${b.kindOf(e)}), ${area.length} vertices, ${c.fmtArea(polygonArea(area).abs())}.');
      },
    ),
    // ------------------------------------------------ layers
    cadOp(
      b,
      group: 'layers',
      name: 'layer_states',
      description: 'View → Layers → Layer states: lists the named states of the layers kept in the project (which layers are shown and locked), and whether layers are isolated now. save_layer_state keeps one, restore_layer_state puts one back.',
      schema: obj({}),
      run: (a, i) async {
        final states = b.p.layerStates;
        String names(LayerState s, bool locked) => [
          for (final e in s.layers.entries)
            if (locked ? e.value.$2 : e.value.$1) e.key,
        ].join(', ');
        final isolated = c.layersIsolated ? '\nLayers are isolated now (unisolate_layers shows them again).' : '';
        if (states.isEmpty) return ToolOutput('No layer states.$isolated');
        return ToolOutput('${[for (final s in states) '"${s.name}": shown ${names(s, false)}; locked ${names(s, true)}'].join('\n')}$isolated');
      },
    ),
    cadOp(
      b,
      group: 'layers',
      name: 'save_layer_state',
      effect: ToolEffect.write,
      description: 'View → Layers → Layer states → Save: keeps which layers are shown and locked now under "name" (a state of that name is replaced), e.g. "hydraulic sheet". One undo step.',
      schema: obj({'name': str('Name of the state.')}, required: ['name']),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final name = a.str('name', required: true)!.trim();
        if (name.isEmpty || !c.saveLayerState(name)) throw ToolInputError('Not saved (an empty name, or a design is running).');
        return ToolOutput('Saved layer state "$name".');
      },
    ),
    cadOp(
      b,
      group: 'layers',
      name: 'restore_layer_state',
      effect: ToolEffect.write,
      description: 'View → Layers → Layer states → Restore: shows, hides, locks and unlocks the layers as the state "name" keeps them (layers made after it stay as they are). Not an undo step (as the eye and the lock of the layers panel).',
      schema: obj({'name': str('Name of the state (layer_states lists them).')}, required: ['name']),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        final name = a.str('name', required: true)!;
        if (!c.restoreLayerState(name)) throw ToolInputError('No layer state "$name". States: ${b.p.layerStates.map((s) => s.name).join(', ')}.');
        return ToolOutput('Layers as in "$name".');
      },
    ),
    cadOp(
      b,
      group: 'layers',
      name: 'delete_layer_state',
      effect: ToolEffect.write,
      description: 'View → Layers → Layer states → Delete: removes the state "name" from the project. One undo step.',
      schema: obj({'name': str('Name of the state.')}, required: ['name']),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final name = a.str('name', required: true)!;
        if (!c.deleteLayerState(name)) throw ToolInputError('No layer state "$name".');
        return ToolOutput('Deleted layer state "$name".');
      },
    ),
    cadOp(
      b,
      group: 'layers',
      name: 'isolate_layers',
      effect: ToolEffect.write,
      description: 'View → Layers → Isolate (LAYISO): shows only the layers given (default: those of the selection, else the current layer), remembering how every layer was; unisolate_layers puts them back. Not an undo step.',
      schema: obj({'layers': arr(str(), 'Layer names to keep shown.', 100)}),
      args: (i) => {'n': (i['layers'] as List?)?.join(', ') ?? ''},
      run: (a, i) async {
        final names = a.strings('layers');
        for (final n in names) {
          if (b.p.findLayer(n) == null) throw ToolInputError('No layer "$n" (list_layers).');
        }
        final shown = c.isolateLayers(names.isEmpty ? null : names);
        return ToolOutput(
          '$shown layer${shown == 1 ? '' : 's'} shown: ${[for (final l in b.p.layers)
            if (l.visible) l.name].join(', ')}.',
        );
      },
    ),
    cadOp(
      b,
      group: 'layers',
      name: 'unisolate_layers',
      effect: ToolEffect.write,
      description: 'View → Layers → Show all (LAYUNISO): the layers as they were before isolate_layers (every layer shown when none were isolated in this tab). Not an undo step.',
      schema: obj({}),
      run: (a, i) async {
        c.unisolateLayers();
        return ToolOutput(
          'Layers shown: ${[for (final l in b.p.layers)
            if (l.visible) l.name].join(', ')}.',
        );
      },
    ),
    // ------------------------------------------------ drawing order
    cadOp(
      b,
      group: 'edit',
      name: 'draw_order',
      effect: ToolEffect.write,
      description: 'Edit → Drawing order (TOFRONT, TOBACK): brings the items to the front of the drawing ("to": "front") or sends them behind the others ("back") — a picture under the drawing, a hatch or an area over another of its kind. One undo step.',
      schema: obj(
        {
          'ids': idsWith('Items (ids or names).', maxItems: 2000),
          'to': str('Where to (default "front").', ['front', 'back']),
        },
        required: ['ids'],
      ),
      args: many,
      run: (a, i) async {
        cadNotBusy(b);
        final es = b.findAll(a.strings('ids', required: true));
        final n = c.reorder(ids: es.map((e) => e.id), back: a.str('to') == 'back');
        if (n == 0) throw ToolInputError('Nothing moved (a design is running).');
        return ToolOutput('Moved $n item${n == 1 ? '' : 's'} to the ${a.str('to') == 'back' ? 'back' : 'front'}.');
      },
    ),
    // ------------------------------------------------ dimension style
    cadOp(
      b,
      group: 'annotate',
      name: 'dim_style',
      effectFor: (i) => i.keys.any((k) => k != 'reset') || i['reset'] == true ? ToolEffect.write : ToolEffect.read,
      description: 'Draw → Dimension style: with no input, reads the style of every dimension of the project; with fields, sets them (one undo step): "text_height_m" (0 = the size of the labels), "arrow" (none, arrow, tick, dot), "arrow_size_m" (0 = the text height), "decimals" (0–6), "unit" (m, cm, mm, ft, inch; "project" follows the project), "show_unit"; "reset" true goes back to the program\'s style.',
      schema: obj({
        'text_height_m': num_('Text height in metres of the drawing (0 = label size).'),
        'arrow': str('Ends of the dimension lines.', [for (final x in DimArrow.values) x.name]),
        'arrow_size_m': num_('Arrowhead length in metres (0 = text height).'),
        'decimals': int_('0–6.'),
        'unit': str('Unit of the lengths.', ['project', for (final u in LengthUnit.values) u.name]),
        'show_unit': bool_('Write the unit after the value.'),
        'reset': bool_('Back to the program\'s style.'),
      }),
      args: (i) => {'n': i.isEmpty ? '' : i.keys.join(', ')},
      run: (a, i) async {
        String describe(DimStyle s) {
          final text = s.textHeightM == 0 ? 'label size' : '${cadN(s.textHeightM, 3)} m';
          final arrows = '${s.arrow.name}${s.arrowSizeM > 0 ? ' ${cadN(s.arrowSizeM, 3)} m' : ''}';
          final unit = '${s.unit?.name ?? 'project'}, ${s.showUnit ? 'written' : 'left out'}';
          return 'text $text, arrows $arrows, ${s.decimals} decimals, unit $unit (12.5 m reads "${s.length(12.5, c.units)}")';
        }

        if (i.isEmpty) return ToolOutput('Dimension style: ${describe(b.p.dimStyle)}.');
        cadNotBusy(b);
        var s = a.flag('reset') ?? false ? DimStyle.standard : b.p.dimStyle;
        final u = a.str('unit');
        s = s.copyWith(
          textHeightM: a.number('text_height_m', min: 0, max: 1000),
          arrow: DimArrow.values.asNameMap()[a.str('arrow')],
          arrowSizeM: a.number('arrow_size_m', min: 0, max: 1000),
          decimals: a.integer('decimals', min: 0, max: 6),
          unit: u == null ? null : LengthUnit.values.asNameMap()[u],
          clearUnit: u == 'project',
          showUnit: a.flag('show_unit'),
        );
        c.setDimStyle(s);
        return ToolOutput('Dimension style: ${describe(b.p.dimStyle)}.');
      },
    ),
    // ------------------------------------------------ block references
    cadOp(
      b,
      group: 'blocks',
      name: 'set_block_attributes',
      effect: ToolEffect.write,
      description: 'Sets attribute values of a block reference (a code, a flow, a name the block asks for): "values" {TAG: value}; a value equal to the block\'s default is not kept, "" clears it. The visible attributes are written on the drawing; a block of the bill of materials counts its references by code. One undo step.',
      schema: obj(
        {
          'id': str('The block reference (id or name).'),
          'values': {'type': 'object', 'description': 'Attribute values by tag, e.g. {"CODE": "CX-01"}.', 'additionalProperties': str()},
        },
        required: ['id', 'values'],
      ),
      args: one,
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        if (e is! BlockRefEntity) throw ToolInputError('${e.id} is a ${b.kindOf(e)}, not a block reference.');
        final d = e.definition ?? b.p.blocks.byName(e.blockName);
        if (d == null) throw ToolInputError('The block "${e.blockName}" of ${e.id} is not in the library (list_blocks).');
        final raw = i['values'];
        if (raw is! Map) throw ToolInputError('"values" must be an object {TAG: value}.');
        final values = {for (final x in raw.entries) BlockAttributeDef.tagOf('${x.key}'): '${x.value ?? ''}'};
        final unknown = [
          for (final k in values.keys)
            if (d.attributeOf(k) == null) k,
        ];
        if (unknown.isNotEmpty) throw ToolInputError('Block "${e.blockName}" has no attribute ${unknown.join(', ')}; it has ${d.attributes.map((x) => x.tag).join(', ')}.');
        c.setBlockAttributes(e.id, values);
        return ToolOutput('Attributes of ${e.id}: ${[for (final x in d.attributes) '${x.tag}=${e.attribute(x.tag)}'].join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'define_block_attributes',
      effect: ToolEffect.write,
      description: 'Sets the attributes of block "name" (what each reference fills in: tag, prompt, default, visible, height_m, and [x, y] in block coordinates — by default one under the other right of the block) and whether its references count in the bill of materials ("in_bom"; a CODE attribute gives the item code, PRICE the unit price). Every reference follows. One undo step.',
      schema: obj(
        {
          'name': str('Block name (list_blocks).'),
          'attributes': arr(
            obj(
              {
                'tag': str('Tag, e.g. CODE, FLOW.'),
                'prompt': str(),
                'default': str(),
                'visible': bool_('Written on the drawing (default true).'),
                'height_m': num_('Text height (default 0.5).'),
                'at': pointWith('Where its value is written, in block coordinates.'),
              },
              required: ['tag'],
            ),
            'The attributes, in order (they replace the block\'s).',
            50,
          ),
          'in_bom': bool_('The references count in the bill of materials.'),
        },
        required: ['name'],
      ),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final name = a.str('name', required: true)!;
        final old = b.p.blocks.byName(name);
        if (old == null) throw ToolInputError('No block "$name". Blocks: ${b.p.blocks.blocks.map((x) => x.name).join(', ')}.');
        var attrs = old.attributes;
        final raw = i['attributes'];
        if (raw is List) {
          attrs = [];
          for (var k = 0; k < raw.length; k++) {
            final m = raw[k] is Map ? (raw[k] as Map).cast<String, dynamic>() : const <String, dynamic>{};
            final x = ToolArgs(m);
            final tag = BlockAttributeDef.tagOf(x.str('tag', required: true)!);
            if (tag.isEmpty) throw ToolInputError('attributes[$k] has no tag.');
            final h = x.number('height_m', min: 0.001, max: 1000) ?? 0.5;
            attrs.add(
              BlockAttributeDef(
                tag: tag,
                prompt: x.str('prompt') ?? tag,
                defaultValue: x.str('default') ?? '',
                visible: x.flag('visible') ?? true,
                height: h,
                position: x.point('at') ?? old.defaultAttributePosition(k, height: h),
              ),
            );
          }
        }
        if (!c.saveBlock(b.p.blocks, old.copyWith(attributes: attrs, inBom: a.flag('in_bom')))) throw ToolInputError('Not changed (a design is running).');
        return ToolOutput('Block "$name": attributes ${attrs.map((x) => x.tag).join(', ')}${(a.flag('in_bom') ?? old.inBom) ? '; counted in the bill of materials' : ''}.');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'explode_block_refs',
      effect: ToolEffect.write,
      description:
          'Edit → Blocks → Explode references: turns block references into copies of what they draw (their attributes become texts), which then change one by one. One undo step; returns the new ids.',
      schema: obj({'ids': idsWith('Block references (ids or names).', maxItems: 2000)}, required: ['ids']),
      args: many,
      run: (a, i) async {
        cadNotBusy(b);
        final es = cadEditable(b, a.strings('ids', required: true)).whereType<BlockRefEntity>().toList();
        if (es.isEmpty) throw ToolInputError('None of these is a block reference.');
        final before = cadIds(b);
        c.explodeBlockRefs(es.map((e) => e.id));
        return ToolOutput('Exploded ${es.length} reference${es.length == 1 ? '' : 's'}.\n${cadMade(b, cadAdded(b, before))}');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'edit_block_in_place',
      effect: ToolEffect.write,
      description: 'Edit → Blocks → Edit block in place (BEDIT), in steps: "start" with the reference "id" turns it into copies (they become the selection; change them with the other operations), "save" makes the selected items (or the copies) the block\'s new definition — every reference of the block follows — and "cancel" undoes the edit. One undo step each.',
      schema: obj(
        {
          'step': str('start, save or cancel.', ['start', 'save', 'cancel']),
          'id': str('The block reference to edit (step "start").'),
        },
        required: ['step'],
      ),
      args: (i) => {'n': '${i['step']}'},
      run: (a, i) async {
        cadNotBusy(b);
        switch (a.str('step', required: true)) {
          case 'start':
            final e = cadEditable(b, [a.str('id', required: true)!]).first;
            if (e is! BlockRefEntity || !c.startBlockEdit(e.id)) throw ToolInputError('${e.id} is not a block reference whose block is in the library.');
            return ToolOutput('Editing block "${e.blockName}": the copies are ${c.selection.join(', ')}. Change them, then step "save".');
          case 'save':
            final s = c.blockEdit;
            if (s == null) throw ToolInputError('No block is being edited (step "start" first).');
            if (!c.saveBlockEdit()) {
              throw ToolInputError('Not saved: a block reference holds drawing items only (lines, polylines, circles, arcs, splines, hatches, symbols, texts, dimensions, leaders).');
            }
            return ToolOutput('Block "${s.blockName}" redefined; every reference follows.');
          default:
            if (c.blockEdit == null) throw ToolInputError('No block is being edited.');
            c.cancelBlockEdit();
            return ToolOutput('Edit of the block cancelled.');
        }
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'export_block_library',
      effect: ToolEffect.export,
      description: 'Edit → Blocks → Export the library: downloads every block of the project (with its attributes) as a .oci-blocks.json file to bring into other projects (import_block_library).',
      schema: obj({}),
      run: (a, i) async {
        if (b.p.blocks.isEmpty) throw ToolInputError('The project has no blocks.');
        await exportBlockLibraryAction(c);
        return ToolOutput('Exported ${b.p.blocks.length} blocks.');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'import_block_library',
      effect: ToolEffect.write,
      description: 'Edit → Blocks → Import a library: the blocks of a block library file (.oci-blocks.json) or of a project file the user attached, by its file name, go into the project\'s library; a block of a name already there is redefined (its references follow). One undo step.',
      schema: obj({'file': str('File name of the attachment.')}, required: ['file']),
      args: (i) => {'n': '${i['file']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final (name, bytes) = attached(a.str('file', required: true)!);
        List<BlockDefinition> blocks;
        try {
          blocks = blockLibraryFromJson(jsonDecode(utf8.decode(bytes)));
        } on Object {
          throw ToolInputError('"$name" is no block library or project file.');
        }
        final n = c.importBlockLibrary(blocks);
        if (n == 0) throw ToolInputError('No block came from "$name".');
        return ToolOutput('Imported $n blocks: ${blocks.map((x) => x.name).join(', ')}.');
      },
    ),
    // ------------------------------------------------ review without a server
    cadOp(
      b,
      group: 'review',
      name: 'compare_project',
      description: 'File → Compare with…: what changed between another copy of this project — a version kept in the browser ("version", from list_versions or the versions dialog), another open tab ("tab", its name) or a project file the user attached ("file") — and the drawing open: items added, removed and changed (by id, with the fields that differ), the settings that differ and the main figures of both (lengths, outlets, valves, areas and, with results, flow, pressures and cost). "show" true frames the differences on the drawing until the next edit.',
      schema: obj({
        'version': int_('A version of this project kept in the browser.'),
        'tab': str('The name of another open tab.'),
        'file': str('File name of an attached project file.'),
        'show': bool_('Frame the differences on the drawing.'),
      }),
      args: (i) => {'n': '${i['version'] ?? i['tab'] ?? i['file'] ?? ''}'},
      run: (a, i) async {
        Project other;
        String label;
        DesignResults? otherResults;
        final v = a.integer('version', min: 1);
        final tab = a.str('tab');
        final file = a.str('file');
        if (v != null) {
          final json = await c.store.load(b.p.meta.uid, version: v);
          if (json == null) throw ToolInputError('No version $v of this project in the browser (versions: ${c.store.versions(b.p.meta.uid).map((x) => x.version).join(', ')}).');
          final m = (jsonDecode(json) as Map).cast<String, dynamic>();
          other = Project.fromJson(m);
          otherResults = m['results'] is Map ? DesignResults.fromJson((m['results'] as Map).cast<String, dynamic>()) : null;
          label = 'version $v';
        } else if (tab != null) {
          ProjectController? x;
          for (final o in AiAssistant.workspace?.tabs ?? const <ProjectController>[]) {
            if (!identical(o, c) && o.project.meta.name.trim().toLowerCase() == tab.trim().toLowerCase()) x = o;
          }
          if (x == null) throw ToolInputError('No other open tab "$tab".');
          other = x.project;
          otherResults = x.results;
          label = 'tab "$tab"';
        } else if (file != null) {
          other = projectOf(file);
          label = 'file "$file"';
        } else {
          throw ToolInputError('Give "version", "tab" or "file".');
        }
        final cmp = compareProjects(other, b.p, beforeResults: otherResults, afterResults: c.results);
        if (a.flag('show') ?? false) c.showComparison(cmp);
        return ToolOutput(comparisonText(cmp, label));
      },
    ),
    cadOp(
      b,
      group: 'review',
      name: 'import_review_comments',
      effect: ToolEffect.write,
      description: 'File → Bring back the comments of a copy: the review comments and revision clouds of a copy of this project sent for review and returned (a project file the user attached) come into the drawing — one of the same id is updated (text, resolved, photo, place), one at the same place with the same text is already there, the others are added. One undo step; returns how many came.',
      schema: obj({'file': str('File name of the attached project file.')}, required: ['file']),
      args: (i) => {'n': '${i['file']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final r = c.importReview(projectOf(a.str('file', required: true)!));
        if (r == null) return ToolOutput('Nothing new: every comment and cloud of the copy is already in the drawing.');
        return ToolOutput('Comments of the copy: ${r.added} added, ${r.updated} updated, ${r.unchanged} already here; ids ${r.ids.take(60).join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'review',
      name: 'open_version_in_tab',
      effect: ToolEffect.write,
      description: 'Versions → Open in a new tab: a version of this project kept in the browser opens in a tab of its own, as a separate copy (its own name and history), beside the drawing open; the assistant stays on this project.',
      schema: obj({'version': int_('The version number.')}, required: ['version']),
      args: (i) => {'n': '${i['version']}'},
      run: (a, i) async {
        final v = a.integer('version', min: 1, required: true)!;
        final json = await c.store.load(b.p.meta.uid, version: v);
        if (json == null) throw ToolInputError('No version $v of this project in the browser.');
        final p = Project.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
        p.meta.name = c.t('cmp.versionName', {'n': p.meta.name, 'v': '$v'});
        if (!(b.host?.openTab(p) ?? false)) throw ToolInputError('Tabs are not available here.');
        return ToolOutput('Version $v opened in a new tab as "${p.meta.name}".');
      },
    ),
    cadOp(
      b,
      group: 'review',
      name: 'set_comment_photo',
      effect: ToolEffect.write,
      description: 'Puts a photo the user attached on an existing review comment (or replaces its photo): a small copy is kept with the comment; "move" true takes the comment to where the photo\'s GPS says (needs a georeference). add_photo_comment makes a new comment instead. One undo step.',
      schema: obj({'id': str('The comment (id or name).'), 'file': str('File name of the attached photo.'), 'move': bool_('Move the comment to the photo\'s GPS position.')}, required: ['id', 'file']),
      args: one,
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        if (e is! CommentEntity) throw ToolInputError('${e.id} is a ${b.kindOf(e)}, not a review comment.');
        final (name, bytes) = attached(a.str('file', required: true)!);
        if (!c.setCommentPhoto(e.id, bytes, name, move: a.flag('move') ?? false)) throw ToolInputError('"$name" is not a picture this program reads.');
        return ToolOutput('Photo $name on ${e.id}${a.flag('move') ?? false ? ' at ${cadPt((b.p.byId(e.id) as CommentEntity).position)}' : ''}.');
      },
    ),
  ];
}
