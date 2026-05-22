import 'package:cloud_firestore/cloud_firestore.dart';

/// The 7 item categories locked by WBS 3.6.
/// Do not add or rename. `kitchenware` is `kitchenware`, not `kitchen`.
enum ItemCategory {
  clothing,
  books,
  kitchenware,
  household,
  electronics,
  furniture,
  other;

  /// Firestore string value.
  String get value => name;

  static ItemCategory fromString(String s) {
    return ItemCategory.values.firstWhere(
      (c) => c.value == s,
      orElse: () => ItemCategory.other,
    );
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case ItemCategory.clothing:
        return 'Clothing';
      case ItemCategory.books:
        return 'Books';
      case ItemCategory.kitchenware:
        return 'Kitchenware';
      case ItemCategory.household:
        return 'Household';
      case ItemCategory.electronics:
        return 'Electronics';
      case ItemCategory.furniture:
        return 'Furniture';
      case ItemCategory.other:
        return 'Other';
    }
  }

  /// Short hint text shown in the category picker.
  String get hint {
    switch (this) {
      case ItemCategory.clothing:
        return 'Jackets, bags, accessories…';
      case ItemCategory.books:
        return 'Textbooks, novels, magazines';
      case ItemCategory.kitchenware:
        return 'Mugs, cookware, gadgets';
      case ItemCategory.household:
        return 'Lamps, plants, décor';
      case ItemCategory.electronics:
        return 'Small gadgets, cables, parts';
      case ItemCategory.furniture:
        return 'Chairs, desks, shelves';
      case ItemCategory.other:
        return "Anything that doesn't fit above";
    }
  }
}

/// The 4 item conditions locked by WBS 3.6.
enum ItemCondition {
  newCondition,
  likeNew,
  good,
  used;

  /// Firestore string value.
  String get value {
    switch (this) {
      case ItemCondition.newCondition:
        return 'new';
      case ItemCondition.likeNew:
        return 'like-new';
      case ItemCondition.good:
        return 'good';
      case ItemCondition.used:
        return 'used';
    }
  }

  static ItemCondition fromString(String s) {
    switch (s) {
      case 'new':
        return ItemCondition.newCondition;
      case 'like-new':
        return ItemCondition.likeNew;
      case 'good':
        return ItemCondition.good;
      case 'used':
        return ItemCondition.used;
      default:
        return ItemCondition.used;
    }
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case ItemCondition.newCondition:
        return 'New';
      case ItemCondition.likeNew:
        return 'Like new';
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.used:
        return 'Used';
    }
  }
}

/// The 3 item status values locked by WBS 3.6 and 6.5.
enum ItemStatus {
  active,
  traded,
  deleted;

  String get value => name;

  static ItemStatus fromString(String s) {
    return ItemStatus.values.firstWhere(
      (v) => v.value == s,
      orElse: () => ItemStatus.active,
    );
  }
}

/// Item document as defined in WBS 3.6 (`/items/{itemId}`).
/// No trust score, no GPS, no age.
class Item {
  final String id;
  final String ownerId;
  final String name;
  final ItemCategory category;
  final ItemCondition condition;

  /// Null means "use category typical weight at impact calculation time".
  /// Per WBS 6.2: weight left blank stores null, NOT the typical weight.
  final double? weight;

  final String? description;
  final String? wants;
  final String photoUrl;
  final ItemStatus status;
  final DateTime? createdAt;

  const Item({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.condition,
    this.weight,
    this.description,
    this.wants,
    required this.photoUrl,
    this.status = ItemStatus.active,
    this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return Item(
      id: id,
      ownerId: (json['ownerId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      category: ItemCategory.fromString((json['category'] as String?) ?? ''),
      condition: ItemCondition.fromString((json['condition'] as String?) ?? ''),
      weight: (json['weight'] as num?)?.toDouble(),
      description: json['description'] as String?,
      wants: json['wants'] as String?,
      photoUrl: (json['photoUrl'] as String?) ?? '',
      status: ItemStatus.fromString((json['status'] as String?) ?? 'active'),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'name': name,
    'category': category.value,
    'condition': condition.value,
    'weight': weight,
    'description': description,
    'wants': wants,
    'photoUrl': photoUrl,
    'status': status.value,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  Item copyWith({
    String? id,
    String? ownerId,
    String? name,
    ItemCategory? category,
    ItemCondition? condition,
    double? weight,
    String? description,
    String? wants,
    String? photoUrl,
    ItemStatus? status,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      weight: weight ?? this.weight,
      description: description ?? this.description,
      wants: wants ?? this.wants,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
