import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void navigateTo(String route) {
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
  }
}
