import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/garment.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';

class AddGarmentModal extends StatefulWidget {
  final WardrobeState state;

  const AddGarmentModal({super.key, required this.state});

  static Future<void> show(BuildContext context, WardrobeState state) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddGarmentModal(state: state),
    );
  }

  @override
  State<AddGarmentModal> createState() => _AddGarmentModalState();
}

class _AddGarmentModalState extends State<AddGarmentModal> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _fabricController = TextEditingController();

  GarmentCategory _selectedCategory = GarmentCategory.tops;
  GarmentStatus _initialStatus = GarmentStatus.closet;

  String? _selectedImagePath;
  bool _isSaving = false;

  final List<int> _colorPalette = [
    0xFF0058BE,
    0xFF006C49,
    0xFFB45309,
    0xFF475569,
    0xFF7C3AED,
    0xFFE11D48,
    0xFF0D9488,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _fabricController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null) {
        String finalPath = picked.path;

        // On mobile/desktop, copy file permanently to application documents directory
        if (!kIsWeb) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final garmentsDir = Directory('${appDir.path}/garments');
            if (!garmentsDir.existsSync()) {
              garmentsDir.createSync(recursive: true);
            }
            final fileName =
                'garment_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final savedImage =
                await File(picked.path).copy('${garmentsDir.path}/$fileName');
            finalPath = savedImage.path;
          } catch (e) {
            debugPrint('Failed to copy file to documents dir: $e');
          }
        }

        setState(() {
          _selectedImagePath = finalPath;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access camera/photo: $e')),
      );
    }
  }

  void _saveGarment() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a garment name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    widget.state.addGarment(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      initialStatus: _initialStatus,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      fabricNotes: _fabricController.text.trim().isEmpty
          ? null
          : _fabricController.text.trim(),
      imageUrl: _selectedImagePath,
      fallbackColor: _colorPalette[_selectedCategory.index % _colorPalette.length],
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.secondary,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${_nameController.text.trim()} added to ${_initialStatus == GarmentStatus.closet ? 'Closet' : 'Hamper'}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset > 0 ? bottomInset : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Upload Garment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0x1F000000)),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Intake Card
                  _buildPhotoSection(),
                  const SizedBox(height: 20),

                  // Garment Name
                  const Text(
                    'Garment Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Vintage Denim Jacket',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0x1F000000)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0x1F000000)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Brand & Fabric Notes
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Brand (Optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _brandController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Uniqlo / Levi\'s',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Color(0x1F000000)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Color(0x1F000000)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fabric / Care',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _fabricController,
                              decoration: InputDecoration(
                                hintText: 'e.g. 100% Cotton · Cold',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Color(0x1F000000)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Color(0x1F000000)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Category Selector
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCategoryGrid(),
                  const SizedBox(height: 20),

                  // Initial Location Switcher
                  const Text(
                    'Initial Location',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLocationToggle(),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveGarment,
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Garment to Wardrobe',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    final hasImage = _selectedImagePath != null && _selectedImagePath!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x1F000000)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                _buildImagePreview()
              else
                _buildNoImagePlaceholder(),
              // Camera & Gallery action pill overlay
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded, size: 16),
                        label: Text(
                          hasImage ? 'Retake' : 'Take Photo',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: AppColors.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text(
                          'From Gallery',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: AppColors.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final path = _selectedImagePath!;
    if (kIsWeb || path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo_rounded,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Snap or Upload Garment Photo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Photos are saved permanently to your phone',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Row(
      children: GarmentCategory.values.map((cat) {
        final isSelected = _selectedCategory == cat;
        IconData icon;
        switch (cat) {
          case GarmentCategory.tops:
            icon = Icons.dry_cleaning_rounded;
            break;
          case GarmentCategory.bottoms:
            icon = Icons.view_column_rounded;
            break;
          case GarmentCategory.outerwear:
            icon = Icons.layers_rounded;
            break;
          case GarmentCategory.delicates:
            icon = Icons.spa_rounded;
            break;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0x1F000000),
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x220058BE),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.onSurface,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _initialStatus = GarmentStatus.closet),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _initialStatus == GarmentStatus.closet
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _initialStatus == GarmentStatus.closet
                      ? const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checkroom_rounded,
                      size: 16,
                      color: _initialStatus == GarmentStatus.closet
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'In Closet (Clean)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _initialStatus == GarmentStatus.closet
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _initialStatus == GarmentStatus.closet
                            ? AppColors.secondary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _initialStatus = GarmentStatus.dirtyHamper),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _initialStatus == GarmentStatus.dirtyHamper
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _initialStatus == GarmentStatus.dirtyHamper
                      ? const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_basket_rounded,
                      size: 16,
                      color: _initialStatus == GarmentStatus.dirtyHamper
                          ? AppColors.tertiary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'In Hamper (Dirty)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _initialStatus == GarmentStatus.dirtyHamper
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _initialStatus == GarmentStatus.dirtyHamper
                            ? AppColors.tertiary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
