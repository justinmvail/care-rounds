import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/journal_entry.dart';
import '../../models/visit_note_draft.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/my_rounds_provider.dart' show selfCaregiverIdProvider;
import '../../providers/storage_provider.dart';
import '../../providers/visit_note_service_provider.dart';
import '../../providers/voice_capture_provider.dart';
import '../team/flags_screen.dart' show raiseSupervisorFlag;
import '../../services/voice_intake.dart' show showVoiceCapturePermissionDeniedSnackBar;
import '../../theme.dart';
import '../../widgets/path_header.dart';

/// Ambient visit documentation (Track-2 #16, the flagship) — "the note that
/// writes itself". The worker talks (or types) a quick account of the visit;
/// the AI structures it into a reviewable visit note; on save it's written
/// to the journal. Nothing is saved until the worker reviews it.
///
/// Two phases in one screen: **capture** (dictate/type the account, then
/// "Write the note") and **review** (edit the structured fields, then
/// "Save"). The model only reorganises what the worker said — the medical
/// guardrails (no diagnosis / no dosing) live in the system prompt.
class VisitNoteScreen extends ConsumerStatefulWidget {
  const VisitNoteScreen({super.key});

  static const String route = '/medical/visit-note';

  static const Key transcriptFieldKey = Key('visit-note-transcript');
  static const Key dictateButtonKey = Key('visit-note-dictate');
  static const Key generateButtonKey = Key('visit-note-generate');
  static const Key summaryFieldKey = Key('visit-note-summary');
  static const Key observationsFieldKey = Key('visit-note-observations');
  static const Key tasksFieldKey = Key('visit-note-tasks');
  static const Key concernFieldKey = Key('visit-note-concern');
  static const Key attentionBannerKey = Key('visit-note-attention');
  static const Key saveButtonKey = Key('visit-note-save');
  static const Key backToEditKey = Key('visit-note-back-to-edit');
  static const Key segmentCountKey = Key('visit-note-segment-count');

  @override
  ConsumerState<VisitNoteScreen> createState() => _VisitNoteScreenState();
}

enum _Phase { capture, review }

class _VisitNoteScreenState extends ConsumerState<VisitNoteScreen> {
  final TextEditingController _transcript = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _observations = TextEditingController();
  final TextEditingController _tasks = TextEditingController();
  final TextEditingController _concern = TextEditingController();

  _Phase _phase = _Phase.capture;
  bool _busy = false;
  bool _listening = false;
  bool _needsAttention = false;

  /// How many separate spoken stretches the worker has added to this account.
  ///
  /// A home-care nurse asked for a mode that keeps listening across a long
  /// session so she can review at the end, instead of having to compose the
  /// whole account in one go from memory. Dictation already APPENDED to the
  /// running transcript — but nothing said so, so there was no reason to
  /// believe a second tap wouldn't overwrite the first. Counting the parts and
  /// naming the action makes the session real to the worker.
  int _segments = 0;

  @override
  void dispose() {
    _transcript.dispose();
    _summary.dispose();
    _observations.dispose();
    _tasks.dispose();
    _concern.dispose();
    super.dispose();
  }

