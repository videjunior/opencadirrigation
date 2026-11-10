import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/io/share_inbox.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/main.dart';

/// Share links (`#p=…`) reach the app through the inbox that `main()` fills first thing (the web engine rewrites the
/// address without the fragment while it starts, before the first frame: the link the start-up read from the
/// address later was always gone, 1.6.1). The page script's side is test/js/site_share_link.test.js.
void main() {
  String fragmentOf(String link) => link.substring(link.indexOf('#'));
  Map<String, dynamic> garden([String? name]) {
    final j = jsonDecode(File('examples/en/garden.oci.json').readAsStringSync()) as Map<String, dynamic>;
    if (name != null) j['meta'] = {...(j['meta'] as Map).cast<String, dynamic>(), 'name': name};
    return j;
  }

  group('the fragment of a share link', () {
    test('is p= and its data, with or without its #', () {
      expect(isShareFragment('#p=H4sI'), isTrue);
      expect(isShareFragment('p=H4sI'), isTrue);
      expect(isShareFragment('#p='), isFalse, reason: 'no project');
      expect(isShareFragment(''), isFalse);
      expect(isShareFragment('#install'), isFalse);
      expect(isShareFragment('#/p=H4sI'), isFalse, reason: 'a route of the engine is no link');
    });
  });

  group('the inbox', () {
    test('keeps the link that opened the page for the start-up, once', () {
      final inbox = ShareInbox()..receive('#p=first');
      expect(inbox.takeStart(), '#p=first');
      expect(inbox.takeStart(), isNull, reason: 'taken once: a second shell does not open it again');
    });

    test('a page opened without a link: the start-up finds none, and the first link pasted later is a later link', () {
      final inbox = ShareInbox();
      expect(inbox.takeStart(), isNull);
      final got = <String>[];
      inbox
        ..receive('#p=pasted')
        ..listen(got.add);
      expect(got, ['#p=pasted']);
    });

    test('later links wait for the shell, in their order, and then come as they arrive', () {
      final inbox = ShareInbox()
        ..receive('#p=start')
        ..receive('#p=second')
        ..receive('p=third');
      expect(inbox.takeStart(), '#p=start');
      final got = <String>[];
      inbox.listen(got.add);
      expect(got, ['#p=second', '#p=third'], reason: 'the fragment always with its #');
      inbox.receive('#p=fourth');
      expect(got, ['#p=second', '#p=third', '#p=fourth']);
    });

    test('ignores what is not a link, and a shell that went away stops getting them', () {
      final inbox = ShareInbox();
      void onLink(String l) => fail('no listener: $l');
      final got = <String>[];
      inbox
        ..receive('#install')
        ..receive('')
        ..receive('#p=');
      expect(inbox.takeStart(), isNull);
      inbox
        ..listen(onLink)
        ..stopListening(onLink)
        ..receive('#p=after')
        ..stopListening(got.add) // another shell's listener is not this one: nothing changes
        ..listen(got.add);
      expect(got, ['#p=after'], reason: 'kept while no shell listened');
      inbox.stopListening();
      inbox.receive('#p=later');
      expect(got, ['#p=after']);
    });

    test('nothing to take on the desktop builds (no address): the capture changes nothing', () {
      final inbox = ShareInbox();
      captureShareLinks(inbox);
      expect(inbox.takeStart(), isNull);
    });
  });

  group('the app', () {
    Future<void> settle(WidgetTester tester, [int n = 4]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('opens the project of the link that opened the page, then those pasted later, each in a tab of its own', (tester) async {
      TutorialController.markDone();
      setPref('lang', 'en');
      LocalProjectStore().clearAll();
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = garden();
      final link = shareLinkFor(shareableProjectJson(first));
      // as main() takes it from the page script, before the app starts
      shareInbox.receive(fragmentOf(link));
      await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
      await settle(tester);
      final shell = tester.state(find.byType(AppShell)) as dynamic;
      final ws = shell.ws as Workspace;
      ProjectController c = ws.current;
      c.autosaveEnabled = false;
      expect(ws.tabs, hasLength(1), reason: 'the blank tab of the start is used');
      expect(c.project.meta.name, 'Residential garden');
      expect(c.project.entities, hasLength((first['entities'] as List).length));
      expect(c.project.meta.uid, isNot((first['meta'] as Map)['uid']), reason: 'a copy, with a uid of its own');

      // a second link pasted into the address bar of the open app
      shareInbox.receive(fragmentOf(shareLinkFor(shareableProjectJson(garden('Second shared garden')))));
      await settle(tester, 2);
      expect(ws.tabs, hasLength(2));
      c = ws.current;
      c.autosaveEnabled = false;
      expect(c.project.meta.name, 'Second shared garden');

      // a damaged one is told, and opens nothing
      shareInbox.receive('#p=H4sIAAAAdamaged');
      await settle(tester, 2);
      expect(ws.tabs, hasLength(2));
      expect(ws.current.lastMessage, ws.current.t('share.damaged'));
      for (final t in ws.tabs) {
        t.autosaveEnabled = false;
      }
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 1);
      // the shell that went away no longer gets links: they wait for the next one
      shareInbox.receive('#p=waiting');
      final got = <String>[];
      shareInbox.listen(got.add);
      expect(got, ['#p=waiting']);
      shareInbox.stopListening();
    });
  });
}
