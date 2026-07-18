import 'package:carerounds/models/care_circle_membership.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/circle_memberships_provider.dart';
import 'package:carerounds/providers/clients_view_provider.dart';
import 'package:carerounds/screens/team/clients_roster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

Patient _patient(String id, String name) => Patient(
      id: id,
      name: name,
      age: 78,
      diagnosis: "Alzheimer's disease",
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

CareCircleMembership _membership(String id, String caregiverId, String patient) =>
    CareCircleMembership(
      id: id,
      caregiverId: caregiverId,
      patientId: patient,
      permissionLevel: PermissionLevel.editor,
      invitedAt: DateTime.utc(2026, 5, 1),
      acceptedAt: DateTime.utc(2026, 5, 2),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.binding.setSurfaceSize(const Size(440, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: ClientsRosterScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each client with its assigned-caregiver count',
      (WidgetTester tester) async {
    await _pump(tester, overrides: <Override>[
      lovedOnesViewProvider.overrideWith(
        (Ref ref) async => LovedOnesView(
          patients: <Patient>[
            _patient('p-mary', 'Mary Henderson'),
            _patient('p-frank', 'Frank Albright'),
          ],
          activeId: 'p-mary',
        ),
      ),
      circleMembershipsProvider.overrideWith(
        (Ref ref) async => <CareCircleMembership>[
          _membership('m1', 'c1', 'p-mary'),
          _membership('m2', 'c2', 'p-mary'),
          _membership('m3', 'c1', 'p-frank'),
        ],
      ),
    ]);

    expect(find.byKey(ClientsRosterScreen.listKey), findsOneWidget);
    expect(find.text('Mary Henderson'), findsOneWidget);
    expect(find.text('Frank Albright'), findsOneWidget);
    // Mary has two caregivers and is the active client; Frank has one.
    expect(find.text('2 caregivers assigned · Active'), findsOneWidget);
    expect(find.text('1 caregiver assigned'), findsOneWidget);
  });

  testWidgets('shows the empty state when the team has no clients',
      (WidgetTester tester) async {
    await _pump(tester, overrides: <Override>[
      lovedOnesViewProvider.overrideWith(
        (Ref ref) async =>
            const LovedOnesView(patients: <Patient>[], activeId: null),
      ),
      circleMembershipsProvider
          .overrideWith((Ref ref) async => const <CareCircleMembership>[]),
    ]);

    expect(find.byKey(ClientsRosterScreen.emptyKey), findsOneWidget);
    expect(find.textContaining('No clients yet'), findsOneWidget);
  });
}
