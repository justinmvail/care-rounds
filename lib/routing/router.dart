import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/auth_provider.dart';
import '../providers/loved_one_lookup_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/patient_configured_provider.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/conversation_list_screen.dart';
import '../screens/community/learn_playbook_detail_screen.dart';
import '../screens/community/learn_screen.dart';
import '../screens/home_screen.dart';
import '../screens/journal/journal_entry_screen.dart';
import '../screens/journal/journal_screen.dart';
import '../screens/journal/journal_wizard_screen.dart';
import '../screens/medical/care_plan_routine_form.dart';
import '../screens/medical/care_plan_routines_screen.dart';
import '../screens/medical/emergency_card_edit_screen.dart';
import '../screens/medical/care_summary_screen.dart';
import '../screens/medical/emergency_card_screen.dart';
import '../screens/medical/health_log_entry_form.dart';
import '../screens/medical/health_log_screen.dart';
import '../screens/medical/medical_hub_screen.dart';
import '../screens/medical/schedule_screen.dart';
import '../screens/medical/visit_note_screen.dart';
import '../screens/scan_document_screen.dart';
import '../screens/appointment/appointment_detail_screen.dart';
import '../screens/appointment/appointment_form_screen.dart';
import '../screens/appointment/appointment_list_screen.dart';
import '../models/appointment_draft.dart';
import '../models/document.dart' show Insurance;
import '../models/medication_draft.dart';
import '../screens/medication/dose_log_screen.dart';
import '../screens/medication/dose_window_list_screen.dart';
import '../screens/medication/medication_form_screen.dart';
import '../screens/medication/medication_import_review_screen.dart';
import '../screens/medication/medication_list_screen.dart';
import '../screens/onboarding/loved_one_setup_screen.dart';
import '../screens/onboarding/sign_in_screen.dart';
import '../screens/onboarding/welcome_carousel.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/team/activity_screen.dart';
import '../screens/team/calendar_screen.dart';
import '../screens/team/care_circle_screen.dart';
import '../screens/team/care_team_hub_screen.dart';
import '../screens/team/clients_roster_screen.dart';
import '../screens/team/flags_screen.dart';
import '../screens/team/circle_qr_screen.dart';
import '../screens/team/circle_scan_screen.dart';
import '../screens/team/username_screen.dart';
import '../screens/team/my_rounds_screen.dart';
import '../screens/team/shifts_screen.dart';
import '../screens/team/tasks_screen.dart';
import '../services/voice_intake.dart';
import '../widgets/tab_scaffold.dart';

part 'router.g.dart';

/// Route names for go_router. Use these instead of raw path strings
/// when calling `context.goNamed(...)` so a rename only touches one
/// place.
class CareRoundsRoutes {
  CareRoundsRoutes._();

  static const String home = 'home';
  static const String journal = 'journal';
  static const String crisis = 'crisis';
  static const String onboarding = 'onboarding';
  static const String signIn = 'sign-in';
  static const String setup = 'setup';
  static const String settings = 'settings';
  // Add-a-client setup wizard (Issue #6) — reused from onboarding in add
  // mode to append + activate another client. (The separate Settings-side
  // "Clients" manager was retired in Track-2 #33.)
  static const String lovedOnesAdd = 'loved-ones-add';
  static const String journalEntry = 'journal-entry';
  static const String journalNew = 'journal-new';
  static const String chatList = 'chat-list';
  static const String chatThread = 'chat-thread';
  static const String medicationList = 'medication-list';
  static const String medicationForm = 'medication-form';
  static const String medicationScanReview = 'medication-scan-review';
  static const String scanDocument = 'scan-document';
  static const String learn = 'learn';
  static const String rounds = 'rounds';
  static const String careSummary = 'care-summary';
  static const String medicationEdit = 'medication-edit';
  static const String medicationDoseLog = 'medication-dose-log';
  static const String medicationWindowList = 'medication-window-list';
  static const String medicationWindowNew = 'medication-window-new';
  static const String medicationWindowEdit = 'medication-window-edit';
  static const String appointmentList = 'appointment-list';
  static const String appointmentDetail = 'appointment-detail';
  static const String appointmentForm = 'appointment-form';
  static const String appointmentEdit = 'appointment-edit';
  // Learn playbook detail (worker micro-training), relocated out of the
  // removed Community tab. (Videos deep-link to YouTube and have no in-app
  // route; fb_1780932492880889.)
  static const String communityLearnPlaybook = 'community-learn-playbook';

