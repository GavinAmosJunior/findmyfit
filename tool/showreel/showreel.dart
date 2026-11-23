import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smart_laundry_tracker/l10n/strings.dart';
import 'package:smart_laundry_tracker/screens/welcome_film.dart';
import 'package:smart_laundry_tracker/theme/app_theme.dart';

/// A 30-second, 16:9 showreel of FindMyFit, cut like an iPhone launch
/// film but in white: a few big words that come in out of a blur, the
/// name lit by a passing light, the app floating and turning slowly in
/// 3D beside each feature, a run of quick cuts, then the name. Fast, and
/// it loops white to white.
///
/// Drawn at 960×540 and rendered at 2× (1920×1080) by render_test.dart.
const reelSeconds = 30.0;
const reelSize = Size(960, 540);

const _ink = Color(0xFF1D1D1F);
const _gray = Color(0xFF6E6E73);

/// When each feature starts, in seconds; each runs [_feature] seconds.
const _features = [5.0, 8.4, 11.8, 15.2];
const _feature = 3.4;

/// The quick cuts: a word, then the app close on what it means.
const _montageStart = 18.7;
const _cut = 0.8;
const _cuts = <(String?, int, double, double, Alignment)>[
  ('Snap.', 0, 0, 0, Alignment.center),
  (null, 0, 0.55, 0.85, Alignment(0, -0.1)),
  ('Shuffle.', 0, 0, 0, Alignment.center),
  (null, 1, 0.24, 0.5, Alignment(0, -0.2)),
  ('Wear.', 0, 0, 0, Alignment.center),
  (null, 2, 0.5, 0.75, Alignment(0.2, 0.9)),
  ('Find.', 0, 0, 0, Alignment.center),
  (null, 3, 0.55, 0.85, Alignment(0, -0.1)),
];
const _endStart = _montageStart + _cut * 8;

class Showreel extends StatelessWidget {
  /// Seconds into the reel.
  final double time;
  final String by;

  const Showreel({super.key, required this.time, required this.by});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final steps = [
      (s.stepAddTitle, s.stepAddBody),
      (s.stepFitTitle, s.stepFitBody),
      (s.stepWearTitle, s.stepWearBody),
      (s.stepCheckTitle, s.stepCheckBody),
    ];
    final cut = ((time - _montageStart) / _cut).floor();
    return SizedBox.fromSize(
      size: reelSize,
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The problem, in two beats, then the answer.
            if (time < 1.9) _Line(local: time - 0.2, length: 1.7, words: const ['Clothes', 'go', 'to', 'the', 'laundry.']),
            if (time >= 1.9 && time < 3.4) _Line(local: time - 1.9, length: 1.5, words: const ['Not', 'all', 'come', 'back.'], dim: 2),
            if (time >= 3.4 && time < 5.0) _Name(local: time - 3.4, length: 1.6),
            for (final (i, start) in _features.indexed)
              if (time >= start && time < start + _feature)
                _Feature(local: time - start, chapter: i, title: steps[i].$1, body: steps[i].$2, flip: i.isOdd),
            if (cut >= 0 && cut < _cuts.length) _Cut(local: time - _montageStart - cut * _cut, cut: _cuts[cut]),
            if (time >= _endStart) _End(local: time - _endStart, length: reelSeconds - _endStart, by: by),
          ],
        ),
      ),
    );
  }
}

/// 0 → 1 between [a] and [b], eased.
double _ease(double x, double a, double b, [Curve c = Curves.easeInOutCubic]) =>
    c.transform(((x - a) / (b - a)).clamp(0.0, 1.0));

/// Comes out of a blur, settling from a touch larger, and leaves the same
/// way, quickly: the launch-film entrance.
class _Focus extends StatelessWidget {
  final double local;
  final double length;
  final double delay;
  final Widget child;

  const _Focus({required this.local, required this.length, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final inT = _ease(local, delay, delay + 0.45, Curves.easeOutCubic);
    final out = _ease(local, length - 0.28, length, Curves.easeInCubic);
    final shown = inT * (1 - out);
    final blur = 12 * (1 - inT) + 8 * out;
    final child = Opacity(
      opacity: shown,
      child: Transform.scale(scale: 1.07 - 0.07 * inT + 0.03 * out, child: this.child),
    );
    if (blur < 0.2 || shown == 0) return child;
    return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: child);
  }
}

/// A line that arrives a word at a time. Words before [dim] are gray.
class _Line extends StatelessWidget {
  final double local;
  final double length;
  final List<String> words;
  final int? dim;

  const _Line({required this.local, required this.length, required this.words, this.dim});

  @override
  Widget build(BuildContext context) {
    final style = context.text.displayLarge?.copyWith(fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -1.8);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        children: [
          for (final (i, w) in words.indexed)
            _Focus(
              local: local,
              length: length,
              delay: i * 0.08,
              child: Text(w, style: style?.copyWith(color: dim != null && i < dim! ? _gray.withValues(alpha: 0.6) : _ink)),
            ),
        ],
      ),
    );
  }
}

/// The name, lit by a band of light passing across it.
class _Name extends StatelessWidget {
  final double local;
  final double length;

  const _Name({required this.local, required this.length});

