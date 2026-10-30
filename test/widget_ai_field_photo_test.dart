import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/widgets/properties_panel.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/image_prep.dart';
import 'package:opencadirrigation/core/ai/project_context.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

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
  bool openTab(Project p) => true;
}

/// A JPEG photo of [w] × [h] with the GPS tags a phone writes: latitude and
/// longitude as degrees, minutes and seconds, the direction and the time.
Uint8List _photo(double lat, double lon, {int w = 1200, int h = 900, bool gps = true}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(120, 90, 60));
  if (gps) {
    // the latitude as one rational in degrees, the longitude as degrees,
    // minutes and seconds (phones write three rationals)
    img.IfdValue dms(double v) {
      final a = v.abs(), d = a.floor().toDouble(), m = ((a - d) * 60).floor().toDouble(), s = ((a - d) * 60 - m) * 60;
      return img.IfdValueDouble.list([d, m, s]);
    }

    final g = im.exif.gpsIfd;
    g[0x0001] = img.IfdValueAscii(lat < 0 ? 'S' : 'N');
    g[0x0002] = img.IfdValueRational((lat.abs() * 1e6).round(), 1000000);
    g[0x0003] = img.IfdValueAscii(lon < 0 ? 'W' : 'E');
    g[0x0004] = dms(lon);
    g[0x0011] = img.IfdValueRational(2305, 10);
    im.exif.exifIfd[0x9003] = img.IfdValueAscii('2026:10:29 14:02:07');
  }
  return img.encodeJpg(im, quality: 80);
}

