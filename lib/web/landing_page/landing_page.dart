import 'package:flutter/material.dart';
import '../login/login_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5D0000), 
              Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Branding/Hero section
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 200),
                  const SizedBox(height: 24),
                  const Text(
                    'PYRA CHECK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const Text(
                    'ADVANCED FIRE SAFETY MANAGEMENT SYSTEM',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'PORTAL LOGIN',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Top Navigation Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 40),
                    const SizedBox(width: 12),
                    const Text('PyraCheck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
      ),
    );
  }
}
