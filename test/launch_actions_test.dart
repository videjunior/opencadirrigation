import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/launch_files.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/launch_actions.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// What the installed app does with the files the system hands it (lib/app/launch_actions.dart): a project opens in
/// the blank tab or a tab of its own, an OpenCADIrrigation link in a shared text opens its project, a share that
/// could not be kept says so. The browser side (launch queue, share target) is in test/js.
void main() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  String projectJson(String name) {
    final p = Project()..meta.name = name;
    p.entities.add(LineEntity(id: p.newId(), a: Pt.zero, b: const Pt(10, 0)));
    return jsonEncode(p.toJson());
  }

  test('how a launched file opens: by its extension, a JSON file by its format', () {
    expect(launchKindOf('farm.oci.json', Uint8List(0)), LaunchKind.project);
    expect(launchKindOf('old.ICAD', Uint8List(0)), LaunchKind.project);
    expect(launchKindOf('plan.PDF', Uint8List(0)), LaunchKind.pdf);
    expect(launchKindOf('site.dxf', Uint8List(0)), LaunchKind.import);
    expect(launchKindOf('photo.jpg', Uint8List(0)), LaunchKind.import);
    expect(launchKindOf('copy.json', bytes('{"format":"opencadirrigation","version":2}')), LaunchKind.project);
    expect(launchKindOf('older.json', bytes('{"format":"irrigationcad"}')), LaunchKind.project);
    expect(launchKindOf('fields.json', bytes('{"type":"FeatureCollection","features":[]}')), LaunchKind.import, reason: 'GeoJSON is imported');
    expect(launchKindOf('broken.json', bytes('{not json')), LaunchKind.import, reason: 'refused by the import, with its reason');
  });

  testWidgets('projects open in the blank tab, then in tabs of their own; a link in a shared text opens its project', (tester) async {
    LocalProjectStore().clearAll();
    final ws = Workspace(systemClipboard: false);
    ws.current.autosaveEnabled = false;
    await ws.current.setLanguage('en', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    final context = tester.element(find.byType(SizedBox).last);

    await handleLaunch(context, ws, LaunchRequest(files: [LaunchFile('north.oci.json', bytes(projectJson('North field')))]));
    expect(ws.tabs, hasLength(1), reason: 'the blank tab of a fresh start is used');
    expect(ws.current.project.meta.name, 'North field');

    await handleLaunch(context, ws, LaunchRequest(files: [LaunchFile('south.json', bytes(projectJson('South field')))], shared: true));
    expect(ws.tabs, hasLength(2));
    expect(ws.current.project.meta.name, 'South field');

    final link = shareLinkFor(shareableProjectJson(jsonDecode(projectJson('Shared orchard')) as Map<String, dynamic>));
    await handleLaunch(context, ws, LaunchRequest(text: 'Have a look: $link', shared: true));
    expect(ws.tabs, hasLength(3));
    expect(ws.current.project.meta.name, 'Shared orchard');

    for (final t in ws.tabs) {
      t.autosaveEnabled = false;
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a share that could not be kept, or that brings nothing, is told', (tester) async {
    final ws = Workspace(systemClipboard: false);
    ws.current.autosaveEnabled = false;
    await ws.current.setLanguage('en', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    final context = tester.element(find.byType(SizedBox).last);
    await handleLaunch(context, ws, const LaunchRequest(shared: true, failed: true));
    expect(ws.current.lastMessage, ws.current.t('launch.shareFailed'));
    await handleLaunch(context, ws, const LaunchRequest(shared: true, text: 'just words'));
    expect(ws.current.lastMessage, ws.current.t('launch.nothing'));
    expect(ws.tabs, hasLength(1), reason: 'nothing opened');
    await tester.pumpWidget(const SizedBox());
  });
}
