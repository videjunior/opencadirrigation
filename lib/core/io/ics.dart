/// iCalendar files (RFC 5545, "Internet Calendaring and Scheduling Core
/// Object Specification", IETF 2009), the subset a calendar of events
/// needs: a VCALENDAR with VEVENTs that start at a local "floating" time
/// (§3.3.5 form #1: no "Z", no TZID — the event happens at that clock time
/// wherever the phone is), last a DURATION (§3.3.6) and repeat by an RRULE
/// (§3.3.10), plus the calendar name of RFC 7986 (NAME) and the
/// X-WR-CALNAME most calendar apps read.
///
/// The format rules this writer keeps (and test/core/ics_test.dart checks):
/// - every line ends in CRLF (§3.1);
/// - a line longer than 75 octets is folded: CRLF then one space, the
///   octets counted in UTF-8 and a character never split (§3.1);
/// - TEXT values escape backslash, semicolon and comma with a backslash and
///   write a line break as "\n" (§3.3.11);
/// - every VEVENT has a UID (§3.8.4.7) and a DTSTAMP in UTC (§3.8.7.2);
///   VERSION and PRODID open the calendar (§3.7.3, §3.7.4).
library;

import 'dart:convert';

/// One event of the calendar.
class IcsEvent {
  const IcsEvent({required this.uid, required this.start, required this.duration, required this.summary, this.description = '', this.rrule, this.transparent = true});

  /// Unique and stable (an import of the same event again updates it).
  final String uid;

  /// Local floating time (the time zone is ignored: the clock time is
  /// written as it is).
  final DateTime start;
  final Duration duration;
  final String summary, description;

  /// The recurrence rule, e.g. `FREQ=DAILY;INTERVAL=2;COUNT=15` (null: once).
  final String? rrule;

  /// Shown as free time (TRANSP:TRANSPARENT): irrigation does not make the
  /// grower busy.
  final bool transparent;
}

/// [s] as an iCalendar TEXT value (§3.3.11).
String icsText(String s) => s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\r\n', '\\n').replaceAll('\n', '\\n').replaceAll('\r', '\\n');

/// The content line [line] folded at 75 octets (§3.1): the physical lines,
/// each continuation starting with one space, UTF-8 sequences kept whole.
List<String> icsFold(String line) {
  const max = 75;
  final out = <String>[];
  final cur = StringBuffer();
  var octets = 0;
  var limit = max;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (octets + n > limit) {
      out.add(cur.toString());
      cur
        ..clear()
        ..write(' ');
      octets = 1;
      limit = max;
    }
    cur.write(ch);
    octets += n;
  }
  out.add(cur.toString());
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A DATE-TIME in local floating form, `YYYYMMDDTHHMMSS` (§3.3.5).
String icsLocal(DateTime t) => '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

/// A DATE-TIME in UTC, `YYYYMMDDTHHMMSSZ` (§3.3.5 form #2).
String icsUtc(DateTime t) => '${icsLocal(t.toUtc())}Z';

/// A DURATION (§3.3.6): `PT1H30M`, whole minutes (at least one).
String icsDuration(Duration d) {
  final minutes = d.inSeconds <= 0 ? 1 : (d.inSeconds / 60).round().clamp(1, 1 << 30);
  final h = minutes ~/ 60, m = minutes % 60;
  return 'PT${h > 0 ? '${h}H' : ''}${m > 0 || h == 0 ? '${m}M' : ''}';
}

/// The calendar [name] with [events], stamped at [stamp] (the time the file
/// is made; written in UTC), as the text of an .ics file.
String writeIcs({required String prodId, required String name, required List<IcsEvent> events, required DateTime stamp, String? description}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$prodId',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'NAME:${icsText(name)}',
    'X-WR-CALNAME:${icsText(name)}',
    if (description != null && description.isNotEmpty) ...['DESCRIPTION:${icsText(description)}', 'X-WR-CALDESC:${icsText(description)}'],
  ];
  final dtstamp = icsUtc(stamp);
  for (final e in events) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${e.uid}',
      'DTSTAMP:$dtstamp',
      'DTSTART:${icsLocal(e.start)}',
      'DURATION:${icsDuration(e.duration)}',
      if (e.rrule != null) 'RRULE:${e.rrule}',
      'SUMMARY:${icsText(e.summary)}',
      if (e.description.isNotEmpty) 'DESCRIPTION:${icsText(e.description)}',
      if (e.transparent) 'TRANSP:TRANSPARENT',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  final b = StringBuffer();
  for (final l in lines) {
    for (final f in icsFold(l)) {
      b
        ..write(f)
        ..write('\r\n');
    }
  }
  return b.toString();
}

/// The content lines of [ics] unfolded (§3.1: a CRLF followed by a space or
/// a tab is removed).
List<String> icsUnfold(String ics) => ics.replaceAll(RegExp('\r\n[ \t]'), '').split('\r\n').where((l) => l.isNotEmpty).toList();

/// A 32-bit FNV-1a hash of [s] in hexadecimal (stable UIDs; the product
/// by the prime 2^24 + 403 is split so that it stays exact where an int is
/// a double, on the web).
String icsHash(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h = (h ^ b) & 0xFFFFFFFF;
    h = (((h << 24) & 0xFFFFFFFF) + h * 403) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
