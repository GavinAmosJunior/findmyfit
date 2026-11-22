import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../services/samples.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import 'welcome_film.dart';

/// The first thing a new person sees, the way Apple introduces an app:
/// first why it exists, then how it works, then a way to try it.
///
/// 1. Why: never lose clothes to the laundry again.
/// 2. How: a film of the app in use (welcome_film.dart), four chapters in
///    the order you'd live them: add, pick an outfit, wear, check back.
///    The steps under it follow along; tap one to watch it.
/// 3. Try: fill the closet with sample clothes, or start empty.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _pages = 6;
  final _pager = PageController();
  int _page = 0;
  bool _working = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scenes and the last page use the sample art; have it ready.
    for (final a in Samples.assets) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Duration get _slide =>
      MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 420);

  void _next() {
    HapticFeedback.selectionClick();
    _pager.nextPage(duration: _slide, curve: Curves.easeInOutCubic);
  }

  /// Straight to the last page, where sample clothes are offered.
  void _skip() {
    HapticFeedback.selectionClick();
    _pager.animateToPage(_pages - 1, duration: _slide * 1.6, curve: Curves.easeInOutCubic);
  }

  Future<void> _finish({required bool samples}) async {
    if (_working) return;
    final state = AppScope.read(context);
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    HapticFeedback.lightImpact();
    try {
      if (samples) {
        await Samples.add(state, s);
        showMessageOn(messenger, s.samplesAdded);
      }
    } catch (e) {
      // Without samples the app still works; never strand someone here.
      debugPrint('Sample clothes skipped: $e');
    } finally {
      state.finishWelcome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final last = _page == _pages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip, top right, on every page but the last.
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: last,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(onPressed: _skip, child: Text(s.skip)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _HelloPage(s: s),
                  for (final (i, (title, body)) in [
                    (s.stepAddTitle, s.stepAddBody),
                    (s.stepFitTitle, s.stepFitBody),
                    (s.stepWearTitle, s.stepWearBody),
                    (s.stepCheckTitle, s.stepCheckBody),
                  ].indexed)
                    _FeaturePage(chapter: i, title: title, body: body, active: _page == i + 1),
                  _TryPage(s: s),
                ],
              ),
            ),
            _Dots(count: _pages, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : (last ? () => _finish(samples: true) : _next),
                  child: _working
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: context.colors.surface),
                        )
                      : Text(last ? s.useSamples : s.continueLabel),
                ),
              ),
            ),
            // Kept in place on every page so the button above never jumps.
            SizedBox(
              height: 48,
              child: AnimatedOpacity(
                opacity: last ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !last || _working,
                  child: TextButton(
                    onPressed: () => _finish(samples: false),
                    child: Text(s.startEmpty),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Plays its children in one after another, fading and rising a little,
/// the first time the page is shown.
class _Entrance extends StatefulWidget {
  final List<Widget> children;

  const _Entrance({required this.children});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _run.value = 1;
    } else if (!_run.isAnimating && _run.value == 0) {
      _run.forward();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, child) in widget.children.indexed)
          Builder(builder: (context) {
            final start = (i / (n + 1)) * 0.6;
            final t = CurvedAnimation(parent: _run, curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: t,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(t),
                child: child,
              ),
            );
          }),
      ],
    );
  }
}

/// A page that centers its content and scrolls when text is large.
class _Page extends StatelessWidget {
  final Widget child;

  const _Page({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: child)),
        ),
      ),
    );
  }
}

class _HelloPage extends StatelessWidget {
  final S s;

  const _HelloPage({required this.s});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Page(
      child: _Entrance(
        children: [
          Image.asset(dark ? 'assets/brand/logo_mark_dark.png' : 'assets/brand/logo_mark.png', width: 96, height: 96),
          const SizedBox(height: 36),
          Text(
            s.welcomeTitle,
            textAlign: TextAlign.center,
            style: context.text.displaySmall,
          ),
          const SizedBox(height: 18),
          Text(
            s.welcomeBody,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: context.palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// One idea per page, the way an iPhone sets itself up: a short film,
/// a big title and one line. The film plays once and rests; tap it to
/// play it again.
class _FeaturePage extends StatefulWidget {
  final int chapter;
  final String title;
  final String body;
  final bool active;

  const _FeaturePage({required this.chapter, required this.title, required this.body, required this.active});

  @override
  State<_FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<_FeaturePage> {
  int _take = 0;

  @override
  Widget build(BuildContext context) {
    return _Page(
      child: _Entrance(
        children: [
          GestureDetector(
            onTap: () => setState(() => _take++),
            child: FilmClock(
              key: ValueKey(_take),
              active: widget.active,
              still: filmSeconds * 0.9,
              // A beat to let the page settle before it plays.
              builder: (context, secs) =>
                  AppFilm(chapter: widget.chapter, t: secs % filmSeconds / filmSeconds),
            ),
          ),
          const SizedBox(height: 24),
          Text(widget.title, textAlign: TextAlign.center, style: context.text.headlineMedium),
          const SizedBox(height: 12),
          Text(
            widget.body,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: context.palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _TryPage extends StatelessWidget {
  final S s;

  const _TryPage({required this.s});

  @override
  Widget build(BuildContext context) {
    final art = Samples.preview;
    Widget tile(String asset) => AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.palette.tile, borderRadius: BorderRadius.circular(18)),
            child: Padding(padding: const EdgeInsets.all(10), child: Image.asset(asset)),
          ),
        );
    return _Page(
      child: _Entrance(
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: 10),
                    Expanded(child: tile(art[row * 3 + col])),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 26),
          Text(s.tryTitle, textAlign: TextAlign.center, style: context.text.headlineMedium),
          const SizedBox(height: 14),
          Text(
            s.tryBody,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: context.palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// Which page you're on, like the dots under an iPhone's home screens.
class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${current + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? context.ink : context.palette.separator,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
