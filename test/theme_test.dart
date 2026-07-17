import 'dart:async';
import 'dart:math' as math;

import 'package:carerounds/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // google_fonts touches the asset bundle / network on TextStyle
  // construction; the binding has to be live for those calls.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The font files aren't bundled in test assets and tests must not
    // hit the network. google_fonts fires fire-and-forget Futures from
    // TextStyle construction; when those fail (no asset, no network),
    // the errors surface as uncaught zone errors and fail unrelated
    // tests. Pre-initialize both themes inside a guarded zone here so
    // every loading future is rooted in a zone that swallows its
    // errors. Subsequent tests read the cached themes — no new loads.
    GoogleFonts.config.allowRuntimeFetching = false;
    final Completer<void> initialized = Completer<void>();
    unawaited(runZonedGuarded(
      () async {
        // Force lazy init of both themes inside this zone.
        careroundsLightTheme.toString();
        careroundsDarkTheme.toString();
        try {
          await GoogleFonts.pendingFonts();
        } catch (_) {
          // expected — fonts aren't bundled in tests
        }
        if (!initialized.isCompleted) initialized.complete();
      },
      (Object error, StackTrace stack) {
        // Swallow font-load errors only. Anything else is a real bug.
        final String message = error.toString();
        if (message.contains('google_fonts') ||
            message.contains('GoogleFonts') ||
            message.contains('was not found in the application assets') ||
            message.contains('Failed to load font')) {
          return;
        }
        if (!initialized.isCompleted) {
          initialized.completeError(error, stack);
        }
      },
    ));
    await initialized.future;
  });

  group('CareRoundsColors', () {
    test('all 10 tokens match BUILD_SPEC.md §3.1 verbatim', () {
      expect(careroundsColors.primary, const Color(0xFF1F2A44));
      expect(careroundsColors.primarySoft, const Color(0xFF2A3B61));
      expect(careroundsColors.text, const Color(0xFF33373D));
      expect(careroundsColors.cta, const Color(0xFFC97458));
      // Accessible filled-CTA background: white text on it clears WCAG-AA.
      expect(careroundsColors.ctaFilled, const Color(0xFFB05C40));
      expect(careroundsColors.accentDeep, const Color(0xFFB05C40));
      expect(careroundsColors.surfaceWarm, const Color(0xFFF8F6F3));
      expect(careroundsColors.background, const Color(0xFFFFFFFF));
      expect(careroundsColors.link, const Color(0xFF4054B2));
      expect(careroundsColors.error, const Color(0xFFCF2E2E));
      expect(careroundsColors.success, const Color(0xFF2A7C4F));
    });
  });

  group('CTA contrast (WCAG-AA)', () {
    // Relative luminance + contrast ratio per WCAG 2.x.
    double channel(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    double luminance(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    double contrast(Color a, Color b) {
      final double la = luminance(a) + 0.05;
      final double lb = luminance(b) + 0.05;
      return la > lb ? la / lb : lb / la;
    }

    test('white on the filled-CTA background clears AA (>= 4.5:1)', () {
      final double ratio = contrast(
        Colors.white,
        careroundsColors.ctaFilled,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('white on the DECORATIVE salmon would FAIL AA (documents the '
        'reason the filled token exists)', () {
      final double ratio = contrast(Colors.white, careroundsColors.cta);
      expect(ratio, lessThan(4.5));
    });
  });

  group('careroundsLightTheme', () {
    test('uses Material 3', () {
      expect(careroundsLightTheme.useMaterial3, isTrue);
    });

    test('brightness is light', () {
      expect(careroundsLightTheme.brightness, Brightness.light);
    });

    test('colorScheme.primary is the navy brand token (#1F2A44)', () {
      expect(careroundsLightTheme.colorScheme.primary, const Color(0xFF1F2A44));
      expect(careroundsLightTheme.colorScheme.primary, careroundsColors.primary);
    });

    test('colorScheme.secondary is the accessible filled-CTA background '
        '(#B05C40), not the lighter decorative salmon', () {
      // Filled buttons read their background from `secondary` and foreground
      // from `onSecondary`; the decorative salmon (`cb.cta`) is too light for
      // white text (3.43:1). `secondary` is the darker AA-passing tone.
      expect(
        careroundsLightTheme.colorScheme.secondary,
        careroundsColors.ctaFilled,
      );
      expect(careroundsLightTheme.colorScheme.secondary, const Color(0xFFB05C40));
    });

    test('colorScheme.tertiary is accentDeep (#B05C40)', () {
      expect(careroundsLightTheme.colorScheme.tertiary, careroundsColors.accentDeep);
    });

    test('colorScheme.error is the brand error red', () {
      expect(careroundsLightTheme.colorScheme.error, careroundsColors.error);
    });

    test('surface is white and surfaceContainerHighest is surfaceWarm', () {
      expect(careroundsLightTheme.colorScheme.surface, careroundsColors.background);
      expect(
        careroundsLightTheme.colorScheme.surfaceContainerHighest,
        careroundsColors.surfaceWarm,
      );
    });

    test('onSurface is the warm body-text color (#33373D)', () {
      expect(careroundsLightTheme.colorScheme.onSurface, careroundsColors.text);
    });

    test('scaffoldBackgroundColor is the brand background', () {
      expect(
        careroundsLightTheme.scaffoldBackgroundColor,
        careroundsColors.background,
      );
    });

    group('textTheme maps to BUILD_SPEC.md §3.2 type ramp', () {
      test('displayLarge — Montserrat 700 / 32', () {
        final TextStyle style = careroundsLightTheme.textTheme.displayLarge!;
        expect(style.fontSize, 32);
        expect(style.fontWeight, FontWeight.w700);
      });

      test('headlineLarge — Montserrat 700 / 26', () {
        final TextStyle style = careroundsLightTheme.textTheme.headlineLarge!;
        expect(style.fontSize, 26);
        expect(style.fontWeight, FontWeight.w700);
      });

      test('headlineMedium — Montserrat 600 / 22', () {
        final TextStyle style = careroundsLightTheme.textTheme.headlineMedium!;
        expect(style.fontSize, 22);
        expect(style.fontWeight, FontWeight.w600);
      });

      test('titleLarge — Montserrat 600 / 20', () {
        final TextStyle style = careroundsLightTheme.textTheme.titleLarge!;
        expect(style.fontSize, 20);
        expect(style.fontWeight, FontWeight.w600);
      });

      test('bodyLarge — Lato 400 / 20 (large default per audience)', () {
        final TextStyle style = careroundsLightTheme.textTheme.bodyLarge!;
        expect(style.fontSize, 20);
        expect(style.fontWeight, FontWeight.w400);
      });

      test('bodyMedium — Lato 400 / 16', () {
        final TextStyle style = careroundsLightTheme.textTheme.bodyMedium!;
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w400);
      });

      test('labelLarge — Lato 700 / 18', () {
        final TextStyle style = careroundsLightTheme.textTheme.labelLarge!;
        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w700);
      });
    });
  });

  group('careroundsDarkTheme', () {
    test('uses Material 3', () {
      expect(careroundsDarkTheme.useMaterial3, isTrue);
    });

    test('brightness is dark', () {
      expect(careroundsDarkTheme.brightness, Brightness.dark);
    });

    test('surface is the dark navy (#0F1422)', () {
      expect(careroundsDarkTheme.colorScheme.surface, const Color(0xFF0F1422));
    });

    test('onSurface is the warm-white text (#E8E6E2)', () {
      expect(careroundsDarkTheme.colorScheme.onSurface, const Color(0xFFE8E6E2));
    });

    test('secondary is the dark-palette CTA (brightened for contrast)', () {
      // Dark mode brightens the brand orange so the CTA keeps AA contrast
      // on the dark canvas; it intentionally differs from the light CTA.
      expect(
        careroundsDarkTheme.colorScheme.secondary,
        careroundsColorsDark.cta,
      );
    });

    test('primary is the dark-palette primary (lightened slate-blue)', () {
      // Navy-on-navy is illegible, so dark mode lifts `primary` to a pale
      // slate-blue for headings/icons/chips.
      expect(
        careroundsDarkTheme.colorScheme.primary,
        careroundsColorsDark.primary,
      );
    });

    test('registers the dark CareRoundsColors extension', () {
      expect(
        careroundsDarkTheme.extension<CareRoundsColors>(),
        same(careroundsColorsDark),
      );
    });

    test('light theme registers the light CareRoundsColors extension', () {
      expect(
        careroundsLightTheme.extension<CareRoundsColors>(),
        same(careroundsColors),
      );
    });

    test('scaffoldBackgroundColor matches the dark surface', () {
      expect(
        careroundsDarkTheme.scaffoldBackgroundColor,
        const Color(0xFF0F1422),
      );
    });
  });
}
