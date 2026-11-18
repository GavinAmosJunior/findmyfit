import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_laundry_tracker/main.dart';
import 'package:smart_laundry_tracker/models/garment.dart';
import 'package:smart_laundry_tracker/state/wardrobe_state.dart';

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
    expect(find.byType(NavigationBar), findsOneWidget);
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

      await tester.pumpWidget(FindMyFitApp(state: state));
      await tester.pumpAndSettle();
      for (final icon in [
        Icons.shopping_basket_outlined,
        Icons.local_laundry_service_outlined,
        Icons.travel_explore_outlined,
      ]) {
        await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(icon)));
        await tester.pumpAndSettle();
      }
      // Pushed screens: return check, settings, add clothes.
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.local_laundry_service_outlined)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.checkroom_outlined)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // Any RenderFlex overflow above would have failed the test.
      expect(tester.takeException(), isNull);
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
