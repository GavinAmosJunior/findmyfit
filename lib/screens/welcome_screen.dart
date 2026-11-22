import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../services/samples.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'welcome_scenes.dart';

/// The first thing a new person sees, in the spirit of setting up a new
/// iPhone: calm pages, one idea each, big bold titles, and one clear
/// button at the bottom. Each idea plays as a small looping film (see
/// welcome_scenes.dart): scanning a piece, shuffling a fit, Wore it into
/// the hamper, and checking a load back in. The last page offers sample
/// clothes, so the app can be tried before photographing a single piece.
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
    setState(() => _working = true);
    HapticFeedback.lightImpact();
    try {
      if (samples) await Samples.add(state, s);
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
                  _FeaturePage(
                    scene: ScanScene(active: _page == 1),
                    title: s.scanTitle,
                    body: s.scanBody,
                  ),
                  _FeaturePage(
                    scene: ShuffleScene(active: _page == 2),
                    title: s.shuffleTitle,
                    body: s.shuffleBody,
                  ),
                  _FeaturePage(
                    scene: HamperScene(active: _page == 3),
                    title: s.hamperTitle,
                    body: s.hamperBody,
                  ),
                  _FeaturePage(
                    scene: CheckScene(active: _page == 4),
                    title: s.checkTitle,
                    body: s.checkBody,
                  ),
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
            style: context.text.displaySmall?.copyWith(fontSize: 40, letterSpacing: -1.4),
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

/// One idea: its little film, a bold title and a line or two.
class _FeaturePage extends StatelessWidget {
  final Widget scene;
  final String title;
  final String body;

  const _FeaturePage({required this.scene, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return _Page(
      child: _Entrance(
        children: [
          scene,
          const SizedBox(height: 28),
          Text(title, textAlign: TextAlign.center, style: context.text.headlineMedium),
          const SizedBox(height: 14),
          Text(
            body,
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