/// Field photos placed by their GPS, pinned to the drawing as comments with
/// a copy of the photo; the review command runs read-only; the user's marks
/// go with the next message; the picture after the changes is on by default.
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

  test('the GPS of a phone photo: degrees, minutes and seconds, south and west, direction and time', () {
    final p = photoPlace(_photo(-22.512345, -47.498765))!;
    expect(p.lat, closeTo(-22.512345, 1e-6));
    expect(p.lon, closeTo(-47.498765, 1e-6));
    expect(p.direction, closeTo(230.5, 1e-9));
    expect(p.taken, DateTime(2026, 10, 29, 14, 2, 7));
    expect(photoPlace(_photo(0, 0, gps: false)), isNull);
    expect(photoPlace(img.encodePng(img.Image(width: 4, height: 4))), isNull, reason: 'PNG has no EXIF GPS');
    final thumb = photoThumbnail(_photo(-22.5, -47.5))!;
    final t = img.decodeJpg(thumb)!;
    expect(t.width, 480);
    expect(t.height, 360);
  });

  testWidgets('an attached photo says where it was taken; add_photo_comment pins it there with the photo', (tester) async {
    final g = GeoReference.fromLatLonOrigin(-22.5, -47.5);
    c.project.meta.georef = g;
    c.addEntity(ControlValveEntity(id: 'v1', position: const Pt(20, -50), zoneName: 'North'));
    final bytes = _photo(-22.5005, -47.4998);
    final (ex, ey) = g.fromLatLon(-22.5005, -47.4998);
    final ai = AiAssistant.of(c);
    final a = AiAttachment('IMG_0042.jpg', 'image/jpeg', bytes);
    ai.addAttachment(a);
    expect(a.place, contains('Taken at [${ex.toStringAsFixed(2)}, ${ey.toStringAsFixed(2)}] m'));
    expect(a.place, contains('facing 231° from north'));
    expect(a.place, contains('the nearest item is v1 (controlValve)'));
    expect(a.place, contains('add_photo_comment'));
    expect(a.parts().whereType<AiTextPart>().map((x) => x.text).join(), contains('<photo_place name="IMG_0042.jpg">'));
    // the tool pins it at the GPS position, the photo kept small
    final host = _Host()..files['IMG_0042.jpg'] = bytes;
    final box = AgentToolbox(c, host: host);
    final tool = box.tools.firstWhere((t) => t.name == 'add_photo_comment');
    expect(tool.effect, ToolEffect.write);
    late ToolOutput out;
    await tester.runAsync(() async => out = await tool.run({'name': 'IMG_0042.jpg', 'text': 'Pump nameplate: 7.5 kW, 30 m³/h at 45 m'}));
    expect(out.text, contains('Pinned comment'));
    final cm = c.project.entities.whereType<CommentEntity>().single;
    expect(cm.position.x, closeTo(ex, 1e-6));
    expect(cm.position.y, closeTo(ey, 1e-6));
    expect(cm.text, 'Pump nameplate: 7.5 kW, 30 m³/h at 45 m');
    expect(cm.author, 'AI');
    expect(img.decodeJpg(base64Decode(cm.photo))!.width, 480);
    // kept in the project file and back
    final back = Entity.fromJson(jsonDecode(jsonEncode(cm.toJson())) as Map<String, dynamic>) as CommentEntity;
    expect(back.photo, cm.photo);
    // the model reads its size, not the base64; a share link leaves it out,
    // like embedded images; the note written back would lose the photo
    final head = cm.photo.substring(0, 64);
    final read = await box.tools.firstWhere((t) => t.name == 'get_entity').run({'id': cm.id});
    expect(read.text, isNot(contains(head)));
    expect(read.text, contains('a JPEG photo of'));
    final shared = shareableProjectJson(c.project.toJson());
    expect(shared, isNot(contains(head)));
    expect(shared, contains('Pump nameplate'));
    final update = box.tools.firstWhere((t) => t.name == 'update_entities');
    await expectLater(
      () => update.run({
        'updates': [
          {
            'id': cm.id,
            'set': {'photo': photoNote(cm.photo)},
          },
        ],
      }),
      throwsA(isA<ToolInputError>()),
    );
    expect(c.project.entities.whereType<CommentEntity>().single.photo, cm.photo);
    // a photo without GPS needs `at`; without a georeference the GPS cannot be placed
    host.files['plain.jpg'] = _photo(0, 0, gps: false);
    await expectLater(() => tool.run({'name': 'plain.jpg', 'text': 'x'}), throwsA(isA<ToolInputError>()));
    await tester.runAsync(
      () async => out = await tool.run({
        'name': 'plain.jpg',
        'text': 'Valve box',
        'at': [5, 6],
      }),
    );
    expect(c.project.entities.whereType<CommentEntity>().last.position, const Pt(5, 6));
    await expectLater(() => tool.run({'name': 'missing.jpg', 'text': 'x'}), throwsA(isA<ToolInputError>()));
    c.project.meta.georef = null;
    final none = AiAttachment('IMG_0043.jpg', 'image/jpeg', bytes);
    ai.addAttachment(none);
    expect(none.place, contains('The project has no georeference'));
  });

  testWidgets('the properties of a comment show its photo and remove it in one undo step', (tester) async {
    final thumb = photoThumbnail(_photo(-22.5, -47.5, w: 200, h: 150))!;
    final cm = CommentEntity(id: 'cm1', position: Pt.zero, text: 'Well', photo: base64Encode(thumb));
    c.addEntity(cm);
    c.select(['cm1']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, height: 600, child: PropertiesPanel(c: c)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('comment_photo')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final before = c.historyIndex;
    await tester.tap(find.byKey(const Key('comment_photo_remove')));
    await tester.pump();
    expect(cm.photo, isEmpty);
    expect(c.historyIndex, before + 1);
  });

  testWidgets('/review runs the task read-only; the picture after changes is on by default; marks go with the next message once', (tester) async {
    final ai = AiAssistant.of(c);
    expect(ai.showChanges, isTrue, reason: 'on by default');
    expect(aiCommands.map((x) => x.name), contains('review'));
    expect(c.t('ai.cmd.review.prompt', {'x': ''}), contains('without changing anything'));
    // the user's marks: in the message while they are new or changed
    const ctx = ProjectContext.empty;
    expect(ai.composeText('hi', ctx), isNot(contains('<user_marks>')));
    c.aiMarks.add(const [Pt(10, 20)], note: 'pump');
    c.aiMarks.add(const [Pt(0, 0), Pt(30, 40)]);
    final text = ai.composeText('put the pump at A', ctx);
    expect(text, contains('<user_marks>'));
    expect(text, contains('A: point [10.00, 20.00] — "pump"'));
    expect(text, contains('B: line [[0.00, 0.00], [30.00, 40.00]], 50.0 m long'));
  });
}
