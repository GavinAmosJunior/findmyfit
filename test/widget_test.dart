import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_laundry_tracker/main.dart';
import 'package:smart_laundry_tracker/models/garment.dart';
import 'package:smart_laundry_tracker/screens/home_shell.dart';
import 'package:smart_laundry_tracker/state/wardrobe_state.dart';
import 'package:smart_laundry_tracker/theme/app_icons.dart';

Future<WardrobeState> _loadedState() async {
  final state = WardrobeState(load: false);
  await state.loadFromStorage();
  return state;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('empty closet invites you to add clothes', (tester) async {
    final state = await _loadedState();
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Start your closet'), findsOneWidget);
    expect(find.text('Add clothes'), findsOneWidget);
    expect(find.byType(AppTabBar), findsOneWidget);
  });

  testWidgets('one tap on "Wore it" moves a garment to the hamper, Undo brings it back', (tester) async {
    final state = await _loadedState();
    state.addGarment(name: 'Blue tee', category: GarmentCategory.tops);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Wore Blue tee — move to hamper'));
    await tester.pumpAndSettle();
    expect(state.garments.single.status, GarmentStatus.dirtyHamper);
    expect(state.garments.single.wearCount, 1);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.garments.single.status, GarmentStatus.closet);
    expect(state.garments.single.wearCount, 0);
  });

  testWidgets('switching to Bahasa Indonesia translates the tabs', (tester) async {
    final state = await _loadedState();
    state.setLanguage('id');
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Lemari'), findsWidgets);
    expect(find.text('Keranjang'), findsOneWidget);
  });

  for (final lang in ['en', 'id']) {
    testWidgets('every tab fits a small phone with large text ($lang)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final state = await _loadedState();
      state.setLanguage(lang);
      final a = state.addGarment(name: 'Oversized vintage denim jacket', category: GarmentCategory.outerwear);
      final b = state.addGarment(name: 'Silk blouse', category: GarmentCategory.delicates, status: GarmentStatus.dirtyHamper);
      final c = state.addGarment(name: 'Grey joggers', category: GarmentCategory.bottoms, status: GarmentStatus.dirtyHamper);
      final batch = state.sendToLaundry(garmentIds: [b.id], laundromatName: 'Sparkle Clean Laundromat');
      state.sendToLaundry(garmentIds: [c.id], laundromatName: 'Sparkle Clean Laundromat');
      state.finishReturn(batch.id);
      state.toggleFavorite(a.id);
      state.addGarment(name: 'Wide leg pleated trousers', category: GarmentCategory.bottoms);

      // Fails with the screen name and the overflowing widget, so a CI
      // failure says exactly what to fix.
      Future<void> settle(String screen) async {
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error != null) {
          final details = error is FlutterError ? error.toStringDeep() : '$error';
          fail('$screen ($lang) overflowed: $details');
        }
      }

      Finder tab(IconData icon) => find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(icon));
      void back() => tester.state<NavigatorState>(find.byType(Navigator).first).pop();

      await tester.pumpWidget(FindMyFitApp(state: state));
      await settle('Closet');
      await tester.tap(tab(AppIcons.hamper));
      await settle('Hamper');
      await tester.tap(tab(AppIcons.laundry));
      await settle('Laundry');
      await tester.tap(tab(AppIcons.missing));
      await settle('Missing');

      await tester.tap(tab(AppIcons.laundry));
      await settle('Laundry');
      await tester.ensureVisible(find.byIcon(AppIcons.chevron).first);
      await tester.tap(find.byIcon(AppIcons.chevron).first);
      await settle('Return check');
      back();
      await settle('Laundry');
      await tester.tap(tab(AppIcons.closet));
      await settle('Closet');
      await tester.tap(find.byIcon(AppIcons.settings));
      await settle('Settings');
      back();
      await settle('Closet');
      await tester.tap(tab(AppIcons.fits));
      await settle('Fits');
      await tester.ensureVisible(find.byIcon(AppIcons.shuffle));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.shuffle));
      await settle('Fits after shuffling');
      await tester.tap(tab(AppIcons.closet));
      await settle('Closet');
      await tester.tap(find.byIcon(AppIcons.add));
      await settle('Add clothes');
    });
  }

  group('laundry round trip', () {
    test('ticked items come back clean, the rest go missing', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'A', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      final b = state.addGarment(name: 'B', category: GarmentCategory.bottoms, status: GarmentStatus.dirtyHamper);

      final batch = state.sendToLaundry(garmentIds: [a.id, b.id], laundromatName: 'Sparkle');
      expect(state.countOf(GarmentStatus.inLaundry), 2);
      expect(state.recentLaundromats, ['Sparkle']);

      state.toggleReceived(batch.id, a.id);
      state.finishReturn(batch.id);

      expect(state.garmentById(a.id)!.status, GarmentStatus.closet);
      expect(state.garmentById(b.id)!.status, GarmentStatus.missing);
      expect(state.garmentById(b.id)!.currentBatchId, batch.id, reason: 'missing items remember their batch');
      expect(state.batchById(batch.id)!.isCompleted, isTrue);
    });

    test('history stops counting a piece as missing once it is found', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'A', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      final batch = state.sendToLaundry(garmentIds: [a.id], laundromatName: 'Sparkle');
      state.finishReturn(batch.id);
      expect(state.stillMissingFrom(batch), 1);

      state.markFound(a.id);
      expect(state.stillMissingFrom(batch), 0);
    });

    test('cancelling a batch returns clothes to the hamper', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'A', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      final batch = state.sendToLaundry(garmentIds: [a.id], laundromatName: '');
      expect(batch.laundromatName, 'Laundromat');

      state.cancelBatch(batch.id);
      expect(state.garmentById(a.id)!.status, GarmentStatus.dirtyHamper);
      expect(state.batches, isEmpty);
    });
  });

  testWidgets('Fits only suggests: shuffling and saving never move clothes', (tester) async {
    final state = await _loadedState();
    final a = state.addGarment(name: 'Linen shirt', category: GarmentCategory.tops);
    state.addGarment(name: 'Oxford shirt', category: GarmentCategory.tops);
    final b = state.addGarment(name: 'Chinos', category: GarmentCategory.bottoms);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.fits)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(AppIcons.shuffle));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.shuffle));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save fit'));
    await tester.pumpAndSettle();

    expect(state.fits, hasLength(1));
    expect(state.garments.every((g) => g.status == GarmentStatus.closet), isTrue);
    expect(state.garmentById(a.id)!.wearCount + state.garmentById(b.id)!.wearCount, 0);
    expect(find.text('Wear this fit'), findsNothing);
  });

  testWidgets('a piece put in the hamper by mistake goes back with one tap', (tester) async {
    final state = await _loadedState();
    final g = state.addGarment(name: 'Blue tee', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.hamper)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Put Blue tee back in the closet'));
    await tester.pumpAndSettle();
    expect(state.garmentById(g.id)!.status, GarmentStatus.closet);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.garmentById(g.id)!.status, GarmentStatus.dirtyHamper);
  });

  testWidgets('finishing a check with everything back stamps the ticket ALL BACK', (tester) async {
    final state = await _loadedState();
    final g = state.addGarment(name: 'Tee', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    state.sendToLaundry(garmentIds: [g.id], laundromatName: 'Sparkle');
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.laundry)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPARKLE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('ALL BACK'), findsOneWidget, reason: 'stays on the check and shows the stamp');
    expect(state.garmentById(g.id)!.status, GarmentStatus.closet);
  });

  testWidgets('closing the add form with something typed asks before discarding', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _loadedState();
    state.addGarment(name: 'Tee', category: GarmentCategory.tops);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Black jeans');
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discard this piece?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Black jeans'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this piece?'), findsNothing);
    expect(find.byIcon(AppIcons.close), findsNothing);
    expect(state.garments, hasLength(1));
  });

  group('fit shuffle', () {
    test('rails hold clean clothes only, bottoms apart from the rest', () async {
      final state = await _loadedState();
      state.addGarment(name: 'Tee', category: GarmentCategory.tops);
      state.addGarment(name: 'Coat', category: GarmentCategory.outerwear);
      state.addGarment(name: 'Jeans', category: GarmentCategory.bottoms);
      state.addGarment(name: 'Dirty shorts', category: GarmentCategory.bottoms, status: GarmentStatus.dirtyHamper);
      expect(state.shuffleTops.map((g) => g.name), unorderedEquals(['Tee', 'Coat']));
      expect(state.shuffleBottoms.map((g) => g.name), ['Jeans']);
    });

    test('saving the same fit twice removes it, and deleted pieces hide it', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'Tee', category: GarmentCategory.tops);
      final b = state.addGarment(name: 'Jeans', category: GarmentCategory.bottoms);
      expect(state.toggleFit([a.id, b.id]), isTrue);
      expect(state.isFitSaved([b.id, a.id]), isTrue, reason: 'order does not matter');
      expect(state.toggleFit([b.id, a.id]), isFalse);
      expect(state.fits, isEmpty);

      state.toggleFit([a.id, b.id]);
      state.markLost(a.id);
      expect(state.fits, isEmpty);
    });

    test('saved fits survive a backup, and older backups without fits load', () async {
      final source = await _loadedState();
      final a = source.addGarment(name: 'Tee', category: GarmentCategory.tops);
      final b = source.addGarment(name: 'Jeans', category: GarmentCategory.bottoms);
      source.toggleFit([a.id, b.id]);
      final backup = source.toBackup();

      SharedPreferences.setMockInitialValues({});
      final target = await _loadedState();
      target.restoreBackup(backup);
      expect(target.fits.single.itemIds, unorderedEquals([a.id, b.id]));

      target.restoreBackup(Map.of(backup)..remove('fits'));
      expect(target.fits, isEmpty);
    });
  });

  group('garments', () {
    test('editing can clear optional fields', () async {
      final state = await _loadedState();
      final g = state.addGarment(name: 'Jacket', category: GarmentCategory.outerwear, brand: 'Levi’s', notes: 'Cold wash');
      state.updateGarment(g.edited(name: 'Denim jacket', category: g.category, brand: null, notes: null, imageUrl: null));

      final edited = state.garmentById(g.id)!;
      expect(edited.name, 'Denim jacket');
      expect(edited.brand, isNull);
      expect(edited.notes, isNull);
    });

    test('a deleted garment can be restored in place', () async {
      final state = await _loadedState();
      state.addGarment(name: 'First', category: GarmentCategory.tops);
      final second = state.addGarment(name: 'Second', category: GarmentCategory.tops);
      final index = state.removeGarment(second.id);
      state.restoreGarment(second, index);
      expect(state.garments.first.id, second.id);
    });
  });

  group('backup', () {
    test('export then import restores everything', () async {
      final source = await _loadedState();
      final g = source.addGarment(name: 'Batik shirt', category: GarmentCategory.tops, imageUrl: 'data:image/jpeg;base64,AAAA');
      source.toggleFavorite(g.id);
      final backup = source.toBackup();

      SharedPreferences.setMockInitialValues({});
      final target = await _loadedState();
      target.restoreBackup(backup);

      final restored = target.garments.single;
      expect(restored.name, 'Batik shirt');
      expect(restored.isFavorite, isTrue);
      expect(restored.imageUrl, 'data:image/jpeg;base64,AAAA');
    });

    test('a file that is not a backup is rejected and nothing changes', () async {
      final state = await _loadedState();
      state.addGarment(name: 'Keep me', category: GarmentCategory.tops);
      expect(() => state.restoreBackup({'hello': 'world'}), throwsFormatException);
      expect(state.garments.single.name, 'Keep me');
    });

    test('older saves with separate fabric and wash notes still load', () {
      final g = Garment.fromJson({
        'id': 'old',
        'name': 'Old shirt',
        'fabricNotes': 'Linen',
        'washNotes': 'Machine Wash Safe',
      });
      expect(g.notes, 'Linen');
      expect(g.wearCount, 0);
    });
  });
}
