# Showreel

A 30-second, 1080p60, silent, looping showreel of FindMyFit for a laptop
at an exhibition. Built from the app's own tour films, drawn frame by frame.

```bash
flutter test tool/showreel/render_test.dart
ffmpeg -y -framerate 60 -i build/showreel/frames/f%05d.png -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -movflags +faststart showreel/FindMyFit-showreel.mp4
```

Check a few moments first: `REEL_AT=2.5,12,28 flutter test tool/showreel/render_test.dart`
(pictures land in build/showreel/check). Needs macOS for the SF font.
