import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/care_plan_routine.dart';
import '../../models/medication.dart' show FrequencyKind;
import '../../providers/active_patient_provider.dart';
import '../../providers/care_plan_provider.dart';
import '../../providers/care_plan_suggestion_provider.dart';
import '../../providers/patient_timeline_provider.dart' show invalidatePatientTimeline;
import '../../theme.dart';
import '../../widgets/path_header.dart';
import '../medication/medication_list_screen.dart'
    show MedicationListItem, medicationListProvider;

/// AI-guided care-plan checklist (Track-2 #19). Proposes a checklist of
/// concrete visit tasks grounded in the client's profile + medications; the
/// worker reviews, unchecks anything that doesn't fit, and approves the rest
/// into routines. Nothing is created until the worker taps "Add".
///
/// The model only SUGGESTS in-scope care tasks — no diagnosis, no dosing (the
/// guardrails live in the system prompt).
class CarePlanSuggestScreen extends ConsumerStatefulWidget {
  const CarePlanSuggestScreen({super.key});

  static const String route = '/medical/routines/suggest';

  static const Key loadingKey = Key('care-plan-suggest-loading');
  static const Key listKey = Key('care-plan-suggest-list');
  static const Key emptyKey = Key('care-plan-suggest-empty');
  static const Key retryKey = Key('care-plan-suggest-retry');
  static const Key addButtonKey = Key('care-plan-suggest-add');
  static Key tileKey(int i) => Key('care-plan-suggest-tile-$i');

  @override
  ConsumerState<CarePlanSuggestScreen> createState() =>
      _CarePlanSuggestScreenState();
}

class _CarePlanSuggestScreenState extends ConsumerState<CarePlanSuggestScreen> {
  bool _loading = true;
  bool _failed = false;
  List<String> _tasks = const <String>[];
  final Set<int> _selected = <int>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    List<String> tasks;
    try {
      final patient = await ref.read(activePatientProvider.future);
      final List<MedicationListItem> meds =
          await ref.read(medicationListProvider.future);
      final String context = buildClientCareContext(
        patient,
        <String>[for (final MedicationListItem m in meds) m.medication.name],
      );
      tasks = await ref
          .read(carePlanSuggestionServiceProvider)
          .suggest(clientContext: context);
    } catch (_) {
      tasks = const <String>[];
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = tasks.isEmpty;
      _tasks = tasks;
      _selected
        ..clear()
        ..addAll(List<int>.generate(tasks.length, (int i) => i));
    });
  }

  Future<void> _add() async {
    if (_saving || _selected.isEmpty) return;
    setState(() => _saving = true);
    final String patientId = await ref.read(activePatientIdProvider.future);
    final DateTime now = DateTime.now();
    int n = 0;
    for (final int i in _selected) {
      await ref.read(carePlanProvider.notifier).upsert(CarePlanRoutine(
            id: 'routine-suggest-${now.microsecondsSinceEpoch}-$i',
            patientId: patientId,
            title: _tasks[i],
            body: '',
            scheduledTime: const TimeOfDay(hour: 9, minute: 0),
            frequencyKind: FrequencyKind.daily,
            daysOfWeek: const <int>{},
            startsOn: now,
            subtasks: const <String>[],
          ));
      n += 1;
    }
    invalidatePatientTimeline(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(n == 1
            ? 'Added 1 task to routines.'
            : 'Added $n tasks to routines.'),
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
                  PathHeaderCrumb(label: 'Routines', route: '/medical/routines'),
                  PathHeaderCrumb(label: 'Suggested tasks'),
                ],
                title: 'Suggested tasks',
                backLabel: 'Back to Routines',
                leadingIcon: Icons.checklist_outlined,
              ),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        key: CarePlanSuggestScreen.loadingKey,
        child: CircularProgressIndicator(),
      );
    }
    if (_failed) {
      return Center(
        key: CarePlanSuggestScreen.emptyKey,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Couldn't put together suggestions just now.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.hc.text,
                    ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: CarePlanSuggestScreen.retryKey,
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Suggested from this client’s profile. Uncheck anything that '
            'doesn’t fit, then add the rest to routines.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.hc.primarySoft,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: CarePlanSuggestScreen.listKey,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            itemCount: _tasks.length,
            itemBuilder: (BuildContext context, int i) {
              final bool checked = _selected.contains(i);
              return CheckboxListTile(
                key: CarePlanSuggestScreen.tileKey(i),
                value: checked,
                activeColor: context.hc.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_tasks[i]),
                onChanged: (bool? v) => setState(() {
                  if (v ?? false) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            key: CarePlanSuggestScreen.addButtonKey,
            onPressed: (_selected.isEmpty || _saving) ? null : _add,
            icon: const Icon(Icons.add_task, color: Colors.white),
            label: Text(_selected.length == 1
                ? 'Add 1 to routines'
                : 'Add ${_selected.length} to routines'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.hc.ctaFilled,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ],
    );
  }
}
