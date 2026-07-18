import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/home_clock_provider.dart';
import 'package:carerounds/providers/my_rounds_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/widgets/home/today_visits_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

final DateTime _now = DateTime(2026, 7, 18, 9, 0);

Patient _patient(String id, String name) => Patient(
      id: id,
      name: name,
      age: 78,
      diagnosis: 'Post-stroke',
      diagnosedAt: DateTime.utc(2022, 1, 1),
      medications: const <CrisisMedication>[],
      allergies: const <String>[],
      calms: const <String>[],
      escalates: const <String>[],
      primaryCaregiver: const Contact(name: 'Sam', phone: '555'),
      healthcarePOA: const Contact(name: 'Sam', phone: '555'),
      advanceDirective:
          const AdvanceDirectiveStatus(onFileAt: 'Not on file', dnr: false),
    );

CareShift _shift(String id, String patientId, DateTime start) => CareShift(
      id: id,
      caregiverId: 'cg-1',
      start: start,
      end: start.add(const Duration(hours: 1)),
      patientId: patientId,
    );

/// Storage seeded with two clients; [self] optionally marks this device's
/// caregiver so the card's self-gate resolves.
Future<InMemoryStorageProvider> _storage({String? self}) async {
  final InMemoryStorageProvider s = InMemoryStorageProvider();
  await s.upsertPatient(_patient('p-mary', 'Mary Henderson'));
  await s.upsertPatient(_patient('p-frank', 'Frank Albright'));
  if (self != null) await s.setSelfCaregiverId(self);
  return s;
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required InMemoryStorageProvider storage,
  List<CareShift> rounds = const <CareShift>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 780));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(child: TodayVisitsCard()),
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'medical/schedule',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('SCHEDULE'))),
          ),
          GoRoute(
            path: 'rounds',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('ROUNDS'))),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        storageBackendProvider.overrideWithValue(storage),
        myRoundsProvider.overrideWith((Ref ref) async => rounds),
        homeClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('collapses to nothing until the worker picks who they are',
      (WidgetTester tester) async {
    await _pump(
      tester,
      storage: await _storage(), // no self set
      rounds: <CareShift>[_shift('s-1', 'p-mary', DateTime(2026, 7, 18, 10))],
    );

    expect(find.byKey(TodayVisitsCard.cardKey), findsNothing);
  });

  testWidgets("lists today's visits across clients, earliest first",
      (WidgetTester tester) async {
    await _pump(
      tester,
      storage: await _storage(self: 'cg-1'),
      rounds: <CareShift>[
        _shift('s-late', 'p-frank', DateTime(2026, 7, 18, 14)),
        _shift('s-early', 'p-mary', DateTime(2026, 7, 18, 10)),
        _shift('s-yesterday', 'p-mary', DateTime(2026, 7, 17, 10)),
      ],
    );

    expect(find.byKey(TodayVisitsCard.cardKey), findsOneWidget);
    expect(find.text("Today's visits"), findsOneWidget);
    // Today's two visits render with client names; yesterday's is filtered out.
    expect(find.byKey(TodayVisitsCard.rowKey('s-early')), findsOneWidget);
    expect(find.byKey(TodayVisitsCard.rowKey('s-late')), findsOneWidget);
    expect(find.byKey(TodayVisitsCard.rowKey('s-yesterday')), findsNothing);
    expect(find.text('Mary Henderson'), findsOneWidget);
    expect(find.text('Frank Albright'), findsOneWidget);

    // Earliest first: Mary (10am) sits above Frank (2pm).
    final double maryY =
        tester.getTopLeft(find.byKey(TodayVisitsCard.rowKey('s-early'))).dy;
    final double frankY =
        tester.getTopLeft(find.byKey(TodayVisitsCard.rowKey('s-late'))).dy;
    expect(maryY, lessThan(frankY));
  });

  testWidgets('shows the empty line when the worker has no visits today',
      (WidgetTester tester) async {
    await _pump(
      tester,
      storage: await _storage(self: 'cg-1'),
      rounds: <CareShift>[_shift('s-y', 'p-mary', DateTime(2026, 7, 17, 10))],
    );

    expect(find.byKey(TodayVisitsCard.cardKey), findsOneWidget);
    expect(find.byKey(TodayVisitsCard.emptyKey), findsOneWidget);
    expect(find.text('No visits scheduled today.'), findsOneWidget);
  });

  testWidgets('the next visit gets a "Start visit" action + a Next chip',
      (WidgetTester tester) async {
    // now = 09:00; the 10:00 visit is the next one due.
    await _pump(
      tester,
      storage: await _storage(self: 'cg-1'),
      rounds: <CareShift>[
        _shift('s-early', 'p-mary', DateTime(2026, 7, 18, 10)),
        _shift('s-late', 'p-frank', DateTime(2026, 7, 18, 14)),
      ],
    );

    expect(find.byKey(TodayVisitsCard.startVisitKey('s-early')), findsOneWidget);
    // Only the focus visit gets a Start action.
    expect(find.byKey(TodayVisitsCard.startVisitKey('s-late')), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Now'), findsNothing);
  });

  testWidgets('a visit in progress shows the Now chip',
      (WidgetTester tester) async {
    // now = 09:00 sits inside the 08:30–09:30 shift.
    await _pump(
      tester,
      storage: await _storage(self: 'cg-1'),
      rounds: <CareShift>[
        CareShift(
          id: 's-now',
          caregiverId: 'cg-1',
          start: DateTime(2026, 7, 18, 8, 30),
          end: DateTime(2026, 7, 18, 9, 30),
          patientId: 'p-mary',
        ),
      ],
    );

    expect(find.text('Now'), findsOneWidget);
    expect(find.byKey(TodayVisitsCard.startVisitKey('s-now')), findsOneWidget);
  });

  testWidgets('tapping Start visit switches the active client and opens Schedule',
      (WidgetTester tester) async {
    final InMemoryStorageProvider storage = await _storage(self: 'cg-1');
    await _pump(
      tester,
      storage: storage,
      rounds: <CareShift>[_shift('s-early', 'p-frank', DateTime(2026, 7, 18, 10))],
    );

    await tester.tap(find.byKey(TodayVisitsCard.startVisitKey('s-early')));
    await tester.pumpAndSettle();

    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(await storage.getActivePatientId(), 'p-frank');
  });

  testWidgets('tapping a visit switches the active client and opens Schedule',
      (WidgetTester tester) async {
    final InMemoryStorageProvider storage = await _storage(self: 'cg-1');
    await _pump(
      tester,
      storage: storage,
      rounds: <CareShift>[_shift('s-early', 'p-frank', DateTime(2026, 7, 18, 10))],
    );

    await tester.tap(find.byKey(TodayVisitsCard.rowKey('s-early')));
    await tester.pumpAndSettle();

    // Navigated into the (now Frank-centred) Schedule, and the switch stuck.
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(await storage.getActivePatientId(), 'p-frank');
  });
}
