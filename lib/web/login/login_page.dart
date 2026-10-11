import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';
import '../../services/web_helper.dart';

// ---------------------------------------------------------------------------
// Design tokens — same set used everywhere else in the product.
// ---------------------------------------------------------------------------
class _Tok {
  static const bg          = Color(0xFF0E0F10);
  static const surface     = Color(0xFF161719);
  static const surfaceAlt  = Color(0xFF1D1E21);
  static const border      = Color(0xFF2A2B2F);
  static const borderSoft  = Color(0xFF212225);

  static const textHi      = Color(0xFFECECEC);
  static const textMid     = Color(0xFFA6A7AC);
  static const textLo      = Color(0xFF6E7075);

  static const brand       = Color(0xFFB3261E);
  static const ok          = Color(0xFF3FB950);
  static const warn        = Color(0xFFD29922);
  static const info        = Color(0xFF4C8DFF);
  static const danger      = Color(0xFFF85149);

  static const rSm = 4.0;
  static const rMd = 6.0;
  static const rLg = 8.0;

  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';
  static const h1     = TextStyle(fontFamily: stack, fontSize: 24, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.4, height: 1.2);
  static const h2     = TextStyle(fontFamily: stack, fontSize: 16, fontWeight: FontWeight.w600, color: textHi, letterSpacing: -0.2);
  static const body   = TextStyle(fontFamily: stack, fontSize: 13, color: textHi, height: 1.4);
  static const bodySm = TextStyle(fontFamily: stack, fontSize: 12, color: textMid, height: 1.35);
  static const label  = TextStyle(fontFamily: stack, fontSize: 11, fontWeight: FontWeight.w600, color: textMid, letterSpacing: 0.2);
  static const caption= TextStyle(fontFamily: stack, fontSize: 11, color: textLo, height: 1.4);

  // Display — used only for the brand-column hero headline.
  static const display = TextStyle(
    fontFamily: stack,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -1.0,
    height: 1.1,
  );
  static const lede = TextStyle(
    fontFamily: stack,
    fontSize: 14,
    color: textMid,
    height: 1.55,
  );
}

