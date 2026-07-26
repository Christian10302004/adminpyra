import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  final _firestore = FirebaseFirestore.instance;

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'User';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 12),
              const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Full Name', Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField(emailController, 'Email Address', Icons.alternate_email),
                const SizedBox(height: 16),
                _buildTextField(phoneController, 'Phone Number', Icons.phone_outlined),
                const SizedBox(height: 16),
                _buildTextField(passwordController, 'Initial Password', Icons.lock_outline, obscure: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'System Access Role',
                    labelStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: [
                    _buildRoleItem('User', Icons.shield, const Color(0xFF1B5E20), 'Pyra User (Mobile)'),
                    _buildRoleItem('Inspector', Icons.local_fire_department, const Color(0xFFFF5722), 'Check Inspector (Audit)'),
                    _buildRoleItem('Clerk/Encoder', Icons.edit_note_rounded, Colors.cyan, 'Clerk / Data Encoder'),
                    _buildRoleItem('Fire Marshal', Icons.verified_user_rounded, Colors.deepPurpleAccent, 'Fire Marshal'),
                    _buildRoleItem('admin', Icons.admin_panel_settings_rounded, Colors.redAccent, 'System Administrator'),
                  ],
                  onChanged: (value) => setState(() => selectedRole = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (emailController.text.isNotEmpty && nameController.text.isNotEmpty) {
                  try {
                    if (passwordController.text.length < 6) {
                      throw 'Password must be at least 6 characters long.';
                    }

                    String appName = 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}';
                    FirebaseApp secondaryApp = await Firebase.initializeApp(
                      name: appName,
                      options: Firebase.app().options,
                    );

                    UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
                        .createUserWithEmailAndPassword(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );

                    String accountId = 'PYRA-${10000 + Random().nextInt(90000)}';
                    var bytes = utf8.encode(passwordController.text.trim());
                    var hashedPassword = sha256.convert(bytes).toString();

                    await _firestore.collection('users').doc(userCredential.user!.uid).set({
                      'account_id': accountId,
                      'createdAt': FieldValue.serverTimestamp(),
                      'email': emailController.text.trim(),
                      'full_name': nameController.text.trim(),
                      'lastSeen': FieldValue.serverTimestamp(),
                      'password': hashedPassword, 
                      'phone': phoneController.text.trim(),
                      'role': selectedRole,
                      'status': 'active',
                    });

                    await secondaryApp.delete();

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1B5E20),
                          content: Text('Account successfully created for ${emailController.text}'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Creation Failed: $e'), 
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 10),
                          action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('CREATE ACCOUNT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  DropdownMenuItem<String> _buildRoleItem(String value, IconData icon, Color color, String text) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User & Role Management',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('Configure access levels and monitor active sessions', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.add),
                label: const Text('NEW SYSTEM ACCOUNT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (FirebaseAuth.instance.currentUser == null) {
                      return const Center(child: Text('Error: Not Logged In', style: TextStyle(color: Colors.red)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Text('Check your Firestore Rules in Firebase Console.', style: TextStyle(fontSize: 12, color: Colors.white38)),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final users = snapshot.data!.docs;

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 80,
                        horizontalMargin: 30,
                        columns: const [
                          DataColumn(label: Text('FULL NAME', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70))),
                          DataColumn(label: Text('EMAIL IDENTITY', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70))),
                          DataColumn(label: Text('ROLE LEVEL', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70))),
                          DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70))),
                        ],
                        rows: users.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String role = data['role'] ?? 'User';
                          
                          Color roleColor;
                          switch (role.toLowerCase()) {
                            case 'inspector':
                              roleColor = const Color(0xFFFF5722);
                              break;
                            case 'clerk/encoder':
                              roleColor = Colors.cyan;
                              break;
                            case 'fire marshal':
                              roleColor = Colors.deepPurpleAccent;
                              break;
                            case 'admin':
                              roleColor = Colors.redAccent;
                              break;
                            default:
                              roleColor = const Color(0xFF1B5E20);
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: roleColor.withOpacity(0.1),
                                      child: Text(
                                        (data['full_name'] ?? 'U')[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(data['full_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                              DataCell(Text(data['email'] ?? '', style: const TextStyle(color: Colors.white70))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: roleColor.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF4CAF50), // Active Green
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('ACTIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38)),
                                  ],
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () => _confirmDelete(context, doc),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Revoke System Access?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete this account and all associated permissions.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
