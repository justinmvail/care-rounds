import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/onboarding_provider.dart';
import '../../theme.dart';

/// Three-page welcome carousel (BUILD_SPEC.md §5.11).
///
/// Each page renders the verbatim copy locked in §5.11 — the strings
/// are exposed as a const list on [WelcomeCarousel.pages] so screen
/// tests assert against the same source the widget reads.
///
/// Both the top-right "Skip" and the bottom CTA hand off to `/sign-in`.
/// On page 3 the CTA reads "Get started" and additionally flips
/// [onboardingCompletedProvider] true so the router redirect stops
/// bouncing the caregiver back here on the next launch. **Skip does NOT
/// flip that flag** — the value prop must stay reachable if a reflexive
/// Skip happens (the router lets `/sign-in` through the onboarding gate),
/// and a successful sign-in completes onboarding instead.
class WelcomeCarousel extends ConsumerStatefulWidget {
  const WelcomeCarousel({super.key});

  /// Widget keys for tests. Tests address by key (not by visible copy)
  /// so a wording edit doesn't ripple into a test rewrite.
  static const Key pageViewKey = Key('welcome-carousel-pageview');
  static const Key skipButtonKey = Key('welcome-carousel-skip');
  static const Key primaryCtaKey = Key('welcome-carousel-cta');
  static const Key dotIndicatorKey = Key('welcome-carousel-dots');

  /// The three pages' copy, locked verbatim against BUILD_SPEC.md
  /// §5.11. Exposed so screen tests compare against the same source.
  static const List<WelcomeCarouselPage> pages = <WelcomeCarouselPage>[
    WelcomeCarouselPage(
      glyph: 'H',
      title: 'Care Rounds',
      body: 'Your whole caseload, organized — with a coach for every visit.',
      subtitle: 'Meds, schedules, and shift-by-shift guidance grounded in '
          'each client\'s real care.',
    ),
    WelcomeCarouselPage(
      glyph: '📱',
      title: 'A coach that knows each client.',
      body:
          'Before a visit or right in the moment, get step-by-step guidance '
          'grounded in that client\'s care — and a clear nudge to flag your '
          'supervisor when something needs more than you.',
    ),
    WelcomeCarouselPage(
      glyph: '📔',
      title: 'Notes that write themselves.',
      body:
          'Speak your visit notes and we turn them into the record. Less '
          'paperwork at the end of a shift, more time with the people you '
          'care for.',
    ),
  ];

  @override
  ConsumerState<WelcomeCarousel> createState() => _WelcomeCarouselState();
}

class _WelcomeCarouselState extends ConsumerState<WelcomeCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _page == WelcomeCarousel.pages.length - 1;

  void _onCtaPressed() {
    if (_isLastPage) {
      ref.read(onboardingCompletedProvider.notifier).complete();
      context.go('/sign-in');
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _onSkipPressed() {
    // Skip does NOT mark onboarding complete (UIUX_REVIEW: doing so made
    // the value prop reachable exactly once — a reflexive Skip in the
    // first two seconds permanently deleted the only explanation of what
    // Care Rounds is). Onboarding is marked complete only by "Get started"
    // or a successful sign-in; the router's onboarding gate lets `/sign-in`
    // through even while incomplete, so a skipper who has second thoughts
    // can still get back to the carousel.
    context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.hc.background,
      appBar: AppBar(
        backgroundColor: context.hc.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              label: l10n.welcomeSkipSemantics,
              child: TextButton(
                key: WelcomeCarousel.skipButtonKey,
                onPressed: _onSkipPressed,
                child: Text(
                  l10n.commonSkip,
                  style: textTheme.labelLarge?.copyWith(
                    color: context.hc.primarySoft,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                key: WelcomeCarousel.pageViewKey,
                controller: _controller,
                itemCount: WelcomeCarousel.pages.length,
                onPageChanged: (int index) => setState(() => _page = index),
                itemBuilder: (BuildContext context, int index) {
                  return _PageBody(page: WelcomeCarousel.pages[index]);
                },
              ),
            ),
            _DotIndicator(
              key: WelcomeCarousel.dotIndicatorKey,
              count: WelcomeCarousel.pages.length,
              active: _page,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: WelcomeCarousel.primaryCtaKey,
                  onPressed: _onCtaPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.hc.ctaFilled,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _isLastPage
                        ? l10n.welcomeGetStartedCta
                        : l10n.welcomeNextCta,
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final WelcomeCarouselPage page;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Page 1 (glyph sentinel 'H') renders the Care Rounds "rounds"
          // brand mark — a teal tile with a white orbit ring + amber
          // waypoint. Pages 2 & 3 keep their emoji glyphs in a plain teal
          // block since they're feature illustrations, not brand marks.
          // The AppIcon / LaunchImage PNGs still carry the old mark and are
          // a separate raster regen (follow-up).
          if (page.glyph == 'H')
            const _RoundsBrandMark()
          else
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.hc.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              // Decorative feature glyph — ExcludeSemantics so VoiceOver /
              // TalkBack don't announce "pill" / "speech balloon" before the
              // real title + body (UIUX_REVIEW: a11y on the first impression).
              child: ExcludeSemantics(
                child: Text(
                  page.glyph,
                  style: textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 56,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (page.subtitle != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              page.subtitle!,
              style: textTheme.bodyLarge?.copyWith(
                color: context.hc.primarySoft,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    super.key,
    required this.count,
    required this.active,
  });

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == active ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              // Navy active dot, dimmed navy for inactive. Orange is
              // reserved for the CTA button below — using it here
              // doubled the orange surface area on the carousel.
              color: i == active
                  ? context.hc.primary
                  : context.hc.primarySoft.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// One page in the welcome carousel — glyph + title + body. Top-level
/// so the screen test asserts against the same const list the widget
/// reads. Fields map 1:1 onto BUILD_SPEC.md §5.11's locked copy;
/// changes here are spec changes.
@immutable
class WelcomeCarouselPage {
  const WelcomeCarouselPage({
    required this.glyph,
    required this.title,
    required this.body,
    this.subtitle,
  });

  final String glyph;
  final String title;
  final String body;

  /// Optional concrete value-prop line rendered beneath [body] (page 1
  /// only, today). Null on the feature pages, which carry their value in
  /// [body] already.
  final String? subtitle;
}

/// The Care Rounds "rounds" mark: a deep-teal rounded tile carrying a white
/// orbit ring with a single amber waypoint dot — a caregiver's circuit of
/// visits. Deliberately distinct from Holdclose's "Hc" split mark. Sized at
/// 120×120 to drop into the carousel's logo slot.
class _RoundsBrandMark extends StatelessWidget {
  const _RoundsBrandMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 120,
        height: 120,
        color: context.hc.primary,
        child: Center(
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                // The orbit ring — Positioned.fill so the DecoratedBox takes
                // the whole 84×84 box (a bare DecoratedBox has no child and
                // would collapse to zero size, hiding the ring).
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 11),
                    ),
                  ),
                ),
                // The amber waypoint sitting on the ring at 12 o'clock.
                Positioned(
                  top: -5,
                  left: 31,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.hc.cta,
                      border: Border.all(color: context.hc.primary, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
