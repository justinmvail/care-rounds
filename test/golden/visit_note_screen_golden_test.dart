import 'package:alchemist/alchemist.dart';
import 'package:carerounds/screens/medical/visit_note_screen.dart';
import 'package:carerounds/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Golden of the flagship ambient-documentation entry (Track-2 #16), on its
/// capture phase — talk-it-through button, the free-text account field, and
/// the "Write the note" primary. The review phase is exercised by the widget
/// test (it needs a service to populate it).
Widget _host() {
  final GoRouter router = GoRouter(
    initialLocation: VisitNoteScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: VisitNoteScreen.route,
        builder: (_, __) => const VisitNoteScreen(),
      ),
    ],
  );
  return ProviderScope(
    child: SizedBox(
      width: 420,
      height: 820,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => ColoredBox(
          color: careroundsColors.background,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
  group('VisitNoteScreen golden', () {
    goldenTest(
      'capture phase — talk it through, then write the note',
      fileName: 'visit_note_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(name: 'capture', child: _host()),
        ],
      ),
    );
  });
}
