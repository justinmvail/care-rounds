import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/care_event.dart';
import 'package:carerounds/providers/active_patient_provider.dart';
import 'package:carerounds/providers/care_events_provider.dart';
import 'package:carerounds/providers/care_plan_provider.dart';
import 'package:carerounds/providers/care_tasks_provider.dart';
import 'package:carerounds/providers/patient_timeline_provider.dart';
import 'package:carerounds/screens/appointment/appointment_list_screen.dart';
import 'package:carerounds/screens/medical/care_plan_routines_screen.dart';
import 'package:carerounds/screens/medical/schedule_screen.dart';
import 'package:carerounds/screens/team/calendar_screen.dart';
import 'package:carerounds/widgets/path_header.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// The Schedule wrapper (Track-2 #32) — one surface with a segmented
/// Calendar / Appointments / Routines control, each hosting the existing
/// screen in `embedded` mode (its own PathHeader suppressed). These tests
/// exercise the wrapper: the single header, the three segments, and body
/// switching. The embedded screens' own behavior is covered by their tests.

final DateTime _now = DateTime(2026, 7, 18, 9, 0);

Future<void> _pump(
  WidgetTester tester,
  CareRoundsDatabase db,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final GoRouter router = GoRouter(
    initialLocation: ScheduleScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: ScheduleScreen.route,
        builder: (BuildContext c, GoRouterState s) => const ScheduleScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // Calendar segment
        careEventsProvider.overrideWith((Ref ref) async => const <CareEvent>[]),
        patientTimelineEventsProvider
            .overrideWith((Ref ref) async => const <CareEvent>[]),
        calendarClockProvider.overrideWithValue(() => _now),
        // Appointments segment
        appointmentListClockProvider.overrideWithValue(() => _now),
        // Routines segment (real in-memory repos, like its own test)
        carePlanRepositoryProvider
            .overrideWithValue(CarePlanRepository(db)),
        careTasksRepositoryProvider
            .overrideWithValue(CareTasksRepository(db)),
        activePatientIdProvider
            .overrideWith((Ref ref) async => 'demo-patient-mary'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CareRoundsDatabase db;
  setUp(() => db = CareRoundsDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('renders one Schedule header + three segments; Calendar default',
      (WidgetTester tester) async {
    await _pump(tester, db);

    // Exactly one page header, titled "Schedule".
    expect(find.byType(PathHeader), findsOneWidget);
    expect(find.text('Schedule'), findsWidgets); // title + crumb

    // The three segment pills.
    expect(find.byKey(ScheduleScreen.segmentKey(ScheduleSegment.calendar)),
        findsOneWidget);
    expect(find.byKey(ScheduleScreen.segmentKey(ScheduleSegment.appointments)),
        findsOneWidget);
    expect(find.byKey(ScheduleScreen.segmentKey(ScheduleSegment.routines)),
        findsOneWidget);

    // Default segment is Calendar — the embedded calendar is mounted, and it
    // does NOT render its own PathHeader (the wrapper owns the one header).
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byType(AppointmentListScreen), findsNothing);
    expect(find.byType(CarePlanRoutinesScreen), findsNothing);
  });

  testWidgets('tapping Appointments swaps the body to the appointments list',
      (WidgetTester tester) async {
    await _pump(tester, db);

    await tester.tap(
        find.byKey(ScheduleScreen.segmentKey(ScheduleSegment.appointments)));
    await tester.pumpAndSettle();

    expect(find.byType(AppointmentListScreen), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
    // Still exactly one header (the wrapper's), not the appointment screen's.
    expect(find.byType(PathHeader), findsOneWidget);
  });

  testWidgets('tapping Routines swaps the body to the routines list',
      (WidgetTester tester) async {
    await _pump(tester, db);

    await tester.tap(
        find.byKey(ScheduleScreen.segmentKey(ScheduleSegment.routines)));
    await tester.pumpAndSettle();

    expect(find.byType(CarePlanRoutinesScreen), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
    // The routines add-FAB (from the embedded screen) is reachable.
    expect(find.byKey(CarePlanRoutinesScreen.addFabKey), findsOneWidget);
    expect(find.byType(PathHeader), findsOneWidget);
  });
}
