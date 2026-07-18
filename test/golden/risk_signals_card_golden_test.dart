import 'package:alchemist/alchemist.dart';
import 'package:carerounds/models/risk_signal.dart';
import 'package:carerounds/providers/risk_signals_provider.dart';
import 'package:carerounds/theme.dart';
import 'package:carerounds/widgets/home/risk_signals_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Golden of Home's "Watch for" early-warning card (Track-2 #18) — an urgent
/// refill signal over a watch-level fall trend, each with its plain reason.
void main() {
  group('RiskSignalsCard golden', () {
    goldenTest(
      "early-warning signals for the active client",
      fileName: 'risk_signals_card',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'urgent + watch',
            child: ProviderScope(
              overrides: <Override>[
                clientRiskSignalsProvider.overrideWithValue(const <RiskSignal>[
                  RiskSignal(
                    kind: 'refill_out',
                    level: RiskLevel.urgent,
                    title: 'No refills left',
                    detail:
                        'Atorvastatin has no refills left — contact the '
                        'pharmacy or prescriber before it runs out.',
                  ),
                  RiskSignal(
                    kind: 'falls_3plus_7d',
                    level: RiskLevel.watch,
                    title: 'Recent falls',
                    detail: '3+ falls this week. Worth mentioning at the next '
                        'visit.',
                  ),
                ]),
              ],
              child: SizedBox(
                width: 390,
                height: 300,
                child: MaterialApp(
                  home: Scaffold(
                    backgroundColor: careroundsColors.background,
                    body: const SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: RiskSignalsCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}
