import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// In a wide desktop browser, shows the app inside a phone outline so it
/// looks like it will on a phone. On real phones it does nothing.
///
/// The phone scales to fit the window, and the app inside is told the
/// phone's size and safe areas, so headers never sit under the fake notch.
class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  static const _bezel = 10.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!kIsWeb || media.size.width < 600) return child;

    final height = math.min(880.0, media.size.height - 32);
    final width = height * 0.47;
    final screen = Size(width - _bezel * 2, height - _bezel * 2);
    const safe = EdgeInsets.only(top: 48, bottom: 20);

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(_bezel),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(52),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 36, offset: Offset(0, 16))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: MediaQuery(
              data: media.copyWith(size: screen, padding: safe, viewPadding: safe),
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned(
                    top: 11,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 104,
                        height: 30,
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
