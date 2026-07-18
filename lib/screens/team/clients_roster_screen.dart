import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/care_circle_membership.dart';
import '../../models/patient.dart';
import '../../providers/circle_memberships_provider.dart';
import '../../theme.dart';
import '../../widgets/path_header.dart';
import '../settings/loved_ones_screen.dart'
    show LovedOnesScreen, LovedOnesView, lovedOnesViewProvider,
        switchActivePatient;

/// The team's roster of clients (Care Rounds) — every client the team cares
/// for, each with how many caregivers are assigned to them, and the active
/// client flagged. Tapping a client switches the whole app to them.
///
/// This is the cross-client face of the Team hub: where the Care Circle
/// (People) lists the caregivers, Clients lists who the team serves. It
/// reuses the loved-ones roster + the caregiver↔client memberships, so it's
/// UI over data that already exists.
class ClientsRosterScreen extends ConsumerWidget {
  const ClientsRosterScreen({super.key});

  static const String route = '/team/clients';
  static const Key listKey = Key('clients-roster-list');
  static const Key addKey = Key('clients-roster-add');
  static const Key emptyKey = Key('clients-roster-empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LovedOnesView> clients =
        ref.watch(lovedOnesViewProvider);
    final AsyncValue<List<CareCircleMembership>> memberships =
        ref.watch(circleMembershipsProvider);

    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PathHeader(
              breadcrumbs: <PathHeaderCrumb>[
                PathHeaderCrumb(label: 'Care', route: '/medical'),
                PathHeaderCrumb(label: 'Team', route: '/team'),
              ],
              title: 'Clients',
            ),
            Expanded(
              child: clients.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, _) =>
                    Center(child: Text('Couldn\'t load: $e')),
                data: (LovedOnesView view) =>
                    _Body(view: view, memberships: memberships),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.view, required this.memberships});

  final LovedOnesView view;
  final AsyncValue<List<CareCircleMembership>> memberships;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view.patients.isEmpty) {
      return Center(
        key: ClientsRosterScreen.emptyKey,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.groups_outlined,
                  size: 48, color: context.hc.primarySoft),
              const SizedBox(height: 16),
              Text(
                'No clients yet. Add the people your team cares for to see '
                'them here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: ClientsRosterScreen.addKey,
                onPressed: () => context.push(LovedOnesScreen.addRoute),
                icon: const Icon(Icons.add),
                label: const Text('Add a client'),
              ),
            ],
          ),
        ),
      );
    }

    // caregiver-assignment count per client.
    final Map<String, int> counts = <String, int>{};
    for (final CareCircleMembership m in memberships.value ?? const []) {
      counts[m.patientId] = (counts[m.patientId] ?? 0) + 1;
    }

    return ListView(
      key: ClientsRosterScreen.listKey,
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final Patient p in view.patients)
          _ClientCard(
            patient: p,
            caregiverCount: counts[p.id] ?? 0,
            isActive: p.id == view.activeId,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: ClientsRosterScreen.addKey,
          onPressed: () => context.push(LovedOnesScreen.addRoute),
          icon: const Icon(Icons.add),
          label: const Text('Add a client'),
        ),
      ],
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({
    required this.patient,
    required this.caregiverCount,
    required this.isActive,
  });

  final Patient patient;
  final int caregiverCount;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String assigned = caregiverCount == 1
        ? '1 caregiver assigned'
        : '$caregiverCount caregivers assigned';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(patient.name),
        subtitle: Text(isActive ? '$assigned · Active' : assigned),
        trailing: Icon(
          isActive ? Icons.check_circle : Icons.chevron_right,
          color: isActive ? context.hc.success : null,
        ),
        onTap: () => _open(context, ref),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await switchActivePatient(ref, patient.id);
    if (context.mounted) context.go('/');
  }
}
