import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If running on a narrow screen or mobile device, render natively
    final media = MediaQuery.of(context);
    final isDesktopWidth = media.size.width > 540;

    if (!isDesktopWidth || !kIsWeb) {
      return child;
    }

    // On wide desktop/web screen, render inside a sleek phone container
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 420,
          height: 890,
          margin: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: const Color(0xFF334155), width: 8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 36,
                offset: Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              child,
              // Subtle dynamic island / camera pill on top
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 110,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
