import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../services/textbee_service.dart';
import 'admin_theme.dart';

// Filter options: display label ↔ underlying Firestore status value.
const _statusOptions = <String, String?>{
  'All statuses': null,
  'Pending approval': 'pending_approval',
  'Awaiting requirements': 'approved_waiting_requirements',
  'Requirements submitted': 'requirements_submitted',
  'Assigned': 'assigned',
  'Completed': 'completed',
};

class InspectionManagementView extends StatefulWidget {
  const InspectionManagementView({super.key});

  @override
  State<InspectionManagementView> createState() =>
      _InspectionManagementViewState();
}

class _InspectionManagementViewState extends State<InspectionManagementView> {
  String _statusLabel = 'All statuses';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            searchController: _searchController,
            searchFocus: _searchFocus,
            statusLabel: _statusLabel,
            onSearchChanged: (_) => setState(() {}),
            onStatusChanged: (v) => setState(() => _statusLabel = v),
            onClearSearch: () {
              _searchController.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Tok.surface,
                borderRadius: BorderRadius.circular(Tok.rLg),
                border: Border.all(color: Tok.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('inspection_requests')
                    .orderBy('requested_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.error_outline_rounded,
                      label: 'Error loading inspections',
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Tok.textLo,
                        ),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  // Apply in-memory filters
                  final filterValue = _statusOptions[_statusLabel];
                  if (filterValue != null) {
                    docs = docs
                        .where(
                            (d) => (d.data() as Map)['status'] == filterValue)
                        .toList();
                  }

                  if (_searchController.text.isNotEmpty) {
                    final q = _searchController.text.toLowerCase();
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final prop = (data['property_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final owner =
                      (data['full_name'] ?? data['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      return prop.contains(q) || owner.contains(q);
                    }).toList();
                  }

                  return Column(
                    children: [
                      const _TableHeader(),
                      Divider(height: 1, color: Tok.borderSoft),
                      Expanded(
                        child: docs.isEmpty
                            ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          label: 'No matching inspections found',
                        )
                            : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Tok.borderSoft,
                          ),
                          itemBuilder: (context, i) => _InspectionRow(
                            docId: docs[i].id,
                            data:
                            docs[i].data() as Map<String, dynamic>,
                            onUpdated: () => setState(() {}),
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
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String statusLabel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClearSearch;

  const _FilterBar({
    required this.searchController,
    required this.searchFocus,
    required this.statusLabel,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Tok.surface,
              borderRadius: BorderRadius.circular(Tok.rMd),
              border: Border.all(color: Tok.border),
            ),
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              style: Tok.body,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search property or owner...',
                hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Tok.textLo,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClearSearch,
                  splashRadius: 16,
                  color: Tok.textLo,
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Status filter
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Tok.surface,
            borderRadius: BorderRadius.circular(Tok.rMd),
            border: Border.all(color: Tok.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusLabel,
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
              style: Tok.body,
              items: _statusOptions.keys
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onStatusChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tok.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('PROPERTY / OWNER', style: Tok.label),
          ),
          Expanded(
            flex: 2,
            child: Text('INSPECTOR', style: Tok.label),
          ),
          Expanded(
            flex: 3,
            child: Text('PROCESS STAGE', style: Tok.label),
          ),
          SizedBox(width: 180, child: Text('ACTION', style: Tok.label)),
        ],
      ),
    );
  }
}

class _InspectionRow extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const _InspectionRow({
    required this.docId,
    required this.data,
    required this.onUpdated,
  });

  @override
  State<_InspectionRow> createState() => _InspectionRowState();
}

class _InspectionRowState extends State<_InspectionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final status = (widget.data['status'] ?? 'pending_approval').toString();
    final inspector =
    (widget.data['inspector_name'] ?? 'Unassigned').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: () => _showInspectionDetailsDialog(
          context,
          widget.docId,
          widget.data,
          widget.onUpdated,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hover
              ? Tok.surfaceAlt.withValues(alpha: 0.5)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Property & Info
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data['property_name'] ?? 'Untitled',
                      style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Owner: ${widget.data['full_name'] ?? widget.data['email'] ?? '—'}',
                      style:
                      Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Inspector
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_pin_circle_outlined,
                      size: 14,
                      color: Tok.textLo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inspector,
                        style: Tok.bodySm.copyWith(color: Tok.textMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Process stage (Status)
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(status: status),
                ),
              ),

              // Actions
              SizedBox(
                width: 180,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ActionAffordance(
                    docId: widget.docId,
                    status: status,
                    data: widget.data,
                    onUpdated: widget.onUpdated,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getDetails(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tok.rSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  (String, Color) _getDetails(String s) {
    switch (s) {
      case 'pending_approval':
        return ('Pending Approval', Tok.warn);
      case 'approved_waiting_requirements':
        return ('Awaiting Documents', Tok.info);
      case 'requirements_submitted':
        return ('Reviewing Files', Tok.purple);
      case 'assigned':
        return ('Assigned', Tok.info);
      case 'completed':
        return ('Completed', Tok.ok);
      default:
        return (s.replaceAll('_', ' '), Tok.textLo);
    }
  }
}

class _ActionAffordance extends StatelessWidget {
  final String docId;
  final String status;
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const _ActionAffordance({
    required this.docId,
    required this.status,
    required this.data,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'completed') {
      return _MiniButton(
        label: 'View Evidence',
        color: Tok.ok,
        icon: Icons.search_rounded,
        onTap: () => _showInspectionDetailsDialog(context, docId, data, onUpdated),
      );
    }
    if (status == 'pending_approval') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniButton(
            label: 'Approve',
            color: Tok.ok,
            onTap: () => _approveRequest(context),
          ),
          const SizedBox(width: 6),
          _MiniButton(
            label: 'Details',
            color: Tok.surfaceAlt,
            onTap: () => _showInspectionDetailsDialog(context, docId, data, onUpdated),
          ),
        ],
      );
    }
    if (status == 'requirements_submitted') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniButton(
            label: 'Assign Inspector',
            color: Tok.info,
            onTap: () => _showInspectorPicker(context),
          ),
          const SizedBox(width: 6),
          _MiniButton(
            label: 'Details',
            color: Tok.surfaceAlt,
            onTap: () => _showInspectionDetailsDialog(context, docId, data, onUpdated),
          ),
        ],
      );
    }
    return _MiniButton(
      label: 'View Details',
      color: Tok.surfaceAlt,
      onTap: () => _showInspectionDetailsDialog(context, docId, data, onUpdated),
    );
  }

  Future<void> _approveRequest(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('inspection_requests')
        .doc(docId)
        .update({
      'status': 'approved_waiting_requirements',
      'approved_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'uid': data['uid'],
      'title': 'Request Approved',
      'message':
      'Your inspection request for ${data['property_name']} is approved. Please upload requirements.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    if (data['phone'] != null) {
      TextbeeService.sendSMS(
        data['phone'],
        "Hello! Your inspection request for ${data['property_name']} has been approved. Please upload your requirements in the PyraCheck app.",
      );
    }
    onUpdated();
  }

  void _showInspectorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InspectorPickerDialog(
        onSelect: (id, name) async {
          await FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .update({
            'status': 'assigned',
            'assigned_to': id,
            'inspector_name': name,
            'assigned_at': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance.collection('notifications').add({
            'uid': data['uid'],
            'title': 'Inspector Assigned',
            'message': '$name has been assigned to inspect your property.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          if (data['phone'] != null) {
            TextbeeService.sendSMS(
              data['phone'],
              "BFP Alert: Inspector $name has been assigned to ${data['property_name']}. They will contact you shortly.",
            );
          }

          if (context.mounted) Navigator.pop(context);
          onUpdated();
        },
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;
  const _MiniButton({
    required this.label,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorPickerDialog extends StatelessWidget {
  final void Function(String id, String name) onSelect;
  const _InspectorPickerDialog({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Inspector',
                    style: TextStyle(
                      color: Tok.textHi,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'Inspector')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final inspectors = snapshot.data!.docs;
                      if (inspectors.isEmpty) {
                        return Text(
                          'No active inspectors found.',
                          style: TextStyle(
                            color: Tok.textLo,
                            fontSize: 13,
                          ),
                        );
                      }

                      return Column(
                        children: inspectors.map((doc) {
                          final name =
                              (doc.data() as Map)['full_name'] ?? 'Unknown';
                          return ListTile(
                            onTap: () => onSelect(doc.id, name),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Tok.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Tok.textMid,
                              ),
                            ),
                            title: Text(name, style: Tok.body),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Tok.textLo,
                            ),
                          );
                        }).toList(),
                      );
                    },
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

void _showInspectionDetailsDialog(
  BuildContext context,
  String docId,
  Map<String, dynamic> data,
  VoidCallback onUpdated,
) {
  showDialog(
    context: context,
    builder: (ctx) => _InspectionDetailsDialog(
      docId: docId,
      data: data,
      onUpdated: onUpdated,
    ),
  );
}

class _InspectionDetailsDialog extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const _InspectionDetailsDialog({
    required this.docId,
    required this.data,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending_approval').toString();
    final propName = (data['property_name'] ?? 'Untitled Property').toString();
    final address = (data['address'] ?? '—').toString();
    final ownerName = (data['full_name'] ?? data['email'] ?? '—').toString();
    final phone = (data['phone'] ?? '—').toString();
    final email = (data['email'] ?? '—').toString();
    final inspector = (data['inspector_name'] ?? 'Unassigned').toString();
    final remarks = (data['remarks'] ?? 'No special remarks').toString();
    final sigBase64 = data['client_signature_base64'] as String?;

    return Dialog(
      backgroundColor: Tok.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                propName,
                                style: Tok.h2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusPill(status: status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref ID: ${docId.toUpperCase()}',
                          style: Tok.caption.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: Tok.textMid),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview grid
                    Text('General Information', style: Tok.h2),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Tok.bg,
                        borderRadius: BorderRadius.circular(Tok.rMd),
                        border: Border.all(color: Tok.border),
                      ),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _infoItem('Property Owner', ownerName),
                          _infoItem('Contact Phone', phone),
                          _infoItem('Owner Email', email),
                          _infoItem('Address', address),
                          _infoItem('Assigned Inspector', inspector),
                          _infoItem('Audit Remarks', remarks),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Client Requirements Submissions
                    Text('Client Requirement Files', style: Tok.h2),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('inspection_requests')
                          .doc(docId)
                          .collection('files')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Tok.bg,
                              borderRadius: BorderRadius.circular(Tok.rSm),
                              border: Border.all(color: Tok.borderSoft),
                            ),
                            child: Text(
                              'No requirement files uploaded yet.',
                              style: Tok.bodySm.copyWith(color: Tok.textLo),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: docs.map((d) {
                            final m = d.data() as Map<String, dynamic>;
                            final b64 = (m['base64'] ?? '').toString();
                            final name = (m['name'] ?? 'Requirement Document').toString();
                            if (b64.isEmpty) return const SizedBox.shrink();
                            return InkWell(
                              onTap: () => _showEvidenceLightbox(
                                context,
                                b64,
                                const [],
                                name,
                              ),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Tok.rSm),
                                  border: Border.all(color: Tok.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.memory(
                                  base64Decode(b64),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.description_outlined),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Inspector Evidence & AI Detections
                    Text('Inspector Audit Evidence & AI Detections', style: Tok.h2),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('inspection_requests')
                          .doc(docId)
                          .collection('evidence')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final primaryB64 = data['evidence_base64'] as String?;

                        if (docs.isEmpty && (primaryB64 == null || primaryB64.isEmpty)) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Tok.bg,
                              borderRadius: BorderRadius.circular(Tok.rSm),
                              border: Border.all(color: Tok.borderSoft),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: Tok.textLo),
                                const SizedBox(width: 8),
                                Text(
                                  status == 'completed'
                                      ? 'Audit completed. No evidence photos attached.'
                                      : 'Audit is in progress. Inspector evidence will appear here upon completion.',
                                  style: Tok.bodySm.copyWith(color: Tok.textLo),
                                ),
                              ],
                            ),
                          );
                        }

                        if (docs.isEmpty && primaryB64 != null && primaryB64.isNotEmpty) {
                          return _buildEvidenceCard(
                            context,
                            b64: primaryB64,
                            detections: const [],
                            index: 1,
                          );
                        }

                        return Column(
                          children: [
                            for (int i = 0; i < docs.length; i++) ...[
                              _buildEvidenceCardFromDoc(context, docs[i], i + 1),
                              if (i < docs.length - 1) const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),

                    if (sigBase64 != null && sigBase64.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Client Signature', style: Tok.h2),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: Tok.border),
                        ),
                        child: Image.memory(
                          base64Decode(sigBase64),
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: Tok.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status == 'completed'
                        ? '✅ Inspection completed by $inspector'
                        : 'Inspection stage: ${status.replaceAll('_', ' ')}',
                    style: Tok.bodySm.copyWith(
                      color: status == 'completed' ? Tok.ok : Tok.textLo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tok.surfaceAlt,
                      foregroundColor: Tok.textHi,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tok.rMd),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Tok.label),
          const SizedBox(height: 3),
          Text(
            value,
            style: Tok.body.copyWith(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCardFromDoc(BuildContext context, QueryDocumentSnapshot doc, int index) {
    final m = doc.data() as Map<String, dynamic>;
    final b64 = (m['base64'] ?? '').toString();
    final detections = (m['detections'] as List?) ?? const [];
    return _buildEvidenceCard(
      context,
      b64: b64,
      detections: detections,
      index: index,
    );
  }

  Widget _buildEvidenceCard(
      BuildContext context, {
        required String b64,
        required List<dynamic> detections,
        required int index,
      }) {
    if (b64.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tok.bg,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showEvidenceLightbox(
              context,
              b64,
              detections,
              'Evidence Photo #$index',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tok.rSm),
              child: Image.memory(
                base64Decode(b64),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Evidence Photo #$index',
                      style: Tok.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _showEvidenceLightbox(
                        context,
                        b64,
                        detections,
                        'Evidence Photo #$index',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'View Fullscreen',
                          style: TextStyle(
                            color: Tok.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 14, color: Tok.info),
                    const SizedBox(width: 4),
                    Text(
                      'Roboflow AI Detections:',
                      style: Tok.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (detections.isEmpty)
                  Text(
                    'No AI detections tagged for this photo.',
                    style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: detections.map((d) {
                      final cls = (d['class'] ?? 'Equipment').toString();
                      final pct = (d['confidence_pct'] ?? '').toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Tok.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(Tok.rSm),
                          border: Border.all(
                            color: Tok.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '🤖 $cls ${pct.isNotEmpty ? "($pct)" : ""}',
                          style: TextStyle(
                            color: Tok.textHi,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showEvidenceLightbox(
  BuildContext context,
  String base64,
  List<dynamic> detections,
  String title,
) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Tok.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: Tok.h2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tok.rMd),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: Image.memory(
                          base64Decode(base64),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (detections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Tok.bg,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: Tok.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  size: 18,
                                  color: Tok.info,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Roboflow AI Identified Safety Equipment',
                                  style: TextStyle(
                                    color: Tok.textHi,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: detections.map((d) {
                                final cls = (d['class'] ?? 'Object').toString();
                                final pct = (d['confidence_pct'] ?? '').toString();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Tok.info.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(Tok.rSm),
                                    border: Border.all(
                                      color: Tok.info.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '🤖 $cls ${pct.isNotEmpty ? "($pct)" : ""}',
                                    style: TextStyle(
                                      color: Tok.textHi,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}