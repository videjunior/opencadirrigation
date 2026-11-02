import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_coverage.dart';
import 'package:opencadirrigation/app/ai/op_parts/fmt.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/io/data_cache_store.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/data_cache_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/points_import_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/share_confirm_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/stakeout_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The functions of 1.6.0 for file formats in the interface and for the AI
/// assistant: the points import wizard, the stake-out points, the downloads
/// kept on the device, the question before a large shared project, and the
/// operations of the assistant for each of them.
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => [for (final _ in questions) ''];
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => const PlanDecision.approved(AgentPermission.auto);
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

/// Points of Rio de Janeiro as latitude, longitude, elevation (degrees with
/// five decimals, no header).
const _rio = '-22.90681,-43.17291,10\n-22.90702,-43.17313,12\n-22.90724,-43.17305,11\n';

void main() {
  late ProjectController c;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
  });

  Future<BuildContext> app(WidgetTester tester) async {
    late BuildContext ctx;
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('the points wizard shows the columns, swaps latitude and longitude and imports', (tester) async {
    final ctx = await app(tester);
    final result = showPointsImportDialog(ctx, c, 'rio.csv', Uint8List.fromList(utf8.encode(_rio)));
    await tester.pumpAndSettle();
    expect(find.text(c.t('ptsimp.title')), findsOneWidget);
    expect(find.text('-22.90681'), findsOneWidget);
    expect(find.byKey(const Key('ptsimp_world')), findsOneWidget);
    expect(find.byKey(const Key('ptsimp_swap')), findsOneWidget);
    expect(find.text(c.t('ptsimp.count', {'n': '3', 's': '0'})), findsOneWidget);
    // latitude first: the centre is in Rio
    expect(find.byKey(const Key('ptsimp_centre')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('ptsimp_centre'))).data, contains('-22.9'));
    await tester.ensureVisible(find.byKey(const Key('ptsimp_swap')));
    await tester.tap(find.byKey(const Key('ptsimp_swap')));
    await tester.pumpAndSettle();
    // the other order puts the centre at latitude -43
    expect(tester.widget<Text>(find.byKey(const Key('ptsimp_centre'))).data, contains('-43.1'));
    await tester.ensureVisible(find.byKey(const Key('ptsimp_swap')));
    await tester.tap(find.byKey(const Key('ptsimp_swap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ptsimp_import')));
    await tester.pumpAndSettle();
    final summary = await result;
    expect(summary, contains('3'));
    expect(c.project.entities.whereType<SpotHeightEntity>(), hasLength(3));
    expect(c.project.meta.georef!.zone, 23);
    expect(c.project.meta.georef!.north, isFalse);
  });

  testWidgets('the stake-out dialog counts the points of the kinds chosen', (tester) async {
    final ctx = await app(tester);
    final cat = c.project.catalog;
    c.addEntity(ControlValveEntity(id: c.project.newId(), position: const Pt(0, 0), zoneName: 'Z1'));
    c.addEntity(OutletEntity(id: c.project.newId(), position: const Pt(5, 5), outletSpecId: cat.outlets.first.id));
    c.addEntity(PipeEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(0, 50)], scope: HydraulicScope.zone, pipeSpecId: cat.pipes.first.id));
    showStakeoutDialog(ctx, c);
    await tester.pumpAndSettle();
    // the valve, the head and the far end of the pipe (its start is the valve)
    expect(find.text(c.t('stake.count', {'n': '3'})), findsOneWidget);
    expect(find.byKey(const Key('stake_no_georef')), findsOneWidget);
    expect(find.byKey(const Key('stake_no_terrain')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stake_kind_outlets')));
    await tester.pumpAndSettle();
    expect(find.text(c.t('stake.count', {'n': '2'})), findsOneWidget);
    await tester.tap(find.text(c.t('cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the downloads kept: their size by kind, cleared by kind', (tester) async {
    final ctx = await app(tester);
    final store = MemoryDataCacheStore();
    final dc = DataCache(store);
    await dc.bytes((url) async => List.filled(2000, 7), 'dem')('tile/1');
    await dc.text((url) async => '{"daily":{}}', 'climate')('series/1');
    expect(store.values.keys, ['dem:tile/1', 'climate:series/1']);
    // a second request is answered by the store
    expect(await dc.bytes((url) async => throw StateError('no network'), 'dem')('tile/1'), hasLength(2000));
    expect(dc.hits, 1);
    showDataCacheDialog(ctx, c, cache: dc);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cache_stats_dem')), findsOneWidget);
    expect(find.textContaining('2 kB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cache_clear_dem')));
    await tester.pumpAndSettle();
    expect(store.values.keys, ['climate:series/1']);
    await tester.tap(find.text(c.t('close')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a large project from a link opens only when the user says so', (tester) async {
    final ctx = await app(tester);
    expect(await confirmSharedProject(ctx, c, '{"entities":[]}'), isTrue);
    final big = '{"entities":[${List.filled(30000, '{"type":"line","id":"e1","a":[0,0],"b":[1,1]}').join(',')}]}';
    expect(big.length, greaterThan(shareLinkConfirmChars));
    bool? large;
    final f = confirmSharedProject(ctx, c, big).then((v) => large = v);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share_large_body')), findsOneWidget);
    expect(find.textContaining('30000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share_large_open')));
    await tester.pumpAndSettle();
    await f;
    expect(large, isTrue);
    // and declined
    final g = confirmSharedProject(ctx, c, big).then((v) => large = v);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share_large_cancel')));
    await tester.pumpAndSettle();
    await g;
    expect(large, isFalse);
  });

  group('the operations of the assistant', () {
    late _Host host;
    late AgentToolbox box;
    final saveFiles = engFileSink;
    final files = <String, Object>{};

    setUp(() {
      host = _Host();
      box = AgentToolbox(c, host: host);
      files.clear();
      engFileSink = (c, name, mime, data) async => files[name] = data;
    });
    tearDown(() => engFileSink = saveFiles);

    AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);

    testWidgets('names, descriptions, schemas, summaries and routes', (tester) async {
      final mine = opsFmt(box);
      expect(mine.map((o) => o.name), containsAll(['preview_points_attachment', 'import_points_attachment', 'export_stakeout_points', 'data_cache_info', 'set_data_cache', 'clear_data_cache']));
      for (final o in mine) {
        expect(o.description.length, greaterThan(150), reason: o.name);
        expect(o.inputSchema['type'], 'object', reason: o.name);
        expect(o.describe(const {}).startsWith('ai.op.'), isFalse, reason: o.name);
        expect(box.operations.where((x) => x.name == o.name), hasLength(1), reason: o.name);
      }
      expect(op('export_stakeout_points').effect, ToolEffect.export);
      expect(op('export_stakeout_points').mustConfirm(const {}), isTrue);
      expect(op('clear_data_cache').mustConfirm(const {}), isTrue);
      expect(op('import_points_attachment').effect, ToolEffect.write);
      for (final k in ['menu:exp.stakeout', 'menu:cache.menu', 'dialog:points_import_dialog.pointsImport', 'dialog:stakeout_dialog.stakeout', 'dialog:data_cache_dialog.dataCache']) {
        expect(aiCoverage[k], isNotNull, reason: k);
      }
    });

    testWidgets('a points file: looked at, then imported with the columns and the system given', (tester) async {
      host.files['rio.csv'] = Uint8List.fromList(utf8.encode(_rio));
      final look = await op('preview_points_attachment').run({'name': 'rio.csv'});
      expect(look.text, contains('3 points'));
      expect(look.text, contains('lat=0'));
      expect(look.text, contains('lat -22.9'));
      expect(c.project.entities, isEmpty, reason: 'a preview changes nothing');
      final out = await op('import_points_attachment').run({
        'name': 'rio.csv',
        'columns': {'lat': 0, 'lon': 1, 'z': 2},
        'crs': 'geographic',
        'datum': 'sirgas2000',
      });
      expect(out.text, startsWith('Imported rio.csv'));
      expect(c.project.entities.whereType<SpotHeightEntity>(), hasLength(3));
      expect(c.project.meta.georef!.zone, 23);
      await expectLater(op('import_points_attachment').run({'name': 'none.csv'}), throwsA(isA<ToolInputError>()));
      await expectLater(op('import_points_attachment').run({'name': 'rio.csv', 'columns': {'x': -1}}), throwsA(isA<ToolInputError>()));
    });

    testWidgets('the stake-out points as a file, and the downloads kept', (tester) async {
      c.setGeoreference(const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253000));
      c.addEntity(ControlValveEntity(id: c.project.newId(), position: const Pt(1, 2), zoneName: 'Z1'));
      final out = await op('export_stakeout_points').run({
        'order': 'penzd',
        'kinds': ['valves'],
      });
      expect(out.text, contains('1 points'));
      final text = files.values.single as String;
      expect(text, startsWith('1,186001.000,8253002.000,,'));
      expect(text, contains('Z1'));
      await expectLater(
        op('export_stakeout_points').run({
          'kinds': ['lateral_ends'],
        }),
        throwsA(isA<ToolInputError>()),
      );
      final info = await op('data_cache_info').run(const {});
      expect(info.text, contains('dem:'));
      expect(info.text, contains('climate:'));
      final keep = appDataCache().enabled;
      await op('set_data_cache').run({'enabled': false});
      expect(appDataCache().enabled, isFalse);
      await op('set_data_cache').run({'enabled': keep});
      expect(appDataCache().enabled, keep);
      final cleared = await op('clear_data_cache').run({'kind': 'dem'});
      expect(cleared.text, startsWith('Cleared'));
    });
  });
}
