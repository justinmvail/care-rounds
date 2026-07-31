import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/scribe.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/ambient_scribe_provider.dart';
import '../../providers/my_rounds_provider.dart' show selfCaregiverIdProvider;
import '../../theme.dart';
import '../../widgets/path_header.dart';
import 'visit_note_screen.dart';

/// One-slot handover of a finished scribe session's narration to
/// [VisitNoteScreen], so the ambient path feeds the SAME structuring pipeline
/// that has been measured against the deployed model rather than growing a
/// second one.
///
/// A tiny mutable holder behind a plain Provider rather than a state notifier:
/// there is no UI that rebuilds on it (the visit note reads it once in
/// `didChangeDependencies` and clears it), and a test can simply seed it.
class ScribeHandoff {
  String? narration;

  /// Read-and-clear: the handover is single-use, so backing out of the visit
  /// note and returning cannot silently re-fill the field.
  String? take() {
    final String? v = narration;
    narration = null;
    return v;
  }
}

final Provider<ScribeHandoff> scribeHandoffProvider =
    Provider<ScribeHandoff>((Ref ref) => ScribeHandoff());

/// Continuous visit transcription — "the scribe".
///
/// Three phases, in this order and never out of it:
///
/// 1. **Consent.** The worker reads the disclosure aloud and records how the
///    client agreed. There is no way to reach the microphone without this. A
///    silent checkbox would be worse than nothing: ticking a box while the
///    client is told nothing is the precise pattern the 2026 ambient-scribe
///    class actions are built on, so the script is supplied verbatim and what
///    was disclosed is stored with the session.
/// 2. **Listening.** Speech accrues as attributed segments. Stop is always one
///    tap away and always visible.
/// 3. **Review.** The worker says which voice is theirs, reads the transcript,
///    and sends it to the visit note. Nothing is saved anywhere until then.
class AmbientScribeScreen extends ConsumerStatefulWidget {
  const AmbientScribeScreen({super.key});

  static const String route = '/medical/scribe';

  static const Key unavailableKey = Key('scribe-unavailable');
  static const Key disclosureKey = Key('scribe-disclosure');
  static const Key consentMethodKey = Key('scribe-consent-method');
  static const Key startKey = Key('scribe-start');
  static const Key stopKey = Key('scribe-stop');
  static const Key transcriptKey = Key('scribe-transcript');
  static const Key thatsMeKey = Key('scribe-thats-me');
  static const Key useForNoteKey = Key('scribe-use-for-note');
  static const Key discardKey = Key('scribe-discard');

  @override
  ConsumerState<AmbientScribeScreen> createState() =>
      _AmbientScribeScreenState();
}

enum _Phase { consent, listening, review }

class _AmbientScribeScreenState extends ConsumerState<AmbientScribeScreen> {
  _Phase _phase = _Phase.consent;
  ScribeConsentMethod? _method;
  final List<ScribeSegment> _segments = <ScribeSegment>[];
  StreamSubscription<ScribeSegment>? _sub;
  ScribeConsent? _consent;

  /// The engine, captured when the screen builds rather than read in
  /// [dispose]. Reading a provider through `ref` during dispose throws — and
  /// this is the path that RELEASES THE MICROPHONE, so it is the last place
  /// that may fail. Holding the instance makes teardown independent of the
  /// element being alive.
  AmbientScribe? _engine;

  /// The engine, guaranteed non-null once dependencies are available.
  AmbientScribe get _scribe =>
      _engine ?? (_engine = ref.read(ambientScribeProvider))!;

