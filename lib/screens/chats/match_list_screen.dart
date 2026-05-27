/// Match List Screen — WBS 9.1
///
/// Chats screen: lists all active and completed matches for the current user.
/// Query: matches.where('participants', arrayContains: uid)
///              .where('status', whereIn: ['active', 'completed'])
///
/// Cancelled matches are excluded by the Firestore query.
/// Empty state shown when the user has no matches.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../items/upload_item_screen.dart' show CurrentUidGetter;

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

// ---------------------------------------------------------------------------
// MatchRowData — all display-ready data for one row
// ---------------------------------------------------------------------------

/// Resolved display data for a single match row.
///
/// This is produced by the production Firestore stream or injected directly
/// in widget tests to avoid hitting Firebase.
class MatchRowData {
  final String matchId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  /// The item the current user is offering (what the other person wants).
  final String myItemName;

  /// The item the other user is offering (what the current user wants).
  final String theirItemName;

  final String lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const MatchRowData({
    required this.matchId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    required this.myItemName,
    required this.theirItemName,
    required this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });
}

// ---------------------------------------------------------------------------
// Default UID getter
// ---------------------------------------------------------------------------

String? _defaultUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// Timestamp formatter
// ---------------------------------------------------------------------------

String _formatTimestamp(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final msgDay = DateTime(time.year, time.month, time.day);

  if (msgDay == today) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (msgDay == yesterday) return 'Yesterday';

  final daysAgo = today.difference(msgDay).inDays;
  if (daysAgo < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[time.weekday - 1];
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[time.month - 1]} ${time.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// MatchListScreen — WBS 9.1
// ---------------------------------------------------------------------------

/// Chats screen — lists all active and completed matches for the current user.
///
/// All dependencies are injectable for widget tests.
class MatchListScreen extends StatelessWidget {
  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  /// Injectable stream — when provided, used directly instead of the Firestore
  /// query. Used in widget tests to inject fake data without hitting Firebase.
  final Stream<List<MatchRowData>>? matchesStream;

  /// Called when the user taps a row. Receives the matchId.
  ///
  /// When null (production), tapping pushes the '/chat' named route with the
  /// matchId as the route argument.
  final void Function(String matchId)? onChatTap;

  /// Called when the user taps "Go to Discover" on the empty state.
  ///
  /// In production the shell passes a callback that switches the bottom nav
  /// to the Discover tab (index 0). In tests it can be injected directly.
  final VoidCallback? onGoToDiscover;

  const MatchListScreen({
    super.key,
    this.getCurrentUid,
    this.matchesStream,
    this.onChatTap,
    this.onGoToDiscover,
  });

  CurrentUidGetter get _uidGetter => getCurrentUid ?? _defaultUidGetter;

  Stream<List<MatchRowData>> _resolveStream(String uid) {
    if (matchesStream != null) return matchesStream!;
    return _buildFirestoreStream(uid);
  }

  // Builds a live stream of resolved match rows from Firestore.
  // Firestore query already excludes cancelled matches.
  Stream<List<MatchRowData>> _buildFirestoreStream(String uid) {
    return FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: uid)
        .where('status', whereIn: ['active', 'completed'])
        .snapshots()
        .asyncMap((snapshot) => _resolveMatchRows(snapshot.docs, uid));
  }

  Future<List<MatchRowData>> _resolveMatchRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    return Future.wait(docs.map((doc) => _resolveOneRow(doc, uid)));
  }

  Future<MatchRowData> _resolveOneRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) async {
    final data = doc.data();
    final userAId = data['userAId'] as String? ?? '';
    final userBId = data['userBId'] as String? ?? '';
    final isUserA = userAId == uid;
    final otherUserId = isUserA ? userBId : userAId;

    // myItemId: the item this user is offering (what the other person wants).
    // theirItemId: the item the other person is offering (what this user wants).
    final myItemId = isUserA
        ? (data['userBWantsItemId'] as String? ?? '')
        : (data['userAWantsItemId'] as String? ?? '');
    final theirItemId = isUserA
        ? (data['userAWantsItemId'] as String? ?? '')
        : (data['userBWantsItemId'] as String? ?? '');

    final db = FirebaseFirestore.instance;

    // Fire all reads in parallel.
    final userSnapF = db.collection('users').doc(otherUserId).get();
    final myItemSnapF = db.collection('items').doc(myItemId).get();
    final theirItemSnapF = db.collection('items').doc(theirItemId).get();
    final messagesSnapF = db
        .collection('matches')
        .doc(doc.id)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();

    final userSnap = await userSnapF;
    final myItemSnap = await myItemSnapF;
    final theirItemSnap = await theirItemSnapF;
    final messagesSnap = await messagesSnapF;

    final userData = userSnap.data() ?? {};
    final myItemData = myItemSnap.data() ?? {};
    final theirItemData = theirItemSnap.data() ?? {};

    String lastMessage = '';
    DateTime? lastMessageTime;
    if (messagesSnap.docs.isNotEmpty) {
      final msgData = messagesSnap.docs.first.data();
      lastMessage = msgData['text'] as String? ?? '';
      final sentAt = msgData['sentAt'];
      if (sentAt is Timestamp) lastMessageTime = sentAt.toDate();
    }

    return MatchRowData(
      matchId: doc.id,
      otherUserName: userData['displayName'] as String? ?? '',
      otherUserPhotoUrl: userData['photoUrl'] as String? ?? '',
      myItemName: myItemData['name'] as String? ?? '',
      theirItemName: theirItemData['name'] as String? ?? '',
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: 0, // MVP: unread counting is handled in WBS 9.4
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uidGetter();

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: _kSurface,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: _buildBody(context, uid),
    );
  }

  Widget _buildBody(BuildContext context, String? uid) {
    if (uid == null || uid.isEmpty) {
      return _EmptyState(onGoToDiscover: onGoToDiscover);
    }

    return StreamBuilder<List<MatchRowData>>(
      stream: _resolveStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Something went wrong. Please try again.',
              style: TextStyle(color: _kTextSecondary),
            ),
          );
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return _EmptyState(onGoToDiscover: onGoToDiscover);
        }

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return _MatchRow(
              row: row,
              onTap: () {
                if (onChatTap != null) {
                  onChatTap!(row.matchId);
                } else {
                  Navigator.pushNamed(context, '/chat', arguments: row.matchId);
                }
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _MatchRow — single row in the Chats list
// ---------------------------------------------------------------------------

class _MatchRow extends StatelessWidget {
  final MatchRowData row;
  final VoidCallback? onTap;

  const _MatchRow({required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = row.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _AvatarCircle(
              name: row.otherUserName,
              photoUrl: row.otherUserPhotoUrl,
              size: 48,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + timestamp row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.otherUserName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(row.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: hasUnread ? _kGreenPrimary : _kTextTertiary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Trade pill
                  _TradePill(
                    myItemName: row.myItemName,
                    theirItemName: row.theirItemName,
                  ),
                  const SizedBox(height: 6),
                  // Last message + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: hasUnread ? _kTextPrimary : _kTextSecondary,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: row.unreadCount),
                      ],
                    ],
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
// _TradePill — "Your {X} ⇄ their {Y}" summary pill
// ---------------------------------------------------------------------------

class _TradePill extends StatelessWidget {
  final String myItemName;
  final String theirItemName;

  const _TradePill({required this.myItemName, required this.theirItemName});

  @override
  Widget build(BuildContext context) {
    final myFirst = myItemName.isNotEmpty ? myItemName.split(' ').first : '';
    final theirFirst = theirItemName.isNotEmpty
        ? theirItemName.split(' ').first
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kSurfaceAlt,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        'Your $myFirst ⇄ their $theirFirst',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _kTextSecondary,
          height: 1.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UnreadBadge — green count bubble
// ---------------------------------------------------------------------------

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _kGreenPrimary,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AvatarCircle — circular avatar with initials fallback
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;

  const _AvatarCircle({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: _kGreenSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyState — shown when user has no matches
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback? onGoToDiscover;

  const _EmptyState({this.onGoToDiscover});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.message_outlined, size: 40, color: _kTextTertiary),
            const SizedBox(height: 16),
            const Text(
              'No matches yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start swiping on the Discover tab to find people to swap with.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _kSurfaceAlt,
                foregroundColor: _kTextPrimary,
                side: const BorderSide(color: _kBorder),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: onGoToDiscover,
              child: const Text(
                'Go to Discover',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
