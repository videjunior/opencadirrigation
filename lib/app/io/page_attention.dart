/// Whether the page is in the background, and how to call its user back
/// from there (conditional import): in the browser, the visibility and the
/// focus of the document, the title of its tab and the Notifications API;
/// elsewhere (desktop builds, tests) nothing.
library;

import 'page_attention_stub.dart' if (dart.library.js_interop) 'page_attention_web.dart' as impl;

/// What the page can do to call its user back.
abstract class PageAttention {
  /// The page is hidden (another tab, the window minimised) or the window
  /// does not have the focus.
  bool get inBackground;

  /// Alternates the title of the tab with [text] until [stopBlink], or until
  /// the page comes back to the foreground.
  void blinkTitle(String text);
  void stopBlink();

  /// The permission of the system notifications: `granted`, `denied`,
  /// `default` (not asked yet) or `unsupported`.
  String get notificationPermission;

  /// Asks the user to allow the system notifications (call it from a click:
  /// browsers ignore it otherwise); the permission afterwards.
  Future<String> requestNotifications();

  /// Shows a system notification (only when it is granted); a click on it
  /// brings the page to the front. [tag] replaces an earlier one of the
  /// same tag.
  void notify(String title, String body, {String tag = ''});

  /// [f] runs whenever the page comes back to the foreground.
  void onForeground(void Function() f);
}

/// The page of this platform (one per app).
PageAttention get pageAttention => _page ??= impl.platformPageAttention();
PageAttention? _page;

/// Nothing to call back with: the desktop builds and the tests.
class NoPageAttention implements PageAttention {
  const NoPageAttention();

  @override
  bool get inBackground => false;

  @override
  void blinkTitle(String text) {}

  @override
  void stopBlink() {}

  @override
  String get notificationPermission => 'unsupported';

  @override
  Future<String> requestNotifications() async => 'unsupported';

  @override
  void notify(String title, String body, {String tag = ''}) {}

  @override
  void onForeground(void Function() f) {}
}
