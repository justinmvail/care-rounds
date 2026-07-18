import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The 10 brand color tokens from BUILD_SPEC.md §3.1.
///
/// Source of truth for every color used in screen build methods. Read
/// these via `Theme.of(context).colorScheme.X` or `careroundsColors.X`
/// — never as raw hex.
@immutable
class CareRoundsColors extends ThemeExtension<CareRoundsColors> {
  const CareRoundsColors({
    required this.primary,
    required this.primarySoft,
    required this.text,
    required this.cta,
    required this.ctaFilled,
    required this.accentDeep,
    required this.surfaceWarm,
    required this.background,
    required this.link,
    required this.error,
    required this.success,
  });

  final Color primary;
  final Color primarySoft;
  final Color text;

  /// The salmon brand accent. Use for DECORATIVE, non-text-bearing marks
  /// (icons, chip tints, borders, focus rings). At 3.43:1 white text on
  /// this fails WCAG-AA, so it is NOT a filled-button background — use
  /// [ctaFilled] for anything that carries white/on-secondary label text.
  final Color cta;

  /// Accessible filled-CTA background. Darker than [cta] so white
  /// (`onSecondary`) text on it clears WCAG-AA (4.72:1 in light mode).
  /// Every filled primary button (ElevatedButton / FilledButton / FAB)
  /// reads its background from here and its foreground from
  /// `colorScheme.onSecondary`, so dark mode pairs correctly.
  final Color ctaFilled;

  final Color accentDeep;
  final Color surfaceWarm;
  final Color background;
  final Color link;
  final Color error;
  final Color success;

