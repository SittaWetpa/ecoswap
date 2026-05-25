import 'package:flutter/material.dart';
import 'step1_name_photo.dart';
import 'step2_district.dart';
import 'step3_bio.dart';

/// Coordinator that sequences the three profile-setup steps.
///
/// Step 0 → [Step1NamePhoto] (name + photo)
/// Step 1 → [Step2District] (home district)
/// Step 2 → [Step3Bio]      (short bio)
///
/// On completion pops back to the root route; the [StreamBuilder] in app.dart
/// will then show [ProfileScreen] because the user is now authenticated.
class SetupFlowScreen extends StatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  int _step = 0;

  void _goToStep(int step) => setState(() => _step = step);

  /// Finished all 3 steps — pop everything back to the root route so the
  /// auth stream's StreamBuilder takes over and shows ProfileScreen.
  void _done() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => Step1NamePhoto(
        onNext: () => _goToStep(1),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      1 => Step2District(
        onNext: () => _goToStep(2),
        onBack: () => _goToStep(0),
      ),
      2 => Step3Bio(onDone: _done, onBack: () => _goToStep(1)),
      _ => const SizedBox.shrink(),
    };
  }
}
