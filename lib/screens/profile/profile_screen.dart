import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as auth_prov;

// Design tokens
const _kDangerSoft = Color(0xFFFCEBEB);
const _kDanger = Color(0xFFC44545);

/// Top-level Profile screen.
///
/// WBS 4.3 owns the logout button and confirmation dialog only.
/// The full profile UI is implemented in WBS 5.4.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    // Capture the provider before the async gap so we don't call
    // context.read inside an async callback (which can fail if the
    // widget is unmounted by the time the dialog resolves).
    final authProvider = context.read<auth_prov.AuthProvider>();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You\'ll need to sign in again to continue swapping.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog first
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
    return Scaffold(
      // Title-only top bar — no back arrow (top-level screen), no cog, no info
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Placeholder body — full UI implemented in WBS 5.4
            const Expanded(child: Center(child: Text('Profile — coming soon'))),

            // Log out destructive button (full-width, 48px, radius 8px)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => _showLogoutDialog(context),
                  style: TextButton.styleFrom(
                    backgroundColor: _kDangerSoft,
                    foregroundColor: _kDanger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
