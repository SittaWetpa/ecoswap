import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart' as auth_prov;
import 'screens/auth/login_screen.dart';
import 'screens/profile_setup/setup_flow.dart';
import 'screens/shell/main_shell.dart';

// Design token
const _kGreenPrimary = Color(0xFF1D9E75);

class EcoSwapApp extends StatelessWidget {
  /// Injectable auth state stream.
  ///
  /// - Production: leave null — the app reads from [authProvider].
  /// - Tests that only need route-guard coverage: inject a stream here
  ///   AND inject an [authProvider] built with the same fake FirebaseAuth.
  ///   The legacy tests that only supply [authStateStream] still work
  ///   because we fall through to the stream when it is non-null.
  final Stream<User?>? authStateStream;

  /// Injectable [auth_prov.AuthProvider].
  ///
  /// - Production: leave null — app creates one backed by
  ///   [FirebaseAuth.instance].
  /// - Tests: supply a provider built with a fake [FirebaseAuth] so the
  ///   real Firebase SDK is never touched.
  final auth_prov.AuthProvider? authProvider;

  /// Optional widget shown when the user is authenticated.
  ///
  /// - Production: leave null — the app shows [MainShell].
  /// - Tests that only need route-guard coverage: inject a lightweight
  ///   stub widget so Firebase-dependent screens inside [MainShell] are
  ///   never constructed.
  final Widget? authenticatedHome;

  const EcoSwapApp({
    super.key,
    this.authStateStream,
    this.authProvider,
    this.authenticatedHome,
  });

  @override
  Widget build(BuildContext context) {
    // Named routes shared by both app paths.
    final routes = <String, WidgetBuilder>{
      '/profile-setup': (_) => const SetupFlowScreen(),
    };

    // When a raw stream is injected (legacy test path), skip the real
    // AuthProvider so the Firebase SDK is never touched in tests.
    if (authStateStream != null) {
      final app = MaterialApp(
        title: 'EcoSwap',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _kGreenPrimary),
          fontFamily: 'Inter',
        ),
        routes: routes,
        home: StreamBuilder<User?>(
          stream: authStateStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return authenticatedHome ?? const MainShell();
            }
            return const LoginScreen();
          },
        ),
      );
      // Wrap with AuthProvider when one is injected so ProfileScreen can read it.
      if (authProvider != null) {
        return ChangeNotifierProvider<auth_prov.AuthProvider>.value(
          value: authProvider!,
          child: app,
        );
      }
      return app;
    }

    // Production path — use the real (or injected) AuthProvider.
    final provider = authProvider ?? auth_prov.AuthProvider();

    return ChangeNotifierProvider<auth_prov.AuthProvider>.value(
      value: provider,
      child: MaterialApp(
        title: 'EcoSwap',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _kGreenPrimary),
          fontFamily: 'Inter',
        ),
        routes: routes,
        home: StreamBuilder<User?>(
          stream: provider.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              // Logged-in: show the main shell (bottom nav + all top-level tabs)
              return const MainShell();
            }
            // Not logged in: show login screen (entry point to auth flow)
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
