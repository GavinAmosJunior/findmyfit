import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../services/cutout.dart';
import '../services/image_store.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import '../widgets/pill.dart';
import '../theme/app_icons.dart';

/// Adding is camera-first: snap a photo, type a name, tap "Add and next",
/// and the camera opens again for the next piece. "Choose photos" queues
/// several gallery photos to name one after another.
///
/// Each photo has its background removed while the name is typed (on
/// Android), so the garment shows on its own. The photo's corner buttons
/// switch back to the original and turn it a quarter turn.
///
/// The same screen edits an existing garment.
class GarmentFormScreen extends StatefulWidget {
  final Garment? editing;

  /// Where to show "Added" once this screen closes (the caller's tab).
  final ScaffoldMessengerState? messenger;

  /// Opens the photo library first instead of the camera.
  final bool fromGallery;

  const GarmentFormScreen({super.key, this.editing, this.messenger, this.fromGallery = false});

  /// [messenger] shows the "added" messages; by default, the one around
  /// [context].
  static Future<void> openAdd(BuildContext context, {ScaffoldMessengerState? messenger, bool fromGallery = false}) {
    final shown = messenger ?? ScaffoldMessenger.of(context);
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GarmentFormScreen(messenger: shown, fromGallery: fromGallery),
      ),
    );
  }

  static Future<void> openEdit(BuildContext context, Garment garment) =>
      Navigator.of(context)
          .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => GarmentFormScreen(editing: garment)));

  @override
  State<GarmentFormScreen> createState() => _GarmentFormScreenState();
}

class _GarmentFormScreenState extends State<GarmentFormScreen> {
  // Remembered between adds in one session, since piles tend to be similar.
  static GarmentCategory _lastCategory = GarmentCategory.tops;

  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _notes = TextEditingController();
  final _nameFocus = FocusNode();
  final _picker = ImagePicker();

  late GarmentCategory _category;
  bool _dirty = false;

  // The photo as taken, its cutout once ready, which of the two to keep,
  // and quarter turns to apply when saving.
  String? _original;
  String? _cutout;
  bool _useCutout = true;
  int _turns = 0;
  bool _lifting = false;

  // The garment where it stood and how it moved, for the lift; and whether
  // the lift is still to play for this photo.
  Uint8List? _inPlace;
  CutoutGeometry? _geometry;
  bool _playLift = false;

  // Set when no garment was found in this photo; trying again won't help.
  bool _noGarment = false;
  Future<void>? _liftDone;
  int _photoToken = 0;
  bool _saving = false;

  String? get _image => _useCutout && _cutout != null ? _cutout : _original;
  bool _busy = false;
  bool _showNameError = false;
  int _added = 0;
  final List<XFile> _queue = [];
  int _queueTotal = 0;

