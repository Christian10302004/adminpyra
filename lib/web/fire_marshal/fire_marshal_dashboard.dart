import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/web_helper.dart';
import '../../services/theme_provider.dart';
import 'fire_marshal_theme.dart';
import 'tabs/marshal_command_tab.dart';
import 'tabs/inspection_registry_tab.dart';
import 'tabs/issuance_center_tab.dart';

class FireMarshalDashboard extends StatefulWidget {
  const FireMarshalDashboard({super.key});

  @override
  State<FireMarshalDashboard> createState() => _FireMarshalDashboardState();
}

class _FireMarshalDashboardState extends State<FireMarshalDashboard> {
  int _selectedIndex = 0;

  static const _titles = <String>[
    'Marshal Command',
    'Full Inspection Registry',
    'Issuance Center',
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Tok.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            titles: _titles,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onLogout: _showLogoutDialog,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _titles[_selectedIndex]),
                Expanded(
                  child: IndexedStack(
                    key: ValueKey('marshal_stack_$isDark'),
                    index: _selectedIndex,
                    children: [
                      MarshalCommandTab(onTabRequested: (i) => setState(() => _selectedIndex = i)),
                      const InspectionRegistryTab(),
                      const IssuanceCenterTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final borderSide = BorderSide(color: Tok.border);
        return AlertDialog(
          backgroundColor: Tok.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rLg),
            side: borderSide,
          ),
          title: Text('Sign out?', style: TextStyle(color: Tok.textHi, fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text('You will be returned to the sign-in screen.', style: TextStyle(color: Tok.textMid, fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Tok.textMid))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Tok.brand, foregroundColor: Colors.white),
              onPressed: () async { await FirebaseAuth.instance.signOut(); reloadPage(); },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<String> titles;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({required this.selectedIndex, required this.titles, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(color: Tok.surface, border: Border(right: BorderSide(color: Tok.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    children: [
                      TextSpan(text: 'Pyra', style: TextStyle(color: Tok.ok)),
                      TextSpan(text: 'Check', style: TextStyle(color: Tok.brand)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('FIRE MARSHAL', style: Tok.label)),
          const SizedBox(height: 8),
          Divider(height: 1, color: Tok.borderSoft),
          _NavTile(icon: Icons.shield_outlined, title: titles[0], selected: selectedIndex == 0, onTap: () => onSelect(0)),
          _NavTile(icon: Icons.list_alt_rounded, title: titles[1], selected: selectedIndex == 1, onTap: () => onSelect(1)),
          _NavTile(icon: Icons.verified_user_outlined, title: titles[2], selected: selectedIndex == 2, onTap: () => onSelect(2)),
          const Spacer(),
          Divider(height: 1, color: Tok.borderSoft),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              return _NavTile(
                icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                title: isDark ? 'Light Mode' : 'Dark Mode',
                selected: false,
                onTap: () {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
          _NavTile(icon: Icons.logout_rounded, title: 'Sign out', selected: false, onTap: onLogout),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Tok.textHi : Tok.textMid;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: selected ? Tok.surfaceAlt : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: fg, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: Tok.bg, border: Border(bottom: BorderSide(color: Tok.border))),
      child: Row(
        children: [
          Text(title, style: Tok.h1),
          const Spacer(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              return Tooltip(
                message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                child: InkWell(
                  onTap: () {
                    themeProvider.toggleTheme();
                  },
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                      color: Tok.textMid,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 22, color: Tok.border),
          const SizedBox(width: 16),
          Icon(Icons.account_circle_outlined, color: Tok.textMid, size: 20),
          const SizedBox(width: 8),
          Text('Fire Marshal', style: TextStyle(color: Tok.textHi, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
