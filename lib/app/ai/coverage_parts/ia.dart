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
  // ---- 1.6.0 IA+ (wave 2): the assistant's own panel, settings and cards
  'panel:ai.connectionTest': 'n/a:the user checks their own key, account and model with one small request; the assistant never handles keys',
  'panel:ai.applyRest': 'n/a:the user\'s answer to an approval card (this change and the plain ones after it); the assistant proposes, the user approves',
  'panel:ai.stepCosts': 'n/a:the user\'s view of what each request cost and read from the cache; the assistant\'s own tokens are not a function to run',
  'panel:ai.stageEffort': 'n/a:the user decides how much the assistant reasons at each stage; the assistant never changes its own settings',
  'panel:ai.attention': 'n/a:how the program calls the user back to the browser tab (the title blinks); nothing to run',
  'panel:ai.notifications': 'n/a:the browser\'s permission for system notifications is the user\'s to give',
  'panel:ai.conversations': 'n/a:the user\'s conversations with the assistant kept in this browser; the assistant works in the one open',
  'panel:ai.exportConversation': 'n/a:a file of the conversation for the user (another browser, a report of a problem); the assistant works in the conversation itself',
  'panel:ai.importConversation': 'n/a:the user brings a conversation back from a file; the assistant then goes on with it',
};
