import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// Typedef for the Firestore item-doc writer so tests can inject a simple
/// closure instead of trying to fake the sealed FirebaseFirestore hierarchy.
typedef ItemDocWriter = Future<String> Function(Map<String, dynamic> data);

/// Returns the default writer that adds to the real Firestore items collection.
ItemDocWriter _defaultWriter() {
  return (Map<String, dynamic> data) async {
    final ref = await FirebaseFirestore.instance.collection('items').add(data);
    return ref.id;
  };
}

/// Typedef for a Firestore stream of active items for a user.
typedef ActiveItemsStream = Stream<List<Item>> Function(String uid);

/// Service for item-related Firestore operations.
///
/// All Firestore interactions are injectable via constructor parameters
/// so tests can run without a real Firebase project.
class ItemService {
  final ItemDocWriter _writeItemDoc;
  final FirebaseFirestore? _firestore;

  ItemService({ItemDocWriter? itemDocWriter, FirebaseFirestore? firestore})
    : _writeItemDoc = itemDocWriter ?? _defaultWriter(),
      _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Creates a new item document in Firestore.
  ///
  /// Returns the Firestore document ID of the created item.
  ///
  /// [ownerId] — the UID of the current user
  /// [name] — item name (required, 1–60 chars)
  /// [category] — one of the 7 locked categories
  /// [condition] — one of the 4 locked conditions
  /// [photoUrl] — Cloud Storage download URL
  /// [weight] — optional kg (null = use category typical at impact calc time)
  /// [description] — optional, max 280 chars
  /// [wants] — optional, max 140 chars
  ///
  /// Always writes `status: 'active'` and `ownerId: currentUid`.
  Future<String> createItem({
    required String ownerId,
    required String name,
    required ItemCategory category,
    required ItemCondition condition,
    required String photoUrl,
    double? weight,
    String? description,
    String? wants,
  }) async {
    final data = <String, dynamic>{
      'ownerId': ownerId,
      'name': name.trim(),
      'category': category.value,
      'condition': condition.value,
      'weight': weight,
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'wants': wants?.trim().isEmpty == true ? null : wants?.trim(),
      'photoUrl': photoUrl,
      'status': ItemStatus.active.value,
      'createdAt': FieldValue.serverTimestamp(),
    };

    return _writeItemDoc(data);
  }

  /// Returns a stream of all active items for [uid], excluding traded and
  /// deleted items.
  ///
  /// Used by WBS 6.3 (My Items) and WBS 6.5 (Item Status Lifecycle).
  Stream<List<Item>> activeItemsForUser(String uid) {
    return _db
        .collection('items')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: ItemStatus.active.value)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Item.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Returns a stream of all non-deleted items for [uid] (active + traded).
  ///
  /// Used by WBS 6.3 My Items screen — shows active and traded, hides deleted.
  Stream<List<Item>> nonDeletedItemsForUser(String uid) {
    return _db
        .collection('items')
        .where('ownerId', isEqualTo: uid)
        .where('status', isNotEqualTo: ItemStatus.deleted.value)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Item.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }
}
