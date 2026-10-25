import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/field_calculators.dart';
import 'package:opencadirrigation/app/widgets/dialogs/mechanised_dialogs.dart';
import 'package:opencadirrigation/app/widgets/fields.dart';
import 'package:opencadirrigation/core/design/pivot.dart' show PivotKind;
import 'package:opencadirrigation/core/design/pivot_package.dart' show TowerDrive;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/main.dart';

/// The pivot package dialog (package, drive and timer, corner arm, variable
/// rate, electrical) and the field calculators (travelling gun, surface
/// irrigation, gated pipe).
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  /// Types [text] into the numeric field [key] and commits it (Enter).
  Future<void> type(WidgetTester tester, Key key, String text) async {
    final field = find.descendant(of: find.byKey(key), matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  /// Taps [target] after scrolling it into view (a text field's scroll
  /// padding can leave a neighbour half under the dialog title).
  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await settle(tester, 2);
  }

  Future<void> pick(WidgetTester tester, Key dropdown, String item) async {
    await tester.ensureVisible(find.byKey(dropdown));
    await tester.tap(find.byKey(dropdown));
    await settle(tester, 2);
    await tester.tap(find.text(item).last);
    await settle(tester, 2);
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(Key('mech_tab_$name')));
    await settle(tester, 2);
  }

  /// A 300 m pivot (six 50 m spans) in a square field of half side 335 m.
  (PivotEntity, AreaEntity) addPivot(ProjectController c) {
    final field = AreaEntity(id: c.project.newId(), points: [const Pt(-335, -335), const Pt(335, -335), const Pt(335, 335), const Pt(-335, 335)], name: 'Talhão');
    final pv = PivotEntity(id: c.project.newId(), center: const Pt(0, 0), radiusM: 300, name: 'PV 1');
    c.addEntity(field);
    c.addEntity(pv);
    return (pv, field);
  }

  PivotEntity live(ProjectController c, PivotEntity p) => c.project.byId(p.id)! as PivotEntity;

  test('tyre sizes give the rolling diameter of the drive', () {
    expect(tyreRollingDiameterFromSize('11.2-38'), closeTo(TowerDrive.tyreRollingDiameter(sectionWidthInch: 11.2, rimDiameterInch: 38), 1e-12));
    expect(tyreRollingDiameterFromSize(' 14,9 x 24 '), closeTo(TowerDrive.tyreRollingDiameter(sectionWidthInch: 14.9, rimDiameterInch: 24), 1e-12));
    expect(tyreRollingDiameterFromSize('11.2R38'), tyreRollingDiameterFromSize('11.2-38'));
    expect(tyreRollingDiameterFromSize('320/85R38'), closeTo(TowerDrive.tyreRollingDiameter(sectionWidthInch: 320 / 25.4, rimDiameterInch: 38, aspectRatio: 0.85), 1e-12));
    // about 1.43 m for the usual 11.2-38
    expect(tyreRollingDiameterFromSize('11.2-38'), closeTo(1.43, 0.01));
    expect(tyreRollingDiameterFromSize(''), isNull);
    expect(tyreRollingDiameterFromSize('pneu'), isNull);
    expect(tyreRollingDiameterFromSize('38'), isNull);
  });

  testWidgets('the package dialog shows the analyses and commits the edits of every tab as one undo step', (tester) async {
    final c = await pumpShell(tester);
    final (pv, field) = addPivot(c);
    await settle(tester);
    final before = c.historyIndex;
    showPivotMachineDialog(ctxOf(tester), c, pv);
    await settle(tester);
    expect(find.text('Pacote do pivô: PV 1'), findsOneWidget);
    expect(find.byKey(const Key('mech_nozzle_chart')), findsOneWidget);
    expect(find.byKey(const Key('mech_spans_table')), findsOneWidget);
    expect(find.text('Vazão do sistema'), findsOneWidget);
    // package: nozzles on drops 1.8 m above the ground, unregulated
    await type(tester, const Key('mech_nozzle_height'), '1,8');
    expect(find.textContaining('Pendural'), findsWidgets);
    await press(tester, find.byKey(const Key('mech_regulated')));
    expect(find.text('Sem reguladores'), findsOneWidget);
    // drive and timer: no speed yet, then the speed of the last tower and a 50 % setting
    await tab(tester, 'drive');
    expect(find.textContaining('Sem velocidade da última torre'), findsOneWidget);
    await type(tester, const Key('mech_speed100'), '3');
    expect(find.byKey(const Key('mech_timer_chart')), findsOneWidget);
    expect(find.textContaining('Sem velocidade da última torre'), findsNothing);
    await type(tester, const Key('mech_timer'), '50');
    expect(find.text('Horas por volta (50 %)'), findsOneWidget);
    // the tyre helper fills the rolling diameter; an unknown size says so
    await tester.enterText(find.byKey(const Key('mech_tyre_size')), 'grande');
    await press(tester, find.byKey(const Key('mech_tyre_apply')));
    expect(find.text('Medida de pneu não reconhecida'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mech_tyre_size')), '11.2-38');
    await press(tester, find.byKey(const Key('mech_tyre_apply')));
    expect(find.text('Medida de pneu não reconhecida'), findsNothing);
    // corner arm along the field outline set back 20 m
    await tab(tester, 'arm');
    expect(find.text('Informe o comprimento do braço e escolha a trajetória-guia para calculá-lo.'), findsOneWidget);
    await type(tester, const Key('mech_arm_length'), '150');
    await pick(tester, const Key('mech_guide'), 'Talhão');
    await type(tester, const Key('mech_guide_offset'), '20');
    expect(find.byKey(const Key('mech_banks_table')), findsOneWidget);
    expect(find.byKey(const Key('mech_arm_preview')), findsOneWidget);
    expect(find.text('Área acrescentada'), findsOneWidget);
    // electrical on 480 V
    await tab(tester, 'electrical');
    expect(find.text('Informe a tensão da rede para o projeto elétrico da máquina.'), findsOneWidget);
    await type(tester, const Key('mech_volt'), '480');
    expect(find.byKey(const Key('mech_towers_table')), findsOneWidget);
    expect(find.text('Gerador'), findsOneWidget);
    expect(live(c, pv).machine.isDefault, isTrue, reason: 'nothing is stored before OK');
    expect(c.historyIndex, before);
    await tester.tap(find.byKey(const Key('mech_ok')));
    await settle(tester);
    expect(find.byKey(const Key('mech_ok')), findsNothing);
    expect(c.historyIndex, before + 1, reason: 'one undo step for the whole dialog');
    expect(c.historyEntries.firstWhere((e) => e.current).label, 'hist.pivotMachine');
    final m = live(c, pv).machine;
    expect(m.nozzleHeightM, closeTo(1.8, 1e-9));
    expect(m.regulated, isFalse);
    expect(m.towerSpeedMPerMin, 3);
    expect(m.timerPct, 50);
    expect(m.tyreRollingDiameterM, closeTo(tyreRollingDiameterFromSize('11.2-38')!, 1e-12));
    expect(m.cornerArmLengthM, 150);
    expect(m.guidePathId, field.id);
    expect(m.guideOffsetM, 20);
    expect(m.voltage, 480);
    // kept in the file
    expect(live(c, pv).toJson()['mach'], isA<Map<String, dynamic>>());
    c.undo();
    await settle(tester);
    expect(live(c, pv).machine.isDefault, isTrue);
  });

  testWidgets('Cancel discards the edits; OK without changes adds no step', (tester) async {
    final c = await pumpShell(tester);
    final (pv, _) = addPivot(c);
    await settle(tester);
    final before = c.historyIndex;
    showPivotMachineDialog(ctxOf(tester), c, pv);
    await settle(tester);
    await type(tester, const Key('mech_nozzle_height'), '2');
    await tab(tester, 'electrical');
    await type(tester, const Key('mech_volt'), '400');
    await tester.tap(find.byKey(const Key('mech_cancel')));
    await settle(tester);
    expect(live(c, pv).machine.isDefault, isTrue);
    expect(c.historyIndex, before);
    showPivotMachineDialog(ctxOf(tester), c, pv);
    await settle(tester);
    await tester.tap(find.byKey(const Key('mech_ok')));
    await settle(tester);
    expect(c.historyIndex, before);
    // a linear move has no corner arm nor sector prescription
    c.mutate(
      () => live(c, pv)
        ..kind = PivotKind.linear
        ..travelM = 400,
    );
    await settle(tester);
    showPivotMachineDialog(ctxOf(tester), c, live(c, pv));
    await settle(tester);
    expect(find.text('Comprimento irrigado efetivo'), findsOneWidget);
    await tab(tester, 'arm');
    expect(find.text('Só pivôs centrais têm braço de canto.'), findsOneWidget);
    await tab(tester, 'vri');
    expect(find.text('Só pivôs centrais têm prescrição por setores.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mech_cancel')));
    await settle(tester);
  });

  testWidgets('the variable-rate prescription from zones or sectors, saved as CSV', (tester) async {
    final c = await pumpShell(tester);
    final (pv, _) = addPivot(c);
    final east = AreaEntity(id: c.project.newId(), points: [const Pt(0, -400), const Pt(400, -400), const Pt(400, 400), const Pt(0, 400)], name: 'Leste');
    c.addEntity(east);
    // a speed for the depth at 100 %
    c.mutate(() => live(c, pv).machine.towerSpeedMPerMin = 3);
    await settle(tester);
    final saved = <(String, String, String)>[];
    final original = mechanisedFileSaver;
    mechanisedFileSaver = (name, content, {String mime = ''}) async => saved.add((name, content, mime));
    addTearDown(() => mechanisedFileSaver = original);
    showPivotMachineDialog(ctxOf(tester), c, live(c, pv));
    await settle(tester);
    await tab(tester, 'vri');
    expect(find.text('Marque zonas ou adicione setores para ter a prescrição.'), findsOneWidget);
    // the east half at 20 mm: about 17 % of the speed there, 100 % elsewhere
    await press(tester, find.byKey(Key('mech_zone_${east.id}')));
    await type(tester, Key('mech_zone_depth_${east.id}'), '20');
    expect(find.byKey(const Key('mech_vri_table')), findsOneWidget);
    expect(find.text('por velocidade'), findsOneWidget);
    await press(tester, find.byKey(const Key('mech_csv')));
    expect(saved, hasLength(1));
    expect(saved.single.$1, endsWith('_vri.csv'));
    expect(saved.single.$3, 'text/csv');
    final lines = saved.single.$2.trim().split('\n');
    expect(lines.first, 'start_deg,end_deg,timer_pct,depth_mm,target_mm');
    expect(lines, hasLength(4));
    expect(lines[1].startsWith('0.00,90.00,'), isTrue);
    expect(lines[1].endsWith(',20.00,20.00'), isTrue);
    expect(lines[2].startsWith('90.00,270.00,100.00,'), isTrue);
    // compass bearings: 90°–270° of the drawing is 180°–0° clockwise from north
    await press(tester, find.byKey(const Key('mech_compass')));
    await press(tester, find.byKey(const Key('mech_csv')));
    expect(saved, hasLength(2));
    expect(saved.last.$2.trim().split('\n')[2].startsWith('180.00,0.00,100.00,'), isTrue);
    // bank boundaries switch to zone control
    final banks = find.descendant(of: find.byKey(const Key('mech_vri_banks')), matching: find.byType(TextField));
    await tester.ensureVisible(banks);
    await tester.tap(banks);
    await tester.enterText(banks, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    expect(find.text('por zonas (2 bancos)'), findsOneWidget);
    // the sectors table instead of the zones
    await press(tester, find.text('Setores (tabela)'));
    await press(tester, find.byKey(const Key('mech_sector_add')));
    await type(tester, const Key('mech_sector_0_depth'), '15');
    await press(tester, find.byKey(const Key('mech_sector_add')));
    expect(find.byKey(const Key('mech_sector_1_start')), findsOneWidget);
    await press(tester, find.byTooltip('Remover setor').last);
    expect(find.byKey(const Key('mech_sector_1_start')), findsNothing);
    await tester.tap(find.byKey(const Key('mech_ok')));
    await settle(tester);
    final m = live(c, pv).machine;
    expect(m.vriZones, isEmpty, reason: 'the sectors table is what the design uses');
    expect(m.vriSectors, hasLength(1));
    expect(m.vriSectors.single.startDeg, 0);
    expect(m.vriSectors.single.endDeg, 90);
    expect(m.vriSectors.single.depthMm, 15);
    expect(m.vriBankEdgesM, [150]);
    expect(m.towerSpeedMPerMin, 3);
    // back to the zones, none ticked: switching the source alone is a change
    final steps = c.historyIndex;
    showPivotMachineDialog(ctxOf(tester), c, live(c, pv));
    await settle(tester);
    await tab(tester, 'vri');
    expect(find.byKey(const Key('mech_sector_0_start')), findsOneWidget, reason: 'a machine with sectors opens on the table');
    await press(tester, find.text('Zonas (áreas do desenho)'));
    await tester.tap(find.byKey(const Key('mech_ok')));
    await settle(tester);
    expect(c.historyIndex, steps + 1);
    expect(live(c, pv).machine.vriSectors, isEmpty);
    expect(live(c, pv).machine.hasVri, isFalse);
  });

  testWidgets('the field calculators open, follow the data and close', (tester) async {
    final c = await pumpShell(tester);
    // travelling gun: 90 m wetted diameter in light wind, tapered nozzle: lanes 75 % apart
    showTravellerCalculator(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Autopropelido com carretel enrolador'), findsOneWidget);
    expect(find.text('67.5 m (75 % do diâmetro; tabela 75 %)'), findsOneWidget);
    await type(tester, const Key('trav_field_width'), '400');
    expect(find.text('Número de faixas'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // a lane spacing wider than the table is a warning
    await type(tester, const Key('trav_lane_spacing'), '80');
    expect(find.textContaining('Espaçamento entre faixas maior que o da tabela'), findsOneWidget);
    // a catalogue gun gives the flow and the diameter
    await pick(tester, const Key('trav_gun'), 'Canhão hidráulico 1,5"');
    expect(tester.widget<NumField>(find.byKey(const Key('trav_flow'))).enabled, isFalse);
    expect(tester.widget<NumField>(find.byKey(const Key('trav_diameter'))).enabled, isFalse);
    await tester.tap(find.text('Fechar'));
    await settle(tester);

    // surface irrigation: the best inflow of a furrow design, then an evaluation and borders
    showSurfaceIrrigationCalculator(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Irrigação por superfície'), findsOneWidget);
    expect(find.text('Melhor vazão'), findsOneWidget);
    expect(find.byKey(const Key('surf_rows')), findsOneWidget);
    expect(find.text('Eficiência de aplicação'), findsOneWidget);
    await pick(tester, const Key('surf_mode'), 'Avaliar (vazão e corte dados)');
    expect(find.byKey(const Key('surf_cutoff')), findsOneWidget);
    expect(find.byKey(const Key('surf_rows')), findsNothing);
    // cut off before the water reaches the end
    await type(tester, const Key('surf_cutoff'), '10');
    expect(find.textContaining('Corte antes de a água chegar ao fim'), findsOneWidget);
    await pick(tester, const Key('surf_system'), 'Faixas com saída livre');
    expect(find.byKey(const Key('surf_spacing')), findsNothing);
    expect(find.text('Recessão no fim'), findsOneWidget);
    await press(tester, find.byKey(const Key('surf_typed')));
    expect(find.text('k (m/min^a)'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);

    // gated pipe: the least inlet head by default, a warning below it
    showGatedPipeCalculator(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Tubo janelado (alimentação de sulcos)'), findsOneWidget);
    expect(find.byKey(const Key('gate_table')), findsOneWidget);
    expect(find.text('Nenhum aviso.'), findsOneWidget);
    await type(tester, const Key('gate_inlet'), '0,01');
    expect(find.textContaining('Pressão na entrada abaixo da mínima'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });

  testWidgets('the dialogs follow the display units', (tester) async {
    final c = await pumpShell(tester);
    final (pv, _) = addPivot(c);
    final edit = c.beginSettingsEdit('hist.params');
    c.project.params.units = Units.us;
    c.commitSettingsEdit(edit);
    await settle(tester);
    showPivotMachineDialog(ctxOf(tester), c, pv);
    await settle(tester);
    expect(find.textContaining('(ft)'), findsWidgets);
    await type(tester, const Key('mech_nozzle_height'), '6');
    await tester.tap(find.byKey(const Key('mech_ok')));
    await settle(tester);
    expect(live(c, pv).machine.nozzleHeightM, closeTo(6 * metersPerFoot, 1e-9));
    showGatedPipeCalculator(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('(gpm)'), findsWidgets);
    expect(find.textContaining('(psi)'), findsWidgets);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });

  testWidgets('on a phone every tab and calculator lays out in the scrolling dialog', (tester) async {
    final c = await pumpShell(tester);
    final (pv, field) = addPivot(c);
    c.mutate(
      () => live(c, pv).machine
        ..towerSpeedMPerMin = 3
        ..cornerArmLengthM = 150
        ..guidePathId = field.id
        ..guideOffsetM = 20
        ..voltage = 480
        ..vriZones[field.id] = 12,
    );
    await settle(tester);
    tester.view.physicalSize = const Size(390, 844);
    await settle(tester);
    showPivotMachineDialog(ctxOf(tester), c, live(c, pv));
    await settle(tester);
    for (final name in ['drive', 'arm', 'vri', 'electrical', 'package']) {
      await press(tester, find.byKey(Key('mech_tab_$name')));
      expect(tester.takeException(), isNull, reason: 'tab $name');
    }
    expect(find.byKey(const Key('mech_nozzle_chart')), findsOneWidget);
    await press(tester, find.byKey(const Key('mech_cancel')));
    for (final open in [showTravellerCalculator, showSurfaceIrrigationCalculator, showGatedPipeCalculator]) {
      open(ctxOf(tester), c);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await press(tester, find.text('Fechar'));
    }
  });
}
