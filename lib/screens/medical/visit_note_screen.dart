import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/journal_entry.dart';
import '../../models/care_plan_routine.dart';
import '../../models/care_task.dart';
import '../../models/visit_note_draft.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/my_rounds_provider.dart' show selfCaregiverIdProvider;
import '../../providers/storage_provider.dart';
import '../../providers/care_plan_provider.dart' show carePlanRepositoryProvider;
import '../../providers/care_tasks_provider.dart' show careTasksRepositoryProvider;
import '../../providers/visit_note_service_provider.dart';
import '../../providers/voice_capture_provider.dart';
import 'ambient_scribe_screen.dart' show scribeHandoffProvider;
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
/// "Save"). The model only reorganizes what the worker said — the medical
/// guardrails (no diagnosis / no dosing) live in the system prompt.
class VisitNoteScreen extends ConsumerStatefulWidget {
  const VisitNoteScreen({super.key});

  static const String route = '/medical/visit-note';

  static const Key transcriptFieldKey = Key('visit-note-transcript');
  static const Key dictateButtonKey = Key('visit-note-dictate');
  static const Key generateButtonKey = Key('visit-note-generate');
  static const Key summaryFieldKey = Key('visit-note-summary');
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
  /// The AI's proposal, as discrete lines the worker approves one at a time.
  final List<_ReviewItem> _items = <_ReviewItem>[];

  /// The client's REQUIRED items for this visit, loaded before the AI runs so
  /// the checklist exists independently of what anyone remembered to say.
  List<CarePlanRoutine> _planRoutines = const <CarePlanRoutine>[];
  List<String> _openTaskTitles = const <String>[];

  _Phase _phase = _Phase.capture;

