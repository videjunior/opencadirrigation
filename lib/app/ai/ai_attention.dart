/// Calls the user back when the app is in the background and a task of the
/// assistant waits for them (an approval, questions, a plan) or ends: the
/// title of the browser tab blinks until the page is in front again and,
/// when the user allowed it in the assistant's settings, a system
/// notification says so (the Notifications API). Nothing leaves the page.
library;

import 'dart:async';

import '../io/page_attention.dart';
import '../io/prefs.dart';
import 'ai_assistant.dart';

/// What happened to a task, for the call back.
enum AiAttentionEvent { waiting, done, failed }

class AiAttention {
  AiAttention._();

  /// The page (tests put a fake one here).
  static PageAttention? debugPage;
  static PageAttention get _page => debugPage ?? pageAttention;

  /// The title of the tab blinks when a task in the background waits or
  /// ends (on by default).
  static bool get enabled => getPref('ai.attention') != 'off';
  static set enabled(bool on) {
    setPref('ai.attention', on ? 'on' : 'off');
    if (!on) _page.stopBlink();
  }

  /// A system notification goes with it, once the browser allows them (the
  /// user turns it on in the settings, which asks the browser).
  static bool get notify => getPref('ai.notify') == 'on';
  static set notify(bool on) {
    if (on) {
      setPref('ai.notify', 'on');
    } else {
      removePref('ai.notify');
    }
  }

  /// The permission of the system notifications ([PageAttention.notificationPermission]).
  static String get permission => _page.notificationPermission;

  /// Asks the browser to allow the system notifications (from a click) and
  /// turns them on when it does; the permission afterwards.
  static Future<String> allowNotifications() async {
    final p = await _page.requestNotifications();
    notify = p == 'granted';
    return p;
  }

  static bool _installed = false;

  /// What each assistant was doing at the last change of activity.
  static final Map<AiAssistant, (bool busy, bool waiting)> _was = {};

  /// Starts listening to the assistants (once).
  static void ensure() {
    if (_installed) return;
    _installed = true;
    AiAssistant.activity.addListener(_check);
  }

  /// Forgets what was seen (tests).
  static void debugReset() {
    _was.clear();
    _page.stopBlink();
  }

  static bool _scheduled = false;

  /// After a change of activity: once what the change brings is in place
  /// (a task that ends says how only after it marks the end).
  static void _check() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      _look();
    });
  }

  static void _look() {
    final page = _page;
    final live = {...AiAssistant.live};
    _was.removeWhere((a, _) => !live.contains(a));
    for (final a in live) {
      final was = _was[a] ?? (false, false);
      final now = (a.busy, a.waiting);
      _was[a] = now;
      AiAttentionEvent? e;
      if (now.$2 && !was.$2) {
        e = AiAttentionEvent.waiting;
      } else if (was.$1 && !now.$1) {
        e = a.lastTurnFailed ? AiAttentionEvent.failed : AiAttentionEvent.done;
      }
      if (e == null || !enabled || !page.inBackground) continue;
      final t = a.c.t;
      final name = a.c.project.meta.name.trim().isEmpty ? t('name.newProject') : a.c.project.meta.name.trim();
      final title = t('ai.attn.${e.name}');
      page.blinkTitle(title);
      if (notify) page.notify(title, t('ai.attn.${e.name}.body', {'n': name}), tag: 'opencadirrigation-ai');
    }
  }
}
