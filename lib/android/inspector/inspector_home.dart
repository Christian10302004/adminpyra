import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class InspectorHome extends StatefulWidget {
  const InspectorHome({super.key});

  @override
  State<InspectorHome> createState() => _InspectorHomeState();
}

class _InspectorHomeState extends State<InspectorHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_getTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5D0000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Column(
          children: [
            FutureBuilder<UserModel?>(
              future: authService.getUserData(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userModel = snapshot.data;
                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5D0000), Color(0xFF2E0000)],
                    ),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.engineering_rounded, size: 40, color: const Color(0xFFFF5722)),
                  ),
                  accountName: Text(userModel?.fullName ?? "Loading..."),
                  accountEmail: Text(user?.email ?? ""),
                );
              },
            ),
            _buildDrawerTile(Icons.assignment_ind_rounded, 'My Assignments', 0),
            _buildDrawerTile(Icons.history_edu_rounded, 'Audit History', 1),
            _buildDrawerTile(Icons.map_rounded, 'Service Area', 2),
            const Spacer(),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);
                await authService.signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, int index) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFFF5722) : Colors.white38),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0: return 'Inspector Assignments';
      case 1: return 'Audit History';
      case 2: return 'Area Map';
      default: return 'Inspector';
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildAssignments();
      case 1: return const Center(child: Text('Past audits will appear here.', style: TextStyle(color: Colors.white38)));
      case 2: return const Center(child: Text('Map view for inspections...', style: TextStyle(color: Colors.white38)));
      default: return const SizedBox();
    }
  }

  Widget _buildAssignments() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFF5722).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.business_rounded, color: Color(0xFFFF5722)),
            ),
            title: Text('Pending Audit: Building ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Requested yesterday • High Priority', style: TextStyle(color: Colors.white38)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            onTap: () {},
          ),
        );
      },
    );
  }
}
