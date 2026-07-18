import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/care_shift.dart';
import '../../models/patient.dart';
import '../../providers/clients_view_provider.dart'
    show LovedOnesView, lovedOnesViewProvider, switchActivePatient;
import '../../providers/home_clock_provider.dart';
import '../../providers/my_rounds_provider.dart';
import '../../theme.dart';
import '../form/format.dart';

/// The "Today's visits" dashboard card (Track-2 #34) — the first thing a
/// direct-care worker sees on Home: their own rounds for TODAY, across every
/// client, not the single active client's schedule (that's the card below).
///
/// A family caregiver's Home leads with "my one person's day"; a paid worker's
/// Home should lead with "my day of visits." This card answers "where am I due,
/// and for whom" at a glance. Tapping a visit switches the whole app to that
/// client and opens their schedule; the header jumps to the full Rounds tab.
///
/// It renders only once the worker has said which caregiver they are
/// ([selfCaregiverIdProvider]); before that (and on a fresh/empty install) it
/// collapses to nothing, so Home falls back to the client schedule card.
class TodayVisitsCard extends ConsumerWidget {
  const TodayVisitsCard({super.key});

  static const Key cardKey = Key('home-today-visits-card');
  static const Key emptyKey = Key('home-today-visits-empty');
  static const Key viewRoundsKey = Key('home-today-visits-rounds');
  static const Key moreKey = Key('home-today-visits-more');
  static Key rowKey(String shiftId) => Key('home-today-visits-row-$shiftId');

  /// At most this many visits before the rest roll into a "+N more" link.
  static const int _maxRows = 5;
  static const double _radius = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? self = ref.watch(selfCaregiverIdProvider).asData?.value;
    // Not configured yet → no card; Home leads with the client schedule card.
    if (self == null || self.isEmpty) return const SizedBox.shrink();

    final DateTime now = ref.watch(homeClockProvider)();
    final AsyncValue<List<CareShift>> rounds = ref.watch(myRoundsProvider);
    final Map<String, String> names = _clientNames(ref);

    final List<CareShift> today = switch (rounds) {
      AsyncData<List<CareShift>>(:final List<CareShift> value) =>
        _todayVisits(value, now),
      _ => const <CareShift>[],
    };

    return Padding(
      // Own the gap to the schedule card below, so a hidden card leaves no
      // spacer and the empty dashboard stays pixel-stable.
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
      color: context.hc.surfaceWarm,
      borderRadius: BorderRadius.circular(_radius),
      child: Padding(
        key: cardKey,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Header(onTapRounds: () => context.go('/rounds')),
            const SizedBox(height: 12),
            if (today.isEmpty)
              Text(
                'No visits scheduled today.',
                key: emptyKey,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.hc.text,
                    ),
              )
            else
              ..._rows(context, ref, today, names, now),
          ],
        ),
      ),
      ),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    WidgetRef ref,
    List<CareShift> today,
    Map<String, String> names,
    DateTime now,
  ) {
    final List<CareShift> shown = today.take(_maxRows).toList(growable: false);
    final int hidden = today.length - shown.length;
    return <Widget>[
      for (final CareShift s in shown)
        _VisitRow(
          shift: s,
          clientName: names[s.patientId] ?? 'A client',
          now: now,
          onTap: () async {
            await switchActivePatient(ref, s.patientId);
            if (context.mounted) context.push('/medical/schedule');
          },
        ),
      if (hidden > 0)
        InkWell(
          key: moreKey,
          onTap: () => context.go('/rounds'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '+$hidden more in Rounds',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.hc.link,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
    ];
  }

  Map<String, String> _clientNames(WidgetRef ref) {
    final LovedOnesView? view = ref.watch(lovedOnesViewProvider).asData?.value;
    return <String, String>{
      for (final Patient p in view?.patients ?? const <Patient>[]) p.id: p.name,
    };
  }
}

/// Today's shifts (start within the current calendar day), earliest first.
List<CareShift> _todayVisits(List<CareShift> shifts, DateTime now) {
  final DateTime startOfToday = DateTime(now.year, now.month, now.day);
  final DateTime startOfTomorrow = startOfToday.add(const Duration(days: 1));
  final List<CareShift> today = shifts
      .where((CareShift s) =>
          !s.start.isBefore(startOfToday) && s.start.isBefore(startOfTomorrow))
      .toList()
    ..sort((CareShift a, CareShift b) => a.start.compareTo(b.start));
  return today;
}

class _Header extends StatelessWidget {
  const _Header({required this.onTapRounds});

  final VoidCallback onTapRounds;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            "Today's visits",
            style: tt.titleLarge?.copyWith(color: context.hc.primary),
          ),
        ),
        TextButton(
          key: TodayVisitsCard.viewRoundsKey,
          onPressed: onTapRounds,
          style: TextButton.styleFrom(
            foregroundColor: context.hc.link,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Rounds →'),
        ),
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({
    required this.shift,
    required this.clientName,
    required this.now,
    required this.onTap,
  });

  final CareShift shift;
  final String clientName;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final bool past = shift.end.isBefore(now);
    final String window =
        '${formatClock12h(shift.start)} – ${formatClock12h(shift.end)}';
    final Color nameColor = past
        ? context.hc.primary.withValues(alpha: 0.55)
        : context.hc.primary;
    final Color timeColor = past
        ? context.hc.primarySoft.withValues(alpha: 0.55)
        : context.hc.primarySoft;
    return InkWell(
      key: TodayVisitsCard.rowKey(shift.id),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.person_outline, size: 20, color: timeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    window,
                    style: tt.bodyMedium?.copyWith(color: timeColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: context.hc.primarySoft),
          ],
        ),
      ),
    );
  }
}
