import 'package:flutter/material.dart';
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
  
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _processAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // LOGIN LOGIC
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // REGISTRATION LOGIC (Matches Admin Dashboard Structure)
        if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
          throw 'Please fill in all fields';
        }

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Generate Data identical to Admin Dashboard
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
          'role': 'User',
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
      backgroundColor: Colors.black,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5D0000), Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset('assets/images/logo.png', height: 120),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Text(
                _isLogin ? 'Sign in to monitor your safety' : 'Join the PyraCheck network',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              if (!_isLogin) ...[
                _buildField(_nameController, 'Full Name', Icons.person_outline),
                const SizedBox(height: 16),
                _buildField(_phoneController, 'Phone Number', Icons.phone_outlined),
                const SizedBox(height: 16),
              ],
              
              _buildField(_emailController, 'Email Address', Icons.email_outlined),
              const SizedBox(height: 16),
              _buildField(_passwordController, 'Password', Icons.lock_outline, obscure: true),
              
              const SizedBox(height: 32),
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
                      : Text(
                          _isLogin ? 'LOGIN' : 'SIGN UP',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login",
                  style: const TextStyle(color: Color(0xFFFF5722)),
                ),
              ),
            ],
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
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: const Color(0xFF1B5E20)),
      ),
    );
  }
}
