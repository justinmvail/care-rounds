import 'dart:async';

import 'package:carerounds/db/database.dart';
import 'package:carerounds/widgets/tab_scaffold.dart';
import 'package:carerounds/l10n/app_localizations.dart';
import 'package:carerounds/models/chat.dart';
import 'package:carerounds/providers/auth_provider.dart';
import 'package:carerounds/providers/home_conversation_provider.dart';
import 'package:carerounds/providers/onboarding_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/routing/router.dart';
import 'package:carerounds/screens/onboarding/loved_one_setup_screen.dart';
import 'package:carerounds/seed/mary_henderson.dart';
import 'package:carerounds/screens/appointment/appointment_list_screen.dart';
import 'package:carerounds/screens/chat/conversation_list_screen.dart';
import 'package:carerounds/providers/my_rounds_provider.dart';
import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/screens/settings/loved_ones_screen.dart';
import 'package:carerounds/screens/team/my_rounds_screen.dart';
import 'package:carerounds/screens/home_screen.dart';
import 'package:carerounds/screens/medical/emergency_card_screen.dart';
import 'package:carerounds/screens/medical/medical_hub_screen.dart';
import 'package:carerounds/screens/team/care_team_hub_screen.dart';
import 'package:carerounds/screens/medication/medication_list_screen.dart';
import 'package:carerounds/screens/onboarding/sign_in_screen.dart';
import 'package:carerounds/screens/onboarding/welcome_carousel.dart';
import 'package:carerounds/services/chat_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Pump the router wrapped in a bare MaterialApp + a ProviderScope.
/// We deliberately skip `careroundsLightTheme` here — its google_fonts
/// TextStyles fire fire-and-forget Futures during construction; in
/// unit tests without bundled font assets those Futures fail in the
/// root zone and surface as uncaught errors. The theme contract is
/// owned by theme_test.dart; here we only care about navigation
/// behaviour.
///
/// Used by the behavioural groups (tab switching, push semantics, the
/// crisis redirect) which actually mount screens. The exhaustive
/// path-resolution table lives in the `namedLocation` group below — it
/// needs no widget tree, so it never trips the FakeAsync pending-timer
/// assertion that live drift query streams would otherwise raise.
///
/// The ProviderScope is required because the shell branches watch
/// riverpod providers (Home → `homeConversationProvider`, Chat →
/// `chatRepositoryProvider`, Community → `forumApiClientProvider`). The
/// chat repository is backed by an in-memory drift database so the Chat
/// branch resolves deterministically; the community feed falls through
/// to the demo (in-memory) forum client the default settings select.
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  String initialLocation = '/',
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final GoRouter router = buildRouter(initialLocation: initialLocation);
  final DateTime now = DateTime.utc(2026, 5, 30, 12);
  final CareRoundsDatabase db = CareRoundsDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // HomeScreen builds via homeConversationProvider; route-only
        // tests don't stand up a real drift database, so we hand the
        // home tab a synthetic conversation that lets it render the
        // chat scaffold without hitting storage.
        homeConversationProvider.overrideWith(
          (_) async => Conversation(
            id: 'route-test-conv',
            title: 'Today',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        // Chat branch (/chat + /chat/:id) reads the repository through a
        // one-shot FutureProvider; back it with an in-memory database so
        // the list + thread render deterministically. The other
        // storage-backed routes are exercised by `namedLocation` (no
        // widget mount) precisely BECAUSE rendering a live drift query
        // stream inside the FakeAsync test zone leaves a pending timer.
        chatRepositoryProvider.overrideWith((_) => ChatRepository(db)),
        // The Rounds branch renders MyRoundsScreen, which otherwise opens a
        // live drift stream (pending timer → pumpAndSettle hang). Feed it a
        // resolved, DB-free state so the branch renders deterministically.
        selfCaregiverIdProvider.overrideWith((_) async => 'me'),
        myRoundsProvider.overrideWith((_) async => const <CareShift>[]),
        lovedOnesViewProvider.overrideWith(
          (_) async =>
              const LovedOnesView(patients: <Patient>[], activeId: null),
        ),
      ],
      // Onboarding / sign-in / setup screens reachable through the router
      // read chrome strings via AppLocalizations.of (#18 localization);
      // register the delegate + supportedLocales so `.of(context)`
      // resolves (nullable-getter: false).
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

/// One named-route expectation: the [CareRoundsRoutes] name, the
/// path parameters to fill, and the location it must resolve to.
class _NamedRoute {
  const _NamedRoute(this.name, this.location, [this.params = const {}]);
  final String name;
  final String location;
  final Map<String, String> params;
}

void main() {
  group('careroundsRouter — route registration (old + Phase 14 IA)', () {
    // Exhaustive check that every registered route — carried over from
    // earlier phases AND added/moved in the Phase 14.5 rewrite — resolves
    // by name to the expected location. `namedLocation` is a pure lookup
    // against the route table, so it covers the storage-backed feature
    // routes (medication/appointment forms, journal) that can't be safely
    // *rendered* in a unit test without leaving a drift query-stream timer
    // pending. The go()-based behavioural groups below cover the screens
    // that DO render cleanly.
    const List<_NamedRoute> registered = <_NamedRoute>[
      // Carried over from earlier phases.
      _NamedRoute(CareRoundsRoutes.home, '/'),
      _NamedRoute(CareRoundsRoutes.settings, '/settings'),
      _NamedRoute(CareRoundsRoutes.onboarding, '/onboarding'),
      _NamedRoute(CareRoundsRoutes.signIn, '/sign-in'),
      _NamedRoute(CareRoundsRoutes.setup, '/setup'),
      // Journal — moved to top-level pushed routes in Phase 14.5.
      _NamedRoute(CareRoundsRoutes.journal, '/journal'),
      _NamedRoute(CareRoundsRoutes.journalNew, '/journal/new'),
      _NamedRoute(CareRoundsRoutes.journalEntry, '/journal/sample-id',
          <String, String>{'id': 'sample-id'}),
      // Medications — moved to top-level pushed routes in Phase 14.5.
      _NamedRoute(CareRoundsRoutes.medicationList, '/medications'),
      _NamedRoute(CareRoundsRoutes.medicationForm, '/medications/new'),
      _NamedRoute(CareRoundsRoutes.medicationEdit,
          '/medications/sample-id/edit', <String, String>{'id': 'sample-id'}),
      _NamedRoute(CareRoundsRoutes.medicationDoseLog, '/medications/today'),
      // Appointments — moved to top-level pushed routes in Phase 14.5.
      _NamedRoute(CareRoundsRoutes.appointmentList, '/appointments'),
      _NamedRoute(CareRoundsRoutes.appointmentForm, '/appointments/new'),
      _NamedRoute(CareRoundsRoutes.appointmentDetail,
          '/appointments/sample-id', <String, String>{'id': 'sample-id'}),
      _NamedRoute(CareRoundsRoutes.appointmentEdit,
          '/appointments/sample-id/edit', <String, String>{'id': 'sample-id'}),
      // Rounds shell branch (replaces the removed Community forum) + Learn.
      _NamedRoute(CareRoundsRoutes.rounds, '/rounds'),
      _NamedRoute(CareRoundsRoutes.learn, '/learn'),
      _NamedRoute(CareRoundsRoutes.communityLearnPlaybook,
          '/learn/playbooks/sample-id', <String, String>{'id': 'sample-id'}),
      // New Phase 14 shell branches + the Medical emergency sub-route.
      _NamedRoute(CareRoundsRoutes.medicalHub, '/medical'),
      _NamedRoute(
          CareRoundsRoutes.medicalCardsEmergency, '/medical/cards/emergency'),
      _NamedRoute(CareRoundsRoutes.medicalCardsEmergencyEdit,
          '/medical/cards/emergency/edit'),
      _NamedRoute(CareRoundsRoutes.teamHub, '/team'),
      _NamedRoute(CareRoundsRoutes.chatList, '/chat'),
      _NamedRoute(CareRoundsRoutes.chatThread, '/chat/sample-id',
          <String, String>{'id': 'sample-id'}),
      // `/crisis` stays registered for deep-link compat (it redirects at
      // navigation time — see the behavioural group below).
      _NamedRoute(CareRoundsRoutes.crisis, '/crisis'),
    ];

    for (final _NamedRoute route in registered) {
      test('${route.name} resolves to ${route.location}', () {
        final GoRouter router = buildRouter();
        addTearDown(router.dispose);
        expect(
          router.namedLocation(route.name, pathParameters: route.params),
          route.location,
        );
      });
    }
  });

  group('careroundsRouter — fixed 4-tab shell', () {
    testWidgets(
      'opens on Home by default inside the tab shell',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        expect(currentPath(router), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget);
      },
    );

    testWidgets(
      'context.go switches between the four shell branches, tab bar persists',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        // Care branch — the tile hub (Phase 14.15; renamed from Medical in
        // the 2026-06-06 IA refactor, path kept `/medical` internally).
        router.go('/medical');
        await tester.pumpAndSettle();
        expect(currentPath(router), '/medical');
        expect(find.byType(MedicalHubScreen), findsOneWidget);
        expect(
          find.byType(TabScaffoldBar),
          findsOneWidget,
          reason: 'a shell branch keeps the bottom tab bar visible',
        );

        // Care Circle now lives INSIDE the Care branch (no separate Team
        // shell branch), but `/team` still resolves to the hub.
        router.go('/team');
        await tester.pumpAndSettle();
        expect(currentPath(router), '/team');
        expect(find.byType(CareTeamHubScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget);

        // Chat branch — direct landing.
        router.go('/chat');
        await tester.pumpAndSettle();
        expect(currentPath(router), '/chat');
        expect(find.byType(ConversationListScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget);

        // Rounds branch — direct landing.
        router.go('/rounds');
        await tester.pumpAndSettle();
        expect(currentPath(router), '/rounds');
        expect(find.byType(MyRoundsScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget);

        // Back to Home.
        router.go('/');
        await tester.pumpAndSettle();
        expect(currentPath(router), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      '/chat/:id pushes onto the Chat branch navigator (tab bar stays)',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        router.go('/chat');
        await tester.pumpAndSettle();
        expect(find.byType(ConversationListScreen), findsOneWidget);

        // A thread is a child of the Chat branch with no
        // `parentNavigatorKey`, so it pushes onto the branch navigator
        // — the bottom tab bar must remain visible, unlike a root-
        // pushed feature route which covers the whole shell.
        unawaited(router.push('/chat/sample-id'));
        await tester.pumpAndSettle();

        expect(
          find.byType(TabScaffoldBar),
          findsOneWidget,
          reason: 'a thread pushed onto the branch navigator keeps the '
              'tab bar',
        );
        expect(find.byType(ConversationListScreen), findsNothing);
      },
    );

    testWidgets(
      '/crisis redirects to the canonical Emergency Card location',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        router.go('/crisis');
        await tester.pumpAndSettle();

        expect(currentPath(router), '/medical/cards/emergency');
        expect(find.byType(EmergencyCardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('careroundsRouter — push semantics on the moved feature routes', () {
    testWidgets(
      'pushing /medications keeps the tab bar + leaves a PathHeader back',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        // Root of the Home tab has no back affordance + shows the tab
        // bar. The Home landing is a hub landing (single breadcrumb), so
        // it renders no tappable parent crumb.
        expect(find.widgetWithText(InkWell, 'Care'), findsNothing);
        expect(find.byType(TabScaffoldBar), findsOneWidget);

        // `push` adds an imperative match on top of the current stack;
        // go_router doesn't roll the displayed URL forward for imperative
        // pushes, so we assert by what the user sees: the
        // MedicationListScreen, the PathHeader's parent breadcrumb crumb
        // (the tappable 'Care' crumb that IS the back affordance), and —
        // per Caroline's alpha feedback (2026-06-07) — the bottom tab bar
        // STAYS VISIBLE because the route now lives inside the Care shell
        // branch instead of being pushed onto the root navigator.
        unawaited(router.push('/medications'));
        await tester.pumpAndSettle();

        expect(find.byType(MedicationListScreen), findsOneWidget);
        expect(
          find.widgetWithText(InkWell, 'Care'),
          findsOneWidget,
          reason: "the PathHeader's parent crumb is the back affordance "
              "in place of the old AppBar back arrow",
        );
        expect(
          find.byType(TabScaffoldBar),
          findsOneWidget,
          reason: 'an in-branch feature route keeps the bottom tab bar',
        );

        // Tapping the parent breadcrumb crumb runs context.go('/medical'),
        // so we land on the Care hub inside the tab shell — the tab bar
        // stays and the Medications screen is gone.
        await tester.tap(find.widgetWithText(InkWell, 'Care'));
        await tester.pumpAndSettle();
        expect(find.byType(MedicalHubScreen), findsOneWidget);
        expect(find.byType(MedicationListScreen), findsNothing);
        expect(find.byType(TabScaffoldBar), findsOneWidget);
        expect(currentPath(router), '/medical');
      },
    );

    testWidgets(
      'pushing /appointments keeps the tab bar + leaves a PathHeader back',
      (WidgetTester tester) async {
        final GoRouter router = await pumpRouter(tester);

        unawaited(router.push('/appointments'));
        await tester.pumpAndSettle();

        expect(find.byType(AppointmentListScreen), findsOneWidget);
        // The parent 'Care' breadcrumb crumb is the back affordance,
        // replacing the old AppBar back arrow; the route now renders in
        // the Care shell branch, so the bottom tab bar stays visible.
        expect(find.widgetWithText(InkWell, 'Care'), findsOneWidget);
        expect(
          find.byType(TabScaffoldBar),
          findsOneWidget,
          reason: 'an in-branch feature route keeps the bottom tab bar',
        );

        // Tapping the crumb runs context.go('/medical') → the Care hub
        // inside the tab shell.
        await tester.tap(find.widgetWithText(InkWell, 'Care'));
        await tester.pumpAndSettle();
        expect(find.byType(MedicalHubScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget);
        expect(currentPath(router), '/medical');
      },
    );
  });

  group('careroundsRedirect — pure policy (BUILD_SPEC.md §5.11 + §5.12)', () {
    const AuthState signedOut = AuthState.signedOut();
    const AuthState signedIn = AuthState.signedIn(
      user: User(
        id: 'redirect-test',
        email: 'redirect@carerounds.app',
        name: 'Redirect Test',
      ),
    );
    const AuthState loading = AuthState.loading();

    test('un-onboarded + signed-out funnels everything to /onboarding', () {
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: false,
          authState: signedOut,
          patientConfigured: true,
        ),
        '/onboarding',
      );
      expect(
        careroundsRedirect(
          location: '/journal',
          onboardingCompleted: false,
          authState: signedOut,
          patientConfigured: true,
        ),
        '/onboarding',
      );
      expect(
        careroundsRedirect(
          location: '/sign-in',
          onboardingCompleted: false,
          authState: signedOut,
          patientConfigured: true,
        ),
        isNull,
        reason: 'UIUX_REVIEW: `/sign-in` is allowed through the onboarding '
            'gate so the carousel Skip can reach it WITHOUT marking '
            'onboarding done — the value prop stays reachable. Onboarding '
            'completes on a successful sign-in.',
      );
    });

    test(
      '/onboarding returns null when onboarding incomplete (no loop)',
      () {
        // The redirect MUST return null when the user is already on the
        // gate's target location — otherwise go_router treats the
        // decision as unstable and bails after its safety limit.
        expect(
          careroundsRedirect(
            location: '/onboarding',
            onboardingCompleted: false,
            authState: signedOut,
            patientConfigured: true,
          ),
          isNull,
        );
      },
    );

    test('onboarded + signed-out funnels everything to /sign-in', () {
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: true,
        ),
        '/sign-in',
      );
      expect(
        careroundsRedirect(
          location: '/journal',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: true,
        ),
        '/sign-in',
      );
      expect(
        careroundsRedirect(
          location: '/onboarding',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: true,
        ),
        '/sign-in',
        reason: 'onboarded users never need to see the carousel again',
      );
    });

    test('/sign-in returns null when onboarded + signed-out (no loop)', () {
      expect(
        careroundsRedirect(
          location: '/sign-in',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: true,
        ),
        isNull,
      );
    });

    test('auth loading state is treated as signed-out (gates to /sign-in)', () {
      // While the OAuth round-trip is in flight the auth machine reads
      // [AuthStateLoading]. The redirect must NOT bounce the user off
      // `/sign-in` mid-flow — treat anything that isn't explicitly
      // signedIn as signedOut.
      expect(
        careroundsRedirect(
          location: '/sign-in',
          onboardingCompleted: true,
          authState: loading,
          patientConfigured: true,
        ),
        isNull,
      );
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: loading,
          patientConfigured: true,
        ),
        '/sign-in',
      );
    });

    test('signed-in user can navigate anywhere outside the auth screens', () {
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: true,
        ),
        isNull,
      );
      expect(
        careroundsRedirect(
          location: '/journal',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: true,
        ),
        isNull,
      );
      expect(
        careroundsRedirect(
          location: '/medical',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: true,
        ),
        isNull,
      );
    });

    test(
      'signed-in user bounced off /onboarding + /sign-in back to /',
      () {
        // Deep links or browser back can land a signed-in caregiver on
        // an auth screen — kick them home rather than asking them to
        // re-onboard.
        expect(
          careroundsRedirect(
            location: '/onboarding',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: true,
          ),
          '/',
        );
        expect(
          careroundsRedirect(
            location: '/sign-in',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: true,
          ),
          '/',
        );
      },
    );

    test(
      'onboarded + signed-in but NO patient funnels everything to /setup',
      () {
        // The third gate: a fresh real-mode install reaches sign-in, signs
        // in, then has no client on file yet — every location collapses
        // to the setup wizard until one is saved.
        expect(
          careroundsRedirect(
            location: '/',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: false,
          ),
          '/setup',
        );
        expect(
          careroundsRedirect(
            location: '/journal',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: false,
          ),
          '/setup',
        );
      },
    );

    test('/setup returns null when patient not configured (no loop)', () {
      // The redirect MUST return null on the gate's own target so
      // go_router treats the decision as stable.
      expect(
        careroundsRedirect(
          location: '/setup',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: false,
        ),
        isNull,
      );
    });

    test('onboarded + signed-in WITH a patient reaches / (no setup gate)', () {
      // Once a client is on file the setup gate is satisfied: Home
      // resolves cleanly and a stray landing on /setup bounces home.
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: true,
        ),
        isNull,
      );
      expect(
        careroundsRedirect(
          location: '/setup',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: true,
        ),
        '/',
        reason: 'a configured caregiver never needs the setup wizard again',
      );
    });

    test('setup gate sits BELOW onboarding + auth gates', () {
      // Even with no patient, an un-onboarded or signed-out user is held
      // at the earlier gate first — /setup is unreachable until both
      // earlier gates pass.
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: false,
          authState: signedIn,
          patientConfigured: false,
        ),
        '/onboarding',
      );
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: false,
        ),
        '/sign-in',
      );
    });

    test(
      'fresh sign-in lookup PENDING holds on /sign-in, not /setup',
      () {
        // A returning caregiver just signed in on a new install: no loved
        // one on THIS device yet, but the backend lookup that may pull
        // their existing one down is still in flight. The redirect must
        // HOLD on the sign-in screen (its spinner) rather than committing
        // to the setup wizard, which would make them create a duplicate
        // (fb 2026-06-13).
        expect(
          careroundsRedirect(
            location: '/',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: false,
            lovedOneLookupPending: true,
          ),
          '/sign-in',
        );
        // The sign-in screen's own `context.go('/')` lands on '/setup' via
        // an earlier frame — still bounced back while the lookup runs.
        expect(
          careroundsRedirect(
            location: '/setup',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: false,
            lovedOneLookupPending: true,
          ),
          '/sign-in',
        );
      },
    );

    test('/sign-in returns null while the lookup is pending (no loop)', () {
      // The held location returns null so go_router treats the decision as
      // stable and the sign-in page's state is preserved (no re-navigation
      // ping-pong) for the duration of the lookup.
      expect(
        careroundsRedirect(
          location: '/sign-in',
          onboardingCompleted: true,
          authState: signedIn,
          patientConfigured: false,
          lovedOneLookupPending: true,
        ),
        isNull,
      );
    });

    test(
      'lookup PENDING is moot once a client IS configured (still Home)',
      () {
        // If the backend lookup pulled a client down (patientConfigured
        // flips true) the gate opens to Home regardless of a not-yet-
        // cleared pending flag — patient-on-file always wins.
        expect(
          careroundsRedirect(
            location: '/',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: true,
            lovedOneLookupPending: true,
          ),
          isNull,
        );
      },
    );

    test('lookup PENDING never overrides the auth gate', () {
      // A stray pending flag must not strand a signed-OUT user: the auth
      // gate sits above the loved-one lookup, so they still go to sign-in
      // (which is where the flow lives anyway).
      expect(
        careroundsRedirect(
          location: '/',
          onboardingCompleted: true,
          authState: signedOut,
          patientConfigured: false,
          lovedOneLookupPending: true,
        ),
        '/sign-in',
      );
    });

    test(
      'lookup settled (NOT pending) + no patient still funnels to /setup',
      () {
        // Once the lookup clears with no client found (a genuinely new
        // caregiver), the setup wizard is exactly right — the default
        // (pending false) preserves the original gate behavior.
        expect(
          careroundsRedirect(
            location: '/',
            onboardingCompleted: true,
            authState: signedIn,
            patientConfigured: false,
            lovedOneLookupPending: false,
          ),
          '/setup',
        );
      },
    );
  });

  group('careroundsRouterProvider — wired redirect (task 31)', () {
    testWidgets(
      'unauthenticated + un-onboarded app lands on /onboarding',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final _RedirectSpyAuth auth = _RedirectSpyAuth();
        addTearDown(auth.dispose);

        await _pumpWiredRouter(tester, auth: auth);

        // Even though the wired router's `initialLocation` is `/`, the
        // redirect policy collapses everything to `/onboarding` until
        // the carousel finishes.
        expect(find.byType(WelcomeCarousel), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'tapping Skip from /onboarding lands on /sign-in',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final _RedirectSpyAuth auth = _RedirectSpyAuth();
        addTearDown(auth.dispose);

        await _pumpWiredRouter(tester, auth: auth);

        expect(find.byType(WelcomeCarousel), findsOneWidget);

        await tester.tap(find.byKey(WelcomeCarousel.skipButtonKey));
        await tester.pumpAndSettle();

        // Skip routes to `/sign-in` (carousel does `context.go`) WITHOUT
        // firing onboarding's `complete()` (UIUX_REVIEW). The onboarding
        // gate now lets `/sign-in` through even while incomplete, so the
        // tap reaches sign-in instead of bouncing back to the carousel;
        // the auth gate then holds the user there (still `signedOut`).
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.byType(WelcomeCarousel), findsNothing);
      },
    );

    testWidgets(
      'after onboarding + fake sign-in, lands on / (home tab visible)',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final _RedirectSpyAuth auth = _RedirectSpyAuth();
        addTearDown(auth.dispose);

        final ProviderContainer container = await _pumpWiredRouter(
          tester,
          auth: auth,
        );

        // Walk the carousel to its end so `onboardingCompletedProvider`
        // flips true — this is the same path the carousel test
        // exercises for the welcome flow, here in service of the
        // redirect.
        for (int i = 0; i < WelcomeCarousel.pages.length; i++) {
          await tester.tap(find.byKey(WelcomeCarousel.primaryCtaKey));
          await tester.pumpAndSettle();
        }

        expect(container.read(onboardingCompletedProvider), isTrue);
        expect(find.byType(SignInScreen), findsOneWidget);

        // Fake the OAuth completion — the wired router's
        // refreshListenable will fire and re-evaluate the redirect.
        auth.simulateSignIn();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(TabScaffoldBar), findsOneWidget,
            reason: 'tab bar must be visible once the user lands on /');
      },
    );

    testWidgets(
      'onboarded + signed-in with NO patient lands on /setup, not Home',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final _RedirectSpyAuth auth = _RedirectSpyAuth();
        addTearDown(auth.dispose);

        // Empty store → no client on file → the setup gate must hold
        // the caregiver on the wizard once onboarding + auth pass.
        final InMemoryStorageProvider emptyStore = InMemoryStorageProvider();
        addTearDown(emptyStore.dispose);

        final ProviderContainer container = await _pumpWiredRouter(
          tester,
          auth: auth,
          storage: emptyStore,
        );

        for (int i = 0; i < WelcomeCarousel.pages.length; i++) {
          await tester.tap(find.byKey(WelcomeCarousel.primaryCtaKey));
          await tester.pumpAndSettle();
        }
        expect(container.read(onboardingCompletedProvider), isTrue);

        auth.simulateSignIn();
        await tester.pumpAndSettle();

        // The third gate fires: no patient → the loved-one wizard, not
        // Home.
        expect(find.byType(LovedOneSetupScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'onboarded + signed-in WITH a seeded patient lands on Home (gate '
      'skipped, mirrors DEMO_MODE)',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final _RedirectSpyAuth auth = _RedirectSpyAuth();
        addTearDown(auth.dispose);

        // Default seeded store already holds Mary — the same condition
        // DEMO_MODE produces — so the setup gate is satisfied and the
        // caregiver boots straight to Home, never seeing the wizard.
        final ProviderContainer container = await _pumpWiredRouter(
          tester,
          auth: auth,
        );

        for (int i = 0; i < WelcomeCarousel.pages.length; i++) {
          await tester.tap(find.byKey(WelcomeCarousel.primaryCtaKey));
          await tester.pumpAndSettle();
        }
        expect(container.read(onboardingCompletedProvider), isTrue);

        auth.simulateSignIn();
        await tester.pumpAndSettle();

        expect(find.byType(LovedOneSetupScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}

/// Test [AuthProvider] that lets the test drive the state machine via
/// [simulateSignIn] / [simulateSignOut]. Mirrors the spy pattern used
/// by `test/screens/onboarding/sign_in_screen_test.dart` but tailored
/// to the redirect tests (which don't care about call-count tracking).
class _RedirectSpyAuth implements AuthProvider {
  _RedirectSpyAuth();

  static const User _user = User(
    id: 'redirect-spy-user',
    email: 'spy@carerounds.app',
    name: 'Spy Caregiver',
  );

  AuthState _state = const AuthState.signedOut();
  final StreamController<AuthState> _changes =
      StreamController<AuthState>.broadcast();

  Future<void> dispose() => _changes.close();

  @override
  Stream<AuthState> watchAuthState() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithApple() async => simulateSignIn();

  @override
  Future<void> signInWithGoogle() async => simulateSignIn();

  @override
  Future<void> signOut() async => simulateSignOut();

  @override
  Future<void> deleteAccount() async => simulateSignOut();

  void simulateSignIn() => _emit(const AuthState.signedIn(user: _user));

  void simulateSignOut() => _emit(const AuthState.signedOut());

  void _emit(AuthState next) {
    _state = next;
    if (!_changes.isClosed) _changes.add(next);
  }
}

/// Pump [careroundsRouterProvider] inside a real `MaterialApp.router`
/// with auth overridden to [auth]. Returns the [ProviderContainer] so
/// tests can read [onboardingCompletedProvider] without going through
/// the widget tree.
///
/// [storage] backs the loved-one-setup gate's `getPatient()` probe.
/// Defaults to an in-memory store **already holding a patient**, so the
/// existing onboarding/auth-gate tests sail past the setup gate straight
/// to Home as they did before the gate existed; the setup-gate tests
/// hand in an empty store to exercise the `/setup` redirect.
Future<ProviderContainer> _pumpWiredRouter(
  WidgetTester tester, {
  required _RedirectSpyAuth auth,
  StorageProvider? storage,
}) async {
  final DateTime now = DateTime.utc(2026, 5, 30, 12);
  final StorageProvider store = storage ?? _seededStorage();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authBackendProvider.overrideWithValue(auth),
      storageBackendProvider.overrideWithValue(store),
      // Home tab depends on this; the wired router test never sets up
      // a drift store, so swap a synthetic conversation in.
      homeConversationProvider.overrideWith(
        (_) async => Conversation(
          id: 'wired-conv',
          title: 'Today',
          createdAt: now,
          updatedAt: now,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = container.read(careroundsRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// An in-memory store pre-seeded with a client so the setup gate is
/// already satisfied — the default backing store for the wired-router
/// tests that only care about the onboarding + auth gates.
StorageProvider _seededStorage() {
  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  addTearDown(storage.dispose);
  unawaited(storage.upsertPatient(maryHenderson()));
  return storage;
}
