/// The worked example of the AI assistant's manual: a small drip project
/// designed end to end with the real tools, kept as data. The "example"
/// topic prints the calls with what their results say, and
/// test/widget_ai_manual_test.dart replays them on a new project and checks
/// that every result still says it, so the example stays true.
library;

import 'dart:convert';

import 'agent_tools.dart';

/// One call of the worked example.
class ManualStep {
  const ManualStep(this.tool, this.input, this.why, {this.shows = const []});
  final String tool;
  final Map<String, Object?> input;

  /// What the step does and why.
  final String why;

  /// Lines of the result, "…" standing for any text (numbers, ids); the
  /// replay checks that the result still has them.
  final List<String> shows;
}

/// [show] as a pattern: "…" matches any text on the line.
RegExp showPattern(String show) => RegExp(show.split('…').map(RegExp.escape).join('.*?'));

/// A 50 × 30 m field of drip tape fed from a well 40 m west of it.
const workedExample = <ManualStep>[
  ManualStep(
    'create_entities',
    {
      'entities': [
        {
          'type': 'area',
          'name': 'Field',
          'pts': [
            [0, 0],
            [50, 0],
            [50, 30],
            [0, 30],
          ],
          'crop': 'Tomato',
        },
        {
          'type': 'waterSupply',
          'name': 'Well',
          'p': [-40, 15],
          'calc': true,
          'wl': -4,
        },
        {
          'type': 'pipe',
          'name': 'Main',
          'scope': 'mainline',
          'pts': [
            [-40, 15],
            [-1.5, 15],
          ],
        },
        {
          'type': 'misc',
          'name': 'Filter',
          'spec': 'filter_disc50',
          'p': [-30, 15],
        },
      ],
    },
    'The field, the well (water 4 m below the ground; the design finds the pressure the system needs), a mainline that ends 1.5 m west of the middle of the field, where generate_block will put the valve, and a disc filter on it (a device on a pipe splits it).',
    shows: [
      'Created 4 items:',
      '… | waterSupply | Well | at [-40.00, 15.00], pressure calculated by the design',
      '… | pipe | Main | mainline, size by the design, 38.5 m, 2 vertices, [-40.00, 15.00] → [-1.50, 15.00]',
    ],
  ),
  ManualStep(
    'generate_block',
    {'area': 'Field', 'lateral': 'tape', 'lateral_spacing_m': 1.5, 'tape': 'tape16_10_30', 'direction_deg': 0, 'submain': 'start', 'zone_name': 'Block 1'},
    'Tape every 1.5 m running east, the submain along the west edge, and the valve, chosen for the block\'s flow, 1.5 m outside the middle of the submain: at the end of the mainline.',
    shows: ['Zone "Block 1": valve … ev25 (0.2–6.0 m³/h) at [-1.50, 15.00], nominal block flow … m³/h.', 'Added 23 items (20 × Drip tape, 2 × Zone pipe, 1 × Control valve); ids …'],
  ),
  ManualStep(
    'run_design',
    {},
    'Size the pipes and analyse: the zone is within its pressure window, and the well must give the pressure the summary calls "needs" (no pump yet).',
    shows: [
      '1 zones; all within their pressure window.',
      'Flow All zones: … L/h; Well: … L/h at … m.c.a. (needs …).',
      'Costs (…): materials …, annual energy …, annual total ….',
      'Messages: 0 errors, 0 warnings — [no_terrain] …',
    ],
  ),
  ManualStep(
    'rank_pumps',
    {},
    'Pumps for that duty: the suitable ones first, then by life-cycle cost; the first is the cheapest to buy and run.',
    shows: ['Duty: … m³/h at … m (All zones).', '… | parallel\npump_c1 | Centrifugal pump 1 hp … | true | true | 1'],
  ),
  ManualStep(
    'apply_pump',
    {'pump': 'pump_c1'},
    'Install it. There is no pump near the well, so one is added on the mainline 1.5 m from it, before the filter.',
    shows: ['Added pump … (Centrifugal pump 1 hp …) at [-38.50, 15.00] on the mainline. Run the design again.'],
  ),
  ManualStep(
    'run_design',
    {},
    'Design again: the pump now gives the pressure, so the well needs none.',
    shows: ['1 zones; all within their pressure window.', 'Well: … L/h at 0.0 m.c.a. (needs 0.0).'],
  ),
  ManualStep(
    'get_design_messages',
    {},
    'What is left: read why and how, fix the errors, explain the rest to the user.',
    shows: ['… messages: 0 errors, 0 warnings, … notes. Design results present.', '[no_terrain] No elevation data: the ground is taken as flat'],
  ),
  ManualStep(
    'get_report_table',
    {'table': 'zones'},
    'The figures to report: the zone flow, the pressures against the window, the uniformity.',
    shows: ['Zone | Valve | Outlets | Flow (L/h) | Downstream P (m.c.a.) | Valve loss | Required P | Min P | Max P | Allow. min | Allow. max | …', 'Block 1 | Solenoid valve 1" | 3320 | …'],
  ),
];

/// The "example" topic.
String exampleTopic(AgentToolbox b) {
  final out = StringBuffer(
    '# Worked example: a drip block from a well\n'
    'Run on a new project in English with the default catalogue (the ids and names below are of that catalogue; confirm them with search_catalog in another). Items are referred to by name, so no id has to be read back. Each result is shown in part, "…" standing for numbers and ids (the program\'s tests replay the calls and check these lines).\n',
  );
  for (var k = 0; k < workedExample.length; k++) {
    final s = workedExample[k];
    out.writeln(
      '\n${k + 1}. ${s.tool} ${jsonEncode(s.input)}\n   ${s.why}${s.shows.isEmpty ? '' : '\n   The result shows:\n${s.shows.map((x) => '     ${x.replaceAll('\n', '\n     ')}').join('\n')}'}',
    );
  }
  out.writeln(
    '\nThen, on request: get_report_table "bom" for the materials, set_quote and "proposal" for the quote, export_file for files. A real project adds terrain (download_terrain), the crop data of the area, system flows for several zones and the user\'s choices (ask_user).',
  );
  return out.toString();
}