  bool get _isEdit => widget.editing != null;
  bool get _hasCamera =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    final g = widget.editing;
    _category = g?.category ?? _lastCategory;
    if (g != null) {
      _name.text = g.name;
      _brand.text = g.brand ?? '';
      _notes.text = g.notes ?? '';
      _original = g.imageUrl;
    } else if (widget.fromGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _choosePhotos(auto: true));
    } else if (_hasCamera) {
      // Camera-first: open it straight away on phones.
      WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto(auto: true));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _notes.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// [auto]: opened by the app (on arrival, or for the next piece), not
  /// by a button, so backing out means leaving.
  Future<void> _takePhoto({bool auto = false}) async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: ImageStore.maxSize,
        maxHeight: ImageStore.maxSize,
        imageQuality: ImageStore.quality,
      );
      if (shot != null) {
        await _usePhoto(shot);
      } else if (auto) {
        _closeIfUntouched();
      }
    } catch (_) {
      if (mounted) showMessage(context, S.of(context).photoError);
    }
  }

  /// Backing out of the camera or library before there's anything here
  /// means "never mind": close Add and go back to where you were. Pieces
  /// already added in this session stay, with a message saying so.
  void _closeIfUntouched() {
    if (!mounted || _isEdit || _hasUnsavedInput || _queue.isNotEmpty || _busy) return;
    final s = S.of(context);
    final messenger = widget.messenger ?? ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (_added > 0) showMessageOn(messenger, s.addedCount(_added));
  }

  Future<void> _choosePhotos({bool auto = false}) async {
    try {
      if (_isEdit) {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: ImageStore.maxSize,
          maxHeight: ImageStore.maxSize,
          imageQuality: ImageStore.quality,
        );
        if (one != null) await _usePhoto(one);
        return;
      }
      final many = await _picker.pickMultiImage(
        maxWidth: ImageStore.maxSize,
        maxHeight: ImageStore.maxSize,
        imageQuality: ImageStore.quality,
      );
      if (many.isEmpty) {
        if (auto) _closeIfUntouched();
        return;
      }
      _queue
        ..clear()
        ..addAll(many.skip(1));
      // A queue ("Photo 1 of 3", Skip) only when there's more than one.
      _queueTotal = many.length > 1 ? many.length : 0;
      await _usePhoto(many.first);
    } catch (_) {
      if (mounted) showMessage(context, S.of(context).photoError);
    }
  }

  Future<void> _usePhoto(XFile file) async {
    final token = ++_photoToken;
    setState(() => _busy = true);
    final bytes = await file.readAsBytes();
    final stored = await ImageStore.saveBytes(bytes);
    if (!mounted || token != _photoToken) return;
    setState(() {
      _original = stored;
      _cutout = null;
      _useCutout = true;
      _turns = 0;
      _noGarment = false;
      _busy = false;
    });
    if (Cutout.supported) {
      // The name keyboard waits for the lift, so the photo stays in view
      // while its background melts away.
      _liftDone = _lift(bytes, token);
    } else {
      _nameFocus.requestFocus();
    }
  }

  /// Removes the background in the background, while the name is typed.
  /// Quiet when it runs on its own; when asked for with the button, says
  /// why there's no cutout.
  Future<void> _lift(Uint8List bytes, int token, {bool asked = false}) async {
    setState(() => _lifting = true);
    final result = await Cutout.lift(bytes);
    final png = result.png;
    final stored = png == null ? null : await ImageStore.saveBytes(png);
    if (!mounted || token != _photoToken) return;
    setState(() {
      _lifting = false;
      _cutout = stored;
      _useCutout = true;
      _noGarment = stored == null && !result.unavailable;
      _inPlace = result.inPlace;
      _geometry = result.geometry;
      _playLift = stored != null && result.geometry != null;
    });
    if (!asked && _name.text.isEmpty && !_nameFocus.hasFocus) {
      // Let the lift play (about 1.5 s), then ask for the name.
      final wait = stored == null || MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1400);
      Future.delayed(wait, () {
        if (mounted && token == _photoToken && !_nameFocus.hasFocus) _nameFocus.requestFocus();
      });
    }
    if (stored == null && asked) {
      final s = S.of(context);
      showMessage(
        context,
        result.downloading ? s.cutoutNotReady : (result.unavailable ? s.cutoutFailed : s.noCutout),
      );
    }
  }

  /// Removing the background from a photo saved before this feature.
  Future<void> _liftExisting() async {
    final ref = _original;
    if (ref == null) return;
    final bytes = await ImageStore.read(ref);
    if (bytes == null || !mounted) return;
    _liftDone = _lift(bytes, _photoToken, asked: true);
  }

  void _toggleCutout() {
    HapticFeedback.selectionClick();
    if (_cutout == null) {
      _liftExisting();
    } else {
      setState(() => _useCutout = !_useCutout);
    }
  }

  void _rotate() {
    HapticFeedback.selectionClick();
    setState(() => _turns++);
  }

  void _clearPhoto() {
    _photoToken++;
    _original = null;
    _cutout = null;
    _useCutout = true;
    _turns = 0;
    _lifting = false;
    _noGarment = false;
    _liftDone = null;
    _inPlace = null;
    _geometry = null;
    _playLift = false;
  }

  /// The image to save: waits for a cutout still being made, and bakes in
  /// any quarter turns.
  Future<String?> _finalImage() async {
    if (_liftDone != null) await _liftDone;
    final ref = _image;
    if (ref == null || _turns % 4 == 0) return ref;
    final bytes = await ImageStore.read(ref);
    if (bytes == null) return ref;
    return ImageStore.saveBytes(await Cutout.rotateQuarter(bytes, turns: _turns));
  }

  String? _clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  bool _validate() {
    if (_name.text.trim().isNotEmpty) return true;
    setState(() => _showNameError = true);
    _nameFocus.requestFocus();
    return false;
  }

  /// Whether closing now would lose something the person entered.
  bool get _hasUnsavedInput {
    String text(TextEditingController c) => c.text.trim();
    final g = widget.editing;
    if (g == null) {
      return _image != null || text(_name).isNotEmpty || text(_brand).isNotEmpty || text(_notes).isNotEmpty;
    }
    return text(_name) != g.name ||
        text(_brand) != (g.brand ?? '') ||
        text(_notes) != (g.notes ?? '') ||
        _category != g.category ||
        _image != g.imageUrl ||
        _turns % 4 != 0;
  }

  /// Back, swipe back or ✕: ask before throwing away a photo or edits.
  Future<void> _confirmLeave() async {
    final s = S.of(context);
    if (_hasUnsavedInput) {
      final discard = await confirmAction(
        context,
        title: _isEdit ? s.discardChangesTitle : s.discardPieceTitle,
        body: _isEdit ? null : s.discardPieceBody,
        confirmLabel: s.discard,
        cancelLabel: s.keepEditing,
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _saveEdit() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    final image = await _finalImage();
    if (!mounted) return;
    AppScope.read(context).updateGarment(
      widget.editing!.edited(
        name: _name.text.trim(),
        category: _category,
        brand: _clean(_brand),
        notes: _clean(_notes),
        imageUrl: image,
      ),
    );
    Navigator.of(context).pop();
  }

  /// Saves the current piece. With [next], resets for the next one.
  Future<void> _add({required bool next}) async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    final image = await _finalImage();
    if (!mounted) return;
    setState(() => _saving = false);
    final s = S.of(context);
    final garment = AppScope.read(context).addGarment(
      name: _name.text,
      category: _category,
      status: _dirty ? GarmentStatus.dirtyHamper : GarmentStatus.closet,
      brand: _brand.text,
      notes: _notes.text,
      imageUrl: image,
    );
    _lastCategory = _category;
    HapticFeedback.lightImpact();
    _added++;

    if (!next) {
      final messenger = widget.messenger ?? ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showMessageOn(messenger, _added > 1 ? s.addedCount(_added) : s.added(garment.name));
      return;
    }

    setState(() {
      _name.clear();
      _brand.clear();
      _notes.clear();
      _clearPhoto();
      _showNameError = false;
    });
    if (_queue.isNotEmpty) {
      await _usePhoto(_queue.removeAt(0));
    } else {
      _queueTotal = 0;
      if (_hasCamera) {
        await _takePhoto(auto: true);
      } else {
        _nameFocus.requestFocus();
      }
    }
  }

  Future<void> _skip() async {
    setState(_clearPhoto);
    if (_queue.isNotEmpty) {
      await _usePhoto(_queue.removeAt(0));
    } else {
      setState(() => _queueTotal = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final inQueue = _queueTotal > 0;
    final current = _queueTotal - _queue.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _isEdit ? s.cancel : s.done,
            icon: const Icon(AppIcons.close),
            onPressed: _confirmLeave,
          ),
          title: Text(_isEdit ? s.editGarment : (inQueue ? s.queueProgress(current, _queueTotal) : s.addClothes)),
          actions: [
            if (_isEdit)
              TextButton(
                onPressed: _saving ? null : _saveEdit,
                child: Text(s.save, style: const TextStyle(fontWeight: FontWeight.w700)),
              )
            else if (_added > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    s.addedCount(_added),
                    style: context.text.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    _photoArea(context, s),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: _isEdit ? TextInputAction.done : TextInputAction.next,
                      style: context.text.bodyLarge,
                      onChanged: (_) {
                        if (_showNameError) setState(() => _showNameError = false);
                      },
                      onSubmitted: (_) => _isEdit ? _saveEdit() : _add(next: true),
                      decoration: InputDecoration(
                        labelText: s.name,
                        hintText: s.nameHint,
                        errorText: _showNameError ? s.nameRequired : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(s.category, style: context.text.labelMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in GarmentCategory.values)
                          Pill(
                            icon: categoryIcon(c),
                            label: s.categoryLabel(c),
                            selected: _category == c,
                            onTap: () => setState(() => _category = c),
                          ),
                      ],
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.alreadyDirty),
                        value: _dirty,
                        onChanged: (v) => setState(() => _dirty = v),
                      ),
                    ],
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: _isEdit && (_brand.text.isNotEmpty || _notes.text.isNotEmpty),
                        title: Text(
                          '${s.brand}, ${s.notes.toLowerCase()} · ${s.optional.toLowerCase()}',
                          style: context.text.bodyMedium,
                        ),
                        children: [
                          TextField(
                            controller: _brand,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(labelText: s.brand),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notes,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(labelText: s.notes),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isEdit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: _busy || _saving ? null : () => _add(next: false), child: Text(s.add)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _busy || _saving ? null : () => _add(next: true),
                          icon: Icon(_hasCamera ? AppIcons.camera : AppIcons.forward),
                          label: Text(s.addAndNext),
                        ),
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

  Widget _preview(BuildContext context, S s, Garment preview) {
    final ref = _image!;
    final cutoutOn = _useCutout && _cutout != null;
    final canCutout =
        _cutout != null || (Cutout.supported && !ImageStore.isCutout(_original) && !_lifting && !_noGarment);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final isFileCutout = ImageStore.isCutout(ref) && !kIsWeb && !ref.startsWith('data:');
    final original = _original;
    final lift = isFileCutout &&
        ref == _cutout &&
        _playLift &&
        !reduceMotion &&
        _inPlace != null &&
        _geometry != null &&
        original != null &&
        !ImageStore.isCutout(original) &&
        !original.startsWith('data:');
    // The lift and the still cutout share one slot, so finishing the lift
    // swaps them without a visible change.
    final Widget picture = isFileCutout
        ? _Slot(
            key: ValueKey(ref),
            child: lift
                ? _LiftReveal(
                    photo: File(original),
                    inPlace: _inPlace!,
                    geometry: _geometry!,
                    finalFile: File(ref),
                    onDone: () {
                      if (mounted) setState(() => _playLift = false);
                    },
                  )
                : _CutoutPreview(file: File(ref)),
          )
        : _Slot(key: ValueKey(ref), child: GarmentImage(garment: preview, iconSize: 64));

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedRotation(
          turns: _turns / 4,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            // The lift starts from the photo itself, so it needs no crossfade.
            duration: reduceMotion || lift ? Duration.zero : const Duration(milliseconds: 450),
            // Fill the square, as the photo did before it could switch.
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            // The old picture melts away: it fades and goes soft as the
            // new one comes into focus.
            transitionBuilder: (child, anim) => AnimatedBuilder(
              animation: anim,
              child: child,
              builder: (context, child) {
                final blur = (1 - anim.value) * 14;
                return Opacity(
                  opacity: anim.value,
                  child: blur < 0.1
                      ? child
                      : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: child),
                );
              },
            ),
            child: picture,
          ),
        ),
        // While it works, a soft glow turns slowly around the photo's edge.
        if (_lifting && !reduceMotion) const Positioned.fill(child: IgnorePointer(child: _ThinkingGlow())),
        if (_lifting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(
              child: _Pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(s.liftingOut, style: context.text.labelMedium?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _PhotoButton(icon: AppIcons.rotate, tooltip: s.rotate, onPressed: _saving ? null : _rotate),
              if (canCutout) ...[
                const SizedBox(height: 8),
                _PhotoButton(
                  icon: cutoutOn ? AppIcons.cutoutOn : AppIcons.cutout,
                  tooltip: cutoutOn ? s.showOriginal : s.showCutout,
                  selected: cutoutOn,
                  onPressed: _saving ? null : _toggleCutout,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoArea(BuildContext context, S s) {
    final preview = Garment(id: 'preview', name: _name.text, category: _category, imageUrl: _image);
    final hasPhoto = _image != null;
    final inQueue = _queueTotal > 0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 1,
            child: _busy
                ? ColoredBox(
                    color: context.palette.tile,
                    child: const Center(child: CircularProgressIndicator.adaptive()),
                  )
                : hasPhoto
                ? _preview(context, s, preview)
                : Material(
                    color: context.palette.tile,
                    child: InkWell(
                      onTap: _hasCamera ? _takePhoto : _choosePhotos,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(color: context.ink, shape: BoxShape.circle),
                            child: Icon(AppIcons.camera, size: 30, color: context.colors.surface),
                          ),
                          const SizedBox(height: 14),
                          Text(s.addPhoto, style: context.text.titleMedium),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_hasCamera) ...[
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : _takePhoto,
                  icon: const Icon(AppIcons.cameraOutline),
                  label: Text(hasPhoto ? s.changePhoto : s.takePhoto),
                ),
              ),
            ],
            Expanded(
              child: TextButton.icon(
                onPressed: _busy ? null : _choosePhotos,
                icon: const Icon(AppIcons.library),
                label: Text(!_hasCamera && hasPhoto ? s.changePhoto : s.choosePhotos),
              ),
            ),
            if (inQueue) TextButton(onPressed: _busy ? null : _skip, child: Text(s.skip)),
          ],
        ),
      ],
    );
  }
}

