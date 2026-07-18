import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/care_shift.dart';
import '../../models/caregiver.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/care_shifts_provider.dart';
import '../../providers/my_rounds_provider.dart';
import '../../providers/storage_provider.dart';
import '../../theme.dart';
import '../../widgets/path_header.dart';
import '../../providers/clients_view_provider.dart'
    show LovedOnesView, lovedOnesViewProvider;

/// "My Rounds" (Care Rounds) — the signed-in worker's shifts across EVERY
/// client, grouped by day. Unlike the Shifts coverage board (scoped to the
/// active client), this is scoped to the *caregiver* and spans all clients:
/// a direct-care worker's day of visits (ACL Track 2 use case #1).
///
/// When the device's user hasn't been chosen yet, the body is a one-time
/// "which caregiver are you?" picker; after that it lists the rounds.
class MyRoundsScreen extends ConsumerWidget {
  const MyRoundsScreen({super.key});

  static const String route = '/team/my-rounds';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> self = ref.watch(selfCaregiverIdProvider);
    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PathHeader(
              // Rounds is a top-level tab now — a single crumb renders the
              // title row only (no breadcrumb trail, no Back), same as the
              // other tab roots.
              breadcrumbs: <PathHeaderCrumb>[
                PathHeaderCrumb(label: 'Rounds'),
              ],
              title: 'My Rounds',
              leadingIcon: Icons.route_outlined,
            ),
            // Differentiate from the (single-client) Care › Schedule: Rounds
            // is the worker's whole day ACROSS clients (Track-2 #32).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Your visits across all clients',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.hc.primarySoft,
                    ),
              ),
            ),
            Expanded(
              child: self.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, _) =>
                    Center(child: Text('Couldn\'t load: $e')),
                data: (String? id) => (id == null || id.isEmpty)
                    ? const _SelfPicker(key: MyRoundsScreen.pickerKey)
                    : const _Rounds(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Key pickerKey = Key('my-rounds-self-picker');
  static const Key roundsListKey = Key('my-rounds-list');
}

/// One-time "which caregiver are you?" picker. Persists the choice so every
/// later launch goes straight to the rounds.
class _SelfPicker extends ConsumerWidget {
  const _SelfPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Caregiver>> roster =
        ref.watch(schedulableCaregiversProvider);
    return roster.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Couldn\'t load: $e')),
      data: (List<Caregiver> caregivers) {
        if (caregivers.isEmpty) {
          return const _Empty(
            icon: Icons.group_outlined,
            message: 'Add caregivers to your team first, then pick which one '
                'is you to see your rounds.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Which caregiver are you?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final Caregiver c in caregivers)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.displayName),
                  onTap: () => _choose(ref, c.id),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _choose(WidgetRef ref, String caregiverId) async {
    await ref.read(storageProvider).setSelfCaregiverId(caregiverId);
    ref.invalidate(selfCaregiverIdProvider);
    ref.invalidate(myRoundsProvider);
  }
}

/// The rounds list — my shifts across all clients, grouped by calendar day.
class _Rounds extends ConsumerWidget {
  const _Rounds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CareShift>> rounds = ref.watch(myRoundsProvider);
    final AsyncValue<LovedOnesView> clients =
        ref.watch(lovedOnesViewProvider);

    return rounds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Couldn\'t load: $e')),
      data: (List<CareShift> shifts) {
        if (shifts.isEmpty) {
          return const _Empty(
            icon: Icons.event_available_outlined,
            message: 'No shifts scheduled for you yet. Shifts you\'re assigned '
                'to — across every client — show up here as your rounds.',
          );
        }
        // patientId -> client name, for the row subtitle.
        final Map<String, String> names = <String, String>{
          for (final p in clients.value?.patients ?? const [])
            p.id: p.name,
        };
        final List<_DayGroup> days = _groupByDay(shifts);
        return ListView.builder(
          key: MyRoundsScreen.roundsListKey,
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          itemBuilder: (BuildContext context, int i) {
            final _DayGroup group = days[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 20, bottom: 8),
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(group.day),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.hc.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                for (final CareShift s in group.shifts)
                  _ShiftCard(shift: s, clientName: names[s.patientId]),
              ],
            );
          },
        );
      },
    );
  }
}

class _ShiftCard extends ConsumerWidget {
  const _ShiftCard({required this.shift, required this.clientName});

  final CareShift shift;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final String window =
        '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(shift.start))}'
        ' – ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(shift.end))}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time_outlined),
        title: Text(clientName ?? 'Client'),
        subtitle: Text(
          shift.notes == null || shift.notes!.isEmpty
              ? window
              : '$window · ${shift.notes}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openClient(context, ref, shift.patientId),
      ),
    );
  }

  Future<void> _openClient(
    BuildContext context,
    WidgetRef ref,
    String patientId,
  ) async {
    // Switch the whole app to this client, then land on their dashboard.
    await ref.read(storageProvider).setActivePatientId(patientId);
    ref.invalidate(activePatientProvider);
    ref.invalidate(activePatientIdProvider);
    if (context.mounted) context.go('/');
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: context.hc.primarySoft),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroup {
  _DayGroup(this.day, this.shifts);
  final DateTime day;
  final List<CareShift> shifts;
}

/// Group already-sorted shifts by their local calendar day.
List<_DayGroup> _groupByDay(List<CareShift> shifts) {
  final List<_DayGroup> out = <_DayGroup>[];
  for (final CareShift s in shifts) {
    final DateTime day = DateTime(s.start.year, s.start.month, s.start.day);
    if (out.isNotEmpty && out.last.day == day) {
      out.last.shifts.add(s);
    } else {
      out.add(_DayGroup(day, <CareShift>[s]));
    }
  }
  return out;
}
