import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart' show AiAssistant;
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/cad_plus_commands.dart';
import 'package:opencadirrigation/app/tools/insert_block_tool.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/blocks_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/cad_plus_dialogs.dart';
import 'package:opencadirrigation/app/widgets/layout_mode.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/dim_style.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/layer_states.dart';
import 'package:opencadirrigation/main.dart';

/// The drawing functions of 1.6.0 (CAD+) in the running app: text edited
/// in place on the drawing, the magnifier of a finger drawing, the length
/// and angle beside the cursor, the snaps one by one, the layer states, the
/// dimension style, the insert dialog of a block of references with
/// attributes, the properties of a block reference and of a mixed
/// selection, and the comparison with another open tab.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    c.snap.enabled = false;
    c.camera.center = const Pt(20, 0);
    c.camera.scale = 10;
    await settle(tester);
    return c;
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(AppShell));
  RenderBox canvasBox(WidgetTester tester) => tester.renderObject(find.byType(CadCanvas)) as RenderBox;
  Offset global(WidgetTester tester, ProjectController c, Pt world) => canvasBox(tester).localToGlobal(c.camera.toScreen(world));

  testWidgets('a double click on a text edits it in place: Enter keeps it (one undo step), Esc leaves it', (tester) async {
    final c = await pumpShell(tester);
    // a desktop with a mouse from the start: the layout follows the pointer
    // (UI-06) and the test platform counts as a touch screen until the first
    // click, so that click would shrink the palette and move the drawing
    // under the second one
    lastPointerKind.value = PointerDeviceKind.mouse;
    addTearDown(() => lastPointerKind.value = null);
    final t = TextEntity(id: c.project.newId(), position: const Pt(20, 0), text: 'Pump', height: 2);
    c.addEntity(t);
    await settle(tester, 1);
    final at = global(tester, c, const Pt(21, 1));
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await settle(tester, 2);
    expect(find.byKey(const Key('text_in_place_field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('text_in_place_field')), 'Pump house');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    expect((c.project.byId(t.id)! as TextEntity).text, 'Pump house');
    expect(c.historyEntries.last.label, 'hist.textEdit');
    expect(find.byKey(const Key('text_in_place_field')), findsNothing);
    // Esc leaves the text as it was
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('text_in_place_field')), 'nope');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, 2);
    expect((c.project.byId(t.id)! as TextEntity).text, 'Pump house');
  });

  testWidgets('a finger dragged while drawing aims with a magnifier: the point goes where it is lifted', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.line);
    await settle(tester, 1);
    final g = await tester.startGesture(global(tester, c, const Pt(10, 0)), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 30));
    await g.moveTo(global(tester, c, const Pt(12, 0)));
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byKey(const Key('touch_loupe')), findsOneWidget);
    await g.moveTo(global(tester, c, const Pt(15, 0)));
    await tester.pump(const Duration(milliseconds: 30));
    await g.up();
    await settle(tester, 2);
    expect(find.byKey(const Key('touch_loupe')), findsNothing);
    expect(c.keyTarget!.referencePoint!.distanceTo(const Pt(15, 0)), lessThan(0.05), reason: 'the first point where the finger was lifted');
    // the magnifier off: a drag draws as before (no magnifier)
    c.cadPlus.touchLoupe = false;
    final h = await tester.startGesture(global(tester, c, const Pt(25, 0)), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 30));
    await h.moveTo(global(tester, c, const Pt(27, 0)));
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byKey(const Key('touch_loupe')), findsNothing);
    await h.up();
    await settle(tester, 2);
  });

  testWidgets('the length and angle of the segment show beside the mouse while drawing', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.line);
    await settle(tester, 1);
    c.keyTarget!.feedPoint(const Pt(10, 0));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: global(tester, c, const Pt(12, 0)));
    await mouse.moveTo(global(tester, c, const Pt(13, 4)));
    await settle(tester, 1);
    expect(find.byKey(const Key('dynamic_input')), findsOneWidget);
    expect(find.text('5.00'), findsOneWidget);
    c.cadPlus.dynamicInput = false;
    c.refresh();
    await settle(tester, 1);
    expect(find.byKey(const Key('dynamic_input')), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('the snaps one by one, the layer states and the dimension style in their dialogs', (tester) async {
    final c = await pumpShell(tester);
    final snaps = showSnapSettingsDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('snap_mode_tangent')));
    await settle(tester, 1);
    expect(c.snap.modes.contains('tangent'), isFalse);
    await tester.tap(find.byKey(const Key('snap_none')));
    await settle(tester, 1);
    expect(c.snap.modes, isEmpty);
    await tester.tap(find.byKey(const Key('snap_all')));
    await settle(tester, 1);
    expect(c.snap.modes.length, 10);
    await tester.tap(find.text(c.t('close')).last);
    await settle(tester);
    await snaps;
    // layer states
    final names = [for (final l in c.project.layers) l.name];
    c.toggleLayer(names[1]);
    final states = showLayerStatesDialog(ctx(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('layer_states_none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('layer_state_save')));
    await settle(tester, 1);
    expect(c.project.layerStates, hasLength(1));
    c.toggleLayer(names[1]);
    final st = c.project.layerStates.single.name;
    await tester.tap(find.byKey(Key('layer_state_restore_$st')));
    await settle(tester, 1);
    expect(c.project.layerNamed(names[1]).visible, isFalse);
    await tester.tap(find.text(c.t('close')).last);
    await settle(tester);
    await states;
    // dimension style
    final dims = showDimStyleDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text(c.t('dim.arrow.arrow')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('dim_ok')));
    await settle(tester);
    await dims;
    expect(c.project.dimStyle.arrow, DimArrow.arrow);
    expect(c.historyEntries.last.label, 'hist.dimStyle');
  });

  testWidgets('a block of drawing items goes in as a reference with its attribute values, edited in the properties', (tester) async {
    final c = await pumpShell(tester);
    final def = BlockDefinition.fromEntities(
      'Valve box',
      [
        PolylineEntity(id: 'a', points: const [Pt(0, 0), Pt(2, 0), Pt(2, 1), Pt(0, 1)], closed: true),
        TextEntity(id: 'b', position: const Pt(0, 1.5), text: '{CODE=VB-00}', height: 0.4),
      ],
      Pt.zero,
      inBom: true,
    );
    c.saveBlock(c.project.blocks, def);
    final asking = showInsertBlockDialog(ctx(tester), c, c.project.blocks);
    await settle(tester);
    expect(find.byKey(const Key('blk_as')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('blk_attr_CODE')), 'VB-12');
    await tester.tap(find.text(c.t('blk.at')));
    await settle(tester, 1);
    await tester.enterText(find.byKey(const Key('blk_ax')), '20');
    await tester.enterText(find.byKey(const Key('blk_ay')), '0');
    await tester.tap(find.byKey(const Key('blk_insert_ok')));
    await settle(tester);
    final r = (await asking)!;
    expect(r.values, {'CODE': 'VB-12'});
    expect(r.asReference, isTrue);
    final ids = c.insertBlock(r.block, r.at!, values: r.values, asReference: r.asReference);
    final ref = c.project.byId(ids.single)! as BlockRefEntity;
    expect(ref.attribute('CODE'), 'VB-12');
    // its properties: the attribute as a field
    c.select([ref.id]);
    await settle(tester, 2);
    expect(find.byKey(const Key('blkref_field_CODE')), findsOneWidget);
    expect(find.byKey(const Key('blkref_explode')), findsOneWidget);
    // a mixed selection: chips of its kinds
    final circle = CircleEntity(id: c.project.newId(), center: const Pt(30, 0), radius: 1);
    c.addEntity(circle);
    c.select([ref.id, circle.id]);
    await settle(tester, 2);
    expect(find.byKey(const Key('batch_kinds')), findsOneWidget);
    await tester.tap(find.byKey(const Key('batch_only_kind')));
    await settle(tester, 2);
    expect(c.selection, hasLength(1));
  });

  testWidgets('compare with another open tab: what changed, shown on the drawing', (tester) async {
    final c = await pumpShell(tester);
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    final ws = AiAssistant.workspace!;
    final other = ws.addTab(select: false);
    other.project.meta.name = 'Copy B';
    await settle(tester, 1);
    final comparing = showCompareDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(Key('cmp_tab_${other.tabId}')));
    await settle(tester);
    expect(find.byKey(const Key('cmp_summary')), findsOneWidget);
    expect(find.text(c.t('cmp.summary', {'a': '1', 'r': '0', 'c': '0'})), findsOneWidget);
    await tester.tap(find.byKey(const Key('cmp_show')));
    await settle(tester, 1);
    await tester.tap(find.text(c.t('close')).last);
    await settle(tester);
    await comparing;
  });
}
