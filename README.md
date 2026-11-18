# FindMyFit

A Flutter app that tracks your clothes through the laundry cycle, so nothing
goes missing between your closet and the laundromat.

## How it works

1. **Closet** – every garment you own, with a photo and category.
2. **Hamper** – mark clothes as dirty when you wear them.
3. **Laundry** – send hamper items to the laundry as a batch.
4. **Return checklist** – when the laundry comes back, tick off each item.
   Anything not ticked moves to **Missing**, so you know exactly what to ask
   the laundromat about.

## Features

- **Camera-first adding** – snap, name, "Add and next"; or pick a pile of
  photos from your gallery and name them one by one
- **One-tap "Wore it"** on every clean garment, with Undo
- **Return check** – tick each piece as it comes back; the rest move to Missing
- **Ask the laundromat** – share a ready-made list of missing items
- **Backup** – export everything, photos included, to one file and import it
  on a new phone
- Care-label style status tags, light and dark mode, English and Bahasa
  Indonesia
- Data stays on your device (no account needed)

Design follows Apple's Human Interface Guidelines: 44pt touch targets,
text contrast of at least 4.5:1 in both modes, status never shown by color
alone, and confirmation only for actions that can't be undone.

## Running it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run -d chrome      # web
flutter run                # connected Android device or emulator
```

iOS builds need a Mac with Xcode.

## Project layout

```
lib/
  models/    Garment and LaundryBatch data classes
  state/     WardrobeState – app state and on-device storage
  screens/   Closet, Hamper, Laundry, Missing, Add garment
  widgets/   Shared UI pieces
  theme/     Colors and typography
```

The `add_garment/`, `dirty_hamper_batch_drop_off/` and similar folders hold the
original design mockups (HTML + screenshot).