  /// A finished scribe session hands its narration over here, so the ambient
  /// path feeds the same structuring pipeline as spoken dictation instead of
  /// growing a parallel one. Consumed once, then cleared, so backing out and
  /// returning doesn't silently re-fill the field.
  bool _tookHandoff = false;
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
    for (final _ReviewItem i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load the plan up front — a failure here must leave the worker with an
    // empty checklist they can still fill in, never a broken screen.
    unawaited(() async {
      try {
        final List<CarePlanRoutine> routines =
            await ref.read(carePlanRepositoryProvider).listAll();
        final List<CareTask> tasks =
            await ref.read(careTasksRepositoryProvider).listTasks();
        if (!mounted) return;
        setState(() {
          _planRoutines = routines;
          _openTaskTitles = <String>[
            for (final CareTask t in tasks)
              if (t.completedAt == null && t.title.trim().isNotEmpty)
                t.title.trim(),
          ];
        });
      } catch (_) {
        // Plan unavailable — the checklist starts empty rather than failing.
      }
    }());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tookHandoff) return;
    final String? handoff = ref.read(scribeHandoffProvider).take();
    if (handoff == null || handoff.trim().isEmpty) return;
    _tookHandoff = true;
    _transcript.text = handoff.trim();
    // The scribe session counts as the first captured part, so the worker can
    // keep adding to it by voice exactly as with hand dictation.
    _segments = 1;
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
      for (final _ReviewItem i in _items) {
        i.dispose();
      }
      _items
        ..clear()
        ..addAll(_itemsFrom(result));
      _needsAttention = result.needsAttention;
      _phase = _Phase.review;
    });
  }

  /// Turn the AI's draft into approvable lines.
  ///
  /// The draft already carries observations as separate entries — the prompt
  /// asks for one line per thing noticed, and [VisitNoteDraft.fromModelJson]
  /// splits an older single-blob reply — because a worker cannot approve "she
  /// ate well and seemed steady and refused her shower" as one unit when only
  /// part of it is true.
  List<_ReviewItem> _itemsFrom(VisitNoteDraft d) {
    final List<_ReviewItem> out = _seedFromPlan();
    for (final String raw in d.tasksDone) {
      final String t = raw.trim();
      if (t.isEmpty) continue;
      // Prefer TICKING an existing plan item over adding a duplicate line.
      final int i = out.indexWhere((_ReviewItem it) =>
          it.source == _Source.plan && _matches(it.text, t));
      if (i >= 0) {
        out[i]
          ..approved = true
          ..source = _Source.ai
          ..evidence = t;
      } else {
        out.add(_ReviewItem(group: _Group.care, text: t));
      }
    }
    for (final String o in d.observations) {
      if (o.trim().isNotEmpty) {
        out.add(_ReviewItem(group: _Group.noticed, text: o.trim()));
      }
    }
    if (d.concern.trim().isNotEmpty) {
      out.add(_ReviewItem(group: _Group.flag, text: d.concern.trim()));
    }
    return out;
  }

  /// Do the AI's phrase and a plan item describe the same job?
  ///
  /// Deliberately conservative: a match needs a shared meaningful word, and the
  /// stop-list keeps "the", "with", "her" from matching everything to
  /// everything. A FALSE check is the dangerous direction — recording that a
  /// required task was done when it was not is a falsified care record — so
  /// when in doubt this returns false and the plan item simply stays unchecked
  /// for the worker to handle.
  static bool _matches(String planTitle, String heard) {
    const Set<String> stop = <String>{
      'the', 'a', 'an', 'and', 'with', 'for', 'her', 'his', 'their', 'to',
      'of', 'in', 'on', 'at', 'gave', 'did', 'done', 'client', 'am', 'pm',
      'help', 'helped',
    };
    Set<String> words(String t) => t
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String w) => w.length > 3 && !stop.contains(w))
        .toSet();
    final Set<String> a = words(planTitle);
    final Set<String> b = words(heard);
    if (a.isEmpty || b.isEmpty) return false;
    return a.intersection(b).isNotEmpty;
  }

  /// Build the visit's checklist: the client's REQUIRED items first, then check
  /// the ones the worker's account covered.
  ///
  /// The list exists before the AI runs. The AI's job is to check boxes and
  /// show the words that justified each check — not to decide what the visit
  /// consisted of.
  List<_ReviewItem> _seedFromPlan() => <_ReviewItem>[
        for (final CarePlanRoutine r in _planRoutines)
          _ReviewItem(
            group: _Group.care,
            text: r.title,
            approved: false,
            source: _Source.plan,
          ),
        for (final String t in _openTaskTitles)
          _ReviewItem(
            group: _Group.care,
            text: t,
            approved: false,
            source: _Source.plan,
          ),
      ];

  List<String> _approved(_Group g) => _items
      .where((_ReviewItem i) => i.group == g && i.approved && i.text.isNotEmpty)
      .map((_ReviewItem i) => i.text)
      .toList();

  Future<void> _save() async {
    final DateTime now = DateTime.now();
    // ONLY checked lines are written. An unchecked line is something the AI
    // heard and the worker rejected — it must not reach the record.
    final List<String> tasks = _approved(_Group.care);
    final String situation = <String>[
      _summary.text.trim(),
      ..._approved(_Group.noticed),
    ].where((String s) => s.isNotEmpty).join('\n\n');
    final String concern = _approved(_Group.flag).join('\n');
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
                      items: _items,
                      needsAttention: _needsAttention,
                      onToggle: (_ReviewItem item, bool v) =>
                          setState(() => item.approved = v),
                      onDelete: (_ReviewItem item) => setState(() {
                        _items.remove(item);
                        item.dispose();
                      }),
                      onAdd: (_Group g) => setState(() => _items.add(
                          _ReviewItem(group: g, text: ''))),
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

/// Which part of the visit an item belongs to. The AI proposes items; the
/// worker decides which are true.
enum _Group { care, noticed, flag }

extension _GroupLabel on _Group {
  String get label => switch (this) {
        _Group.care => 'Care given',
        _Group.noticed => 'What I noticed',
        _Group.flag => 'To pass on',
      };
  String get addLabel => switch (this) {
        _Group.care => 'Add something you did',
        _Group.noticed => 'Add something you noticed',
        _Group.flag => 'Add something to pass on',
      };
}

/// Where a line came from — which decides how it is drawn and what it means
/// when it is left unchecked.
enum _Source {
  /// On the client's care plan: required for this visit whether or not anyone
  /// mentioned it. Left unchecked, it is a VISIBLE OMISSION — which is the
  /// point, because the measured weakness of the model is missing things
  /// (0 invention, 91% capture), and a missing line is otherwise invisible.
  plan,

  /// The AI heard it. Pre-checked, drawn in the AI color, and shown with the
  /// words it heard so the worker can check the basis rather than trust it.
  ai,

  /// The worker added it.
  worker,
}

/// One proposed line of the visit note.
///
/// The note used to arrive as four blocks of prose, which meant "review" was
/// really one undifferentiated approval over everything the model said — a
/// wrong line had to be spotted inside a paragraph and rewritten. As discrete
/// items each one can be kept, corrected, or dropped on its own, and Save
/// approves a list the worker can actually see.
class _ReviewItem {
  _ReviewItem({
    required this.group,
    required String text,
    this.approved = true,
    this.source = _Source.ai,
    this.evidence,
  }) : controller = TextEditingController(text: text);

  final _Group group;
  final TextEditingController controller;
  bool approved;

  /// Provenance, so the worker can see what the app filled in versus what they
  /// did — the app should never be mistaken for the person who was in the room.
  _Source source;

  /// The worker's own words that caused an AI check, shown under the line.
  /// A check the worker cannot check is a check they have to take on faith.
  String? evidence;

  String get text => controller.text.trim();
  void dispose() => controller.dispose();
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.summary,
    required this.items,
    required this.needsAttention,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onSave,
    required this.onBack,
  });

  final TextEditingController summary;
  final List<_ReviewItem> items;
  final bool needsAttention;
  final void Function(_ReviewItem item, bool approved) onToggle;
  final void Function(_ReviewItem item) onDelete;
  final void Function(_Group group) onAdd;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final int approved = items.where((i) => i.approved && i.text.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text(
          'Here is what I heard. Uncheck anything that is not right, fix the '
          'wording, add whatever I missed. Only checked lines are saved.',
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
        _Field(
          label: 'Headline',
          controller: summary,
          fieldKey: VisitNoteScreen.summaryFieldKey,
          minLines: 1,
        ),
        for (final _Group g in _Group.values) ...<Widget>[
          const SizedBox(height: 18),
          Text(g.label.toUpperCase(),
              style: tt.labelSmall?.copyWith(
                  color: context.hc.primarySoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 4),
          for (final _ReviewItem item in items.where((i) => i.group == g))
            _ItemRow(
              item: item,
              onToggle: (bool v) => onToggle(item, v),
              onDelete: () => onDelete(item),
            ),
          TextButton.icon(
            key: Key('visit-note-add-${g.name}'),
            onPressed: () => onAdd(g),
            icon: const Icon(Icons.add, size: 18),
            label: Text(g.addLabel),
            style: TextButton.styleFrom(foregroundColor: context.hc.primary),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: VisitNoteScreen.saveButtonKey,
          onPressed: approved == 0 ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: context.hc.cta,
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(approved == 1
              ? 'Save 1 line to the record'
              : 'Save $approved lines to the record'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: VisitNoteScreen.backToEditKey,
          onPressed: onBack,
          child: const Text('Back to what I said'),
        ),
      ],
    );
  }
}

/// A single approvable line: check to keep, tap the text to correct it, X to
/// drop it. An unchecked line stays visible so the worker can see what the AI
/// heard and chose not to keep — it is simply not written.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final _ReviewItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // AI-filled lines are drawn in the accent color so the worker can see at
    // a glance what the app claimed versus what they set themselves. A check
    // the worker cannot distinguish from their own is a check they will stop
    // reading.
    final bool byAi = item.source == _Source.ai;
    final Color check = byAi ? context.hc.accentDeep : context.hc.cta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Checkbox(
            key: Key('visit-note-check-${item.hashCode}'),
            value: item.approved,
            onChanged: (bool? v) => onToggle(v ?? false),
            activeColor: check,
          ),
          Expanded(
            child: TextField(
              key: Key('visit-note-item-${item.hashCode}'),
              controller: item.controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(
                color: item.approved
                    ? context.hc.text
                    : context.hc.text.withValues(alpha: 0.45),
                decoration:
                    item.approved ? null : TextDecoration.lineThrough,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type what happened',
              ),
            ),
          ),
          IconButton(
            key: Key('visit-note-drop-${item.hashCode}'),
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove this line',
            color: context.hc.primarySoft,
          ),
            ],
          ),
          // The words that caused the check, so the worker checks the basis
          // rather than trusting the app.
          if (byAi && (item.evidence ?? '').isNotEmpty)
            Padding(
              key: Key('visit-note-evidence-${item.hashCode}'),
              padding: const EdgeInsets.only(left: 48, bottom: 6),
              child: Text(
                'you said: "${item.evidence}"',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.hc.accentDeep, fontStyle: FontStyle.italic),
              ),
            ),
          // A required item nobody mentioned. Left plainly unchecked — this is
          // the omission the AI could not have surfaced on its own.
          if (item.source == _Source.plan && !item.approved)
            Padding(
              key: Key('visit-note-missed-${item.hashCode}'),
              padding: const EdgeInsets.only(left: 48, bottom: 6),
              child: Text(
                'on the care plan — not mentioned',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: context.hc.primarySoft),
              ),
            ),
        ],
      ),
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
