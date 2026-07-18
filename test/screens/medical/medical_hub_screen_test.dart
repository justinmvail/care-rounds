import 'package:carerounds/screens/medical/medical_hub_screen.dart';
import 'package:carerounds/widgets/hub_tile.dart';
import 'package:carerounds/widgets/path_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The ten tiles in their display order, grouped into three sections
/// (Track-2 #31): (label, icon, route). Order = section order, then tile
/// order within each section — "This visit", then "Client info", then
/// "Team & training".
///
/// The **Team** tile is always present (the door to the cross-client Team
/// hub stays discoverable; the `/team` sub-hub itself handles the
/// coordination-off onboarding).
///
/// `route` is the exact string each tile `context.push`es — it doubles as
/// the per-tile [MedicalHubScreen.tileKey] seed, so it must match the
/// screen verbatim. The "Schedule" tile is the single consolidated time
/// surface (Track-2 #32) — a segmented Calendar / Appointments / Routines
/// wrapper at `/medical/schedule`, replacing the three former peer tiles.
const List<(String, IconData, String)> _expected = <(String, IconData, String)>[
  // This visit
  ('Document visit', Icons.mic_none_outlined, '/medical/visit-note'),
  ('Schedule', Icons.schedule_outlined, '/medical/schedule'),
  ('Health Log', Icons.monitor_heart_outlined, '/medical/health-log'),
  ('Journal', Icons.book_outlined, '/journal'),
  ('Scan a document', Icons.document_scanner_outlined, '/scan'),
  // Client info
  ('Emergency Card', Icons.shield_outlined, '/medical/cards/emergency'),
  ('Medications', Icons.medication_outlined, '/medications'),
  ('Care summary', Icons.summarize_outlined, '/care-summary'),
  // Team & training
  ('Team', Icons.groups_outlined, '/team'),
  ('Learn', Icons.school_outlined, '/learn'),
];

/// The route path a tile resolves to, with any `?query` stripped. A
/// `GoRoute` is registered by path (a query string is not a valid path
/// pattern), and `matchedLocation` likewise reports the path only — the
/// query params live on the URI separately. So a tile that pushes
/// `/team/calendar?from=medical` matches the `/team/calendar` route.
String _matchedPath(String route) => Uri.parse(route).path;

/// A router that mounts the hub at `/medical` and registers a stub
/// destination for every tile route so a `context.push` resolves end to
/// end. The destinations the hub points at land in later phases; here we
/// only assert the navigation target is correct.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/medical',
    routes: <RouteBase>[
      GoRoute(
        path: '/medical',
        builder: (BuildContext context, GoRouterState state) =>
            const MedicalHubScreen(),
      ),
      for (final (_, _, String route) in _expected)
        GoRoute(
          path: _matchedPath(route),
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(child: Text('DEST ${_matchedPath(route)}')),
          ),
        ),
    ],
  );
}

/// Pumps the hub at a tall phone surface so all tiles render inside the
/// viewport (the grid scrolls, but a tall surface keeps every tile
/// hittable). [MedicalHubScreen] is a plain StatelessWidget now (the tile
/// list no longer reads settings), so no ProviderScope is needed. We
/// deliberately skip `careroundsLightTheme` — its google_fonts TextStyles
/// fire fire-and-forget Futures that surface as uncaught errors in a
/// font-less test host; the screen re-applies its brand colors directly,
/// so navigation behavior is unaffected.
Future<GoRouter> _pumpHub(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final GoRouter router = _router();
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('MedicalHubScreen', () {
    testWidgets(
        'renders all ten tiles grouped into three sections, in order',
        (WidgetTester tester) async {
      await _pumpHub(tester);

      final List<HubTile> tiles =
          tester.widgetList<HubTile>(find.byType(HubTile)).toList();
      expect(tiles.length, 10);
      // The three section headings render, in order (Track-2 #31).
      expect(find.text('THIS VISIT'), findsOneWidget);
      expect(find.text('CLIENT INFO'), findsOneWidget);
      expect(find.text('TEAM & TRAINING'), findsOneWidget);
      // "Document visit" (the flagship) leads the first section.
      expect(tiles.first.label, 'Document visit');
      expect(
        tiles.map((HubTile t) => t.label).toList(),
        <String>[for (final (String label, _, _) in _expected) label],
      );
      expect(
        tiles.map((HubTile t) => t.icon).toList(),
        <IconData>[for (final (_, IconData icon, _) in _expected) icon],
      );
    });

    testWidgets('the Find-a-provider tile uses plain-language, not "NPI"',
        (WidgetTester tester) async {
      await _pumpHub(tester);

      final HubTile provider = tester
          .widgetList<HubTile>(find.byType(HubTile))
          .firstWhere((HubTile t) => t.label == 'Learn');
      expect(provider.subLabel, 'quick training');
      expect(find.textContaining('NPI'), findsNothing);
    });

    testWidgets('the landing breadcrumb starts from Home (Home › Care)',
        (WidgetTester tester) async {
      await _pumpHub(tester);

      // Every page's trail starts at Home now, so the Care landing reads
      // "Home › Care" rather than suppressing the breadcrumb.
      expect(find.byType(PathHeader), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('›'), findsOneWidget); // Home › Care
      // 'Care' is both the title and the terminal crumb.
      expect(find.text('Care'), findsNWidgets(2));
      // No legacy Back chevron control.
      expect(find.text('‹'), findsNothing);
    });

    testWidgets(
        'the Care Circle tile is always present with an inviting sub-label',
        (WidgetTester tester) async {
      // No longer gated on the Settings toggle (UIUX_REVIEW) — the door to
      // inviting family stays discoverable regardless of coordination state.
      await _pumpHub(tester);

      final List<HubTile> tiles =
          tester.widgetList<HubTile>(find.byType(HubTile)).toList();
      final HubTile careCircle =
          tiles.firstWhere((HubTile t) => t.label == 'Team');
      expect(careCircle.subLabel, 'clients, caregivers & shifts');
      expect(
        find.byKey(MedicalHubScreen.tileKey('/team')),
        findsOneWidget,
      );
    });

    for (final (String label, _, String route) in _expected) {
      testWidgets('tapping "$label" pushes $route',
          (WidgetTester tester) async {
        final GoRouter router = await _pumpHub(tester);

        await tester.ensureVisible(
          find.byKey(MedicalHubScreen.tileKey(route)),
        );
        await tester.tap(find.byKey(MedicalHubScreen.tileKey(route)));
        await tester.pumpAndSettle();

        // A tile `context.push`es its route — the imperative push keeps
        // the shell's base URI but appends the pushed match, so assert on
        // the last matched location (and the rendered destination). The
        // matched location is the route *path*; a tile that pushes a
        // `?query` (Schedule's `?from=medical`) still resolves to its
        // bare-path route, so compare against [_matchedPath].
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          _matchedPath(route),
        );
        expect(find.text('DEST ${_matchedPath(route)}'), findsOneWidget);
      });
    }
  });
}
