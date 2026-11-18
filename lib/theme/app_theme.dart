import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/garment.dart';

/// Colors for one status's care-label tag.
class TagColors {
  final Color background;
  final Color foreground;
  final Color border;

  const TagColors(this.background, this.foreground, this.border);

  static TagColors lerp(TagColors a, TagColors b, double t) => TagColors(
        Color.lerp(a.background, b.background, t)!,
        Color.lerp(a.foreground, b.foreground, t)!,
        Color.lerp(a.border, b.border, t)!,
      );
}

/// App-specific colors that Material's ColorScheme has no slot for.
///
/// Every text/background pair here was checked for at least 4.5:1 contrast
/// in both light and dark mode.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color secondaryText;
  final Color tertiaryText;
  final Color separator;
  final Color card;
  final TagColors clean;
  final TagColors hamper;
  final TagColors laundry;
  final TagColors missing;

  const AppPalette({
    required this.secondaryText,
    required this.tertiaryText,
    required this.separator,
    required this.card,
    required this.clean,
    required this.hamper,
    required this.laundry,
    required this.missing,
  });

  TagColors forStatus(GarmentStatus status) {
    switch (status) {
      case GarmentStatus.closet:
        return clean;
      case GarmentStatus.dirtyHamper:
        return hamper;
      case GarmentStatus.inLaundry:
        return laundry;
      case GarmentStatus.missing:
        return missing;
    }
  }

  static const light = AppPalette(
    secondaryText: Color(0xFF475569), // 7.58:1 on card
    tertiaryText: Color(0xFF5B6678), // 5.81:1 on card
    separator: Color(0xFFE2E8F0),
    card: Color(0xFFFFFFFF),
    clean: TagColors(Color(0xFFECFDF5), Color(0xFF065F46), Color(0xFF6EE7B7)),
    hamper: TagColors(Color(0xFFFFFBEB), Color(0xFF92400E), Color(0xFFFCD34D)),
    laundry: TagColors(Color(0xFFEFF6FF), Color(0xFF1E40AF), Color(0xFF93C5FD)),
    missing: TagColors(Color(0xFFFEF2F2), Color(0xFF991B1B), Color(0xFFFCA5A5)),
  );

  static const dark = AppPalette(
    secondaryText: Color(0xFFB4BDCC), // 9.00:1 on card
    tertiaryText: Color(0xFF939DAF), // 6.24:1 on card
    separator: Color(0xFF263042),
    card: Color(0xFF171C27),
    clean: TagColors(Color(0xFF052E22), Color(0xFF6EE7B7), Color(0xFF047857)),
    hamper: TagColors(Color(0xFF3B2304), Color(0xFFFCD34D), Color(0xFFB45309)),
    laundry: TagColors(Color(0xFF0C1E46), Color(0xFF93C5FD), Color(0xFF1D4ED8)),
    missing: TagColors(Color(0xFF3F0A0A), Color(0xFFFCA5A5), Color(0xFFB91C1C)),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      card: Color.lerp(card, other.card, t)!,
      clean: TagColors.lerp(clean, other.clean, t),
      hamper: TagColors.lerp(hamper, other.hamper, t),
      laundry: TagColors.lerp(laundry, other.laundry, t),
      missing: TagColors.lerp(missing, other.missing, t),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Fallback colors for garments without a photo, picked per category.
const garmentSwatches = <int>[
  0xFF3B5B8C,
  0xFF2F6B55,
  0xFF8A5A2B,
  0xFF5B4B8A,
  0xFF8C3B4F,
  0xFF3E6670,
];

class AppTheme {
  static const _accentLight = Color(0xFF0058BE);
  static const _accentDark = Color(0xFF6EA8FF);

  /// Plus Jakarta Sans for large titles only; body text uses the platform
  /// font (SF Pro on iPhone, Roboto on Android) for legibility at small
  /// sizes, as Apple's branding guidance suggests.
  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle display(double size, FontWeight weight, double spacing) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: primary,
          height: 1.2,
        );

    return TextTheme(
      displaySmall: display(34, FontWeight.w700, -0.6),
      headlineMedium: display(28, FontWeight.w700, -0.4),
      headlineSmall: display(22, FontWeight.w700, -0.3),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primary),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 17, height: 1.35, color: primary),
      bodyMedium: TextStyle(fontSize: 15, height: 1.35, color: primary),
      bodySmall: TextStyle(fontSize: 13, height: 1.3, color: secondary),
      labelLarge: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color accent,
    required Color onAccent,
    required Color background,
    required Color text,
    required AppPalette palette,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      error: palette.missing.foreground,
      onError: palette.missing.background,
      surface: background,
      onSurface: text,
      onSurfaceVariant: palette.secondaryText,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.card,
      surfaceContainer: palette.card,
      surfaceContainerHigh: palette.card,
      surfaceContainerHighest: palette.separator,
      outline: palette.tertiaryText,
      outlineVariant: palette.separator,
    );
    final textTheme = _textTheme(text, palette.secondaryText);
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [palette],
      // iOS shows a soft highlight on press, not a ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: text.withValues(alpha: 0.06),
      // Pages slide in from the right and can be swiped back, on both phones.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: text,
        // No titleTextStyle here: it would also shrink the large titles
        // of SliverAppBar.large, which should use headlineMedium.
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        // White on the grouped background is enough; no outline (iOS
        // inset grouped lists have none).
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? accent : palette.secondaryText,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? accent : palette.secondaryText,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 50),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 50),
          shape: pill,
          // iOS "bordered" buttons are a tinted fill, not an outline.
          backgroundColor: accent.withValues(alpha: brightness == Brightness.light ? 0.10 : 0.16),
          side: BorderSide.none,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.separator.withValues(alpha: brightness == Brightness.light ? 0.7 : 1),
        selectedColor: text,
        secondarySelectedColor: text,
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: text),
        secondaryLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: background),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(color: palette.tertiaryText),
        labelStyle: TextStyle(color: palette.secondaryText),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        contentTextStyle: TextStyle(
          fontSize: 15,
          color: brightness == Brightness.light ? Colors.white : const Color(0xFF0F172A),
        ),
        actionTextColor: brightness == Brightness.light ? const Color(0xFF93C5FD) : _accentLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.separator, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 10,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: palette.secondaryText,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: palette.tertiaryText, width: 1.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
        shape: const CircleBorder(),
      ),
    );
  }

  static final ThemeData light = _build(
    brightness: Brightness.light,
    accent: _accentLight,
    onAccent: Colors.white, // 6.69:1
    background: const Color(0xFFF4F5F8),
    text: const Color(0xFF0F172A),
    palette: AppPalette.light,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    accent: _accentDark,
    onAccent: const Color(0xFF0B0F17), // 7.95:1
    background: const Color(0xFF0B0F17),
    text: const Color(0xFFF1F5F9),
    palette: AppPalette.dark,
  );
}
