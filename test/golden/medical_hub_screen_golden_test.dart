import 'package:alchemist/alchemist.dart';
import 'package:carerounds/models/settings.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:carerounds/screens/medical/medical_hub_screen.dart';
import 'package:carerounds/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// Golden of the Care hub — the nine tiles grouped into three labelled
/// sections ("This visit", "Client info", "Team & training"; Track-2 #31).
/// The Team tile is always shown now, so this golden pins the full sectioned
/// landing.
///
/// No theme is passed: per `flutter_test_config.dart`, goldens avoid dragging
/// google_fonts through the framework; the hub's [PathHeader] + [HubTile]
/// children re-apply their brand colors directly.
InMemoryStorageProvider _teamOffStorage() {
  final InMemoryStorageProvider storage = InMemoryStorageProvider();
  storage.updateSettings(
    AppSettings.defaults().copyWith(teamCoordinationEnabled: false),
  );
  return storage;
}

void main() {
  group('MedicalHubScreen golden', () {
    goldenTest(
      'renders the sectioned 9-tile hub landing',
      fileName: 'medical_hub_screen',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          GoldenTestScenario(
            name: 'care hub — 7 tiles (Phase 14.15)',
            child: SizedBox(
              width: 420,
              height: 820,
              child: ProviderScope(
                overrides: <Override>[
                  storageProvider.overrideWithValue(_teamOffStorage()),
                ],
                child: MaterialApp(
                  builder: (BuildContext context, Widget? child) => ColoredBox(
                    color: careroundsColors.background,
                    child: child ?? const SizedBox.shrink(),
                  ),
                  home: const MedicalHubScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}
