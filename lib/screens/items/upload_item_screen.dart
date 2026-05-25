import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../constants/impact.dart';
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
const _kDangerSoft = Color(0xFFFCEBEB);

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Returns the current Firebase Auth user's UID, or null when not signed in.
typedef CurrentUidGetter = String? Function();

String? _defaultCurrentUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// FieldLabel widget  (matches prototype FieldLabel atom)
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}

// ---------------------------------------------------------------------------
// PhotoField widget  (matches prototype PhotoField atom)
// ---------------------------------------------------------------------------

class _PhotoField extends StatelessWidget {
  final bool hasPhoto;
  final double? uploadProgress;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  /// The uploaded photo URL — shown as actual image when non-empty.
  final String? imageUrl;

  const _PhotoField({
    required this.hasPhoto,
    required this.onTap,
    this.uploadProgress,
    this.onRemove,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final showImage = hasPhoto && imageUrl != null && imageUrl!.isNotEmpty;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        key: const Key('photoField'),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: uploadProgress != null
              ? Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: uploadProgress,
                      color: _kGreenPrimary,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // Actual photo
                    GestureDetector(
                      onTap: onTap,
                      child: showImage
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: _kGreenSoft,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 40,
                                    color: _kGreenDark,
                                  ),
                                ),
                              ),
                            )
                          : Container(color: _kGreenSoft),
                    ),
                    // Remove button — top-right
                    if (onRemove != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Change photo button — bottom-right
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: _kGreenPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
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
                )
              : GestureDetector(
                  onTap: onTap,
                  child: Column(
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
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ConditionPills widget  (matches prototype ConditionPills atom)
// ---------------------------------------------------------------------------

class _ConditionPills extends StatelessWidget {
  final ItemCondition? value;
  final ValueChanged<ItemCondition> onChanged;

  const _ConditionPills({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ItemCondition.values.map((condition) {
          final isSelected = condition == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(condition),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _kGreenSoft : _kSurfaceAlt,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isSelected ? _kGreenPrimary : _kBorder,
                  ),
                ),
                child: Text(
                  condition.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? _kGreenDark : _kTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryRow widget  (matches prototype CategoryRow atom)
// ---------------------------------------------------------------------------

class _CategoryRow extends StatelessWidget {
  final ItemCategory? value;
  final VoidCallback onTap;

  const _CategoryRow({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value?.label ?? 'Select a category',
              style: TextStyle(
                fontSize: 15,
                color: value != null ? _kTextPrimary : _kTextTertiary,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WeightField widget  (matches prototype WeightField atom)
// ---------------------------------------------------------------------------

class _WeightField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final String? placeholder;

  const _WeightField({
    required this.value,
    required this.onChanged,
    this.placeholder,
  });

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _hasFocus = focused),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hasFocus ? _kGreenPrimary : _kBorder,
            width: _hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('weightField'),
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: widget.placeholder ?? 'approx. weight (optional)',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: _kTextTertiary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15, color: _kTextPrimary),
                onChanged: widget.onChanged,
              ),
            ),
            const Text(
              'kg',
              style: TextStyle(fontSize: 13, color: _kTextTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryPicker bottom sheet
// ---------------------------------------------------------------------------

class _CategoryPickerSheet extends StatelessWidget {
  final ItemCategory? value;
  final ValueChanged<ItemCategory> onPick;

  const _CategoryPickerSheet({required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Constrain height so the sheet never exceeds 70% of the screen,
      // and the ListView inside is always scrollable in tests.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pick a category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Helps others find your item, and how we estimate impact.',
                  style: TextStyle(fontSize: 13, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          // Category options — scrollable so all 7 are reachable
          Flexible(
            child: ListView(
              key: const Key('categoryPickerList'),
              shrinkWrap: true,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              children: ItemCategory.values.map((cat) {
                final isSelected = cat == value;
                return InkWell(
                  key: Key('categoryOption_${cat.value}'),
                  onTap: () {
                    onPick(cat);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _kGreenSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            size: 20,
                            color: _kGreenPrimary,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UploadItemScreen
// ---------------------------------------------------------------------------

/// Upload Item screen — WBS 6.2.
///
/// Doubles as the Edit Item form when [initialItem] is provided (WBS 6.4).
/// In edit mode the title changes to "Edit item", the submit label to
/// "Save changes", and a destructive "Delete item" button appears.
///
/// Fields:
///   - Photo (required)
///   - Name (required, 1–60 chars)
///   - Category (required, 7 options)
///   - Condition (required, 4 options as pills)
///   - Weight in kg (optional decimal)
///   - Description (optional, max 280 chars)
///   - Wants (optional, max 140 chars)
///
/// On submit (create mode): writes to `/items/{itemId}` with `status: 'active'`
/// and `ownerId: currentUid`.
/// On submit (edit mode): updates only the user-editable fields.
///
/// All dependencies are injectable for tests.
class UploadItemScreen extends StatefulWidget {
  /// Injectable [PhotoService] — defaults to production instance.
  final PhotoService? photoService;

  /// Injectable [ItemService] — defaults to production instance.
  final ItemService? itemService;

  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  /// Called after a successful item submission; used by tests to verify
  /// navigation intent.
  final VoidCallback? onSubmitSuccess;

  /// When set, the screen operates in edit mode: fields are pre-filled from
  /// this item, the form calls [ItemService.updateItem] on save, and a
  /// destructive delete button is shown.
  final Item? initialItem;

  /// Called after a successful soft-delete; used by tests to verify intent.
  final VoidCallback? onDeleteSuccess;

  const UploadItemScreen({
    super.key,
    this.photoService,
    this.itemService,
    this.getCurrentUid,
    this.onSubmitSuccess,
    this.initialItem,
    this.onDeleteSuccess,
  });

  @override
  State<UploadItemScreen> createState() => _UploadItemScreenState();
}

class _UploadItemScreenState extends State<UploadItemScreen> {
  // Form state
  bool _hasPhoto = false;
  String _photoUrl = '';
  double? _uploadProgress;

  final _nameController = TextEditingController();
  ItemCategory? _category;
  ItemCondition? _condition;
  final _weightController = TextEditingController();
  final _descController = TextEditingController();
  final _wantsController = TextEditingController();

  // Validation errors
  String? _nameError;
  String? _photoError;
  String? _categoryError;
  String? _conditionError;
  String? _weightError;

  // Loading state
  bool _isSubmitting = false;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    if (initial != null) {
      _photoUrl = initial.photoUrl;
      _hasPhoto = initial.photoUrl.isNotEmpty;
      _nameController.text = initial.name;
      _category = initial.category;
      _condition = initial.condition;
      if (initial.weight != null) {
        _weightController.text = initial.weight!.toStringAsFixed(
          initial.weight! == initial.weight!.truncateToDouble() ? 0 : 1,
        );
      }
      _descController.text = initial.description ?? '';
      _wantsController.text = initial.wants ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _descController.dispose();
    _wantsController.dispose();
    super.dispose();
  }

  // ── Injected dependencies ─────────────────────────────────────────────────

  PhotoService get _photoService => widget.photoService ?? PhotoService();
  ItemService get _itemService => widget.itemService ?? ItemService();
  CurrentUidGetter get _getCurrentUid =>
      widget.getCurrentUid ?? _defaultCurrentUidGetter;

  // ── Derived state ─────────────────────────────────────────────────────────

  /// Returns typical-weight placeholder text for the selected category.
  String _weightPlaceholder() {
    if (_category == null) return 'approx. weight (optional)';
    final tw = typicalWeight[_category!.value] ?? 0.5;
    return '${tw.toStringAsFixed(1)} kg typical for ${_category!.label.toLowerCase()}';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handlePickPhoto() async {
    if (_isSubmitting) return;
    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() {
      _uploadProgress = 0;
      _photoError = null;
    });

    try {
      // Use a temporary path; after submit the item ID is known, but we
      // upload eagerly using a UUID-style temporary key. For MVP simplicity
      // we use the uid + timestamp as the storage key.
      final tempKey = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
      final url = await _photoService.pickAndUpload(
        storagePath: 'item_photos/$tempKey.jpg',
      );

      if (!mounted) return;

      if (url != null) {
        setState(() {
          _photoUrl = url;
          _hasPhoto = true;
          _uploadProgress = null;
        });
      } else {
        setState(() => _uploadProgress = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = null;
        _photoError = 'Photo upload failed. Please try again.';
      });
    }
  }

  void _handleOpenCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        value: _category,
        onPick: (cat) {
          setState(() {
            _category = cat;
            _categoryError = null;
          });
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate all required fields
    setState(() {
      _photoError = _hasPhoto ? null : 'A photo is required.';
      _nameError = _validateName(_nameController.text);
      _categoryError = _category == null ? 'Please select a category.' : null;
      _conditionError = _condition == null
          ? 'Please select a condition.'
          : null;
      _weightError = _validateWeight(_weightController.text);
    });

    if (_photoError != null ||
        _nameError != null ||
        _categoryError != null ||
        _conditionError != null ||
        _weightError != null) {
      return;
    }

    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final weightText = _weightController.text.trim();
      final weight = weightText.isEmpty ? null : double.tryParse(weightText);

      final descText = _descController.text.trim();
      final wantsText = _wantsController.text.trim();

      if (_isEditMode) {
        await _itemService.updateItem(
          widget.initialItem!.id,
          name: _nameController.text.trim(),
          category: _category!,
          condition: _condition!,
          photoUrl: _photoUrl,
          weight: weight,
          description: descText.isEmpty ? null : descText,
          wants: wantsText.isEmpty ? null : wantsText,
        );
      } else {
        await _itemService.createItem(
          ownerId: uid,
          name: _nameController.text.trim(),
          category: _category!,
          condition: _condition!,
          photoUrl: _photoUrl,
          weight: weight,
          description: descText.isEmpty ? null : descText,
          wants: wantsText.isEmpty ? null : wantsText,
        );
      }

      if (!mounted) return;

      widget.onSubmitSuccess?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text(
          'This will remove the item from your swaps. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('deleteCancelButton'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('deleteConfirmButton'),
            style: TextButton.styleFrom(foregroundColor: _kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await _itemService.softDeleteItem(widget.initialItem!.id);
      if (!mounted) return;
      widget.onDeleteSuccess?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Item name is required.';
    if (trimmed.length > 60) {
      return 'Item name must be 60 characters or fewer.';
    }
    return null;
  }

  String? _validateWeight(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null; // weight is optional
    final value = double.tryParse(trimmed);
    if (value == null || value <= 0) {
      return 'Please enter a valid weight (e.g. 0.5).';
    }
    return null;
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  InputDecoration _textFieldDecoration({String? hintText, String? errorText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 15, color: _kTextTertiary),
      filled: true,
      fillColor: _kSurfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      errorText: errorText,
      errorStyle: const TextStyle(color: _kDanger, fontSize: 12),
      constraints: const BoxConstraints(minHeight: 48),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      // Hierarchical top bar (back arrow + title)
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: const BackButton(color: _kTextPrimary),
        title: Text(
          _isEditMode ? 'Edit item' : 'Add an item',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Scrollable form content
            Expanded(
              child: SingleChildScrollView(
                key: const Key('formScrollView'),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1 — Photo (required)
                    _FieldLabel('Photo'),
                    _PhotoField(
                      hasPhoto: _hasPhoto,
                      uploadProgress: _uploadProgress,
                      onTap: _handlePickPhoto,
                      imageUrl: _photoUrl,
                      onRemove: () => setState(() {
                        _hasPhoto = false;
                        _photoUrl = '';
                      }),
                    ),
                    if (_photoError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _photoError!,
                        style: const TextStyle(color: _kDanger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 2 — Item name (required, 1–60 chars)
                    _FieldLabel('What is it?'),
                    TextFormField(
                      key: const Key('nameField'),
                      controller: _nameController,
                      maxLength: 60,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                      decoration: _textFieldDecoration(
                        hintText: 'e.g. Leather tote bag',
                        errorText: _nameError,
                      ).copyWith(counterText: ''),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                      ),
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3 — Category (required, 7-option bottom sheet)
                    _FieldLabel('Category'),
                    _CategoryRow(
                      value: _category,
                      onTap: _handleOpenCategoryPicker,
                    ),
                    if (_categoryError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _categoryError!,
                        style: const TextStyle(color: _kDanger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 4 — Condition (required, 4-option pill row)
                    _FieldLabel('Condition'),
                    _ConditionPills(
                      value: _condition,
                      onChanged: (cond) {
                        setState(() {
                          _condition = cond;
                          _conditionError = null;
                        });
                      },
                    ),
                    if (_conditionError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _conditionError!,
                        style: const TextStyle(color: _kDanger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 5 — Weight (optional decimal kg)
                    _FieldLabel('Weight'),
                    _WeightField(
                      value: _weightController.text.isEmpty
                          ? null
                          : _weightController.text,
                      placeholder: _weightPlaceholder(),
                      onChanged: (val) {
                        _weightController.text = val;
                        if (_weightError != null) {
                          setState(() => _weightError = null);
                        }
                      },
                    ),
                    if (_weightError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _weightError!,
                        style: const TextStyle(color: _kDanger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      "Used to estimate the CO₂ impact of your swap. We'll use a typical weight for the category if you skip this.",
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextTertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6 — Description (optional, max 280 chars)
                    _FieldLabel('Description (optional)'),
                    TextFormField(
                      key: const Key('descriptionField'),
                      controller: _descController,
                      maxLines: 4,
                      maxLength: 280,
                      inputFormatters: [LengthLimitingTextInputFormatter(280)],
                      decoration:
                          _textFieldDecoration(
                            hintText:
                                "Anything worth mentioning — brand, size, why you're letting it go…",
                          ).copyWith(
                            counterStyle: const TextStyle(
                              fontSize: 11,
                              color: _kTextTertiary,
                            ),
                            alignLabelWithHint: true,
                          ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextPrimary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 7 — Wants (optional, max 140 chars)
                    _FieldLabel('What would you like in return?'),
                    TextFormField(
                      key: const Key('wantsField'),
                      controller: _wantsController,
                      maxLines: 3,
                      maxLength: 140,
                      inputFormatters: [LengthLimitingTextInputFormatter(140)],
                      decoration:
                          _textFieldDecoration(
                            hintText:
                                'e.g. books, kitchenware, or something useful for a dorm',
                          ).copyWith(
                            counterStyle: const TextStyle(
                              fontSize: 11,
                              color: _kTextTertiary,
                            ),
                            alignLabelWithHint: true,
                          ),
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

            // Sticky bottom — submit (+ optional delete in edit mode)
            Container(
              decoration: const BoxDecoration(
                color: _kSurface,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('submitButton'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGreenPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _kGreenPrimary.withValues(
                            alpha: 0.4,
                          ),
                          disabledForegroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditMode
                                    ? 'Save changes'
                                    : 'Add to my swaps',
                              ),
                      ),
                    ),
                    if (_isEditMode) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('deleteButton'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDangerSoft,
                            foregroundColor: _kDanger,
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _handleDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete item'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
