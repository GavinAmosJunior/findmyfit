import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_laundry_tracker/services/cutout.dart';
import 'package:smart_laundry_tracker/services/image_store.dart';

/// A photo with a red "garment" (a 2:1 rectangle) on a grey floor, turned
/// by [degrees] clockwise, plus the mask a segmenter would return for it.
(img.Image, CutoutSubject) _scene({double degrees = 0, int size = 240, double scale = 1}) {
  final photo = img.Image(width: size, height: size);
  img.fill(photo, color: img.ColorRgb8(120, 120, 120));
  final mask = List<double>.filled(size * size, 0);
  final t = degrees * math.pi / 180;
  final halfW = 70 * scale, halfH = 35 * scale;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - size / 2, dy = y - size / 2;
      // Undo the turn to test against the upright rectangle.
      final u = dx * math.cos(t) + dy * math.sin(t);
      final v = -dx * math.sin(t) + dy * math.cos(t);
      if (u.abs() <= halfW && v.abs() <= halfH) {
        photo.setPixelRgb(x, y, 200, 30, 30);
        mask[y * size + x] = 0.98;
      }
    }
  }
  return (photo, CutoutSubject(x: 0, y: 0, width: size, height: size, mask: mask));
}

/// How much of the visible part's bounding box is filled. An upright
/// rectangle fills nearly all of it; a tilted one leaves empty corners.
double _fill(img.Image cut) {
  var minX = cut.width, minY = cut.height, maxX = 0, maxY = 0, n = 0;
  for (final p in cut) {
    if (p.a > 128) {
      n++;
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
  }
  return n / ((maxX - minX + 1) * (maxY - minY + 1));
}

void main() {
  test('the background goes transparent and the garment is centered on a square', () {
    final (photo, subject) = _scene();
    final out = img.decodePng(composeCutout(photo, [subject])!)!;
    expect(out.width, out.height);
    expect(out.getPixel(0, 0).a, 0, reason: 'the floor is gone');
    final middle = out.getPixel(out.width ~/ 2, out.height ~/ 2);
    expect((middle.r, middle.g, middle.a), (200, 30, 255), reason: 'the garment keeps its color');
    expect(_fill(out), greaterThan(0.95));
  });

  for (final degrees in [0.0, -25.0, 18.0, 33.0]) {
    test('the lift geometry carries a $degrees° garment onto its cutout', () {
      final (photo, subject) = _scene(degrees: degrees, size: 300);
      final made = composeCutoutDetailed(photo, [subject])!;
      final out = img.decodePng(made.png)!;
      final g = made.geometry;
      final k = out.width / g.side;
      // Every garment pixel of the photo should land on garment in the cutout.
      var hits = 0, total = 0;
      for (var y = 0; y < photo.height; y += 3) {
        for (var x = 0; x < photo.width; x += 3) {
          if (subject.mask[y * photo.width + x] < 0.9) continue;
          total++;
          final q = g.place(Offset(x + 0.5, y + 0.5)) * k;
          final qx = q.dx.round().clamp(0, out.width - 1), qy = q.dy.round().clamp(0, out.height - 1);
          if (out.getPixel(qx, qy).a > 128) hits++;
        }
      }
      expect(hits / total, greaterThan(0.93));
      expect(img.decodePng(made.inPlace)!.width / img.decodePng(made.inPlace)!.height, closeTo(1, 0.01),
          reason: 'the in-place picture keeps the photo\'s shape');
    });
  }

  for (final degrees in [-25.0, 18.0, 33.0]) {
    test('a garment tilted $degrees° is straightened', () {
      final (photo, subject) = _scene(degrees: degrees);
      final maskImage = img.Image(width: photo.width, height: photo.height, numChannels: 4);
      for (final px in maskImage) {
        px.a = subject.mask[px.y * photo.width + px.x] > 0.5 ? 255 : 0;
      }
      final before = _fill(maskImage);
      final out = img.decodePng(composeCutout(photo, [subject])!)!;
      expect(before, lessThan(0.75), reason: 'the scene really is tilted');
      expect(_fill(out), greaterThan(0.9));
    });
  }

  test('a garment lying sideways is left for the rotate button, not guessed', () {
    final (photo, subject) = _scene(degrees: 90);
    final out = img.decodePng(composeCutout(photo, [subject])!)!;
    var minX = out.width, maxX = 0, minY = out.height, maxY = 0;
    for (final p in out) {
      if (p.a > 128) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    expect(maxY - minY, greaterThan((maxX - minX) * 1.5), reason: 'still tall, as photographed');
  });

  test('a tiny stray object is not mistaken for the garment', () {
    final (photo, subject) = _scene(scale: 0.12);
    expect(composeCutout(photo, [subject]), isNull);
  });

  test('of several things found, the big one in the middle wins', () {
    final (photo, garment) = _scene();
    final sock = CutoutSubject(x: 0, y: 0, width: 20, height: 20, mask: List.filled(400, 0.99));
    final out = img.decodePng(composeCutout(photo, [sock, garment])!)!;
    expect(out.width, greaterThan(140), reason: 'sized to the 140px garment, not the 20px sock');
  });

  test('lift runs the whole way with a stand-in for the phone model', () async {
    final (photo, subject) = _scene(degrees: 20);
    Cutout.finder = (_) async => [subject];
    final done = await Cutout.lift(img.encodeJpg(photo, quality: 95));
    expect(ImageStore.isCutoutBytes(done.png!), isTrue);

    Cutout.finder = (_) async => [];
    final none = await Cutout.lift(img.encodeJpg(photo));
    expect((none.png, none.unavailable), (null, false), reason: 'nothing found: keep the plain photo');

    Cutout.finder = (_) async => throw Exception('Waiting for the subject segmentation optional module to be downloaded.');
    final later = await Cutout.lift(img.encodeJpg(photo));
    expect((later.png, later.unavailable, later.downloading), (null, true, true),
        reason: 'told apart, so the app can say try again');

    Cutout.finder = (_) async => throw Exception('NullPointerException');
    final broken = await Cutout.lift(img.encodeJpg(photo));
    expect((broken.unavailable, broken.downloading), (true, false), reason: 'not blamed on a download');
  });

  test('rotate turns a quarter clockwise and keeps the format', () async {
    final tall = img.Image(width: 10, height: 30, numChannels: 4);
    final turned = await Cutout.rotateQuarter(img.encodePng(tall));
    final back = img.decodePng(turned)!;
    expect((back.width, back.height), (30, 10));

    final jpg = await Cutout.rotateQuarter(img.encodeJpg(img.Image(width: 16, height: 40)));
    expect(ImageStore.isCutoutBytes(jpg), isFalse);
  });

  test('cutouts are told apart from photos by their stored form', () {
    expect(ImageStore.isCutout('/data/garments/g_1.png'), isTrue);
    expect(ImageStore.isCutout('data:image/png;base64,AAAA'), isTrue);
    expect(ImageStore.isCutout('/data/garments/g_1.jpg'), isFalse);
    expect(ImageStore.isCutout(null), isFalse);
    expect(ImageStore.isCutoutBytes(Uint8List.fromList([1, 2, 3])), isFalse);
  });
}
