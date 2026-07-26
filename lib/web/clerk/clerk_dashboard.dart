import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/web_helper.dart'; 
import '../login/login_page.dart';
import '../admin/inspection_management_view.dart';
import '../admin/reports_certificates_view.dart';

class ClerkDashboard extends StatefulWidget {
  const ClerkDashboard({super.key});

  @override
  State<ClerkDashboard> createState() => _ClerkDashboardState();
}

class _ClerkDashboardState extends State<ClerkDashboard> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Clerk Terminal',
    'Data Entry (Inspections)',
    'Reports & Records',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF002E2E), 
                  Color(0xFF001A1A), 
                ],
              ),
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/images/logo.png', height: 90),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    children: [
                      TextSpan(text: 'Pyra', style: TextStyle(color: Color(0xFF2E7D32))),
                      TextSpan(text: 'Check', style: TextStyle(color: Colors.cyan)),
                    ],
                  ),
                ),
                const Text('CLERK / ENCODER', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 50),
                _NavTile(
                  icon: Icons.dashboard_customize_rounded,
                  title: 'Clerk Terminal',
                  onTap: () => setState(() => _selectedIndex = 0),
                  selected: _selectedIndex == 0,
                ),
                _NavTile(
                  icon: Icons.edit_document,
                  title: 'Data Entry',
                  onTap: () => setState(() => _selectedIndex = 1),
                  selected: _selectedIndex == 1,
                ),
                _NavTile(
                  icon: Icons.folder_shared_rounded,
                  title: 'Reports & Records',
                  onTap: () => setState(() => _selectedIndex = 2),
                  selected: _selectedIndex == 2,
                ),
                const Spacer(),
                const Divider(indent: 30, endIndent: 30, color: Colors.white10),
                _NavTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  onTap: () => _showLogoutDialog(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: Text(_titles[_selectedIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  actions: [
                    const Center(child: Text('ENCODER ACCESS', style: TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 20),
                    const CircleAvatar(
                      backgroundColor: Colors.cyan,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        const ClerkOverview(),
                        const InspectionManagementView(),
                        const ReportsCertificatesView(),
                      ],
                    ),
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out from the encoder terminal?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              reloadPage();
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class ClerkOverview extends StatelessWidget {
  const ClerkOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Data Statistics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 30,
                mainAxisSpacing: 30,
                childAspectRatio: 2.5,
                children: [
                  _StatCard(title: 'PENDING ENTRIES', value: '24', icon: Icons.pending_rounded, color: Colors.cyan),
                  _StatCard(title: 'PROCESSED TODAY', value: '12', icon: Icons.check_circle_outline, color: const Color(0xFF2E7D32)),
                ],
              );
            },
          ),
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

  const _NavTile({required this.icon, required this.title, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: selected ? Colors.white : Colors.white24),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white24,
            fontWeight: selected ? FontWeight.w900 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: selected ? Colors.cyan.withOpacity(0.1) : Colors.transparent,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
