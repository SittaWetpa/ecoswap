import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EcoSwapApp());
}

class EcoSwapApp extends StatelessWidget {
  const EcoSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoSwap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D9E75)),
        fontFamily: 'Inter',
      ),
      initialRoute: '/signup',
      routes: {
        '/signup': (_) => const SignupScreen(),
        '/profile-setup': (_) => const Scaffold(
              body: Center(child: Text('Profile setup coming soon')),
            ),
      },
    );
  }
}
