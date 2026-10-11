import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

class AndroidLoginPage extends StatefulWidget {
  const AndroidLoginPage({super.key});

  @override
  State<AndroidLoginPage> createState() => _AndroidLoginPageState();
}

class _AndroidLoginPageState extends State<AndroidLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Anti-brute force tracking
  int _loginAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth (behavior unchanged — same Firebase calls, same Firestore shape)
  // ---------------------------------------------------------------------------
  Future<void> _processAuth() async {
    if (_formKey.currentState?.validate() != true) return;

    // Check for lockout
    if (_isLogin && _lockoutUntil != null) {
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        final remaining = _lockoutUntil!.difference(DateTime.now());
        setState(() => _errorMessage =
            'Too many failed attempts. Please wait ${remaining.inSeconds} seconds.');
        return;
      } else {
        // Lockout expired, reset counters
        _lockoutUntil = null;
        _loginAttempts = 0;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Reset on success
        _loginAttempts = 0;
        _lockoutUntil = null;
      } else {
        final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // ... (rest of registration logic remains same)

        final accountId = 'PYRA-${10000 + Random().nextInt(90000)}';
        final bytes = utf8.encode(_passwordController.text.trim());
        final hashedPassword = sha256.convert(bytes).toString();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'account_id': accountId,
          'createdAt': FieldValue.serverTimestamp(),
          'email': _emailController.text.trim(),
          'full_name': _nameController.text.trim(),
          'lastSeen': FieldValue.serverTimestamp(),
          'password': hashedPassword,
          'phone': _phoneController.text.trim(),
          'role': 'User',
          'status': 'active',
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      if (_isLogin && (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential')) {
        _loginAttempts++;
        if (_loginAttempts >= 3) {
          _lockoutUntil = DateTime.now().add(const Duration(minutes: 1));
          _errorMessage = 'Account temporarily locked for 1 minute due to 3 failed attempts.';
        } else {
          _errorMessage = 'Incorrect email or password. Attempt $_loginAttempts of 3.';
        }
      } else {
        setState(() => _errorMessage = _humanizeAuthError(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _humanizeAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // resizeToAvoidBottomInset keeps the form usable when the keyboard opens.
      resizeToAvoidBottomInset: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5D0000), Colors.black],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  32,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom * 0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),

                          // Hero — logo, headline, subtitle
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 96,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isLogin ? 'Welcome!' : 'Create Account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? 'Sign in to monitor your safety records.'
                                : 'Join PyraCheck.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Error banner (inline, above the fields)
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          // Fields
                          if (!_isLogin) ...[
                            _FieldLabel('Full Name', required: true),
                            const SizedBox(height: 6),
                            _MobileTextField(
                              controller: _nameController,
                              hint: 'Juan Dela Cruz',
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your full name.'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            _FieldLabel('Phone number', required: true),
                            const SizedBox(height: 6),
                            _MobileTextField(
                              controller: _phoneController,
                              hint: 'ex.09123456789',
                              keyboardType: TextInputType.phone,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your phone Number.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          _FieldLabel('Email Address', required: true),
                          const SizedBox(height: 6),
                          _MobileTextField(
                            controller: _emailController,
                            hint: 'name@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Enter your email address.';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              _FieldLabel('Password', required: true),
                              const Spacer(),
                              if (_isLogin)
                                TextButton(
                                  onPressed: _isLoading ? null : _sendPasswordReset,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    minimumSize: const Size(0, 20),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: Colors.white60,
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _MobileTextField(
                            controller: _passwordController,
                            hint: _isLogin ? 'Your password' : 'At least 6 characters',
                            obscure: _obscurePassword,
                            autofillHints: _isLogin
                                ? const [AutofillHints.password]
                                : const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _isLoading ? null : _processAuth(),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Enter your password.';
                              if (t.length < 6) return 'Password must be at least 6 characters.';
                              return null;
                            },
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 18,
                              ),
                              splashRadius: 18,
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Primary action (theme color preserved: 0xFF1B5E20)
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _processAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFF1B5E20).withValues(alpha: 0.55),
                                disabledForegroundColor: Colors.white70,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(_isLogin ? 'Sign In' : 'Create Account'),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Mode toggle (theme color preserved: 0xFFFF5722)
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF5722),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: Text(
                              _isLogin
                                  ? "Don't have an account? Sign Up"
                                  : "Already have an account? Sign In",
                            ),
                          ),

                          const Spacer(),

                          // Bottom institutional line
                          const SizedBox(height: 16),
                          const Text(
                            'BFP · San Francisco, Agusan del Sur',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    final bool? send = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161719),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2B2F)),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and we will send you a password reset link.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle:
                      const TextStyle(color: Colors.white60, fontSize: 13),
                  hintText: 'name@example.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Colors.white54, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF0E0F10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2A2B2F)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2A2B2F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF4C8DFF)),
                  ),
                ),
                validator: (v) {
                  final e = (v ?? '').trim();
                  if (e.isEmpty) return 'Enter your email address.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogCtx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (send != true) return;

    final targetEmail = resetEmailController.text.trim();
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Password reset link sent to $targetEmail. Check your inbox or spam folder.'),
          backgroundColor: const Color(0xFF3FB950),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send reset link: $e'),
          backgroundColor: const Color(0xFFF85149),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// MOBILE FORM PRIMITIVES
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.3,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFFF5722))),
        ],
      ),
    );
  }
}

class _MobileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _MobileTextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 11,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}