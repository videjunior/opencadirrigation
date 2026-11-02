/// The drawing tools of 1.6.0 (CAD+): Lengthen (a click near the end of an
/// item lengthens or shortens it as the panel says), the outline by a
/// click inside a region closed by lines, and the field photo pinned where
/// it was taken (a click places the photo that carried no position).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../../core/ai/image_prep.dart' show photoPlace, photoThumbnail;
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/lengthen.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'cad_plus_commands.dart';
import 'tools.dart';
import 'typed_point.dart';

/// Lengthen: a click on an item, near the end to change.
class LengthenTool extends Tool {
  LengthenTool(super.c, super.host);
  @override
  ToolId get id => ToolId.lengthen;
  @override
  String get hintKey => 'hint.lengthen';

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit == null) return;
    c.lengthenAt(hit.id, p);
  }

  /// A number typed sets the value of the current mode (metres, or a
  /// percentage).
  @override
  bool onInput(String text) {
    final v = parseTypedValue(text);
    if (v == null) return false;
    final s = c.cadPlus;
    s.lengthenValue = s.lengthenMode == LengthenMode.percent ? v : c.units.lengthToSi(v);
    c.notify(c.t('cadp.lengthenSet', {'v': lengthenValueText(c)}));
    return true;
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final p = cursor;
    if (p == null) return;
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    final length = hit == null ? null : lengthOfLengthenable(hit);
    if (hit == null || length == null) {
      host.setStatus(lengthenValueText(c));
      return;
    }
    final made = lengthenEntity(hit, p, c.cadPlus.lengthenMode, c.cadPlus.lengthenValue);
    final pts = made?.linearPoints;
    if (pts != null && pts.length >= 2) drawPolyline(canvas, cam, pts, previewPaint);
    host.setStatus('${fmtLen(length)} → ${made == null ? '—' : fmtLen(lengthOfLengthenable(made) ?? 0)}   (${lengthenValueText(c)})');
  }
}

/// The value of Lengthen in words for the status bar (`+2.00 m`, `= 25.00
/// m`, `50 %`).
String lengthenValueText(ProjectController c) {
  final s = c.cadPlus;
  final u = c.units;
  return switch (s.lengthenMode) {
    LengthenMode.delta => '${s.lengthenValue >= 0 ? '+' : ''}${u.lengthFromSi(s.lengthenValue).toStringAsFixed(2)} ${u.lengthLabel}',
    LengthenMode.total => '= ${u.lengthFromSi(s.lengthenValue).toStringAsFixed(2)} ${u.lengthLabel}',
    LengthenMode.percent => '${s.lengthenValue.toStringAsFixed(1)} %',
  };
}

/// The outline by a click inside: the region the lines close around the
/// click becomes a closed polyline (or an area); the outline found is
/// shown under the cursor before the click.
class BoundaryTool extends Tool {
  BoundaryTool(super.c, super.host);
  @override
  ToolId get id => ToolId.boundary;
  @override
  String get hintKey => 'hint.boundary';
  @override
  bool get usesSnap => false;

  Pt? _probe;
  List<Pt>? _ring;

  /// Above this many items the outline is only looked for at the click.
  static const maxPreviewItems = 4000;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    c.boundaryAt(p);
    _probe = null;
    _ring = null;
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final p = cursor;
    if (p == null) return;
    // a large drawing shows no outline before the click (looking for it
    // under a moving cursor would hold the screen)
    if (c.project.entities.length > maxPreviewItems) {
      host.setStatus(c.t('hint.boundary'));
      return;
    }
    // the outline is looked for again only when the cursor moved a few pixels
    if (_probe == null || _probe!.distanceTo(p) * cam.scale > 6) {
      _probe = p;
      _ring = c.boundaryOutline(p);
    }
    final ring = _ring;
    if (ring == null) {
      host.setStatus(c.t('cadp.boundaryNone'));
      return;
    }
    final fill = Paint()..color = Cad.selection.withValues(alpha: 0.12);
    final path = Path()..addPolygon([for (final q in ring) cam.toScreen(q)], true);
    canvas.drawPath(path, fill);
    drawPolyline(canvas, cam, ring, previewPaint, close: true);
    host.setStatus(c.t('cadp.boundaryFound', {'a': c.fmtArea(polygonArea(ring).abs())}));
  }
}

/// 1.6.0 CAD: a field photo waiting for its place (it carried no GPS
/// position): the thumbnail, the file name and the text of the comment.
class PendingFieldPhoto {
  const PendingFieldPhoto(this.thumbnail, this.name);
  final Uint8List thumbnail;
  final String name;
}

