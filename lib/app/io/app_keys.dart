import 'package:flutter/widgets.dart';

/// Navigator of the running app; used by platform code (desktop file
/// dialogs) that has no BuildContext of its own.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'appNavigator');

/// Tracks the route on top of the navigator (dialogs, menus), for the
/// keyboard dispatcher: Esc closes a dismissible dialog even when the
/// browser focus is not inside the Flutter view.
class AppRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  Route<dynamic>? get top => _stack.isEmpty ? null : _stack.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
  }
}

final AppRouteObserver appRouteObserver = AppRouteObserver();
