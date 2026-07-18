import 'package:alchemist/alchemist.dart';
import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/home_clock_provider.dart';
import 'package:carerounds/providers/my_rounds_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/theme.dart';
import 'package:carerounds/widgets/home/today_visits_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Golden of Home's "Today's visits" card (Track-2 #34): the worker's rounds
/// for today, across clients, leading the dashboard.
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

CareShift _shift(String id, String patientId, int hour) => CareShift(
      id: id,
      caregiverId: 'cg-1',
      start: DateTime(2026, 7, 18, hour),
      end: DateTime(2026, 7, 18, hour + 1),
      patientId: patientId,
    );

Future<Widget> _host() async {
  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  await storage.upsertPatient(_patient('p-mary', 'Mary Henderson'));
  await storage.upsertPatient(_patient('p-frank', 'Frank Albright'));
  await storage.setSelfCaregiverId('cg-1');
  return ProviderScope(
    overrides: <Override>[
      storageBackendProvider.overrideWithValue(storage),
      myRoundsProvider.overrideWith((Ref ref) async => <CareShift>[
            _shift('s-1', 'p-mary', 10),
            _shift('s-2', 'p-frank', 14),
          ]),
      homeClockProvider.overrideWithValue(() => _now),
    ],
    child: SizedBox(
      width: 390,
      height: 300,
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: careroundsColors.background,
          body: const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: TodayVisitsCard(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TodayVisitsCard golden', () {
    goldenTest(
      "today's visits across clients",
      fileName: 'today_visits_card',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'populated',
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