  // Phase 14 IA — Medical hub + its feature pages (BUILD_SPEC.md §4–§5).
  // The hub branch (`medicalHub` → `/medical`) lands in this phase as a
  // placeholder; the feature-page names below are forward-declared here
  // so Phases 14.15–14.24 can wire `goNamed(...)` without re-touching
  // this enum-like surface. Only `medicalHub` + `medicalCardsEmergency`
  // resolve to a registered route today; the rest gain routes as their
  // owning phase lands.
  static const String medicalHub = 'medical-hub';
  static const String medicalSchedule = 'medical-schedule';
  static const String medicalVisitNote = 'medical-visit-note';
  static const String medicalHealthLog = 'medical-health-log';
  static const String medicalHealthLogNew = 'medical-health-log-new';
  static const String medicalHealthLogEdit = 'medical-health-log-edit';
  static const String medicalRoutines = 'medical-routines';
  static const String medicalRoutineNew = 'medical-routine-new';
  static const String medicalRoutineEdit = 'medical-routine-edit';
  static const String medicalCardsEmergency = 'medical-cards-emergency';
  static const String medicalCardsEmergencyEdit =
      'medical-cards-emergency-edit';

  // Phase 14 IA — Care Team hub + its feature pages. Same forward-
  // declaration contract as the Medical names: `teamHub` → `/team`
  // lands here as a placeholder, the rest gain routes in 14.26–14.33.
  static const String teamHub = 'team-hub';
  static const String teamCalendar = 'team-calendar';
  static const String teamTasks = 'team-tasks';
  static const String teamShifts = 'team-shifts';
  static const String teamCircle = 'team-circle';
  // Care-circle connect (2026-06-06) — username onboarding + QR connect.
  static const String teamCircleUsername = 'team-circle-username';
  static const String teamCircleQr = 'team-circle-qr';
  static const String teamCircleScan = 'team-circle-scan';
  static const String teamActivity = 'team-activity';
  static const String teamFlags = 'team-flags';
}

