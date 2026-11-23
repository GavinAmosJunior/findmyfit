// Renders the showreel to PNG frames, one per frame, for ffmpeg.
//
//   flutter test tool/showreel/render_test.dart            all frames (60 fps)
//   REEL_AT=2,6.5,12 flutter test tool/showreel/render_test.dart   just those seconds
//
// Frames go to build/showreel/frames. See tool/showreel/README.md.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_laundry_tracker/services/samples.dart';
import 'package:smart_laundry_tracker/state/app_scope.dart';
import 'package:smart_laundry_tracker/state/wardrobe_state.dart';
import 'package:smart_laundry_tracker/theme/app_theme.dart';

import 'showreel.dart';

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

void main() {
  testWidgets('render showreel', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    const fps = 60;
    final at = Platform.environment['REEL_AT'];
    final out = Directory(at == null ? 'build/showreel/frames' : 'build/showreel/check')..createSync(recursive: true);

    tester.view.physicalSize = reelSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      // Apple's own system font, from this Mac, and the app's icons.
      await _font('SF', '/System/Library/Fonts/SFNS.ttf');
      await _font('PhosphorRegular', 'assets/fonts/Phosphor-Regular.ttf');
      await _font('PhosphorFill', 'assets/fonts/Phosphor-Fill.ttf');
      await _font('PhosphorBold', 'assets/fonts/Phosphor-Bold.ttf');
    });

    final base = AppTheme.light;
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'SF'),
      scaffoldBackgroundColor: Colors.white,
    );
    final state = WardrobeState(load: false)..setUserName('Gavin');
    final key = GlobalKey();
    Widget reel(double time) => AppScope(
          state: state,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: RepaintBoundary(key: key, child: Showreel(time: time, by: 'by Gavin Amos Junior')),
          ),
        );

    await tester.pumpWidget(reel(0));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Showreel));
      for (final a in [...Samples.assets, 'assets/brand/logo_mark.png']) {
        await precacheImage(AssetImage(a), ctx);
      }
    });

    final times = at != null
        ? at.split(',').map(double.parse).toList()
        : [for (var i = 0; i < reelSeconds * fps; i++) i / fps];
    for (final (i, time) in times.indexed) {
      await tester.pumpWidget(reel(time));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = at != null ? 'at_$time.png' : 'f${i.toString().padLeft(5, '0')}.png';
        File('${out.path}/$name').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
