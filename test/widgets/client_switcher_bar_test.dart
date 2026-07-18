import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/widgets/client_switcher_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A fake storage pre-seeded with [patients] and [activeId] so the bar's
/// `activePatientProvider` and the sheet's `lovedOnesViewProvider` resolve
/// from one consistent, switchable source.
Future<InMemoryStorageProvider> _storage({
  required List<Patient> patients,
  String? activeId,
}) async {
  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  for (final Patient p in patients) {
    await storage.upsertPatient(p);
  }
  if (activeId != null) await storage.setActivePatientId(activeId);
  return storage;
}

Future<void> _pump(WidgetTester tester, StorageProvider storage) async {
  await tester.binding.setSurfaceSize(const Size(390, 780));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        storageBackendProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(children: <Widget>[ClientSwitcherBar()]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ClientSwitcherBar', () {
    testWidgets('names the active client on the persistent strip',
        (WidgetTester tester) async {
      await _pump(
        tester,
        await _storage(
          patients: <Patient>[
            _patient('p-mary', 'Mary Henderson'),
            _patient('p-frank', 'Frank Albright'),
          ],
          activeId: 'p-mary',
        ),
      );

      expect(find.byKey(ClientSwitcherBar.barKey), findsOneWidget);
      expect(find.text('CURRENT CLIENT'), findsOneWidget);
      expect(find.text('Mary Henderson'), findsOneWidget);
    });

    testWidgets('collapses to nothing when no client is on file',
        (WidgetTester tester) async {
      await _pump(tester, await _storage(patients: <Patient>[]));

      expect(find.byKey(ClientSwitcherBar.barKey), findsNothing);
      expect(find.text('CURRENT CLIENT'), findsNothing);
    });

    testWidgets('tapping opens a sheet listing every client + Add',
        (WidgetTester tester) async {
      await _pump(
        tester,
        await _storage(
          patients: <Patient>[
            _patient('p-mary', 'Mary Henderson'),
            _patient('p-frank', 'Frank Albright'),
          ],
          activeId: 'p-mary',
        ),
      );

      await tester.tap(find.byKey(ClientSwitcherBar.barKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ClientSwitcherBar.sheetKey), findsOneWidget);
      expect(find.byKey(ClientSwitcherBar.sheetRowKey('p-mary')),
          findsOneWidget);
      expect(find.byKey(ClientSwitcherBar.sheetRowKey('p-frank')),
          findsOneWidget);
      expect(find.byKey(ClientSwitcherBar.addKey), findsOneWidget);
    });

    testWidgets('tapping another client re-centres the app and closes the sheet',
        (WidgetTester tester) async {
      await _pump(
        tester,
        await _storage(
          patients: <Patient>[
            _patient('p-mary', 'Mary Henderson'),
            _patient('p-frank', 'Frank Albright'),
          ],
          activeId: 'p-mary',
        ),
      );

      await tester.tap(find.byKey(ClientSwitcherBar.barKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ClientSwitcherBar.sheetRowKey('p-frank')));
      await tester.pumpAndSettle();

      // Sheet dismissed, and the persistent strip now names the new client.
      expect(find.byKey(ClientSwitcherBar.sheetKey), findsNothing);
      expect(find.text('Frank Albright'), findsOneWidget);
      expect(find.text('Mary Henderson'), findsNothing);
    });
  });
}
