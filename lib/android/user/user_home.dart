import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.orange.shade900,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            FutureBuilder<UserModel?>(
              future: authService.getUserData(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userModel = snapshot.data;
                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: Colors.orange.shade900),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.orange),
                  ),
                  accountName: Text(userModel?.fullName ?? "Loading..."),
                  accountEmail: Text(user?.email ?? ""),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('My Reports'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Request Inspection'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
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

  String _getTitle() {
    switch (_selectedIndex) {
      case 0: return 'Property Dashboard';
      case 1: return 'My Reports';
      case 2: return 'New Request';
      default: return 'User';
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildDashboard();
      case 1: return const Center(child: Text('No reports available yet.'));
      case 2: return const Center(child: Text('Form to request a new inspection...'));
      default: return const SizedBox();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Property Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Stay updated on your safety status.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          const Card(
            color: Colors.green,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.white, size: 40),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Compliance Status", style: TextStyle(color: Colors.white70)),
                      Text("SECURE", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Latest Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.check)),
            title: Text("Annual Fire Check"),
            subtitle: Text("Completed on Oct 12, 2024"),
          ),
        ],
      ),
    );
  }
}
