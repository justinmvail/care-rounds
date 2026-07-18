import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../widgets/hub_tile.dart';
import '../../widgets/path_header.dart';

/// The Care tile-hub at `/medical` (route path kept internal) — the single
/// entry point to everything about caring for your client: the emergency
/// card, meds, schedule, appointments, health log, routines, the journal,
/// and the Care Circle of helpers.
///
/// Renamed from "Medical" (2026-06-06) — the clinical word was off-brand —
/// and the former separate "Team" tab folded in here as the **Care Circle**
/// tile. That tile is always shown now (UIUX_REVIEW): the door to inviting
/// family stays discoverable; the sub-hub itself handles the
/// coordination-off onboarding CTA.
///
/// This is a **landing screen**: the [PathHeader] carries a single crumb
/// ("Care") so it renders the title row only — no breadcrumb trail and no
/// Back control (you reach the hub by tapping the Care tab, and re-tapping
/// it pops the branch back here). Each tile pushes its feature page.
///
/// The tiles are grouped into three labelled sections (Track-2 #31) rather
/// than a flat wall of eleven — a direct-care worker scanning the tab reads
/// "what do I do this visit / what's the client's info / team & training"
/// instead of hunting an undifferentiated grid.
class MedicalHubScreen extends StatelessWidget {
  const MedicalHubScreen({super.key});

  /// Stable per-tile key derived from the tile's destination route. Tests
  /// tap by route rather than by visible label so a copy edit doesn't
  /// break them.
  static Key tileKey(String route) => Key('medical-hub-tile-$route');

  /// The Care hub, grouped into sections.
  ///
  /// **Emergency Card leads its section** (UIUX_REVIEW): the highest-stakes,
  /// most-glanceable surface — the one screen you show a first responder — and
  /// it carries the hub's single amber chip (#28: one primary accent per hub).
  ///
  /// The **Team** tile is ALWAYS shown (UIUX_REVIEW): the door to the
  /// cross-client Team hub must be discoverable, not hidden behind a Settings
  /// toggle. It routes to `/team`, which — when coordination is still off —
  /// greets a first-time worker with the onboarding CTA that flips the setting
  /// on in place.
  static List<_CareSection> _sectionsFor(BuildContext context) =>
      <_CareSection>[
        _CareSection(
          title: 'This visit',
          tiles: <_MedicalTileSpec>[
            // One Schedule surface (Track-2 #32): the segmented
            // Calendar / Appointments / Routines wrapper replaces the three
            // former peer tiles.
            _MedicalTileSpec(
              icon: Icons.schedule_outlined,
              label: 'Schedule',
              subLabel: 'calendar, appointments & routines',
              route: '/medical/schedule',
              chipColor: context.hc.link,
            ),
            _MedicalTileSpec(
              icon: Icons.monitor_heart_outlined,
              label: 'Health Log',
              subLabel: 'symptoms & vitals',
              route: '/medical/health-log',
              chipColor: context.hc.link,
            ),
            _MedicalTileSpec(
              icon: Icons.book_outlined,
              label: 'Journal',
              subLabel: 'care notes',
              route: '/journal',
              chipColor: context.hc.text,
            ),
            _MedicalTileSpec(
              icon: Icons.document_scanner_outlined,
              label: 'Scan a document',
              subLabel: 'Rx & appointment cards',
              route: '/scan',
              chipColor: context.hc.primary,
            ),
          ],
        ),
        _CareSection(
          title: 'Client info',
          tiles: <_MedicalTileSpec>[
            _MedicalTileSpec(
              icon: Icons.shield_outlined,
              label: 'Emergency Card',
              subLabel: 'info for first responders',
              route: '/medical/cards/emergency',
              chipColor: context.hc.cta,
            ),
            _MedicalTileSpec(
              icon: Icons.medication_outlined,
              label: 'Medications',
              subLabel: 'doses & reminders',
              route: '/medications',
              chipColor: context.hc.primary,
            ),
            _MedicalTileSpec(
              icon: Icons.summarize_outlined,
              label: 'Care summary',
              subLabel: 'share at handoff',
              route: '/care-summary',
              chipColor: context.hc.primary,
            ),
          ],
        ),
        _CareSection(
          title: 'Team & training',
          tiles: <_MedicalTileSpec>[
            _MedicalTileSpec(
              icon: Icons.groups_outlined,
              label: 'Team',
              subLabel: 'clients, caregivers & shifts',
              route: '/team',
              chipColor: context.hc.accentDeep,
            ),
            _MedicalTileSpec(
              icon: Icons.school_outlined,
              label: 'Learn',
              subLabel: 'quick training',
              route: '/learn',
              chipColor: context.hc.link,
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final List<_CareSection> sections = _sectionsFor(context);
    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              // Single crumb → PathHeader suppresses the breadcrumb row
              // and the Back control, rendering the title row only.
              child: PathHeader(
                breadcrumbs: <PathHeaderCrumb>[
                  PathHeaderCrumb(label: 'Care'),
                ],
                title: 'Care',
                backLabel: 'Back to Home',
                leadingIcon: Icons.volunteer_activism_outlined,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final _CareSection section in sections)
                      _SectionBlock(section: section),
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

/// One labelled section of the Care hub: a small heading over a two-column
/// tile grid, sharing the [HubGrid] geometry (12px gap, two equal columns)
/// but without its own scroll view — the whole hub scrolls as one column.
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final _CareSection section;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              section.title.toUpperCase(),
              style: TextStyle(
                color: context.hc.primarySoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double itemWidth = (constraints.maxWidth - _gap) / 2;
              return Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: <Widget>[
                  for (final _MedicalTileSpec spec in section.tiles)
                    SizedBox(
                      width: itemWidth,
                      child: HubTile(
                        key: MedicalHubScreen.tileKey(spec.route),
                        icon: spec.icon,
                        label: spec.label,
                        subLabel: spec.subLabel,
                        chipColor: spec.chipColor,
                        onTap: () => context.push(spec.route),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A titled group of Care-hub tiles (Track-2 #31).
@immutable
class _CareSection {
  const _CareSection({required this.title, required this.tiles});

  final String title;
  final List<_MedicalTileSpec> tiles;
}

/// Static description of one [MedicalHubScreen] tile — the glyph, the two
/// label lines, the chip color, and the route the tile pushes.
@immutable
class _MedicalTileSpec {
  const _MedicalTileSpec({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.route,
    required this.chipColor,
  });

  final IconData icon;
  final String label;
  final String subLabel;
  final String route;
  final Color chipColor;
}
