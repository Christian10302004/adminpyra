import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../../services/textbee_service.dart';
import '../../services/web_helper.dart';
import 'admin_theme.dart';

// Filter options: display label ↔ underlying Firestore status value.
const _statusOptions = <String, String?>{
  'All statuses': null,
  'Pending approval': 'pending_approval',
  'Awaiting requirements': 'approved_waiting_requirements',
  'Requirements submitted': 'requirements_submitted',
  'Resubmission required': 'resubmission_required',
  'Accepted (Conditional)': 'requirements_accepted_conditional',
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
          SizedBox(width: 340, child: Text('ACTION', style: Tok.label)),
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
                width: 340,
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
      case 'resubmission_required':
        return ('Needs Resubmit', Tok.danger);
      case 'requirements_accepted_conditional':
        return ('Accepted w/ Remark', Tok.warn);
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
    if (status == 'requirements_submitted' ||
        status == 'requirements_accepted_conditional' ||
        status == 'resubmission_required' ||
        status == 'approved_waiting_requirements') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'requirements_submitted' ||
              status == 'approved_waiting_requirements') ...[
            _MiniButton(
              label: 'Review',
              color: Tok.purple,
              onTap: () => _showReviewDialog(context),
            ),
            const SizedBox(width: 6),
          ],
          if (status == 'requirements_submitted' ||
              status == 'requirements_accepted_conditional' ||
              status == 'approved_waiting_requirements') ...[
            _MiniButton(
              label: 'Assign Inspector',
              color: Tok.info,
              onTap: () => _showInspectorPicker(context),
            ),
            const SizedBox(width: 6),
          ],
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
        onSelect: (id, name, selectedDate) async {
          final dateStr =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

          await FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .update({
            'status': 'assigned',
            'assigned_to': id,
            'inspector_name': name,
            'scheduled_date': Timestamp.fromDate(selectedDate),
            'scheduled_date_str': dateStr,
            'assigned_at': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance.collection('notifications').add({
            'uid': data['uid'],
            'title': 'Inspector Assigned',
            'message': '$name has been assigned to inspect your property on $dateStr.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          if (data['phone'] != null) {
            TextbeeService.sendSMS(
              data['phone'],
              "BFP Alert: Inspector $name has been assigned to ${data['property_name']} for $dateStr. They will contact you shortly.",
            );
          }

          if (context.mounted) Navigator.pop(context);
          onUpdated();
        },
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _RequirementsReviewDialog(
        docId: docId,
        data: data,
        onUpdated: onUpdated,
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

class _InspectorPickerDialog extends StatefulWidget {
  final void Function(String id, String name, DateTime scheduledDate) onSelect;
  const _InspectorPickerDialog({required this.onSelect});

  @override
  State<_InspectorPickerDialog> createState() => _InspectorPickerDialogState();
}

class _InspectorPickerDialogState extends State<_InspectorPickerDialog> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Tok.brand,
              surface: Tok.surface,
              onSurface: Tok.textHi,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_selectedDate);

    return Dialog(
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign Inspector',
                    style: TextStyle(
                      color: Tok.textHi,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Tok.textMid),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date Selection Box
              Text('INSPECTION DATE', style: Tok.label),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(Tok.rMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Tok.surfaceAlt,
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    border: Border.all(color: Tok.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: Tok.brand),
                      const SizedBox(width: 10),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Tok.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Change Date',
                        style: TextStyle(
                          color: Tok.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('SELECT INSPECTOR (MAX 5 ASSIGNMENTS / DAY)', style: Tok.label),
              const SizedBox(height: 8),

              // Query all scheduled inspections on dateStr to build inspector counts
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('inspection_requests')
                    .where('scheduled_date_str', isEqualTo: dateStr)
                    .snapshots(),
                builder: (context, dateSnapshot) {
                  final Map<String, int> inspectorCounts = {};
                  if (dateSnapshot.hasData) {
                    for (final doc in dateSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final inspectorId = data['assigned_to'] as String?;
                      if (inspectorId != null && inspectorId.isNotEmpty) {
                        inspectorCounts[inspectorId] = (inspectorCounts[inspectorId] ?? 0) + 1;
                      }
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
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
                          final name = (doc.data() as Map)['full_name'] ?? 'Unknown';
                          final count = inspectorCounts[doc.id] ?? 0;
                          final isFull = count >= 5;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isFull ? Tok.danger.withValues(alpha: 0.05) : Tok.surfaceAlt,
                              borderRadius: BorderRadius.circular(Tok.rMd),
                              border: Border.all(
                                color: isFull ? Tok.danger.withValues(alpha: 0.3) : Tok.borderSoft,
                              ),
                            ),
                            child: ListTile(
                              onTap: isFull
                                  ? null
                                  : () => widget.onSelect(
                                        doc.id,
                                        name,
                                        _selectedDate,
                                      ),
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isFull
                                      ? Tok.danger.withValues(alpha: 0.15)
                                      : Tok.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: isFull ? Tok.danger : Tok.brand,
                                ),
                              ),
                              title: Text(
                                name,
                                style: Tok.body.copyWith(
                                  color: isFull ? Tok.textLo : Tok.textHi,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                isFull
                                    ? 'FULL: 5/5 inspections assigned on $dateStr'
                                    : '$count/5 assigned for $dateStr',
                                style: TextStyle(
                                  color: isFull ? Tok.danger : Tok.ok,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isFull
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Tok.danger.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(Tok.rSm),
                                      ),
                                      child: Text(
                                        'MAX LIMIT',
                                        style: TextStyle(
                                          color: Tok.danger,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Tok.textLo,
                                    ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementsReviewDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const _RequirementsReviewDialog({
    required this.docId,
    required this.data,
    required this.onUpdated,
  });

  @override
  State<_RequirementsReviewDialog> createState() =>
      _RequirementsReviewDialogState();
}

class _RequirementsReviewDialogState
    extends State<_RequirementsReviewDialog> {
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _processReview(bool returnForResubmit) async {
    final remark = _remarksController.text.trim();
    if (remark.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter remarks before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newStatus = returnForResubmit
          ? 'resubmission_required'
          : 'requirements_accepted_conditional';

      await FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(widget.docId)
          .update({
        'status': newStatus,
        'admin_remarks': remark,
        'reviewed_at': FieldValue.serverTimestamp(),
      });

      final title = returnForResubmit
          ? 'Requirements Resubmission Required'
          : 'Requirements Accepted Provisionally';
      final msg = returnForResubmit
          ? 'Your requirements submission for ${widget.data['property_name']} needs correction: $remark'
          : 'Your requirements for ${widget.data['property_name']} have been conditionally accepted: $remark';

      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': widget.data['uid'],
        'title': title,
        'message': msg,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (widget.data['phone'] != null) {
        TextbeeService.sendSMS(
          widget.data['phone'],
          "BFP Notice: $msg",
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final propName =
        (widget.data['property_name'] ?? 'Untitled Property').toString();
    final inspectionType =
        (widget.data['inspection_type'] ?? 'Annual Fire Inspection').toString();

    return Dialog(
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Requirements',
                          style: TextStyle(
                            color: Tok.textHi,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          propName,
                          style: Tok.bodySm.copyWith(color: Tok.textLo),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Tok.textMid),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLIENT SUBMITTED REQUIREMENTS & CHECKLIST',
                        style: Tok.label),
                    const SizedBox(height: 10),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('inspection_requests')
                          .doc(widget.docId)
                          .collection('files')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Requirements Checklist
                            WebRequirementsChecklist(
                              inspectionType: inspectionType,
                              uploadedCount: docs.length,
                            ),
                            const SizedBox(height: 12),

                            if (docs.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Tok.bg,
                                  borderRadius: BorderRadius.circular(Tok.rSm),
                                  border: Border.all(color: Tok.borderSoft),
                                ),
                                child: Text(
                                  'No requirement files uploaded yet by client.',
                                  style: Tok.bodySm.copyWith(color: Tok.textLo),
                                ),
                              )
                            else ...[
                              Text('Uploaded Files Preview:', style: Tok.caption),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: docs.map((d) {
                                  final m = d.data() as Map<String, dynamic>;
                                  final b64 = (m['base64'] ?? '').toString();
                                  final name = (m['name'] ?? 'Requirement Document').toString();
                                  if (b64.isEmpty) return const SizedBox.shrink();
                                  final isPdf = _isPdfData(b64, name);

                                  return InkWell(
                                    onTap: () => _showEvidenceLightbox(
                                      context,
                                      b64,
                                      const [],
                                      name,
                                    ),
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: Tok.bg,
                                        borderRadius: BorderRadius.circular(Tok.rSm),
                                        border: Border.all(color: Tok.border),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: isPdf
                                          ? _buildPdfThumbnail(name)
                                          : Image.memory(
                                              base64Decode(b64),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _buildPdfThumbnail(name),
                                            ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    Text('REVIEW REMARKS / FEEDBACK', style: Tok.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarksController,
                      maxLines: 3,
                      style: Tok.body,
                      decoration: InputDecoration(
                        hintText:
                            'E.g., "Missing Fire Safety Inspection Certificate. Please upload valid proof." or "Accepted with condition: Submit complete documents within 30 days."',
                        hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                        filled: true,
                        fillColor: Tok.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          borderSide: BorderSide(color: Tok.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isSubmitting)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _processReview(true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Tok.danger,
                                side: BorderSide(color: Tok.danger.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Tok.rMd),
                                ),
                              ),
                              child: const Text(
                                'Return & Resubmit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _processReview(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Tok.brand,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Tok.rMd),
                                ),
                              ),
                              child: const Text(
                                'Accept w/ Remark',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
    final scheduledDate = (data['scheduled_date_str'] ?? 'Unscheduled').toString();
    final adminRemarks = (data['admin_remarks'] ?? 'None').toString();
    final remarks = (data['remarks'] ?? 'No special remarks').toString();
    final inspectionType = (data['inspection_type'] ?? 'Annual Fire Inspection').toString();
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
                          _infoItem('Scheduled Date', scheduledDate),
                          _infoItem('Admin / Marshal Remarks', adminRemarks),
                          _infoItem('Audit Remarks', remarks),
                          _infoItem('Certificate Requested', inspectionType),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (data['lat'] != null && data['lng'] != null) ...[
                      _buildEstablishmentMap(
                        (data['lat'] as num).toDouble(),
                        (data['lng'] as num).toDouble(),
                      ),
                      const SizedBox(height: 24),
                    ],

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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WebRequirementsChecklist(
                              inspectionType: inspectionType,
                              uploadedCount: docs.length,
                            ),
                            if (docs.isEmpty)
                              Container(
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
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: docs.map((d) {
                                  final m = d.data() as Map<String, dynamic>;
                                  final b64 = (m['base64'] ?? '').toString();
                                  final name = (m['name'] ?? 'Requirement Document').toString();
                                  if (b64.isEmpty) return const SizedBox.shrink();
                                  final isPdf = _isPdfData(b64, name);

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
                                        color: Tok.bg,
                                        borderRadius: BorderRadius.circular(Tok.rSm),
                                        border: Border.all(color: Tok.border),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: isPdf
                                          ? _buildPdfThumbnail(name)
                                          : Image.memory(
                                              base64Decode(b64),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _buildPdfThumbnail(name),
                                            ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Inspector Evidence & AI Detections
                    Text('Inspector Audit Evidence & AI Detections', style: Tok.h2),
                    if (data['inspector_remarks'] != null &&
                        (data['inspector_remarks'] as String).trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
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
                                Icon(Icons.notes_rounded, size: 16, color: Tok.brand),
                                const SizedBox(width: 6),
                                Text(
                                  'Inspector Remarks',
                                  style: TextStyle(
                                    color: Tok.textHi,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['inspector_remarks'] as String,
                              style: Tok.bodySm.copyWith(color: Tok.textHi),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  Row(
                    children: [
                      if (status == 'completed') ...[
                        Icon(Icons.check_circle_rounded, size: 16, color: Tok.ok),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        status == 'completed'
                            ? 'Inspection completed by $inspector'
                            : 'Inspection stage: ${status.replaceAll('_', ' ')}',
                        style: Tok.bodySm.copyWith(
                          color: status == 'completed' ? Tok.ok : Tok.textLo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

  Widget _buildEstablishmentMap(double lat, double lng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pinned Establishment Location', style: Tok.h2),
            InkWell(
              onTap: () {
                final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                openBase64InNewTab(url, 'html');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.directions_rounded, size: 14, color: Tok.info),
                    const SizedBox(width: 4),
                    Text(
                      'Open Directions / Google Maps',
                      style: TextStyle(
                        color: Tok.info,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tok.rMd),
            border: Border.all(color: Tok.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pyrafullapp.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
    final remarks = (m['remarks'] ?? data['inspector_remarks'] ?? '').toString();
    return _buildEvidenceCard(
      context,
      b64: b64,
      detections: detections,
      index: index,
      remarks: remarks,
    );
  }

  Widget _buildEvidenceCard(
      BuildContext context, {
        required String b64,
        required List<dynamic> detections,
        required int index,
        String? remarks,
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
              remarks: remarks,
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
                        remarks: remarks,
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
                    Icon(Icons.center_focus_strong_rounded, size: 14, color: Tok.info),
                    const SizedBox(width: 4),
                    Text(
                      'Roboflow AI Detections:',
                      style: Tok.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildDetectionsSplitView(detections),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isHazardClass(String className) {
  final lower = className.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
  return lower.contains('cigarette') ||
      lower.contains('firecracker') ||
      lower.contains('flammable') ||
      lower.contains('lighter') ||
      lower.contains('loaded outlet') ||
      lower.contains('overload') ||
      lower.contains('exposed wiring') ||
      lower.contains('exposed wired') ||
      lower.contains('wiring') ||
      lower.contains('wired') ||
      lower.contains('damaged wire') ||
      lower.contains('spark') ||
      lower.contains('bidon') ||
      lower.contains('hazard') ||
      lower.contains('combustible') ||
      lower.contains('danger');
}

String _formatClassName(String rawCls) {
  String clean = rawCls
      .replaceAll('sparks - v1 2022-08-01 10:00pm', 'Sparks')
      .replaceAll('--t1', '')
      .replaceAll('--t2', '')
      .replaceAll('--t3', '')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');

  return clean
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

List<Map<String, dynamic>> _formatAndDeduplicateDetections(List<dynamic> rawDetections) {
  final Map<String, String> uniqueMap = {};

  for (final d in rawDetections) {
    if (d is Map) {
      final rawCls = (d['class'] ?? 'Equipment').toString();
      final formattedName = _formatClassName(rawCls);

      final pctRaw = (d['confidence_pct'] ?? '')
          .toString()
          .replaceAll('%', '')
          .replaceAll('(', '')
          .replaceAll(')', '')
          .trim();
      final pctVal = double.tryParse(pctRaw) ?? (((d['confidence'] as num?)?.toDouble() ?? 0.0) * 100);
      final pctDisplay = '${pctVal.toStringAsFixed(1)}%';

      if (!uniqueMap.containsKey(formattedName)) {
        uniqueMap[formattedName] = pctDisplay;
      } else {
        final existingRaw = uniqueMap[formattedName]!.replaceAll('%', '').trim();
        final existingVal = double.tryParse(existingRaw) ?? 0.0;
        if (pctVal > existingVal) {
          uniqueMap[formattedName] = pctDisplay;
        }
      }
    }
  }

  return uniqueMap.entries.map((e) {
    final name = e.key;
    final pct = e.value;
    final isHazard = _isHazardClass(name);
    return {
      'name': name,
      'pct': pct,
      'isHazard': isHazard,
    };
  }).toList();
}

Widget _buildDetectionsSplitView(List<dynamic> rawDetections) {
  if (rawDetections.isEmpty) {
    return Text(
      'No AI detections tagged for this photo.',
      style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
    );
  }

  final items = _formatAndDeduplicateDetections(rawDetections);
  final compliantList = items.where((i) => !(i['isHazard'] as bool)).toList();
  final hazardList = items.where((i) => (i['isHazard'] as bool)).toList();

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // LEFT: COMPLIANT SAFETY EQUIPMENT
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Tok.ok.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Tok.rSm),
            border: Border.all(color: Tok.ok.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 13, color: Tok.ok),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Compliant Equipment',
                      style: TextStyle(
                        color: Tok.ok,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (compliantList.isEmpty)
                Text('None detected', style: TextStyle(color: Tok.textLo, fontSize: 11))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: compliantList.map((item) {
                    final name = item['name'] as String;
                    final pct = item['pct'] as String;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Tok.ok.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        border: Border.all(color: Tok.ok.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        pct.isNotEmpty ? '$name $pct' : name,
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
      ),
      const SizedBox(width: 8),

      // RIGHT: FIRE HAZARDS DETECTED
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Tok.danger.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Tok.rSm),
            border: Border.all(color: Tok.danger.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: Tok.danger),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Fire Hazards',
                      style: TextStyle(
                        color: Tok.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (hazardList.isEmpty)
                Text('No hazards detected', style: TextStyle(color: Tok.textLo, fontSize: 11))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hazardList.map((item) {
                    final name = item['name'] as String;
                    final pct = item['pct'] as String;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Tok.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        border: Border.all(color: Tok.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        pct.isNotEmpty ? '$name $pct' : name,
                        style: TextStyle(
                          color: Tok.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}


bool _isPdfData(String base64Str, [String? name]) {
  if (name != null && name.toLowerCase().endsWith('.pdf')) return true;
  try {
    final bytes = base64Decode(base64Str);
    return bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  } catch (_) {
    return false;
  }
}

Widget _buildPdfThumbnail(String name) {
  return Container(
    width: 110,
    height: 110,
    padding: const EdgeInsets.all(8),
    color: Tok.bg,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_rounded, size: 36, color: Tok.danger),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            fontSize: 10,
            color: Tok.textHi,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

void _showEvidenceLightbox(
  BuildContext context,
  String base64,
  List<dynamic> detections,
  String title, {
  String? remarks,
}) {
  final isPdf = _isPdfData(base64, title);

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
                    if (isPdf)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Tok.bg,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: Tok.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                size: 64, color: Tok.danger),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: Tok.h2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'PDF Document',
                              style: Tok.bodySm.copyWith(color: Tok.textLo),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      openBase64InNewTab(base64, 'pdf'),
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 18),
                                  label: const Text('Open PDF in New Tab'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Tok.brand,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(Tok.rSm),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => downloadBase64File(
                                      base64,
                                      title.replaceAll('.pdf', ''),
                                      'pdf'),
                                  icon: const Icon(Icons.download_rounded,
                                      size: 18),
                                  label: const Text('Download PDF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Tok.textHi,
                                    side: BorderSide(color: Tok.border),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(Tok.rSm),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Tok.rMd),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 440),
                          child: Image.memory(
                            base64Decode(base64),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Tok.bg,
                                borderRadius: BorderRadius.circular(Tok.rMd),
                                border: Border.all(color: Tok.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.description_outlined,
                                      size: 64, color: Tok.textMid),
                                  const SizedBox(height: 16),
                                  Text(title, style: Tok.h2),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        openBase64InNewTab(base64, 'pdf'),
                                    icon: const Icon(Icons.open_in_new_rounded,
                                        size: 18),
                                    label: const Text('Open Document'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Tok.brand,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (detections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetectionsSplitView(detections),
                    ],
                    if (remarks != null && remarks.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
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
                                Icon(Icons.notes_rounded, size: 16, color: Tok.brand),
                                const SizedBox(width: 6),
                                Text(
                                  'Inspector Remarks',
                                  style: TextStyle(
                                    color: Tok.textHi,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              remarks,
                              style: Tok.bodySm.copyWith(color: Tok.textHi),
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