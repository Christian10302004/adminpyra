import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../clerk_theme.dart';
import '../../../services/web_helper.dart';

class ClerkOverviewTab extends StatefulWidget {
  final Function(int) onTabRequested;
  const ClerkOverviewTab({super.key, required this.onTabRequested});

  @override
  State<ClerkOverviewTab> createState() => _ClerkOverviewTabState();
}

class _ClerkOverviewTabState extends State<ClerkOverviewTab> {
  String _selectedBrgyFilter = 'All';
  final _searchController = TextEditingController();

  static const _barangays = <String>[
    'All', 'Alegria', 'Bayugan 2', 'Bitan-agan', 'Borbon', 'Caimpugan',
    'Das-agan', 'Ebro', 'Hubang', 'Karaos', 'Ladgadan',
    'Lapinigan', 'Lucac', 'Magasawang Bato', 'New Lorenzo',
    'Ormaca', 'Pasta', 'Pisa-an', 'Barangay 1', 'Barangay 2',
    'Barangay 3', 'Barangay 4', 'Barangay 5', 'Rizal',
    'San Antonio', 'San Isidro', 'San Jose', 'San Roque',
    'Santa Ana', 'Tagapua', 'Tibog', 'To-og',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .snapshots(),
      builder: (context, snapshot) {
        int pendingEntries = 0;
        int activeWorkflows = 0;
        int totalIssued = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            final certStatus = data['certificate_status'] ?? '';

            if (status == 'pending_approval' ||
                status == 'requirements_submitted') {
              pendingEntries++;
            }
            if (status == 'completed' || status == 'assigned') {
              activeWorkflows++;
            }
            if (certStatus == 'issued') {
              totalIssued++;
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        decoration: InputDecoration(
                          hintText: 'Search by property or owner...',
                          hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Tok.textLo,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _searchController.clear(),
                      child: Text(
                        'Clear',
                        style: TextStyle(color: Tok.textLo, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              _MetricsBar(
                pending: pendingEntries,
                active: activeWorkflows,
                issued: totalIssued,
              ),
              const SizedBox(height: 28),

              SectionHeader(
                title: 'Inspection requests by barangay',
                subtitle: 'Filter the queue by the address on file.',
                trailing: _BarangayFilter(
                  value: _selectedBrgyFilter,
                  options: _barangays,
                  onChanged: (v) => setState(() => _selectedBrgyFilter = v),
                ),
              ),
              const SizedBox(height: 12),
              _RequestsTable(
                filter: _selectedBrgyFilter,
                searchQuery: _searchController.text,
                onUploadCertificate: () => widget.onTabRequested(2),
              ),
              const SizedBox(height: 28),

              const SectionHeader(
                title: 'Successfully issued certificates',
                subtitle: 'Officially released by the Fire Marshal.',
              ),
              const SizedBox(height: 12),
              _IssuedCertificatesTable(
                searchQuery: _searchController.text,
                onView: (data) => _viewFile(context, data),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewFile(BuildContext context, Map<String, dynamic> data) {
    final base64 = data['certificate_base64'] as String?;
    final ext = (data['certificate_extension'] ?? 'jpg').toString();
    if (base64 == null) return;

    if (ext.toLowerCase() == 'pdf') {
      openBase64InNewTab(base64, ext);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Tok.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rLg),
          side: BorderSide(color: Tok.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Certificate', style: Tok.h2),
                          const SizedBox(height: 2),
                          Text(
                            (data['certificate_filename'] ?? 'Image')
                                .toString(),
                            style: Tok.bodySm.copyWith(
                              color: Tok.textLo,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Tok.textMid),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Tok.borderSoft),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    child: Image.memory(
                      base64Decode(base64),
                      fit: BoxFit.contain,
                    ),
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

class _MetricsBar extends StatelessWidget {
  final int pending, active, issued;
  const _MetricsBar({
    required this.pending,
    required this.active,
    required this.issued,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Pending tasks',
                value: '$pending',
                hint: 'Approvals and requirements',
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: Tok.borderSoft),
            Expanded(
              child: _Metric(
                label: 'Active workflows',
                value: '$active',
                hint: 'Assigned or completed',
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: Tok.borderSoft),
            Expanded(
              child: _Metric(
                label: 'Issued certificates',
                value: '$issued',
                hint: 'Officially released',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value, hint;
  const _Metric({
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: Tok.label),
          const SizedBox(height: 8),
          Text(value, style: Tok.num),
          const SizedBox(height: 4),
          Text(
            hint,
            style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BarangayFilter extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _BarangayFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 14, color: Tok.textLo),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: Tok.surface,
              borderRadius: BorderRadius.circular(Tok.rMd),
              icon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.expand_more_rounded,
                    size: 16, color: Tok.textLo),
              ),
              style: Tok.body,
              items: options
                  .map((b) => DropdownMenuItem(
                value: b,
                child: Text(b, style: Tok.body),
              ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsTable extends StatelessWidget {
  final String filter, searchQuery;
  final VoidCallback onUploadCertificate;
  const _RequestsTable({
    required this.filter,
    required this.searchQuery,
    required this.onUploadCertificate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // FIXED: removed `const` from TableShell because Tok.textLo is a getter
          return TableShell(
            child: SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Tok.textLo),
                ),
              ),
            ),
          );
        }

        var docs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['property_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q) ||
                (data['full_name'] ?? data['email'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q);
          }).toList();
        }

        if (filter != 'All') {
          docs = docs.where((doc) {
            final addr =
                (doc.data() as Map)['address']?.toString().toLowerCase() ?? '';
            return addr.contains(filter.toLowerCase());
          }).toList();
        }

        return TableShell(
          header: Container(
            color: Tok.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('PROPERTY / OWNER', style: Tok.label),
                ),
                Expanded(
                  flex: 3,
                  child: Text('BARANGAY', style: Tok.label),
                ),
                SizedBox(
                  width: 160,
                  child: Text('STATUS', style: Tok.label),
                ),
                SizedBox(
                  width: 160,
                  child: Text('CERTIFICATE', style: Tok.label),
                ),
              ],
            ),
          ),
          child: docs.isEmpty
              ? const EmptyState(
            icon: Icons.location_off_outlined,
            title: 'No requests for this area',
            subtitle: 'Try a different barangay or set the filter to All.',
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Tok.borderSoft),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _RequestRow(
                data: data,
                onUploadCertificate: onUploadCertificate,
              );
            },
          ),
        );
      },
    );
  }
}

class _RequestRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onUploadCertificate;
  const _RequestRow({
    required this.data,
    required this.onUploadCertificate,
  });
  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hover = false;

  String _barangayFromAddress(String address) {
    final parts = address.split(',');
    return parts.length > 1 ? parts[1].trim() : '—';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'pending_approval').toString();
    final adminRemarks = (data['admin_remarks'] ?? '').toString();
    final hasCert = data['certificate_base64'] != null;
    final isCompleted = status == 'completed';
    final barangay = _barangayFromAddress((data['address'] ?? '').toString());

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: () => _showRequestDetails(context, data),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color:
          _hover ? Tok.surfaceAlt.withValues(alpha: 0.55) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['property_name'] ?? 'Untitled').toString(),
                      style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      (data['full_name'] ?? data['email'] ?? '—').toString(),
                      style:
                      Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (adminRemarks.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            status == 'resubmission_required'
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 12,
                            color: status == 'resubmission_required' ? Tok.danger : Tok.warn,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Remark: $adminRemarks',
                              style: Tok.bodySm.copyWith(
                                color: status == 'resubmission_required' ? Tok.danger : Tok.warn,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  barangay,
                  style: Tok.bodySm.copyWith(color: Tok.textMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusTag(status: status),
                ),
              ),
              SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _CertIndicator(
                          hasCert: hasCert, isCompleted: isCompleted),
                      const SizedBox(width: 12),
                      if (isCompleted && !hasCert)
                        RowActionButton(
                          label: 'Upload',
                          icon: Icons.upload_file_outlined,
                          onPressed: widget.onUploadCertificate,
                        ),
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

  void _showRequestDetails(BuildContext context, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending_approval').toString();
    final propName = (data['property_name'] ?? 'Untitled').toString();
    final ownerName = (data['full_name'] ?? data['email'] ?? '—').toString();
    final adminRemarks = (data['admin_remarks'] ?? 'None').toString();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rLg),
          side: BorderSide(color: Tok.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(propName, style: Tok.h2),
                          const SizedBox(height: 2),
                          Text('Owner: $ownerName', style: Tok.bodySm.copyWith(color: Tok.textLo)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: Tok.textMid),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Tok.borderSoft),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Status: ', style: Tok.label),
                    StatusTag(status: status),
                  ],
                ),
                const SizedBox(height: 16),
                Text('BFP ADMIN / MARSHAL REMARKS', style: Tok.label),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Tok.bg,
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    border: Border.all(color: Tok.border),
                  ),
                  child: Text(
                    adminRemarks,
                    style: Tok.body.copyWith(
                      color: adminRemarks != 'None' ? Tok.textHi : Tok.textLo,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tok.surfaceAlt,
                      foregroundColor: Tok.textHi,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CertIndicator extends StatelessWidget {
  final bool hasCert, isCompleted;
  const _CertIndicator({required this.hasCert, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final (label, color) = hasCert
        ? ('Uploaded', Tok.ok)
        : isCompleted
        ? ('Missing', Tok.warn)
        : ('—', Tok.textLo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Tok.bodySm.copyWith(color: Tok.textMid, fontSize: 11),
        ),
      ],
    );
  }
}

class _IssuedCertificatesTable extends StatelessWidget {
  final void Function(Map<String, dynamic> data) onView;
  final String searchQuery;
  const _IssuedCertificatesTable({
    required this.onView,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('certificate_status', isEqualTo: 'issued')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // FIXED: removed `const` from TableShell because Tok.textLo is a getter
          return TableShell(
            child: SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Tok.textLo),
                ),
              ),
            ),
          );
        }

        var docs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['property_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q) ||
                (data['full_name'] ?? data['email'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q);
          }).toList();
        }

        final sorted = docs.toList()
          ..sort((a, b) {
            final at = (a.data() as Map)['issued_at'] as Timestamp?;
            final bt = (b.data() as Map)['issued_at'] as Timestamp?;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

        return TableShell(
          header: Container(
            color: Tok.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('PROPERTY', style: Tok.label),
                ),
                Expanded(
                  flex: 3,
                  child: Text('ISSUED TO', style: Tok.label),
                ),
                SizedBox(
                  width: 120,
                  child: Text('ISSUED', style: Tok.label),
                ),
                SizedBox(
                  width: 160,
                  child: Text('EXPIRATION', style: Tok.label),
                ),
                SizedBox(
                  width: 200,
                  child: Text('', style: Tok.label),
                ),
              ],
            ),
          ),
          child: sorted.isEmpty
              ? const EmptyState(
            icon: Icons.verified_outlined,
            title: 'No certificates issued yet',
            subtitle:
            'Issued certificates will appear here for reference.',
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sorted.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Tok.borderSoft),
            itemBuilder: (context, index) {
              final doc = sorted[index];
              final data = doc.data() as Map<String, dynamic>;
              return _IssuedRow(
                data: data,
                onViewAudit: () =>
                    showFullAuditDialog(context, doc.id, data),
                onViewCertificate: () => viewCertificate(context, data),
              );
            },
          ),
        );
      },
    );
  }
}

