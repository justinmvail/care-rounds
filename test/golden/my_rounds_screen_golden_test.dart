import 'package:alchemist/alchemist.dart';
import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/providers/my_rounds_provider.dart';
import 'package:carerounds/screens/settings/loved_ones_screen.dart';
import 'package:carerounds/screens/team/my_rounds_screen.dart';
import 'package:carerounds/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

CareShift _shift(
  String id,
  DateTime start, {
  String patient = 'clientA',
  String? notes,
}) =>
    CareShift(
      id: id,
      caregiverId: 'me',
      start: start,
      end: start.add(const Duration(hours: 2)),
      patientId: patient,
      notes: notes,
    );

/// Golden of "My Rounds" (Care Rounds) in its populated state — the signed-in
/// worker's shifts across clients, grouped by day. No theme is passed: per
/// `flutter_test_config.dart`, goldens avoid dragging google_fonts through the
/// framework, and `context.hc` falls back to the default brand palette.
void main() {
  group('MyRoundsScreen golden', () {
    goldenTest(
      'renders a day of rounds across clients',
      fileName: 'my_rounds_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'my rounds — shifts across clients',
            child: SizedBox(
              width: 420,
              height: 820,
              child: ProviderScope(
                overrides: <Override>[
                  selfCaregiverIdProvider
                      .overrideWith((Ref ref) async => 'me'),
                  myRoundsProvider.overrideWith(
                    (Ref ref) async => <CareShift>[
                      _shift('s1', DateTime(2026, 6, 1, 8),
                          notes: 'Morning meds'),
                      _shift('s2', DateTime(2026, 6, 1, 13),
                          patient: 'clientB'),
                    ],
                  ),
                  lovedOnesViewProvider.overrideWith(
                    (Ref ref) async => const LovedOnesView(
                        patients: [], activeId: null),
                  ),
                ],
                child: MaterialApp(
                  builder: (BuildContext context, Widget? child) => ColoredBox(
                    color: careroundsColors.background,
                    child: child,
                  ),
                  home: const MyRoundsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}
