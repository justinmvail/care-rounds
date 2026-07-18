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
  static Key startVisitKey(String shiftId) =>
      Key('home-today-visits-start-$shiftId');

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
    // The visit to steer the worker to: the one in progress, else the next
    // one due today. It gets the highlight + the one-tap "Start visit".
    final int? focus = _focusIndex(shown, now);
    return <Widget>[
      for (int i = 0; i < shown.length; i++)
        _VisitRow(
          shift: shown[i],
          clientName: names[shown[i].patientId] ?? 'A client',
          now: now,
          isFocus: i == focus,
          inProgress: !shown[i].start.isAfter(now) && shown[i].end.isAfter(now),
          onTap: () => _go(context, ref, shown[i].patientId),
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

  /// Switch the whole app to [patientId] and open that client's schedule —
  /// the "start this visit" action, shared by a row tap and the Start button.
  Future<void> _go(BuildContext context, WidgetRef ref, String patientId) async {
    await switchActivePatient(ref, patientId);
    if (context.mounted) context.push('/medical/schedule');
  }

  Map<String, String> _clientNames(WidgetRef ref) {
    final LovedOnesView? view = ref.watch(lovedOnesViewProvider).asData?.value;
    return <String, String>{
      for (final Patient p in view?.patients ?? const <Patient>[]) p.id: p.name,
    };
  }
}

/// Index (within [shown]) of the visit to steer the worker to: the one in
/// progress now, else the next upcoming; null if every visit today is done.
int? _focusIndex(List<CareShift> shown, DateTime now) {
  for (int i = 0; i < shown.length; i++) {
    if (!shown[i].start.isAfter(now) && shown[i].end.isAfter(now)) return i;
  }
  for (int i = 0; i < shown.length; i++) {
    if (shown[i].start.isAfter(now)) return i;
  }
  return null;
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
    this.isFocus = false,
    this.inProgress = false,
  });

  final CareShift shift;
  final String clientName;
  final DateTime now;
  final VoidCallback onTap;

  /// The current/next visit — gets the highlight + the Start button.
  final bool isFocus;

  /// True when the focus visit is happening right now (vs. still upcoming).
  final bool inProgress;

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

    final Widget headline = Row(
      children: <Widget>[
        Icon(Icons.person_outline, size: 20, color: timeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        color: nameColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isFocus) ...<Widget>[
                    const SizedBox(width: 8),
                    _NowChip(inProgress: inProgress),
                  ],
                ],
              ),
              Text(window, style: tt.bodyMedium?.copyWith(color: timeColor)),
            ],
          ),
        ),
        if (!isFocus)
          Icon(Icons.chevron_right, size: 18, color: context.hc.primarySoft),
      ],
    );

    if (!isFocus) {
      return InkWell(
        key: TodayVisitsCard.rowKey(shift.id),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: headline,
        ),
      );
    }

    // Focus visit: a bordered, tappable block with the one-tap Start action.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: context.hc.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: TodayVisitsCard.rowKey(shift.id),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.hc.primary, width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                headline,
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  key: TodayVisitsCard.startVisitKey(shift.id),
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Start visit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.hc.ctaFilled,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "Now" / "Next" pill on the focus visit.
class _NowChip extends StatelessWidget {
  const _NowChip({required this.inProgress});

  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final Color c = inProgress ? context.hc.cta : context.hc.link;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Text(
        inProgress ? 'Now' : 'Next',
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
