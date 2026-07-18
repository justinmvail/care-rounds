import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/care_plan_routine.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/active_patient_provider.dart';
import 'package:carerounds/providers/care_plan_provider.dart';
import 'package:carerounds/providers/care_plan_suggestion_provider.dart';
import 'package:carerounds/providers/care_tasks_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/screens/medical/care_plan_suggest_screen.dart';
import 'package:carerounds/screens/medication/medication_list_screen.dart'
    show MedicationListItem, medicationListProvider;
import 'package:carerounds/services/care_plan_suggestion_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override, Ref;

Patient _patient() => Patient(
      id: 'p-mary',
      name: 'Mary Henderson',
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

Future<CarePlanRepository> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final CareRoundsDatabase db = CareRoundsDatabase(NativeDatabase.memory());
  addTearDown(() async => db.close());
  final CarePlanRepository planRepo = CarePlanRepository(db);
  final CareTasksRepository tasksRepo = CareTasksRepository(db);

  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  await storage.upsertPatient(_patient());

  final GoRouter router = GoRouter(
    initialLocation: CarePlanSuggestScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: CarePlanSuggestScreen.route,
        builder: (_, __) => const CarePlanSuggestScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        storageBackendProvider.overrideWithValue(storage),
        medicationListProvider
            .overrideWith((Ref ref) async => const <MedicationListItem>[]),
        carePlanSuggestionServiceProvider
            .overrideWithValue(const FakeCarePlanSuggestionService()),
        carePlanRepositoryProvider.overrideWithValue(planRepo),
        careTasksRepositoryProvider.overrideWithValue(tasksRepo),
        activePatientIdProvider.overrideWith((Ref ref) async => 'p-mary'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return planRepo;
}

void main() {
  testWidgets('loads a suggested checklist (all pre-checked)',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.byKey(CarePlanSuggestScreen.listKey), findsOneWidget);
    // The fake proposes six tasks.
    expect(find.byKey(CarePlanSuggestScreen.tileKey(0)), findsOneWidget);
    expect(find.byKey(CarePlanSuggestScreen.tileKey(5)), findsOneWidget);
    expect(find.text('Add 6 to routines'), findsOneWidget);
  });

  testWidgets('approving the selected tasks creates routines',
      (WidgetTester tester) async {
    final CarePlanRepository repo = await _pump(tester);

    // Uncheck the first suggestion → 5 remain selected.
    await tester.tap(find.byKey(CarePlanSuggestScreen.tileKey(0)));
    await tester.pumpAndSettle();
    expect(find.text('Add 5 to routines'), findsOneWidget);

    await tester.tap(find.byKey(CarePlanSuggestScreen.addButtonKey));
    await tester.pumpAndSettle();

    final List<CarePlanRoutine> saved = await repo.listAll();
    expect(saved, hasLength(5));
    // The saved routines carry the suggested titles for the active client.
    expect(saved.every((CarePlanRoutine r) => r.patientId == 'p-mary'), isTrue);
    expect(
      saved.map((CarePlanRoutine r) => r.title),
      contains('Encourage fluids through the visit'),
    );
  });
}
