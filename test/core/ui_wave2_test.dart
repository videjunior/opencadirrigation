import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/project_name.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/ui_prefs.dart';
import 'package:opencadirrigation/app/version.dart';
import 'package:opencadirrigation/app/widgets/dialogs/command_palette.dart';
import 'package:opencadirrigation/app/widgets/dialogs/feedback_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/help_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/whats_new_dialog.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The logic of the interface functions of 1.6.0 (wave 2): the name of an
/// unnamed project, the command palette's search, the manual's subjects and
/// their chapters, the report's diagnostics and address, what is new, the
/// interface preferences and the high-contrast palette, the tutorial's
/// tracks, touch texts and saved progress, a large linked project, and the
/// decimal separator guessed for point and catalogue tables.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pt = I18n('pt'), en = I18n('en'), es = I18n('es');

  group('a new project has no name of its own', () {
    test('empty, or the default an earlier version wrote, reads "New project" in the language of the moment', () {
      for (final n in ['', '  ', 'Novo projeto', 'New project', 'Nuevo proyecto']) {
        expect(isUnnamedProject(n), isTrue, reason: n);
        expect(projectTitle(en, n), 'New project');
        expect(projectTitle(pt, n), 'Novo projeto');
        expect(projectTitle(es, n), 'Nuevo proyecto');
      }
      expect(isUnnamedProject('Fazenda Boa Vista'), isFalse);
      expect(projectTitle(en, ' Fazenda Boa Vista '), 'Fazenda Boa Vista');
      expect(projectFileStem(en, ''), 'New_project');
      expect(projectFileStem(pt, 'Pomar 2/3'), 'Pomar_2_3');
      final unnamed = StoredProject(uid: 'p1', name: '', savedAt: DateTime(2026, 11, 2, 9, 5), kind: 'autosave', bytes: 10);
      expect(storedProjectLabel(en, unnamed), startsWith('New project · 2026-11-02'));
      expect(storedProjectLabel(en, StoredProject(uid: 'p2', name: 'Horta', savedAt: DateTime(2026), kind: 'saved', bytes: 1)), 'Horta');
    });

    test('the controller and the model leave the name empty; the language never sticks to it', () async {
      expect(ProjectMeta().name, '');
      expect(Project().meta.name, '');
      final c = ProjectController()..autosaveEnabled = false;
      await c.setLanguage('pt', persist: false);
      c.newProject();
      expect(c.project.meta.name, '', reason: 'nothing written in the language the tab was created in');
      await c.setLanguage('en', persist: false);
      expect(projectTitle(c.t, c.project.meta.name), 'New project');
      // an unnamed project exports under "New project" of the export language
      c.setGeoreferenceAt(-21.4459, -45.4592);
      final kml = c.exporter().kml();
      expect(kml, contains('New project'));
    });
  });

  group('the command palette', () {
    test('accents and case do not matter; every word must appear; the best match comes first', () {
      expect(foldSearch('  Ação  Pivô '), 'acao pivo');
      final entries = [
        PaletteEntry(label: 'Densograma…', path: 'Zona', run: () {}),
        PaletteEntry(label: 'Desfazer', path: 'Editar', shortcut: 'Ctrl+Z', keywords: 'Undo U UNDO', run: () {}),
        PaletteEntry(label: 'Exportar desenho', path: 'Arquivo', keywords: 'Export drawing'),
        PaletteEntry(label: 'Projetar tudo', path: 'Projeto', shortcut: 'F5', keywords: 'Design all RUN', run: () {}),
      ];
      expect(rankPalette(entries, '').length, entries.length);
      expect(rankPalette(entries, 'dens').map((e) => e.label), ['Densograma…']);
      expect(rankPalette(entries, 'undo').first.label, 'Desfazer', reason: 'the English name and the aliases are searched');
      expect(rankPalette(entries, 'run').first.label, 'Projetar tudo', reason: 'a typed alias equal to the query comes first');
      expect(rankPalette(entries, 'export desenho').map((e) => e.label), ['Exportar desenho']);
      expect(rankPalette(entries, 'xyz'), isEmpty);
      // an entry that cannot run now still shows, after those that can
      final both = rankPalette([PaletteEntry(label: 'Desenho A'), PaletteEntry(label: 'Desenho B', run: () {})], 'desenho');
      expect(both.first.label, 'Desenho B');
      expect(both.last.enabled, isFalse);
    });

    test('the leaves of the menus: actions, switches and choices with their paths, run as the menu would', () {
      var undone = 0;
      bool? grid = false;
      String? lang;
      final menus = <Widget>[
        SubmenuButton(
          menuChildren: [
            MenuItemButton(onPressed: () => undone++, trailingIcon: const Text('Ctrl+Z'), leadingIcon: const Icon(Icons.undo), child: const Text('Desfazer')),
            MenuItemButton(onPressed: null, child: const Text('Colar')),
            SubmenuButton(
              menuChildren: [
                CheckboxMenuButton(value: grid, onChanged: (v) => grid = v, child: const Text('Grade  (F7)')),
                RadioMenuButton<String>(value: 'en', groupValue: 'pt', onChanged: (v) => lang = v, child: const Text('English')),
              ],
              child: const Text('Ver'),
            ),
          ],
          child: const Text('Editar'),
        ),
      ];
      final out = paletteFromMenus(menus, englishOf: englishLabels(pt));
      expect(out.map((e) => e.label), ['Desfazer', 'Colar', 'Grade  (F7)', 'English']);
      expect(out.first.path, 'Editar');
      expect(out.first.shortcut, 'Ctrl+Z');
      expect(out.first.icon, Icons.undo);
      expect(out[1].enabled, isFalse);
      expect(out[2].path, 'Editar › Ver');
      expect(out[2].checked, isFalse);
      expect(out[3].checked, isFalse);
      out.first.run!();
      out[2].run!();
      out[3].run!();
      expect(undone, 1);
      expect(grid, isTrue);
      expect(lang, 'en', reason: 'a choice runs with its own value type');
      // the English name of a Portuguese label (one written with its shortcut too)
      final english = englishLabels(pt);
      expect(english('Desfazer'), 'Undo');
      expect(english('Grade  (F7)'), en('view.grid'));
      expect(englishLabels(en)('Undo'), '');
    });

    test('the typed commands and the switches of the screen are entries too', () {
      final c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      final typed = <String>[];
      final all = buildPaletteEntries(c, runAlias: typed.add);
      final line = rankPalette(all, 'pline').first;
      expect(line.label, c.t('tool.polyline'));
      line.run!();
      expect(typed, isNotEmpty);
      final snap = all.firstWhere((e) => e.label == c.t('status.snap'));
      final before = c.snap.enabled;
      snap.run!();
      expect(c.snap.enabled, !before);
      expect(all.any((e) => e.label == c.t('uiv.contrast')), isTrue);
    });
  });

  group('the manual', () {
    test('every subject is written in the three languages and the dialogs it explains exist', () {
      expect(helpTopics.map((h) => h.id).toSet().length, helpTopics.length);
      for (final h in helpTopics) {
        for (final t in [pt, en, es]) {
          expect(t.has('help.t.${h.id}') && t.has('help.b.${h.id}'), isTrue, reason: h.id);
        }
        expect(pt('help.b.${h.id}'), isNot(en('help.b.${h.id}')), reason: '${h.id} translated');
        expect(es('help.b.${h.id}'), isNot(en('help.b.${h.id}')), reason: '${h.id} translated');
        for (final k in h.titleKeys) {
          expect(en.has(k), isTrue, reason: '${h.id}: $k');
        }
      }
      expect(helpTopicForTitle(pt, pt('design.params')), 'params');
      expect(helpTopicForTitle(en, en('design.catalog')), 'catalog');
      expect(helpTopicForTitle(en, 'Something else'), isNull);
    });

    test('each subject links to a chapter and a section that exist, in English and in Portuguese', () {
      String anchors(String path) => [for (final l in File(path).readAsLinesSync()) if (l.startsWith('#')) githubAnchor(l.replaceFirst(RegExp(r'^#+\s*'), ''))].join('\n');
      for (final h in helpTopics) {
        final enFile = 'docs/manual/${h.chapter}.md', ptFile = 'docs/manual/pt-BR/${h.chapter}.md';
        expect(File(enFile).existsSync() && File(ptFile).existsSync(), isTrue, reason: h.chapter);
        if (h.heading.isNotEmpty) expect(anchors(enFile).split('\n'), contains(githubAnchor(h.heading)), reason: '${h.id}: ${h.heading}');
        if (h.headingPt.isNotEmpty) expect(anchors(ptFile).split('\n'), contains(githubAnchor(h.headingPt)), reason: '${h.id}: ${h.headingPt}');
        expect(helpChapterUrl('pt', h), contains('/docs/manual/pt-BR/${h.chapter}.md'));
        expect(helpChapterUrl('de', h), contains('/docs/manual/${h.chapter}.md'));
      }
      expect(githubAnchor('Design parameters (Design → Design parameters)'), 'design-parameters-design--design-parameters');
      expect(githubAnchor('Projeto (`.oci.json`)'), 'projeto-ocijson');
      expect(githubAnchor('Seleção e grips'), 'seleção-e-grips');
    });
  });

  group('the report to the project', () {
    test('the browser and the system from the user agent', () {
      expect(describeClient('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'), 'Chrome 131 · macOS');
      expect(describeClient('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0'), 'Edge 131 · Windows');
      expect(describeClient('Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1'), 'Safari 18 · iOS');
      expect(describeClient('Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0'), 'Firefox 133 · Linux');
      expect(describeClient('Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'), 'Chrome 131 · Android');
      expect(describeClient(''), '');
    });

    test('the diagnostics say nothing of the user nor of what the project holds', () {
      final c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      c.project.meta
        ..name = 'Fazenda Secreta'
        ..client = 'Cliente X'
        ..site = 'Rua Y, 123';
      final d = feedbackDiagnostics(c, userAgent: 'Mozilla/5.0 (Windows NT 10.0) Chrome/131.0.0.0', screen: const Size(1440, 900), pixelRatio: 2, layout: 'wide').join('\n');
      expect(d, contains(appVersionLabel));
      expect(d, contains('Chrome 131 · Windows'));
      expect(d, contains('1440 × 900'));
      expect(d, contains('0 items'));
      for (final private in ['Fazenda', 'Cliente', 'Rua']) {
        expect(d, isNot(contains(private)));
      }
      final body = feedbackBody(en, FeedbackKind.problem, details: 'It froze.', steps: '1. Press F5', diagnostics: ['A', 'B']);
      expect(body, contains('### What happened\nIt froze.'));
      expect(body, contains('### Steps to repeat\n1. Press F5'));
      expect(body, contains('### Diagnostics\n- A\n- B'));
      expect(feedbackBody(pt, FeedbackKind.idea, details: 'Quadro de outorga', diagnostics: const []), isNot(contains(pt('fb.h.steps'))));
    });

    test('the issue form: title, body, template and label in the address; a long body is cut to fit', () {
      final (url, cut) = feedbackIssueUrl(FeedbackKind.problem, 'Freezes', 'Body text');
      final u = Uri.parse(url);
      expect(url, startsWith('$appRepositoryUrl/issues/new?'));
      expect(u.queryParameters['title'], 'Freezes');
      expect(u.queryParameters['body'], 'Body text');
      expect(u.queryParameters['labels'], 'bug');
      expect(u.queryParameters['template'], 'bug_report.md');
      expect(cut, isFalse);
      final (long, wasCut) = feedbackIssueUrl(FeedbackKind.idea, 'Idea', 'ç' * 20000);
      expect(wasCut, isTrue);
      expect(Uri.encodeComponent(Uri.parse(long).queryParameters['body']!).length, lessThanOrEqualTo(feedbackMaxEncodedBody));
      expect(Uri.parse(long).queryParameters['labels'], 'enhancement');
    });
  });

  group('what is new', () {
    setUp(() {
      removePref(whatsNewSeenPref);
      TutorialController.reset();
      LocalProjectStore().clearAll();
    });

    test('every highlight is written in the three languages', () {
      for (final v in whatsNewNotes.keys) {
        for (final k in whatsNewKeys(v)) {
          for (final t in [pt, en, es]) {
            expect(t.has(k), isTrue, reason: k);
          }
        }
      }
      expect(whatsNewKeys(whatsNewVersion), isNotEmpty);
      expect(changelogUrl('pt'), endsWith('CHANGELOG.pt-BR.md'));
      expect(changelogUrl('es'), endsWith('CHANGELOG.md'));
    });

    test('once per version, and only to someone who used an earlier one', () {
      final c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      // a first visit notes the version and says nothing
      expect(shouldShowWhatsNew(c), isFalse);
      expect(getPref(whatsNewSeenPref), appVersion);
      expect(shouldShowWhatsNew(c), isFalse, reason: 'this version was seen');
      // an earlier version seen: shown when this version has news
      setPref(whatsNewSeenPref, '0.9.0');
      expect(shouldShowWhatsNew(c), whatsNewNotes.containsKey(appVersion));
      expect(shouldShowWhatsNew(c), isFalse, reason: 'once');
      // no version seen, but the tutorial done (an earlier version's user)
      removePref(whatsNewSeenPref);
      TutorialController.markDone();
      expect(shouldShowWhatsNew(c), whatsNewNotes.containsKey(appVersion));
    });
  });

  group('the interface preferences', () {
    tearDown(() {
      for (final k in ['ui_scale', 'ui_contrast', 'ui_side_folded', 'ui_side_width', 'ui_reports_height']) {
        removePref(k);
      }
      reloadUiPrefs();
    });

    test('size, contrast, the side panel and the reports height are kept and brought into range', () {
      setUiScale(1.3);
      expect(getPref('ui_scale'), '1.3');
      setUiScale(9);
      expect(uiScale.value, uiScaleMax);
      setUiScale(1);
      expect(getPref('ui_scale'), isNull, reason: 'the default is not written');
      expect(nextUiScale(up: true), 1.15);
      expect(nextUiScale(up: false), 0.85);
      setUiScale(1.5);
      expect(nextUiScale(up: true), 1.5, reason: 'the largest stays');
      setHighContrast(true);
      setSideFolded(true);
      setSideWidth(5000);
      saveReportsHeight(333);
      reloadUiPrefs();
      expect(uiScale.value, 1.5);
      expect(uiHighContrast.value, isTrue);
      expect(uiSideFolded.value, isTrue);
      expect(uiSideWidth.value, sidePanelWidthMax);
      expect(savedReportsHeight(), 333);
      expect(uiFocusMode.value, isFalse, reason: 'focus mode lasts for the session only');
    });

    test('the high-contrast palettes: 7:1 for the secondary labels on every surface, in both themes', () {
      double lum(Color c) => c.computeLuminance();
      double ratio(Color fg, Color bg) {
        // the colour as drawn on the surface (the labels are translucent)
        final a = fg.a;
        final mixed = Color.from(alpha: 1, red: fg.r * a + bg.r * (1 - a), green: fg.g * a + bg.g * (1 - a), blue: fg.b * a + bg.b * (1 - a));
        final l1 = math.max(lum(mixed), lum(bg)), l2 = math.min(lum(mixed), lum(bg));
        return (l1 + 0.05) / (l2 + 0.05);
      }

      for (final p in [CadPalette.darkHigh, CadPalette.lightHigh]) {
        for (final surface in [p.panel, p.dialog, p.background, p.card]) {
          for (final text in [p.fg, p.fg87, p.fg70, p.fg60, p.fg54, p.fg38]) {
            expect(ratio(text, surface), greaterThanOrEqualTo(7), reason: '${p.brightness} ${text.toARGB32().toRadixString(16)} on ${surface.toARGB32().toRadixString(16)}');
          }
          expect(ratio(p.accentText, surface), greaterThanOrEqualTo(4.5));
          expect(ratio(p.error, surface), greaterThanOrEqualTo(4.5));
        }
      }
      expect(identical(CadPalette.of(Brightness.dark), CadPalette.dark), isTrue);
      setHighContrast(true);
      expect(identical(CadPalette.of(Brightness.dark), CadPalette.darkHigh), isTrue);
      expect(identical(CadPalette.of(Brightness.light), CadPalette.lightHigh), isTrue);
      setHighContrast(false);
      expect(identical(CadPalette.of(Brightness.light), CadPalette.light), isTrue);
    });
  });

  group('the tutorial', () {
    tearDown(() => removePref(TutorialController.progressKey));

    test('the tracks take their steps from the full tutorial, each starting at the overview and ending with the closing step', () {
      final all = buildTutorialSteps('en');
      final ids = [for (final s in all) s.id];
      expect(ids.toSet().length, ids.length, reason: 'unique ids');
      for (final e in tutorialTrackSteps.entries) {
        final track = tutorialTrack(all, e.key);
        expect(track.length, e.value.length, reason: '${e.key}: every id exists');
        expect(track.first.id, 'welcome');
        expect(track.last.id, 'shortcuts');
        expect(track.length, lessThan(all.length));
      }
      expect(tutorialTrack(all, TutorialTrack.full), same(all));
      for (final quick in [TutorialTrack.drip, TutorialTrack.landscape, TutorialTrack.pivot]) {
        expect(tutorialTrackSteps[quick]!.length, inInclusiveRange(10, 14), reason: 'a short track (PRD-24)');
      }
      expect(tutorialChapters(all), contains('Automatic design and documents'));
      expect(tutorialChapters(all), contains('AI assistant'));
    });

    test('every step that asks for the mouse or the keyboard has a version for touch screens, in the three languages', () {
      final mouse = RegExp(r'\b(click|press|type|drag|wheel|roll|Ctrl|Del|Enter|Home|F\d)\b', caseSensitive: false);
      for (final lang in ['en', 'pt', 'es']) {
        final steps = buildTutorialSteps(lang);
        final english = buildTutorialSteps('en');
        for (var i = 0; i < steps.length; i++) {
          final action = english[i].action;
          if (action == null || !mouse.hasMatch(action)) continue;
          expect(steps[i].touchAction, isNotNull, reason: '$lang ${steps[i].id}: "$action"');
          expect(english[i].touchAction!, isNot(matches(RegExp(r'\b(click|press|wheel|Ctrl)\b', caseSensitive: false))), reason: english[i].id);
          if (lang != 'en') expect(steps[i].touchAction, isNot(english[i].touchAction), reason: '$lang ${steps[i].id} translated');
        }
      }
      final zoom = buildTutorialSteps('en').firstWhere((s) => s.id == 'zoom');
      expect(zoom.actionFor(touch: true), contains('Pinch'));
      expect(zoom.actionFor(touch: false), contains('mouse wheel'));
      expect(zoom.bodyFor(touch: true), isNot(contains('mouse')));
    });

    test('the steps of 1.1 to 1.5 and of 1.6: automatic design, documents, search, help and the AI that only writes', () {
      final steps = buildTutorialSteps('en');
      final ids = [for (final s in steps) s.id];
      for (final id in ['autoMenu', 'subdivide', 'pivotFit', 'fixOptimize', 'budget', 'sheets', 'field', 'palette', 'manual', 'interfacePrefs']) {
        expect(ids, contains(id));
      }
      final export = steps.firstWhere((s) => s.id == 'export').body;
      for (final f in ['DGN', 'vector PDF', 'GeoJSON', 'GPX', 'LandXML', 'LAS', 'EPANET', 'IFC', 'Shapefile', 'PNG']) {
        expect(export, contains(f));
      }
      final open = steps.firstWhere((s) => s.id == 'aiOpen');
      expect(open.interactive, isTrue, reason: 'it watches the panel');
      expect(open.demo, isNotNull);
      for (final id in ['aiKey', 'aiAsk', 'aiReview']) {
        expect(steps.firstWhere((s) => s.id == id).demo, isNotNull, reason: '$id shows the panel');
      }
    });

    test('where the user stopped is kept for "continue", and cleared at the end of the track', () {
      final all = buildTutorialSteps('en');
      final tc = TutorialController()..start(all);
      expect(TutorialController.savedProgress(), isNull, reason: 'starting writes nothing (an older place is kept)');
      tc.goTo(5);
      expect(TutorialController.savedProgress(), (TutorialTrack.full, all[5].id));
      tc.switchTrack(TutorialTrack.touch);
      expect(tc.steps.length, tutorialTrackSteps[TutorialTrack.touch]!.length);
      tc.next();
      expect(TutorialController.savedProgress(), (TutorialTrack.touch, tc.current.id));
      tc.skip();
      expect(TutorialController.savedProgress(), isNotNull, reason: 'skipped: kept');
      final again = TutorialController()..start(all);
      expect(again.resume(), isTrue);
      expect(again.track, TutorialTrack.touch);
      expect(again.current.id, tutorialTrackSteps[TutorialTrack.touch]![1]);
      again.goToChapter('AI assistant');
      expect(again.current.id, 'aiOpen');
      again.goTo(again.steps.length - 1);
      again.next();
      expect(TutorialController.savedProgress(), isNull, reason: 'finished: nothing to continue');
      tc.dispose();
      again.dispose();
    });
  });

  group('tables read in the notation they are written in (UI-08)', () {
    test('points: "1.250" is 1250 in a file of decimal commas, 1.25 in a file of decimal points', () {
      final comma = PointsCsvReader.parse('E;N;Z\n512345,5;7654321,25;1.250\n512346,5;7654322,25;801,5\n');
      expect(comma.document.entities.length, 2);
      final zs = comma.document.entities.map((e) => e.elevation).toList();
      expect(zs, containsAll([1250.0, 801.5]));
      final point = PointsCsvReader.parse('E,N,Z\n512345.5,7654321.25,1.250\n512346.5,7654322.25,801.5\n');
      final zp = point.document.entities.map((e) => e.elevation).toList();
      expect(zp, containsAll([1.25, 801.5]));
    });

    test('catalogue tables: a round trip through CSV, with decimal points or with decimal commas', () {
      final cat = Catalog.defaultCatalog();
      final csv = CatalogIo.exportCsv(cat, CatalogGroup.pipes);
      final back = CatalogIo.parseCsv(csv, group: CatalogGroup.pipes).catalog.pipes;
      expect(back.length, cat.pipes.length);
      expect(back.first.innerDiameterMm, closeTo(cat.pipes.first.innerDiameterMm, 1e-9));
      // the same table as a spreadsheet in Portuguese writes it: decimal commas
      final commas = csv.split('\n').map((l) => l.replaceAllMapped(RegExp(r'(?<=;|^)(-?\d+)\.(\d+)(?=;|$)'), (m) => '${m[1]},${m[2]}')).join('\n');
      final read = CatalogIo.parseCsv(commas, group: CatalogGroup.pipes).catalog.pipes;
      expect(read.first.innerDiameterMm, closeTo(cat.pipes.first.innerDiameterMm, 1e-9));
    });
  });
}
