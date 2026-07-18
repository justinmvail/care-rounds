import 'package:carerounds/models/risk_signal.dart';
import 'package:carerounds/providers/risk_signals_provider.dart';
import 'package:carerounds/widgets/home/risk_signals_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

Future<void> _pump(WidgetTester tester, List<RiskSignal> signals) async {
  await tester.binding.setSurfaceSize(const Size(390, 780));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        clientRiskSignalsProvider.overrideWithValue(signals),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: RiskSignalsCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders each signal with its title + reason',
      (WidgetTester tester) async {
    await _pump(tester, const <RiskSignal>[
      RiskSignal(
        kind: 'falls_3plus_7d',
        level: RiskLevel.urgent,
        title: 'Recent falls',
        detail: '3+ falls this week.',
      ),
      RiskSignal(
        kind: 'refill_soon',
        level: RiskLevel.watch,
        title: 'Running low',
        detail: 'Aspirin runs out around Jul 22.',
      ),
    ]);

    expect(find.byKey(RiskSignalsCard.cardKey), findsOneWidget);
    expect(find.text('Watch for'), findsOneWidget);
    expect(find.byKey(RiskSignalsCard.rowKey('falls_3plus_7d')), findsOneWidget);
    expect(find.byKey(RiskSignalsCard.rowKey('refill_soon')), findsOneWidget);
    expect(find.text('Recent falls'), findsOneWidget);
    expect(find.textContaining('Aspirin runs out'), findsOneWidget);
  });

  testWidgets('collapses to nothing when there are no signals',
      (WidgetTester tester) async {
    await _pump(tester, const <RiskSignal>[]);
    expect(find.byKey(RiskSignalsCard.cardKey), findsNothing);
    expect(find.text('Watch for'), findsNothing);
  });
}
