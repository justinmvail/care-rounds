import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/models/caregiver.dart';
import 'package:carerounds/providers/care_shifts_provider.dart';
import 'package:carerounds/providers/my_rounds_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/screens/settings/loved_ones_screen.dart';
import 'package:carerounds/screens/team/my_rounds_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

CareShift _shift(String id, DateTime start, {String patient = 'clientA'}) =>
    CareShift(
      id: id,
      caregiverId: 'me',
      start: start,
      end: start.add(const Duration(hours: 2)),
      patientId: patient,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: MyRoundsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no self chosen and no roster, prompts to add caregivers',
      (WidgetTester tester) async {
    await _pump(tester, overrides: <Override>[
      selfCaregiverIdProvider.overrideWith((Ref ref) async => null),
      schedulableCaregiversProvider
          .overrideWith((Ref ref) async => const <Caregiver>[]),
    ]);

    expect(find.byKey(MyRoundsScreen.pickerKey), findsOneWidget);
    expect(find.textContaining('Add caregivers'), findsOneWidget);
  });

  testWidgets('the picker lists the roster and persists the chosen self',
      (WidgetTester tester) async {
    final InMemoryStorageProvider storage = InMemoryStorageProvider();
    await _pump(tester, overrides: <Override>[
      storageProvider.overrideWithValue(storage),
      selfCaregiverIdProvider.overrideWith((Ref ref) async => null),
      schedulableCaregiversProvider.overrideWith(
        (Ref ref) async => const <Caregiver>[
          Caregiver(id: 'c1', displayName: 'Aide One', role: CaregiverRole.aide),
          Caregiver(id: 'c2', displayName: 'Aide Two', role: CaregiverRole.aide),
        ],
      ),
    ]);

    expect(find.text('Which caregiver are you?'), findsOneWidget);
    await tester.tap(find.text('Aide Two'));
    await tester.pumpAndSettle();

    expect(await storage.getSelfCaregiverId(), 'c2');
  });

  testWidgets('with a self chosen but no shifts, shows the empty rounds state',
      (WidgetTester tester) async {
    await _pump(tester, overrides: <Override>[
      selfCaregiverIdProvider.overrideWith((Ref ref) async => 'me'),
      myRoundsProvider.overrideWith((Ref ref) async => const <CareShift>[]),
      lovedOnesViewProvider.overrideWith(
        (Ref ref) async =>
            const LovedOnesView(patients: [], activeId: null),
      ),
    ]);

    expect(find.textContaining('No shifts scheduled'), findsOneWidget);
  });

  testWidgets('with a self chosen and shifts, lists the rounds',
      (WidgetTester tester) async {
    await _pump(tester, overrides: <Override>[
      selfCaregiverIdProvider.overrideWith((Ref ref) async => 'me'),
      myRoundsProvider.overrideWith(
        (Ref ref) async => <CareShift>[
          _shift('s1', DateTime(2026, 6, 1, 8)),
          _shift('s2', DateTime(2026, 6, 1, 13), patient: 'clientB'),
        ],
      ),
      lovedOnesViewProvider.overrideWith(
        (Ref ref) async =>
            const LovedOnesView(patients: [], activeId: null),
      ),
    ]);

    expect(find.byKey(MyRoundsScreen.roundsListKey), findsOneWidget);
    // Two shift cards (client names fall back to "Client" with no roster).
    expect(find.text('Client'), findsNWidgets(2));
  });
}
