import 'package:alchemist/alchemist.dart';
import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/caregiver.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/models/supervisor_flag.dart';
import 'package:carerounds/providers/care_shifts_provider.dart'
    show schedulableCaregiversProvider;
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/providers/supervisor_flags_provider.dart';
import 'package:carerounds/screens/team/flags_screen.dart';
import 'package:carerounds/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Golden of the supervisor escalation inbox (Track-2 #17) — two open flags
/// across clients, each with the client, the message, who raised it, and a
/// resolve action.
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

Future<Widget> _host() async {
  final CareRoundsDatabase db = CareRoundsDatabase(NativeDatabase.memory());
  final SupervisorFlagsRepository repo = SupervisorFlagsRepository(db);
  await repo.raise(SupervisorFlag(
    id: 'f-1',
    patientId: 'p-mary',
    raisedByCaregiverId: 'cg-1',
    message: 'Left ankle looked swollen — please review at the next visit.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ));
  await repo.raise(SupervisorFlag(
    id: 'f-2',
    patientId: 'p-frank',
    raisedByCaregiverId: 'cg-1',
    message: 'Refused morning medications two days running.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
  ));

  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  await storage.upsertPatient(_patient('p-mary', 'Mary Henderson'));
  await storage.upsertPatient(_patient('p-frank', 'Frank Albright'));

  final GoRouter router = GoRouter(
    initialLocation: FlagsScreen.route,
    routes: <RouteBase>[
      GoRoute(path: FlagsScreen.route, builder: (_, __) => const FlagsScreen()),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      supervisorFlagsRepositoryProvider.overrideWithValue(repo),
      storageBackendProvider.overrideWithValue(storage),
      schedulableCaregiversProvider.overrideWith((Ref ref) async =>
          const <Caregiver>[
            Caregiver(id: 'cg-1', displayName: 'Sarah', role: CaregiverRole.aide),
          ]),
    ],
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
  group('FlagsScreen golden', () {
    goldenTest(
      'open escalations inbox',
      fileName: 'flags_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'two open flags',
            child: FutureBuilder<Widget>(
              future: _host(),
              builder: (BuildContext context, AsyncSnapshot<Widget> snap) =>
                  snap.data ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  });
}
