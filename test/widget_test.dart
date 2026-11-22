import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_laundry_tracker/main.dart';
import 'package:smart_laundry_tracker/models/garment.dart';
import 'package:smart_laundry_tracker/models/laundry_batch.dart';
import 'package:smart_laundry_tracker/screens/camera_view.dart';
import 'package:smart_laundry_tracker/screens/garment_form_screen.dart';
import 'package:smart_laundry_tracker/screens/home_shell.dart';
import 'package:smart_laundry_tracker/state/wardrobe_state.dart';
import 'package:smart_laundry_tracker/theme/app_icons.dart';
import 'package:smart_laundry_tracker/widgets/pressable.dart';

Future<WardrobeState> _loadedState() async {
  final state = WardrobeState(load: false);
  await state.loadFromStorage();
  return state;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    // Tests have no camera: use the phone's picker path.
    GarmentFormScreen.ownCamera = false;
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

  testWidgets('Appearance in Settings can force dark mode, and it is remembered', (tester) async {
    final state = await _loadedState();
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppTabBar))).brightness, Brightness.light);

    await tester.tap(find.byIcon(AppIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(state.appearance, 'dark');
    expect(Theme.of(tester.element(find.text('Dark'))).brightness, Brightness.dark);

    final reloaded = await _loadedState();
    expect(reloaded.appearance, 'dark');
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
      // Missing lives inside Laundry, at the top.
      await tester.tap(find.byIcon(AppIcons.warning).first);
      await settle('Missing');
      back();
      await settle('Laundry');
      // The first chevron is the missing card's; the second, the load's.
      await tester.ensureVisible(find.byIcon(AppIcons.chevron).at(1));
      await tester.tap(find.byIcon(AppIcons.chevron).at(1));
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

    test('loads are numbered from 1 and can be named now or later', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'A', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      final b = state.addGarment(name: 'B', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      expect(state.nextLoadNumber, 1);

      final first = state.sendToLaundry(garmentIds: [a.id]);
      final second = state.sendToLaundry(garmentIds: [b.id], nickname: '  Bedsheets ', laundromatName: 'Sparkle');
      expect(first.number, 1);
      expect(first.hasNickname, isFalse);
      expect(second.number, 2);
      expect(second.nickname, 'Bedsheets');
      expect(state.recentLaundromats, ['Sparkle'], reason: 'loads with no place are not remembered as one');

      state.editLoad(first.id, nickname: 'Gym bag', laundromatName: 'Kiloan');
      expect(first.nickname, 'Gym bag');
      state.editLoad(first.id, nickname: ' ', laundromatName: '');
      expect(first.hasNickname, isFalse, reason: 'clearing the name goes back to the number');

      final copy = LaundryBatch.fromJson(second.toJson());
      expect(copy.nickname, 'Bedsheets');
      expect(copy.number, 2);
    });

    test('cancelling a batch returns clothes to the hamper', () async {
      final state = await _loadedState();
      final a = state.addGarment(name: 'A', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
      final batch = state.sendToLaundry(garmentIds: [a.id], laundromatName: '');
      expect(batch.laundromatName, '', reason: 'the laundromat is optional');

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

  testWidgets('the Closet cards show the load out now and an outfit, and only when they apply', (tester) async {
    final state = await _loadedState();
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();
    state.addGarment(name: 'Linen shirt', category: GarmentCategory.tops);
    await tester.pumpAndSettle();
    expect(find.text('Today’s fit'), findsNothing, reason: 'no bottoms yet, so no outfit');
    expect(find.text('At the laundry'), findsNothing);

    state.addGarment(name: 'Chinos', category: GarmentCategory.bottoms);
    final tee = state.addGarment(name: 'Tee', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    state.sendToLaundry(garmentIds: [tee.id], laundromatName: 'Sparkle');
    await tester.pumpAndSettle();
    expect(find.text('Today’s fit'), findsOneWidget);
    expect(find.text('Linen shirt · Chinos'), findsOneWidget, reason: 'beside the laundry card, names go under the pair');
    expect(find.text('At the laundry'), findsOneWidget);
    expect(find.text('0 of 1 back'), findsOneWidget);

    // Showing another fit only suggests: nobody moves.
    await tester.tap(find.text('Today’s fit'));
    await tester.pumpAndSettle();
    expect(state.garments.where((g) => g.status == GarmentStatus.closet), hasLength(2));
  });

  test('shoes, hats, bags and accessories count the wear but skip the hamper', () async {
    final state = await _loadedState();
    final shoes = state.addGarment(name: 'Sneakers', category: GarmentCategory.shoes);
    final tee = state.addGarment(name: 'Tee', category: GarmentCategory.tops);
    expect(state.shuffleTops.map((g) => g.name), ['Tee'], reason: 'shoes never hang on the tops rail');
    state.markWorn(shoes.id);
    state.markWorn(tee.id);
    expect(state.garmentById(shoes.id)!.status, GarmentStatus.closet);
    expect(state.garmentById(shoes.id)!.wearCount, 1);
    expect(state.garmentById(tee.id)!.status, GarmentStatus.dirtyHamper);
  });

  testWidgets('Rails turns on a shoe shelf and the tray; tops and bottoms stay', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _loadedState();
    state.addGarment(name: 'Tee', category: GarmentCategory.tops);
    state.addGarment(name: 'Jeans', category: GarmentCategory.bottoms);
    state.addGarment(name: 'Sneakers', category: GarmentCategory.shoes);
    state.addGarment(name: 'Cap', category: GarmentCategory.hats);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.fits)));
    await tester.pumpAndSettle();
    expect(find.text('Shoes'), findsNothing, reason: 'only tops and bottoms by default');

    await tester.tap(find.byIcon(AppIcons.rails));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Shoes'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Hats'));
    await tester.pumpAndSettle();
    expect(state.railOn(GarmentCategory.shoes), isFalse, reason: 'choices apply when the menu closes');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(state.railOn(GarmentCategory.shoes), isTrue);

    expect(find.text('Sneakers'), findsWidgets, reason: 'the shelf shows');
    expect(find.text('Cap'), findsOneWidget, reason: 'the tray shows the hat');
    expect(tester.takeException(), isNull, reason: 'everything fits a regular phone');
    await tester.tap(find.byIcon(AppIcons.shuffle));
    // The tray flicks through pieces like a reel before it lands.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(state.garments.every((g) => g.status == GarmentStatus.closet), isTrue);
  });

  testWidgets('a missing piece opens its details and can be found again there', (tester) async {
    final state = await _loadedState();
    final g = state.addGarment(name: 'Grey joggers', category: GarmentCategory.bottoms, status: GarmentStatus.dirtyHamper);
    state.finishReturn(state.sendToLaundry(garmentIds: [g.id], laundromatName: 'Sparkle').id);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is Pressable && w.label == 'Grey joggers'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.ensureVisible(find.text('Found it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Found it'));
    await tester.pumpAndSettle();
    expect(state.garmentById(g.id)!.status, GarmentStatus.closet);
  });

  testWidgets('Wardrobe view shows compartments and opens one to its pieces', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _loadedState();
    state.addGarment(name: 'Tee', category: GarmentCategory.tops);
    state.addGarment(name: 'Sneakers', category: GarmentCategory.shoes);
    final out = state.addGarment(name: 'Polo', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wardrobe'));
    await tester.pumpAndSettle();
    expect(state.closetView, 'wardrobe', reason: 'the choice is remembered');
    expect(find.text('Shoes'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget, reason: 'one of two tops is home; the polo is in the hamper');
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel(RegExp('^Tops, ')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 in the wardrobe'), findsOneWidget);
    expect(find.text(out.name), findsOneWidget);
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

  testWidgets('dropping off a load remembers the laundromat and takes an optional name', (tester) async {
    final state = await _loadedState();
    final old = state.addGarment(name: 'Old', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    state.finishReturn(state.sendToLaundry(garmentIds: [old.id], laundromatName: 'Sparkle').id);
    state.markFound(old.id);
    state.addGarment(name: 'Sheet', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    state.addGarment(name: 'Pillowcase', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.hamper)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop off 2 items'));
    await tester.pumpAndSettle();

    expect(find.text('Drop off load 2'), findsOneWidget);
    expect(find.text('at Sparkle'), findsOneWidget, reason: 'the last laundromat is remembered, not asked again');
    await tester.enterText(find.byType(TextField), 'Bedsheets');
    await tester.tap(find.widgetWithText(FilledButton, 'Drop off 2 items').last);
    await tester.pumpAndSettle();

    final load = state.batches.first;
    expect(load.nickname, 'Bedsheets');
    expect(load.laundromatName, 'Sparkle');
    expect(find.text('Bedsheets'), findsOneWidget, reason: 'the Laundry tab shows the load by its name');
  });

  testWidgets('finishing a check with everything back shows All back', (tester) async {
    final state = await _loadedState();
    final g = state.addGarment(name: 'Tee', category: GarmentCategory.tops, status: GarmentStatus.dirtyHamper);
    state.sendToLaundry(garmentIds: [g.id], laundromatName: 'Sparkle');
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.byIcon(AppIcons.laundry)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('All back'), findsOneWidget, reason: 'stays on the check and shows the result');
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

  testWidgets('the name keyboard closes when Add and next opens the camera', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _loadedState();
    state.addGarment(name: 'Tee', category: GarmentCategory.tops);
    await tester.pumpWidget(FindMyFitApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();
    // Our camera covers the form while open; typing the name happens once
    // it's out of the way.
    GarmentFormScreen.ownCamera = true;
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Black jeans');
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Add and next'));
    await tester.pump();
    await tester.pump();
    expect(state.garments, hasLength(2));
    expect(find.byType(CameraView), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse, reason: 'no keyboard over the viewfinder');
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
