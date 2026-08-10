import 'package:flutter/material.dart';

/// Thread-safe navigation helper with a 400ms debouncing guard.
/// Prevents multi-click double-pushes, route flickering, and animation jank when tapping fast.
class SafeNavigator {
  SafeNavigator._();

  static DateTime _lastNavTime = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<T?> push<T>(BuildContext context, Widget screen) async {
    final now = DateTime.now();
    if (now.difference(_lastNavTime).inMilliseconds < 400) {
      return null;
    }
    _lastNavTime = now;

    return Navigator.push<T>(
      context,
      PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
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
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