  /// Resolved ONCE. `isAvailable` returns a fresh Future on every call, so
  /// handing it straight to a FutureBuilder inside build() restarted it on
  /// every setState — which meant each incoming segment bounced the screen
  /// back to a spinner and the session was never visible.
  Future<bool>? _availability;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine ??= ref.read(ambientScribeProvider);
    _availability ??= _scribe.isAvailable;
  }

  @override
  void dispose() {
    _sub?.cancel();
    // The microphone must not outlive the screen under any exit path.
    unawaited(_engine?.stop() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _start() async {
    final ScribeConsentMethod? method = _method;
    if (method == null) return;
    final String patientId = ref.read(activePatientProvider).value?.id ?? '';
    final String caregiverId =
        ref.read(selfCaregiverIdProvider).value ?? '';

    _consent = ScribeConsent(
      patientId: patientId,
      method: method,
      disclosedAt: DateTime.now(),
      disclosedByCaregiverId: caregiverId,
      script: scribeDisclosureScript,
    );

    setState(() {
      _phase = _Phase.listening;
      _segments.clear();
    });

    _sub = _scribe.start().listen(
      (ScribeSegment s) {
        if (mounted) setState(() => _segments.add(s));
      },
      onDone: () {
        if (mounted && _phase == _Phase.listening) _finish();
      },
      onError: (Object _) {
        if (mounted && _phase == _Phase.listening) _finish();
      },
    );
  }

  Future<void> _stop() async {
    // Move to review FIRST. The worker tapped Stop; the screen must respond to
    // that immediately and must not sit in "Listening" while teardown
    // completes — cancelling a subscription can take arbitrarily long, and a
    // mic that still looks live is exactly the wrong thing to show.
    if (mounted) _finish();
    final StreamSubscription<ScribeSegment>? sub = _sub;
    _sub = null;
    await _engine?.stop();
    await sub?.cancel();
  }

  void _finish() => setState(() => _phase = _Phase.review);

  /// The worker identifies their own voice. Every segment from that voice
  /// cluster becomes [ScribeSpeaker.worker]; the rest become
  /// [ScribeSpeaker.other]. This is voice SEPARATION — the app never claims to
  /// recognize a named person from their voice.
  void _claimVoice(int? voiceId) {
    setState(() {
      for (int i = 0; i < _segments.length; i++) {
        final ScribeSegment s = _segments[i];
        _segments[i] = s.copyWith(
          speaker: s.voiceId == voiceId
              ? ScribeSpeaker.worker
              : ScribeSpeaker.other,
        );
      }
    });
  }

  void _useForNote() {
    final ScribeConsent? consent = _consent;
    if (consent == null) return;
    final ScribeSession session = ScribeSession(
      patientId: consent.patientId,
      consent: consent,
      startedAt: consent.disclosedAt,
      segments: List<ScribeSegment>.unmodifiable(_segments),
      endedAt: DateTime.now(),
    );
    ref.read(scribeHandoffProvider).narration = session.narration;
    context.go(VisitNoteScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: PathHeader(
                breadcrumbs: <PathHeaderCrumb>[
                  PathHeaderCrumb(label: 'Care', route: '/medical'),
                  PathHeaderCrumb(label: 'Scribe'),
                ],
                title: 'Scribe',
                leadingIcon: Icons.graphic_eq,
              ),
            ),
            Expanded(
              child: FutureBuilder<bool>(
                future: _availability,
                builder: (BuildContext context, AsyncSnapshot<bool> snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.data != true) return const _Unavailable();
                  return switch (_phase) {
                    _Phase.consent => _ConsentView(
                        method: _method,
                        onMethod: (ScribeConsentMethod m) =>
                            setState(() => _method = m),
                        onStart: _start,
                      ),
                    _Phase.listening => _ListeningView(
                        segments: _segments,
                        onStop: _stop,
                      ),
                    _Phase.review => _ReviewView(
                        segments: _segments,
                        onClaimVoice: _claimVoice,
                        onUse: _useForNote,
                        onDiscard: () {
                          // Reached directly from a deep link or a cold start
                          // there is nothing to pop, and Discard must never be
                          // a dead button — fall back to the Care hub.
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/medical');
                          }
                        },
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => Padding(
        key: AmbientScribeScreen.unavailableKey,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Scribe is not set up on this phone',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The scribe transcribes on the phone itself, so it needs its '
              'language files installed before it can listen. You can still '
              'talk the visit through on the visit note.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.hc.primarySoft),
            ),
          ],
        ),
      );
}

class _ConsentView extends StatelessWidget {
  const _ConsentView({
    required this.method,
    required this.onMethod,
    required this.onStart,
  });

  final ScribeConsentMethod? method;
  final ValueChanged<ScribeConsentMethod> onMethod;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text('Ask first', style: tt.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Read this out loud before you start. The scribe listens to the '
          'room, so the person you are with needs to know and needs to be able '
          'to say no.',
          style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft),
        ),
        const SizedBox(height: 14),
        Container(
          key: AmbientScribeScreen.disclosureKey,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.hc.surfaceWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.hc.primarySoft),
          ),
          child: Text(scribeDisclosureScript,
              style: tt.bodyLarge?.copyWith(height: 1.4)),
        ),
        const SizedBox(height: 18),
        Text('What did they say?', style: tt.titleSmall),
        const SizedBox(height: 6),
        Column(
          key: AmbientScribeScreen.consentMethodKey,
          children: <Widget>[
            for (final ScribeConsentMethod m in ScribeConsentMethod.values)
              RadioListTile<ScribeConsentMethod>(
                value: m,
                groupValue: method,
                onChanged: (ScribeConsentMethod? v) {
                  if (v != null) onMethod(v);
                },
                contentPadding: EdgeInsets.zero,
                title: Text(m.label),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: AmbientScribeScreen.startKey,
          // No consent recorded, no microphone. The control is not merely
          // discouraged — it does nothing.
          onPressed: method == null ? null : onStart,
          icon: const Icon(Icons.graphic_eq),
          label: const Text('Start listening'),
          style: FilledButton.styleFrom(
            backgroundColor: context.hc.cta,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Everything stays on this phone. If they change their mind, stop the '
          'scribe and the transcript goes with it.',
          style: tt.bodySmall?.copyWith(color: context.hc.primarySoft),
        ),
      ],
    );
  }
}

