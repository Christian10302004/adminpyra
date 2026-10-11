import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/web_helper.dart';
import '../../services/theme_provider.dart';
import 'admin_theme.dart';
import 'manage_users_view.dart';
import 'inspection_management_view.dart';
import 'reports_certificates_view.dart';
import 'views/overview_view.dart';
import 'views/barangay_management_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  static const _titles = <String>[
    'Dashboard',
    'Inspection Management',
    'User & Role Management',
    'Reports & Certificates',
    'Barangay Management',
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
                _TopBar(
                  title: _titles[_selectedIndex],
                  onOpenNotifications: (docs) =>
                      _showNotificationsPanel(context, docs),
                ),
                Expanded(
                  child: IndexedStack(
                    key: ValueKey('admin_stack_$isDark'),
                    index: _selectedIndex,
                    children: const [
                      OverviewView(),
                      InspectionManagementView(),
                      ManageUsersView(),
                      ReportsCertificatesView(),
                      BarangayManagementView(),
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
        title: Text(
          'Log out?',
          style: TextStyle(
              color: Tok.textHi, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You will be returned to the sign-in screen.',
          style: TextStyle(color: Tok.textMid, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Tok.textMid),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tok.rMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              reloadPage();
            },
            child: const Text(
              'Log out',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsPanel(
      BuildContext context, List<QueryDocumentSnapshot> docs) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final unread = docs.where((d) {
          final data = d.data() as Map;
          return [
            'pending_approval',
            'requirements_submitted'
          ].contains(data['status']) &&
              data['admin_read'] != true;
        }).length;

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 72, 32, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
              child: Material(
                color: Tok.surface,
                borderRadius: BorderRadius.circular(Tok.rLg),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Tok.border),
                    borderRadius: BorderRadius.circular(Tok.rLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                        child: Row(
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: Tok.textHi,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Tok.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(Tok.rSm),
                                  border: Border.all(
                                      color: Tok.brand.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '$unread new',
                                  style: TextStyle(
                                    color: Tok.brand,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: Tok.textMid),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Tok.borderSoft),
                      Expanded(
                        child: docs.isEmpty
                            ? const EmptyState(
                          icon: Icons.inbox_rounded,
                          label: 'No recent activity',
                        )
                            : ListView.separated(
                          padding:
                          const EdgeInsets.symmetric(vertical: 4),
                          itemCount: docs.take(15).length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Tok.borderSoft,
                            indent: 56,
                          ),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data =
                            doc.data() as Map<String, dynamic>;
                            final status =
                            (data['status'] ?? '') as String;
                            final isUnread = data['admin_read'] != true;
                            final isAlert = [
                              'pending_approval',
                              'requirements_submitted'
                            ].contains(status);
                            final highlight = isAlert && isUnread;

                            return InkWell(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection('inspection_requests')
                                    .doc(doc.id)
                                    .update({'admin_read': true});
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                if (mounted) {
                                  setState(() => _selectedIndex = 1);
                                }
                              },
                              child: Container(
                                color: highlight
                                    ? Tok.brand.withValues(alpha: 0.04)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                        BorderRadius.circular(Tok.rSm),
                                      ),
                                      child: Icon(
                                        _getStatusIcon(status),
                                        size: 14,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['property_name'] ??
                                                'Inspection request',
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Tok.textHi,
                                              fontSize: 13,
                                              fontWeight: highlight
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            status.replaceAll('_', ' '),
                                            style: Tok.bodySm.copyWith(
                                                color: Tok.textLo),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (highlight)
                                      Container(
                                        margin: const EdgeInsets.only(
                                            top: 6, left: 8),
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Tok.brand,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('pending')) return Tok.stPending;
    if (status.contains('approved')) return Tok.stApproved;
    if (status.contains('assigned')) return Tok.stAssigned;
    if (status.contains('completed')) return Tok.stCompleted;
    return Tok.textLo;
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('pending')) return Icons.hourglass_top_rounded;
    if (status.contains('approved')) return Icons.check_circle_outline_rounded;
    if (status.contains('assigned')) return Icons.person_pin_circle_outlined;
    if (status.contains('completed')) return Icons.verified_outlined;
    return Icons.info_outline_rounded;
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    children: [
                      TextSpan(text: 'Pyra', style: TextStyle(color: Tok.ok)),
                      TextSpan(
                          text: 'Check', style: TextStyle(color: Tok.brand)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('BFP COMMAND', style: Tok.label),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Tok.borderSoft),
          const SizedBox(height: 8),

          _NavTile(
            icon: Icons.analytics_outlined,
            title: titles[0],
            onTap: () => onSelect(0),
            selected: selectedIndex == 0,
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('inspection_requests')
                .snapshots(),
            builder: (context, snapshot) {
              int badgeCount = 0;
              if (snapshot.hasData) {
                badgeCount = snapshot.data!.docs.where((d) {
                  final data = d.data() as Map;
                  final s = data['status'] ?? '';
                  final isUnread = data['admin_read'] != true;
                  final isAlert = s == 'pending_approval' ||
                      s == 'requirements_submitted';
                  return isAlert && isUnread;
                }).length;
              }
              return _NavTile(
                icon: Icons.assignment_outlined,
                title: titles[1],
                onTap: () => onSelect(1),
                selected: selectedIndex == 1,
                badge: badgeCount > 0 ? badgeCount : null,
              );
            },
          ),
          _NavTile(
            icon: Icons.people_outline_rounded,
            title: titles[2],
            onTap: () => onSelect(2),
            selected: selectedIndex == 2,
          ),
          _NavTile(
            icon: Icons.verified_user_outlined,
            title: titles[3],
            onTap: () => onSelect(3),
            selected: selectedIndex == 3,
          ),
          _NavTile(
            icon: Icons.account_balance_outlined,
            title: titles[4],
            onTap: () => onSelect(4),
            selected: selectedIndex == 4,
          ),

          const Spacer(),
          Divider(height: 1, color: Tok.borderSoft),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              return _NavTile(
                icon: isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                title: isDark ? 'Light Mode' : 'Dark Mode',
                onTap: () {
                  themeProvider.toggleTheme();
                },
                selected: false,
              );
            },
          ),
          _NavTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            onTap: onLogout,
            selected: false,
            destructive: true,
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
  final VoidCallback onTap;
  final bool selected;
  final int? badge;
  final bool destructive;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.badge,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? Tok.textHi
        : destructive
        ? Tok.textLo
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
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: Tok.brand,
                        borderRadius: BorderRadius.circular(Tok.rSm),
                      ),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
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
  final void Function(List<QueryDocumentSnapshot> docs) onOpenNotifications;

  const _TopBar({required this.title, required this.onOpenNotifications});

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
              Text(
                'San Francisco, Agusan del Sur',
                style: TextStyle(color: Tok.textLo, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('inspection_requests')
                .orderBy('requested_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              int alerts = 0;
              for (final d in docs) {
                final data = d.data() as Map;
                final s = data['status'] ?? '';
                if (data['admin_read'] != true &&
                    (s == 'pending_approval' ||
                        s == 'requirements_submitted')) {
                  alerts++;
                }
              }
              return Tooltip(
                message: 'Notifications',
                child: InkWell(
                  onTap: () =>
                      onOpenNotifications(docs.cast<QueryDocumentSnapshot>()),
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 20, color: Tok.textMid),
                        if (alerts > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 14),
                              decoration: BoxDecoration(
                                color: Tok.brand,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                alerts > 99 ? '99+' : '$alerts',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              return Tooltip(
                message:
                isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                child: InkWell(
                  onTap: () {
                    themeProvider.toggleTheme();
                  },
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
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
                child: Text(
                  'A',
                  style: TextStyle(
                      color: Tok.textHi,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Administrator',
                    style: TextStyle(
                        color: Tok.textHi,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'BFP Command',
                    style: TextStyle(color: Tok.textLo, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 16, color: Tok.textLo),
            ],
          ),
        ],
      ),
    );
  }
}