import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../services/auth_service.dart';
import '../../services/web_helper.dart';
import '../../services/offline_service.dart';
import '../../models/user_model.dart';

import 'user_theme.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/request_tab.dart';
import 'tabs/account_tab.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    OfflineService.syncOfflineData();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final User? user = FirebaseAuth.instance.currentUser;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(_getTitle(), style: Tok.h1.copyWith(color: colors.textHi)),
        actions: [
          FutureBuilder<int>(
            future: OfflineService.getQueueCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox();
              return IconButton(
                tooltip: 'Sync offline data',
                icon: Badge(
                  label: Text(count.toString()),
                  backgroundColor: Tok.info,
                  child: const Icon(Icons.cloud_upload_outlined, size: 20, color: Tok.info),
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Syncing…'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  await OfflineService.syncOfflineData();
                  if (mounted) setState(() {});
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('uid', isEqualTo: user?.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Icon(Icons.notifications_outlined, size: 20);
                }
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  backgroundColor: Tok.brand,
                  child: const Icon(Icons.notifications_outlined, size: 20),
                );
              },
            ),
            onPressed: () => _showNotificationsSheet(context, user?.uid ?? ''),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _UserDrawer(
        selectedIndex: _selectedIndex,
        user: user,
        authService: authService,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardTab(
            onTabRequested: (i) => setState(() => _selectedIndex = i),
            onViewCertificate: _viewUserCertificate,
          ),
          ReportsTab(
            onTabRequested: (i) => setState(() => _selectedIndex = i),
            onUploadRequirement: _uploadRequirement,
            onSubmitRequirements: _submitFinalRequirements,
            onViewEvidence: (b64) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CertificateModal(
                  base64Data: b64,
                  fileName: 'Inspection_Evidence.jpg',
                ),
              );
            },
            onViewCertificate: () {},
          ),
          RequestTab(
            onSubmitted: () => setState(() => _selectedIndex = 0),
          ),
          const AccountTab(),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'My Reports';
      case 2: return 'New Request';
      case 3: return 'Account';
      default: return 'Dashboard';
    }
  }

  // ---------------------------------------------------------------------------
  // Shared logic: uploads, downloads, media
  // ---------------------------------------------------------------------------
  Future<void> _uploadRequirement(String docId) async {
    final colors = context.colors;

    final String? option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Upload Requirement',
                      style: Tok.h3.copyWith(color: colors.textHi),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Tok.brand),
                  title: Text('Take Photo', style: Tok.body.copyWith(color: colors.textHi)),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Tok.brand),
                  title: Text('Choose Photo from Gallery', style: Tok.body.copyWith(color: colors.textHi)),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.note_add_outlined, color: Tok.brand),
                  title: Text('Choose File / Document', style: Tok.body.copyWith(color: colors.textHi)),
                  subtitle: Text('PDF, DOC, TXT, Images', style: Tok.caption.copyWith(color: colors.textLo)),
                  onTap: () => Navigator.pop(context, 'file'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (option == null) return;

    try {
      Uint8List? bytes;
      String fileName = 'Document_${DateTime.now().millisecondsSinceEpoch}';

      if (option == 'camera' || option == 'gallery') {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: option == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 25,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (image == null) return;
        bytes = await image.readAsBytes();
        fileName = image.name.isNotEmpty ? image.name : '$fileName.jpg';
      } else if (option == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        fileName = file.name;
      }

      if (bytes == null) return;
      if (bytes.length > 750000) throw 'File is too large for database storage (Max 750 KB).';

      final base64String = base64Encode(bytes);
      final Map<String, dynamic> payload = {
        'base64': base64String,
        'name': fileName,
        'uploaded_at': FieldValue.serverTimestamp(),
      };

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        payload['uploaded_at'] = DateTime.now().toIso8601String();
        await OfflineService.addToQueue('requirement', docId, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally. Will sync when online.'),
              backgroundColor: Tok.info,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
      } else {
        await FirebaseFirestore.instance
            .collection('inspection_requests')
            .doc(docId)
            .collection('files')
            .add(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploaded successfully'),
              backgroundColor: Tok.ok,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Tok.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitFinalRequirements(String docId) async {
    final Map<String, dynamic> payload = {
      'status': 'requirements_submitted',
      'requirements_at': FieldValue.serverTimestamp(),
    };

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      payload['requirements_at'] = DateTime.now().toIso8601String();
      await OfflineService.addToQueue('completion', docId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status update queued locally.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .update(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requirements submitted for review.'),
            backgroundColor: Tok.ok,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _viewUserCertificate(Map<String, dynamic> data) {
    final String? base64 = data['certificate_base64'];
    if (base64 == null || base64.isEmpty) return;

    final String ext = (data['certificate_extension'] ?? 'pdf').toString().toLowerCase();
    String name = (data['certificate_filename'] ?? '').toString();
    if (name.isEmpty) {
      final prop = (data['property_name'] ?? 'Inspection').toString().replaceAll(' ', '_');
      name = 'Certificate_$prop.$ext';
    } else if (!name.toLowerCase().endsWith('.$ext') && !name.toLowerCase().endsWith('.pdf')) {
      name = '$name.$ext';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CertificateModal(
        base64Data: base64,
        fileName: name,
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.rMd)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Activity alerts', style: Tok.h2.copyWith(color: context.colors.textHi)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: context.colors.textMid),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.colors.borderSoft),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('No notifications yet.', style: TextStyle(color: context.colors.textLo)),
                    );
                  }
                  final sorted = docs.toList()
                    ..sort((a, b) {
                      final aT = (a.data() as Map)['timestamp'] as Timestamp?;
                      final bT = (b.data() as Map)['timestamp'] as Timestamp?;
                      if (aT == null) return 1;
                      if (bT == null) return -1;
                      return bT.compareTo(aT);
                    });
                  return ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.borderSoft, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final doc = sorted[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final unread = data['read'] != true;
                      return InkWell(
                        onTap: () => FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'read': true}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          color: unread ? context.colors.surfaceAlt.withValues(alpha: 0.5) : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8, height: 8,
                                margin: const EdgeInsets.only(top: 6, right: 12),
                                decoration: BoxDecoration(
                                  color: unread ? Tok.brand : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? '',
                                      style: Tok.body.copyWith(
                                        color: context.colors.textHi,
                                        fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['message'] ?? '',
                                      style: Tok.bodySm.copyWith(color: context.colors.textMid),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level sign-out dialog (accessible from any widget).
// ---------------------------------------------------------------------------
void showLogoutConfirmationDialog(BuildContext context, AuthService authService) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authService.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      );
    },
  );
}

class _UserDrawer extends StatelessWidget {
  final int selectedIndex;
  final User? user;
  final AuthService authService;
  final ValueChanged<int> onSelect;

  const _UserDrawer({
    required this.selectedIndex,
    required this.user,
    required this.authService,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Drawer(
      backgroundColor: colors.surface,
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
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: colors.border),
                          image: userModel?.profilePicBase64 != null
                              ? DecorationImage(
                            image: MemoryImage(base64Decode(userModel!.profilePicBase64!)),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: userModel?.profilePicBase64 == null
                            ? Text(
                          getInitials(userModel?.fullName ?? 'U'),
                          style: TextStyle(color: colors.textHi, fontSize: 14, fontWeight: FontWeight.w600),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userModel?.fullName ?? 'Loading…', style: Tok.h3.copyWith(color: colors.textHi), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(user?.email ?? '', style: Tok.caption.copyWith(color: colors.textLo), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(height: 1, color: colors.borderSoft),
            const SizedBox(height: 8),
            _DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', selected: selectedIndex == 0, onTap: () { onSelect(0); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.description_outlined, label: 'My reports', selected: selectedIndex == 1, onTap: () { onSelect(1); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.add_task_rounded, label: 'Request inspection', selected: selectedIndex == 2, onTap: () { onSelect(2); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.settings_outlined, label: 'Account', selected: selectedIndex == 3, onTap: () { onSelect(3); Navigator.pop(context); }),
            const Spacer(),
            Divider(height: 1, color: colors.borderSoft),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                showLogoutConfirmationDialog(context, authService);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
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
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.selected = false, this.destructive = false});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fg = selected ? colors.textHi : destructive ? Tok.danger : colors.textMid;
    return Material(
      color: selected ? colors.surfaceAlt : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (selected) Positioned(left: 0, top: 6, bottom: 6, child: Container(width: 2, color: Tok.brand)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 14),
                  Expanded(child: Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}