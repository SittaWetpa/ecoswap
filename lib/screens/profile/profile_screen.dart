import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart' as auth_prov;
import '../../services/impact_service.dart';
import '../../widgets/impact_stat_strip.dart';
import 'edit_profile_screen.dart';

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
const _kDanger = Color(0xFFC44545);

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Streams the raw JSON map for a user document.
///
/// Returns `null` when the document doesn't exist yet.  Using a plain
/// [Map] avoids exposing the sealed [DocumentSnapshot] type in tests.
typedef UserDocReader = Stream<Map<String, dynamic>?> Function(String uid);

Stream<Map<String, dynamic>?> _defaultUserDocReader(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? snap.data() : null);
}

// ---------------------------------------------------------------------------
// ProfileScreen
// ---------------------------------------------------------------------------

/// Top-level Profile screen — view mode.
///
/// WBS 5.4: Shows user photo, display name, district pill, impact summary
/// (swaps / CO₂ / waste), My Items shortcut, bio, Edit Profile button,
/// and Logout button.
///
/// Top bar is title-only (no cog, no info icon) per the locked decision in
/// CLAUDE.md.
///
/// [userDocReader] and [getCurrentUid] are injectable for tests.
class ProfileScreen extends StatelessWidget {
  /// Injectable Firestore reader — defaults to real Firestore.
  ///
  /// Accepts a [uid] and returns a stream of the raw user-document JSON map,
  /// or `null` when the document doesn't exist. Using the plain [Map] type
  /// keeps this class free of the sealed [DocumentSnapshot] so tests can
  /// inject a simple [Stream.value] without any Firebase setup.
  final UserDocReader? userDocReader;

  /// Injectable UID getter — defaults to [AuthProvider.currentUser?.uid].
  final String? Function()? getCurrentUid;

  /// Called when the user taps "My items" row.
  final VoidCallback? onMyItems;

  /// Injectable [ImpactService] for the embedded [ImpactStatStrip] (WBS 11.4).
  ///
  /// When `null` (the production default), the strip uses the values
  /// already streamed from `/users/{uid}` as its seed and does NOT make
  /// an extra service call — the user-doc stream is the canonical
  /// source on this screen. Tests pass a fake to verify the strip's
  /// service-driven code path.
  final ImpactService? impactService;

  const ProfileScreen({
    super.key,
    this.userDocReader,
    this.getCurrentUid,
    this.onMyItems,
    this.impactService,
  });

  void _showLogoutDialog(
    BuildContext context,
    auth_prov.AuthProvider authProvider,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "You'll need to sign in again to continue swapping.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              // Route guard in app.dart handles redirect to LoginScreen
            },
            style: TextButton.styleFrom(foregroundColor: _kDanger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<auth_prov.AuthProvider>();
    final uid = getCurrentUid != null
        ? getCurrentUid!()
        : authProvider.currentUser?.uid;

    final reader = userDocReader ?? _defaultUserDocReader;

    return Scaffold(
      backgroundColor: _kSurface,
      // Title-only top bar — no cog, no info icon (locked decision)
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<Map<String, dynamic>?>(
              stream: reader(uid),
              builder: (context, snapshot) {
                app_user.User? user;
                if (snapshot.hasData && snapshot.data != null) {
                  user = app_user.User.fromJson(snapshot.data!, uid: uid);
                }

                return _ProfileBody(
                  user: user,
                  uid: uid,
                  impactService: impactService,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EditProfileScreen(
                          initialUser: user,
                          getCurrentUid: getCurrentUid,
                        ),
                      ),
                    );
                  },
                  onMyItems: onMyItems,
                  onLogout: () => _showLogoutDialog(context, authProvider),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProfileBody — the scrollable content of the profile screen
// ---------------------------------------------------------------------------

class _ProfileBody extends StatelessWidget {
  final app_user.User? user;
  final String uid;
  final VoidCallback onEdit;
  final VoidCallback? onMyItems;
  final VoidCallback onLogout;
  final ImpactService? impactService;

  const _ProfileBody({
    required this.user,
    required this.uid,
    required this.onEdit,
    required this.onMyItems,
    required this.onLogout,
    required this.impactService,
  });

  String _districtLabel(app_user.HomeDistrict d) {
    if (d.districtNameTh.isEmpty && d.districtNameEn.isEmpty) {
      return 'District not set';
    }
    // Format: "Thai · English, Province"  (WBS 5.4 requirement)
    return '${d.districtNameTh} · ${d.districtNameEn}, ${d.provinceNameEn}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? '';
    final bio = user?.bio ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final district = user?.homeDistrict;
    final tradesCount = user?.tradesCount ?? 0;
    final co2 = user?.totalCo2Saved ?? 0.0;
    final waste = user?.totalWasteDiverted ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top section: avatar + name + district ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                // Avatar 96px — initials fallback
                _Avatar(initial: initial, photoUrl: user?.photoUrl ?? ''),
                const SizedBox(height: 12),
                // Display name
                Text(
                  displayName.isEmpty ? 'Your name' : displayName,
                  key: const Key('profileDisplayName'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                if (district != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _districtLabel(district),
                    key: const Key('profileDistrict'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Impact summary strip (WBS 11.4) ───────────────────────────────
          //
          // The Profile screen already streams `/users/{uid}` for other
          // fields, so we seed the strip with the counter values from that
          // same snapshot to avoid a loading flash. The strip widget is
          // the canonical home of impact-strip formatting and styling —
          // see lib/widgets/impact_stat_strip.dart.
          ImpactStatStrip(
            impactService: impactService,
            initialImpact: UserImpact(
              trades: tradesCount,
              co2Kg: co2,
              wasteKg: waste,
            ),
          ),

          const SizedBox(height: 16),

          // ── My items shortcut ─────────────────────────────────────────────
          GestureDetector(
            key: const Key('myItemsRow'),
            onTap: onMyItems,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kSurfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      size: 20,
                      color: _kGreenPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My items',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                        Text(
                          'View and manage your listings',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _kTextSecondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── About / Bio section ───────────────────────────────────────────
          if (bio.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              key: const Key('profileBio'),
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Edit profile — secondary button (matches prototype)
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const Key('editProfileButton'),
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _kTextPrimary,
                  ),
                  label: const Text(
                    'Edit profile',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _kTextPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _kSurfaceAlt,
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Log out — ghost/text button
              SizedBox(
                height: 48,
                child: TextButton(
                  key: const Key('logoutButton'),
                  onPressed: onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: _kTextSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Log out', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Avatar — 96px circle with initials fallback
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String initial;
  final String photoUrl;

  const _Avatar({required this.initial, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: _kGreenSoft,
      );
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: _kGreenSoft,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}
