import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../theme/app_icons.dart';

/// FindMyFit's own camera, in the spirit of the iPhone's: the picture
/// large in the middle, a close button you can always see, a big round
/// shutter, your photo library on the left and the lens switch on the
/// right. It covers the Add screen; closing it is always one tap.
class CameraView extends StatefulWidget {
  final ValueChanged<XFile> onPhoto;
  final VoidCallback onLibrary;
  final VoidCallback onClose;

  /// The camera can't run here (no camera, no permission): use the
  /// phone's own camera instead.
  final VoidCallback onUnavailable;

  const CameraView({
    super.key,
    required this.onPhoto,
    required this.onLibrary,
    required this.onClose,
    required this.onUnavailable,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _lens = 0;
  FlashMode _flash = FlashMode.off;
  bool _taking = false;
  bool _pressed = false;
  // The white blink when a photo is taken.
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('none', 'No camera');
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _lens = back == -1 ? 0 : back;
      await _open();
    } catch (e) {
      debugPrint('Camera unavailable: $e');
      if (mounted) widget.onUnavailable();
    }
  }

  Future<void> _open() async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(
      _cameras[_lens],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await c.initialize();
    try {
      await c.setFlashMode(_flash);
    } catch (_) {}
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _controller = c);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && c == null && _cameras.isNotEmpty) {
      _open().catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blink.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _taking) return;
    HapticFeedback.mediumImpact();
    setState(() => _taking = true);
    _blink.forward(from: 0);
    try {
      final photo = await c.takePicture();
      if (mounted) widget.onPhoto(photo);
    } catch (e) {
      debugPrint('Photo failed: $e');
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    HapticFeedback.selectionClick();
    _lens = (_lens + 1) % _cameras.length;
    try {
      await _open();
    } catch (_) {}
  }

  Future<void> _toggleFlash() async {
    HapticFeedback.selectionClick();
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              // Close, always within reach; flash on the other side.
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    _GlassButton(icon: AppIcons.close, label: s.close, onTap: widget.onClose),
                    const Spacer(),
                    _GlassButton(
                      icon: switch (_flash) {
                        FlashMode.off => AppIcons.flashOff,
                        FlashMode.auto => AppIcons.flashAuto,
                        _ => AppIcons.flash,
                      },
                      label: s.flash,
                      onTap: _toggleFlash,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // The picture, with a little guidance for a clean cutout.
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF111113)),
                            if (ready)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: c.value.previewSize?.height ?? 3,
                                  height: c.value.previewSize?.width ?? 4,
                                  child: CameraPreview(c),
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 14,
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      color: Colors.black.withValues(alpha: 0.3),
                                      child: Text(
                                        s.cameraHint,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // The blink as the photo is taken.
                            IgnorePointer(
                              child: FadeTransition(
                                opacity: Tween(begin: 0.85, end: 0.0).animate(
                                  CurvedAnimation(parent: _blink, curve: Curves.easeOut),
                                ),
                                child: AnimatedBuilder(
                                  animation: _blink,
                                  builder: (_, child) =>
                                      _blink.isAnimating ? child! : const SizedBox.shrink(),
                                  child: const ColoredBox(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Library, shutter, lens.
              SizedBox(
                height: 128,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _GlassButton(icon: AppIcons.library, label: s.choosePhotos, onTap: widget.onLibrary, size: 54),
                    Semantics(
                      button: true,
                      label: s.takePhoto,
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _pressed = true),
                        onTapCancel: () => setState(() => _pressed = false),
                        onTapUp: (_) => setState(() => _pressed = false),
                        onTap: _shoot,
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: AnimatedScale(
                            scale: _pressed ? 0.86 : 1,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _cameras.length > 1 ? 1 : 0.35,
                      child: _GlassButton(icon: AppIcons.switchCamera, label: s.switchCamera, onTap: _flip, size: 54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round, frosted button over the dark camera.
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  const _GlassButton({required this.icon, required this.label, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: size,
                height: size,
                color: Colors.white.withValues(alpha: 0.16),
                child: Icon(icon, color: Colors.white, size: size * 0.46),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
