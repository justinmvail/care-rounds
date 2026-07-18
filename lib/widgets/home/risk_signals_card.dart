import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/risk_signal.dart';
import '../../providers/risk_signals_provider.dart';
import '../../theme.dart';

/// The "Watch for" dashboard card (Track-2 #18) — the active client's
/// early-warning signals (repeated falls, a medication running out), so a
/// worker sees rising need before it becomes a crisis. Each row states the
/// plain reason it fired; nothing here diagnoses.
///
/// Collapses to nothing when there are no signals, so a quiet client leaves
/// the dashboard unchanged (and owns its own bottom gap when shown).
class RiskSignalsCard extends ConsumerWidget {
  const RiskSignalsCard({super.key});

  static const Key cardKey = Key('home-risk-signals-card');
  static Key rowKey(String kind) => Key('home-risk-signals-row-$kind');

  static const double _radius = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RiskSignal> signals = ref.watch(clientRiskSignalsProvider);
    if (signals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: context.hc.surfaceWarm,
        borderRadius: BorderRadius.circular(_radius),
        child: Padding(
          key: cardKey,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Watch for',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.hc.primary,
                    ),
              ),
              const SizedBox(height: 8),
              for (final RiskSignal s in signals) _SignalRow(signal: s),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final RiskSignal signal;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final bool urgent = signal.level == RiskLevel.urgent;
    final Color accent = urgent ? context.hc.cta : context.hc.link;
    return Padding(
      key: RiskSignalsCard.rowKey(signal.kind),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            urgent ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  signal.title,
                  style: tt.bodyLarge?.copyWith(
                    color: context.hc.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.detail,
                  style: tt.bodyMedium?.copyWith(color: context.hc.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