class _IssuedRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onViewAudit, onViewCertificate;
  const _IssuedRow({
    required this.data,
    required this.onViewAudit,
    required this.onViewCertificate,
  });
  @override
  State<_IssuedRow> createState() => _IssuedRowState();
}

class _IssuedRowState extends State<_IssuedRow> {
  bool _hover = false;

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final expTs = data['expiration_date'] as Timestamp?;
    final isExpired = expTs != null && expTs.toDate().isBefore(DateTime.now());

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
        _hover ? Tok.surfaceAlt.withValues(alpha: 0.55) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                (data['property_name'] ?? 'Untitled').toString(),
                style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                (data['full_name'] ?? data['email'] ?? '—').toString(),
                style: Tok.bodySm.copyWith(color: Tok.textMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                _fmtDate(data['issued_at']),
                style: Tok.bodySm.copyWith(
                  color: Tok.textMid,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Tok.rSm),
                      border: Border.all(
                        color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isExpired ? 'Expired (${_fmtDate(expTs)})' : _fmtDate(expTs),
                      style: TextStyle(
                        color: isExpired ? Tok.danger : Tok.ok,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RowActionButton(
                    label: 'View audit',
                    icon: Icons.analytics_outlined,
                    onPressed: widget.onViewAudit,
                  ),
                  const SizedBox(width: 8),
                  GhostIconButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View certificate',
                    onPressed: widget.onViewCertificate,
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