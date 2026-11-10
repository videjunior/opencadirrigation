// The browser of OpenRouter's models with a scripted download (the recorded
// sample of the real list, test/fixtures/openrouter): the list as it opens
// (tools on), search, the filters, sorting, choosing a model (registered,
// kept in the preferences, returned), taking it out again, the copy kept
// for when the download fails, the failure with nothing kept and its retry,
// on a phone and in both themes.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/data_cache_store.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/place_search.dart' show siteFetch;
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_model_catalog.dart';
import 'package:opencadirrigation/core/ai/openrouter_catalog.dart';

void main() {
  final sample = File('test/fixtures/openrouter/models_sample.json').readAsStringSync();
  final all = OpenRouterCatalog.parse(sample);
  final originalFetch = siteFetch;
  late List<Uri> asked;
  late DataCache cache;

  setUp(() {
    asked = [];
    cache = DataCache(MemoryDataCacheStore());
    debugAppDataCache = cache;
    siteFetch = (url, headers) async {
      asked.add(url);
      return sample;
    };
  });
  tearDown(() {
    siteFetch = originalFetch;
    debugAppDataCache = null;
    removePref(OpenRouterCatalog.prefKey);
    AiModel.unregister();
    Cad.use(Brightness.dark);
  });

  /// The dialog over a button; [chosen] gets what it returns.
  Future<ProjectController> open(WidgetTester tester, List<AiModel?> chosen, {Size size = const Size(1280, 900), Brightness theme = Brightness.dark}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Cad.use(theme);
    final c = ProjectController();
    await c.setLanguage('en', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(theme),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () async => chosen.add(await showOpenRouterCatalog(context, c)), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return c;
  }

  String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('aor_count'))).data!;
  List<String> names(WidgetTester tester) => [for (final e in tester.widgetList<ListTile>(find.byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains('aor_row_')))) (e.title as Text).data!];

  testWidgets('opens on the models that call tools, cheapest first, with what the user should know; search, filters and sorting', (tester) async {
    final chosen = <AiModel?>[];
    await open(tester, chosen);
    expect(asked.single.toString(), 'https://openrouter.ai/api/v1/models');
    final withTools = all.where((e) => e.model.tools).length;
    expect(count(tester), '$withTools models');
    expect(find.byKey(const Key('aor_free_note')), findsOneWidget);
    expect(find.textContaining('can only talk'), findsWidgets);
    expect(find.textContaining('OpenRouter (openrouter.ai)'), findsOneWidget);
    expect(find.text('Palmyra X5'), findsNothing, reason: 'no tools: hidden at first');
    // cheapest first: a free model leads, the routers come last
    expect(names(tester).take(2).toSet(), {'Free Models Router', 'Gemma 4 31B (free)'});
    final list = find.descendant(of: find.byKey(const Key('aor_list')), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.byKey(Key('aor_row_${withTools - 1}')), 200, scrollable: list);
    expect((tester.widget<ListTile>(find.byKey(Key('aor_row_${withTools - 1}'))).title as Text).data, 'Auto Router');
    Future<void> top() async {
      await tester.drag(list, const Offset(0, 3000));
      await tester.pumpAndSettle();
    }

    await top();
    // the price per million tokens, the context and the maker
    await tester.enterText(find.byKey(const Key('aor_search')), 'opus');
    await tester.pumpAndSettle();
    expect(find.textContaining('Anthropic · US\$ 4 / 20 per million tokens · 1M context · already offered'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('aor_search')), '');
    await tester.pumpAndSettle();
    // tools off: the model that only talks appears
    await tester.tap(find.byKey(const Key('aor_tools')));
    await tester.pumpAndSettle();
    expect(count(tester), '${all.length} models');
    await tester.scrollUntilVisible(find.text('Palmyra X5'), 200, scrollable: list);
    expect(find.text('Palmyra X5'), findsOneWidget);
    await top();
    // pictures only
    await tester.tap(find.byKey(const Key('aor_vision')));
    await tester.pumpAndSettle();
    expect(count(tester), '${all.where((e) => e.model.vision).length} models');
    // free only
    await tester.tap(find.byKey(const Key('aor_free')));
    await tester.pumpAndSettle();
    expect(names(tester).toSet(), {'Gemma 4 31B (free)', 'Free Models Router'});
    // by name
    await tester.tap(find.byKey(const Key('aor_by_name')));
    await tester.pumpAndSettle();
    expect(names(tester), ['Free Models Router', 'Gemma 4 31B (free)']);
    // a search that finds nothing says so
    await tester.enterText(find.byKey(const Key('aor_search')), 'no such model');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_none')), findsOneWidget);
    expect(count(tester), '0 models');
    await tester.tap(find.byKey(const Key('aor_close')));
    await tester.pumpAndSettle();
    expect(chosen, [null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a row adds the model to the user\'s list and returns it; it can be taken out again', (tester) async {
    final chosen = <AiModel?>[];
    await open(tester, chosen);
    await tester.enterText(find.byKey(const Key('aor_search')), 'glm');
    await tester.pumpAndSettle();
    expect(names(tester), ['GLM 5.3']);
    expect(find.textContaining('Z.ai · US\$'), findsOneWidget, reason: 'the maker, searched too');
    await tester.tap(find.byKey(const Key('aor_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_dialog')), findsNothing);
    final m = chosen.single!;
    expect(m.id, 'z-ai/glm-5.3');
    expect(m.label, 'GLM 5.3 (OpenRouter)');
    expect(AiModel.find('z-ai/glm-5.3'), same(m));
    expect(AiModel.offered(AiProvider.openrouter).last, same(m));
    expect(OpenRouterCatalog.decode(getPref(OpenRouterCatalog.prefKey)).single.id, 'z-ai/glm-5.3');
    // one of the app's own models is chosen as it is, not added
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('aor_search')), 'opus');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aor_row_0')));
    await tester.pumpAndSettle();
    expect(chosen.last, AiModel.orOpus55);
    expect(OpenRouterCatalog.added.map((x) => x.id), ['z-ai/glm-5.3']);
    // the model added is marked, with a button to take it out
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('aor_search')), 'glm');
    await tester.pumpAndSettle();
    expect(find.textContaining('in your list'), findsOneWidget);
    await tester.tap(find.byKey(const Key('aor_remove_0')));
    await tester.pumpAndSettle();
    expect(AiModel.find('z-ai/glm-5.3'), isNull);
    expect(OpenRouterCatalog.decode(getPref(OpenRouterCatalog.prefKey)), isEmpty);
    expect(find.byKey(const Key('aor_remove_0')), findsNothing);
    expect(find.byKey(const Key('aor_dialog')), findsOneWidget, reason: 'removing does not close the dialog');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline: the copy kept from the last download, said so with its day; nothing kept: the reason and a retry', (tester) async {
    final chosen = <AiModel?>[];
    await open(tester, chosen);
    expect(await cache.store.get(openRouterCacheKey), isNotNull, reason: 'kept in the data cache');
    await tester.tap(find.byKey(const Key('aor_close')));
    await tester.pumpAndSettle();
    siteFetch = (url, headers) async => throw HttpStatusException(503, '{"error":{"message":"Service temporarily unavailable","code":503}}');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_offline')), findsOneWidget);
    expect(find.textContaining('OpenRouter answered 503'), findsOneWidget);
    expect(count(tester), '${all.where((e) => e.model.tools).length} models');
    await tester.tap(find.byKey(const Key('aor_close')));
    await tester.pumpAndSettle();
    // nothing kept (the user keeps no downloads) and no connection
    cache.enabled = false;
    siteFetch = (url, headers) async => throw const SocketException('offline');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_failed')), findsOneWidget);
    expect(find.textContaining('could not be reached'), findsOneWidget);
    siteFetch = (url, headers) async => sample;
    await tester.tap(find.byKey(const Key('aor_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_failed')), findsNothing);
    expect(find.byKey(const Key('aor_list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final theme in Brightness.values) {
    testWidgets('fits a phone (360 × 640) in the ${theme.name} theme, with the keyboard up too', (tester) async {
      final chosen = <AiModel?>[];
      await open(tester, chosen, size: const Size(360, 640), theme: theme);
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byKey(const Key('aor_dialog')));
      expect(box.width, lessThanOrEqualTo(360));
      expect(box.height, lessThanOrEqualTo(640));
      expect(find.byKey(const Key('aor_row_0')), findsOneWidget, reason: 'rows in sight at once');
      // the note on free models opens on a tap
      expect(find.byKey(const Key('aor_free_note')), findsNothing);
      await tester.tap(find.byKey(const Key('aor_free_more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aor_free_note')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // the keyboard takes 300 px: the list shrinks, nothing overflows
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('aor_list'))).height, greaterThan(80), reason: 'the search and a few rows stay usable');
      await tester.scrollUntilVisible(
        find.byKey(const Key('aor_row_0')),
        100,
        scrollable: find.descendant(of: find.byKey(const Key('aor_list')), matching: find.byType(Scrollable)),
      );
      await tester.tap(find.byKey(const Key('aor_row_0')));
      await tester.pumpAndSettle();
      expect(chosen.single, isNotNull);
    });
  }
}
