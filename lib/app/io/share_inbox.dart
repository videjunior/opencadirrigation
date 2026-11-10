/// Projects shared by a link (`#p=…`, lib/core/io/share_link.dart) reach the
/// app through this inbox, never through the address the app reads later.
///
/// The web engine reads the fragment of the address as a page of the app (it
/// keeps the default hash address strategy) and rewrites the address without
/// it while it starts, before the first frame: a link read from the address
/// after start-up was always gone (1.6.1). So the entry page's script
/// (`site.js`, written by tool/site.dart) takes the link out of the address
/// before the engine and the statistics load, and hands it over through
/// `window.ociLinks`; [captureShareLinks], the first thing `main()` does,
/// takes it from there (or, on a page without that script, from the address
/// itself, before the engine has set up its history). A link pasted into the
/// address bar of the open app arrives the same way, later.
///
/// Nothing happens on the desktop builds, which have no address.
library;

import 'share_inbox_stub.dart' if (dart.library.js_interop) 'share_inbox_web.dart' as impl;

/// Whether [fragment] (with or without its `#`) is the fragment of a share
/// link, as `shareLinkFor` writes it.
bool isShareFragment(String fragment) {
  final f = fragment.startsWith('#') ? fragment.substring(1) : fragment;
  return f.startsWith('p=') && f.length > 2;
}

/// The share links of this page: the one that opened it, for the start-up
/// to open, and those that came later (a link pasted into the address bar),
/// for the shell to open as they arrive.
class ShareInbox {
  String? _start;
  bool _startTaken = false;
  final List<String> _later = [];
  void Function(String fragment)? _listener;

  /// A link [fragment] (`#p=…`) arrives. Anything else is ignored.
  void receive(String fragment) {
    if (!isShareFragment(fragment)) return;
    final f = fragment.startsWith('#') ? fragment : '#$fragment';
    if (!_startTaken && _start == null) {
      _start = f;
    } else if (_listener != null) {
      _listener!(f);
    } else {
      _later.add(f);
    }
  }

  /// The link that opened the page, once: the start-up opens it (null when
  /// none, and on every later call). Links arriving from now on are later
  /// links.
  String? takeStart() {
    final f = _start;
    _start = null;
    _startTaken = true;
    return f;
  }

  /// Calls [onLink] with every later link, those that arrived before first
  /// (in their order). One listener at a time: the last one set.
  void listen(void Function(String fragment) onLink) {
    _listener = onLink;
    final pending = List.of(_later);
    _later.clear();
    for (final f in pending) {
      onLink(f);
    }
  }

  /// Stops calling [onLink] (the listener set, when null): later links wait again.
  void stopListening([void Function(String fragment)? onLink]) {
    if (onLink == null || _listener == onLink) _listener = null;
  }
}

/// The inbox of this page.
final shareInbox = ShareInbox();

/// Takes the links the page was handed (and, on the web, keeps taking those
/// pasted later) into [inbox]; called first thing in `main()`.
void captureShareLinks([ShareInbox? inbox]) => impl.captureShareLinks(inbox ?? shareInbox);
