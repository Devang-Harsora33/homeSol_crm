import 'package:flutter/material.dart';

class AppObserver extends RouteObserver<ModalRoute<dynamic>> {
  static String? currentScreenName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _updateScreenName(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _updateScreenName(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      _updateScreenName(previousRoute);
    }
  }

  void _updateScreenName(PageRoute route) {
    final screenName = route.settings.name;
    if (screenName != null) {
      currentScreenName = screenName;
    }
  }
}
