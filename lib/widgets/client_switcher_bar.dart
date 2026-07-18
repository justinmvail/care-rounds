import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../providers/active_patient_provider.dart';
import '../providers/clients_view_provider.dart'
    show LovedOnesView, lovedOnesViewProvider, switchActivePatient,
        lovedOnesAddRoute;
import '../theme.dart';

/// The persistent "who am I working with right now" strip that sits at the
/// top of the four-tab shell, above every screen (Care Rounds, Track 2).
///
/// A direct-care worker carries a caseload of several clients and moves
/// between them through the day; without a constant, unmissable signal of the
/// *selected* client, every screen below (meds, coach grounding, the visit
/// note) is ambiguous — "whose 8am dose is this?". This bar names the active
/// client on every tab and, on tap, opens a switcher sheet so changing who
/// the whole app is centred on is one reach away rather than buried in
/// Settings.
///
/// It renders only once a client is on file (during onboarding, before the
/// first client exists, it collapses to nothing). Switching re-centres the
/// app in place — it invalidates the active-patient providers via
/// [switchActivePatient] and does NOT navigate, so the worker stays on the
/// tab they were on, now showing the newly-selected client.
class ClientSwitcherBar extends ConsumerWidget {
  const ClientSwitcherBar({super.key});

  static const Key barKey = Key('client-switcher-bar');
  static const Key sheetKey = Key('client-switcher-sheet');
  static const Key addKey = Key('client-switcher-add');

  static Key sheetRowKey(String patientId) =>
      Key('client-switcher-row-$patientId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Patient?> active = ref.watch(activePatientProvider);
    final Patient? patient = active.asData?.value;
    // No client yet (fresh install pre-setup, or a load error) → the shell
    // starts at the screen's own header, no empty strip.
    if (patient == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Current client: ${patient.name}. Tap to switch clients.',
      excludeSemantics: true,
      child: Material(
        color: context.hc.surfaceWarm,
        child: InkWell(
          key: barKey,
          onTap: () => _openSwitcher(context),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.hc.primarySoft.withValues(alpha: 0.15),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: <Widget>[
                _Avatar(name: patient.name, radius: 15),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CURRENT CLIENT',
                        style: TextStyle(
                          color: context.hc.primarySoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.hc.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Switch',
                  style: TextStyle(
                    color: context.hc.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.expand_more, color: context.hc.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSwitcher(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.hc.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => const _ClientSwitcherSheet(),
    );
  }
}

/// The switcher sheet: every client the team serves, the active one checked,
/// plus "Add a client". Tapping a client re-centres the app and closes the
/// sheet without navigating away from the current tab.
class _ClientSwitcherSheet extends ConsumerWidget {
  const _ClientSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LovedOnesView> view = ref.watch(lovedOnesViewProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          key: ClientSwitcherBar.sheetKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.hc.primarySoft.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Switch client',
                style: TextStyle(
                  color: context.hc.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: view.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("Couldn't load your clients.\n$e"),
                ),
                data: (LovedOnesView v) => ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final Patient p in v.patients)
                      _SheetRow(patient: p, isActive: p.id == v.activeId),
                    const Divider(height: 8),
                    ListTile(
                      key: ClientSwitcherBar.addKey,
                      leading: Icon(Icons.person_add_alt_1,
                          color: context.hc.primary),
                      title: Text(
                        'Add a client',
                        style: TextStyle(
                          color: context.hc.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(lovedOnesAddRoute);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends ConsumerWidget {
  const _SheetRow({required this.patient, required this.isActive});

  final Patient patient;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String subtitle = <String>[
      if (patient.age > 0) '${patient.age}',
      if (patient.diagnosis.trim().isNotEmpty) patient.diagnosis.trim(),
    ].join(' · ');
    return ListTile(
      key: ClientSwitcherBar.sheetRowKey(patient.id),
      leading: _Avatar(name: patient.name, radius: 18),
      title: Text(
        patient.name,
        style: TextStyle(
          color: context.hc.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              style: TextStyle(color: context.hc.primarySoft)),
      trailing: isActive
          ? Icon(Icons.check_circle, color: context.hc.success)
          : Icon(Icons.radio_button_unchecked, color: context.hc.primarySoft),
      onTap: isActive
          ? null
          : () async {
              await switchActivePatient(ref, patient.id);
              if (context.mounted) Navigator.of(context).pop();
            },
    );
  }
}

/// A small initials avatar shared by the bar and the sheet rows.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.radius});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.hc.primarySoft.withValues(alpha: 0.16),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: context.hc.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Up to two uppercase initials from [name]; `?` for an empty name.
String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
