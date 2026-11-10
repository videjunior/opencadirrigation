/// AI coverage of the functions added in 1.7.0 for the irrigation programme
/// played on the plan (the player over the drawing, the animation as a GIF,
/// a frame as a PNG, the programme as a calendar file) (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coveragePly = <String, String>{
  // ---- Design → Agronomy (desktop menu and phone menu)
  'menu:ply.menu': 'op:programme_picture',
  // ---- the player of lib/app/widgets/dialogs/programme_player_dialogs.dart and its controls
  'dialog:programme_player_dialogs.programmePlayer': 'op:programme_picture',
  'dialog:programme_player_dialogs.programmePlayer.play': 'op:programme_picture',
  'dialog:programme_player_dialogs.programmePlayer.seek': 'op:programme_picture',
  'dialog:programme_player_dialogs.programmePlayer.next': 'op:programme_picture',
  'dialog:programme_player_dialogs.programmePlayer.speed': 'n/a:the pace of the animation on the user\'s screen; the assistant looks at any moment with programme_picture',
  'dialog:programme_player_dialogs.programmePlayer.png': 'op:export_programme_animation',
  'dialog:programme_player_dialogs.programmeGif': 'op:export_programme_animation',
  'dialog:programme_player_dialogs.programmeGif.size': 'op:export_programme_animation',
  'dialog:programme_player_dialogs.programmeGif.frames': 'op:export_programme_animation',
  'dialog:programme_player_dialogs.programmeGif.baseMap': 'op:export_programme_animation',
  'dialog:programme_player_dialogs.programmeCalendar': 'op:export_programme_calendar',
  'dialog:programme_player_dialogs.programmeCalendar.days': 'op:export_programme_calendar',
  'dialog:programme_player_dialogs.programmeCalendar.month': 'op:export_programme_calendar',
  // ---- the Play button of the irrigation programme dialog
  'dialog:water_balance_dialogs.irrigationProgramme.play': 'op:programme_picture',
};
