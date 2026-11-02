/// The professional title block of the drawing sheets and the cover of the
/// document packages: who the project is for, who answers for it and the
/// records the authorities ask for (File → Title block). Stored in the
/// project details (`meta.titleBlock`), written only when something is set,
/// so a project without it keeps its file as it was.
///
/// In Brazil every signed sheet carries the technical lead, the number in
/// the professional council (CREA for engineers and agronomists, CAU for
/// architects, CFTA for agricultural technicians, CFT for industrial
/// technicians) and the record of the technical responsibility the council
/// names: ART at CREA, RRT at CAU, TRT at CFTA and CFT. Water permits and
/// rural credit also ask for the CAR (Cadastro Ambiental Rural) and the
/// permit (outorga) number. Elsewhere the same fields hold the registration
/// in the local professional body.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'read_report.dart';

/// Stage of the design the sheets and documents are issued for.
enum ProjectStage { none, study, preliminary, basic, executive, asBuilt }

/// Professional councils offered in the title block (any other may be typed).
const professionalCouncils = ['CREA', 'CAU', 'CFTA', 'CFT'];

/// The record of technical responsibility of [council]: ART (CREA), RRT
/// (CAU), TRT (CFTA, CFT); empty for any other council.
String responsibilityRecordOf(String council) {
  final c = council.trim().toUpperCase();
  if (c.startsWith('CREA')) return 'ART';
  if (c.startsWith('CAU')) return 'RRT';
  if (c.startsWith('CFTA') || c.startsWith('CRTA') || c.startsWith('CFT') || c.startsWith('CRT')) return 'TRT';
  return '';
}

/// A line of the revision table of the sheets: revision, date, what
/// changed and who made it (the revision clouds of the drawing add theirs).
class TitleRevision {
  TitleRevision({this.revision = '', this.date = '', this.description = '', this.author = ''});
  String revision;

  /// As typed (the sheets print it as it is).
  String date;
  String description;
  String author;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isEmpty => revision.trim().isEmpty && date.trim().isEmpty && description.trim().isEmpty && author.trim().isEmpty;

  TitleRevision copy() => TitleRevision(revision: revision, date: date, description: description, author: author)..extra = extra;

  Map<String, dynamic> toJson() => {...?extra, 'rev': revision, 'date': date, 'desc': description, if (author.isNotEmpty) 'by': author};

  static TitleRevision fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    String s(String k) => j[k] is String ? j[k] as String : '';
    return TitleRevision(revision: s('rev'), date: s('date'), description: s('desc'), author: s('by'))..extra = j.unread;
  }
}

class TitleBlock {
  TitleBlock({
    this.company = '',
    this.responsible = '',
    this.council = '',
    this.registration = '',
    this.responsibilityRecord = '',
    this.car = '',
    this.waterPermit = '',
    this.municipality = '',
    this.stage = ProjectStage.none,
    this.drawingNumber = '',
    this.issueDate = '',
    List<TitleRevision>? revisions,
    Uint8List? logo,
    this.logoMime = '',
  }) : revisions = revisions ?? [],
       _logo = logo == null || logo.isEmpty ? null : logo;

  /// Company or office that issues the project (beside its logo).
  String company;

  /// The technical lead who signs the project.
  String responsible;

  /// Professional council of [responsible] (CREA, CAU, CFTA, CFT or another).
  String council;

  /// Registration number in [council] (with the state: "SP 5060123456").
  String registration;

  /// Number of the record of technical responsibility (ART, RRT or TRT; see
  /// [responsibilityRecordOf]).
  String responsibilityRecord;

  /// Cadastro Ambiental Rural of the property.
  String car;

  /// Water permit (outorga) of the abstraction.
  String waterPermit;

  /// Municipality and state ("Uberaba/MG").
  String municipality;
  ProjectStage stage;

  /// Code of the drawing set ("IRR-2026-014"): sheet n of a set prints as
  /// "IRR-2026-014-0n".
  String drawingNumber;

  /// Date of issue (YYYY-MM-DD); empty = the day the sheets are made.
  String issueDate;

  /// The revision table, oldest first.
  final List<TitleRevision> revisions;

  Uint8List? _logo;
  String? _logoText;

  /// Media type of [logo] (image/png or image/jpeg).
  String logoMime;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  /// The logo printed in the title block and on the cover (PNG or JPEG), or null.
  Uint8List? get logo => _logo;
  set logo(Uint8List? bytes) {
    _logo = bytes == null || bytes.isEmpty ? null : bytes;
    _logoText = null;
    if (_logo == null) logoMime = '';
  }

  /// The logo as Base64, made once: every undo step and save shares the
  /// same text instead of a new copy of the picture.
  String? get _logoBase64 => _logo == null ? null : (_logoText ??= base64Encode(_logo!));

  /// The record named after the council ("ART"), or "ART/RRT/TRT" when the
  /// council is not one of [professionalCouncils].
  String get recordName {
    final r = responsibilityRecordOf(council);
    return r.isEmpty ? 'ART/RRT/TRT' : r;
  }

  /// "CREA SP 5060123456": the council and the registration, as printed.
  String get registrationText => [council.trim(), registration.trim()].where((s) => s.isNotEmpty).join(' ');

