import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/design_runner.dart' show createDesignRunner;
import 'package:opencadirrigation/app/state/design_runner_io.dart' show IsolateDesignRunner;
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The design job protocol (request → progress/done/error → apply) and the
/// runners that carry it: on the calling thread and in an isolate.
void main() {
  Project example() => buildExampleProject(I18n('pt').call, lang: 'pt');

  Map<String, String?> sizes(Project p) => {for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId};

  test('runDesignJob reports progress, then done, and its results match the in-thread design', () async {
    final reference = example();
    final expected = Designer(reference, label: I18n('pt').call).designAll();

    final p = example();
    final messages = <Map<String, dynamic>>[];
    await runDesignJob(DesignRequest.of(p, lang: 'pt').toJson(), messages.add);
    expect(messages.last['type'], 'done');
    expect(messages.where((m) => m['type'] == 'progress').length, greaterThanOrEqualTo(expected.zones.length + 4));
    expect(messages.any((m) => m['type'] == 'error'), isFalse);
    // the response survives a JSON round trip (worker/isolate transport)
    final response = DesignResponse.fromJson(jsonDecode(jsonEncode(messages.last)) as Map<String, dynamic>);
    // the job worked on a copy: the caller's project is untouched until applied
    expect(sizes(p), sizes(example()));
    expect(sizes(p), isNot(equals(sizes(reference))));
    applyDesignResponse(p, response);
    final r = response.results;
    expect(r.zones.keys.toSet(), expected.zones.keys.toSet());
    for (final e in r.zones.entries) {
      final z = expected.zones[e.key]!;
      expect(e.value.converged, z.converged);
      expect(e.value.totalFlow, closeTo(z.totalFlow, 1e-9));
      expect(e.value.minOutletPressure, closeTo(z.minOutletPressure, 1e-6));
      expect(e.value.pipes.length, z.pipes.length);
      expect(e.value.outlets.length, z.outlets.length);
    }
    expect(r.systemFlows.length, expected.systemFlows.length);
    expect(r.bom.length, expected.bom.length);
    expect(r.capitalCost, closeTo(expected.capitalCost, 1e-6));
    expect(r.flushing.length, expected.flushing.length);
    expect(r.surge.length, expected.surge.length);
    // the sized pipes (and any telescoped pieces) were written into the project
    expect(sizes(p), sizes(reference));
    expect(p.entities.length, reference.entities.length);
    expect(p.nextIdValue, reference.nextIdValue);
  });

  test('images stay on the UI side and keep their place after the job', () async {
    final p = example();
    final img = ImageEntity(id: p.newId(), origin: const Pt(0, 0), width: 10, height: 10, data: Uint8List.fromList(List.filled(50000, 7)));
    p.entities.insert(0, img);
    final req = DesignRequest.of(p, lang: 'pt');
    expect((req.project['entities'] as List).any((e) => (e as Map)['type'] == img.toJson()['type']), isFalse);
    // the request is far smaller than the project with its embedded image
    expect(jsonEncode(req.toJson()).length, lessThan(jsonEncode(p.toJson()).length - 40000));
    final r = await InThreadDesignRunner().run(req);
    applyDesignResponse(p, r);
    expect(identical(p.entities.first, img), isTrue);
    expect(p.entities.whereType<ImageEntity>().length, 1);
    expect(r.results.zones.length, 2);
  });

  test('errors inside the job come back as DesignJobException', () async {
    final bad = DesignRequest(project: {'format': 'nonsense'}, lang: 'pt');
    await expectLater(InThreadDesignRunner().run(bad), throwsA(isA<DesignJobException>().having((e) => e.message, 'message', contains('Not an OpenCADIrrigation project'))));
    await expectLater(IsolateDesignRunner().run(bad), throwsA(isA<DesignJobException>().having((e) => e.message, 'message', contains('Not an OpenCADIrrigation project'))));
  });

  test('isolate runner designs off the main isolate and streams progress', () async {
    expect(createDesignRunner(), isA<IsolateDesignRunner>());
    final p = example();
    final seen = <DesignProgress>[];
    String? mode;
    final r = await IsolateDesignRunner().run(DesignRequest.of(p, lang: 'pt'), onProgress: seen.add, onMode: (m) => mode = m);
    expect(mode, 'isolate');
    expect(seen.first.stage, DesignStage.zones);
    expect(seen.last.done, seen.last.total);
    expect(r.results.zones.length, 2);
    expect(r.results.systemFlows.length, 2);
    applyDesignResponse(p, r);
    expect(sizes(p).values.where((s) => s != null).length, greaterThan(0));
  });

  test('controller runs the design through the isolate runner and applies it', () async {
    setPref('lang', 'pt');
    final c = ProjectController();
    loadExampleAction(c);
    final modes = <String>[];
    var progressed = 0;
    c.addListener(() {
      if (c.busy && c.designMode.isNotEmpty && !modes.contains(c.designMode)) modes.add(c.designMode);
      if (c.progress != null) progressed++;
    });
    await c.runDesign();
    expect(modes, ['isolate']);
    expect(progressed, greaterThan(3));
    expect(c.busy, isFalse);
    expect(c.designMode, '');
    expect(c.results, isNotNull);
    expect(c.results!.zones.length, 2);
    expect(c.results!.zones.values.every((z) => z.converged), isTrue);
    expect(sizes(c.project).values.where((s) => s != null).length, greaterThan(0));
    expect(c.lastMessage, contains('Projeto concluído'));
    // analysis-only keeps the sizes just assigned
    final before = sizes(c.project);
    await c.runDesign(sizeZones: false, sizeMain: false);
    expect(sizes(c.project), before);
    expect(c.results!.method, 'analysis');
  });
}