  @override
  CareRoundsColors copyWith({
    Color? primary,
    Color? primarySoft,
    Color? text,
    Color? cta,
    Color? ctaFilled,
    Color? accentDeep,
    Color? surfaceWarm,
    Color? background,
    Color? link,
    Color? error,
    Color? success,
  }) {
    return CareRoundsColors(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      text: text ?? this.text,
      cta: cta ?? this.cta,
      ctaFilled: ctaFilled ?? this.ctaFilled,
      accentDeep: accentDeep ?? this.accentDeep,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      background: background ?? this.background,
      link: link ?? this.link,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  CareRoundsColors lerp(
    covariant ThemeExtension<CareRoundsColors>? other,
    double t,
  ) {
    if (other is! CareRoundsColors) return this;
    return CareRoundsColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      cta: Color.lerp(cta, other.cta, t)!,
      ctaFilled: Color.lerp(ctaFilled, other.ctaFilled, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      background: Color.lerp(background, other.background, t)!,
      link: Color.lerp(link, other.link, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Light brand palette (BUILD_SPEC.md §3.1). Source of truth for light
/// mode and the safe const fallback for any context that can't reach a
/// [BuildContext] (theme construction, top-level functions, static data).
// Care Rounds brand palette — "Teal & Amber" (deliberately distinct from
// Holdclose's warm navy + salmon). Deep teal reads professional, clean, and
// trustworthy for a direct-care-team tool; a warm amber accent supplies the
// energy (the mic, active states, highlights). Cool mist surfaces replace
// Holdclose's warm cream.
const CareRoundsColors careroundsColors = CareRoundsColors(
  primary: Color(0xFF0E5C57),
  primarySoft: Color(0xFF157A72),
  text: Color(0xFF1B2B29),
  // Decorative amber accent (icons / borders / highlights — NOT white-text).
  cta: Color(0xFFE8973C),
  // Filled-button background: deep teal carries white text at ~5.4:1
  // (WCAG-AA pass), keeping the button system accessible without a per-widget
  // foreground audit. Amber stays the decorative accent on [cta].
  ctaFilled: Color(0xFF0B665E),
  // Deep amber for amber-toned text/borders that need AA on white (~4.9:1).
  accentDeep: Color(0xFFB4711A),
  surfaceWarm: Color(0xFFEDF4F2),
  background: Color(0xFFFFFFFF),
  link: Color(0xFF127A72),
  error: Color(0xFFCF2E2E),
  success: Color(0xFF2E7D5B),
);

// Dark palette derived per BUILD_SPEC.md §3.1: navy surface, warm-white
// text, orange CTA unchanged.
const Color _darkSurface = Color(0xFF0B1615);
const Color _darkSurfaceVariant = Color(0xFF13211F);
const Color _darkText = Color(0xFFE6EBE9);

/// Dark brand palette. Same token slots as [careroundsColors] but tuned
/// for a dark navy/charcoal canvas:
/// - `background`/`surfaceWarm` become dark navy + a slightly lifted
///   variant so cards separate from the scaffold.
/// - `text` is the warm off-white `_darkText` (≈13.5:1 on `_darkSurface`,
///   well past WCAG-AA for body text).
/// - `primary`/`primarySoft` (used for headings, icons, chips) are
///   lightened to a pale slate-blue so navy-on-navy stays legible.
/// - `cta`/`accentDeep` (the brand orange) are nudged brighter so the CTA
///   keeps AA contrast on the dark canvas while staying on-brand.
/// - `link`/`error`/`success` are lightened for contrast on dark.
const CareRoundsColors careroundsColorsDark = CareRoundsColors(
  primary: Color(0xFF6FD0C4),
  primarySoft: Color(0xFF4FA89E),
  text: _darkText,
  cta: Color(0xFFF0A94E),
  // Filled-button background on dark: bright teal that pairs with the
  // dark `onSecondary`, so it carries dark text at high contrast.
  ctaFilled: Color(0xFF2AA99B),
  accentDeep: Color(0xFFE8973C),
  surfaceWarm: _darkSurfaceVariant,
  background: _darkSurface,
  link: Color(0xFF5FB8AE),
  error: Color(0xFFF06A6A),
  success: Color(0xFF5FBF8C),
);

/// Reads the active [CareRoundsColors] theme extension off [context],
/// falling back to the light const if no ancestor theme registered one
/// (keeps tests + stray contexts safe — never crashes, never returns
/// null).
extension CareRoundsColorsContext on BuildContext {
  CareRoundsColors get hc =>
      Theme.of(this).extension<CareRoundsColors>() ?? careroundsColors;
}

TextTheme _careroundsTextTheme({
  required Color bodyColor,
  required Color headingColor,
}) {
  return TextTheme(
    displayLarge: GoogleFonts.sora(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: headingColor,
    ),
    headlineLarge: GoogleFonts.sora(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: headingColor,
    ),
    headlineMedium: GoogleFonts.sora(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: headingColor,
    ),
    titleLarge: GoogleFonts.sora(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: headingColor,
    ),
    bodyLarge: GoogleFonts.lato(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
    bodyMedium: GoogleFonts.lato(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
    labelLarge: GoogleFonts.lato(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: bodyColor,
    ),
  );
}

ThemeData _buildLightTheme() {
  const ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0E5C57),
    onPrimary: Color(0xFFFFFFFF),
    // `secondary` is the FILLED-CTA background (the accessible deep teal
    // #0B665E), so `onSecondary` white text on a filled button clears
    // WCAG-AA. The decorative amber accent stays on `cr.cta`.
    secondary: Color(0xFF0B665E),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF0B665E),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFCF2E2E),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1B2B29),
    surfaceContainerHighest: Color(0xFFEDF4F2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: careroundsColors.background,
    extensions: const <ThemeExtension<dynamic>>[careroundsColors],
    textTheme: _careroundsTextTheme(
      bodyColor: careroundsColors.text,
      headingColor: careroundsColors.primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: careroundsColors.background,
      foregroundColor: careroundsColors.primary,
      elevation: 0,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: careroundsColors.primary,
      ),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final ColorScheme scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: careroundsColorsDark.primary,
    onPrimary: _darkSurface,
    secondary: careroundsColorsDark.cta,
    onSecondary: _darkSurface,
    tertiary: careroundsColorsDark.accentDeep,
    onTertiary: _darkSurface,
    error: careroundsColorsDark.error,
    onError: _darkSurface,
    surface: _darkSurface,
    onSurface: _darkText,
    surfaceContainerHighest: _darkSurfaceVariant,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: _darkSurface,
    extensions: const <ThemeExtension<dynamic>>[careroundsColorsDark],
    textTheme: _careroundsTextTheme(
      bodyColor: _darkText,
      headingColor: _darkText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkText,
      elevation: 0,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _darkText,
      ),
    ),
  );
}

final ThemeData careroundsLightTheme = _buildLightTheme();
final ThemeData careroundsDarkTheme = _buildDarkTheme();
