import 'package:cloud_firestore/cloud_firestore.dart';

/// Item categories as defined in WBS 3.6.
enum ItemCategory {
  clothing,
  books,
  kitchenware,
  household,
  electronics,
  furniture,
  other,
}

extension ItemCategoryLabel on ItemCategory {
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

  /// Typical weight in kg per WBS 11.1.
  double get typicalWeightKg {
    switch (this) {
      case ItemCategory.clothing:
        return 0.5;
      case ItemCategory.books:
        return 0.8;
      case ItemCategory.kitchenware:
        return 1.0;
      case ItemCategory.household:
        return 1.5;
      case ItemCategory.electronics:
        return 0.5;
      case ItemCategory.furniture:
        return 10.0;
      case ItemCategory.other:
        return 0.5;
    }
  }

  String get value {
    switch (this) {
      case ItemCategory.clothing:
        return 'clothing';
      case ItemCategory.books:
        return 'books';
      case ItemCategory.kitchenware:
        return 'kitchenware';
      case ItemCategory.household:
        return 'household';
      case ItemCategory.electronics:
        return 'electronics';
      case ItemCategory.furniture:
        return 'furniture';
      case ItemCategory.other:
        return 'other';
    }
  }
}

ItemCategory itemCategoryFromString(String value) {
  switch (value) {
    case 'clothing':
      return ItemCategory.clothing;
    case 'books':
      return ItemCategory.books;
    case 'kitchenware':
      return ItemCategory.kitchenware;
    case 'household':
      return ItemCategory.household;
    case 'electronics':
      return ItemCategory.electronics;
    case 'furniture':
      return ItemCategory.furniture;
    case 'other':
    default:
      return ItemCategory.other;
  }
}

/// Item conditions as defined in WBS 3.6.
enum ItemCondition { newItem, likeNew, good, used }

extension ItemConditionLabel on ItemCondition {
  String get label {
    switch (this) {
      case ItemCondition.newItem:
        return 'New';
      case ItemCondition.likeNew:
        return 'Like new';
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.used:
        return 'Used';
    }
  }

  String get value {
    switch (this) {
      case ItemCondition.newItem:
        return 'new';
      case ItemCondition.likeNew:
        return 'like-new';
      case ItemCondition.good:
        return 'good';
      case ItemCondition.used:
        return 'used';
    }
  }
}

ItemCondition itemConditionFromString(String value) {
  switch (value) {
    case 'new':
      return ItemCondition.newItem;
    case 'like-new':
      return ItemCondition.likeNew;
    case 'good':
      return ItemCondition.good;
    case 'used':
    default:
      return ItemCondition.used;
  }
}

/// Item document as defined in WBS 3.6 (`/items/{itemId}`).
class Item {
  final String id;
  final String ownerId;
  final String name;
  final ItemCategory category;
  final ItemCondition condition;

  /// Optional weight in kg. null means "use category typical at impact
  /// calculation time" — do NOT substitute the typical value here.
  final double? weight;
  final String? description;
  final String? wants;
  final String photoUrl;
  final String status; // 'active' | 'traded' | 'deleted'
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
    this.status = 'active',
    this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return Item(
      id: id,
      ownerId: (json['ownerId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      category: itemCategoryFromString((json['category'] as String?) ?? ''),
      condition: itemConditionFromString((json['condition'] as String?) ?? ''),
      weight: (json['weight'] as num?)?.toDouble(),
      description: json['description'] as String?,
      wants: json['wants'] as String?,
      photoUrl: (json['photoUrl'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
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
    'status': status,
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
    Object? weight = _sentinel,
    Object? description = _sentinel,
    Object? wants = _sentinel,
    String? photoUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      weight: weight == _sentinel ? this.weight : weight as double?,
      description: description == _sentinel
          ? this.description
          : description as String?,
      wants: wants == _sentinel ? this.wants : wants as String?,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Sentinel object used by copyWith to distinguish "not provided" from null.
const _sentinel = Object();
