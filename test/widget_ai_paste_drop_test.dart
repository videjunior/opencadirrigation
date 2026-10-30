import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/file_drop.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_drop.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_panel.dart';

import 'support/fake_claude.dart';

/// Files into the AI chat by drag and drop and by paste, without a browser
/// (the router is driven with the events the browser listeners hand it):
/// the paperclip's checks for every file (kinds, size limits, several at
/// once, nothing while the assistant works, one notice for the files that
/// cannot go), the highlight while files are dragged over the panel, drops
/// on the panel and elsewhere in the window, the panel of the tab on screen,
/// a closed panel, pasted pictures named after their type, and which pastes
/// are pastes of files.
void main() {
  const key = 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000';
  final drops = AiFileDrop.instance;

  Future<ProjectController> newTab() async {
    final t = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    t.newProject();
    await t.setLanguage('en', persist: false);
    return t;
  }

  late ProjectController c;
  setUp(() async {
    LocalProjectStore().clearAll();
    AiAssistant.clearSessionKey();
    setPref(AiAssistant.keyPref, key);
    c = await newTab();
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
    drops.install(() => c);
  });
  tearDown(() {
    drops.uninstall();
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    removePref(AiAssistant.keyPref);
    AiAssistant.clearSessionKey();
    AiAssistant.panelOpen.value = false;
  });

  Uint8List png() => img.encodePng(img.Image(width: 8, height: 6));
  Uint8List jpg() => img.encodeJpg(img.Image(width: 8, height: 6));
  Uint8List text(String s) => Uint8List.fromList(s.codeUnits);
  AiAssistant ai([ProjectController? tab]) => AiAssistant.of(tab ?? c);
  List<String> names([ProjectController? tab]) => [for (final a in ai(tab).attachments) a.name];
  final overlay = find.byKey(const Key('ai_drop_overlay'));
  bool inputFocused(WidgetTester tester) => tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('ai_input')), matching: find.byType(EditableText))).focusNode.hasFocus;

  /// The docked panel beside a stand-in for the drawing, keyed by the tab
  /// it shows, as the shell lays it out.
  Future<void> pumpPanel(WidgetTester tester, {ValueNotifier<ProjectController>? shown}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final tab = shown ?? ValueNotifier(c);
    AiAssistant.panelOpen.value = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Placeholder()),
              ValueListenableBuilder<bool>(
                valueListenable: AiAssistant.panelOpen,
                builder: (_, open, _) => open
                    ? ValueListenableBuilder<ProjectController>(
                        valueListenable: tab,
                        builder: (_, pc, _) => SizedBox(
                          width: aiPanelWidth,
                          child: AiAgentPanel(key: ValueKey('ai_panel_${pc.tabId}'), c: pc),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the files be read and attached.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('every file goes through the paperclip\'s checks: kinds, size limits, several at once, one notice naming those refused', (tester) async {
    final quiet = c.messageSeq;
    expect(
      await aiAttachFiles(c, ai(), [
        DroppedFile.bytes('shot.png', png(), type: 'image/png'),
        DroppedFile.bytes('sheet.pdf', text('%PDF-1.4'), type: 'application/pdf'),
        DroppedFile.bytes('notes.txt', text('PVC 50 mm')),
        DroppedFile.bytes('site.dxf', text('0\nEOF\n')),
      ]),
      4,
    );
    expect(names(), ['shot.png', 'sheet.pdf', 'notes.txt', 'site.dxf']);
    expect(ai().attachments.first.isImage, isTrue);
    expect(ai().attachments.last.importOnly, isTrue, reason: 'a drawing is imported, not read by the model');
    expect(c.messageSeq, quiet, reason: 'nothing refused, nothing said');

    // one file refused: the paperclip's notice, as it was
    expect(await aiAttachFiles(c, ai(), [DroppedFile.bytes('letter.docx', text('Dear'))]), 0);
    expect(c.lastMessage, c.t('ai.attach.bad'));

    // several: the good ones go, the notice names the others; a file that
    // cannot go whatever its content is never read
    var reads = 0;
    DroppedFile sized(String name, int size) => DroppedFile(name, size, () async {
      reads++;
      return Uint8List(size);
    });
    const mb = 1024 * 1024;
    expect(
      await aiAttachFiles(c, ai(), [
        DroppedFile.bytes('field.jpg', jpg(), type: 'image/jpeg'),
        sized('photo.png', 21 * mb), // a picture may have 20 MB
        sized('survey.dwg', 21 * mb), // a drawing to import, 60 MB
        sized('video.mov', 10), // not a kind the assistant takes
        sized('lidar.las', 61 * mb), // over every limit
        DroppedFile('gone.pdf', 100, () async => throw StateError('moved away')),
      ]),
      2,
    );
    expect(names().skip(4), ['field.jpg', 'survey.dwg']);
    expect(reads, 2, reason: 'the movie and the 61 MB cloud were never read');
    expect(c.lastMessage, 'photo.png, video.mov, lidar.las, gone.pdf: ${c.t('ai.attach.bad')}');
  });

  testWidgets('while the assistant works nothing is attached, by drop or paste, as with the paperclip; the highlight says so', (tester) async {
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.hang()]).call;
    await pumpPanel(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Start the design');
    await tester.tap(find.byKey(const Key('ai_send')));
    await tester.pump(const Duration(milliseconds: 60));
    expect(ai().busy, isTrue);
    expect(tester.widget<IconButton>(find.byKey(const Key('ai_attach'))).onPressed, isNull, reason: 'the paperclip is off');

    expect(await aiAttachFiles(c, ai(), [DroppedFile.bytes('shot.png', png())]), 0);
    expect(c.lastMessage, c.t('ai.attach.busy'));

    final panel = tester.getRect(find.byKey(const Key('ai_panel')));
    drops.dragAt(panel.center);
    await tester.pump();
    expect(overlay, findsOneWidget);
    expect(find.descendant(of: overlay, matching: find.text(c.t('ai.attach.busy'))), findsOneWidget);
    var seq = c.messageSeq;
    drops.dropped(panel.center, [DroppedFile.bytes('shot.png', png())]);
    await settle(tester);
    expect(overlay, findsNothing);
    expect(ai().attachments, isEmpty);
    expect((c.messageSeq, c.lastMessage), (seq + 1, c.t('ai.attach.busy')));

    // the box keeps the cursor while the assistant works: a pasted picture is refused the same way
    await tester.tap(find.byKey(const Key('ai_input')));
    await tester.pump();
    expect(drops.takesPaste, isTrue);
    seq = c.messageSeq;
    drops.pasted([DroppedFile.bytes('image.png', png(), type: 'image/png')]);
    await settle(tester);
    expect(ai().attachments, isEmpty);
    expect((c.messageSeq, c.lastMessage), (seq + 1, c.t('ai.attach.busy')));

    ai().stop();
    for (var i = 0; i < 20 && ai().busy; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(ai().busy, isFalse);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('files dragged over the panel light it up; dropped there, or anywhere while it is open, every one is checked and the rest attached', (tester) async {
    await pumpPanel(tester);
    final panel = tester.getRect(find.byKey(const Key('ai_panel')));
    expect(overlay, findsNothing);
    drops.dragAt(panel.center);
    await tester.pump();
    expect(overlay, findsOneWidget);
    expect(find.descendant(of: overlay, matching: find.text(c.t('ai.attach.drop'))), findsOneWidget);
    expect(panel.contains(tester.getRect(overlay).center), isTrue, reason: 'over the panel, not the drawing');
    // over the drawing: no highlight; back on the panel; out of the window
    drops.dragAt(const Offset(200, 400));
    await tester.pump();
    expect(overlay, findsNothing);
    drops.dragAt(panel.topLeft + const Offset(20, 20));
    await tester.pump();
    expect(overlay, findsOneWidget);
    drops.dragAt(null);
    await tester.pump();
    expect(overlay, findsNothing);

    // the settings were showing: the files bring the conversation back, with the cursor in the box
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    expect(find.byKey(const Key('ai_input')), findsNothing);
    drops.dragAt(panel.center);
    await tester.pump();
    drops.dropped(panel.center, [
      DroppedFile.bytes('shot.png', png(), type: 'image/png'),
      DroppedFile.bytes('memo.docx', text('x')),
      DroppedFile.bytes('valves.csv', text('zone;valve')),
    ]);
    await settle(tester);
    expect(overlay, findsNothing);
    expect(names(), ['shot.png', 'valves.csv']);
    expect(c.lastMessage, 'memo.docx: ${c.t('ai.attach.bad')}');
    expect(find.byKey(const Key('ai_input')), findsOneWidget, reason: 'the conversation shows the files');
    expect(find.textContaining('shot.png ('), findsOneWidget, reason: 'its chip');
    expect(inputFocused(tester), isTrue);

    // dropped on the drawing while the panel is open: into the chat as well
    drops.dropped(const Offset(200, 400), [DroppedFile.bytes('site.kml', text('<kml/>'))]);
    await settle(tester);
    expect(names(), ['shot.png', 'valves.csv', 'site.kml']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the panel closed a drop only says where files go, and the closed panel takes nothing', (tester) async {
    await pumpPanel(tester);
    final where = tester.getRect(find.byKey(const Key('ai_panel'))).center;
    AiAssistant.panelOpen.value = false;
    await tester.pump();
    expect(find.byKey(const Key('ai_panel')), findsNothing);
    drops.dragAt(where);
    await tester.pump();
    expect(overlay, findsNothing);
    drops.dropped(where, [DroppedFile.bytes('shot.png', png(), type: 'image/png')]);
    await settle(tester);
    expect(ai().attachments, isEmpty);
    expect(c.lastMessage, c.t('ai.attach.noPanel'));
    expect(drops.takesPaste, isFalse, reason: 'no chat box on screen');
  });

  testWidgets('the panel takes files for the tab it shows (notices on the tab on screen); a tab switched away holds nothing', (tester) async {
    c.tabId = 1;
    final other = await newTab();
    other.tabId = 2;
    final shown = ValueNotifier(c);
    await pumpPanel(tester, shown: shown);
    final panel = tester.getRect(find.byKey(const Key('ai_panel')));
    // the panel stays on the other tab's assistant (it works there, say)
    shown.value = other;
    await tester.pump();
    final seq = other.messageSeq;
    drops.dropped(panel.center, [DroppedFile.bytes('notes.txt', text('PN 80')), DroppedFile.bytes('memo.docx', text('x'))]);
    await settle(tester);
    expect(names(other), ['notes.txt']);
    expect(names(), isEmpty);
    expect(c.lastMessage, 'memo.docx: ${c.t('ai.attach.bad')}', reason: 'the notice shows on the tab on screen');
    expect(other.messageSeq, seq);
    // and back: the first tab's panel, a new one
    shown.value = c;
    await tester.pump();
    drops.dropped(panel.center, [DroppedFile.bytes('more.txt', text('PE 16'))]);
    await settle(tester);
    expect(names(), ['more.txt']);
    expect(names(other), ['notes.txt']);
  });

  testWidgets('pictures and files pasted into the chat box are attached, named after their type when they come without a name; elsewhere pastes are left alone', (tester) async {
    await pumpPanel(tester);
    expect(drops.takesPaste, isFalse, reason: 'the box does not have the cursor');
    await tester.tap(find.byKey(const Key('ai_input')));
    await tester.pump();
    expect(drops.takesPaste, isTrue);
    drops.pasted([
      DroppedFile.bytes('image.png', png(), type: 'image/png'), // a screenshot: the browser's generic name
      DroppedFile.bytes('', jpg(), type: 'image/jpeg'), // a picture without a name
      DroppedFile.bytes('quote.pdf', text('%PDF-1.4'), type: 'application/pdf'), // copied in the file manager
    ]);
    await settle(tester);
    final n = names();
    expect(n, hasLength(3));
    final a = RegExp(r'^pasted-(\d+)\.png$').firstMatch(n[0]), b = RegExp(r'^pasted-(\d+)\.jpg$').firstMatch(n[1]);
    expect(a, isNotNull, reason: '$n');
    expect(b, isNotNull, reason: '$n');
    expect(int.parse(b!.group(1)!), int.parse(a!.group(1)!) + 1, reason: 'one number each');
    expect(n[2], 'quote.pdf');
    expect(ai().attachments.take(2).every((x) => x.isImage), isTrue);
    expect(find.byKey(const Key('ai_input')), findsOneWidget);
    expect(inputFocused(tester), isTrue, reason: 'the cursor stays in the box');

    // the box without the cursor: pastes are not taken
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(drops.takesPaste, isFalse);
  });

  test('which pastes are pastes of files, and the names of pasted pictures', () {
    expect(pasteIsFiles(['image/png']), isTrue, reason: 'a screenshot');
    expect(pasteIsFiles(['application/pdf'], text: 'quote.pdf'), isTrue, reason: 'a file copied in the file manager comes with its name');
    expect(pasteIsFiles(['image/png'], text: 'https://example.com/plan.png', richText: true), isTrue, reason: 'a picture copied from a web page, with its address');
    expect(pasteIsFiles(['image/png'], text: 'Zone\tFlow\n1\t2.5', richText: true), isFalse, reason: 'cells copied from a spreadsheet, with a picture of them');
    expect(pasteIsFiles(['image/png'], text: '42', richText: true), isFalse, reason: 'one cell');
    expect(pasteIsFiles(['application/pdf'], text: 'Spec', richText: true), isTrue, reason: 'a document is not a picture of the text');
    expect(pasteIsFiles([], text: 'PVC 50 mm'), isFalse, reason: 'text is pasted as text');

    var n = 0;
    int next() => ++n;
    expect(pastedName('image.png', 'image/png', next), 'pasted-1.png');
    expect(pastedName('', 'image/jpeg', next), 'pasted-2.jpg');
    expect(pastedName('  ', 'image/webp', next), 'pasted-3.webp');
    expect(pastedName('site plan.png', 'image/png', next), 'site plan.png');
    expect(pastedName('Pasted Graphic', 'image/png', next), 'Pasted Graphic.png');
    expect(pastedName('report.pdf', 'application/pdf', next), 'report.pdf');
    expect(pastedName('image.png', '', next), 'image.png', reason: 'not a picture from the clipboard');
    expect(pastedName('', '', next), 'pasted-4');
    expect(n, 4, reason: 'a number only for the files renamed');
    final f = DroppedFile.bytes('a.txt', text('x'));
    expect(identical(f.renamed('a.txt'), f), isTrue);
    expect(f.renamed('b.txt').name, 'b.txt');
  });
}
