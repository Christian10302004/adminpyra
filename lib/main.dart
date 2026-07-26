import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'web/login/login_page.dart';
import 'web/admin/admin_dashboard.dart';
import 'web/clerk/clerk_dashboard.dart';
import 'web/landing_page/landing_page.dart';
import 'android/user/user_home.dart';
import 'android/login/android_login_page.dart';
import 'android/inspector/inspector_home.dart'; // Added Inspector Home
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PyraCheck Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1B5E20),
          secondary: Color(0xFFFF5722),
          surface: Color(0xFF1A1A1A),
          background: Color(0xFF000000),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          if (kIsWeb) {
            return const LandingPage(); 
          } else {
            return const AndroidLoginPage(); 
          }
        }

        return StreamBuilder<DocumentSnapshot>(
          key: ValueKey(user.uid),
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              final data = roleSnapshot.data!.data() as Map<String, dynamic>;
              final String rawRole = data['role']?.toString() ?? 'User';
              final String role = rawRole.toLowerCase();

              if (role == 'admin') {
                return const AdminDashboard();
              } else if (role == 'clerk/encoder') {
                return const ClerkDashboard();
              } else if (role == 'user') {
                return const UserHome();
              } else if (role == 'inspector') { // Added Inspector Routing
                return const InspectorHome();
              } else {
                return _buildRestrictedScreen(rawRole);
              }
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', height: 120),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRestrictedScreen(String role) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, color: Color(0xFFFF5722), size: 64),
            const SizedBox(height: 16),
            const Text('ACCESS RESTRICTED', 
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('Role "$role" is not authorized for this portal.', style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Return to Login', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
