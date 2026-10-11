import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'admin_theme.dart';

// Role definitions — single source of truth for label, icon, color, description.
class _Role {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _Role({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const all = <_Role>[
    _Role(
      value: 'User',
      label: 'Pyra User',
      description: 'Citizen mobile access',
      icon: Icons.shield_outlined,
      color: Tok.ok,
    ),
    _Role(
      value: 'Inspector',
      label: 'Check Inspector',
      description: 'On-field audit access',
      icon: Icons.local_fire_department_outlined,
      color: Tok.brand,
    ),
    _Role(
      value: 'Clerk/Encoder',
      label: 'Clerk / Encoder',
      description: 'Data entry & records',
      icon: Icons.edit_note_outlined,
      color: Colors.teal,
    ),
    _Role(
      value: 'Fire Marshal',
      label: 'Fire Marshal',
      description: 'Approvals & oversight',
      icon: Icons.verified_user_outlined,
      color: Tok.purple,
    ),
    _Role(
      value: 'Establishment Representative',
      label: 'Establishment Rep',
      description: 'Web portal for establishments',
      icon: Icons.business_outlined,
      color: Tok.info,
    ),
    _Role(
      value: 'admin',
      label: 'System Administrator',
      description: 'Full system access',
      icon: Icons.admin_panel_settings_outlined,
      color: Tok.danger,
    ),
  ];

  static _Role forValue(String? v) {
    return all.firstWhere(
          (r) => r.value.toLowerCase() == (v ?? '').toLowerCase(),
      orElse: () => all.first,
    );
  }
}

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String? _roleFilter; // null = all

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with search and actions
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Tok.surface,
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    border: Border.all(color: Tok.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: Tok.body,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email or ID...',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Tok.textLo,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _RoleFilter(
                current: _roleFilter,
                onChanged: (v) => setState(() => _roleFilter = v),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add personnel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tok.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tok.rMd),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // User table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Tok.surface,
                borderRadius: BorderRadius.circular(Tok.rLg),
                border: Border.all(color: Tok.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.error_outline,
                      label: 'Error loading users',
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Tok.textLo,
                        ),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  // Apply search and filters in memory for faster feedback
                  if (_searchController.text.isNotEmpty) {
                    final q = _searchController.text.toLowerCase();
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return (data['full_name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                          (data['email'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(q) ||
                          (data['account_id'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(q);
                    }).toList();
                  }

                  if (_roleFilter != null) {
                    docs = docs.where((d) {
                      final role = (d.data() as Map<String, dynamic>)['role']
                          ?.toString()
                          .toLowerCase();
                      return role == _roleFilter!.toLowerCase();
                    }).toList();
                  }

                  return Column(
                    children: [
                      _TableHeader(count: docs.length),
                      Divider(height: 1, color: Tok.borderSoft),
                      Expanded(
                        child: docs.isEmpty
                            ? const EmptyState(
                          icon: Icons.people_outline,
                          label: 'No matching records',
                        )
                            : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Tok.borderSoft,
                          ),
                          itemBuilder: (context, i) => _UserRow(
                            docId: docs[i].id,
                            data:
                            docs[i].data() as Map<String, dynamic>,
                            onRefresh: () => setState(() {}),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddUserDialog(),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final int count;
  const _TableHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tok.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('NAME & IDENTITY', style: Tok.label),
          ),
          Expanded(
            flex: 3,
            child: Text('ASSIGNED ROLE', style: Tok.label),
          ),
          Expanded(
            flex: 2,
            child: Text('STATUS', style: Tok.label),
          ),
          const SizedBox(width: 80),
          Text('$count total',
              style: Tok.label.copyWith(color: Tok.textMid)),
        ],
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  const _UserRow({
    required this.docId,
    required this.data,
    required this.onRefresh,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final role = _Role.forValue(widget.data['role']);
    final status =
    (widget.data['status'] ?? 'active').toString().toLowerCase();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hover
            ? Tok.surfaceAlt.withValues(alpha: 0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Name & Info
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Tok.surfaceAlt,
                      borderRadius: BorderRadius.circular(Tok.rMd),
                      border: Border.all(color: Tok.border),
                    ),
                    child: Text(
                      _initials(widget.data['full_name'] ?? 'U'),
                      style: TextStyle(
                        color: Tok.textHi,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['full_name'] ?? 'Unnamed',
                          style: Tok.body.copyWith(
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.data['email'] ??
                              widget.data['account_id'] ??
                              '—',
                          style: Tok.bodySm.copyWith(color: Tok.textLo),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Role tag
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: role.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Tok.rSm),
                      border:
                      Border.all(color: role.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(role.icon, size: 14, color: role.color),
                        const SizedBox(width: 8),
                        Text(
                          role.label,
                          style: TextStyle(
                            color: role.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: status == 'active' ? Tok.ok : Tok.textLo,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status.toUpperCase(),
                    style: Tok.label.copyWith(
                      color: status == 'active' ? Tok.textHi : Tok.textLo,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            _RowActions(
              docId: widget.docId,
              currentRole: widget.data['role'] ?? 'User',
              status: status,
              onRefresh: widget.onRefresh,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _RowActions extends StatelessWidget {
  final String docId;
  final String currentRole;
  final String status;
  final VoidCallback onRefresh;

  const _RowActions({
    required this.docId,
    required this.currentRole,
    required this.status,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ActionButton(
            icon: Icons.manage_accounts_outlined,
            tooltip: 'Change role',
            onTap: () => _showRoleDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: status == 'active'
                ? Icons.block_rounded
                : Icons.check_circle_outline,
            tooltip: status == 'active' ? 'Suspend user' : 'Activate user',
            color: status == 'active' ? Tok.danger : Tok.ok,
            onTap: () => _toggleStatus(context),
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _RolePicker(
        current: currentRole,
        onSelect: (newRole) async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .update({'role': newRole});
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context) async {
    final next = status == 'active' ? 'suspended' : 'active';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'status': next});
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Tok.border),
          ),
          child: Icon(icon, size: 14, color: color ?? Tok.textMid),
        ),
      ),
    );
  }
}

class _RoleFilter extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onChanged;
  const _RoleFilter({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: current,
          dropdownColor: Tok.surface,
          borderRadius: BorderRadius.circular(Tok.rMd),
          icon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: Tok.textLo,
            ),
          ),
          hint: Text(
            'All roles',
            style: TextStyle(color: Tok.textLo, fontSize: 13),
          ),
          style: Tok.body,
          items: [
            const DropdownMenuItem(value: null, child: Text('All roles')),
            ..._Role.all.map(
                  (r) => DropdownMenuItem(value: r.value, child: Text(r.label)),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _RolePicker({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign User Role',
                    style: TextStyle(
                      color: Tok.textHi,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elevating a user\'s role changes their access level in the PyraCheck ecosystem.',
                    style: TextStyle(color: Tok.textLo, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ..._Role.all.map((r) {
                    final selected =
                        current.toLowerCase() == r.value.toLowerCase();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? r.color.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(Tok.rMd),
                        border: Border.all(
                          color: selected
                              ? r.color.withValues(alpha: 0.4)
                              : Tok.borderSoft,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => onSelect(r.value),
                        leading: Icon(
                          r.icon,
                          color: selected ? r.color : Tok.textLo,
                        ),
                        title: Text(
                          r.label,
                          style: Tok.body.copyWith(
                            fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          r.description,
                          style: Tok.bodySm.copyWith(
                            color: Tok.textLo,
                            fontSize: 11,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: r.color,
                        )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD USER DIALOG
// ---------------------------------------------------------------------------
class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();
  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'User';
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    if (_email.text.isEmpty || _pass.text.isEmpty || _name.text.isEmpty) {
      setState(() => _error = 'Please fill required fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Create second Firebase app to avoid logging out current admin
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'temp',
        options: Firebase.app().options,
      );

      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );

      final accountId = 'PYRA-${10000 + Random().nextInt(90000)}';
      final bytes = utf8.encode(_pass.text);
      final hashed = sha256.convert(bytes).toString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'account_id': accountId,
        'createdAt': FieldValue.serverTimestamp(),
        'email': _email.text.trim(),
        'full_name': _name.text.trim(),
        'lastSeen': FieldValue.serverTimestamp(),
        'password': hashed,
        'phone': _phone.text.trim(),
        'role': _role,
        'status': 'active',
      });

      await tempApp.delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Station Personnel',
                style: TextStyle(
                  color: Tok.textHi,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Tok.danger, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
              _field('FULL NAME *', _name, 'e.g. Juan Dela Cruz'),
              const SizedBox(height: 16),
              _field('EMAIL ADDRESS *', _email, 'name@agency.gov.ph'),
              const SizedBox(height: 16),
              _field('PASSWORD *', _pass, 'Initial credentials',
                  obscure: true),
              const SizedBox(height: 16),
              _field('PHONE NUMBER', _phone, '+63 900 000 0000'),
              const SizedBox(height: 16),
              Text('ASSIGN ROLE', style: Tok.label),
              const SizedBox(height: 8),
              _RoleFilter(
                current: _role,
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Tok.textMid),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tok.brand,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
      String label,
      TextEditingController c,
      String hint, {
        bool obscure = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tok.label),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          obscureText: obscure,
          style: Tok.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
            filled: true,
            fillColor: Tok.bg,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: BorderSide(color: Tok.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: BorderSide(color: Tok.info),
            ),
          ),
        ),
      ],
    );
  }
}