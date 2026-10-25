import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/vegetation_dialog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

import 'support/aerial_scene.dart';

/// The vegetation dialog on the synthetic garden: from the base map view
/// (a fake snapshot) and from a selected aerial photo, the areas it creates
/// in one undo step, the reasons it gives without pixels, and its layout on
/// a phone and on a desktop.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 5]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
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

  final scene = AerialScene();
  final png = Uint8List.fromList(img.encodePng(img.Image.fromBytes(width: scene.width, height: scene.height, bytes: scene.rgba().buffer, numChannels: 4)));

  testWidgets('the base map view: two lawns, three crowns and the patio, created in one undo step', (tester) async {
    final c = await pumpShell(tester);
    const origin = Pt(500, 300);
    c.baseMapSnapshot = () async => (png, scene.corners(origin: origin));
    final step = c.historyIndex, count = c.project.entities.length;
    showVegetationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byType(VegetationDialog), findsOneWidget);
    expect(find.text('Criar áreas (5)'), findsOneWidget);
    expect(find.text('Mapa base na tela (vista atual)'), findsOneWidget);
    expect(find.textContaining('termos de uso'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^2 · 5[01]\d m²$')), findsOneWidget, reason: 'the net area of the two lawns (≈ 510 m²)');
    expect(find.byKey(const Key('veg_error')), findsNothing);
    await tester.tap(find.byKey(const Key('veg_create')));
    await settle(tester);
    expect(find.byType(VegetationDialog), findsNothing);
    final areas = c.project.entities.whereType<AreaEntity>().toList();
    expect(areas.map((a) => a.name), ['Gramado 1', 'Gramado 2', 'Árvores e arbustos 1', 'Árvores e arbustos 2', 'Árvores e arbustos 3']);
    expect(pointInPolygon(origin + const Pt(6, 6), areas.first.points), isTrue);
    expect(areas.first.area, closeTo(384, 384 * 0.02));
    expect(areas.first.crop, 'Gramado');
    final exclusions = c.project.entities.whereType<PolylineEntity>().toList();
    expect(exclusions.single.name, 'Exclusão 1 (Gramado 1)');
    expect(exclusions.single.layer, Layers.drawing);
    expect(c.selection, hasLength(6));
    expect(c.historyIndex, step + 1);
    expect(c.lastMessage, contains('5 áreas e 1 exclusões'));
    c.undo();
    await settle(tester, 2);
    expect(c.project.entities, hasLength(count));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a selected aerial photo, turned: lawns only, the crown in the lawn an exclusion', (tester) async {
    final c = await pumpShell(tester);
    final photo = ImageEntity(id: c.project.newId(), origin: const Pt(-40, 25), width: scene.widthM, height: scene.heightM, rotationDeg: 30, data: png, name: 'drone.png');
    c.addEntities([photo]);
    c.select([photo.id]);
    await settle(tester);
    showVegetationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Foto aérea selecionada: drone.png'), findsOneWidget);
    // the drawing has no georeference: the areas use the photo's placement
    expect(find.textContaining('Desenho sem georreferência'), findsOneWidget);
    await tester.tap(find.byKey(const Key('veg_trees')));
    await settle(tester);
    expect(find.text('Criar áreas (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('veg_create')));
    await settle(tester);
    final areas = c.project.entities.whereType<AreaEntity>().toList();
    expect(areas.map((a) => a.name), ['Gramado 1', 'Gramado 2']);
    final lawnA = AerialScene.place(const Pt(6, 6), origin: photo.origin, rotationDeg: 30);
    expect(pointInPolygon(lawnA, areas.first.points), isTrue);
    expect(c.project.entities.whereType<PolylineEntity>(), hasLength(2), reason: 'the patio and the crown');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no pixels: the reason instead of the picture, nothing to create', (tester) async {
    final c = await pumpShell(tester);
    // the canvas's own snapshot: no georeference, no map
    showVegetationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('veg_error')), findsOneWidget);
    expect(find.textContaining('não tem georreferência'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('veg_create'))).onPressed, isNull);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    // georeferenced, no base map on screen; then the map is there and is read again
    c.setGeoreferenceAt(-21.8, -46.6);
    var ready = false;
    c.baseMapSnapshot = () async => ready ? (png, scene.corners()) : null;
    showVegetationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('Nenhum mapa base na tela'), findsOneWidget);
    ready = true;
    await tester.tap(find.byKey(const Key('veg_reload')));
    await settle(tester);
    expect(find.byKey(const Key('veg_error')), findsNothing);
    expect(find.text('Criar áreas (5)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a phone and on a small window; the settings run the detection again', (tester) async {
    for (final size in const [Size(390, 844), Size(820, 640), Size(1280, 800)]) {
      final c = await pumpShell(tester, size: size);
      c.baseMapSnapshot = () async => (png, scene.corners());
      showVegetationDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text('Criar áreas (5)'), findsOneWidget, reason: '$size');
      expect(find.byKey(const Key('veg_preview')), findsOneWidget);
      // without the split: one class, the crown inside lawn A merged into it
      final split = find.byKey(const Key('veg_split'));
      await tester.ensureVisible(split);
      await tester.pump();
      await tester.tap(split);
      await settle(tester);
      expect(find.text('Criar áreas (4)'), findsOneWidget, reason: '$size');
      // the minimum area above lawn B: lawn A alone
      final minArea = find.descendant(of: find.byKey(const Key('veg_min_area')), matching: find.byType(TextField));
      await tester.ensureVisible(minArea);
      await tester.tap(minArea);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(minArea, '200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Criar áreas (1)'), findsOneWidget, reason: '$size');
      final advanced = find.byKey(const Key('veg_advanced'));
      await tester.ensureVisible(advanced);
      await tester.pump();
      await tester.tap(advanced);
      await settle(tester);
      expect(find.byKey(const Key('veg_clean')), findsOneWidget);
      // the threshold far up: nothing green left
      final slider = find.byKey(const Key('veg_threshold'));
      await tester.ensureVisible(slider);
      await tester.pump();
      await tester.drag(slider, const Offset(2000, 0));
      await settle(tester);
      expect(find.text('Criar áreas (1)'), findsOneWidget, reason: 'lawn A is lush green: still found at the top of the threshold');
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(find.byType(VegetationDialog), findsNothing);
    }
  });
}
