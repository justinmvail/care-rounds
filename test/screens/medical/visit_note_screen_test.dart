import 'package:carerounds/models/journal_entry.dart';
import 'package:carerounds/models/visit_note_draft.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/providers/visit_note_service_provider.dart';
import 'package:carerounds/screens/medical/visit_note_screen.dart';
import 'package:carerounds/services/visit_note_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// A fake that returns a caller-supplied draft, so a test can drive the
/// review phase (including the supervisor-flag banner) deterministically.
class _FixedVisitNoteService implements VisitNoteService {
  const _FixedVisitNoteService(this.draft);
  final VisitNoteDraft draft;
  @override
  Future<VisitNoteDraft?> structure({required String transcript}) async =>
      transcript.trim().isEmpty ? null : draft;
}

Future<InMemoryStorageProvider> _pump(
  WidgetTester tester, {
  VisitNoteService service = const FakeVisitNoteService(),
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  final GoRouter router = GoRouter(
    initialLocation: VisitNoteScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: VisitNoteScreen.route,
        builder: (_, __) => const VisitNoteScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      // Always inject the fake explicitly: the default provider builds the
      // real shim service under the test harness (FLUTTER_TEST isn't an OS
      // env var here), which would block on Dio.
      overrides: <Override>[
        storageBackendProvider.overrideWithValue(storage),
        visitNoteServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

Future<List<JournalEntry>> _entries(InMemoryStorageProvider s) =>
    s.listAllJournalEntries();

void main() {
  testWidgets('type → Write the note → review → Save writes a journal entry',
      (WidgetTester tester) async {
    // Default service under flutter test is FakeVisitNoteService.
    final InMemoryStorageProvider storage = await _pump(tester);

    await tester.enterText(
      find.byKey(VisitNoteScreen.transcriptFieldKey),
      'Morning visit, she was steady, gave meds and helped with a shower.',
    );
    await tester.tap(find.byKey(VisitNoteScreen.generateButtonKey));
    await tester.pump(); // show the busy spinner
    await tester.pump(const Duration(milliseconds: 50)); // fake resolves → review

    // Review phase: the structured fields are populated + editable.
    expect(find.byKey(VisitNoteScreen.summaryFieldKey), findsOneWidget);
    expect(find.byKey(VisitNoteScreen.tasksFieldKey), findsOneWidget);

    await tester.tap(find.byKey(VisitNoteScreen.saveButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final List<JournalEntry> saved = await _entries(storage);
    expect(saved, hasLength(1));
    // The visit maps onto the journal's situation / attempts / notes fields.
    expect(saved.single.situationText, contains('Morning visit'));
    expect(saved.single.attemptsText, contains('Gave 8:00 AM medications'));
  });

  testWidgets('a needs-attention note shows the supervisor flag + saves it',
      (WidgetTester tester) async {
    final InMemoryStorageProvider storage = await _pump(
      tester,
      service: const _FixedVisitNoteService(VisitNoteDraft(
        summary: 'She had a fall',
        observations: 'Slipped in the bathroom, no visible injury.',
        tasksDone: <String>['checked for injury'],
        concern: 'Fall in the bathroom around 9am.',
        needsAttention: true,
      )),
    );

    await tester.enterText(
      find.byKey(VisitNoteScreen.transcriptFieldKey),
      'she slipped in the bathroom this morning',
    );
    await tester.tap(find.byKey(VisitNoteScreen.generateButtonKey));
    await tester.pump(); // show the busy spinner
    await tester.pump(const Duration(milliseconds: 50)); // fake resolves → review

    // The supervisor-flag banner shows in review.
    expect(find.byKey(VisitNoteScreen.attentionBannerKey), findsOneWidget);

    await tester.tap(find.byKey(VisitNoteScreen.saveButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final List<JournalEntry> saved = await _entries(storage);
    expect(saved, hasLength(1));
    // The flag rides along in the saved note so the supervisor sees it.
    expect(saved.single.notes, contains('Flag for supervisor'));
  });

  testWidgets('an empty transcript cannot be turned into a note',
      (WidgetTester tester) async {
    final InMemoryStorageProvider storage = await _pump(tester);

    // Generate with nothing typed → stays on capture, no review fields.
    await tester.tap(find.byKey(VisitNoteScreen.generateButtonKey));
    await tester.pump(); // show the busy spinner
    await tester.pump(const Duration(milliseconds: 50)); // fake resolves → review

    expect(find.byKey(VisitNoteScreen.summaryFieldKey), findsNothing);
    expect(await _entries(storage), isEmpty);
  });
}
