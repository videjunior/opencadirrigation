import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import '../tutorial/tutorial.dart';

class ToolPalette extends StatelessWidget {
  const ToolPalette({super.key, required this.c});
  final ProjectController c;

  /// Tool groups (also used by the mobile tool bar).
  static const groups = <(String, List<(ToolId, IconData)>)>[
    ('nav', [(ToolId.select, Icons.near_me_outlined), (ToolId.pan, Icons.pan_tool_alt_outlined), (ToolId.measure, Icons.straighten), (ToolId.profile, Icons.show_chart)]),
    ('draw', [(ToolId.line, Icons.horizontal_rule), (ToolId.polyline, Icons.polyline_outlined), (ToolId.rect, Icons.crop_square), (ToolId.circle, Icons.circle_outlined), (ToolId.arc, Icons.architecture), (ToolId.spline, Icons.gesture), (ToolId.hatch, Icons.texture), (ToolId.symbol, Icons.park_outlined), (ToolId.text, Icons.text_fields), (ToolId.dimension, Icons.space_bar), (ToolId.dimAngular, Icons.square_foot), (ToolId.dimRadial, Icons.radio_button_unchecked), (ToolId.leader, Icons.call_made)]),
    ('edit', [(ToolId.rotate, Icons.rotate_right), (ToolId.mirror, Icons.flip), (ToolId.scale, Icons.open_in_full), (ToolId.offset, Icons.copy_all_outlined), (ToolId.trim, Icons.content_cut), (ToolId.extend, Icons.east), (ToolId.cutPipe, Icons.carpenter_outlined), (ToolId.alignImage, Icons.control_camera)]),
    ('terrain', [(ToolId.contour, Icons.landscape_outlined), (ToolId.spot, Icons.add_location_alt_outlined), (ToolId.area, Icons.grass)]),
    ('zone', [(ToolId.zonePipe, Icons.timeline), (ToolId.sprayline, Icons.linear_scale), (ToolId.tape, Icons.more_horiz), (ToolId.outlet, Icons.water_drop_outlined), (ToolId.valve, Icons.change_history), (ToolId.block, Icons.grid_on), (ToolId.autohead, Icons.apps)]),
    ('main', [(ToolId.supply, Icons.water), (ToolId.mainPipe, Icons.show_chart), (ToolId.pump, Icons.settings), (ToolId.misc, Icons.device_hub), (ToolId.junction, Icons.fiber_manual_record), (ToolId.pivot, Icons.radar)]),
  ];

  @override
  Widget build(BuildContext context) {
    final keys = <String, GlobalKey>{'nav': TutorialTargets.paletteNav, 'draw': TutorialTargets.paletteDraw, 'terrain': TutorialTargets.paletteTerrain, 'zone': TutorialTargets.paletteZone, 'main': TutorialTargets.paletteMain};
    return LayoutBuilder(builder: (context, constraints) {
      // one column when everything fits, otherwise two so the hydraulic
      // groups stay visible without scrolling
      final needed = groups.fold<double>(0, (sum, g) => sum + 12 + g.$2.length * 30.0);
      final cols = constraints.maxHeight < needed ? 2 : 1;
      return Container(
        key: TutorialTargets.palette,
        width: 8 + cols * 36 + (cols - 1) * 2,
        color: const Color(0xFF1B1F24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final g in groups) ...[
                const SizedBox(height: 4),
                Wrap(key: keys[g.$1], spacing: 2, children: [
                  for (final (id, icon) in g.$2)
                    Tooltip(
                      message: toolLabel(c.t, id),
                      child: InkWell(
                        key: Key('tool_${id.name}'),
                        onTap: () {
                          if (g.$1 == 'main' && (id == ToolId.pump || id == ToolId.misc || id == ToolId.junction)) c.toolSettings.pointScope = HydraulicScope.mainline;
                          if (g.$1 == 'zone' && (id == ToolId.outlet || id == ToolId.valve)) c.toolSettings.pointScope = HydraulicScope.zone;
                          c.setTool(id);
                        },
                        child: Container(
                          width: 36,
                          height: 28,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(color: c.activeTool == id ? const Color(0xFF2E7DD1) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                          child: Icon(icon, size: 17, color: c.activeTool == id ? Colors.white : Colors.white70),
                        ),
                      ),
                    ),
                ]),
                const Divider(height: 8, indent: 8, endIndent: 8),
              ],
            ],
          ),
        ),
      );
    });
  }
}
