import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/caregiver.dart';
import '../../models/patient.dart';
import '../../models/supervisor_flag.dart';
import '../../providers/active_patient_provider.dart';
import '../../providers/care_shifts_provider.dart' show schedulableCaregiversProvider;
import '../../providers/clients_view_provider.dart'
    show LovedOnesView, lovedOnesViewProvider;
import '../../providers/my_rounds_provider.dart' show selfCaregiverIdProvider;
import '../../providers/supervisor_flags_provider.dart';
import '../../theme.dart';
import '../../widgets/path_header.dart';

/// The supervisor escalation inbox (Track-2 #17) — every OPEN flag across
/// clients, newest first. Flags arrive here two ways: the flagship's ambient
/// visit note raises one when the AI marks a visit `needs_attention`, and a
/// worker can raise one directly from here. A flag stays open until a
/// supervisor resolves it — a human decision, never automatic.
class FlagsScreen extends ConsumerWidget {
  const FlagsScreen({super.key});

  static const String route = '/team/flags';
  static const Key listKey = Key('flags-list');
  static const Key emptyKey = Key('flags-empty');
  static const Key raiseFabKey = Key('flags-raise-fab');
  static const Key raiseSheetKey = Key('flags-raise-sheet');
  static const Key raiseFieldKey = Key('flags-raise-field');
  static const Key raiseSubmitKey = Key('flags-raise-submit');
  static Key cardKey(String id) => Key('flags-card-$id');
  static Key resolveKey(String id) => Key('flags-resolve-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SupervisorFlag>> flags =
        ref.watch(openSupervisorFlagsProvider);
    final Map<String, String> clientNames = _clientNames(ref);
    final Map<String, String> caregiverNames = _caregiverNames(ref);

    return Scaffold(
      backgroundColor: context.hc.background,
      floatingActionButton: FloatingActionButton.extended(
        key: raiseFabKey,
        heroTag: 'flags-raise-fab',
        backgroundColor: context.hc.ctaFilled,
        foregroundColor: Colors.white,
        onPressed: () => _openRaiseSheet(context, ref),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Raise a flag'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PathHeader(
              breadcrumbs: <PathHeaderCrumb>[
                PathHeaderCrumb(label: 'Care', route: '/medical'),
                PathHeaderCrumb(label: 'Team', route: '/team'),
                PathHeaderCrumb(label: 'Flags'),
              ],
              title: 'Flags',
            ),
            Expanded(
              child: flags.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, _) =>
                    Center(child: Text("Couldn't load flags: $e")),
                data: (List<SupervisorFlag> open) => open.isEmpty
                    ? const _Empty()
                    : _List(
                        flags: open,
                        clientNames: clientNames,
                        caregiverNames: caregiverNames,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _clientNames(WidgetRef ref) {
    final LovedOnesView? v = ref.watch(lovedOnesViewProvider).asData?.value;
    return <String, String>{
      for (final Patient p in v?.patients ?? const <Patient>[]) p.id: p.name,
    };
  }

  Map<String, String> _caregiverNames(WidgetRef ref) {
    final List<Caregiver> roster =
        ref.watch(schedulableCaregiversProvider).asData?.value ??
            const <Caregiver>[];
    return <String, String>{for (final Caregiver c in roster) c.id: c.displayName};
  }

  Future<void> _openRaiseSheet(BuildContext context, WidgetRef ref) async {
    final String? patientId =
        await ref.read(activePatientIdProvider.future);
    if (patientId == null || !context.mounted) return;
    final String? self = await ref.read(selfCaregiverIdProvider.future);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.hc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => _RaiseFlagSheet(
        onSubmit: (String message) => raiseSupervisorFlag(
          ref,
          patientId: patientId,
          raisedByCaregiverId: self ?? '',
          message: message,
        ),
      ),
    );
  }
}

/// The "Raise a flag" bottom sheet — a StatefulWidget so it OWNS its text
/// controller and disposes it in its own lifecycle (disposing it from the
/// caller races the sheet's dismiss animation, which still reads it).
class _RaiseFlagSheet extends StatefulWidget {
  const _RaiseFlagSheet({required this.onSubmit});

  final Future<void> Function(String message) onSubmit;

  @override
  State<_RaiseFlagSheet> createState() => _RaiseFlagSheetState();
}

class _RaiseFlagSheetState extends State<_RaiseFlagSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: FlagsScreen.raiseSheetKey,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Flag for a supervisor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.hc.primary,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: FlagsScreen.raiseFieldKey,
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What should a supervisor know?',
              filled: true,
              fillColor: context.hc.surfaceWarm,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: FlagsScreen.raiseSubmitKey,
            onPressed: () async {
              final String msg = _controller.text.trim();
              if (msg.isEmpty) return;
              await widget.onSubmit(msg);
              if (context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.hc.ctaFilled,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Send to supervisor'),
          ),
        ],
      ),
    );
  }
}

/// Raise a flag for [patientId] and refresh the inbox. Shared by the Flags
/// screen's "Raise a flag" sheet and the visit-note screen's auto-flag on a
/// `needs_attention` note (Track-2 #17).
Future<void> raiseSupervisorFlag(
  WidgetRef ref, {
  required String patientId,
  required String raisedByCaregiverId,
  required String message,
  DateTime? now,
}) async {
  final DateTime ts = now ?? DateTime.now();
  await ref.read(supervisorFlagsRepositoryProvider).raise(SupervisorFlag(
        id: 'flag-${ts.microsecondsSinceEpoch}',
        patientId: patientId,
        raisedByCaregiverId: raisedByCaregiverId,
        message: message,
        createdAt: ts,
      ));
  ref.invalidate(openSupervisorFlagsProvider);
}

class _List extends ConsumerWidget {
  const _List({
    required this.flags,
    required this.clientNames,
    required this.caregiverNames,
  });

  final List<SupervisorFlag> flags;
  final Map<String, String> clientNames;
  final Map<String, String> caregiverNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      key: FlagsScreen.listKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: flags.length,
      itemBuilder: (BuildContext context, int i) {
        final SupervisorFlag f = flags[i];
        final String client = clientNames[f.patientId] ?? 'A client';
        final String who = caregiverNames[f.raisedByCaregiverId] ?? 'A caregiver';
        return Card(
          key: FlagsScreen.cardKey(f.id),
          color: context.hc.surfaceWarm,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.flag, size: 18, color: context.hc.accentDeep),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        client,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: context.hc.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  f.message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.hc.text,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Raised by $who · ${_when(f.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.hc.primarySoft,
                      ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: FlagsScreen.resolveKey(f.id),
                    onPressed: () async {
                      await ref
                          .read(supervisorFlagsRepositoryProvider)
                          .resolve(f.id, at: DateTime.now());
                      ref.invalidate(openSupervisorFlagsProvider);
                    },
                    icon: Icon(Icons.check_circle_outline,
                        color: context.hc.success),
                    label: Text(
                      'Resolve',
                      style: TextStyle(color: context.hc.success),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A coarse relative-time label — enough for an inbox glance.
  static String _when(DateTime t) {
    final Duration ago = DateTime.now().difference(t);
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes}m ago';
    if (ago.inHours < 24) return '${ago.inHours}h ago';
    return '${ago.inDays}d ago';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: FlagsScreen.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.outlined_flag, size: 48, color: context.hc.primarySoft),
            const SizedBox(height: 16),
            Text(
              'No open flags.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.hc.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you or a caregiver flags something for a supervisor — or '
              'the visit note catches something worth escalating — it shows '
              'up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.hc.text,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
