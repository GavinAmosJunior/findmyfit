import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/strings.dart';
import '../models/garment.dart';
import '../services/image_store.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/garment_image.dart';
import '../theme/app_icons.dart';

/// Adding is camera-first: snap a photo, type a name, tap "Add and next",
/// and the camera opens again for the next piece. "Choose photos" queues
/// several gallery photos to name one after another.
///
/// The same screen edits an existing garment.
class GarmentFormScreen extends StatefulWidget {
  final Garment? editing;

  /// Where to show "Added" once this screen closes (the caller's tab).
  final ScaffoldMessengerState? messenger;

  const GarmentFormScreen({super.key, this.editing, this.messenger});

  static Future<void> openAdd(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GarmentFormScreen(messenger: ScaffoldMessenger.of(context)),
    ),
  );

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
  String? _image;
  bool _dirty = false;
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
      _image = g.imageUrl;
    } else if (_hasCamera) {
      // Camera-first: open it straight away on phones.
      WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
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

  Future<void> _takePhoto() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: ImageStore.maxSize,
        maxHeight: ImageStore.maxSize,
        imageQuality: ImageStore.quality,
      );
      if (shot != null) await _usePhoto(shot);
    } catch (_) {
      if (mounted) showMessage(context, S.of(context).photoError);
    }
  }

  Future<void> _choosePhotos() async {
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
      if (many.isEmpty) return;
      _queue
        ..clear()
        ..addAll(many.skip(1));
      _queueTotal = many.length;
      await _usePhoto(many.first);
    } catch (_) {
      if (mounted) showMessage(context, S.of(context).photoError);
    }
  }

  Future<void> _usePhoto(XFile file) async {
    setState(() => _busy = true);
    final stored = await ImageStore.savePicked(file);
    if (!mounted) return;
    setState(() {
      _image = stored;
      _busy = false;
    });
    _nameFocus.requestFocus();
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
        _image != g.imageUrl;
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

  void _saveEdit() {
    if (!_validate()) return;
    AppScope.read(context).updateGarment(
      widget.editing!.edited(
        name: _name.text.trim(),
        category: _category,
        brand: _clean(_brand),
        notes: _clean(_notes),
        imageUrl: _image,
      ),
    );
    Navigator.of(context).pop();
  }

  /// Saves the current piece. With [next], resets for the next one.
  Future<void> _add({required bool next}) async {
    if (!_validate()) return;
    final s = S.of(context);
    final garment = AppScope.read(context).addGarment(
      name: _name.text,
      category: _category,
      status: _dirty ? GarmentStatus.dirtyHamper : GarmentStatus.closet,
      brand: _brand.text,
      notes: _notes.text,
      imageUrl: _image,
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
      _image = null;
      _showNameError = false;
    });
    if (_queue.isNotEmpty) {
      await _usePhoto(_queue.removeAt(0));
    } else {
      _queueTotal = 0;
      if (_hasCamera) {
        await _takePhoto();
      } else {
        _nameFocus.requestFocus();
      }
    }
  }

  Future<void> _skip() async {
    setState(() => _image = null);
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
              TextButton(onPressed: _saveEdit, child: Text(s.save))
            else if (_added > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text(s.addedCount(_added), style: context.text.labelMedium)),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in GarmentCategory.values)
                          ChoiceChip(
                            avatar: Icon(
                              categoryIcon(c),
                              size: 18,
                              color: _category == c ? context.colors.surface : context.palette.secondaryText,
                            ),
                            label: Text(s.categoryLabel(c)),
                            selected: _category == c,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _category = c);
                            },
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
                        child: OutlinedButton(onPressed: _busy ? null : () => _add(next: false), child: Text(s.add)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _add(next: true),
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

  Widget _photoArea(BuildContext context, S s) {
    final preview = Garment(id: 'preview', name: _name.text, category: _category, imageUrl: _image);
    final hasPhoto = _image != null;
    final inQueue = _queueTotal > 0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: _busy
                ? ColoredBox(
                    color: context.palette.card,
                    child: const Center(child: CircularProgressIndicator.adaptive()),
                  )
                : hasPhoto
                ? GarmentImage(garment: preview, iconSize: 64)
                : Material(
                    color: context.palette.card,
                    child: InkWell(
                      onTap: _hasCamera ? _takePhoto : _choosePhotos,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.addPhoto, size: 48, color: context.colors.primary),
                          const SizedBox(height: 10),
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
