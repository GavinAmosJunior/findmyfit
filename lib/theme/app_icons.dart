import 'package:flutter/widgets.dart';

/// Every icon in the app, in one place.
///
/// The glyphs come from Phosphor Icons (MIT, assets/fonts/PHOSPHOR_LICENSE),
/// bundled as fonts in pubspec.yaml.
///
/// Phosphor is drawn like SF Symbols: one stroke weight, rounded ends,
/// outline for toolbars and lists, fill for selected tabs and status
/// (sf-symbols.md › Design variants). Keeping them here means one visual
/// language everywhere.
abstract final class AppIcons {
  // Sections. Outline when idle, fill when selected.
  static const IconData closet = IconData(0xe7fe, fontFamily: _regular);
  static const IconData closetFill = IconData(0xe7fe, fontFamily: _fill);
  static const IconData hamper = IconData(0xe678, fontFamily: _regular);
  static const IconData hamperFill = IconData(0xe678, fontFamily: _fill);
  static const IconData laundry = IconData(0xede8, fontFamily: _regular);
  static const IconData laundryFill = IconData(0xede8, fontFamily: _fill);
  static const IconData missing = IconData(0xea64, fontFamily: _regular);
  static const IconData missingFill = IconData(0xea64, fontFamily: _fill);

  // Categories.
  static const IconData tops = IconData(0xe670, fontFamily: _fill);
  static const IconData bottoms = IconData(0xec88, fontFamily: _fill);
  static const IconData outerwear = IconData(0xecd0, fontFamily: _fill);
  static const IconData delicates = IconData(0xea7e, fontFamily: _fill);
  static const IconData shoes = IconData(0xe80c, fontFamily: _fill);
  static const IconData hats = IconData(0xea28, fontFamily: _fill);
  static const IconData bags = IconData(0xe29c, fontFamily: _fill);
  static const IconData accessories = IconData(0xe816, fontFamily: _fill);
  static const IconData watches = IconData(0xe4e6, fontFamily: _fill);
  static const IconData rails = IconData(0xe434, fontFamily: _regular);

  // Actions.
  static const IconData add = IconData(0xe3d4, fontFamily: _bold);
  static const IconData search = IconData(0xe30c, fontFamily: _regular);
  static const IconData noResults = IconData(0xe30e, fontFamily: _regular);
  static const IconData close = IconData(0xe4f6, fontFamily: _regular);
  static const IconData settings = IconData(0xe272, fontFamily: _regular);
  static const IconData favorite = IconData(0xe2a8, fontFamily: _fill);
  static const IconData favoriteOutline = IconData(0xe2a8, fontFamily: _regular);
  static const IconData edit = IconData(0xe3b4, fontFamily: _regular);
  static const IconData delete = IconData(0xe4a6, fontFamily: _regular);
  static const IconData sort = IconData(0xe098, fontFamily: _regular);
  static const IconData share = IconData(0xeaf0, fontFamily: _regular);
  static const IconData download = IconData(0xe20c, fontFamily: _regular);
  static const IconData chat = IconData(0xe16e, fontFamily: _regular);
  static const IconData forward = IconData(0xe06c, fontFamily: _bold);
  static const IconData chevron = IconData(0xe13a, fontFamily: _bold);
  static const IconData back = IconData(0xe138, fontFamily: _regular);
  static const IconData more = IconData(0xe1fe, fontFamily: _bold);
  static const IconData warning = IconData(0xe4e2, fontFamily: _fill);

  static const IconData fits = IconData(0xe422, fontFamily: _regular);
  static const IconData fitsFill = IconData(0xe422, fontFamily: _fill);
  static const IconData putBack = IconData(0xe08a, fontFamily: _regular);

  /// "I wore this": a shirt, for every kind of piece.
  static const IconData wore = IconData(0xe670, fontFamily: _regular);

  // Fit Shuffle.
  static const IconData shuffle = IconData(0xe422, fontFamily: _bold);
  static const IconData locked = IconData(0xe308, fontFamily: _fill);
  static const IconData unlocked = IconData(0xe30a, fontFamily: _regular);

  // Photos.
  static const IconData camera = IconData(0xe10e, fontFamily: _fill);
  static const IconData cameraOutline = IconData(0xe10e, fontFamily: _regular);
  static const IconData addPhoto = IconData(0xec58, fontFamily: _regular);
  static const IconData library = IconData(0xe836, fontFamily: _regular);
  static const IconData rotate = IconData(0xe036, fontFamily: _regular);
  static const IconData cutout = IconData(0xe6b6, fontFamily: _regular);
  static const IconData cutoutOn = IconData(0xe6b6, fontFamily: _fill);
  static const IconData flash = IconData(0xe2de, fontFamily: _fill);
  static const IconData flashOff = IconData(0xe2e0, fontFamily: _regular);
  static const IconData flashAuto = IconData(0xea84, fontFamily: _regular);
  static const IconData switchCamera = IconData(0xe7a4, fontFamily: _regular);

  // Checks.
  static const IconData check = IconData(0xe182, fontFamily: _bold);
  static const IconData checkAll = IconData(0xe53a, fontFamily: _bold);
  static const IconData checked = IconData(0xe184, fontFamily: _fill);
  static const IconData unchecked = IconData(0xe18a, fontFamily: _regular);
  static const IconData allFound = IconData(0xe606, fontFamily: _regular);
}

const _regular = 'PhosphorRegular';
const _fill = 'PhosphorFill';
const _bold = 'PhosphorBold';