  /// The date of issue, or null when it is not set or not a date.
  DateTime? get issued => parseTitleDate(issueDate);

  /// Nothing set: the project file leaves the title block out.
  bool get isDefault => !isProfessional && revisions.isEmpty && extra == null;

  /// Something of the professional title block is set: the sheets print it
  /// instead of the plain one.
  bool get isProfessional =>
      _logo != null ||
      [company, responsible, council, registration, responsibilityRecord, car, waterPermit, municipality, drawingNumber, issueDate].any((s) => s.trim().isNotEmpty) ||
      stage != ProjectStage.none;

  /// The latest revision (the last of the table), or empty.
  String get currentRevision {
    for (final r in revisions.reversed) {
      if (r.revision.trim().isNotEmpty) return r.revision.trim();
    }
    return '';
  }

  TitleBlock copy() => TitleBlock(
    company: company,
    responsible: responsible,
    council: council,
    registration: registration,
    responsibilityRecord: responsibilityRecord,
    car: car,
    waterPermit: waterPermit,
    municipality: municipality,
    stage: stage,
    drawingNumber: drawingNumber,
    issueDate: issueDate,
    revisions: [for (final r in revisions) r.copy()],
    logo: _logo,
    logoMime: logoMime,
  ).._logoText = _logoText;

  /// The parts that belong to the professional, not to one project (company,
  /// logo, technical lead, council and registration): what "Use in new
  /// projects" keeps.
  TitleBlock ownerPart() => TitleBlock(company: company, responsible: responsible, council: council, registration: registration, logo: _logo, logoMime: logoMime).._logoText = _logoText;

  /// Fills the empty owner fields of this title block from [owner].
  void adoptOwner(TitleBlock owner) {
    if (company.trim().isEmpty) company = owner.company;
    if (responsible.trim().isEmpty) responsible = owner.responsible;
    if (council.trim().isEmpty) council = owner.council;
    if (registration.trim().isEmpty) registration = owner.registration;
    if (_logo == null && owner._logo != null) {
      _logo = owner._logo;
      _logoText = owner._logoText;
      logoMime = owner.logoMime;
    }
  }

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (company.isNotEmpty) 'company': company,
    if (responsible.isNotEmpty) 'responsible': responsible,
    if (council.isNotEmpty) 'council': council,
    if (registration.isNotEmpty) 'registration': registration,
    if (responsibilityRecord.isNotEmpty) 'record': responsibilityRecord,
    if (car.isNotEmpty) 'car': car,
    if (waterPermit.isNotEmpty) 'permit': waterPermit,
    if (municipality.isNotEmpty) 'municipality': municipality,
    if (stage != ProjectStage.none) 'stage': stage.name,
    if (drawingNumber.isNotEmpty) 'drawingNo': drawingNumber,
    if (issueDate.isNotEmpty) 'issued': issueDate,
    if (revisions.isNotEmpty) 'revisions': [for (final r in revisions) r.toJson()],
    if (_logo != null) 'logo': _logoBase64,
    if (_logo != null) 'logoMime': logoMime,
  };

  /// Reads the title block; fields this version does not know are kept,
  /// a logo that is not Base64 is dropped (noted in [report]).
  static TitleBlock fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    String s(String k) => j[k] is String ? j[k] as String : '';
    Uint8List? logo;
    String? logoText;
    final raw = j['logo'];
    if (raw is String && raw.isNotEmpty) {
      try {
        logo = base64Decode(raw);
        logoText = raw;
      } on FormatException {
        report?.skip('titleBlock.logo');
      }
    }
    final revisions = <TitleRevision>[
      for (final r in (j['revisions'] is List ? j['revisions'] as List : const []))
        if (r is Map) TitleRevision.fromJson(r.cast<String, dynamic>()),
    ];
    return TitleBlock(
        company: s('company'),
        responsible: s('responsible'),
        council: s('council'),
        registration: s('registration'),
        responsibilityRecord: s('record'),
        car: s('car'),
        waterPermit: s('permit'),
        municipality: s('municipality'),
        stage: enumByName(ProjectStage.values, j['stage'], ProjectStage.none, report: report, key: 'titleBlock.stage'),
        drawingNumber: s('drawingNo'),
        issueDate: s('issued'),
        revisions: revisions,
        logo: logo,
        logoMime: s('logoMime'),
      )
      .._logoText = logo == null ? null : logoText
      ..extra = j.unread;
  }
}

/// A date as typed in the title block: `YYYY-MM-DD`, or day first
/// (`DD/MM/YYYY`, `DD.MM.YYYY`, `DD-MM-YYYY`); null when it is no date.
DateTime? parseTitleDate(String text) {
  final s = text.trim();
  if (s.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  final dayFirst = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(s);
  int? y, m, d;
  if (iso != null) {
    (y, m, d) = (int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  } else if (dayFirst != null) {
    (y, m, d) = (int.parse(dayFirst[3]!), int.parse(dayFirst[2]!), int.parse(dayFirst[1]!));
  }
  if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  // 31/02 rolls over into March: no such day
  return date.month == m && date.day == d ? date : null;
}

/// [d] as the title block stores it (YYYY-MM-DD).
String titleDateText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
