import 'package:flutter/material.dart';

/// Thread-safe navigation helper with a 350ms debouncing guard and fluid cubic transitions.
/// Prevents multi-click double-pushes, route flickering, and animation jank when tapping fast.
class SafeNavigator {
  SafeNavigator._();

  static DateTime _lastNavTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pushes a new route onto the navigator with debouncing and cubic slide-fade transition.
  static Future<T?> push<T>(BuildContext context, Widget screen) async {
    final now = DateTime.now();
    if (now.difference(_lastNavTime).inMilliseconds < 350) {
      return null;
    }
    _lastNavTime = now;

    return Navigator.push<T>(context, createSmoothRoute<T>(screen));
  }

  /// Replaces the current route with a new route using debouncing and cubic slide-fade transition.
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget screen) async {
    final now = DateTime.now();
    if (now.difference(_lastNavTime).inMilliseconds < 350) {
      return null;
    }
    _lastNavTime = now;

    return Navigator.pushReplacement<T, TO>(context, createSmoothRoute<T>(screen));
  }

  /// Pushes a new route and removes all previous routes until predicate is satisfied.
  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget screen, {
    RoutePredicate? predicate,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastNavTime).inMilliseconds < 350) {
      return null;
    }
    _lastNavTime = now;

    return Navigator.pushAndRemoveUntil<T>(
      context,
      createSmoothRoute<T>(screen),
      predicate ?? (route) => false,
    );
  }

  /// Creates a fluid 260ms cubic slide-fade page route.
  static PageRouteBuilder<T> createSmoothRoute<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}
