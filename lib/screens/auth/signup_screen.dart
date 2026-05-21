import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

// Design tokens matching EcoSwap Style Guide
const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kDanger = Color(0xFFC44545);

class SignupScreen extends StatefulWidget {
  final AuthService? authService;

  const SignupScreen({super.key, this.authService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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

  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await (widget.authService ?? AuthService()).signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      }
    } on InvalidEmailException catch (e) {
      setState(() {
        _error = e.message;
      });
    } on WeakPasswordException catch (e) {
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
            // Title
            const Text(
              'Create your account',
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
              'Start swapping with people near you.',
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
            const SizedBox(height: 8),
            // Error message (visible only when _error != null)
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: _kDanger, fontSize: 13),
              ),
            const SizedBox(height: 20),
            // Create account button
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
                onPressed: _isLoading ? null : _handleSignUp,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 24),
            // Bottom toggle — "Already have an account? Sign in"
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(fontSize: 13, color: _kTextSecondary),
                      ),
                      TextSpan(
                        text: 'Sign in',
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
