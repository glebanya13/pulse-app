import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Fast fade for pushes - no slide (slide + opacity is expensive with maps/images).
CustomTransitionPage<T> buildSmoothPage<T>({
  required GoRouterState state,
  required Widget child,
  bool opaque = true,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    opaque: opaque,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Softer shared-axis feel for welcome ↔ login ↔ register ↔ verify.
CustomTransitionPage<T> buildAuthPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.04, 0.03),
        end: Offset.zero,
      ).animate(curved);
      final fadeOut = Tween<double>(begin: 1, end: 0.88).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: fadeOut,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        ),
      );
    },
  );
}

NoTransitionPage<T> buildTabPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    child: child,
  );
}
