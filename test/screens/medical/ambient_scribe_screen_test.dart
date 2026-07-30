import 'package:carerounds/models/scribe.dart';
import 'package:carerounds/providers/ambient_scribe_provider.dart';
import 'package:carerounds/screens/medical/ambient_scribe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

ScribeSegment _seg(String text, {int voiceId = 0}) => ScribeSegment(
      text: text,
      speaker: ScribeSpeaker.unknown,
      at: DateTime(2026, 7, 29, 14, 15),
      voiceId: voiceId,
    );

Future<ScribeHandoff> _pump(
  WidgetTester tester, {
  required AmbientScribe scribe,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final ScribeHandoff handoff = ScribeHandoff();
  final GoRouter router = GoRouter(
    initialLocation: AmbientScribeScreen.route,
    routes: <RouteBase>[
      GoRoute(
        path: AmbientScribeScreen.route,
        builder: (_, __) => const AmbientScribeScreen(),
      ),
      // Landing target for the handoff; the real visit note isn't under test.
      GoRoute(
        path: '/medical/visit-note',
        builder: (_, __) => const Scaffold(body: Text('visit note')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ambientScribeProvider.overrideWithValue(scribe),
        scribeHandoffProvider.overrideWithValue(handoff),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return handoff;
}

void main() {
  group('AmbientScribeScreen — consent gates the microphone', () {
    testWidgets('the disclosure script is shown verbatim, and Start is '
        'disabled until consent is recorded', (WidgetTester tester) async {
      final FakeAmbientScribe scribe =
          FakeAmbientScribe(<ScribeSegment>[_seg('hello')]);
      await _pump(tester, scribe: scribe);

      // The words the worker must read are supplied, not improvised.
      expect(find.byKey(AmbientScribeScreen.disclosureKey), findsOneWidget);
      expect(find.textContaining('write up my notes for this visit'),
          findsOneWidget);
      expect(find.textContaining('turn it off any time'), findsOneWidget);

      final Finder start = find.byKey(AmbientScribeScreen.startKey);
      expect(tester.widget<FilledButton>(start).onPressed, isNull,
          reason: 'no consent recorded yet — the control must be inert');

      // Tapping it must not start the engine either.
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(scribe.started, 0);
      expect(find.byKey(AmbientScribeScreen.stopKey), findsNothing);
    });

    testWidgets('recording how the client agreed enables listening',
        (WidgetTester tester) async {
      final FakeAmbientScribe scribe =
          FakeAmbientScribe(<ScribeSegment>[_seg('she ate breakfast')]);
      await _pump(tester, scribe: scribe);

      await tester.tap(find.text(ScribeConsentMethod.spokenByClient.label));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(AmbientScribeScreen.startKey))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(AmbientScribeScreen.startKey));
      await tester.pumpAndSettle();
      expect(scribe.started, 1);
    });

    testWidgets('hides itself entirely when the engine is unavailable',
        (WidgetTester tester) async {
      await _pump(
        tester,
        scribe: FakeAmbientScribe(const <ScribeSegment>[], available: false),
      );
      expect(find.byKey(AmbientScribeScreen.unavailableKey), findsOneWidget);
      expect(find.byKey(AmbientScribeScreen.disclosureKey), findsNothing);
      expect(find.byKey(AmbientScribeScreen.startKey), findsNothing);
    });
  });

  group('AmbientScribeScreen — session and review', () {
    testWidgets('speech accrues, then Stop moves to review',
        (WidgetTester tester) async {
      final FakeAmbientScribe scribe = FakeAmbientScribe(<ScribeSegment>[
        _seg('Morning visit, she ate most of breakfast.'),
        _seg('I helped her shower.'),
      ]);
      await _pump(tester, scribe: scribe);
      await tester.tap(find.text(ScribeConsentMethod.spokenByClient.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.startKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('ate most of breakfast'), findsOneWidget);
      expect(find.textContaining('helped her shower'), findsOneWidget);

      // Stop is how a real visit ends — one tap, always on screen.
      await tester.tap(find.byKey(AmbientScribeScreen.stopKey));
      await tester.pumpAndSettle();
      expect(scribe.stopped, isTrue, reason: 'the microphone must be released');
      expect(find.byKey(AmbientScribeScreen.useForNoteKey), findsOneWidget);
    });

    testWidgets('claiming a voice attributes that voice to the worker and the '
        'rest to others', (WidgetTester tester) async {
      final FakeAmbientScribe scribe = FakeAmbientScribe(<ScribeSegment>[
        _seg('How are you feeling today?', voiceId: 0),
        _seg('My hip is sore.', voiceId: 1),
      ]);
      final ScribeHandoff handoff = await _pump(tester, scribe: scribe);
      await tester.tap(find.text(ScribeConsentMethod.spokenByClient.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.startKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AmbientScribeScreen.stopKey));
      await tester.pumpAndSettle();

      // Two voices, none attributed yet → the chooser appears.
      expect(find.byKey(AmbientScribeScreen.thatsMeKey), findsOneWidget);
      await tester.tap(find.text('Voice 1 is me'));
      await tester.pumpAndSettle();

      expect(find.text(ScribeSpeaker.worker.label), findsOneWidget);
      expect(find.text(ScribeSpeaker.other.label), findsOneWidget);

      await tester.tap(find.byKey(AmbientScribeScreen.useForNoteKey));
      await tester.pumpAndSettle();

      // The worker's line is the note body; the other voice is reported
      // speech, so nothing is dropped but nothing is passed off as the
      // worker's own clinical account.
      expect(handoff.narration, contains('How are you feeling today?'));
      expect(handoff.narration, contains('They said: My hip is sore.'));
    });

    testWidgets('Use is inert when nothing was picked up',
        (WidgetTester tester) async {
      await _pump(tester, scribe: FakeAmbientScribe(const <ScribeSegment>[]));
      await tester.tap(find.text(ScribeConsentMethod.spokenByClient.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.startKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.stopKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing was picked up'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(AmbientScribeScreen.useForNoteKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('discarding leaves nothing behind for the visit note',
        (WidgetTester tester) async {
      final ScribeHandoff handoff = await _pump(
        tester,
        scribe: FakeAmbientScribe(<ScribeSegment>[_seg('something said')]),
      );
      await tester.tap(find.text(ScribeConsentMethod.spokenByClient.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.startKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.stopKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AmbientScribeScreen.discardKey));
      await tester.pumpAndSettle();

      expect(handoff.narration, isNull);
    });
  });

  group('ScribeSession.narration', () {
    test('only the worker speaks in their own voice; others are reported', () {
      final ScribeSession session = ScribeSession(
        patientId: 'p1',
        consent: ScribeConsent(
          patientId: 'p1',
          method: ScribeConsentMethod.spokenByClient,
          disclosedAt: DateTime(2026, 7, 29),
          disclosedByCaregiverId: 'c1',
          script: scribeDisclosureScript,
        ),
        startedAt: DateTime(2026, 7, 29),
        segments: <ScribeSegment>[
          _seg('Gave the 8am meds.').copyWith(speaker: ScribeSpeaker.worker),
          _seg('I slept badly.').copyWith(speaker: ScribeSpeaker.other),
          _seg('   ').copyWith(speaker: ScribeSpeaker.worker),
        ],
      );
      expect(session.narration,
          'Gave the 8am meds. They said: I slept badly.');
      expect(session.hasSpeech, isTrue);
    });

    test('an empty session has no speech and no narration', () {
      final ScribeSession session = ScribeSession(
        patientId: 'p1',
        consent: ScribeConsent(
          patientId: 'p1',
          method: ScribeConsentMethod.agencyFormOnFile,
          disclosedAt: DateTime(2026, 7, 29),
          disclosedByCaregiverId: 'c1',
          script: scribeDisclosureScript,
        ),
        startedAt: DateTime(2026, 7, 29),
      );
      expect(session.hasSpeech, isFalse);
      expect(session.narration, isEmpty);
    });
  });

  group('selectAmbientScribe', () {
    test('is unavailable unless real capture is compiled in', () async {
      expect(selectAmbientScribe(false), isA<UnavailableAmbientScribe>());
      expect(await selectAmbientScribe(false).isAvailable, isFalse);
      expect(
        await const UnavailableAmbientScribe().start().toList(),
        isEmpty,
      );
    });
  });
}
