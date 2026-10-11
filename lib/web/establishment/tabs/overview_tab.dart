import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../establishment_theme.dart';

class OverviewTab extends StatelessWidget {
  final Function(int, String) onTabRequested;

  const OverviewTab({super.key, required this.onTabRequested});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Tok.textLo,
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // Calculate stats
        final totalRecords = docs.length;
        final completedAudits = docs
            .where((d) => (d.data() as Map)['status'] == 'completed')
            .length;
        final pendingInspections = docs
            .where((d) => (d.data() as Map)['status'] != 'completed')
            .length;

        // Sort recent inspections
        final recentDocs = docs.toList()
          ..sort((a, b) {
            final at = (a.data() as Map)['requested_at'] as Timestamp?;
            final bt = (b.data() as Map)['requested_at'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

        final displayDocs = recentDocs.take(5).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'TOTAL RECORDS',
                      value: '$totalRecords',
                      subtitle: 'All submissions',
                      color: Tok.info,
                      onTap: () => onTabRequested(1, 'All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      label: 'COMPLETED AUDITS',
                      value: '$completedAudits',
                      subtitle: 'Passed inspection',
                      color: Tok.ok,
                      onTap: () => onTabRequested(1, 'completed'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      label: 'PENDING INSPECTIONS',
                      value: '$pendingInspections',
                      subtitle: 'In progress',
                      color: Tok.warn,
                      onTap: () => onTabRequested(1, 'pending'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Live Audit Monitoring Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live audit monitoring', style: Tok.h2),
                  const SizedBox(height: 4),
                  Text(
                    'A snapshot of your most recent inspections.',
                    style: Tok.bodySm.copyWith(color: Tok.textLo),
                  ),
                  const SizedBox(height: 16),

                  // Table
                  TableShell(
                    expandChild: false,
                    header: Container(
                      color: Tok.surfaceAlt,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
                            flex: 2,
                            child: Text('TYPE', style: Tok.label),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text('STATUS', style: Tok.label),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text('CERTIFICATE', style: Tok.label),
                          ),
                          SizedBox(
                            width: 220,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${displayDocs.length} of $totalRecords',
                                style: Tok.label.copyWith(
                                  color: Tok.textMid,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: displayDocs.isEmpty
                        ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No records yet',
                      subtitle:
                      'Submit an inspection request to see it here.',
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: displayDocs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Tok.borderSoft,
                      ),
                      itemBuilder: (context, index) {
                        final doc = displayDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _OverviewRow(
                          data: data,
                          onViewAudit: () => showFullAuditDialog(
                            context,
                            doc.id,
                            data,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Stat Card
// ===========================================================================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tok.rLg),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Tok.surface,
            borderRadius: BorderRadius.circular(Tok.rLg),
            border: Border.all(color: Tok.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: Tok.label),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: Tok.num),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: Tok.bodySm.copyWith(color: Tok.textLo),
                    ),
                  ),
                  Text(
                    'View →',
                    style: Tok.bodySm.copyWith(
                      color: Tok.textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Overview Row (matches RecordsTab layout)
// ===========================================================================
class _OverviewRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onViewAudit;

  const _OverviewRow({
    required this.data,
    required this.onViewAudit,
  });

  @override
  State<_OverviewRow> createState() => _OverviewRowState();
}

class _OverviewRowState extends State<_OverviewRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'pending_approval').toString();
    final certStatus = (data['certificate_status'] ?? '').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hover
            ? Tok.surfaceAlt.withValues(alpha: 0.55)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    'Owner: ${(data['full_name'] ?? data['email'] ?? '—')}',
                    style: Tok.bodySm.copyWith(
                      color: Tok.textLo,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Loc: ${(data['address'] ?? '—')}',
                    style: Tok.bodySm.copyWith(
                      color: Tok.textLo,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (data['inspector_name'] ?? '—').toString(),
                style: Tok.bodySm.copyWith(color: Tok.textMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (data['inspection_type'] ?? '—').toString(),
                style: Tok.bodySm.copyWith(color: Tok.textMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusTag(status: status),
              ),
            ),
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (context) {
                    final expTs = data['expiration_date'] as Timestamp?;
                    final isExpired = expTs != null &&
                        expTs.toDate().isBefore(DateTime.now());
                    return CertIndicator(
                      hasCert: certStatus == 'issued',
                      inReview: certStatus == 'pending_review',
                      isExpired: isExpired,
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RowActionButton(
                    label: 'View audit',
                    icon: Icons.analytics_outlined,
                    onPressed: widget.onViewAudit,
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