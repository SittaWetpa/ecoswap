import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_screen.dart';

// Design token
const _kGreenPrimary = Color(0xFF1D9E75);

class EcoSwapApp extends StatelessWidget {
  final Stream<User?>? authStateStream; // injectable for tests

  const EcoSwapApp({super.key, this.authStateStream});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoSwap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _kGreenPrimary),
        fontFamily: 'Inter',
      ),
      home: StreamBuilder<User?>(
        stream: authStateStream ?? FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Logged-in: show Profile screen (Discover placeholder replaced by WBS 7.x)
            return const ProfileScreen();
          }
          // Not logged in: show login screen (entry point to auth flow)
          return const LoginScreen();
        },
      ),
    );
  }
}
