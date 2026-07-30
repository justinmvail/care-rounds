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

    // Review phase: the AI's proposal arrives as approvable LINES, not prose
    // — one claim per row, each with its own tick box.
    expect(find.byKey(VisitNoteScreen.summaryFieldKey), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);

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

  /// The note used to arrive as four blocks of prose, so "review" was one
  /// undifferentiated approval over everything the model said. As discrete
  /// lines the worker approves each claim on its own — and an untocked line
  /// must never reach the record.
  group('VisitNoteScreen — the review is an approvable checklist', () {
    Future<InMemoryStorageProvider> toReview(WidgetTester tester) async {
      final InMemoryStorageProvider storage = await _pump(
        tester,
        service: const _FixedVisitNoteService(VisitNoteDraft(
          summary: 'Morning visit',
          observations: 'She ate most of breakfast. She seemed steady.',
          tasksDone: <String>['Helped with a shower', 'Gave 8am meds'],
        )),
      );
      await tester.enterText(
          find.byKey(VisitNoteScreen.transcriptFieldKey), 'anything');
      await tester.tap(find.byKey(VisitNoteScreen.generateButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return storage;
    }

    testWidgets('every proposed claim gets its own line, prose included',
        (WidgetTester tester) async {
      await toReview(tester);
      // 2 tasks + 2 observation sentences = 4 approvable lines.
      expect(find.byType(Checkbox), findsNWidgets(4));
      expect(find.text('Helped with a shower'), findsOneWidget);
      // Prose is split on sentence boundaries — a worker cannot approve
      // "she ate well AND seemed steady" as one unit when only half is true.
      expect(find.text('She ate most of breakfast.'), findsOneWidget);
      expect(find.text('She seemed steady.'), findsOneWidget);
    });

    testWidgets('unticking a line keeps it OUT of the saved record',
        (WidgetTester tester) async {
      final InMemoryStorageProvider storage = await toReview(tester);

      // Drop the shower claim — the AI heard it, the worker says no.
      final Finder showerRow = find.ancestor(
        of: find.text('Helped with a shower'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
          of: showerRow.first, matching: find.byType(Checkbox)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(VisitNoteScreen.saveButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final List<JournalEntry> saved = await _entries(storage);
      expect(saved, hasLength(1));
      expect(saved.single.attemptsText, isNot(contains('shower')),
          reason: 'an unticked line must never reach the record');
      expect(saved.single.attemptsText, contains('Gave 8am meds'),
          reason: 'the lines the worker kept still save');
    });

    testWidgets('the worker can add a line the AI missed',
        (WidgetTester tester) async {
      final InMemoryStorageProvider storage = await toReview(tester);

      await tester.tap(find.byKey(const Key('visit-note-add-care')));
      await tester.pumpAndSettle();
      // The new empty row is the last care-group text field.
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'Changed the bed');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(VisitNoteScreen.saveButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final List<JournalEntry> saved = await _entries(storage);
      expect(saved.single.attemptsText, contains('Changed the bed'));
    });

    testWidgets('Save is inert when nothing is ticked',
        (WidgetTester tester) async {
      await toReview(tester);
      for (final Element e in find.byType(Checkbox).evaluate().toList()) {
        await tester.tap(find.byWidget(e.widget));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<FilledButton>(find.byKey(VisitNoteScreen.saveButtonKey))
            .onPressed,
        isNull,
        reason: 'an empty approval is not a note',
      );
    });
  });
}
