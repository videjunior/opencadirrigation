import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Automatic analysis: a moment after an edit the design is analysed again
/// without sizing (the drawing stays as it is), and an analysis overtaken by
/// an edit is thrown away and redone.
void main() {
  setUp(() {
    removePref('design.auto');
    ProjectController.autoAnalysisDelay = const Duration(milliseconds: 30);
  });

  ProjectController example() {
    final c = ProjectController()
      ..setLanguage('pt')
      ..designRunner = InThreadDesignRunner()
      ..autosaveEnabled = false;
    loadExampleAction(c, ExampleId.garden);
    return c;
  }

  Future<void> settle(ProjectController c) async {
    for (var i = 0; i < 400 && (c.results == null || c.autoRunning); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('an edit brings the results back after the quiet time, without sizing', () async {
    final c = example();
    c.autoAnalyze = true;
    await settle(c);
    final specs = {for (final p in c.project.entities.whereType<PipeEntity>()) p.id: p.pipeSpecId};
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(5, 0)));
    expect(c.results, isNull, reason: 'the edit invalidates the results');
    await settle(c);
    expect(c.results, isNotNull);
    expect(c.results!.method, 'analysis');
    expect({for (final p in c.project.entities.whereType<PipeEntity>()) p.id: p.pipeSpecId}, specs, reason: 'nothing is resized');
    // an edit while it runs: the overtaken analysis is dropped and redone
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(0, 5)));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(5, 5)));
    await settle(c);
    expect(c.results, isNotNull);
    expect(c.autoRunning, isFalse);
    c.autoAnalyze = false;
    c.dispose();
  });

  test('switched off, edits leave the results empty; the choice is remembered', () async {
    final c = example();
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(5, 0)));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(c.results, isNull);
    c.autoAnalyze = true;
    expect(getPref('design.auto'), '1');
    c.autoAnalyze = false;
    expect(getPref('design.auto'), isNull);
  });
}
