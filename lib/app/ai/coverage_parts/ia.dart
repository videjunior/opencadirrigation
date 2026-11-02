/// AI coverage of the functions added in 1.6.0 for the AI assistant (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageIa = <String, String>{
  // the assistant's own settings and cards: the user's choices about the assistant
  'panel:ai.keepWarm': 'n/a:the user decides what the assistant may spend while the user pauses; the assistant never changes its own settings',
  'panel:ai.notesTrust': 'n/a:only the user can take the project\'s notes written elsewhere as their own (the assistant reads them with get_notes, marked as information)',
  'panel:ai.notesReview': 'n/a:opens the assistant\'s settings for the user to read and edit the notes; the assistant reads them with get_notes and writes them with update_notes',
  'panel:ai.effortHint': 'n/a:a note on how a change of effort applies; the effort is the user\'s choice in the assistant\'s settings',
  'panel:ai.otherTab': 'n/a:a notice that another browser tab keeps this project\'s conversation; nothing to run',
};
