import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

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

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _processAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // LOGIN
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // REGISTER (Default as 'User')
        if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
          throw 'Please fill in all fields';
        }

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Generate matching data structure
        String accountId = 'PYRA-${10000 + Random().nextInt(90000)}';
        var bytes = utf8.encode(_passwordController.text.trim());
        var hashedPassword = sha256.convert(bytes).toString();

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'account_id': accountId,
          'createdAt': FieldValue.serverTimestamp(),
          'email': _emailController.text.trim(),
          'full_name': _nameController.text.trim(),
          'lastSeen': FieldValue.serverTimestamp(),
          'password': hashedPassword,
          'phone': _phoneController.text.trim(),
          'role': 'User', // Default role for web registration
          'status': 'active',
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(e.message ?? 'Auth failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.orange, content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5D0000), Color(0xFF000000)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 140),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'TERMINAL LOGIN' : 'CREATE ACCOUNT',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin) ...[
                    _buildField(_nameController, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildField(_phoneController, 'Phone Number', Icons.phone_outlined),
                    const SizedBox(height: 16),
                  ],
                  _buildField(_emailController, 'Email Address', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildField(_passwordController, 'Password', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLogin ? 'AUTHORIZE' : 'REGISTER', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? "Need a property account? Register here" : "Already have an account? Login",
                      style: const TextStyle(color: Color(0xFFFF5722)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      ),
    );
  }
}