class _ListeningView extends StatelessWidget {
  const _ListeningView({required this.segments, required this.onStop});

  final List<ScribeSegment> segments;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: <Widget>[
              Icon(Icons.graphic_eq, size: 18, color: context.hc.cta),
              const SizedBox(width: 8),
              Text('Listening', style: tt.titleMedium),
              const Spacer(),
              Text('${segments.length} so far',
                  style:
                      tt.bodySmall?.copyWith(color: context.hc.primarySoft)),
            ],
          ),
        ),
        Expanded(
          child: segments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Go ahead — talk normally through the visit.',
                    style: tt.bodyMedium
                        ?.copyWith(color: context.hc.primarySoft),
                  ),
                )
              : ListView.builder(
                  key: AmbientScribeScreen.transcriptKey,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: segments.length,
                  itemBuilder: (BuildContext context, int i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(segments[i].text, style: tt.bodyMedium),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            key: AmbientScribeScreen.stopKey,
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop listening'),
            style: FilledButton.styleFrom(
              backgroundColor: context.hc.cta,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.segments,
    required this.onClaimVoice,
    required this.onUse,
    required this.onDiscard,
  });

  final List<ScribeSegment> segments;
  final ValueChanged<int?> onClaimVoice;
  final VoidCallback onUse;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final List<int?> voices =
        segments.map((ScribeSegment s) => s.voiceId).toSet().toList();
    final bool attributed =
        segments.any((ScribeSegment s) => s.speaker == ScribeSpeaker.worker);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text('What was said', style: tt.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Nothing has been saved yet. Check it reads right, then send it to '
          'the visit note.',
          style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft),
        ),
        if (voices.length > 1 && !attributed) ...<Widget>[
          const SizedBox(height: 14),
          Text('Which voice is you?', style: tt.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            key: AmbientScribeScreen.thatsMeKey,
            spacing: 8,
            children: <Widget>[
              for (final int? v in voices)
                OutlinedButton(
                  onPressed: () => onClaimVoice(v),
                  child: Text('Voice ${(v ?? 0) + 1} is me'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (segments.isEmpty)
          Text('Nothing was picked up.',
              style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft))
        else
          Column(
            key: AmbientScribeScreen.transcriptKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ScribeSegment s in segments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.speaker.label,
                          style: tt.labelSmall
                              ?.copyWith(color: context.hc.primarySoft)),
                      Text(s.text, style: tt.bodyMedium),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: AmbientScribeScreen.useForNoteKey,
          onPressed: segments.isEmpty ? null : onUse,
          style: FilledButton.styleFrom(
            backgroundColor: context.hc.cta,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Use this for the visit note'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: AmbientScribeScreen.discardKey,
          onPressed: onDiscard,
          child: const Text('Discard'),
        ),
      ],
    );
  }
}
