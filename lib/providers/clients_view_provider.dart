import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/patient.dart';
import '../screens/medication/dose_window_list_screen.dart'
    show doseWindowListProvider;
import '../screens/medication/medication_list_screen.dart'
    show medicationListProvider;
import 'active_patient_provider.dart';
import 'patient_configured_provider.dart';
import 'storage_provider.dart';

part 'clients_view_provider.g.dart';

/// The route that opens the "add a client" setup wizard (add mode). The
/// Team → Clients roster and the persistent client-switcher bar both push
/// this to append a new client. (Formerly `LovedOnesScreen.addRoute`; the
/// Settings-side "Clients" manager screen was retired in Track-2 #33 in
/// favor of the single Team roster + the switcher bar.)
const String lovedOnesAddRoute = '/loved-ones/add';

/// The roster of clients + the active id, bundled so a surface consumes a
/// single [AsyncValue] (multi-patient, Issue #6).
@immutable
class LovedOnesView {
  const LovedOnesView({required this.patients, required this.activeId});

  /// Every client on file, name-sorted (the storage layer sorts).
  final List<Patient> patients;

  /// The id [StorageProvider.getPatient] currently resolves to — the row
  /// the whole app is centred on. Used to flag the active row.
  final String? activeId;

  bool get isEmpty => patients.isEmpty;
}

/// Bundles the client roster + the active id for the roster surfaces.
///
/// `keepAlive: false` so it re-resolves each time a surface opens; the
/// switch / add handlers invalidate it explicitly so the active flag
/// updates in place. Reads through [storageProvider] directly (not the
/// `activePatient*` providers) so the list + the active marker come from
/// one consistent snapshot.
@riverpod
Future<LovedOnesView> lovedOnesView(Ref ref) async {
  final StorageProvider storage = ref.watch(storageProvider);
  final List<Patient> patients = await storage.listPatients();
  // The id the app is centred on — the explicitly-chosen active id when
  // set, else the resolved (first/sole) patient so a row is always
  // flagged when at least one client is on file.
  final String? explicit = await storage.getActivePatientId();
  final String? resolved = explicit ?? (await storage.getPatient())?.id;
  return LovedOnesView(patients: patients, activeId: resolved);
}

/// Switch the active client to [patientId] and refresh every surface that
/// reads the active patient (the active-patient providers + the medication /
/// dose-window lists that query by patient) so the whole app re-centres
/// without a relaunch (multi-patient, Issue #6).
Future<void> switchActivePatient(WidgetRef ref, String patientId) async {
  await ref.read(storageProvider).setActivePatientId(patientId);
  ref.invalidate(activePatientProvider);
  ref.invalidate(activePatientIdProvider);
  ref.invalidate(lovedOnesViewProvider);
  ref.invalidate(medicationListProvider);
  ref.invalidate(doseWindowListProvider);
  // The setup gate re-reads storage; a patient is still on file so it stays
  // true (this keeps `patientConfiguredProvider` consistent if a switch ever
  // races a redirect evaluation).
  await ref.read(patientConfiguredProvider.notifier).reload();
}
