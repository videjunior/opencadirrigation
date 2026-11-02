import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/place_search.dart' show SiteFetch, siteFetch;
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/ai/llm.dart' show AiProvider;
import 'package:opencadirrigation/main.dart';

/// The start-up screen: the app opens on an empty project (no example, no
/// welcome) and asks only where the area is and whether to design with the
/// AI assistant. Coordinates or an address found on OpenStreetMap
/// georeference the project and show the satellite map; with the AI, the
/// assistant opens beside the drawing with the place and the description
/// waiting in its box (nothing is sent). "Don't show" is remembered and the
/// switch in the assistant's settings brings the screen back.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  late SiteFetch fetch;
  setUp(() {
    fetch = siteFetch;
    LocalProjectStore().clearAll();
    setPref('lang', 'pt');
    removePref('ai.askAtStart');
    removePref(AiAssistant.keyPref);
    removePref(AiAssistant.keyPrefOf(AiProvider.openai));
    AiAssistant.clearSessionKey();
  });
  tearDown(() {
    siteFetch = fetch;
    AiAssistant.panelOpen.value = false;
    removePref('ai.askAtStart');
  });

  Future<dynamic> pumpApp(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(offerRecovery: false));
    await settle(tester);
    return tester.state(find.byType(AppShell));
  }

  String inputText(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('ai_input'))).controller!.text;

  (double, double) origin(ProjectController c) => c.project.meta.georef!.toLatLon(0, 0);

  testWidgets('the app starts empty and asks only where the area is and whether to design with the AI', (tester) async {
    TutorialController.reset();
    final shell = await pumpApp(tester);
    final c = shell.c as ProjectController;
    expect(find.byKey(const Key('ai_start')), findsOneWidget);
    expect(find.text('Comece o seu projeto'), findsOneWidget);
    expect(find.byKey(const Key('start_where')), findsOneWidget);
    expect(find.text('Projetar com o assistente de IA?'), findsOneWidget);
    expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsNothing, reason: 'no welcome, even on a first run');
    expect(c.project.entities, isEmpty, reason: 'no example at start');
    // 1.6.0 UI: no name of its own; the tab says "Novo projeto" in the language of the moment
    expect(c.project.meta.name, '');
    expect(find.text('Novo projeto'), findsWidgets);
    // left blank, without the AI: the empty project, no georeference, no assistant
    await tester.tap(find.byKey(const Key('ai_start_no')));
    await settle(tester);
    expect(find.byKey(const Key('ai_start')), findsNothing);
    expect(c.project.meta.georef, isNull);
    expect(AiAssistant.panelOpen.value, isFalse);
    expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsNothing);
    expect(AiAssistant.askAtStart, isTrue, reason: 'asked again at the next start');
  });

  testWidgets('coordinates georeference the project on the satellite map; with the AI the assistant opens with the place in the request', (tester) async {
    final shell = await pumpApp(tester);
    final c = shell.c as ProjectController;
    await tester.enterText(find.byKey(const Key('start_where')), '-22.9068, -47.0626');
    await tester.enterText(find.byKey(const Key('ai_start_describe')), 'Gramado de 400 m², água da rua');
    await tester.tap(find.byKey(const Key('ai_start_yes')));
    await settle(tester);
    expect(find.byKey(const Key('ai_start')), findsNothing);
    final (lat, lon) = origin(c);
    expect(lat, closeTo(-22.9068, 1e-6));
    expect(lon, closeTo(-47.0626, 1e-6));
    expect(c.baseMap, BaseMap.satellite);
    expect(c.project.entities, isEmpty);
    expect(AiAssistant.panelOpen.value, isTrue);
    // no key yet: the panel opens on its settings; the request waits for the conversation
    expect(find.byKey(const Key('ai_key_field_anthropic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_view_chat')));
    await settle(tester);
    expect(inputText(tester), contains('-22.90680'));
    expect(inputText(tester), contains('Gramado de 400 m², água da rua'));
    expect(AiAssistant.of(c).items, isEmpty, reason: 'nothing was sent');
  });

  testWidgets('an address is searched on OpenStreetMap and the user picks the match', (tester) async {
    final asked = <Uri>[];
    siteFetch = (url, headers) async {
      asked.add(url);
      return jsonEncode([
        {'display_name': 'Campinas, São Paulo, Brasil', 'lat': '-22.9056', 'lon': '-47.0608', 'category': 'boundary', 'type': 'administrative'},
        {'display_name': 'Campinas do Sul, Rio Grande do Sul, Brasil', 'lat': '-27.7175', 'lon': '-52.6247', 'category': 'boundary', 'type': 'administrative'},
      ]);
    };
    final shell = await pumpApp(tester);
    final c = shell.c as ProjectController;
    await tester.enterText(find.byKey(const Key('start_where')), 'Campinas');
    await tester.tap(find.byKey(const Key('start_search')));
    await settle(tester, 10);
    expect(asked, hasLength(1));
    expect(asked.single.host, 'nominatim.openstreetmap.org');
    expect(asked.single.queryParameters['q'], 'Campinas');
    expect(asked.single.queryParameters['accept-language'], 'pt');
    expect(find.text('Campinas do Sul, Rio Grande do Sul, Brasil'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start_hit_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_start_no')));
    await settle(tester);
    final (lat, lon) = origin(c);
    expect(lat, closeTo(-27.7175, 1e-6));
    expect(lon, closeTo(-52.6247, 1e-6));
    expect(c.baseMap, BaseMap.satellite);
    expect(AiAssistant.panelOpen.value, isFalse, reason: 'started without the AI');
  });

  testWidgets('a place typed but not searched is searched on start; nothing found keeps the screen with a message', (tester) async {
    var answer = '[]';
    siteFetch = (url, headers) async => answer;
    final shell = await pumpApp(tester);
    final c = shell.c as ProjectController;
    await tester.enterText(find.byKey(const Key('start_where')), 'Sítio Xyzzy');
    await tester.tap(find.byKey(const Key('ai_start_yes')));
    await settle(tester, 10);
    expect(find.byKey(const Key('ai_start')), findsOneWidget);
    expect(find.byKey(const Key('start_where_error')), findsOneWidget);
    expect(c.project.meta.georef, isNull);
    answer = jsonEncode([
      {'display_name': 'Fazenda Xyzzy, Goiás, Brasil', 'lat': '-16.5', 'lon': '-49.25'},
    ]);
    await tester.enterText(find.byKey(const Key('start_where')), 'Fazenda Xyzzy');
    await tester.tap(find.byKey(const Key('ai_start_yes')));
    await settle(tester, 10);
    expect(find.byKey(const Key('ai_start')), findsNothing, reason: 'a single match goes on');
    final (lat, _) = origin(c);
    expect(lat, closeTo(-16.5, 1e-6));
    expect(AiAssistant.panelOpen.value, isTrue);
  });

  testWidgets('"don\'t show" is remembered and the settings switch brings the screen back', (tester) async {
    final shell = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('ai_start_never')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_start_no')));
    await settle(tester);
    expect(AiAssistant.askAtStart, isFalse);
    // the switch in the assistant's settings
    AiAssistant.panelOpen.value = true;
    await settle(tester);
    final c = shell.c as ProjectController;
    expect(AiAssistant.of(c).hasKey, isFalse);
    final toggle = find.byKey(const Key('ai_ask_start'));
    await tester.ensureVisible(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await settle(tester);
    expect(AiAssistant.askAtStart, isTrue);
  });

  testWidgets('not shown once turned off: the empty project opens directly', (tester) async {
    TutorialController.markDone();
    AiAssistant.askAtStart = false;
    final shell = await pumpApp(tester);
    expect(find.byKey(const Key('ai_start')), findsNothing);
    expect((shell.c as ProjectController).project.entities, isEmpty);
    expect(AiAssistant.panelOpen.value, isFalse);
  });

  testWidgets('on a phone the screen fits; with a key saved it names the model and the assistant opens as a sheet', (tester) async {
    setPref(AiAssistant.keyPref, 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000');
    final shell = await pumpApp(tester, size: const Size(400, 860));
    expect(find.byKey(const Key('ai_start')), findsOneWidget);
    expect(find.byKey(const Key('mobile_ai')), findsOneWidget, reason: 'the assistant has a button in the phone bar');
    expect(find.textContaining('Claude Opus 5.5'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow');
    await tester.enterText(find.byKey(const Key('start_where')), '-15.79, -47.88');
    await tester.ensureVisible(find.byKey(const Key('ai_start_yes')));
    await tester.tap(find.byKey(const Key('ai_start_yes')));
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('ai_panel')), findsOneWidget);
    final c = shell.c as ProjectController;
    expect(c.project.meta.georef, isNotNull);
    // with the key the panel opens on the conversation, the request in the box
    expect(inputText(tester), contains(c.t('ai.start.prompt')));
    expect(AiAssistant.of(c).items, isEmpty, reason: 'nothing was sent');
    removePref(AiAssistant.keyPref);
  });
}
