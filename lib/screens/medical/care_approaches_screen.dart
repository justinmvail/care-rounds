import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/care_approach.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/care_approaches_provider.dart';
import '../../providers/my_rounds_provider.dart' show selfCaregiverIdProvider;
import '../../theme.dart';
import '../../widgets/path_header.dart';

/// "What worked last time" — the client's shared record of what workers have
/// tried in the hard moments, and whether it helped.
///
/// The dementia problem this exists for: the practical knowledge of how to
/// approach a particular person — warm the towels before a shower, don't argue
/// about her late husband — is worked out by one aide and then lost when that
/// aide leaves. Home care turns over at nearly 75% a year, so it is lost
/// constantly, and the next worker starts from nothing on the hardest part of
/// the job. Keeping it on the CLIENT's own record, visible to everyone on that
/// client's team, is how it survives the turnover.
///
/// Scope discipline: every entry is what a worker did and what happened. The
/// app does not prescribe, rank clinically, or characterize behavior — it
/// remembers, and it puts what has worked in front of the next person.
class CareApproachesScreen extends ConsumerStatefulWidget {
  const CareApproachesScreen({super.key});

  static const String route = '/medical/approaches';

  static const Key listKey = Key('approaches-list');
  static const Key emptyKey = Key('approaches-empty');
  static const Key addButtonKey = Key('approaches-add');
  static const Key situationFieldKey = Key('approaches-situation');
  static const Key triedFieldKey = Key('approaches-tried');
  static const Key outcomeFieldKey = Key('approaches-outcome');
  static const Key saveKey = Key('approaches-save');

  @override
  ConsumerState<CareApproachesScreen> createState() =>
      _CareApproachesScreenState();
}

class _CareApproachesScreenState extends ConsumerState<CareApproachesScreen> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CareApproach>> async =
        ref.watch(clientCareApproachesProvider);

    return Scaffold(
      backgroundColor: context.hc.background,
      floatingActionButton: FloatingActionButton.extended(
        key: CareApproachesScreen.addButtonKey,
        onPressed: _add,
        backgroundColor: context.hc.cta,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add what you tried'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: PathHeader(
                breadcrumbs: <PathHeaderCrumb>[
                  PathHeaderCrumb(label: 'Care', route: '/medical'),
                  PathHeaderCrumb(label: 'What works'),
                ],
                title: 'What works',
                leadingIcon: Icons.lightbulb_outline,
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Couldn't load this client's notes.",
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                data: (List<CareApproach> items) =>
                    items.isEmpty ? const _Empty() : _Grouped(items: items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final _NewApproach? result = await showModalBottomSheet<_NewApproach>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _AddSheet(),
    );
    if (result == null || !mounted) return;

    final String? patientId =
        (await ref.read(activePatientProvider.future))?.id;
    if (patientId == null || !mounted) return;

    await ref.read(careApproachesRepositoryProvider).record(CareApproach(
          id: 'ca-${DateTime.now().microsecondsSinceEpoch}',
          patientId: patientId,
          situation: result.situation,
          tried: result.tried,
          outcome: result.outcome,
          at: DateTime.now(),
          caregiverId: ref.read(selfCaregiverIdProvider).value,
        ));
    ref.invalidate(clientCareApproachesProvider);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      key: CareApproachesScreen.emptyKey,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Nothing noted yet', style: tt.titleMedium),
          const SizedBox(height: 8),
          Text(
            'When something works — or clearly does not — note it here. The '
            'next person visiting this client will see it, including whoever '
            'covers for you.',
            style: tt.bodyMedium?.copyWith(color: context.hc.primarySoft),
          ),
        ],
      ),
    );
  }
}

class _Grouped extends StatelessWidget {
  const _Grouped({required this.items});

  final List<CareApproach> items;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final Map<CareSituation, List<CareApproach>> bySituation =
        <CareSituation, List<CareApproach>>{};
    for (final CareApproach a in items) {
      bySituation.putIfAbsent(a.situation, () => <CareApproach>[]).add(a);
    }
    // What worked first within each situation — a worker reading this mid-visit
    // wants the thing to try, not a diary.
    for (final List<CareApproach> group in bySituation.values) {
      group.sort((CareApproach a, CareApproach b) {
        final int byOutcome = a.outcome.rank.compareTo(b.outcome.rank);
        return byOutcome != 0 ? byOutcome : b.at.compareTo(a.at);
      });
    }
    final List<CareSituation> order = CareSituation.values
        .where((CareSituation s) => bySituation.containsKey(s))
        .toList();

    return ListView.builder(
      key: CareApproachesScreen.listKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: order.length,
      itemBuilder: (BuildContext context, int i) {
        final CareSituation s = order[i];
        final List<CareApproach> group = bySituation[s]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(s.label, style: tt.titleSmall),
              const SizedBox(height: 6),
              for (final CareApproach a in group)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        switch (a.outcome) {
                          ApproachOutcome.worked => Icons.check_circle_outline,
                          ApproachOutcome.partly => Icons.adjust,
                          ApproachOutcome.didNotWork => Icons.do_not_disturb_on_outlined,
                        },
                        size: 16,
                        color: context.hc.primarySoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(a.tried, style: tt.bodyMedium),
                            Text(a.outcome.label,
                                style: tt.labelSmall
                                    ?.copyWith(color: context.hc.primarySoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What the add sheet returns.
class _NewApproach {
  const _NewApproach(this.situation, this.tried, this.outcome);
  final CareSituation situation;
  final String tried;
  final ApproachOutcome outcome;
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  CareSituation _situation = CareSituation.resistedPersonalCare;
  ApproachOutcome _outcome = ApproachOutcome.worked;
  final TextEditingController _tried = TextEditingController();

  @override
  void dispose() {
    _tried.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What happened?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<CareSituation>(
            key: CareApproachesScreen.situationFieldKey,
            initialValue: _situation,
            decoration: const InputDecoration(labelText: 'The situation'),
            items: <DropdownMenuItem<CareSituation>>[
              for (final CareSituation s in CareSituation.values)
                DropdownMenuItem<CareSituation>(
                    value: s, child: Text(s.label)),
            ],
            onChanged: (CareSituation? v) {
              if (v != null) setState(() => _situation = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: CareApproachesScreen.triedFieldKey,
            controller: _tried,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What you tried',
              hintText: 'e.g. warmed the towels first and told her why',
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ApproachOutcome>(
            key: CareApproachesScreen.outcomeFieldKey,
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'How it went'),
            items: <DropdownMenuItem<ApproachOutcome>>[
              for (final ApproachOutcome o in ApproachOutcome.values)
                DropdownMenuItem<ApproachOutcome>(
                    value: o, child: Text(o.label)),
            ],
            onChanged: (ApproachOutcome? v) {
              if (v != null) setState(() => _outcome = v);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: CareApproachesScreen.saveKey,
            onPressed: _tried.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(
                      _NewApproach(_situation, _tried.text.trim(), _outcome),
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: context.hc.cta,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
