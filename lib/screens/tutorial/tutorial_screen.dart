/// How-It-Works Tutorial — first-run carousel + replayable manual.
///
/// A full-screen swipeable carousel that explains the four-step EcoSwap loop
/// (discover → match → meet & swap → impact). It is shown ONCE automatically
/// the first time an authenticated user lands on [MainShell], and can be
/// replayed any time from the "How it works" row on the Profile screen.
///
/// The same widget serves both entry points — the only difference is the
/// [onDone] callback the caller supplies:
///   - First-run: persist the "seen" flag, then pop.
///   - Profile replay: just pop.
///
/// Locked-decision hygiene (CLAUDE.md):
///   - Vocabulary: "Swap" (user-facing), "swipe" (the gesture). Never "like".
///   - No GPS / km / distance language — "near you" refers to the bucket-based
///     proximity model, not a measured distance.
///   - No fabricated UI (age, verified badges, activity status).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// Persistence — "has the user seen the tutorial?" flag
// ---------------------------------------------------------------------------

/// SharedPreferences key for the first-run tutorial flag. Versioned so a
/// future content refresh can re-show the guide by bumping the suffix.
const String kTutorialSeenKey = 'has_seen_tutorial_v1';

/// Whether the first-run tutorial has already been shown on this device.
/// Returns false when nothing is stored yet (i.e. show it).
Future<bool> hasSeenTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kTutorialSeenKey) ?? false;
}

/// Marks the first-run tutorial as seen so it is not auto-shown again.
Future<void> markTutorialSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kTutorialSeenKey, true);
}

// ---------------------------------------------------------------------------
// Slide model + content
// ---------------------------------------------------------------------------

class _TutorialSlide {
  final IconData icon;
  final String title;
  final String body;

  const _TutorialSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// The four steps of the EcoSwap loop. Kept as a top-level const so a test can
/// assert the count without reaching into widget internals.
const List<_TutorialSlide> _kSlides = <_TutorialSlide>[
  _TutorialSlide(
    icon: Icons.style_outlined,
    title: 'Discover & swipe',
    body:
        'Browse swappers near you. Swipe right on someone whose item you want '
        '— and pick one of your own items to offer in return.',
  ),
  _TutorialSlide(
    icon: Icons.chat_bubble_outline,
    title: "Match & chat",
    body:
        "When you both swipe right, it's a match. Chat to agree on when and "
        'where to meet up.',
  ),
  _TutorialSlide(
    icon: Icons.qr_code_scanner,
    title: 'Meet & swap',
    body:
        'Meet in person and trade. One of you shows a QR code, the other scans '
        'it — that confirms the swap for both sides.',
  ),
  _TutorialSlide(
    icon: Icons.eco_outlined,
    title: 'Track your impact',
    body:
        'Every swap keeps CO₂ out of new production and diverts waste. '
        'Watch your impact grow on the Impact tab.',
  ),
];

// ---------------------------------------------------------------------------
// TutorialScreen
// ---------------------------------------------------------------------------

/// Full-screen "How it works" carousel.
///
/// [onDone] is invoked when the user finishes (taps "Get started" on the last
/// slide) or taps "Skip". The caller decides what done means — persist the
/// seen flag and pop (first-run), or simply pop (Profile replay).
///
/// [showSkip] controls whether the top-right "Skip" affordance is shown. It is
/// true for the first-run presentation and false when replayed from Profile
/// (where the app bar already provides a back/close affordance).
class TutorialScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool showSkip;

  const TutorialScreen({super.key, required this.onDone, this.showSkip = true});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _kSlides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: first-run shows "Skip" (right); replay shows a close
            // "X" (left). Either way the affordance calls onDone so the screen
            // can always be dismissed.
            SizedBox(
              height: 48,
              child: widget.showSkip
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('tutorialSkip'),
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: _kTextSecondary,
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('tutorialClose'),
                        icon: const Icon(Icons.close, size: 24),
                        color: _kTextPrimary,
                        tooltip: 'Close',
                        onPressed: widget.onDone,
                      ),
                    ),
            ),
            // Slides
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _kSlides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) => _SlideView(slide: _kSlides[index]),
              ),
            ),
            // Page dots
            _Dots(count: _kSlides.length, active: _page),
            const SizedBox(height: 20),
            // Primary CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('tutorialNext'),
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreenPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(_isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SlideView — one full-screen slide
// ---------------------------------------------------------------------------

class _SlideView extends StatelessWidget {
  final _TutorialSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon medallion
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: _kGreenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 52, color: _kGreenPrimary),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Dots — page indicator
// ---------------------------------------------------------------------------

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? _kGreenDark : _kTextTertiary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
