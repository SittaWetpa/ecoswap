import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

// Design tokens
const _kDangerSoft = Color(0xFFFCEBEB);
const _kDanger = Color(0xFFC44545);

/// Top-level Profile screen.
///
/// WBS 4.3 owns the logout button and confirmation dialog only.
/// The full profile UI is implemented in WBS 5.4.
///
/// The [authService] parameter is optional so production usage can omit it
/// (defaults to a fresh [AuthService]) while tests inject a stub.
class ProfileScreen extends StatelessWidget {
  final AuthService? authService;

  const ProfileScreen({super.key, this.authService});

  void _showLogoutDialog(BuildContext context) {
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
              await (authService ?? AuthService()).signOut();
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
            const Expanded(
              child: Center(
                child: Text('Profile — coming soon'),
              ),
            ),

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