  Future<void> _dictate() async {
    if (_listening) return;
    final String base = _transcript.text.trimRight();
    setState(() => _listening = true);
    String? result;
    try {
      result = await ref.read(voiceCaptureProvider).capture(
        onPartial: (String partial) {
          if (mounted) _transcript.text = _join(base, partial);
        },
      );
    } on VoiceCapturePermissionDeniedException {
      if (mounted) {
        setState(() => _listening = false);
        showVoiceCapturePermissionDeniedSnackBar(context);
      }
      return;
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _listening = false;
      final String said = result?.trim() ?? '';
      _transcript.text = said.isEmpty ? base : _join(base, said);
      if (said.isNotEmpty) _segments++;
    });
  }

  static String _join(String base, String next) =>
      base.isEmpty ? next : '$base $next';

  Future<void> _generate() async {
    final String transcript = _transcript.text.trim();
    if (transcript.isEmpty || _busy) return;
    setState(() => _busy = true);
    VisitNoteDraft? draft;
    try {
      draft = await ref
          .read(visitNoteServiceProvider)
          .structure(transcript: transcript);
    } catch (_) {
      // A structure() that throws must never strand the spinner on-screen.
      draft = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final VisitNoteDraft? result = draft;
    if (result == null || result.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text(
            "Couldn't turn that into a note — add a little more and try again.",
          ),
        ));
      return;
    }
    setState(() {
      _summary.text = result.summary;
      _observations.text = result.observations;
      _tasks.text = result.tasksDone.join('\n');
      _concern.text = result.concern;
      _needsAttention = result.needsAttention;
      _phase = _Phase.review;
    });
  }

  Future<void> _save() async {
    final DateTime now = DateTime.now();
    final List<String> tasks = _tasks.text
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    final String situation = <String>[
      _summary.text.trim(),
      _observations.text.trim(),
    ].where((String s) => s.isNotEmpty).join('\n\n');
    final String concern = _concern.text.trim();
    final String notes = _needsAttention
        ? (concern.isEmpty
            ? '⚠ Flagged to pass on to your supervisor.'
            : '⚠ Flag for supervisor: $concern')
        : concern;

    // The visit note is filed under the active client (Care Rounds).
    final String patientId = await ref.read(activePatientIdProvider.future);
    final JournalEntry entry = JournalEntry.wizard(
      id: 'journal-visit-${now.microsecondsSinceEpoch}',
      createdAt: now,
      patientId: patientId,
      occurredAt: now,
      situationText: situation.isEmpty ? null : situation,
      attemptsText: tasks.isEmpty ? null : tasks.join('\n'),
      notes: notes.isEmpty ? null : notes,
    );
    await ref.read(storageProvider).insertJournalEntry(entry);

    // Human-in-the-loop escalation (#17): when the AI flagged the visit,
    // raise a supervisor flag carrying the concern so it lands in the Team
    // Flags inbox — the note documents, the flag escalates.
    if (_needsAttention) {
      final String self =
          await ref.read(selfCaregiverIdProvider.future) ?? '';
      await raiseSupervisorFlag(
        ref,
        patientId: patientId,
        raisedByCaregiverId: self,
        message: concern.isEmpty ? _summary.text.trim() : concern,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(_needsAttention
            ? 'Visit note saved — and flagged for your supervisor.'
            : 'Visit note saved to the journal.'),
      ));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: PathHeader(
                breadcrumbs: <PathHeaderCrumb>[
                  PathHeaderCrumb(label: 'Home', route: '/'),
                  PathHeaderCrumb(label: 'Care', route: '/medical'),
                  PathHeaderCrumb(label: 'Document visit'),
                ],
                title: 'Document visit',
                backLabel: 'Back to Care',
                leadingIcon: Icons.mic_none_outlined,
              ),
            ),
            Expanded(
              child: _phase == _Phase.capture
                  ? _CaptureView(
                      transcript: _transcript,
                      listening: _listening,
                      busy: _busy,
                      segments: _segments,
                      onDictate: _dictate,
                      onGenerate: _generate,
                    )
                  : _ReviewView(
                      summary: _summary,
                      observations: _observations,
                      tasks: _tasks,
                      concern: _concern,
                      needsAttention: _needsAttention,
                      onSave: _save,
                      onBack: () => setState(() => _phase = _Phase.capture),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView({
    required this.transcript,
    required this.listening,
    required this.busy,
    required this.segments,
    required this.onDictate,
    required this.onGenerate,
  });

  final TextEditingController transcript;
  final bool listening;
  final bool busy;
  final int segments;
  final VoidCallback onDictate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text(
          'Tell me about the visit — talk or type, in as many goes as you '
          'like. Everything you add builds one account, and I turn it into a '
          'note you review before anything saves.',
          style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: VisitNoteScreen.dictateButtonKey,
          onPressed: listening ? null : onDictate,
          icon: Icon(listening ? Icons.mic : Icons.mic_none,
              color: context.hc.primary),
          label: Text(listening
              ? 'Listening…'
              : segments == 0
                  ? 'Talk it through'
                  : 'Add to the account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.hc.primary,
            side: BorderSide(color: context.hc.primarySoft),
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        if (segments > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            key: VisitNoteScreen.segmentCountKey,
            segments == 1
                ? '1 part added — keep going through the visit, then write the '
                    'note when you are done.'
                : '$segments parts added — keep going through the visit, then '
                    'write the note when you are done.',
            style: tt.bodySmall?.copyWith(color: context.hc.primarySoft),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: VisitNoteScreen.transcriptFieldKey,
          controller: transcript,
          minLines: 6,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. Morning visit with Mrs. Henderson. She ate most of '
                'breakfast, seemed steady, I helped her shower and gave her 8am '
                'meds. Left ankle looked a bit swollen.',
            filled: true,
            fillColor: context.hc.surfaceWarm,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          key: VisitNoteScreen.generateButtonKey,
          onPressed: busy ? null : onGenerate,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome, color: Colors.white),
          label: Text(busy ? 'Writing the note…' : 'Write the note'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.hc.ctaFilled,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.summary,
    required this.observations,
    required this.tasks,
    required this.concern,
    required this.needsAttention,
    required this.onSave,
    required this.onBack,
  });

  final TextEditingController summary;
  final TextEditingController observations;
  final TextEditingController tasks;
  final TextEditingController concern;
  final bool needsAttention;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text(
          'Review and fix anything, then save. Only what you see here is '
          'written.',
          style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft),
        ),
        if (needsAttention) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            key: VisitNoteScreen.attentionBannerKey,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.hc.cta.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.hc.cta),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.flag_outlined, color: context.hc.accentDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Flagged to pass on to your supervisor.',
                    style: tt.bodyMedium?.copyWith(
                      color: context.hc.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Field(label: 'Summary', controller: summary,
            fieldKey: VisitNoteScreen.summaryFieldKey, minLines: 1),
        const SizedBox(height: 16),
        _Field(label: 'What happened', controller: observations,
            fieldKey: VisitNoteScreen.observationsFieldKey, minLines: 3),
        const SizedBox(height: 16),
        _Field(label: 'Care given (one per line)', controller: tasks,
            fieldKey: VisitNoteScreen.tasksFieldKey, minLines: 3),
        const SizedBox(height: 16),
        _Field(label: 'Anything to flag', controller: concern,
            fieldKey: VisitNoteScreen.concernFieldKey, minLines: 2),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          key: VisitNoteScreen.saveButtonKey,
          onPressed: onSave,
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text('Save visit note'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.hc.ctaFilled,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: VisitNoteScreen.backToEditKey,
          onPressed: onBack,
          style: TextButton.styleFrom(foregroundColor: context.hc.primary),
          child: const Text('Back to what I said'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.fieldKey,
    required this.minLines,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: context.hc.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          minLines: minLines,
          maxLines: minLines + 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.hc.surfaceWarm,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