/// Build a fresh GoRouter wired with every BUILD_SPEC.md §5 route.
///
/// Exposed as a builder (not a singleton) so tests get isolated router
/// instances and the demo tour can rebuild with different overrides.
///
/// [redirect] + [refreshListenable] are optional so widget tests that
/// only probe route registration (no auth/onboarding state) can still
/// construct a router with no gates. The production wiring lives in
/// [careroundsRouterProvider]; that's the path the running app uses.
GoRouter buildRouter({
  String initialLocation = '/',
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) {
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: <RouteBase>[
      // Top-level (pushed) routes — outside the tab shell. `parent
      // NavigatorKey: rootNavigatorKey` makes them push onto the root
      // navigator (above the shell) instead of onto a branch
      // navigator. Without that, pushing one of these from inside a
      // tab branch would silently fail to update the displayed
      // location. The pushed screen covers the bottom tab bar and
      // auto-renders a back arrow in the AppBar.
      GoRoute(
        path: '/onboarding',
        name: CareRoundsRoutes.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomeCarousel(),
      ),
      GoRoute(
        path: '/sign-in',
        name: CareRoundsRoutes.signIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SignInScreen(),
      ),
      // New-user loved-one setup wizard — the third gate after the
      // welcome carousel + sign-in. An authenticated caregiver with no
      // [Patient] on file is funnelled here (see `careroundsRedirect`)
      // to create "their person"; on save it lands them on Home. A pushed
      // root-navigator route like the other pre-tab screens, so it covers
      // the tab shell and relies on its own in-page chrome (no OS back).
      GoRoute(
        path: '/setup',
        name: CareRoundsRoutes.setup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LovedOneSetupScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: CareRoundsRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      // Add-a-client setup wizard (Issue #6), reused from onboarding in add
      // mode so a new client is appended + made active rather than gating the
      // first-run flow. Pushed from the Team → Clients roster and the
      // persistent client-switcher bar. (Track-2 #33 retired the separate
      // Settings-side "Clients" manager screen; the roster + switcher bar are
      // the single client-management surface now.) Pushed onto the root
      // navigator so it covers the tab bar like Settings.
      GoRoute(
        path: '/loved-ones/add',
        name: CareRoundsRoutes.lovedOnesAdd,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LovedOneSetupScreen(isAdd: true),
      ),
      // Learn playbook detail (worker micro-training). Relocated out of the
      // removed Community tab to a top-level `/learn` path; pushed onto the
      // root navigator, reached from the Learn entry under Care.
      GoRoute(
        path: '/learn/playbooks/:id',
        name: CareRoundsRoutes.communityLearnPlaybook,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            LearnPlaybookDetailScreen(
          playbookId: state.pathParameters['id'] ?? '',
        ),
      ),
      // Crisis card — deep-link compatibility shim (Phase 14.5). The
      // emergency content now lives at `/medical/cards/emergency` under
      // the Medical hub; `/crisis` survives only so old notification
      // deep links + saved shortcuts still resolve. It redirects to the
      // canonical location rather than rendering a screen of its own.
      // Phase 14.23 deletes the old CrisisCardScreen and lands the real
      // Emergency Card at the redirect target — this route stays alive.
      GoRoute(
        path: '/crisis',
        name: CareRoundsRoutes.crisis,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) =>
            '/medical/cards/emergency',
      ),
      // Tab shell — the fixed 4-tab bar (IA refactor 2026-06-06):
      // Home · Care · Chat · Community. Always exactly four branches,
      // always visible. Each branch is a separate Navigator so
      // back-stacks survive tab switches.
      //
      // The former "Medical" tab is now "Care" (its branch path stays
      // `/medical` internally). The former "Team" tab was folded into
      // the Care branch — its `/team/*` routes now live alongside
      // `/medical` in the same branch. Care is a tile-hub landing; Chat
      // + Community are direct landings. Branch order MUST match
      // `TabScaffold.tabBranchPaths` index-for-index.
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            TabScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                name: CareRoundsRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          // Care branch (Phase 14.15; renamed from Medical 2026-06-06).
          // The Care hub at `/medical` plus EVERY feature page a hub tile
          // opens. Caroline's alpha feedback (2026-06-07): the bottom tab
          // bar must stay visible after entering a Care tile — so the
          // tile landing pages and the sub-pages below them live INSIDE
          // this shell branch (no `parentNavigatorKey: rootNavigatorKey`)
          // and render in the branch navigator, keeping the bar. The
          // Medications / Appointments / Journal lists (reached from Home
          // too) moved in here as branch-level routes so their tiles keep
          // the bar as well; navigating to them from another tab simply
          // activates the Care tab. The PathHeader's parent crumb still
          // does `context.go('/medical')` to return to the hub.
          //
          // Genuinely full-screen surfaces stay on the root navigator
          // (covering the bar on purpose): the Care Circle connect flow
          // (username / QR / scan) reads as a focused modal task.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/medical',
                name: CareRoundsRoutes.medicalHub,
                builder: (BuildContext context, GoRouterState state) =>
                    const MedicalHubScreen(),
                routes: <RouteBase>[
                  // Schedule (Track-2 #32) — the single time surface: a
                  // segmented Calendar / Appointments / Routines wrapper.
                  // ?tab= opens a specific segment (defaults to Calendar).
                  GoRoute(
                    path: 'schedule',
                    name: CareRoundsRoutes.medicalSchedule,
                    builder: (BuildContext context, GoRouterState state) =>
                        ScheduleScreen(
                      initialSegment: _scheduleSegmentFrom(
                        state.uri.queryParameters['tab'],
                      ),
                    ),
                  ),
                  // Ambient visit documentation (Track-2 #16, the flagship) —
                  // talk through the visit, the AI writes the note.
                  GoRoute(
                    path: 'visit-note',
                    name: CareRoundsRoutes.medicalVisitNote,
                    builder: (BuildContext context, GoRouterState state) =>
                        const VisitNoteScreen(),
                  ),
                  // Emergency Card — the read-only ICE card first
                  // responders see. Renders in the Care branch so the tab
                  // bar stays; it's also the `/crisis` redirect target.
                  GoRoute(
                    path: 'cards/emergency',
                    name: CareRoundsRoutes.medicalCardsEmergency,
                    builder: (BuildContext context, GoRouterState state) =>
                        const EmergencyCardScreen(),
                    routes: <RouteBase>[
                      // Edit form for the emergency card — conditions,
                      // medications, allergies, contacts, insurance, and
                      // donor status, saved through the EmergencyCards
                      // notifier. On the modern PathHeader pattern.
                      GoRoute(
                        path: 'edit',
                        name: CareRoundsRoutes.medicalCardsEmergencyEdit,
                        builder: (BuildContext context, GoRouterState state) =>
                            EmergencyCardEditScreen(
                          scannedInsurance: state.extra is Insurance
                              ? state.extra as Insurance
                              : null,
                        ),
                      ),
                    ],
                  ),
                  // Health Log (Phase 14.17) — list + add/edit form.
                  // `health-log/new` is registered before
                  // `health-log/:id/edit` so the literal `new` segment
                  // isn't swallowed by the `:id` parameter.
                  GoRoute(
                    path: 'health-log',
                    name: CareRoundsRoutes.medicalHealthLog,
                    builder: (BuildContext context, GoRouterState state) =>
                        const HealthLogScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'new',
                        name: CareRoundsRoutes.medicalHealthLogNew,
                        builder: (BuildContext context, GoRouterState state) =>
                            const HealthLogEntryForm(),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        name: CareRoundsRoutes.medicalHealthLogEdit,
                        builder: (BuildContext context, GoRouterState state) =>
                            HealthLogEntryForm(
                          entryId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                  // Routines (v2 Care Plan — BUILD_SPEC.md §5.13). The v1
                  // slot/stage CarePlanScreen + CarePlanSectionForm were
                  // deleted in favour of scheduled tasks projecting into
                  // the unified patient timeline. `routines/new` is
                  // registered before `routines/:id` so the literal `new`
                  // segment isn't swallowed by the `:id` parameter.
                  GoRoute(
                    path: 'routines',
                    name: CareRoundsRoutes.medicalRoutines,
                    builder: (BuildContext context, GoRouterState state) =>
                        const CarePlanRoutinesScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'new',
                        name: CareRoundsRoutes.medicalRoutineNew,
                        builder: (BuildContext context, GoRouterState state) =>
                            const CarePlanRoutineForm(),
                      ),
                      GoRoute(
                        path: ':id',
                        name: CareRoundsRoutes.medicalRoutineEdit,
                        builder: (BuildContext context, GoRouterState state) =>
                            CarePlanRoutineForm(
                          routineId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Medications — the Care hub's "Medications" tile + Home's
              // dose-log shortcut. In the Care branch so the tab bar stays.
              // Unified "scan any document" entry — routes each type to its
              // extractor + review flow. In the Care branch so the pushes it
              // makes (med review, appointment form, emergency edit) stay
              // in-branch and the tab bar stays.
              GoRoute(
                path: '/scan',
                name: CareRoundsRoutes.scanDocument,
                builder: (BuildContext context, GoRouterState state) =>
                    const ScanDocumentScreen(),
              ),
              // Learn — worker micro-training playbooks (relocated from the
              // removed Community tab). Reached from the Care hub.
              GoRoute(
                path: '/learn',
                name: CareRoundsRoutes.learn,
                builder: (BuildContext context, GoRouterState state) =>
                    const LearnScreen(),
              ),
              // Shareable care summary (PDF) for provider coordination.
              GoRoute(
                path: '/care-summary',
                name: CareRoundsRoutes.careSummary,
                builder: (BuildContext context, GoRouterState state) =>
                    const CareSummaryScreen(),
              ),
              GoRoute(
                path: '/medications',
                name: CareRoundsRoutes.medicationList,
                builder: (BuildContext context, GoRouterState state) =>
                    const MedicationListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    name: CareRoundsRoutes.medicationForm,
                    builder: (BuildContext context, GoRouterState state) =>
                        const MedicationFormScreen(),
                  ),
                  GoRoute(
                    path: 'today',
                    name: CareRoundsRoutes.medicationDoseLog,
                    // The Home Add sheet's voice button may push a dose-kind
                    // [AddSheetTranscript]; the voice-intake bridge (Phase
                    // 14.14) pre-fills the dose-note field from it.
                    builder: (BuildContext context, GoRouterState state) =>
                        DoseLogScreen(initialNote: VoiceIntake.doseNote(state.extra)),
                  ),
                  // Review + approve a scanned prescription. The scan
                  // handler pushes a [MedicationDraft] via `extra`; a
                  // missing/blank draft opens the screen empty for manual
                  // entry. Two-segment literal path so it never shadows the
                  // `:id/edit` param route below.
                  GoRoute(
                    path: 'scan/review',
                    name: CareRoundsRoutes.medicationScanReview,
                    builder: (BuildContext context, GoRouterState state) {
                      final MedicationDraft draft =
                          state.extra is MedicationDraft
                              ? state.extra as MedicationDraft
                              : const MedicationDraft();
                      return MedicationImportReviewScreen(
                        draft: draft,
                        uncertain: draft.uncertain,
                      );
                    },
                  ),
                  // Edit a medication, pre-filled from its saved row (Phase
                  // 15.6). `:id/edit` is a two-segment path so it never
                  // shadows the literal `new` / `today` children above.
                  GoRoute(
                    path: ':id/edit',
                    name: CareRoundsRoutes.medicationEdit,
                    builder: (BuildContext context, GoRouterState state) =>
                        MedicationFormScreen(
                      medicationId: state.pathParameters['id'],
                    ),
                  ),
                  // Dose-window management (v14 windows pivot). The list
                  // lives under /medications so the back stack reads
                  // Care › Medications › Windows; the form pushes on top of
                  // the list for add + edit.
                  GoRoute(
                    path: 'windows',
                    name: CareRoundsRoutes.medicationWindowList,
                    builder: (BuildContext context, GoRouterState state) =>
                        const DoseWindowListScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'new',
                        name: CareRoundsRoutes.medicationWindowNew,
                        builder: (BuildContext context, GoRouterState state) =>
                            const DoseWindowFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        name: CareRoundsRoutes.medicationWindowEdit,
                        builder: (BuildContext context, GoRouterState state) =>
                            DoseWindowFormScreen(
                          windowId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Appointments — the Care hub's "Appointments" tile. In the
              // Care branch so the tab bar stays.
              GoRoute(
                path: '/appointments',
                name: CareRoundsRoutes.appointmentList,
                builder: (BuildContext context, GoRouterState state) =>
                    const AppointmentListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    name: CareRoundsRoutes.appointmentForm,
                    // The Home Add sheet's voice button may push an
                    // appointment-kind [AddSheetTranscript]; the voice-intake
                    // bridge (Phase 14.14) pre-fills the visit-notes textarea.
                    builder: (BuildContext context, GoRouterState state) =>
                        AppointmentFormScreen(
                      initialNotes: VoiceIntake.appointmentNotes(state.extra),
                      // The Schedule calendar's "Add" affordance passes the
                      // selected day as `?date=YYYY-MM-DD` so the new
                      // appointment lands on the day the caregiver viewed.
                      initialDate: _calendarDateParam(
                          state.uri.queryParameters['date']),
                      // The appointment scan passes an AppointmentDraft via
                      // extra to pre-fill the form.
                      initialDraft: state.extra is AppointmentDraft
                          ? state.extra as AppointmentDraft
                          : null,
                      initialUncertain: state.extra is AppointmentDraft
                          ? (state.extra as AppointmentDraft).uncertain
                          : const <String>{},
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    name: CareRoundsRoutes.appointmentDetail,
                    builder: (BuildContext context, GoRouterState state) =>
                        AppointmentDetailScreen(
                      appointmentId: state.pathParameters['id'] ?? '',
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        name: CareRoundsRoutes.appointmentEdit,
                        builder: (BuildContext context, GoRouterState state) =>
                            AppointmentFormScreen(
                          appointmentId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Journal — the Care hub's "Journal" tile + Home quick
              // actions + the decoder flow. In the Care branch so the tile
              // keeps the tab bar; reaching it from Home/decoder activates
              // the Care tab. `/journal/new` is registered before
              // `/journal/:id` so the literal `new` segment isn't swallowed
              // by the `:id` parameter.
              GoRoute(
                path: '/journal',
                name: CareRoundsRoutes.journal,
                builder: (BuildContext context, GoRouterState state) =>
                    const JournalScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    name: CareRoundsRoutes.journalNew,
                    builder: (BuildContext context, GoRouterState state) {
                      // Two ways in: the chat coach pushes a fully-formed
                      // [JournalWizardArgs]; the Home Add sheet's voice
                      // button pushes an [AddSheetTranscript] (journal-entry
                      // or quick-note kind). The voice-intake bridge (Phase
                      // 14.14) turns the latter into the wizard's initial
                      // value; anything else opens the wizard blank.
                      final Object? extra = state.extra;
                      JournalWizardArgs? args;
                      if (extra is JournalWizardArgs) {
                        args = extra;
                      } else {
                        final String? transcript =
                            VoiceIntake.journalTranscript(extra);
                        if (transcript != null) {
                          args =
                              JournalWizardArgs(initialTranscript: transcript);
                        }
                      }
                      return JournalWizardScreen(args: args);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    name: CareRoundsRoutes.journalEntry,
                    builder: (BuildContext context, GoRouterState state) =>
                        JournalEntryScreen(
                            entryId: state.pathParameters['id'] ?? ''),
                  ),
                ],
              ),
              // Care Circle coordination — folded into Care (2026-06-06):
              // the former Team tab's hub + feature pages live in the Care
              // branch's navigator (no separate tab). Their paths stay
              // `/team/*` internally so existing deep links keep resolving.
              GoRoute(
                path: '/team',
                name: CareRoundsRoutes.teamHub,
                builder: (BuildContext context, GoRouterState state) =>
                    const CareTeamHubScreen(),
                routes: <RouteBase>[
                  // Shared Calendar (Phase 14.29) — the 7-day week view of
                  // appointments, tasks, shifts, and notes. In the Care
                  // branch so the tab bar stays (it's also the Care hub's
                  // "Schedule" tile via `?from=medical`).
                  GoRoute(
                    path: 'calendar',
                    name: CareRoundsRoutes.teamCalendar,
                    // `?from=medical` (the Medical hub's "Schedule" tile)
                    // flips the path header to the Medical breadcrumb;
                    // `?date=YYYY-MM-DD` (the chat coach's "take me to that
                    // day" navigation) opens the calendar on that day.
                    builder: (BuildContext context, GoRouterState state) =>
                        CalendarScreen(
                      fromMedical:
                          state.uri.queryParameters['from'] == 'medical',
                      initialDate: _calendarDateParam(
                          state.uri.queryParameters['date']),
                    ),
                  ),
                  // Tasks board (Phase 14.30) — Open / Claimed / Done
                  // segmented task list. In the Care branch so the tab bar
                  // stays.
                  GoRoute(
                    path: 'tasks',
                    name: CareRoundsRoutes.teamTasks,
                    builder: (BuildContext context, GoRouterState state) =>
                        const TasksScreen(),
                  ),
                  // Shifts board (Phase 14.31) — a 7-day coverage strip with
                  // per-caregiver bands + gap flags. In the Care branch so
                  // the tab bar stays.
                  GoRoute(
                    path: 'shifts',
                    name: CareRoundsRoutes.teamShifts,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ShiftsScreen(),
                  ),
                  // Care Rounds "My Rounds" — the signed-in worker's shifts
                  // across ALL clients (vs Shifts, which is the active client's
                  // coverage board). In the Care branch so the tab bar stays.
                  GoRoute(
                    path: 'my-rounds',
                    builder: (BuildContext context, GoRouterState state) =>
                        const MyRoundsScreen(),
                  ),
                  // Care Rounds "Clients" — the team's roster of the people it
                  // cares for (vs People, the caregiver roster). In the Care
                  // branch so the tab bar stays.
                  GoRoute(
                    path: 'clients',
                    builder: (BuildContext context, GoRouterState state) =>
                        const ClientsRosterScreen(),
                  ),
                  // Activity feed (Phase 14.32) — the chronological,
                  // filterable feed of every care event. In the Care branch
                  // so the tab bar stays.
                  GoRoute(
                    path: 'activity',
                    name: CareRoundsRoutes.teamActivity,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ActivityScreen(),
                  ),
                  // Supervisor escalation inbox (Track-2 #17) — open flags
                  // across clients; the flagship visit note feeds it.
                  GoRoute(
                    path: 'flags',
                    name: CareRoundsRoutes.teamFlags,
                    builder: (BuildContext context, GoRouterState state) =>
                        const FlagsScreen(),
                  ),
                  // Care Circle roster (Phase 14.27). In the Care branch so
                  // the tab bar stays; the connect flow below (username / QR
                  // / scan) stays full-screen on the root navigator as a
                  // focused modal task.
                  GoRoute(
                    path: 'circle',
                    name: CareRoundsRoutes.teamCircle,
                    builder: (BuildContext context, GoRouterState state) =>
                        const CareCircleScreen(),
                    routes: <RouteBase>[
                      // Care-circle connect (2026-06-06) — pick an
                      // @username, show your invite QR, scan another
                      // caregiver's QR to join their circle. These stay on
                      // the root navigator (full-screen) — they're a focused
                      // modal connect task, not a browsable hub page.
                      GoRoute(
                        path: 'username',
                        name: CareRoundsRoutes.teamCircleUsername,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            const UsernameScreen(),
                      ),
                      GoRoute(
                        path: 'qr',
                        name: CareRoundsRoutes.teamCircleQr,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            const CircleQrScreen(),
                      ),
                      GoRoute(
                        path: 'scan',
                        name: CareRoundsRoutes.teamCircleScan,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            const CircleScanScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Chat — direct landing. `/chat/:id` pushes onto THIS branch's
          // navigator (no `parentNavigatorKey`), so a thread keeps the
          // tab bar and pops back to the conversation list.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/chat',
                name: CareRoundsRoutes.chatList,
                builder: (BuildContext context, GoRouterState state) =>
                    const ConversationListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    name: CareRoundsRoutes.chatThread,
                    builder: (BuildContext context, GoRouterState state) {
                      final String id = state.pathParameters['id'] ?? '';
                      // Key by conversation id so navigating thread→thread
                      // (e.g. the center mic opening a fresh thread while
                      // already viewing one) gives a NEW ChatScreen State
                      // that loads the right messages — without a key the
                      // route reuses the prior screen and shows the wrong
                      // conversation (fb_1781035154885086).
                      return ChatScreen(
                        key: ValueKey<String>('chat-$id'),
                        conversationId: id,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Rounds — the worker's daily shifts across all clients (Care
          // Rounds' flagship, promoted from a Care sub-menu into the tab bar,
          // replacing the removed Community forum).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/rounds',
                name: CareRoundsRoutes.rounds,
                builder: (BuildContext context, GoRouterState state) =>
                    const MyRoundsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Pure redirect policy — decoupled from go_router + riverpod so it's
/// unit-testable without pumping a widget tree (BUILD_SPEC.md §5.11 +
/// §5.12).
///
/// Two stacked gates, each returning the SAME path when already
/// satisfied so go_router treats the decision as stable and stops
/// re-evaluating (an unstable redirect would loop until go_router's
/// safety limit kicks in):
///
/// 1. **Onboarding gate** — until [onboardingCompleted] flips true,
///    every location collapses to `/onboarding` **except `/sign-in`**,
///    which is allowed through so the carousel's "Skip" can reach it
///    without marking onboarding done (the value prop stays reachable —
///    UIUX_REVIEW). The carousel and sign-in both return null so the
///    redirect doesn't ping-pong. Onboarding then completes on a
///    successful sign-in.
/// 2. **Auth gate** — onboarding complete but [authState] is
///    [AuthStateSignedOut] funnels every location to `/sign-in`. Sign-in
///    returns null for the same reason.
/// 3. **Loved-one setup gate** — onboarded + signed-in but no [Patient]
///    on file yet ([patientConfigured] false) funnels every location to
///    `/setup` so the caregiver creates "their person" before reaching
///    the app. The wizard itself returns null so the redirect doesn't
///    ping-pong; in `DEMO_MODE` the seeded Mary keeps this flag true so
///    the wizard is skipped entirely.
///
///    **Exception — a fresh sign-in's one-time backend lookup
///    ([lovedOneLookupPending]).** A returning caregiver signing in on a
///    new install has no client on THIS device yet, but their account
///    may already own one on the backend. While that one-time lookup is
///    in flight we hold on `/sign-in` (which shows its own spinner)
///    instead of forcing `/setup` — otherwise the caregiver is made to
///    create a DUPLICATE person that sync then shadows with their
///    original (fb 2026-06-13). Once the lookup settles this falls through
///    to the real setup-vs-home decision.
/// 4. Signed-in caregivers who land on `/onboarding` or `/sign-in`
///    (deep link, browser back) get bounced to `/` rather than being
///    asked to re-onboard.
String? careroundsRedirect({
  required String location,
  required bool onboardingCompleted,
  required AuthState authState,
  required bool patientConfigured,
  bool lovedOneLookupPending = false,
}) {
  const String onboarding = '/onboarding';
  const String signIn = '/sign-in';
  const String setup = '/setup';
  const String home = '/';

  if (!onboardingCompleted) {
    // `/sign-in` is allowed through even while onboarding is incomplete so
    // the carousel's "Skip" can reach it WITHOUT marking onboarding done
    // (UIUX_REVIEW: completing on Skip made the value prop reachable
    // exactly once). Onboarding then completes on a successful sign-in.
    // Both target locations return null so go_router sees a stable
    // decision and stops re-evaluating.
    if (location == onboarding || location == signIn) return null;
    return onboarding;
  }

  final bool signedIn = authState is AuthStateSignedIn;
  if (!signedIn) {
    return location == signIn ? null : signIn;
  }

  if (!patientConfigured) {
    // A fresh sign-in's backend loved-one lookup is still in flight — hold
    // on the sign-in screen rather than flashing (and committing to) the
    // setup wizard before we know whether the account already owns a loved
    // one. Returning `signIn` for any other location keeps us put without
    // a ping-pong; the held page's state is preserved by go_router's
    // route key, so the screen doesn't re-fire its own navigation.
    if (lovedOneLookupPending) {
      return location == signIn ? null : signIn;
    }
    return location == setup ? null : setup;
  }

  if (location == onboarding || location == signIn || location == setup) {
    return home;
  }
  return null;
}

/// `ChangeNotifier` that bridges the riverpod auth-state stream + the
/// [onboardingCompletedProvider] notifier into a single [Listenable]
/// that go_router's `refreshListenable` understands.
///
/// Owned by [careroundsRouterProvider]; widget tests that wire the
/// redirect by hand can construct one directly and drive it with
/// [updateAuthState] + [notify].
@visibleForTesting
class AuthOnboardingRefresh extends ChangeNotifier {
  AuthState _authState = const AuthState.signedOut();

  /// Last [AuthState] the bridge observed. The redirect closure reads
  /// this synchronously instead of awaiting the stream on every
  /// evaluation — go_router calls `redirect` from a non-async path.
  AuthState get authState => _authState;

  /// Fed the auth stream's payload; updates [authState] + fires
  /// listeners so go_router re-evaluates the active redirect.
  void updateAuthState(AuthState next) {
    _authState = next;
    notifyListeners();
  }

  /// Fire listeners without changing [authState]. Used by the
  /// onboarding-complete listener — the redirect re-reads
  /// `onboardingCompletedProvider` from the ref on every evaluation, so
  /// the bridge only needs to wake go_router up.
  void notify() => notifyListeners();
}

/// Production GoRouter wiring — assembles [buildRouter] with the
/// auth + onboarding redirect (BUILD_SPEC.md §5.11 + §5.12) and the
/// [AuthOnboardingRefresh] listenable so the redirect re-runs on every
/// state transition.
///
/// `keepAlive: true` so the router survives across the rebuilds
/// `MaterialApp.router` triggers — without it, every theme/textScaler
/// change would tear the router (and its navigation stack) down.
@Riverpod(keepAlive: true)
GoRouter careroundsRouter(Ref ref) {
  final AuthOnboardingRefresh refresh = AuthOnboardingRefresh();

  // Onboarding flips a bool — the redirect re-reads the provider on
  // every evaluation, so all this listener has to do is wake go_router.
  ref.listen<bool>(
    onboardingCompletedProvider,
    (bool? _, bool __) => refresh.notify(),
  );

  // The loved-one setup gate flips a bool too: false until the
  // persisted patient resolves (or the wizard saves one + calls
  // `reload`), true once "their person" is on file. Same deal — the
  // redirect re-reads the provider on every evaluation, so the listener
  // just wakes go_router when the value lands.
  ref.listen<bool>(
    patientConfiguredProvider,
    (bool? _, bool __) => refresh.notify(),
  );

  // The fresh-sign-in loved-one lookup flips a bool while it asks the
  // backend whether the account already owns a client. The redirect
  // re-reads it on every evaluation, so the listener just wakes go_router
  // when the gate engages (hold on sign-in) or releases (decide
  // setup-vs-home).
  ref.listen<bool>(
    lovedOneLookupProvider,
    (bool? _, bool __) => refresh.notify(),
  );

  // The auth state stream is the source of truth for the auth gate;
  // cache the latest payload on the bridge so the redirect closure can
  // read it synchronously.
  final AuthProvider auth = ref.read(authProvider);
  final StreamSubscription<AuthState> sub =
      auth.watchAuthState().listen(refresh.updateAuthState);

  ref.onDispose(() {
    sub.cancel();
    refresh.dispose();
  });

  return buildRouter(
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) =>
        careroundsRedirect(
      location: state.matchedLocation,
      onboardingCompleted: ref.read(onboardingCompletedProvider),
      authState: refresh.authState,
      patientConfigured: ref.read(patientConfiguredProvider),
      lovedOneLookupPending: ref.read(lovedOneLookupProvider),
    ),
  );
}

/// Parse the calendar route's `?date=YYYY-MM-DD` query param into the day
/// the screen should open on, or null when absent/unparseable (then the
/// calendar defaults to today).
DateTime? _calendarDateParam(String? raw) =>
    (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);

/// Map the Schedule route's `?tab=` query param to a segment; unknown or
/// absent → the Calendar segment (Track-2 #32).
ScheduleSegment _scheduleSegmentFrom(String? raw) => switch (raw) {
      'appointments' => ScheduleSegment.appointments,
      'routines' => ScheduleSegment.routines,
      _ => ScheduleSegment.calendar,
    };
