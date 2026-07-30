import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/journal_entry.dart';
import 'package:carerounds/models/visit_note_draft.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/providers/supervisor_flags_provider.dart';
import 'package:carerounds/providers/visit_note_service_provider.dart';
import 'package:carerounds/providers/voice_capture_provider.dart';
import 'package:carerounds/screens/medical/visit_note_screen.dart';
import 'package:carerounds/services/visit_note_service.dart';
import 'package:drift/native.dart';
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

/// Returns each scripted utterance in turn, so a test can dictate more than
/// once and assert the parts accumulate. The default capture in tests is
/// [UnavailableVoiceCapture], which yields null.
class _ScriptedVoice implements VoiceCapture {
  _ScriptedVoice(this.utterances);
  final List<String> utterances;
  int calls = 0;

  @override
  Future<String?> capture({void Function(String partial)? onPartial}) async {
    if (calls >= utterances.length) return null;
    return utterances[calls++];
  }
}

Future<InMemoryStorageProvider> _pump(
  WidgetTester tester, {
  VisitNoteService service = const FakeVisitNoteService(),
  VoiceCapture? voice,
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
        // Save auto-raises a supervisor flag on a needs-attention note (#17);
        // pin the flags repo to an in-memory DB so it never opens on-device
        // sqlite.
        supervisorFlagsRepositoryProvider.overrideWithValue(
          SupervisorFlagsRepository(CareRoundsDatabase(NativeDatabase.memory())),
        ),
        if (voice != null) voiceCaptureProvider.overrideWithValue(voice),
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

  /// A home-care nurse asked for a mode that keeps listening across a longer
  /// session so she can review at the end, rather than composing the whole
  /// account in one go from memory. Dictation already appended to the running
  /// transcript, but nothing told the worker that — so a second tap looked like
  /// it would overwrite the first. These pin the session being VISIBLE.
  group('VisitNoteScreen — multi-part capture across a visit', () {
    testWidgets('a second dictation ADDS to the account instead of replacing it',
        (WidgetTester tester) async {
      final _ScriptedVoice voice = _ScriptedVoice(<String>[
        'Morning visit, she ate most of breakfast.',
        'She was steady on her feet during the shower.',
      ]);
      await _pump(tester, voice: voice);

      await tester.tap(find.byKey(VisitNoteScreen.dictateButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VisitNoteScreen.dictateButtonKey));
      await tester.pumpAndSettle();

      expect(voice.calls, 2);
      final TextField field = tester
          .widget<TextField>(find.byKey(VisitNoteScreen.transcriptFieldKey));
      final String text = field.controller!.text;
      expect(text, contains('ate most of breakfast'));
      expect(text, contains('steady on her feet'),
          reason: 'the second part must not overwrite the first');
    });

    testWidgets('the running part count appears once something is captured',
        (WidgetTester tester) async {
      final _ScriptedVoice voice = _ScriptedVoice(<String>[
        'First part.',
        'Second part.',
      ]);
      await _pump(tester, voice: voice);

      // Nothing captured yet — no count, and the button invites a first go.
      expect(find.byKey(VisitNoteScreen.segmentCountKey), findsNothing);
      expect(find.text('Talk it through'), findsOneWidget);

      await tester.tap(find.byKey(VisitNoteScreen.dictateButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VisitNoteScreen.segmentCountKey), findsOneWidget);
      expect(find.textContaining('1 part added'), findsOneWidget);
      // The label now says the next tap ADDS, which is the whole point.
      expect(find.text('Add to the account'), findsOneWidget);

      await tester.tap(find.byKey(VisitNoteScreen.dictateButtonKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 parts added'), findsOneWidget);
    });

    testWidgets('a silent capture does not count as a part',
        (WidgetTester tester) async {
      // UnavailableVoiceCapture-style outcome: the mic yielded nothing.
      await _pump(tester, voice: _ScriptedVoice(<String>['   ']));

      await tester.tap(find.byKey(VisitNoteScreen.dictateButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(VisitNoteScreen.segmentCountKey), findsNothing,
          reason: 'an empty result must not claim a captured part');
    });
  });
}
