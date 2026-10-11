import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/web_helper.dart';
import '../../services/theme_provider.dart';
import '../admin/inspection_management_view.dart';
import '../admin/reports_certificates_view.dart';
import 'clerk_theme.dart';
import 'tabs/clerk_overview_tab.dart';
import 'tabs/clerk_reports_tab.dart';

class ClerkDashboard extends StatefulWidget {
  const ClerkDashboard({super.key});

  @override
  State<ClerkDashboard> createState() => _ClerkDashboardState();
}

class _ClerkDashboardState extends State<ClerkDashboard> {
  int _selectedIndex = 0;

  static const _titles = <String>[
    'Clerk Terminal',
    'Inspection Tracking',
    'Certificate Issuance',
    'Data Reports',
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
                    key: ValueKey('clerk_stack_$isDark'),
                    index: _selectedIndex,
                    children: [
                      ClerkOverviewTab(
                        onTabRequested: (index) =>
                            setState(() => _selectedIndex = index),
                      ),
                      const InspectionManagementView(),
                      const ReportsCertificatesView(),
                      const ClerkReportsTab(),
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
      builder: (context) => AlertDialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rLg),
          side: BorderSide(color: Tok.border),
        ),
        title: Text('Sign out?',
            style: TextStyle(color: Tok.textHi, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('You will be returned to the sign-in screen.',
            style: TextStyle(color: Tok.textMid, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Tok.textMid, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              reloadPage();
            },
            child: const Text('Sign out',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<String> titles;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _Sidebar({
    required this.selectedIndex,
    required this.titles,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: Tok.surface,
        border: Border(right: BorderSide(color: Tok.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    children: [
                      TextSpan(text: 'Pyra', style: TextStyle(color: Tok.ok)),
                      TextSpan(text: 'Check', style: TextStyle(color: Tok.brand)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('CLERK / ENCODER', style: Tok.label),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Tok.borderSoft),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.dashboard_customize_outlined,
            title: titles[0],
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavTile(
            icon: Icons.edit_document,
            title: titles[1],
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _NavTile(
            icon: Icons.folder_shared_outlined,
            title: titles[2],
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavTile(
            icon: Icons.bar_chart_rounded,
            title: titles[3],
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
          ),
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
          _NavTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            selected: false,
            onTap: onLogout,
          ),
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
  const _NavTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Tok.textHi : Tok.textMid;
    return Material(
      color: selected ? Tok.surfaceAlt : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Tok.surfaceAlt.withValues(alpha: 0.5),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 6,
                bottom: 6,
                child: Container(width: 2, color: Tok.brand),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      decoration: BoxDecoration(
        color: Tok.bg,
        border: Border(bottom: BorderSide(color: Tok.border)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Tok.h1),
              const SizedBox(height: 1),
              Text('San Francisco, Agusan del Sur',
                  style: TextStyle(color: Tok.textLo, fontSize: 11)),
            ],
          ),
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
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Tok.surfaceAlt,
                  borderRadius: BorderRadius.circular(Tok.rSm),
                  border: Border.all(color: Tok.border),
                ),
                child: Text('C',
                    style: TextStyle(
                        color: Tok.textHi, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Clerk / Encoder',
                      style: TextStyle(
                          color: Tok.textHi, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('BFP Command', style: TextStyle(color: Tok.textLo, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}