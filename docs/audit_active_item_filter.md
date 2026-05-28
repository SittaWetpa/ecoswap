# WBS 10.7 — Active-Item Filter Audit

Audited every path in `lib/` that reads from the `items` Firestore collection
or renders a list of items. Confirms each either filters on `status == 'active'`
or is a documented exception with a written justification.

**Result: all paths compliant. No refactoring required.**

---

## Query paths audited

### 1. Discover feed — `lib/services/feed_service.dart` ✅ COMPLIANT

`FeedService._buildActiveItemChecker()` queries:

```dart
.collection('items')
.where('ownerId', isEqualTo: uid)
.where('status', isEqualTo: 'active')
.limit(1)
```

Explicit Firestore-level `status == 'active'` filter. Only users who have at
least one active item appear as candidates in the swipe deck.

---

### 2. Discover feed — `lib/services/item_service.dart → activeItemsForUser()` ✅ COMPLIANT

Used by `discover_tab.dart` (WBS 7.2) to load items for every candidate before
rendering swipe cards.

```dart
.collection('items')
.where('ownerId', isEqualTo: uid)
.where('status', isEqualTo: ItemStatus.active.value)
```

Firestore-level filter. The in-memory override path (test seam) applies a
client-side `.where((i) => i.status == ItemStatus.active)` guard on top,
so injected lists are also filtered.

---

### 3. User Detail item grid — `lib/screens/discover/user_detail_screen.dart` ✅ COMPLIANT (filtered at caller)

`UserDetailScreen` receives `List<Item> items` as a constructor parameter and
renders whatever it is given. It does not query Firestore directly.

Caller: `discover_tab.dart` populates this list via
`itemService.activeItemsForUser(u.uid)` (see path 2 above), so only active
items reach the screen.

---

### 4. Item Picker modal — `lib/widgets/item_picker_modal.dart` ✅ COMPLIANT (filtered at caller)

`ItemPickerModal` receives `List<Item> items` as a constructor parameter. Its
doc comment states: *"Only active items should be passed; the modal renders
whatever list it receives."*

Caller: `discover_tab.dart` / swipe flow passes items from
`activeItemsForUser()`. No raw Firestore query inside the modal.

---

### 5. My Items screen — `lib/screens/items/my_items_screen.dart` ✅ JUSTIFIED EXCEPTION

Uses `ItemService.nonDeletedItemsForUser()`, which filters
`status != ItemStatus.deleted` (i.e., shows both `active` and `traded` items).

**Justification:** My Items intentionally shows traded items (rendered dimmed)
so the owner can see their full history. Showing only active items would hide
past swaps from the owner's own screen. This is the only screen where this
behaviour is correct.

---

### 6. Match list trade pill — `lib/screens/chats/match_list_screen.dart` ✅ JUSTIFIED EXCEPTION

`_resolveMatchRows()` fetches items by document ID:

```dart
db.collection('items').doc(myItemId).get()
db.collection('items').doc(theirItemId).get()
```

No `status` filter applied.

**Justification:** The match list displays the items that were part of a match
at the time it was created. By the time a match completes, the items will have
`status: 'traded'`. Filtering on `status == 'active'` would make traded items
disappear from completed match rows, breaking the historical display. The chat
is an intentional historical record.

---

### 7. Swap Confirmed screen — `lib/screens/qr/swap_confirmed_screen.dart` ✅ JUSTIFIED EXCEPTION

`loadSwapConfirmedData()` fetches items by document ID:

```dart
db.collection('items').doc(myItemId).get()
db.collection('items').doc(theirItemId).get()
```

No `status` filter applied.

**Justification:** The Swap Confirmed screen displays the two items involved in
the trade that just completed. At this point both items have `status: 'traded'`
(written atomically by `writeTradeAndImpact` in WBS 10.6). Filtering on
`status == 'active'` would return no document and break the screen. The doc IDs
come from the `/trades/` document, not from a collection scan, so no leaked
items are possible.

---

### 8. Impact Dashboard — `lib/screens/impact/impact_dashboard_screen.dart` ✅ JUSTIFIED EXCEPTION

Fetches items by document ID from trade history:

```dart
db.collection('items').doc(myItemId).get()
db.collection('items').doc(theirItemId).get()
```

No `status` filter applied.

**Justification:** The Impact Dashboard shows historical trade data. The items
referenced are already traded (`status: 'traded'`). Filtering by active would
return nothing. Same reasoning as path 7 — lookup by known ID from a
`/trades/` document, not a collection scan.

---

## Summary table

| Path | File | Firestore filter | Verdict |
|---|---|---|---|
| Feed candidate checker | `feed_service.dart` | `status == 'active'` (Firestore) | ✅ Compliant |
| Discover item loader | `item_service.dart → activeItemsForUser()` | `status == 'active'` (Firestore) | ✅ Compliant |
| User Detail grid | `user_detail_screen.dart` | Filtered at caller | ✅ Compliant |
| Item Picker modal | `item_picker_modal.dart` | Filtered at caller | ✅ Compliant |
| My Items screen | `my_items_screen.dart` | `status != 'deleted'` | ✅ Justified exception |
| Match list trade pill | `match_list_screen.dart` | Doc ID lookup (historical) | ✅ Justified exception |
| Swap Confirmed screen | `swap_confirmed_screen.dart` | Doc ID lookup (trade record) | ✅ Justified exception |
| Impact Dashboard | `impact_dashboard_screen.dart` | Doc ID lookup (trade record) | ✅ Justified exception |

---

## Audit method

```
grep -r "collection('items')" lib/
grep -r "activeItemsForUser\|nonDeletedItemsForUser\|items\.where" lib/
```

Grep run on `lib/` at commit `8bbe76b` (branch
`feat/wbs-10.6-UI-success-state-and-trade-record-write`).

All 8 paths accounted for. No unfiltered collection scans found that could leak
traded or deleted items into discovery or matching flows.
