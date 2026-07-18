import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/caregiver.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/models/supervisor_flag.dart';
import 'package:carerounds/providers/care_shifts_provider.dart'
    show schedulableCaregiversProvider;
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/providers/supervisor_flags_provider.dart';
import 'package:carerounds/screens/team/flags_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

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

Future<({SupervisorFlagsRepository repo, InMemoryStorageProvider storage})>
    _pump(
  WidgetTester tester, {
  List<SupervisorFlag> seed = const <SupervisorFlag>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // Own + close the DB so the FlagsScreen's live watch stream (subscribed via
  // openSupervisorFlagsProvider) has no dangling drift timer at test end.
  final CareRoundsDatabase db = CareRoundsDatabase(NativeDatabase.memory());
  addTearDown(() async => db.close());
  final SupervisorFlagsRepository repo = SupervisorFlagsRepository(db);
  for (final SupervisorFlag f in seed) {
    await repo.raise(f);
  }
  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  await storage.upsertPatient(_patient('p-mary', 'Mary Henderson'));
  await storage.setSelfCaregiverId('cg-1');

  final GoRouter router = GoRouter(
    initialLocation: FlagsScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: FlagsScreen.route,
        builder: (_, __) => const FlagsScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        supervisorFlagsRepositoryProvider.overrideWithValue(repo),
        storageBackendProvider.overrideWithValue(storage),
        schedulableCaregiversProvider.overrideWith((Ref ref) async =>
            const <Caregiver>[
              Caregiver(id: 'cg-1', displayName: 'Sarah', role: CaregiverRole.aide),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, storage: storage);
}

SupervisorFlag _flag(String id) => SupervisorFlag(
      id: id,
      patientId: 'p-mary',
      raisedByCaregiverId: 'cg-1',
      message: 'Left ankle swelling — please review.',
      createdAt: DateTime.now(),
    );

void main() {
  testWidgets('empty inbox shows the calm empty state', (WidgetTester tester) async {
    await _pump(tester);
    expect(find.byKey(FlagsScreen.emptyKey), findsOneWidget);
    expect(find.byKey(FlagsScreen.listKey), findsNothing);
  });

  testWidgets('an open flag renders with client name + message + resolve',
      (WidgetTester tester) async {
    await _pump(tester, seed: <SupervisorFlag>[_flag('f-1')]);

    expect(find.byKey(FlagsScreen.cardKey('f-1')), findsOneWidget);
    expect(find.text('Mary Henderson'), findsOneWidget);
    expect(find.textContaining('Left ankle swelling'), findsOneWidget);
    expect(find.textContaining('Sarah'), findsOneWidget); // raised by
    expect(find.byKey(FlagsScreen.resolveKey('f-1')), findsOneWidget);
  });

  testWidgets('resolving a flag removes it from the inbox',
      (WidgetTester tester) async {
    final ({SupervisorFlagsRepository repo, InMemoryStorageProvider storage}) p =
        await _pump(tester, seed: <SupervisorFlag>[_flag('f-1')]);

    await tester.tap(find.byKey(FlagsScreen.resolveKey('f-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(FlagsScreen.cardKey('f-1')), findsNothing);
    expect(await p.repo.listOpen(), isEmpty);
  });

  testWidgets('the Raise-a-flag sheet writes a new open flag',
      (WidgetTester tester) async {
    final ({SupervisorFlagsRepository repo, InMemoryStorageProvider storage}) p =
        await _pump(tester);

    await tester.tap(find.byKey(FlagsScreen.raiseFabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FlagsScreen.raiseSheetKey), findsOneWidget);

    await tester.enterText(
        find.byKey(FlagsScreen.raiseFieldKey), 'Client seems more confused.');
    await tester.tap(find.byKey(FlagsScreen.raiseSubmitKey));
    await tester.pumpAndSettle();

    final List<SupervisorFlag> open = await p.repo.listOpen();
    expect(open, hasLength(1));
    expect(open.single.message, 'Client seems more confused.');
  });
}
