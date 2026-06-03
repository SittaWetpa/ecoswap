import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'app.dart';
import 'firebase_options.dart';

/// reCAPTCHA v3 site key for Firebase App Check on the **web** build.
///
/// Create it in the Firebase console → App Check → Apps → (web app) →
/// reCAPTCHA v3, then pass it at build/run time:
///   flutter run -d chrome --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=xxxx
/// It is only used on web; Android/iOS use Play Integrity / App Attest and
/// ignore this value. The site key is not a secret (it ships in the web app).
const String _recaptchaV3SiteKey = String.fromEnvironment(
  'APP_CHECK_RECAPTCHA_SITE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  runApp(const EcoSwapApp());
}

/// Activates Firebase App Check so the backend can verify requests come from a
/// genuine, untampered build of this app — the main defence against bots
/// abusing the (publicly visible) Firebase config.
///
/// Providers per platform:
///   - Android: Play Integrity in release; the debug provider otherwise so
///     local runs and the emulator (which can't do Play Integrity) still work.
///   - Apple:   App Attest in release; the debug provider otherwise.
///   - Web:     reCAPTCHA v3 (needs [_recaptchaV3SiteKey]).
///
/// In debug/emulator builds the debug provider prints an App Check debug token
/// to the console on first run — register it in the Firebase console
/// (App Check → Apps → Manage debug tokens) so debug builds aren't blocked
/// once enforcement is turned on.
///
/// NOTE: activation alone does not block anything — App Check stays in
/// monitoring mode until you enable *enforcement* per product (Firestore,
/// Storage, Cloud Functions, Auth) in the console. Turn enforcement on only
/// after the dashboard shows traffic is overwhelmingly verified.
///
/// Wrapped in try/catch so a transient activation failure never blocks app
/// startup (a missing token degrades to unverified requests, not a crash).
Future<void> _activateAppCheck() async {
  // On web, App Check needs a reCAPTCHA v3 site key. Without one the reCAPTCHA
  // script throws "Missing required parameters: sitekey" asynchronously (after
  // activate() returns, so the try/catch below can't see it). Skip activation
  // entirely when no key was provided — App Check is a hardening layer, not a
  // startup requirement. Native platforms ignore the key, so this only gates
  // web.
  if (kIsWeb && _recaptchaV3SiteKey.isEmpty) {
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.appAttest
          : AppleProvider.debug,
      webProvider: ReCaptchaV3Provider(_recaptchaV3SiteKey),
    );
  } catch (_) {
    // Ignore — App Check is a hardening layer, not a startup dependency.
  }
}
