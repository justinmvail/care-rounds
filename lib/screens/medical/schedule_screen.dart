import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/path_header.dart';
import '../appointment/appointment_list_screen.dart';
import '../team/calendar_screen.dart';
import 'care_plan_routines_screen.dart';

/// The one **Schedule** surface (Track-2 #32) — the single Care-hub entry for
/// everything time-based about the active client, replacing the three former
/// peer tiles (Schedule / Appointments / Routines).
///
/// A direct-care worker had four overlapping time views competing for the
/// same mental slot: a Schedule calendar, an Appointments list, a Routines
/// list, and the cross-client "My Rounds" tab. This folds the three
/// *client-scoped* ones into a single screen with an in-page segmented
/// control (per the "in-page tabs, not another tile grid" IA invariant);
/// "My Rounds" stays its own tab because it answers a different question —
/// the worker's whole day *across* clients.
///
/// Each segment hosts the existing screen in `embedded` mode (its own
/// PathHeader suppressed; this wrapper supplies the one header) and keeps its
/// own add-FAB. Only the active segment is built, so the two lists' floating
/// action buttons never collide.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.initialSegment = ScheduleSegment.calendar});

  static const String route = '/medical/schedule';

  static Key segmentKey(ScheduleSegment s) => Key('schedule-segment-${s.name}');

  /// Which segment opens first — the Care tile opens [ScheduleSegment.calendar];
  /// a deep link may request another.
  final ScheduleSegment initialSegment;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

/// The three client-scoped time views the Schedule surface consolidates.
enum ScheduleSegment { calendar, appointments, routines }

extension _SegmentLabel on ScheduleSegment {
  String get label => switch (this) {
        ScheduleSegment.calendar => 'Calendar',
        ScheduleSegment.appointments => 'Appointments',
        ScheduleSegment.routines => 'Routines',
      };
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late ScheduleSegment _segment = widget.initialSegment;

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
                  PathHeaderCrumb(label: 'Schedule'),
                ],
                title: 'Schedule',
                backLabel: 'Back to Care',
                leadingIcon: Icons.schedule_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SegmentedControl(
                selected: _segment,
                onChanged: (ScheduleSegment s) =>
                    setState(() => _segment = s),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_segment) {
      case ScheduleSegment.calendar:
        return const CalendarScreen(embedded: true);
      case ScheduleSegment.appointments:
        return const AppointmentListScreen(embedded: true);
      case ScheduleSegment.routines:
        return const CarePlanRoutinesScreen(embedded: true);
    }
  }
}

/// A three-way pill segmented control in the brand palette. The selected
/// segment fills with the primary token (white text, AA); the rest read as
/// quiet outlined pills.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onChanged});

  final ScheduleSegment selected;
  final ValueChanged<ScheduleSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.hc.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          for (final ScheduleSegment s in ScheduleSegment.values)
            Expanded(
              child: _SegmentPill(
                segment: s,
                selected: s == selected,
                onTap: () => onChanged(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final ScheduleSegment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: segment.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? context.hc.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          key: ScheduleScreen.segmentKey(segment),
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              segment.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : context.hc.primary,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
