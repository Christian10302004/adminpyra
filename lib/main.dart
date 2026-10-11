import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'web/admin/admin_dashboard.dart';
import 'web/admin/admin_theme.dart' as admin_theme;
import 'web/clerk/clerk_dashboard.dart';
import 'web/clerk/clerk_theme.dart' as clerk_theme;
import 'web/fire_marshal/fire_marshal_dashboard.dart';
import 'web/fire_marshal/fire_marshal_theme.dart' as fire_marshal_theme;
import 'web/establishment/establishment_dashboard.dart';
import 'web/establishment/establishment_theme.dart' as establishment_theme;
import 'web/landing_page/landing_page.dart';
import 'android/user/user_home.dart';
import 'android/user/user_theme.dart';
import 'android/login/android_login_page.dart';
import 'android/inspector/inspector_home.dart';
import 'android/inspector/inspector_theme.dart' as inspector_theme;
import 'services/auth_service.dart';
import 'services/roboflow_service.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("App starting...");

  // Register every token class so ThemeProvider keeps them all in sync.
  ThemeProvider.registerThemeListener((isDark) {
    admin_theme.Tok.isDark = isDark;
  });
  ThemeProvider.registerThemeListener((isDark) {
    clerk_theme.Tok.isDark = isDark;
  });
  ThemeProvider.registerThemeListener((isDark) {
    fire_marshal_theme.Tok.isDark = isDark;
  });
  ThemeProvider.registerThemeListener((isDark) {
    establishment_theme.Tok.isDark = isDark;
  });
  ThemeProvider.registerThemeListener((isDark) {
    inspector_theme.Tok.isDark = isDark;
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully");
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  // Load the saved theme mode BEFORE constructing the provider, so the
  // very first frame renders in the correct theme.
  ThemeMode initialMode = ThemeMode.dark;
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(ThemeProvider.storageKey);
    debugPrint('THEME: loaded as "$stored"');
    if (stored == 'light') {
      initialMode = ThemeMode.light;
    } else if (stored == 'dark') {
      initialMode = ThemeMode.dark;
    }
  } catch (e) {
    debugPrint('THEME: load failed — $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<RoboflowService>(create: (_) => RoboflowService()),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(initialMode: initialMode),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'PyraCheck',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
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
        if (authSnapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Auth Error: ${authSnapshot.error}')),
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFB3261E)),
            ),
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
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text('Firestore Error: ${roleSnapshot.error}'),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              final data =
              roleSnapshot.data!.data() as Map<String, dynamic>;
              final String rawRole = data['role']?.toString() ?? 'User';
              final String role = rawRole.toLowerCase();

              if (role == 'admin') {
                return const AdminDashboard();
              } else if (role == 'fire marshal' ||
                  role == 'firemarshal' ||
                  role == 'firemarshall') {
                return const FireMarshalDashboard();
              } else if (role == 'clerk/encoder' ||
                  role == 'clerk' ||
                  role == 'encoder') {
                return const ClerkDashboard();
              } else if (role == 'establishment representative') {
                return const EstablishmentDashboard();
              } else if (role == 'user') {
                return const UserHome();
              } else if (role == 'inspector') {
                return const InspectorHome();
              } else {
                return _buildRestrictedScreen(rawRole);
              }
            }

            if (roleSnapshot.connectionState == ConnectionState.active &&
                roleSnapshot.data != null &&
                !roleSnapshot.data!.exists) {
              return _buildRestrictedScreen('No Role (User record missing)');
            }

            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),
                    CircularProgressIndicator(color: Color(0xFFB3261E)),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, color: Color(0xFFFF9800), size: 64),
            const SizedBox(height: 16),
            const Text(
              'ACCESS RESTRICTED',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text('Role "$role" is not authorized for this portal.'),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text(
                'Return to Login',
                style: TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}