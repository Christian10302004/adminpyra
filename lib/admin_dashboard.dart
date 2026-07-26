import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:html' as html; // WEB REFRESH SUPPORT
import 'login_page.dart';
import 'manage_users_view.dart';
import 'inspection_management_view.dart';
import 'reports_certificates_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Dashboard & Analytics',
    'Inspection Management',
    'User & Role Management',
    'Reports & Certificates',
    'System Setup',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Sidebar with Logo Theme Gradient
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4A0000), // Deep Crimson
                  Color(0xFF2E0000), // Dark Maroon
                ],
              ),
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/images/logo.png', height: 100),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    children: [
                      TextSpan(text: 'Pyra', style: TextStyle(color: Color(0xFF2E7D32))),
                      TextSpan(text: 'Check', style: TextStyle(color: Color(0xFFFF5722))),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                _NavTile(
                  icon: Icons.analytics_rounded,
                  title: 'Dashboard & Analytics',
                  onTap: () => setState(() => _selectedIndex = 0),
                  selected: _selectedIndex == 0,
                ),
                _NavTile(
                  icon: Icons.assignment_rounded,
                  title: 'Inspection Management',
                  onTap: () => setState(() => _selectedIndex = 1),
                  selected: _selectedIndex == 1,
                ),
                _NavTile(
                  icon: Icons.people_rounded,
                  title: 'User & Role Management',
                  onTap: () => setState(() => _selectedIndex = 2),
                  selected: _selectedIndex == 2,
                ),
                _NavTile(
                  icon: Icons.verified_user_rounded,
                  title: 'Reports & Certificates',
                  onTap: () => setState(() => _selectedIndex = 3),
                  selected: _selectedIndex == 3,
                ),
                _NavTile(
                  icon: Icons.settings_rounded,
                  title: 'System Setup',
                  onTap: () => setState(() => _selectedIndex = 4),
                  selected: _selectedIndex == 4,
                ),
                const Spacer(),
                const Divider(indent: 30, endIndent: 30, color: Colors.white10),
                _NavTile(
                  icon: Icons.logout_rounded,
                  title: 'LOG OUT',
                  onTap: () => _showLogoutDialog(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: Text(_titles[_selectedIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  actions: [
                    IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_active_outlined, color: Color(0xFFFF5722))),
                    const SizedBox(width: 20),
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1B5E20),
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
                        const OverviewView(),
                        const InspectionManagementView(),
                        const ManageUsersView(),
                        const ReportsCertificatesView(),
                        const Center(child: Text('System Setup View')),
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
        content: const Text('Are you sure you want to terminate your current session?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              html.window.location.reload();
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        int totalUsers = 0;
        int activeInspectors = 0;

        if (snapshot.hasData) {
          totalUsers = snapshot.data!.docs.length;
          activeInspectors = snapshot.data!.docs
              .where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'Inspector')
              .length;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Performance Analytics',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 30,
                    mainAxisSpacing: 30,
                    childAspectRatio: 2.3,
                    children: [
                      _StatCard(
                          title: 'TOTAL REGISTERED',
                          value: totalUsers.toString(),
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFF2E7D32)),
                      _StatCard(
                          title: 'ACTIVE INSPECTORS',
                          value: activeInspectors.toString(),
                          icon: Icons.engineering_rounded,
                          color: const Color(0xFFFF5722)),
                      _StatCard(
                          title: 'PENDING CERTIFICATES',
                          value: '08',
                          icon: Icons.pending_actions_rounded,
                          color: Colors.blueAccent),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text('Heatmap: San Francisco, Agusan del Sur',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              // Map Container
              Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(8.5106, 125.9793), // San Francisco, Agusan del Sur
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.adminpyra',
                      ),
                      // Simulated Heatmap using CircleLayer
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: const LatLng(8.5106, 125.9793),
                            color: Colors.red.withOpacity(0.3),
                            borderStrokeWidth: 2,
                            borderColor: Colors.red.withOpacity(0.5),
                            useRadiusInMeter: true,
                            radius: 500,
                          ),
                          CircleMarker(
                            point: const LatLng(8.5130, 125.9820),
                            color: Colors.orange.withOpacity(0.3),
                            radius: 300,
                            useRadiusInMeter: true,
                          ),
                          CircleMarker(
                            point: const LatLng(8.5080, 125.9750),
                            color: Colors.orange.withOpacity(0.3),
                            radius: 400,
                            useRadiusInMeter: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text('Recent Activity',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  children: [
                    _ActivityItem(title: 'Inspection Completed', subtitle: 'Building A-12 marked as safe', time: '2h ago'),
                    Divider(color: Colors.white10),
                    _ActivityItem(title: 'New User Access', subtitle: 'New mobile user authorized', time: '5h ago'),
                    Divider(color: Colors.white10),
                    _ActivityItem(title: 'Certificate Issued', subtitle: 'Safety cert for Plaza Mall', time: 'Yesterday'),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({required this.title, required this.subtitle, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
        leading: Icon(icon, color: selected ? Colors.white : Colors.white38),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontWeight: selected ? FontWeight.w900 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
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
                Text(title,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