/// The field photo the tool of each controller places.
final pendingFieldPhotos = Expando<PendingFieldPhoto>('pendingFieldPhoto');

extension FieldPhotoCommands on ProjectController {
  /// Pins the photo [bytes] (named [name]) to the drawing as a review
  /// comment with a small copy of it (PRD-08, no AI needed): at the place
  /// its GPS gives (with a georeference), else at the device's GPS fix,
  /// else [at]; with none of them the field photo tool waits for a click.
  /// Returns the comment, or null (not a picture, refused, or waiting for
  /// the click), telling the user why.
  CommentEntity? addFieldPhoto(Uint8List bytes, String name, {Pt? at, String text = ''}) {
    track('fieldPhoto');
    final thumb = photoThumbnail(bytes);
    if (thumb == null) {
      notify(t('photo.notPicture', {'n': name}));
      return null;
    }
    var where = at;
    final g = project.meta.georef;
    if (where == null && g != null) {
      final place = photoPlace(bytes);
      if (place != null) {
        final (x, y) = g.fromLatLon(place.lat, place.lon);
        where = Pt(x, y);
      } else if (gpsPoint != null) {
        where = gpsPoint;
      }
    }
    if (where == null) {
      // the place is clicked
      pendingFieldPhotos[this] = PendingFieldPhoto(thumb, name);
      setTool(ToolId.fieldPhoto);
      notify(t(g == null ? 'photo.clickNoGeoref' : 'photo.clickNoGps'));
      return null;
    }
    return placeFieldPhoto(thumb, name, where, text: text);
  }

  /// The comment of the photo [thumb] at [at]. One undo step.
  CommentEntity? placeFieldPhoto(Uint8List thumb, String name, Pt at, {String text = ''}) {
    final now = DateTime.now();
    final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cm = mutate(
      () {
        final e = CommentEntity(id: project.newId(), position: at, text: text.isEmpty ? name : text, author: toolSettings.commentAuthor, date: day, photo: base64Encode(thumb));
        project.entities.add(e);
        return e;
      },
      invalidateResults: false,
      label: 'hist.fieldPhoto',
    );
    if (cm == null) return null;
    select([cm.id]);
    notify(t('photo.pinned', {'n': name}));
    return cm;
  }

  /// Puts the photo [bytes] on the comment [id] (or replaces it); with
  /// [move] the comment goes to the place the photo's GPS gives. One undo
  /// step; false, telling why, when it cannot.
  bool setCommentPhoto(String id, Uint8List bytes, String name, {bool move = false}) {
    final cm = project.byId(id);
    if (cm is! CommentEntity || project.isLocked(cm.layer)) return false;
    final thumb = photoThumbnail(bytes);
    if (thumb == null) {
      notify(t('photo.notPicture', {'n': name}));
      return false;
    }
    Pt? to;
    if (move) {
      final g = project.meta.georef;
      final place = photoPlace(bytes);
      if (g != null && place != null) {
        final (x, y) = g.fromLatLon(place.lat, place.lon);
        to = Pt(x, y);
      }
    }
    final done = mutate(
      () {
        cm.photo = base64Encode(thumb);
        if (to != null) cm.position = to;
        return true;
      },
      invalidateResults: false,
      label: 'hist.fieldPhoto',
    );
    if (done != true) return false;
    notify(t(to != null ? 'photo.setMoved' : 'photo.set', {'n': name}));
    return true;
  }
}

/// Places the pending field photo ([pendingFieldPhotos]) at the click;
/// then the selection tool comes back.
class FieldPhotoTool extends Tool {
  FieldPhotoTool(super.c, super.host);
  @override
  ToolId get id => ToolId.fieldPhoto;
  @override
  String get hintKey => 'hint.fieldPhoto';

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final ph = pendingFieldPhotos[c];
    if (ph == null) {
      c.setTool(ToolId.select);
      return;
    }
    pendingFieldPhotos[c] = null;
    c.placeFieldPhoto(ph.thumbnail, ph.name, p);
    c.setTool(ToolId.select);
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final p = cursor;
    if (p == null) return;
    final o = cam.toScreen(p);
    final paint = previewPaint;
    canvas.drawRect(Rect.fromCenter(center: o + const Offset(0, -12), width: 18, height: 13), paint);
    canvas.drawCircle(o + const Offset(0, -12), 3.5, paint);
    canvas.drawLine(o + const Offset(0, -5.5), o, paint);
    host.setStatus(pendingFieldPhotos[c]?.name ?? '');
  }
}
