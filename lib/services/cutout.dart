import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;

/// One thing the segmenter found: its box in the photo and, for every pixel
/// in that box, how sure it is (0 to 1) that the pixel belongs to it.
class CutoutSubject {
  final int x, y, width, height;
  final List<double> mask;

  const CutoutSubject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.mask,
  });
}

/// Finds the subjects in a photo file. Swappable so tests can run without
/// the phone's ML model.
typedef SubjectFinder = Future<List<CutoutSubject>> Function(String path);

/// How the garment moved from where it is in the photo to where it sits
/// in the cutout, so the app can animate it gliding there.
///
/// Sizes are in pixels of the upright photo. The cutout is the photo with
/// the garment kept, turned by [turn] degrees clockwise around its middle
/// (growing to [turnedWidth] × [turnedHeight]), cropped to [box], and
/// centered on a square of side [side].
class CutoutGeometry {
  final int width, height;
  final double turn;
  final int turnedWidth, turnedHeight;
  final Rect box;
  final int side;

  const CutoutGeometry({
    required this.width,
    required this.height,
    required this.turn,
    required this.turnedWidth,
    required this.turnedHeight,
    required this.box,
    required this.side,
  });

  /// Where photo pixel [p] lands on the cutout's square, in its own pixels.
  Offset place(Offset p) {
    final a = turn * math.pi / 180;
    final d = p - Offset(width / 2, height / 2);
    final r = Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
    return r + Offset(turnedWidth / 2, turnedHeight / 2) - box.topLeft + Offset((side - box.width) / 2, (side - box.height) / 2);
  }
}

/// What [Cutout.lift] gives back: the cutout, or why there isn't one.
class CutoutResult {
  /// PNG bytes of the garment on a transparent square.
  final Uint8List? png;

  /// The garment cut out where it stands in the photo (the photo's shape,
  /// smaller), and how it moves into [png]. For the lift animation.
  final Uint8List? inPlace;
  final CutoutGeometry? geometry;

  /// True when the phone couldn't run background removal at all, as
  /// opposed to finding no garment.
  final bool unavailable;

  /// True when it couldn't run because Play services is still downloading
  /// the model, so trying again later will help.
  final bool downloading;

  const CutoutResult.done(Uint8List this.png, {this.inPlace, this.geometry}) : unavailable = false, downloading = false;
  const CutoutResult.notFound() : png = null, inPlace = null, geometry = null, unavailable = false, downloading = false;
  const CutoutResult.unavailable({this.downloading = false})
    : png = null,
      inPlace = null,
      geometry = null,
      unavailable = true;
}

/// Lifts a garment out of its photo: the background goes transparent, a
/// slightly tilted garment is straightened, and the result is trimmed and
/// centered on a square.
///
/// Runs on the phone with Google ML Kit (Android), whose model Play
/// services downloads the first time. Elsewhere, or when no garment is
/// found, there's no cutout and the plain photo is kept.
class Cutout {
  /// Longest side of a saved cutout, matching the picker's photo size.
  static const maxSide = 900;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @visibleForTesting
  static SubjectFinder finder = _mlKit;

