import 'package:freezed_annotation/freezed_annotation.dart';

part 'care_approach.freezed.dart';
part 'care_approach.g.dart';

/// The situations a direct-care worker actually runs into with a client living
/// with dementia — the ones that make the job hard, get aides hurt, and drive
/// them out of the sector.
///
/// Deliberately named for what the WORKER encounters, not for a symptom or a
/// clinical construct. "Resisted personal care" is something an aide observes
/// and can act on; "agitation secondary to dementia" is a clinical
/// characterization an aide is not licensed to make and this app does not make
/// for them.
///
/// NOTE: `didNotRecogniseMe` keeps its British spelling as an IDENTIFIER on
/// purpose — `CareSituation.name` is written to the `situation` column, so
/// renaming it would orphan every stored row. The user-facing label is
/// American; the identifier is a storage key, not copy.
enum CareSituation {
  resistedPersonalCare,
  agitatedOrUpset,
  refusedToEat,
  askedTheSameThingRepeatedly,
  didNotRecogniseMe,
  wantedToLeaveOrGoHome,
  refusedMedication,
  upAtNightOrRestless,
  other;

  String get label => switch (this) {
        CareSituation.resistedPersonalCare => 'Resisted personal care',
        CareSituation.agitatedOrUpset => 'Agitated or upset',
        CareSituation.refusedToEat => 'Refused to eat',
        CareSituation.askedTheSameThingRepeatedly =>
          'Asked the same thing over and over',
        CareSituation.didNotRecogniseMe => "Didn't recognize me",
        CareSituation.wantedToLeaveOrGoHome => 'Wanted to leave or go home',
        CareSituation.refusedMedication => 'Refused medication',
        CareSituation.upAtNightOrRestless => 'Up at night or restless',
        CareSituation.other => 'Something else',
      };
}

/// Whether what the worker tried actually helped.
enum ApproachOutcome {
  worked,
  partly,
  didNotWork;

  String get label => switch (this) {
        ApproachOutcome.worked => 'It worked',
        ApproachOutcome.partly => 'Helped a bit',
        ApproachOutcome.didNotWork => "Didn't work",
      };

  /// Ordering weight so the approaches that worked surface first.
  int get rank => switch (this) {
        ApproachOutcome.worked => 0,
        ApproachOutcome.partly => 1,
        ApproachOutcome.didNotWork => 2,
      };
}

/// One thing a worker tried, in one situation, with one client — and whether it
/// helped.
///
/// **Why this exists.** In dementia care the practical knowledge of how to
/// approach a particular person — that she will accept a shower if the towels
/// are warm first, that arguing about her late husband makes it worse — lives
/// in the head of whichever aide worked it out. Aides rotate and the sector
/// turns over at nearly 75% a year in home care, so that knowledge leaves with
/// them and the next worker starts from nothing, on the hardest part of the
/// job. Keeping it on the CLIENT's own record, shared with their team,
/// is how the knowledge outlasts the individual worker.
///
/// This is a record of what a worker did and what happened. It is not a care
/// plan, not a clinical intervention, and not advice: nothing here prescribes,
/// and every entry is authored by the person who was in the room.
@freezed
abstract class CareApproach with _$CareApproach {
  const factory CareApproach({
    required String id,
    required String patientId,
    required CareSituation situation,

    /// What the worker tried, in their own words.
    required String tried,

    required ApproachOutcome outcome,
    required DateTime at,

    /// The caregiver who recorded it, so a later reader knows whose experience
    /// this was — and so credit for working something out is visible.
    String? caregiverId,

    /// Free-text detail the worker chose to add.
    String? notes,
  }) = _CareApproach;

  factory CareApproach.fromJson(Map<String, dynamic> json) =>
      _$CareApproachFromJson(json);
}

/// Condense a client's recorded approaches into the short, ranked briefing a
/// worker (or the coach) can act on: for each situation, what has worked and
/// what hasn't, most recent first.
///
/// Pure so it is unit-testable without a database.
List<String> summarizeApproaches(List<CareApproach> all) {
  final Map<CareSituation, List<CareApproach>> bySituation =
      <CareSituation, List<CareApproach>>{};
  for (final CareApproach a in all) {
    bySituation.putIfAbsent(a.situation, () => <CareApproach>[]).add(a);
  }

  final List<String> out = <String>[];
  for (final CareSituation s in CareSituation.values) {
    final List<CareApproach> items = bySituation[s] ?? const <CareApproach>[];
    if (items.isEmpty) continue;
    // Worked first, then most recent — a worker reading this mid-visit needs
    // the thing to try, not a chronology.
    final List<CareApproach> sorted = <CareApproach>[...items]..sort(
        (CareApproach a, CareApproach b) {
          final int byOutcome = a.outcome.rank.compareTo(b.outcome.rank);
          return byOutcome != 0 ? byOutcome : b.at.compareTo(a.at);
        },
      );
    final String detail = sorted
        .take(3)
        .map((CareApproach a) => '${a.tried} (${a.outcome.label.toLowerCase()})')
        .join('; ');
    out.add('${s.label}: $detail');
  }
  return out;
}
