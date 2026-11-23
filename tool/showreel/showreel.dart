import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smart_laundry_tracker/l10n/strings.dart';
import 'package:smart_laundry_tracker/screens/welcome_film.dart';
import 'package:smart_laundry_tracker/theme/app_theme.dart';

/// A 30-second, 16:9 showreel of FindMyFit, cut like an iPhone launch
/// film: black, a few big words that come in out of a blur, the app
/// floating in the light and turning slowly in 3D, then the name. It
/// loops from black to black.
///
/// Drawn at 960×540 and rendered at 2× (1920×1080) by render_test.dart.
const reelSeconds = 30.0;
const reelSize = Size(960, 540);

const _white = Color(0xFFF5F5F7);
const _gray = Color(0xFF86868B);

/// When each feature starts, in seconds; each runs [_feature] seconds.
const _features = [7.4, 11.9, 16.4, 20.9];
const _feature = 4.5;

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
    return SizedBox.fromSize(
      size: reelSize,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The problem, in two beats.
            if (time < 3.3) _Line(local: time - 0.5, length: 2.8, words: const ['Clothes', 'go', 'to', 'the', 'laundry.']),
            if (time >= 3.2 && time < 5.6) _Line(local: time - 3.3, length: 2.3, words: const ['Not', 'all', 'come', 'back.'], dim: 2),
            // The answer.
            if (time >= 5.5 && time < 7.5) _Name(local: time - 5.6, length: 1.9),
            for (final (i, start) in _features.indexed)
              if (time >= start - 0.1 && time < start + _feature + 0.1)
                _Feature(local: time - start, chapter: i, title: steps[i].$1, body: steps[i].$2, flip: i.isOdd),
            if (time >= 25.4) _End(local: time - 25.5, by: by),
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
/// way: the launch-film entrance.
class _Focus extends StatelessWidget {
  final double local;
  final double length;
  final double delay;
  final Widget child;

  const _Focus({required this.local, required this.length, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final inT = _ease(local, delay, delay + 0.7, Curves.easeOutCubic);
    final out = _ease(local, length - 0.45, length, Curves.easeInCubic);
    final shown = inT * (1 - out);
    final blur = 14 * (1 - inT) + 10 * out;
    final child = Opacity(
      opacity: shown,
      child: Transform.scale(scale: 1.06 - 0.06 * inT + 0.03 * out, child: this.child),
    );
    if (blur < 0.2 || shown == 0) return child;
    return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: child);
  }
}

/// A line that arrives a word at a time. Words from [dim] on are white,
/// the ones before it gray, for emphasis.
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
              delay: i * 0.14,
              child: Text(w, style: style?.copyWith(color: dim != null && i < dim! ? _gray : _white)),
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
    final sweep = _ease(local, 0.2, 1.6, Curves.easeInOut);
    return Center(
      child: _Focus(
        local: local,
        length: length,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: const [_gray, _white, Colors.white, _white, _gray],
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

/// One feature: the app floating in the dark, turning slowly toward the
/// words, which come in out of a blur.
class _Feature extends StatelessWidget {
  final double local;
  final int chapter;
  final String title;
  final String body;
  final bool flip;

  const _Feature({required this.local, required this.chapter, required this.title, required this.body, required this.flip});

  @override
  Widget build(BuildContext context) {
    final filmT = ((local - 0.4) / filmSeconds).clamp(0.0, 0.93);
    final rise = _ease(local, 0, 1.1, Curves.easeOutCubic);
    final out = _ease(local, _feature - 0.45, _feature, Curves.easeInCubic);
    // A slow turn through the whole shot, never stopping.
    final turn = (flip ? -1 : 1) * (0.22 - 0.2 * (local / _feature));
    const w = 330.0, h = w * 420 / 340;

    final screen = Opacity(
      opacity: rise * (1 - out),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(0, 60 * (1 - rise) - 20 * out, 0, 1)
          ..rotateY(turn)
          ..rotateX(0.06 * (1 - rise)),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.10), blurRadius: 70, spreadRadius: 4)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: FittedBox(child: SizedBox(width: 340, height: 420, child: AppFilm(chapter: chapter, t: filmT))),
          ),
        ),
      ),
    );

    final words = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: flip ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _Focus(
          local: local,
          length: _feature,
          delay: 0.25,
          child: Text(
            title,
            textAlign: flip ? TextAlign.right : TextAlign.left,
            style: context.text.displayMedium?.copyWith(fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1.5, height: 1.05, color: _white),
          ),
        ),
        const SizedBox(height: 14),
        _Focus(
          local: local,
          length: _feature,
          delay: 0.45,
          child: Text(
            body,
            textAlign: flip ? TextAlign.right : TextAlign.left,
            style: context.text.titleLarge?.copyWith(fontSize: 23, fontWeight: FontWeight.w500, color: _gray),
          ),
        ),
      ],
    );

    final children = [
      const SizedBox(width: 80),
      Expanded(flex: flip ? 5 : 6, child: flip ? screen : words),
      const SizedBox(width: 30),
      Expanded(flex: flip ? 6 : 5, child: flip ? words : screen),
      const SizedBox(width: 80),
    ];
    return Row(children: children);
  }
}

class _End extends StatelessWidget {
  final double local;
  final String by;

  const _End({required this.local, required this.by});

  @override
  Widget build(BuildContext context) {
    const length = 4.3;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Focus(
            local: local,
            length: length,
            child: ColorFiltered(
              // The mark in white on black.
              colorFilter: const ColorFilter.matrix([0, 0, 0, 0, 245, 0, 0, 0, 0, 245, 0, 0, 0, 0, 247, 0, 0, 0, 1, 0]),
              child: Image.asset('assets/brand/logo_mark.png', width: 76, height: 76),
            ),
          ),
          const SizedBox(height: 22),
          _Focus(
            local: local,
            length: length,
            delay: 0.15,
            child: Text(
              'FindMyFit.',
              style: context.text.displayLarge?.copyWith(fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -2, color: _white),
            ),
          ),
          const SizedBox(height: 12),
          _Focus(
            local: local,
            length: length,
            delay: 0.3,
            child: Text(
              'Never lose clothes to the laundry again.',
              style: context.text.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: _gray),
            ),
          ),
          const SizedBox(height: 40),
          _Focus(
            local: local,
            length: length,
            delay: 0.5,
            child: Text(by, style: context.text.titleSmall?.copyWith(fontSize: 15, color: _gray, letterSpacing: 0.2)),
          ),
        ],
      ),
    );
  }
}