  @override
  Widget build(BuildContext context) {
    final sweep = _ease(local, 0.1, 1.3, Curves.easeInOut);
    return Center(
      child: _Focus(
        local: local,
        length: length,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: const [_ink, _ink, Color(0xFFB0B0B8), _ink, _ink],
            stops: [0, sweep * 0.8, sweep * 0.8 + 0.1, sweep * 0.8 + 0.2, 1],
          ).createShader(rect),
          child: Text(
            'FindMyFit.',
            style: context.text.displayLarge?.copyWith(fontSize: 96, fontWeight: FontWeight.w700, letterSpacing: -3),
          ),
        ),
      ),
    );
  }
}

/// The app's screen, floating: white on white, held up by its shadow.
class _Screen extends StatelessWidget {
  final int chapter;
  final double t;
  final double width;

  const _Screen({required this.chapter, required this.t, this.width = 330});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 420 / 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 50, offset: const Offset(0, 22))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.1),
        child: FittedBox(child: SizedBox(width: 340, height: 420, child: AppFilm(chapter: chapter, t: t))),
      ),
    );
  }
}

/// One feature: the app floating in, turning slowly toward the words.
class _Feature extends StatelessWidget {
  final double local;
  final int chapter;
  final String title;
  final String body;
  final bool flip;

  const _Feature({required this.local, required this.chapter, required this.title, required this.body, required this.flip});

  @override
  Widget build(BuildContext context) {
    // The film at a brisker pace than in the app, resting at its end.
    final filmT = ((local - 0.15) / (filmSeconds * 0.8)).clamp(0.0, 0.93);
    final rise = _ease(local, 0, 0.6, Curves.easeOutCubic);
    final out = _ease(local, _feature - 0.28, _feature, Curves.easeInCubic);
    final turn = (flip ? -1 : 1) * (0.24 - 0.22 * (local / _feature));

    final screen = Opacity(
      opacity: rise * (1 - out),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble((flip ? -1 : 1) * 40 * (1 - rise), 50 * (1 - rise) - 16 * out, 0, 1)
          ..rotateY(turn)
          ..rotateX(0.07 * (1 - rise)),
        child: _Screen(chapter: chapter, t: filmT),
      ),
    );

    final align = flip ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = flip ? TextAlign.right : TextAlign.left;
    final words = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: align,
      children: [
        _Focus(
          local: local,
          length: _feature,
          delay: 0.15,
          child: Text(
            title,
            textAlign: textAlign,
            style: context.text.displayMedium?.copyWith(fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1.5, height: 1.05, color: _ink),
          ),
        ),
        const SizedBox(height: 14),
        _Focus(
          local: local,
          length: _feature,
          delay: 0.28,
          child: Text(
            body,
            textAlign: textAlign,
            style: context.text.titleLarge?.copyWith(fontSize: 23, fontWeight: FontWeight.w500, color: _gray),
          ),
        ),
      ],
    );

    return Row(
      children: [
        const SizedBox(width: 80),
        Expanded(flex: flip ? 5 : 6, child: flip ? screen : words),
        const SizedBox(width: 30),
        Expanded(flex: flip ? 6 : 5, child: flip ? words : screen),
        const SizedBox(width: 80),
      ],
    );
  }
}

/// One quick cut: a single huge word, or the app up close on one moment.
class _Cut extends StatelessWidget {
  final double local;
  final (String?, int, double, double, Alignment) cut;

  const _Cut({required this.local, required this.cut});

  @override
  Widget build(BuildContext context) {
    final (word, chapter, from, to, focus) = cut;
    final k = (local / _cut).clamp(0.0, 1.0);
    if (word != null) {
      return Center(
        child: Transform.scale(
          // A slow push in through the cut.
          scale: 1 + 0.05 * k,
          child: Opacity(
            opacity: _ease(local, 0, 0.12) * (1 - _ease(local, _cut - 0.1, _cut)),
            child: Text(
              word,
              style: context.text.displayLarge?.copyWith(fontSize: 128, fontWeight: FontWeight.w700, letterSpacing: -4.5, color: _ink),
            ),
          ),
        ),
      );
    }
    // Close on the app, drifting in.
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
          alignment: focus,
          scale: 1.9 + 0.15 * k,
          child: _Screen(chapter: chapter, t: from + (to - from) * k, width: 280),
        ),
      ),
    );
  }
}

class _End extends StatelessWidget {
  final double local;
  final double length;
  final String by;

  const _End({required this.local, required this.length, required this.by});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Focus(
            local: local,
            length: length,
            child: Image.asset('assets/brand/logo_mark.png', width: 76, height: 76),
          ),
          const SizedBox(height: 22),
          _Focus(
            local: local,
            length: length,
            delay: 0.12,
            child: Text(
              'FindMyFit.',
              style: context.text.displayLarge?.copyWith(fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -2, color: _ink),
            ),
          ),
          const SizedBox(height: 12),
          _Focus(
            local: local,
            length: length,
            delay: 0.24,
            child: Text(
              'Never lose clothes to the laundry again.',
              style: context.text.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: _gray),
            ),
          ),
          const SizedBox(height: 40),
          _Focus(
            local: local,
            length: length,
            delay: 0.4,
            child: Text(by, style: context.text.titleSmall?.copyWith(fontSize: 15, color: _gray, letterSpacing: 0.2)),
          ),
        ],
      ),
    );
  }
}
