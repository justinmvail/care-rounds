import 'package:alchemist/alchemist.dart';
import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/care_event.dart';
import 'package:carerounds/models/caregiver.dart' show Caregiver;
import 'package:carerounds/providers/active_patient_provider.dart';
import 'package:carerounds/providers/care_events_provider.dart';
import 'package:carerounds/providers/care_plan_provider.dart';
import 'package:carerounds/providers/care_tasks_provider.dart';
import 'package:carerounds/providers/patient_timeline_provider.dart';
import 'package:carerounds/screens/appointment/appointment_list_screen.dart'
    show appointmentListClockProvider;
import 'package:carerounds/screens/medical/schedule_screen.dart';
import 'package:carerounds/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Golden of the consolidated Schedule surface (Track-2 #32): one header +
/// the Calendar / Appointments / Routines segmented control, opened on the
/// default Calendar segment with an empty schedule. Pins the wrapper chrome
/// (the novel bit); the embedded screens have their own goldens.
final DateTime _now = DateTime(2026, 7, 18, 9, 0);

Widget _host() {
  final CareRoundsDatabase db = CareRoundsDatabase(NativeDatabase.memory());
  final GoRouter router = GoRouter(
    initialLocation: ScheduleScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: ScheduleScreen.route,
        builder: (BuildContext c, GoRouterState s) => const ScheduleScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      careEventsProvider.overrideWith((Ref ref) async => const <CareEvent>[]),
      patientTimelineEventsProvider
          .overrideWith((Ref ref) async => const <CareEvent>[]),
      assignableCaregiversProvider
          .overrideWith((Ref ref) async => const <Caregiver>[]),
      calendarClockProvider.overrideWithValue(() => _now),
      appointmentListClockProvider.overrideWithValue(() => _now),
      carePlanRepositoryProvider.overrideWithValue(CarePlanRepository(db)),
      careTasksRepositoryProvider.overrideWithValue(CareTasksRepository(db)),
      activePatientIdProvider
          .overrideWith((Ref ref) async => 'demo-patient-mary'),
    ],
    child: SizedBox(
      width: 420,
      height: 900,
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
  group('ScheduleScreen golden', () {
    goldenTest(
      'segmented Schedule surface — Calendar segment, empty',
      fileName: 'schedule_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(name: 'calendar segment', child: _host()),
        ],
      ),
    );
  });
}