/// A frosted capsule that reads over any photo.
class _Pill extends StatelessWidget {
  final Widget child;

  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.6),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), child: child),
      ),
    ),
  );
}

/// A round button laid over the photo's corner.
class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  const _PhotoButton({required this.icon, required this.tooltip, this.selected = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? Colors.white : Colors.black.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: 22, color: selected ? Colors.black : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a picture in one place in the preview's switcher, whatever it
/// shows inside, so changing its inside isn't a transition.
class _Slot extends StatelessWidget {
  final Widget child;

  const _Slot({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// The glow while the background is being removed: soft color that turns
/// slowly around the inside of the photo's edge, the way Apple shows that
/// something is thinking.
class _ThinkingGlow extends StatefulWidget {
  const _ThinkingGlow();

  @override
  State<_ThinkingGlow> createState() => _ThinkingGlowState();
}

class _ThinkingGlowState extends State<_ThinkingGlow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();

  @override
  void dispose() {
    _c.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
      child: CustomPaint(painter: _GlowPainter(_c)),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Animation<double> turn;

  _GlowPainter(this.turn) : super(repaint: turn);

  static const _colors = [
    Color(0xFF4D8EFF),
    Color(0xFFB467FF),
    Color(0xFFFF6CA8),
    Color(0xFFFF9F45),
    Color(0xFF4D8EFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      colors: _colors,
      transform: GradientRotation(turn.value * 2 * math.pi),
    ).createShader(rect);
    final edge = RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(27));
    // A wide soft bloom, then a fine bright line at the very edge.
    canvas.drawRRect(
      edge,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => false;
}

/// The finished cutout on its tile, framed the same as the lift ends.
class _CutoutPreview extends StatelessWidget {
  final File file;

  const _CutoutPreview({required this.file});

  static const inset = 24.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.tile,
      child: Padding(
        padding: const EdgeInsets.all(inset),
        child: Image(image: FileImage(file), fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }
}

/// Lifting the garment out of its photo, the way Apple's "lift subject"
/// feels. The garment never jumps: it stays exactly where it is while the
/// background melts away under it and a soft glow blooms around its edge.
/// A glint of light passes over it as it lifts off the page, then it
/// glides, straightening, into its place on the tile, and settles.
class _LiftReveal extends StatefulWidget {
  final File photo;
  final Uint8List inPlace;
  final CutoutGeometry geometry;
  final File finalFile;
  final VoidCallback onDone;

  const _LiftReveal({
    required this.photo,
    required this.inPlace,
    required this.geometry,
    required this.finalFile,
    required this.onDone,
  });

  @override
  State<_LiftReveal> createState() => _LiftRevealState();
}

class _LiftRevealState extends State<_LiftReveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  late final MemoryImage _subject = MemoryImage(widget.inPlace);
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_tapped && _c.value >= 0.34) {
        _tapped = true;
        HapticFeedback.lightImpact();
      }
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    return LayoutBuilder(
      builder: (context, box) {
        final d = box.biggest.shortestSide;
        final center = Offset(d / 2, d / 2);
        // The photo fills the square (cover); the cutout sits inside the
        // tile's inset (contain). Work out where the garment goes.
        final cover = math.max(d / g.width, d / g.height);
        final fit = (d - 2 * _CutoutPreview.inset) / g.side;
        final target = Offset(_CutoutPreview.inset, _CutoutPreview.inset) +
            (Offset(g.turnedWidth / 2, g.turnedHeight / 2) -
                    g.box.topLeft +
                    Offset((g.side - g.box.width) / 2, (g.side - g.box.height) / 2)) *
                fit;
        final endScale = fit / cover;
        final angle = g.turn * math.pi / 180;

        Widget subject(Color? tint) => Image(
          image: _subject,
          fit: BoxFit.cover,
          width: d,
          height: d,
          gaplessPlayback: true,
          color: tint,
          colorBlendMode: tint == null ? null : BlendMode.srcIn,
        );

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final melt = Curves.easeInOut.transform(_span(t, 0.0, 0.42));
            final glow = math.sin(math.pi * _span(t, 0.08, 0.78));
            final lift = math.sin(math.pi * _span(t, 0.12, 0.95)) * 1;
            final glide = Curves.easeInOutCubic.transform(_span(t, 0.42, 0.95));
            final sheen = _span(t, 0.26, 0.62);

            // Where the garment is: in the photo, then on its tile.
            final move = (target - center) * glide;
            final scale = (1 + (endScale - 1) * glide) * (1 + 0.045 * lift);

            Widget placed(Widget child) => Transform.translate(
              offset: move,
              child: Transform.rotate(
                angle: angle * glide,
                child: Transform.scale(scale: scale, child: child),
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: context.palette.tile),
                // The background melts away: softens and fades.
                if (melt < 1)
                  Opacity(
                    opacity: 1 - melt,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18 * melt + 0.01, sigmaY: 18 * melt + 0.01),
                      child: Image(image: FileImage(widget.photo), fit: BoxFit.cover, gaplessPlayback: true),
                    ),
                  ),
                // The shadow, as it rises off the page.
                if (lift > 0.01)
                  placed(
                    Transform.translate(
                      offset: Offset(0, 10 * lift),
                      child: Opacity(
                        opacity: 0.22 * lift,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: subject(Colors.black),
                        ),
                      ),
                    ),
                  ),
                // A soft white bloom around the edge.
                if (glow > 0.01)
                  placed(
                    Opacity(
                      opacity: 0.9 * glow,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                        child: subject(Colors.white),
                      ),
                    ),
                  ),
                // The garment, with a glint of light passing over it.
                placed(
                  sheen <= 0 || sheen >= 1
                      ? subject(null)
                      : ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: [
                              (sheen * 1.4 - 0.3).clamp(0.0, 1.0),
                              (sheen * 1.4 - 0.2).clamp(0.0, 1.0),
                              (sheen * 1.4 - 0.1).clamp(0.0, 1.0),
                            ],
                          ).createShader(rect),
                          child: subject(null),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
