import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/medication.dart'; // DoseWindow.isAsNeeded extension
import '../models/risk_signal.dart';
import '../screens/medication/medication_list_screen.dart'
    show MedicationListItem, medicationListProvider, medicationListClockProvider;
import '../services/medication_supply.dart';
import '../services/risk_signals.dart';
import 'pattern_detector_provider.dart';

part 'risk_signals_provider.g.dart';

/// The active client's early-warning signals (Track-2 #18), composed from the
/// journal pattern detector + the per-medication refill runway.
///
/// Sync (reads each source's current value, empty while a source loads) so
/// the Home card consumes a plain `List` — the same shape the pattern-detector
/// provider exposes. Recomputes when either source changes.
@riverpod
List<RiskSignal> clientRiskSignals(Ref ref) {
  final List<MedicationListItem> items =
      ref.watch(medicationListProvider).value ?? const <MedicationListItem>[];
  final DateTime now = ref.watch(medicationListClockProvider)();
  final List<NamedSupply> supplies = <NamedSupply>[
    for (final MedicationListItem it in items)
      (
        medName: it.medication.name,
        supply: computeMedicationSupply(
          it.medication,
          scheduledDosesPerDay:
              it.windows.where((w) => !w.isAsNeeded).length,
          now: now,
        ),
      ),
  ];
  return buildRiskSignals(
    patternAlerts: ref.watch(patternDetectorProvider),
    supplies: supplies,
  );
}
