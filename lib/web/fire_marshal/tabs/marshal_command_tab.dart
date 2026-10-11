import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../fire_marshal_theme.dart';

class MarshalCommandTab extends StatelessWidget {
  final Function(int) onTabRequested;
  const MarshalCommandTab({super.key, required this.onTabRequested});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .snapshots(),
      builder: (context, snapshot) {
        int awaiting = 0;
        int total = 0;
        int issuedThisMonth = 0;
        final now = DateTime.now();

        final statusMap = <String, int>{
          'Pending': 0,
          'In Review': 0,
          'Issued': 0,
        };

        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final certStatus = data['certificate_status'] ?? '';

            if (certStatus == 'pending_review') {
              awaiting++;
              statusMap['In Review'] = statusMap['In Review']! + 1;
            } else if (certStatus == 'issued') {
              statusMap['Issued'] = statusMap['Issued']! + 1;
              final issuedAt = data['issued_at'] as Timestamp?;
              if (issuedAt != null && issuedAt.toDate().month == now.month) {
                issuedThisMonth++;
              }
            } else {
              statusMap['Pending'] = statusMap['Pending']! + 1;
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _MetricCard(
                          title: 'Needs Official Signature',
                          value: '$awaiting',
                          subtitle:
                          'Certificates awaiting your final verification and release.',
                          icon: Icons.draw_rounded,
                          onTap: () => onTabRequested(2),
                        ),
                        const SizedBox(height: 24),
                        _AnalyticsPanel(statusMap: statusMap, total: total),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _SmallMetricRow(
                          metrics: [
                            _MiniMetric(
                              label: 'ISSUED (MONTH)',
                              value: '$issuedThisMonth',
                              icon: Icons.verified_user_outlined,
                            ),
                            _MiniMetric(
                              label: 'COMPLIANCE',
                              value: '94%',
                              icon: Icons.analytics_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _RecentIssuances(docs: snapshot.data?.docs ?? []),
                      ],
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

class _AnalyticsPanel extends StatelessWidget {
  final Map<String, int> statusMap;
  final int total;
  const _AnalyticsPanel({required this.statusMap, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tok.surface,
        border: Border.all(color: Tok.border),
        borderRadius: BorderRadius.circular(Tok.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WORKFLOW DISTRIBUTION', style: Tok.label),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: [
                        PieChartSectionData(
                          value: statusMap['Pending']!.toDouble(),
                          color: Tok.warn,
                          radius: 40,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: statusMap['In Review']!.toDouble(),
                          color: Tok.info,
                          radius: 40,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: statusMap['Issued']!.toDouble(),
                          color: Tok.ok,
                          radius: 40,
                          title: '',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      label: 'Pending Approval',
                      color: Tok.warn,
                      count: statusMap['Pending']!,
                    ),
                    _LegendItem(
                      label: 'Awaiting Signature',
                      color: Tok.info,
                      count: statusMap['In Review']!,
                    ),
                    _LegendItem(
                      label: 'Officially Issued',
                      color: Tok.ok,
                      count: statusMap['Issued']!,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentIssuances extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _RecentIssuances({required this.docs});

  @override
  Widget build(BuildContext context) {
    final issued = docs
        .where((d) => (d.data() as Map)['certificate_status'] == 'issued')
        .toList();
    issued.sort((a, b) {
      final at = (a.data() as Map)['issued_at'] as Timestamp?;
      final bt = (b.data() as Map)['issued_at'] as Timestamp?;
      return (bt ?? Timestamp.now()).compareTo(at ?? Timestamp.now());
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tok.surface,
        border: Border.all(color: Tok.border),
        borderRadius: BorderRadius.circular(Tok.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT SIGNATURES', style: Tok.label),
          const SizedBox(height: 16),
          if (issued.isEmpty)
            Text('No certificates issued yet.', style: Tok.bodySm)
          else
            ...issued.take(5).map((d) {
              final data = d.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Tok.ok,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['property_name'] ?? 'Untitled',
                            style: Tok.bodySm.copyWith(
                              color: Tok.textHi,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            data['inspection_type'] ?? 'Annual Inspection',
                            style: Tok.bodySm.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: Tok.ok),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SmallMetricRow extends StatelessWidget {
  final List<Widget> metrics;
  const _SmallMetricRow({required this.metrics});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: metrics
          .expand((m) => [Expanded(child: m), const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tok.surface,
        border: Border.all(color: Tok.border),
        borderRadius: BorderRadius.circular(Tok.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Tok.textLo),
              const SizedBox(width: 6),
              Text(label, style: Tok.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Tok.h1),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _LegendItem({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: Tok.bodySm),
          const SizedBox(width: 12),
          Text('$count', style: Tok.num.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Tok.surface,
          border: Border.all(color: Tok.border),
          borderRadius: BorderRadius.circular(Tok.rLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Tok.h1),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Tok.textLo, fontSize: 12)),
                  const SizedBox(height: 16),
                  // FIXED: removed `const` — Tok.textHi is a mode-aware getter
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Tok.textHi,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 48, color: Tok.brand.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}