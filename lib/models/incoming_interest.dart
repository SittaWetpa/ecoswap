/// Incoming Interest — F18 (Anonymous Interest) view model.
///
/// Represents the state where another user has already swiped right on the
/// current user and declared which of the current user's items they want, but
/// no match exists yet (the current user hasn't swiped back).
///
/// Surfaced on the Discover deck as a green "Wants your X" badge on that
/// candidate's card (see `prototype/src/screens/discover.jsx` — the
/// `incomingInterest` branch of `SwipeCard`).
///
/// Per the glossary (WBS Dictionary): the badge names the desired item but the
/// candidate's identity is shown as normal on the card — matching the
/// prototype, which keeps the candidate's name/photo visible.
library;

/// One candidate's anonymous interest in one of the current user's items.
class IncomingInterest {
  /// The current user's item the candidate declared they want.
  final String itemId;

  /// Display name of that item — rendered as "Wants your {itemName}".
  final String itemName;

  const IncomingInterest({required this.itemId, required this.itemName});

  @override
  bool operator ==(Object other) =>
      other is IncomingInterest &&
      other.itemId == itemId &&
      other.itemName == itemName;

  @override
  int get hashCode => Object.hash(itemId, itemName);
}
