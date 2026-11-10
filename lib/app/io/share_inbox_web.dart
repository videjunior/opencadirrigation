import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'links.dart' show clearAddressFragment;
import 'share_inbox.dart';

/// The links `site.js` took out of the address (the one that opened the page, at once; those pasted later, as they
/// come). A page without that script (another host page): the address itself, read before the engine sets up its
/// history, then cleared.
void captureShareLinks(ShareInbox inbox) {
  try {
    final take = globalContext.getProperty<JSAny?>('ociLinks'.toJS);
    if (take.isA<JSFunction>()) {
      (take as JSFunction).callAsFunction(
        null,
        ((JSAny? link) {
          if (link.isA<JSString>()) inbox.receive((link as JSString).toDart);
        }).toJS,
      );
      return;
    }
    final hash = web.window.location.hash;
    if (isShareFragment(hash)) {
      inbox.receive(hash);
      clearAddressFragment();
    }
  } catch (_) {
    // no window to read (a worker), or a page that refuses: no link
  }
}
