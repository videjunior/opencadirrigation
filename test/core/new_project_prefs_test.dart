/// What new projects start with (1.6.0 MOD): the mains frequency and the
/// currency of the region unless chosen, the units the user chose (never
/// the US ones by the region alone), and the parameters of a project kept
/// as the template of the next ones; forgotten on request.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/new_project_prefs.dart';
import 'package:opencadirrigation/core/model/regional.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  late ProjectController c;
  setUp(() {
    setPref('lang', 'en');
    for (final k in const [newProjectParamsPref, newProjectCurrencyPref, newProjectHzPref, newProjectUnitsPref]) {
      removePref(k);
    }
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
  });
  tearDown(() {
    for (final k in const [newProjectParamsPref, newProjectCurrencyPref, newProjectHzPref, newProjectUnitsPref]) {
      removePref(k);
    }
  });

  test('without choices: the frequency of the region, metric units, the program\'s parameters', () {
    expect(c.hasNewProjectChoices, isFalse);
    final region = c.machineRegion;
    expect(c.project.params.mainsHz, region == null ? mainsHzForLocale(c.lang, ProjectController.systemLanguageTags()) : mainsHzForRegion(region));
    expect(c.project.params.units.toJson(), Units.metric.toJson(), reason: 'US units are never taken from the region alone');
    final s = c.newProjectSources;
    expect(s.units, DefaultSource.program);
    expect(s.hz, region == null ? DefaultSource.program : DefaultSource.region);
    expect(c.newProjectDefaultsText(), contains('${c.project.params.mainsHz.round()} Hz'));
  });

  test('the parameters of a project kept for the next ones, then forgotten', () {
    c.project.params
      ..maxZoneVelocity = 1.7
      ..interestRate = 0.08
      ..mainsHz = 50
      ..units = Units.us;
    c.saveParamsAsDefault();
    expect(c.hasNewProjectChoices, isTrue);
    expect(c.newProjectSources.hz, DefaultSource.chosen);
    expect(c.newProjectSources.units, DefaultSource.chosen);
    c.newProject();
    final p = c.project.params;
    expect(p.maxZoneVelocity, 1.7);
    expect(p.interestRate, 0.08);
    expect(p.mainsHz, 50);
    expect(p.units.toJson(), Units.us.toJson());
    expect(c.newProjectDefaultsText(), contains('50 Hz'));
    c.clearParamsDefault();
    expect(c.hasNewProjectChoices, isFalse);
    c.newProject();
    expect(c.project.params.maxZoneVelocity, isNot(1.7));
    expect(c.project.params.units.toJson(), Units.metric.toJson());
  });

  test('a template that cannot be read leaves the defaults', () {
    setPref(newProjectParamsPref, '{not json');
    c.newProject();
    expect(c.project.params.units.toJson(), Units.metric.toJson());
  });
}