  static Future<CutoutResult> lift(Uint8List photo) async {
    File? temp;
    try {
      // Phones often save photos sideways with a "rotate me" note. Turn the
      // pixels upright first so the mask and the photo line up.
      final upright = await compute(_upright, photo);
      if (upright == null) return const CutoutResult.notFound();
      temp = File('${Directory.systemTemp.path}/cutout_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await temp.writeAsBytes(upright, flush: true);
      final List<CutoutSubject> subjects;
      try {
        subjects = await finder(temp.path);
      } catch (e) {
        // No model yet, no Play services, or an unsupported phone.
        debugPrint('Cutout unavailable: $e');
        // ML Kit says "Waiting for the ... module to be downloaded".
        return CutoutResult.unavailable(downloading: e.toString().toLowerCase().contains('download'));
      }
      if (subjects.isEmpty) return const CutoutResult.notFound();
      final made = await compute(_composeIsolate, (upright, subjects));
      return made == null
          ? const CutoutResult.notFound()
          : CutoutResult.done(made.png, inPlace: made.inPlace, geometry: made.geometry);
    } catch (e) {
      debugPrint('Cutout skipped: $e');
      return const CutoutResult.notFound();
    } finally {
      try {
        temp?.deleteSync();
      } catch (_) {}
    }
  }

  /// Turns a photo a quarter turn clockwise, keeping its format.
  static Future<Uint8List> rotateQuarter(Uint8List bytes, {int turns = 1}) =>
      compute(_rotate, (bytes, turns));

  static Future<List<CutoutSubject>> _mlKit(String path) async {
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(enableConfidenceMask: true, enableSubjectBitmap: false),
      ),
    );
    try {
      final result = await segmenter.processImage(InputImage.fromFilePath(path));
      return [
        for (final s in result.subjects)
          if (s.confidenceMask != null)
            CutoutSubject(x: s.startX, y: s.startY, width: s.width, height: s.height, mask: s.confidenceMask!),
      ];
    } finally {
      await segmenter.close();
    }
  }
}

Uint8List? _upright(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return img.encodeJpg(img.bakeOrientation(decoded), quality: 92);
}

Uint8List _rotate((Uint8List, int) args) {
  final (bytes, turns) = args;
  final decoder = img.findDecoderForData(bytes);
  final decoded = decoder?.decode(bytes);
  if (decoded == null) return bytes;
  final turned = img.copyRotate(img.bakeOrientation(decoded), angle: 90 * (turns % 4));
  return decoder is img.PngDecoder ? img.encodePng(turned) : img.encodeJpg(turned, quality: 90);
}

ComposedCutout? _composeIsolate((Uint8List, List<CutoutSubject>) args) {
  final photo = img.decodeImage(args.$1);
  if (photo == null) return null;
  return composeCutoutDetailed(photo, args.$2);
}

/// The cutout, the garment where it stood, and how it moved.
typedef ComposedCutout = ({Uint8List png, Uint8List inPlace, CutoutGeometry geometry});

/// Builds the cutout from a photo and the subjects found in it.
///
/// Public for tests; the app goes through [Cutout.lift].
@visibleForTesting
Uint8List? composeCutout(img.Image photo, List<CutoutSubject> subjects) => composeCutoutDetailed(photo, subjects)?.png;

/// Like [composeCutout], also keeping what the lift animation needs.
@visibleForTesting
ComposedCutout? composeCutoutDetailed(img.Image photo, List<CutoutSubject> subjects) {
  final w = photo.width, h = photo.height;
  final subject = _pickSubject(subjects, w, h);
  if (subject == null) return null;

  // 1. The photo with the subject's mask as its alpha. Soft edges are kept,
  //    faint guesses are dropped.
  var cut = img.Image(width: w, height: h, numChannels: 4);
  var area = 0;
  for (var yy = 0; yy < subject.height; yy++) {
    final py = subject.y + yy;
    if (py < 0 || py >= h) continue;
    for (var xx = 0; xx < subject.width; xx++) {
      final px = subject.x + xx;
      if (px < 0 || px >= w) continue;
      final c = subject.mask[yy * subject.width + xx];
      final a = ((c - 0.35) / 0.3).clamp(0.0, 1.0);
      if (a == 0) continue;
      if (a > 0.5) area++;
      final p = photo.getPixel(px, py);
      cut.setPixelRgba(px, py, p.r, p.g, p.b, (a * 255).round());
    }
  }
  // Too small to be the garment: probably a stray object.
  if (area < w * h * 0.02) return null;

  // The garment where it stands, small, for the lift animation.
  final scale = 640 / math.max(w, h);
  final inPlace = img.encodePng(
    scale < 1 ? img.copyResize(cut, width: (w * scale).round(), height: (h * scale).round()) : cut,
    level: 1,
  );

  // 2. Straighten a tilt of up to about 40 degrees. A garment lying sideways
  //    or upside down is left as is: there's a rotate button for that,
  //    because which way is "up" can't be told reliably from the shape.
  final tilt = _tilt(cut);
  if (tilt != null) {
    cut = img.copyRotate(cut, angle: -tilt, interpolation: img.Interpolation.linear);
  }

  // 3. Trim to the garment, pad, and center on a transparent square.
  final box = _opaqueBox(cut);
  if (box == null) return null;
  final trimmed = img.copyCrop(cut, x: box.$1, y: box.$2, width: box.$3, height: box.$4);
  final side = (math.max(trimmed.width, trimmed.height) * 1.12).round();
  var square = img.Image(width: side, height: side, numChannels: 4);
  img.compositeImage(
    square,
    trimmed,
    dstX: (side - trimmed.width) ~/ 2,
    dstY: (side - trimmed.height) ~/ 2,
    blend: img.BlendMode.direct,
  );
  if (side > Cutout.maxSide) {
    square = img.copyResize(square, width: Cutout.maxSide, height: Cutout.maxSide, interpolation: img.Interpolation.average);
  }
  return (
    png: img.encodePng(square, level: 6),
    inPlace: inPlace,
    geometry: CutoutGeometry(
      width: w,
      height: h,
      turn: -(tilt ?? 0),
      turnedWidth: cut.width,
      turnedHeight: cut.height,
      box: Rect.fromLTWH(box.$1.toDouble(), box.$2.toDouble(), box.$3.toDouble(), box.$4.toDouble()),
      side: side,
    ),
  );
}

