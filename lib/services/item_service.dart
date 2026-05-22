import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// Typedef for the Firestore collection reference factory — injectable for
/// tests so no real Firebase project is required.
typedef CollectionRefFn =
    CollectionReference<Map<String, dynamic>> Function(String collectionPath);

CollectionReference<Map<String, dynamic>> _defaultCollectionRef(
  String collectionPath,
) => FirebaseFirestore.instance.collection(collectionPath);

/// Service for reading and writing `/items/{itemId}` documents.
///
/// All Firestore access is mediated through [_collectionRef] so that unit
/// tests can inject a fake without touching a real Firebase project.
class ItemService {
  final CollectionRefFn _collectionRef;

  ItemService({CollectionRefFn? collectionRef})
    : _collectionRef = collectionRef ?? _defaultCollectionRef;

  CollectionReference<Map<String, dynamic>> get _items =>
      _collectionRef('items');

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Writes a new item document to `/items/{itemId}`.
  ///
  /// [ownerId] is always set to the caller-supplied value; [status] is always
  /// forced to `'active'` regardless of what is in [item].
  Future<String> createItem(Item item) async {
    final docRef = _items.doc();
    final data = item.copyWith(id: docRef.id, status: 'active').toJson();
    await docRef.set(data);
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns a real-time stream of all non-deleted items owned by [uid].
  Stream<List<Item>> itemsForUser(String uid) {
    return _items
        .where('ownerId', isEqualTo: uid)
        .where('status', whereIn: ['active', 'traded'])
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Item.fromJson(d.data(), id: d.id)).toList(),
        );
  }

  /// Returns all items with `status: 'active'` owned by [uid].
  Future<List<Item>> activeItemsForUser(String uid) async {
    final snap = await _items
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map((d) => Item.fromJson(d.data(), id: d.id)).toList();
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Writes updated fields to an existing item document.
  Future<void> updateItem(Item item) async {
    final data = item.toJson();
    // Firestore serverTimestamp should not overwrite an existing createdAt.
    data.remove('createdAt');
    await _items.doc(item.id).update(data);
  }

  // ---------------------------------------------------------------------------
  // Soft delete
  // ---------------------------------------------------------------------------

  /// Soft-deletes an item by setting `status: 'deleted'`.
  ///
  /// Does NOT remove the document — historical references in `/matches/` and
  /// `/trades/` remain intact.
  Future<void> deleteItem(String itemId) async {
    await _items.doc(itemId).update({'status': 'deleted'});
  }
}
