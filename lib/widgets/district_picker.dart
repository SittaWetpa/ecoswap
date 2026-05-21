import 'dart:async';

import 'package:flutter/material.dart';

import '../services/district_service.dart';

/// A bottom-sheet widget that lets the user search and select a Thai district.
///
/// Corresponds to the `AreaSearch` / `AreaSearching` / `AreaSelected` components
/// in `prototype/src/screens/setup.jsx` and the `DistrictRow` in editprofile.jsx.
///
/// Usage:
/// ```dart
/// final district = await showDistrictPicker(context, service: districtService);
/// if (district != null) { ... }
/// ```
class DistrictPickerSheet extends StatefulWidget {
  final DistrictService service;
  final DistrictEntry? initialValue;

  const DistrictPickerSheet({
    super.key,
    required this.service,
    this.initialValue,
  });

  @override
  State<DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<DistrictPickerSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<DistrictEntry> _results = [];
  bool _loading = true;
  Timer? _debounce;

  // Tracks the query that was most recently dispatched to _load, so that
  // spurious controller notifications (e.g. from autofocus) that carry the
  // same text do not schedule a redundant debounced search.
  String _lastDispatchedQuery = '';

  static const _debounceMs = 200;

  @override
  void initState() {
    super.initState();
    _load('');
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final text = _controller.text;
    // Skip if the text hasn't actually changed since the last dispatched load.
    if (text == _lastDispatchedQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      _load(text);
    });
  }

  Future<void> _load(String query) async {
    if (!mounted) return;
    _lastDispatchedQuery = query;
    setState(() => _loading = true);
    final results = await widget.service.searchByName(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _select(DistrictEntry entry) {
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    // Bottom sheet takes ~70 % of screen height (matches Style Guide §12).
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF), // --surface
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20), // --radius-xl
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          _DragHandle(),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Select district',
              style: const TextStyle(
                fontSize: 20, // h2
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A), // --text-primary
              ),
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchField(controller: _controller, focusNode: _focusNode),
          ),

          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1D9E75), // --green-primary
                      strokeWidth: 2,
                    ),
                  )
                : _results.isEmpty
                ? _EmptyState(query: _controller.text)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E5E0), // --border
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final entry = _results[index];
                      final isSelected =
                          widget.initialValue?.districtId == entry.districtId;
                      return _DistrictTile(
                        entry: entry,
                        isSelected: isSelected,
                        onTap: () => _select(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E0), // --border
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _SearchField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A1A), // --text-primary
      ),
      decoration: InputDecoration(
        hintText: 'Search your district...',
        hintStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFFA0A09B), // --text-tertiary
        ),
        prefixIcon: const Icon(
          Icons.location_on_outlined,
          size: 20,
          color: Color(0xFFA0A09B), // --text-tertiary
        ),
        filled: true,
        fillColor: const Color(0xFFF7F5F0), // --surface-alt
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // --radius-md
          borderSide: const BorderSide(
            color: Color(0xFFE5E5E0), // --border
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFFE5E5E0), // --border
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF1D9E75), // --green-primary
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _DistrictTile extends StatelessWidget {
  final DistrictEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _DistrictTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isSelected
            ? const Color(0xFFE1F5EE) // --green-soft
            : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: entry.districtNameTh,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A), // --text-primary
                      ),
                    ),
                    TextSpan(
                      text:
                          ' · ${entry.districtNameEn}, ${entry.provinceNameEn}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B6B66), // --text-secondary
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                size: 18,
                color: Color(0xFF1D9E75), // --green-primary
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 40,
              color: Color(0xFFA0A09B), // --text-tertiary
            ),
            const SizedBox(height: 12),
            Text(
              'No districts found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A), // --text-primary
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching in Thai or English',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B6B66), // --text-secondary
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience function to show the district picker as a modal bottom sheet.
///
/// Returns the selected [DistrictEntry] or null if the user dismissed without
/// selecting.
Future<DistrictEntry?> showDistrictPicker(
  BuildContext context, {
  required DistrictService service,
  DistrictEntry? initialValue,
}) {
  return showModalBottomSheet<DistrictEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        DistrictPickerSheet(service: service, initialValue: initialValue),
  );
}

/// Composite field for use in the profile-setup wizard (step 2).
///
/// Mirrors the `AreaSearch` component in `prototype/src/screens/setup.jsx`:
/// - When [value] is null: shows a tappable row that opens the district picker.
/// - When [value] is set: shows a confirmation card ([_AreaSelected]) with a
///   "Change" button and a "nearby districts" info note.
class DistrictAreaField extends StatelessWidget {
  final DistrictEntry? value;
  final DistrictService service;
  final ValueChanged<DistrictEntry?> onChanged;

  const DistrictAreaField({
    super.key,
    required this.value,
    required this.service,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (value != null) {
      return _AreaSelected(entry: value!, onClear: () => onChanged(null));
    }
    return DistrictRow(
      value: null,
      service: service,
      onChanged: (entry) => onChanged(entry),
    );
  }
}

/// Confirmation card shown after a district is picked in the setup wizard.
///
/// Corresponds to `AreaSelected` in `prototype/src/screens/setup.jsx:135-162`.
class _AreaSelected extends StatelessWidget {
  final DistrictEntry entry;
  final VoidCallback onClear;

  const _AreaSelected({required this.entry, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5F0), // --surface-alt
            border: Border.all(
              color: const Color(0xFFE5E5E0), // --border
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: Color(0xFF6B6B66), // --text-secondary
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: entry.districtNameTh,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A), // --text-primary
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${entry.districtNameEn}, ${entry.provinceNameEn}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B6B66), // --text-secondary
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                key: const Key('changeDistrictButton'),
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D9E75), // --green-primary
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: Color(0xFF6B6B66), // --text-secondary
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "We'll show you swappers in ${entry.districtNameEn} and nearby districts.",
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B6B66), // --text-secondary
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A tappable row that shows the currently selected district and opens the
/// picker when tapped.
///
/// Corresponds to `DistrictRow` in `prototype/src/screens/editprofile.jsx`.
/// Display format: "districtNameTh · districtNameEn, provinceNameEn"
class DistrictRow extends StatelessWidget {
  final DistrictEntry? value;
  final DistrictService service;
  final ValueChanged<DistrictEntry> onChanged;

  const DistrictRow({
    super.key,
    required this.value,
    required this.service,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDistrictPicker(
          context,
          service: service,
          initialValue: value,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F0), // --surface-alt
          border: Border.all(
            color: const Color(0xFFE5E5E0), // --border
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8), // --radius-md
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: Color(0xFF6B6B66), // --text-secondary
            ),
            const SizedBox(width: 10),
            Expanded(
              child: value != null
                  ? RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: value!.districtNameTh,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A), // --text-primary
                            ),
                          ),
                          TextSpan(
                            text:
                                ' · ${value!.districtNameEn}, ${value!.provinceNameEn}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF6B6B66), // --text-secondary
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Text(
                      'Select your district',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFA0A09B), // --text-tertiary
                      ),
                    ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B6B66), // --text-secondary
            ),
          ],
        ),
      ),
    );
  }
}