/// The biggest subject, favoring the one nearest the middle of the frame.
CutoutSubject? _pickSubject(List<CutoutSubject> subjects, int w, int h) {
  CutoutSubject? best;
  var bestScore = 0.0;
  final maxDist = math.sqrt(w * w + h * h) / 2;
  for (final s in subjects) {
    if (s.width <= 0 || s.height <= 0 || s.mask.length < s.width * s.height) continue;
    var filled = 0;
    for (final c in s.mask) {
      if (c > 0.5) filled++;
    }
    final cx = s.x + s.width / 2 - w / 2, cy = s.y + s.height / 2 - h / 2;
    final centered = 1 - 0.5 * (math.sqrt(cx * cx + cy * cy) / maxDist);
    final score = filled * centered;
    if (score > bestScore) {
      bestScore = score;
      best = s;
    }
  }
  return best;
}

/// How far, in degrees clockwise, the garment's main axis leans away from
/// the nearest straight line, or null when it shouldn't be touched.
double? _tilt(img.Image cut) {
  var n = 0.0, sx = 0.0, sy = 0.0;
  for (final p in cut) {
    if (p.a > 128) {
      n++;
      sx += p.x;
      sy += p.y;
    }
  }
  if (n == 0) return null;
  final mx = sx / n, my = sy / n;
  var xx = 0.0, yy = 0.0, xy = 0.0;
  for (final p in cut) {
    if (p.a > 128) {
      final dx = p.x - mx, dy = p.y - my;
      xx += dx * dx;
      yy += dy * dy;
      xy += dx * dy;
    }
  }
  // A roundish shape has no clear axis.
  final common = math.sqrt(math.pow(xx - yy, 2) + 4 * xy * xy);
  final major = (xx + yy + common) / 2, minor = (xx + yy - common) / 2;
  if (minor <= 0 || major / minor < 1.3) return null;

  // Angle of the main axis (y points down, so positive is clockwise),
  // folded into -45..45 around the nearest horizontal or vertical.
  var angle = 0.5 * math.atan2(2 * xy, xx - yy) * 180 / math.pi;
  angle = ((angle + 45) % 90 + 90) % 90 - 45;
  if (angle.abs() < 3 || angle.abs() > 40) return null;
  return angle;
}

/// x, y, width, height of the visible part, or null if nothing is visible.
(int, int, int, int)? _opaqueBox(img.Image cut) {
  var minX = cut.width, minY = cut.height, maxX = -1, maxY = -1;
  for (final p in cut) {
    if (p.a > 20) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
  }
  if (maxX < 0) return null;
  return (minX, minY, maxX - minX + 1, maxY - minY + 1);
}