enum _AuthMode { signIn, createAccount }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isSignIn => true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------
  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (password.isEmpty) return 'Enter your password.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    if (!_isSignIn) {
      if (_nameController.text.trim().isEmpty) return 'Enter your full name.';
      if (_phoneController.text.trim().isEmpty) return 'Enter your phone number.';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Auth (behavior unchanged — same Firebase calls, same Firestore shape)
  // -------------------------------------------------------------------------
  Future<void> _processAuth() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignIn) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

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

      reloadPage();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _humanizeAuthError(e));
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

  Future<void> _sendPasswordReset() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    final bool? send = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Tok.rLg),
          side: const BorderSide(color: _Tok.border),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
              color: _Tok.textHi, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and we will send you a password reset link.',
              style: TextStyle(color: _Tok.textMid, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: _Tok.textHi, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle:
                      const TextStyle(color: _Tok.textMid, fontSize: 13),
                  hintText: 'name@example.com',
                  hintStyle: const TextStyle(color: _Tok.textLo),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: _Tok.textMid, size: 18),
                  filled: true,
                  fillColor: _Tok.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_Tok.rSm),
                    borderSide: const BorderSide(color: _Tok.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_Tok.rSm),
                    borderSide: const BorderSide(color: _Tok.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_Tok.rSm),
                    borderSide: const BorderSide(color: _Tok.info),
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
                const Text('Cancel', style: TextStyle(color: _Tok.textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogCtx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tok.brand,
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
          backgroundColor: _Tok.ok,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send reset link: $e'),
          backgroundColor: _Tok.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tok.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 1, child: _BrandColumn()),
                  Expanded(flex: 1, child: _FormColumn(
                    mode: _mode,
                    onModeChanged: (m) {},
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    emailController: _emailController,
                    passwordController: _passwordController,
                    nameController: _nameController,
                    phoneController: _phoneController,
                    onSubmit: _processAuth,
                    onForgotPassword: _sendPasswordReset,
                  )),
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  const _NarrowBrandHeader(),
                  _FormColumn(
                    mode: _mode,
                    onModeChanged: (m) {},
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    emailController: _emailController,
                    passwordController: _passwordController,
                    nameController: _nameController,
                    phoneController: _phoneController,
                    onSubmit: _processAuth,
                    onForgotPassword: _sendPasswordReset,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDE LAYOUT — left brand column
//
// The top-of-column lockup (PyraCheck wordmark, agency label, jurisdiction)
// has been removed. The logo, headline, and lede are now the entire brand
// block, and they are centered vertically and horizontally within the column.
// The footer row at the bottom stays, because the operational dot and the
// emergency number are functional signals, not brand decoration.
// ---------------------------------------------------------------------------
class _BrandColumn extends StatelessWidget {
  const _BrandColumn();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      decoration: const BoxDecoration(
        color: _Tok.surface,
        border: Border(right: BorderSide(color: _Tok.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The brand block sits in the vertical middle of the column.
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Image(
                      image: AssetImage('assets/images/logo.png'),
                      height: 180,
                    ),
                    SizedBox(height: 32),
                    Text(
                      'Fire safety inspection and certification portal.',
                      textAlign: TextAlign.center,
                      style: _Tok.display,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Track inspection requests, review submitted requirements, '
                          'and retrieve official Fire Safety Clearance certificates.',
                      textAlign: TextAlign.center,
                      style: _Tok.lede,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Operational footer stays — system status and emergency line are
          // the kind of information a public portal should always show.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: _Tok.ok,
                  shape: BoxShape.circle,
                ),
              ),
              const Text('Systems operational', style: _Tok.caption),
              const SizedBox(width: 20),
              const Text('For emergencies, dial 911', style: _Tok.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NARROW LAYOUT — condensed header above the form
//
// Same simplification: no wordmark, no agency label, no jurisdiction. Just
// the logo centered, then the headline, then the form below.
// ---------------------------------------------------------------------------
class _NarrowBrandHeader extends StatelessWidget {
  const _NarrowBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', height: 96),
          const SizedBox(height: 24),
          const Text(
            'Fire safety inspection and certification portal.',
            textAlign: TextAlign.center,
            style: _Tok.h2,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM COLUMN
// ---------------------------------------------------------------------------
class _FormColumn extends StatelessWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onModeChanged;
  final String? errorMessage;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onForgotPassword;

  const _FormColumn({
    required this.mode,
    required this.onModeChanged,
    required this.errorMessage,
    required this.isLoading,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.phoneController,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  bool get _isSignIn => mode == _AuthMode.signIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Tok.bg,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                style: _Tok.h2,
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in with the email and password issued to you.',
                style: _Tok.bodySm.copyWith(color: _Tok.textLo),
              ),
              const SizedBox(height: 24),

              // Error banner (inline, above the fields)
              if (errorMessage != null) ...[
                _ErrorBanner(message: errorMessage!),
                const SizedBox(height: 16),
              ],

              // Fields
              if (!_isSignIn) ...[
                const _FieldLabel('Full name', required: true),
                const SizedBox(height: 6),
                _TextField(
                  controller: nameController,
                  hint: 'Juan Dela Cruz',
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                ),
                const SizedBox(height: 14),

                const _FieldLabel('Phone number', required: true),
                const SizedBox(height: 6),
                _TextField(
                  controller: phoneController,
                  hint: '+63 900 000 0000',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
              ],

              const _FieldLabel('Email address', required: true),
              const SizedBox(height: 6),
              _TextField(
                controller: emailController,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                autofocus: _isSignIn,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  const _FieldLabel('Password', required: true),
                  const Spacer(),
                  if (_isSignIn)
                    TextButton(
                      onPressed: isLoading ? null : onForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        minimumSize: const Size(0, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: _Tok.textMid,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _TextField(
                controller: passwordController,
                hint: _isSignIn ? 'Your password' : 'At least 6 characters',
                obscure: obscurePassword,
                autofillHints: _isSignIn
                    ? const [AutofillHints.password]
                    : const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => isLoading ? null : onSubmit(),
                suffix: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _Tok.textLo,
                    size: 16,
                  ),
                  splashRadius: 16,
                  onPressed: onToggleObscure,
                ),
              ),

              const SizedBox(height: 24),

              // Primary action
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Tok.brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _Tok.brand.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_Tok.rMd),
                    ),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                      : Text('Sign in'),
                ),
              ),

              const SizedBox(height: 16),

              // Tiny footnote
              Text(
                'Having trouble signing in? Contact the BFP command center.',
                style: _Tok.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM PRIMITIVES
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: _Tok.label,
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: _Tok.brand)),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: _Tok.body,
      cursorColor: _Tok.textHi,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _Tok.body.copyWith(color: _Tok.textLo),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 36),
        filled: true,
        fillColor: _Tok.bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Tok.rMd),
          borderSide: const BorderSide(color: _Tok.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Tok.rMd),
          borderSide: const BorderSide(color: _Tok.info),
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
        color: _Tok.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_Tok.rMd),
        border: Border.all(color: _Tok.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: _Tok.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _Tok.bodySm.copyWith(color: _Tok.danger),
            ),
          ),
        ],
      ),
    );
  }
}