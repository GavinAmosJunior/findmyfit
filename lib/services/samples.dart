import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../state/wardrobe_state.dart';
import 'image_store.dart';

/// One sample piece: drawn art in assets/samples, shown like a cutout.
typedef _Sample = ({String asset, String en, String id, GarmentCategory category});

/// The clothes the welcome can fill the closet with, so every part of the
/// app has something to show: a few clean pieces to shuffle into outfits,
/// two in the hamper, and a load at the laundry waiting to be checked.
abstract final class Samples {
  /// Where the art is stored. Swappable so tests run without a disk.
  @visibleForTesting
  static Future<String> Function(Uint8List bytes) store = (bytes) => ImageStore.saveBytes(bytes, prefix: 'sample');

  /// Whether [g] is a sample, even if the list of sample ids was lost:
  /// by its photo's file name, or by a sample's name.
  static bool looksLike(Garment g) =>
      (g.imageUrl?.contains('/sample_') ?? false) ||
      [..._closet, ..._hamper, ..._laundry].any((p) => p.en == g.name || p.id == g.name);

  static const List<_Sample> _closet = [
    (asset: 'tee', en: 'White tee', id: 'Kaus putih', category: GarmentCategory.tops),
    (asset: 'jeans', en: 'Blue jeans', id: 'Jeans biru', category: GarmentCategory.bottoms),
    (asset: 'coat', en: 'Camel coat', id: 'Mantel cokelat', category: GarmentCategory.outerwear),
    (asset: 'sneakers', en: 'White sneakers', id: 'Sepatu putih', category: GarmentCategory.shoes),
    (asset: 'cap', en: 'Navy cap', id: 'Topi navy', category: GarmentCategory.hats),
    (asset: 'tote', en: 'Canvas tote', id: 'Tas kanvas', category: GarmentCategory.bags),
    (asset: 'sunglasses', en: 'Sunglasses', id: 'Kacamata hitam', category: GarmentCategory.accessories),
  ];

  static const List<_Sample> _hamper = [
    (asset: 'hoodie', en: 'Grey hoodie', id: 'Hoodie abu', category: GarmentCategory.tops),
    (asset: 'blouse', en: 'Silk blouse', id: 'Blus sutra', category: GarmentCategory.delicates),
  ];

  static const List<_Sample> _laundry = [
    (asset: 'shirt', en: 'Striped shirt', id: 'Kemeja garis', category: GarmentCategory.tops),
    (asset: 'chinos', en: 'Khaki chinos', id: 'Celana chino', category: GarmentCategory.bottoms),
  ];

  /// Every sample's asset path, for preloading the welcome.
  static List<String> get assets =>
      [for (final p in [..._closet, ..._hamper, ..._laundry]) 'assets/samples/${p.asset}.png'];

  /// The pieces shown on the welcome's last page.
  static List<String> get preview =>
      [for (final a in ['tee', 'jeans', 'coat', 'sneakers', 'blouse', 'cap']) 'assets/samples/$a.png'];

  /// A sample's name in the app's language, by its art's name.
  static String name(String asset, S s) {
    final p = [..._closet, ..._hamper, ..._laundry].firstWhere((p) => p.asset == asset);
    return s.isIndonesian ? p.id : p.en;
  }

  /// Fills the closet with the samples, named in the app's language.
  static Future<void> add(WardrobeState state, S s) async {
    final ids = <String>[];
    Future<String> put(_Sample p, GarmentStatus status) async {
      final bytes = await rootBundle.load('assets/samples/${p.asset}.png');
      final image = await store(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      final g = state.addGarment(
        name: s.isIndonesian ? p.id : p.en,
        category: p.category,
        status: status,
        imageUrl: image,
      );
      ids.add(g.id);
      return g.id;
    }

    // Added last-first, since the newest piece shows first.
    final load = [for (final p in _laundry.reversed) await put(p, GarmentStatus.closet)];
    for (final p in _hamper.reversed) {
      await put(p, GarmentStatus.dirtyHamper);
    }
    for (final p in _closet.reversed) {
      await put(p, GarmentStatus.closet);
    }
    state.sendToLaundry(garmentIds: load, laundromatName: s.sampleLaundromat);
    state.markSamples(ids);
  }

  /// Takes the samples out again, photos included.
  static void remove(WardrobeState state) {
    state.removeSamples();
    ImageStore.deleteUnused(state.garments.map((g) => g.imageUrl).whereType<String>().toSet());
  }

  /// Starts the welcome over with a clean slate of samples: for showing
  /// the app to one person after another. Your own clothes stay.
  static void replayWelcome(WardrobeState state) {
    if (state.hasSamples) remove(state);
    state.showWelcomeAgain();
  }
}
