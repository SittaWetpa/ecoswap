import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../models/item.dart';
import '../../services/item_service.dart';
import '../items/upload_item_screen.dart' show CurrentUidGetter;

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// Default UID getter
// ---------------------------------------------------------------------------

String? _defaultCurrentUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// _ItemTile — private widget for a single item card
// ---------------------------------------------------------------------------

class _ItemTile extends StatelessWidget {
  final Item item;
  final void Function(Item item)? onEdit;

  const _ItemTile({required this.item, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isTraded = item.status == ItemStatus.traded;

    Widget tile = GestureDetector(
      onTap: () => onEdit?.call(item),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo area with optional "Traded" pill overlay
            Stack(
              children: [
                // Photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: item.photoUrl.isNotEmpty
                        ? Image.network(
                            item.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: _kSurfaceAlt),
                          )
                        : Container(color: _kSurfaceAlt),
                  ),
                ),
                // "Traded" pill overlay — top-right of photo
                if (isTraded)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreenSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Traded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _kGreenDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Item name
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Bottom row: condition pill + edit icon button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Condition pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE5E5E0)),
                  ),
                  child: Text(
                    item.condition.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
                // Edit icon button
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit, size: 14),
                    color: _kTextSecondary,
                    tooltip: 'Edit ${item.name}',
                    onPressed: () => onEdit?.call(item),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Dim traded items
    if (isTraded) {
      tile = Opacity(opacity: 0.5, child: tile);
    }

    return tile;
  }
}

// ---------------------------------------------------------------------------
// _EmptyState — shown when user has no items
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyState({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 40, color: _kTextTertiary),
            const SizedBox(height: 16),
            const Text(
              'Nothing to swap yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an item from your room — books, clothes, kitchen things — anything you don\'t use anymore.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreenPrimary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: onAdd,
              child: const Text('Add your first item'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MyItemsScreen — WBS 6.3
// ---------------------------------------------------------------------------

/// My Items screen — displays all non-deleted items owned by the current user.
///
/// Items are shown in a 2-column grid. Active and traded items are visually
/// distinguished (traded items are dimmed at 50% opacity with a "Traded" pill).
///
/// All dependencies are injectable for tests.
class MyItemsScreen extends StatelessWidget {
  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  /// Injectable [ItemService] — defaults to a production instance.
  final ItemService? itemService;

  /// Called when the FAB or "Add your first item" button is tapped.
  final VoidCallback? onAdd;

  /// Called when the user taps a tile or the edit icon button.
  final void Function(Item item)? onEdit;

  /// Optional stream override — used in tests to inject a fake stream
  /// without needing a real [ItemService] or Firestore.
  ///
  /// When provided, [itemService] and [getCurrentUid] are ignored for
  /// the data stream (but [getCurrentUid] is still consulted to show
  /// the not-signed-in fallback when this is null and uid is null).
  final Stream<List<Item>>? itemsStream;

  const MyItemsScreen({
    super.key,
    this.getCurrentUid,
    this.itemService,
    this.onAdd,
    this.onEdit,
    this.itemsStream,
  });

  ItemService get _itemService => itemService ?? ItemService();
  CurrentUidGetter get _getCurrentUid =>
      getCurrentUid ?? _defaultCurrentUidGetter;

  Stream<List<Item>> _resolveStream() {
    if (itemsStream != null) return itemsStream!;
    final uid = _getCurrentUid();
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return _itemService.nonDeletedItemsForUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _getCurrentUid();

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('My items'),
        centerTitle: false,
        backgroundColor: _kSurface,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(uid),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my-items-fab',
        backgroundColor: _kGreenPrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: onAdd,
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }

  Widget _buildBody(String? uid) {
    // Not signed in — show empty state as a simple fallback
    if (uid == null || uid.isEmpty) {
      return _EmptyState(onAdd: onAdd);
    }

    return StreamBuilder<List<Item>>(
      stream: _resolveStream(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Something went wrong. Please try again.',
              style: TextStyle(color: _kTextSecondary),
            ),
          );
        }

        // Filter out deleted items client-side for safety
        final allItems = snapshot.data ?? [];
        final items = allItems
            .where((item) => item.status != ItemStatus.deleted)
            .toList();

        // Empty state
        if (items.isEmpty) {
          return _EmptyState(onAdd: onAdd);
        }

        // Grid with items
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${items.length} items · all visible to nearby swappers',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _ItemTile(item: items[index], onEdit: onEdit),
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
