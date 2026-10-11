import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import '../../services/theme_provider.dart';
import '../../models/user_model.dart';
import 'inspector_theme.dart';
import 'tabs/assignments_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/settings_tab.dart';

class InspectorHome extends StatefulWidget {
  const InspectorHome({super.key});

  @override
  State<InspectorHome> createState() => _InspectorHomeState();
}

class _InspectorHomeState extends State<InspectorHome> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAndSync();
  }

  Future<void> _checkAndSync() async {
    await OfflineService.syncOfflineData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final authService = Provider.of<AuthService>(context);
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Tok.bg,
      appBar: AppBar(
        title: Text(_getTitle(), style: Tok.h1.copyWith(color: Tok.textHi)),
        backgroundColor: Tok.bg,
        foregroundColor: Tok.textHi,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: Tok.border)),
        actions: [
          FutureBuilder<int>(
            future: OfflineService.getQueueCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox();
              return IconButton(
                tooltip: 'Sync pending uploads',
                icon: Badge(
                  label: Text(count.toString()),
                  backgroundColor: Tok.info,
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 20,
                    color: Tok.info,
                  ),
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Syncing local audit data…'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  await OfflineService.syncOfflineData();
                  if (mounted) setState(() {});
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _InspectorDrawer(
        selectedIndex: _selectedIndex,
        user: user,
        authService: authService,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
      body: IndexedStack(
        key: ValueKey('inspector_stack_$isDark'),
        index: _selectedIndex,
        children: const [
          AssignmentsTab(),
          HistoryTab(),
          SettingsTab(),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Assignments';
      case 1:
        return 'Audit history';
      case 2:
        return 'Settings';
      default:
        return 'Inspector';
    }
  }
}

class _InspectorDrawer extends StatelessWidget {
  final int selectedIndex;
  final User? user;
  final AuthService authService;
  final ValueChanged<int> onSelect;

  const _InspectorDrawer({
    required this.selectedIndex,
    required this.user,
    required this.authService,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);

    return Drawer(
      backgroundColor: Tok.surface,
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<UserModel?>(
              future: authService.getUserData(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userModel = snapshot.data;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Tok.surfaceAlt,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: Tok.border),
                        ),
                        child: Icon(
                          Icons.engineering_outlined,
                          size: 20,
                          color: Tok.brandSoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userModel?.fullName ?? 'Inspector',
                              style: Tok.h3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: Tok.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(height: 1, color: Tok.borderSoft),
            const SizedBox(height: 8),

            _DrawerItem(
              icon: Icons.assignment_ind_outlined,
              label: 'My assignments',
              selected: selectedIndex == 0,
              onTap: () {
                onSelect(0);
                Navigator.pop(context);
              },
            ),
            _DrawerItem(
              icon: Icons.history_edu_outlined,
              label: 'Audit history',
              selected: selectedIndex == 1,
              onTap: () {
                onSelect(1);
                Navigator.pop(context);
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: selectedIndex == 2,
              onTap: () {
                onSelect(2);
                Navigator.pop(context);
              },
            ),

            const Spacer(),
            Divider(height: 1, color: Tok.borderSoft),

            // ---- THEME TOGGLE ----
            // Same behavior as the admin and clerk shells: flips the mode,
            // awaits the write to SharedPreferences, then reloads the page.
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                final isDark = themeProvider.isDarkMode;
                return _DrawerItem(
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark ? 'Light Mode' : 'Dark Mode',
                  selected: false,
                  onTap: () async {
                    await themeProvider.toggleTheme();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),

            Divider(height: 1, color: Tok.borderSoft),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _showSignOutDialog(context, authService);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          side: BorderSide(color: Tok.border),
        ),
        title: Text(
          'Sign out?',
          style: TextStyle(
            color: Tok.textHi,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your inspector account?',
          style: TextStyle(color: Tok.textMid, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: Tok.textMid),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tok.rSm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authService.signOut();
            },
            child: const Text(
              'Sign out',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? Tok.textHi
        : destructive
        ? Tok.danger
        : Tok.textMid;
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
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