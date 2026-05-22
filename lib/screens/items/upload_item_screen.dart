import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/item.dart';
import '../../services/item_service.dart';
import '../../services/photo_service.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);
const _kDanger = Color(0xFFC44545);

// ---------------------------------------------------------------------------
// UploadItemScreen
// ---------------------------------------------------------------------------

/// Upload Item form — WBS 6.2.
///
/// Creates a new `/items/{itemId}` document with `status: 'active'` and
/// `ownerId` set to [ownerId].
///
/// All 7 fields from the prototype spec are implemented:
///   1. Photo (required)
///   2. Name (required, 1–60 chars)
///   3. Category (required, 7 options)
///   4. Condition (required, 4 options)
///   5. Weight in kg (optional decimal)
///   6. Description (optional, max 280 chars)
///   7. Wants (optional, max 140 chars)
///
/// Injectable [itemService] and [photoService] for widget tests.
class UploadItemScreen extends StatefulWidget {
  final String ownerId;
  final ItemService? itemService;
  final PhotoService? photoService;

  const UploadItemScreen({
    super.key,
    required this.ownerId,
    this.itemService,
    this.photoService,
  });

  @override
  State<UploadItemScreen> createState() => _UploadItemScreenState();
}

class _UploadItemScreenState extends State<UploadItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _descController = TextEditingController();
  final _wantsController = TextEditingController();

  String? _photoUrl;
  ItemCategory? _category;
  ItemCondition? _condition;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _descController.dispose();
    _wantsController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ItemService get _itemService => widget.itemService ?? ItemService();
  PhotoService get _photoService => widget.photoService ?? PhotoService();

  bool get _formValid =>
      _photoUrl != null &&
      _nameController.text.trim().isNotEmpty &&
      _category != null &&
      _condition != null;

  Future<void> _pickPhoto() async {
    setState(() {
      _isUploadingPhoto = true;
      _submitError = null;
    });
    try {
      // We use a temporary placeholder path; the real itemId is assigned on
      // submit. For the MVP single-photo flow this is acceptable.
      final tempId =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.ownerId}';
      final url = await _photoService.pickAndUpload(
        storagePath: 'item_photos/$tempId.jpg',
      );
      if (url != null && mounted) {
        setState(() => _photoUrl = url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitError = 'Photo upload failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formValid) return;
    // Run form validation (name length, weight format).
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final weightText = _weightController.text.trim();
      final weight = weightText.isEmpty ? null : double.tryParse(weightText);

      final item = Item(
        id: '',
        ownerId: widget.ownerId,
        name: _nameController.text.trim(),
        category: _category!,
        condition: _condition!,
        weight: weight,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        wants: _wantsController.text.trim().isEmpty
            ? null
            : _wantsController.text.trim(),
        photoUrl: _photoUrl!,
        status: 'active',
      );

      await _itemService.createItem(item);

      if (mounted) {
        Navigator.pop(context, true); // signal success to caller
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitError = 'Could not save item. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _kTextSecondary,
        letterSpacing: 0.1,
      ),
    ),
  );

  InputDecoration _inputDecoration({String? hintText, String? suffixText}) =>
      InputDecoration(
        filled: true,
        fillColor: _kSurfaceAlt,
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 15, color: _kTextTertiary),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontSize: 13, color: _kTextTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGreenPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kDanger, width: 2),
        ),
        constraints: const BoxConstraints(minHeight: 44),
      );

  // ---------------------------------------------------------------------------
  // Photo field
  // ---------------------------------------------------------------------------

  Widget _buildPhotoField() {
    if (_photoUrl == null) {
      return GestureDetector(
        key: const Key('photo_field_empty'),
        onTap: _isUploadingPhoto ? null : _pickPhoto,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: _kSurfaceAlt,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isUploadingPhoto
                ? const Center(
                    child: CircularProgressIndicator(color: _kGreenPrimary),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 32,
                        color: _kTextTertiary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add a photo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _kTextSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to use camera or library',
                        style: TextStyle(fontSize: 12, color: _kTextTertiary),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    // Photo selected — show network image with a "Change photo" overlay.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _photoUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => Container(
                  color: _kSurfaceAlt,
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: _kTextTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(235),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: _kGreenPrimary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Change photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kGreenPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Condition pills
  // ---------------------------------------------------------------------------

  Widget _buildConditionPills() {
    return Wrap(
      spacing: 8,
      children: ItemCondition.values.map((c) {
        final selected = _condition == c;
        return GestureDetector(
          onTap: () => setState(() => _condition = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kGreenSoft : _kSurfaceAlt,
              border: Border.all(color: selected ? _kGreenPrimary : _kBorder),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              c.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? _kGreenDark : _kTextSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Category row — opens bottom sheet
  // ---------------------------------------------------------------------------

  Widget _buildCategoryRow() {
    final label = _category?.label;
    return GestureDetector(
      key: const Key('category_row'),
      onTap: _showCategoryPicker,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? 'Select a category',
                style: TextStyle(
                  fontSize: 15,
                  color: label != null ? _kTextPrimary : _kTextTertiary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategoryPickerSheet(
        selected: _category,
        onPick: (cat) {
          setState(() => _category = cat);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add an item',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1 — Photo
                    _fieldLabel('Photo'),
                    _buildPhotoField(),
                    const SizedBox(height: 24),

                    // 2 — Item name
                    _fieldLabel('What is it?'),
                    TextFormField(
                      key: const Key('field_name'),
                      controller: _nameController,
                      maxLength: 60,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        hintText: 'e.g. Leather tote bag',
                      ).copyWith(counterText: ''),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Item name is required';
                        if (val.length > 60) {
                          return 'Name must be 60 characters or fewer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3 — Category
                    _fieldLabel('Category'),
                    _buildCategoryRow(),
                    const SizedBox(height: 24),

                    // 4 — Condition
                    _fieldLabel('Condition'),
                    _buildConditionPills(),
                    const SizedBox(height: 24),

                    // 5 — Weight
                    _fieldLabel('Weight'),
                    TextFormField(
                      key: const Key('field_weight'),
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: _inputDecoration(
                        hintText: _category != null
                            ? '${_category!.typicalWeightKg} kg typical for ${_category!.label.toLowerCase()}'
                            : 'approx. weight',
                        suffixText: 'kg',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return null; // optional
                        final parsed = double.tryParse(val);
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid weight in kg';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Used to estimate the CO₂ impact of your swap. '
                      "We'll use a typical weight for the category if you skip this.",
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextTertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6 — Description
                    _fieldLabel('Description (optional)'),
                    TextFormField(
                      key: const Key('field_description'),
                      controller: _descController,
                      maxLines: 4,
                      maxLength: 280,
                      inputFormatters: [LengthLimitingTextInputFormatter(280)],
                      decoration: _inputDecoration(
                        hintText:
                            "Anything worth mentioning — brand, size, why you're letting it go…",
                      ).copyWith(counterText: ''),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 7 — Wants
                    _fieldLabel('What would you like in return?'),
                    TextFormField(
                      key: const Key('field_wants'),
                      controller: _wantsController,
                      maxLines: 3,
                      maxLength: 140,
                      inputFormatters: [LengthLimitingTextInputFormatter(140)],
                      decoration: _inputDecoration(
                        hintText:
                            'e.g. books, kitchenware, or something useful for a dorm',
                      ).copyWith(counterText: ''),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Sticky bottom bar
            Container(
              color: _kSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: _kBorder),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_submitError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _submitError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _kDanger,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('btn_submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreenPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _kGreenPrimary.withAlpha(
                                102,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: (_formValid && !_isSubmitting)
                                ? _submit
                                : null,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Add to my swaps'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category picker bottom sheet
// ---------------------------------------------------------------------------

class _CategoryPickerSheet extends StatelessWidget {
  final ItemCategory? selected;
  final ValueChanged<ItemCategory> onPick;

  const _CategoryPickerSheet({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Pick a category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Helps others find your item, and how we estimate impact.',
              style: TextStyle(fontSize: 13, color: _kTextSecondary),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              child: Column(
                children: ItemCategory.values.map((cat) {
                  final on = selected == cat;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onPick(cat),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: on ? _kGreenSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cat.hint,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (on)
                              const Icon(
                                Icons.check,
                                size: 20,
                                color: _kGreenPrimary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
