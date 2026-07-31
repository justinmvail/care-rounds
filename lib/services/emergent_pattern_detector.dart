import '../models/care_approach.dart';
import '../models/risk_signal.dart';

/// Which part of the day an approach was recorded in. Coarse on purpose — a
/// worker plans a visit around "mornings are easier", not around 14:30.
enum Daypart {
  morning,
  afternoon,
  evening;

  static Daypart of(DateTime t) => switch (t.hour) {
        < 12 => Daypart.morning,
        < 17 => Daypart.afternoon,
        _ => Daypart.evening,
      };

  String get label => switch (this) {
        Daypart.morning => 'the morning',
        Daypart.afternoon => 'the afternoon',
        Daypart.evening => 'the evening',
      };

  /// The plan the pattern implies: if the hard hours cluster late, move the
  /// demanding tasks earlier, and vice versa.
  String get plan => switch (this) {
        Daypart.morning =>
          'the easier window for demanding tasks is later in the day',
        Daypart.afternoon || Daypart.evening =>
          'the easier window for demanding tasks is earlier in the day',
      };
}

/// How far back the rules look. Approaches are recorded far less often than
/// journal entries — a fortnight is enough to show a repeat without letting a
/// pattern the team already solved keep firing.
const Duration kEmergentWindow = Duration(days: 14);

/// How many times a situation must recur inside [kEmergentWindow] before it is
/// a pattern rather than a bad day.
const int kEmergentThreshold = 3;

/// Fraction of a situation's occurrences that must share one daypart before
/// the clustering is called out.
const double kClusterShare = 2 / 3;

/// Most emergent signals surfaced at once, so the Home card stays readable.
const int kMaxEmergentSignals = 3;

/// Per-client pattern detection over the client's own "what works" record.
///
/// **Why this is not another hardcoded rule.** The journal detectors in
/// `pattern_detector.dart` each know in advance what they are looking for —
/// falls, or late-day agitation. They can only find the patterns we thought of
/// while writing them. These rules know nothing about any particular situation:
/// they run over whatever a client's own record happens to contain and report
/// the shape they find in it. One client's pattern turns out to be showers in
/// the evening; another's is refusing medication every morning; a third's is a
/// situation nobody anticipated. The rules are the same for all three, and no
/// code changes when a new one emerges.
///
/// That is possible here and not in the journal because a [CareApproach] is
/// structured — it carries a [CareSituation], a timestamp, and an outcome —
/// so situations can be counted and compared without guessing at free text.
///
/// **Still rule-based and still explainable.** Nothing is learned, trained, or
/// inferred. Each signal states the count it fired on and the plan it implies,
/// so a worker can check the arithmetic against the record. It reports what a
/// team already wrote down; it does not diagnose, and it does not predict with
/// a model.
class EmergentPatternDetector {
  const EmergentPatternDetector();

  /// Run every rule over one client's [approaches], anchored at [now].
  ///
  /// At most one signal per situation — the most actionable rule wins, so a
  /// situation that both recurs and defeats everything tried reports the
  /// second. Ordered by how often the situation came up, capped at
  /// [kMaxEmergentSignals].
  List<RiskSignal> detect(
    List<CareApproach> approaches, {
    required DateTime now,
  }) {
    final DateTime cutoff = now.subtract(kEmergentWindow);
    final Map<CareSituation, List<CareApproach>> recent =
        <CareSituation, List<CareApproach>>{};
    for (final CareApproach a in approaches) {
      if (!a.at.isAfter(cutoff)) continue;
      recent.putIfAbsent(a.situation, () => <CareApproach>[]).add(a);
    }

    final List<({int count, RiskSignal signal})> found =
        <({int count, RiskSignal signal})>[];
    for (final MapEntry<CareSituation, List<CareApproach>> e in recent.entries) {
      if (e.value.length < kEmergentThreshold) continue;
      final RiskSignal? s = _forSituation(e.key, e.value);
      if (s != null) found.add((count: e.value.length, signal: s));
    }

    // Most frequent first; ties keep the enum's declaration order so the
    // output is stable across runs on identical data.
    found.sort((a, b) => b.count - a.count);
    return List<RiskSignal>.unmodifiable(
      found.take(kMaxEmergentSignals).map((e) => e.signal),
    );
  }

  /// The single most useful thing to say about one recurring situation.
  RiskSignal? _forSituation(CareSituation s, List<CareApproach> items) =>
      _nothingWorking(s, items) ?? _clustered(s, items) ?? _recurring(s, items);

  /// Repeatedly tried, nothing has helped yet. The most actionable of the
  /// three: it is the case where the team's own record says they are stuck,
  /// which is a supervisor conversation rather than another attempt.
  RiskSignal? _nothingWorking(CareSituation s, List<CareApproach> items) {
    final bool anyHelped = items.any((CareApproach a) =>
        a.outcome == ApproachOutcome.worked ||
        a.outcome == ApproachOutcome.partly);
    if (anyHelped) return null;
    return RiskSignal(
      kind: 'emergent_nothing_working:${s.name}',
      level: RiskLevel.urgent,
      title: '${s.label} — nothing has worked yet',
      detail: '${items.length} attempts recorded in the last '
          '${kEmergentWindow.inDays} days and none of them helped. Worth '
          'raising with a supervisor rather than trying another variation.',
    );
  }

  /// The situation keeps landing in the same part of the day. This is the
  /// generalization of the hardcoded sundowning rule: it fires on whichever
  /// situation clusters for this particular client, not on a behavior chosen
  /// in advance.
  RiskSignal? _clustered(CareSituation s, List<CareApproach> items) {
    final Map<Daypart, int> byPart = <Daypart, int>{};
    for (final CareApproach a in items) {
      final Daypart p = Daypart.of(a.at);
      byPart[p] = (byPart[p] ?? 0) + 1;
    }
    Daypart? top;
    int best = 0;
    for (final MapEntry<Daypart, int> e in byPart.entries) {
      if (e.value > best) {
        best = e.value;
        top = e.key;
      }
    }
    if (top == null || best / items.length < kClusterShare) return null;
    return RiskSignal(
      kind: 'emergent_cluster:${s.name}',
      level: RiskLevel.watch,
      title: '${s.label} — clusters in ${top.label}',
      detail: '$best of ${items.length} times in the last '
          '${kEmergentWindow.inDays} days it was recorded in ${top.label}. '
          'If that holds, ${top.plan}.',
    );
  }

  /// It simply keeps coming up. The weakest of the three, and the fallback
  /// when a situation recurs without clustering in time or defeating
  /// everything tried — still worth a worker knowing before the visit.
  RiskSignal _recurring(CareSituation s, List<CareApproach> items) {
    final int helped = items
        .where((CareApproach a) => a.outcome == ApproachOutcome.worked)
        .length;
    return RiskSignal(
      kind: 'emergent_recurring:${s.name}',
      level: RiskLevel.watch,
      title: '${s.label} — coming up often',
      detail: '${items.length} times in the last ${kEmergentWindow.inDays} '
          'days, ${helped > 0 ? "$helped handled with something that worked — "
              "check what works before the visit" : "with nothing recorded "
              "that clearly worked yet"}.',
    );
  }
}
