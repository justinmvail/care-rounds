import 'package:alchemist/alchemist.dart';
import 'package:carerounds/models/care_circle_membership.dart';
import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/circle_memberships_provider.dart';
import 'package:carerounds/screens/settings/loved_ones_screen.dart';
import 'package:carerounds/screens/team/clients_roster_screen.dart';
import 'package:carerounds/theme.dart';
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

CareCircleMembership _m(String id, String caregiver, String patient) =>
    CareCircleMembership(
      id: id,
      caregiverId: caregiver,
      patientId: patient,
      permissionLevel: PermissionLevel.editor,
      invitedAt: DateTime.utc(2026, 5, 1),
      acceptedAt: DateTime.utc(2026, 5, 2),
    );

/// Golden of the Team hub's Clients roster (Care Rounds): the team's clients,
/// each with its assigned-caregiver count and the active client flagged. No
/// theme passed (see the other team goldens); `context.hc` falls back to the
/// default brand palette.
void main() {
  group('ClientsRosterScreen golden', () {
    goldenTest(
      'renders the team clients roster with assignment counts',
      fileName: 'clients_roster_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'clients roster — counts + active flag',
            child: SizedBox(
              width: 420,
              height: 820,
              child: ProviderScope(
                overrides: <Override>[
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
                      _m('m1', 'c1', 'p-mary'),
                      _m('m2', 'c2', 'p-mary'),
                      _m('m3', 'c1', 'p-frank'),
                    ],
                  ),
                ],
                child: MaterialApp(
                  builder: (BuildContext context, Widget? child) => ColoredBox(
                    color: careroundsColors.background,
                    child: child,
                  ),
                  home: const ClientsRosterScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}
