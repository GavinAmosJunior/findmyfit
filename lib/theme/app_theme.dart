import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/garment.dart';

/// App-specific colors that Material's ColorScheme has no slot for.
///
/// The look is monochrome: ink on white (white on black in dark mode),
/// with soft gray tiles that every garment sits on like a product shot.
/// The one color is [signal] red, kept for what's missing and for
/// deleting. Every text/background pair was checked for at least 4.5:1.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Labels, captions, inactive tabs.
  final Color secondaryText;

  /// Icons that only decorate (hangers, empty placeholders). Not for text.
  final Color tertiaryText;
  final Color separator;

  /// The gray tile behind garments, cards, fields and grouped lists.
  final Color tile;

  /// Missing clothes and destructive actions. The only color in the app.
  final Color signal;

  const AppPalette({
    required this.secondaryText,
    required this.tertiaryText,
    required this.separator,
    required this.tile,
    required this.signal,
  });

  /// Kept under its old name: cards are tiles now.
  Color get card => tile;

  /// Text color for a status: everything is ink except missing.
  Color statusColor(GarmentStatus status, Color ink) => status == GarmentStatus.missing ? signal : ink;

  static const light = AppPalette(
    secondaryText: Color(0xFF6C6C70), // 5.25:1 on white, 4.78:1 on tile
    tertiaryText: Color(0xFFAEAEB2),
    separator: Color(0xFFE5E5EA),
    tile: Color(0xFFF3F3F5),
    signal: Color(0xFFD70015), // 5.14:1 on white
  );

  static const dark = AppPalette(
    secondaryText: Color(0xFFA1A1A6), // 6.6:1 on tile, 7.9:1 on black
    tertiaryText: Color(0xFF5A5A5E),
    separator: Color(0xFF2C2C2E),
    tile: Color(0xFF1C1C1E),
    signal: Color(0xFFFF6961), // 6.1:1 on tile
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
      tile: Color.lerp(tile, other.tile, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Ink: black in light mode, near-white in dark mode.
  Color get ink => Theme.of(this).colorScheme.onSurface;
}

class AppTheme {
  /// Inter on Android and web; on iPhone, the iPhone's own San Francisco,
  /// so the app reads like the rest of the phone (Apple's font is only
  /// licensed on Apple's own devices, which is why Android keeps Inter).
  /// One family; weight and size carry the hierarchy. Titles are bold and
  /// tight, the way large titles are drawn on iPhone.
  static TextTheme _textTheme(Color primary, Color secondary) {
    final apple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    TextStyle inter(double size, FontWeight weight, {double spacing = 0, double? height, Color? color}) {
      if (!apple) {
        return GoogleFonts.inter(fontSize: size, fontWeight: weight, letterSpacing: spacing, height: height, color: color);
      }
      // San Francisco has its own tracking per size (Apple's type table),
      // tighter than Inter needs, so it's used instead of [spacing].
      final tracking = switch (size) {
        >= 34 => 0.4,
        >= 28 => 0.38,
        >= 22 => -0.26,
        >= 20 => -0.45,
        >= 17 => -0.43,
        >= 16 => -0.31,
        >= 15 => -0.23,
        >= 13 => -0.08,
        _ => 0.0,
      };
      return TextStyle(
        fontFamily: size >= 20 ? 'CupertinoSystemDisplay' : 'CupertinoSystemText',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color,
      );
    }

    return TextTheme(
      displaySmall: inter(34, FontWeight.w700, spacing: -1.0, height: 1.1, color: primary),
      headlineMedium: inter(30, FontWeight.w700, spacing: -0.9, height: 1.15, color: primary),
      headlineSmall: inter(22, FontWeight.w700, spacing: -0.5, height: 1.2, color: primary),
      titleLarge: inter(20, FontWeight.w700, spacing: -0.4, color: primary),
      titleMedium: inter(17, FontWeight.w600, spacing: -0.3, color: primary),
      titleSmall: inter(15, FontWeight.w600, spacing: -0.2, color: primary),
      bodyLarge: inter(17, FontWeight.w400, spacing: -0.2, height: 1.35, color: primary),
      bodyMedium: inter(15, FontWeight.w400, spacing: -0.1, height: 1.35, color: primary),
      bodySmall: inter(13, FontWeight.w400, height: 1.3, color: secondary),
      labelLarge: inter(16, FontWeight.w600, spacing: -0.2),
      labelMedium: inter(13, FontWeight.w600, color: secondary),
      labelSmall: inter(12, FontWeight.w500, color: secondary),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color ink,
    required AppPalette palette,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: background,
      secondary: ink,
      onSecondary: background,
      error: palette.signal,
      onError: Colors.white,
      surface: background,
      onSurface: ink,
      onSurfaceVariant: palette.secondaryText,
      surfaceContainerLowest: background,
      surfaceContainerLow: palette.tile,
      surfaceContainer: palette.tile,
      surfaceContainerHigh: palette.tile,
      surfaceContainerHighest: palette.separator,
      outline: palette.tertiaryText,
      outlineVariant: palette.separator,
    );
    final textTheme = _textTheme(ink, palette.secondaryText);
    const pill = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [palette],
      // iOS shows a soft highlight on press, not a ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: ink.withValues(alpha: 0.05),
      hoverColor: ink.withValues(alpha: 0.04),
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
        centerTitle: true,
        foregroundColor: ink,
        iconTheme: IconThemeData(color: ink, size: 24),
        actionsIconTheme: IconThemeData(color: ink, size: 24),
        titleTextStyle: textTheme.titleMedium,
      ),
      // The back button is a thin chevron on every phone.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(IconData(0xe138, fontFamily: 'PhosphorRegular'), size: 24),
      ),
      iconTheme: IconThemeData(color: ink, size: 24),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink, minimumSize: const Size(44, 44)),
      ),
      cardTheme: CardThemeData(
        color: palette.tile,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: background,
          disabledBackgroundColor: palette.separator,
          disabledForegroundColor: palette.secondaryText,
          minimumSize: const Size(44, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      // The quiet button: ink on a gray capsule.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: palette.tile,
          minimumSize: const Size(44, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          side: BorderSide.none,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(44, 44),
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.tile,
        selectedColor: ink,
        secondarySelectedColor: ink,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, color: ink),
        secondaryLabelStyle: textTheme.titleSmall?.copyWith(color: background),
        side: BorderSide.none,
        shape: pill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.tile,
        // The label sits inside the empty field and gives way to what you
        // type, as on iPhone, instead of jumping onto the field's edge.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.signal, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.signal, width: 1.5),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.secondaryText),
        labelStyle: textTheme.bodyLarge?.copyWith(color: palette.secondaryText),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: 0.18),
        selectionHandleColor: ink,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: background),
        actionTextColor: background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.tertiaryText,
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: background,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.bodyLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: palette.separator,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: palette.separator, space: 1, thickness: 0.8),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: ink,
        textColor: ink,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: palette.tertiaryText, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : Colors.transparent),
        checkColor: WidgetStatePropertyAll(background),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? background : palette.tertiaryText,
        ),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : palette.tile),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : palette.separator,
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: ink, brightness: brightness),
      expansionTileTheme: ExpansionTileThemeData(iconColor: ink, collapsedIconColor: palette.secondaryText),
      badgeTheme: BadgeThemeData(backgroundColor: palette.signal, textColor: Colors.white),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(10)),
        textStyle: textTheme.bodySmall?.copyWith(color: background),
      ),
    );
  }

  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: Colors.white,
    ink: const Color(0xFF0A0A0B), // 19.8:1 on white
    palette: AppPalette.light,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: Colors.black,
    ink: const Color(0xFFF5F5F7), // 19.3:1 on black
    palette: AppPalette.dark,
  );
}
