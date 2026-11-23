import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_laundry_tracker/l10n/strings.dart';
import 'package:smart_laundry_tracker/screens/welcome_film.dart';
import 'package:smart_laundry_tracker/theme/app_theme.dart';

/// A 30-second, 16:9 showreel of FindMyFit for a laptop at an exhibition,
/// in the style of an Apple product film: one idea at a time, big words
/// on the left, the app itself moving on the right, white all around.
/// It loops: the last card fades to white and the first fades back in.
///
/// Drawn at 960×540 and rendered at 2× (1920×1080) by render_test.dart.
const reelSeconds = 30.0;
const reelSize = Size(960, 540);

/// When each feature starts, in seconds; each runs [_feature] seconds.
const _features = [4.0, 9.5, 15.0, 20.5];
const _feature = 5.5;

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
        color: Colors.white,
        child: Stack(
          children: [
            if (time < 4.2) _Title(local: time, text: s.welcomeTitle.replaceAll('\n', ' ').replaceFirst('clothes ', 'clothes\n')),
            for (final (i, start) in _features.indexed)
              if (time >= start - 0.1 && time < start + _feature + 0.1)
                _Feature(local: time - start, chapter: i, title: steps[i].$1, body: steps[i].$2, number: i + 1),
            if (time >= 25.9) _End(local: time - 26, by: by),
          ],
        ),
      ),
    );
  }
}

/// 0 → 1 between [a] and [b], eased.
double _ease(double x, double a, double b, [Curve c = Curves.easeInOutCubic]) =>
    c.transform(((x - a) / (b - a)).clamp(0.0, 1.0));

/// In over the first 0.7 s, out over the last 0.5 s of [length].
double _presence(double local, double length) =>
    math.min(_ease(local, 0.05, 0.75, Curves.easeOutCubic), 1 - _ease(local, length - 0.55, length - 0.05));

/// A line that rises into place as it fades in, a beat after [delay].
class _Rise extends StatelessWidget {
  final double local;
  final double delay;
  final double length;
  final Widget child;

  const _Rise({required this.local, required this.child, this.delay = 0, required this.length});

  @override
  Widget build(BuildContext context) {
    final inT = _ease(local, 0.1 + delay, 0.9 + delay, Curves.easeOutCubic);
    final out = 1 - _ease(local, length - 0.55, length - 0.05);
    return Opacity(
      opacity: math.min(inT, out),
      child: Transform.translate(offset: Offset(0, 18 * (1 - inT)), child: child),
    );
  }
}

class _Title extends StatelessWidget {
  final double local;
  final String text;

  const _Title({required this.local, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _Rise(
        local: local,
        length: 4,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.displayLarge?.copyWith(fontSize: 58, height: 1.08, letterSpacing: -1.6, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final double local;
  final int chapter;
  final int number;
  final String title;
  final String body;

  const _Feature({required this.local, required this.chapter, required this.title, required this.body, required this.number});

  @override
  Widget build(BuildContext context) {
    // The film plays once at its own pace, then rests on its last frame
    // (before its own fade), while the words stay.
    final filmT = ((local - 0.45) / filmSeconds).clamp(0.0, 0.93);
    return Row(
      children: [
        const SizedBox(width: 96),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rise(
                local: local,
                length: _feature,
                child: Text(
                  title,
                  style: context.text.displayMedium?.copyWith(fontSize: 46, letterSpacing: -1.2, fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
              const SizedBox(height: 14),
              _Rise(
                local: local,
                delay: 0.15,
                length: _feature,
                child: Text(
                  body,
                  style: context.text.titleLarge?.copyWith(fontSize: 22, color: const Color(0xFF6E6E73), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: _presence(local, _feature),
          child: Transform.scale(
            scale: 0.97 + 0.03 * _ease(local, 0.05, 0.9, Curves.easeOutCubic),
            // A soft-edged window onto the app, floating a little.
            child: Container(
              width: 380,
              height: 380 * 420 / 340,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: const Color(0xFFE8E8ED)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 40, offset: const Offset(0, 16))],
              ),
              child: FittedBox(child: SizedBox(width: 340, height: 420, child: AppFilm(chapter: chapter, t: filmT))),
            ),
          ),
        ),
        const SizedBox(width: 110),
      ],
    );
  }
}

class _End extends StatelessWidget {
  final double local;
  final String by;

  const _End({required this.local, required this.by});

  @override
  Widget build(BuildContext context) {
    const length = 4.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Rise(local: local, length: length, child: Image.asset('assets/brand/logo_mark.png', width: 84, height: 84)),
          const SizedBox(height: 22),
          _Rise(
            local: local,
            delay: 0.12,
            length: length,
            child: Text(
              'FindMyFit',
              style: context.text.displayLarge?.copyWith(fontSize: 54, letterSpacing: -1.4, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          _Rise(
            local: local,
            delay: 0.24,
            length: length,
            child: Text(
              by,
              style: context.text.titleMedium?.copyWith(fontSize: 18, color: const Color(0xFF6E6E73), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
