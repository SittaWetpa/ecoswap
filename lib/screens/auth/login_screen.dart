import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

// Design tokens matching EcoSwap Style Guide
const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kDanger = Color(0xFFC44545);
const _kInfo = Color(0xFF185FA5);

// ---------------------------------------------------------------------------
// EcoSwap wordmark — shown at top of auth screens
// ---------------------------------------------------------------------------
class _EcoSwapLogo extends StatelessWidget {
  const _EcoSwapLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _kGreenPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'EcoSwap',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kGreenPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  final AuthService? authService;

  const LoginScreen({super.key, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await (widget.authService ?? AuthService()).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Navigation is handled by the authStateChanges() stream in app.dart
    } on InvalidEmailException catch (e) {
      setState(() {
        _error = e.message;
      });
    } on WrongPasswordException catch (e) {
      setState(() {
        _error = e.message;
      });
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _kSurfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kGreenPrimary, width: 2),
      ),
      constraints: const BoxConstraints(minHeight: 44),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _kTextPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _kTextPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // EcoSwap logo
            const _EcoSwapLogo(),
            const SizedBox(height: 24),
            // Title
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle
            const Text(
              'Sign in to keep swapping.',
              style: TextStyle(fontSize: 14, color: _kTextSecondary),
            ),
            const SizedBox(height: 20),
            // Email field
            _buildLabel('Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: _fieldDecoration().copyWith(
                hintText: 'you@example.com',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFA0A09B),
                ),
              ),
              style: const TextStyle(fontSize: 15, color: _kTextPrimary),
            ),
            const SizedBox(height: 14),
            // Password field
            _buildLabel('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _fieldDecoration().copyWith(
                hintText: '••••••••',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFA0A09B),
                ),
              ),
              style: const TextStyle(fontSize: 15, color: _kTextPrimary),
            ),
            const SizedBox(height: 6),
            // Forgot password link (no-op — not in scope)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  // Not in scope for WBS 4.2
                },
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13, color: _kInfo),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Error message (visible only when _error != null)
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: _kDanger, fontSize: 13),
              ),
            const SizedBox(height: 20),
            // Sign in button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreenPrimary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onPressed: _isLoading ? null : _handleSignIn,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 24),
            // Bottom toggle — "New here? Create an account"
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'New here? ',
                        style: TextStyle(fontSize: 13, color: _kTextSecondary),
                      ),
                      TextSpan(
                        text: 'Create an account',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kGreenPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
