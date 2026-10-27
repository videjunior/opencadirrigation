/// The start-up screen: where the area to irrigate is, and whether the AI
/// assistant should design it with the user. Shown when the app opens on a
/// fresh, empty project (not when the address opens an example, the
/// tutorial or a shared project, nor after recovered work), unless the user
/// turned it off here or in the assistant's settings.
///
/// The place is an address or place name found with OpenStreetMap
/// (searched only when the user asks, or presses a start button with a
/// place typed) or coordinates in any form [parseLatLon] reads. Nothing
/// goes to the AI provider from here: the request waits in the assistant's
/// box until the user presses Send.
library;

import 'package:flutter/material.dart';

import '../../../core/io/geo.dart' show parseLatLon;
import '../../ai/ai_assistant.dart';
import '../../io/place_search.dart';
import '../../state/controller.dart';
import '../../theme.dart';

/// What the start-up screen gives back: the place of the project (null:
/// none given), its name, and the request for the assistant when the user
/// chose to design with it (null: start without the AI).
class StartChoice {
  const StartChoice({this.place, this.placeName, this.aiPrompt});
  final (double lat, double lon)? place;
  final String? placeName;
  final String? aiPrompt;
  bool get ai => aiPrompt != null;
}

/// Shows the start-up screen; it always comes back with a choice.
Future<StartChoice> showAiStartDialog(BuildContext context, ProjectController c) async =>
    await showDialog<StartChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiStartDialog(c: c),
    ) ??
    const StartChoice();

class AiStartDialog extends StatefulWidget {
  const AiStartDialog({super.key, required this.c});
  final ProjectController c;

  @override
  State<AiStartDialog> createState() => _AiStartDialogState();
}

class _AiStartDialogState extends State<AiStartDialog> {
  final where = TextEditingController();
  final describe = TextEditingController();
  bool never = false;

  /// The places found for [_searched] (one for typed coordinates).
  List<PlaceHit> hits = const [];
  int? picked;
  String? _searched;
  bool searching = false;
  bool fromOsm = false;
  String? whereError;

  ProjectController get c => widget.c;

  @override
  void dispose() {
    where.dispose();
    describe.dispose();
    super.dispose();
  }

  void _whereChanged(String text) {
    // the matches belong to the text they were found for
    if (_searched != null && text.trim() != _searched) {
      setState(() {
        hits = const [];
        picked = null;
        _searched = null;
        whereError = null;
      });
    }
  }

  /// Finds what is typed: coordinates directly, anything else on
  /// OpenStreetMap. True when there is a place to use.
  Future<bool> _search() async {
    final t = c.t;
    final text = where.text.trim();
    if (text.isEmpty) {
      setState(() {
        hits = const [];
        picked = null;
        _searched = null;
        whereError = null;
      });
      return false;
    }
    final ll = parseLatLon(text);
    if (ll != null) {
      setState(() {
        hits = [PlaceHit(t('start.coords', {'lat': ll.$1.toStringAsFixed(5), 'lon': ll.$2.toStringAsFixed(5)}), ll.$1, ll.$2)];
        picked = 0;
        _searched = text;
        fromOsm = false;
        whereError = null;
      });
      return true;
    }
    setState(() {
      searching = true;
      whereError = null;
    });
    try {
      final found = await searchPlaces(text, lang: c.lang);
      if (!mounted) return false;
      setState(() {
        hits = found;
        picked = found.isEmpty ? null : 0;
        _searched = text;
        fromOsm = true;
        whereError = found.isEmpty ? t('start.notFound') : null;
      });
      return found.isNotEmpty;
    } on PlaceSearchError {
      if (mounted) setState(() => whereError = t('start.searchFailed'));
      return false;
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _finish(bool ai) async {
    final text = where.text.trim();
    if (text.isNotEmpty && _searched != text) {
      // typed but not searched yet: find it first; with several matches the
      // user picks one and presses again
      final ok = await _search();
      if (!ok || hits.length > 1 || !mounted) return;
    }
    if (never) AiAssistant.askAtStart = false;
    final h = picked == null || picked! >= hits.length ? null : hits[picked!];
    final request = describe.text.trim();
    Navigator.of(context).pop(
      StartChoice(
        place: h == null ? null : (h.lat, h.lon),
        placeName: h?.name,
        aiPrompt: ai ? (request.isEmpty ? c.t('ai.start.prompt') : request) : null,
      ),
    );
  }

  Widget _hit(int i, PlaceHit h) => InkWell(
    key: Key('start_hit_$i'),
    onTap: () => setState(() => picked = i),
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(picked == i ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18, color: picked == i ? Cad.accentText : Cad.fg54),
          const SizedBox(width: 8),
          Expanded(child: Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final ai = AiAssistant.of(c);
    final m = ai.model;
    final compact = MediaQuery.sizeOf(context).width < 600;
    const head = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600);
    return AlertDialog(
      key: const Key('ai_start'),
      title: Row(
        children: [
          Icon(Icons.edit_location_alt_outlined, color: Cad.accentText),
          const SizedBox(width: 10),
          Expanded(child: Text(t('start.title'))),
        ],
      ),
      content: SizedBox(
        width: compact ? double.maxFinite : 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. where the area is
              Text(t('start.where'), style: head),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('start_where'),
                      controller: where,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      textInputAction: TextInputAction.search,
                      onChanged: _whereChanged,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: t('start.whereHint'),
                        prefixIcon: const Icon(Icons.place_outlined, size: 20),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const Key('start_search'),
                    onPressed: searching ? null : _search,
                    child: searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('start.search')),
                  ),
                ],
              ),
              if (whereError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(whereError!, key: const Key('start_where_error'), style: TextStyle(fontSize: 12, color: Cad.unconnected)),
                ),
              if (hits.length > 1) Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(t('start.pick'), style: TextStyle(fontSize: 12, color: Cad.fg70))),
              if (hits.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Column(children: [for (final (i, h) in hits.indexed) _hit(i, h)])),
              if (hits.isNotEmpty && fromOsm) Text(t('start.osm'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
              const SizedBox(height: 6),
              Text(t('start.whereNote', {'f': t('menu.file'), 'g': t('file.georef').replaceAll('…', '')}), style: TextStyle(fontSize: 11.5, color: Cad.fg60, height: 1.35)),
              const Divider(height: 28),
              // 2. the AI assistant
              Row(
                children: [
                  Icon(Icons.smart_toy_outlined, size: 19, color: Cad.accentText),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t('ai.start.title'), style: head)),
                ],
              ),
              const SizedBox(height: 6),
              Text(t('ai.start.body'), style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ai_start_describe'),
                controller: describe,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: t('ai.start.describe'),
                  hintText: t('ai.start.example'),
                  hintMaxLines: 3,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ai.hasKey ? t('ai.start.keyReady', {'m': m.label, 'p': m.provider.company}) : t('ai.start.keyNeeded'),
                key: const Key('ai_start_key'),
                style: TextStyle(fontSize: 11.5, color: Cad.fg60, height: 1.35),
              ),
              CheckboxListTile(
                key: const Key('ai_start_never'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: never,
                onChanged: (v) => setState(() => never = v ?? false),
                title: Text(t('ai.start.never'), style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(key: const Key('ai_start_no'), onPressed: searching ? null : () => _finish(false), child: Text(t('start.noAi'))),
        FilledButton.icon(
          key: const Key('ai_start_yes'),
          onPressed: searching ? null : () => _finish(true),
          icon: const Icon(Icons.smart_toy_outlined, size: 18),
          label: Text(t('ai.start.yes')),
        ),
      ],
    );
  }
}
